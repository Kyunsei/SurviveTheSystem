extends Node2D
## 100k-agent performance test for Godot 4.x, with spatial-grid neighbour detection.
## Usage: create a new scene with a single Node2D, attach this script, press F6.
##
## Controls:
##   Left click        -> print the ID of the nearest agent + its neighbours
##                        (agent turns red, its neighbours yellow)
##   Mouse wheel       -> zoom
##   Right/Middle drag -> pan
##   Space             -> pause / resume simulation
##   T                 -> toggle multithreaded update (WorkerThreadPool)
##   G                 -> toggle spatial grid + neighbour detection (separation steering)
##   C                 -> toggle colouring agents by neighbour count (needs grid on)

@export var agent_count: int = 100_000
@export var world_size: Vector2 = Vector2(4000, 2400)
@export var agent_size: float = 3.0
@export var min_speed: float = 10.0
@export var max_speed: float = 60.0
@export var pick_radius_px: float = 6.0          ## click radius in screen pixels
@export var use_threads: bool = true
@export var chunk_size: int = 4096               ## agents per thread task
@export var disable_vsync: bool = true           ## uncapped FPS for benchmarking

@export_group("Neighbours")
@export var use_grid: bool = true
@export var neighbor_radius: float = 12.0        ## also used as grid cell size
@export var separation_strength: float = 300.0
@export var color_by_density: bool = false
@export var density_max_neighbors: int = 8       ## neighbour count that maps to full "hot" colour

# MultiMesh 2D buffer layout per instance:
# [x.x, y.x, 0, origin.x,  x.y, y.y, 0, origin.y,  r, g, b, a]
const STRIDE := 12
const COLOR_DEFAULT := Color(0.4, 0.8, 1.0, 1.0)
const COLOR_HOT := Color(1.0, 0.45, 0.1, 1.0)
const COLOR_SELECTED := Color(1.0, 0.15, 0.15, 1.0)
const COLOR_NEIGHBOR := Color(1.0, 0.95, 0.2, 1.0)

# --- Agent data (Structure of Arrays, no per-agent Nodes) ---
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var neighbor_count := PackedInt32Array()
var buf := PackedFloat32Array()   # GPU instance buffer, written in-place

# --- Spatial grid (flat arrays, rebuilt every frame by counting sort) ---
# Agents of cell c are cell_agents[cell_start[c] .. cell_start[c + 1] - 1]
var cell_size := 1.0
var inv_cell := 1.0
var grid_cols := 0
var grid_rows := 0
var cell_total := 0
var cell_start := PackedInt32Array()
var cell_agents := PackedInt32Array()
var agent_cell := PackedInt32Array()
var grid_valid := false

var mm: MultiMesh
var mmi: MultiMeshInstance2D
var cam: Camera2D
var label: Label

var paused := false
var selected := -1
var highlighted := PackedInt32Array()
var grid_ms := 0.0
var neighbor_ms := 0.0
var sim_ms := 0.0
var upload_ms := 0.0
var pick_ms := 0.0
var _panning := false


func _ready() -> void:
	if disable_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var t0 := Time.get_ticks_usec()
	_init_agents()
	_init_grid()
	_init_rendering()
	_init_camera()
	_init_ui()
	print("Init %d agents, grid %dx%d cells, in %.1f ms" % [
		agent_count, grid_cols, grid_rows, (Time.get_ticks_usec() - t0) / 1000.0])


func _init_agents() -> void:
	pos.resize(agent_count)
	vel.resize(agent_count)
	neighbor_count.resize(agent_count)
	buf.resize(agent_count * STRIDE)

	for i in agent_count:
		var p := Vector2(randf() * world_size.x, randf() * world_size.y)
		pos[i] = p
		vel[i] = Vector2.from_angle(randf() * TAU) * randf_range(min_speed, max_speed)

		var o := i * STRIDE
		buf[o + 0] = 1.0; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
		buf[o + 4] = 0.0; buf[o + 5] = 1.0; buf[o + 6] = 0.0; buf[o + 7] = p.y
		_write_color(i, COLOR_DEFAULT)


func _init_grid() -> void:
	cell_size = neighbor_radius   # cell >= radius -> a 3x3 cell block covers every neighbour
	inv_cell = 1.0 / cell_size
	grid_cols = maxi(1, ceili(world_size.x / cell_size))
	grid_rows = maxi(1, ceili(world_size.y / cell_size))
	cell_total = grid_cols * grid_rows
	cell_start.resize(cell_total + 1)
	cell_agents.resize(agent_count)
	agent_cell.resize(agent_count)


func _init_rendering() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(agent_size, agent_size)

	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D   # must be set before instance_count
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = agent_count
	mm.buffer = buf

	mmi = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _init_camera() -> void:
	cam = Camera2D.new()
	cam.position = world_size * 0.5
	var vp := get_viewport_rect().size
	var z := minf(vp.x / world_size.x, vp.y / world_size.y)
	cam.zoom = Vector2(z, z)
	add_child(cam)
	cam.make_current()


func _init_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	if not paused:
		# Phase 1: build grid from current positions (single-threaded counting sort)
		# Phase 2: neighbour pass reads pos, writes only vel[i] of its own agent
		# Phase 3: movement step writes pos[i]
		# Phases never overlap, so the threaded passes have no data races.
		if use_grid:
			var tg := Time.get_ticks_usec()
			_build_grid()
			grid_valid = true
			grid_ms = (Time.get_ticks_usec() - tg) / 1000.0

			var tn := Time.get_ticks_usec()
			_run_chunks(_neighbors_chunk, delta)
			neighbor_ms = (Time.get_ticks_usec() - tn) / 1000.0
		else:
			grid_ms = 0.0
			neighbor_ms = 0.0

		var t0 := Time.get_ticks_usec()
		_run_chunks(_update_chunk, delta)
		sim_ms = (Time.get_ticks_usec() - t0) / 1000.0

		var t1 := Time.get_ticks_usec()
		mm.buffer = buf   # one bulk upload instead of 100k set_instance_transform_2d calls
		upload_ms = (Time.get_ticks_usec() - t1) / 1000.0

	label.text = "\n".join([
		"FPS: %d   Agents: %d" % [Engine.get_frames_per_second(), agent_count],
		"Mode: %s" % ("threads" if use_threads else "single thread"),
		"Grid build: %.2f ms" % grid_ms,
		"Neighbours: %.2f ms" % neighbor_ms,
		"Move: %.2f ms" % sim_ms,
		"Upload: %.2f ms" % upload_ms,
		"Total CPU: %.2f ms" % (grid_ms + neighbor_ms + sim_ms + upload_ms),
		"Last pick: %.2f ms   Selected: %s" % [pick_ms, str(selected) if selected >= 0 else "-"],
		"[Space] pause  [T] threads  [G] grid %s  [C] density %s" % [
			"ON" if use_grid else "OFF", "ON" if color_by_density else "OFF"],
	])


## Runs fn(chunk_index, delta) over all agents, threaded or not.
func _run_chunks(fn: Callable, delta: float) -> void:
	var tasks := ceili(float(agent_count) / chunk_size)
	if use_threads:
		var id := WorkerThreadPool.add_group_task(fn.bind(delta), tasks, -1, true)
		WorkerThreadPool.wait_for_group_task_completion(id)
	else:
		for c in tasks:
			fn.call(c, delta)


func _update_chunk(chunk: int, delta: float) -> void:
	var start := chunk * chunk_size
	_step(start, mini(start + chunk_size, agent_count), delta)


## Movement hot loop. Writes go straight to the member arrays (never copy them
## into a local var first: that triggers copy-on-write and kills performance).
func _step(start: int, end: int, dt: float) -> void:
	var w := world_size.x
	var h := world_size.y
	for i in range(start, end):
		var v := vel[i]
		var p := pos[i] + v * dt
		var bounced := false
		if p.x < 0.0:
			p.x = -p.x; v.x = -v.x; bounced = true
		elif p.x > w:
			p.x = 2.0 * w - p.x; v.x = -v.x; bounced = true
		if p.y < 0.0:
			p.y = -p.y; v.y = -v.y; bounced = true
		elif p.y > h:
			p.y = 2.0 * h - p.y; v.y = -v.y; bounced = true
		pos[i] = p
		if bounced:
			vel[i] = v
		var o := i * STRIDE
		buf[o + 3] = p.x
		buf[o + 7] = p.y


# ---------------------------------------------------------------- grid

func _cell_of(p: Vector2) -> int:
	var cx := clampi(int(p.x * inv_cell), 0, grid_cols - 1)
	var cy := clampi(int(p.y * inv_cell), 0, grid_rows - 1)
	return cy * grid_cols + cx


## Counting sort: O(N + cells), no per-cell Arrays, no allocations except one cursor copy.
func _build_grid() -> void:
	cell_start.fill(0)

	# 1) count agents per cell (stored shifted by one for the prefix sum)
	for i in agent_count:
		var c := _cell_of(pos[i])
		agent_cell[i] = c
		cell_start[c + 1] += 1

	# 2) prefix sum -> start offset of each cell
	for c in range(1, cell_total + 1):
		cell_start[c] += cell_start[c - 1]

	# 3) scatter agent IDs into their cell's slot range
	var cursor := cell_start.duplicate()
	for i in agent_count:
		var c := agent_cell[i]
		cell_agents[cursor[c]] = i
		cursor[c] += 1


func _neighbors_chunk(chunk: int, delta: float) -> void:
	var start := chunk * chunk_size
	_neighbors(start, mini(start + chunk_size, agent_count), delta)


## For each agent: scan the 3x3 cell block, count neighbours within radius and
## apply a separation push. Reads pos[], writes only vel[i] / neighbor_count[i] / own colour.
@warning_ignore("integer_division")
func _neighbors(start: int, end: int, dt: float) -> void:
	var r2 := neighbor_radius * neighbor_radius
	var k_sep := separation_strength * dt
	var dens_inv := 1.0 / float(maxi(density_max_neighbors, 1))
	for i in range(start, end):
		var p := pos[i]
		var c := agent_cell[i]
		var cx := c % grid_cols
		var cy := c / grid_cols
		var push := Vector2.ZERO
		var n := 0

		for gy in range(maxi(cy - 1, 0), mini(cy + 2, grid_rows)):
			var row := gy * grid_cols
			for gx in range(maxi(cx - 1, 0), mini(cx + 2, grid_cols)):
				var cell := row + gx
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j := cell_agents[k]
					if j == i:
						continue
					var d := p - pos[j]
					var dsq := d.length_squared()
					if dsq < r2 and dsq > 0.0001:
						n += 1
						push += d / dsq   # magnitude ~ 1/distance: closer pushes harder

		neighbor_count[i] = n
		if n > 0:
			var v := vel[i] + push * k_sep
			var s := clampf(v.length(), min_speed, max_speed)
			vel[i] = v.normalized() * s

		if color_by_density and i != selected:
			_write_color(i, COLOR_DEFAULT.lerp(COLOR_HOT, minf(n * dens_inv, 1.0)))


## Returns IDs of agents within `radius` of `point`. Uses the grid when it is
## valid, otherwise brute force. Searches one extra cell ring because positions
## have moved one step since the grid was built.
func _query_radius(point: Vector2, radius: float, exclude: int = -1) -> PackedInt32Array:
	var result := PackedInt32Array()
	var r2 := radius * radius

	if not (use_grid and grid_valid):
		for i in agent_count:
			if i != exclude and pos[i].distance_squared_to(point) <= r2:
				result.append(i)
		return result

	var x0 := clampi(int((point.x - radius) * inv_cell) - 1, 0, grid_cols - 1)
	var x1 := clampi(int((point.x + radius) * inv_cell) + 1, 0, grid_cols - 1)
	var y0 := clampi(int((point.y - radius) * inv_cell) - 1, 0, grid_rows - 1)
	var y1 := clampi(int((point.y + radius) * inv_cell) + 1, 0, grid_rows - 1)
	for gy in range(y0, y1 + 1):
		var row := gy * grid_cols
		for gx in range(x0, x1 + 1):
			var cell := row + gx
			for k in range(cell_start[cell], cell_start[cell + 1]):
				var j := cell_agents[k]
				if j != exclude and pos[j].distance_squared_to(point) <= r2:
					result.append(j)
	return result


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_pick(get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.15)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_panning = mb.pressed

	elif event is InputEventMouseMotion and _panning:
		cam.position -= (event as InputEventMouseMotion).relative / cam.zoom

	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				paused = not paused
			KEY_T:
				use_threads = not use_threads
			KEY_G:
				use_grid = not use_grid
				grid_valid = false
				if not use_grid and color_by_density:
					_set_density_colors(false)
				print("Grid / neighbour detection: %s" % ("ON" if use_grid else "OFF"))
			KEY_C:
				_set_density_colors(not color_by_density)


func _set_density_colors(on: bool) -> void:
	color_by_density = on
	if not on:
		_reset_all_colors()
	mm.buffer = buf
	print("Density colouring: %s" % ("ON" if on else "OFF"))


func _reset_all_colors() -> void:
	for i in agent_count:
		_write_color(i, COLOR_DEFAULT)
	highlighted.clear()
	if selected >= 0:
		_write_color(selected, COLOR_SELECTED)


func _zoom_at(factor: float) -> void:
	var before := get_global_mouse_position()
	cam.zoom = (cam.zoom * factor).clamp(Vector2(0.05, 0.05), Vector2(20, 20))
	cam.position += before - get_global_mouse_position()   # keep point under cursor


func _pick(world_pos: Vector2) -> void:
	var t0 := Time.get_ticks_usec()
	var r := pick_radius_px / cam.zoom.x
	var best := -1
	var best_d := r * r
	for j in _query_radius(world_pos, r):
		var d := pos[j].distance_squared_to(world_pos)
		if d < best_d:
			best_d = d
			best = j
	pick_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var method := "grid" if (use_grid and grid_valid) else "brute force"

	if best < 0:
		print("No agent at %s (pick %.3f ms, %s)" % [world_pos, pick_ms, method])
		return

	# restore previous highlight
	var restore := COLOR_DEFAULT
	for j in highlighted:
		_write_color(j, restore)
	if selected >= 0:
		_write_color(selected, restore)

	selected = best
	var neighbors := _query_radius(pos[best], neighbor_radius, best)
	highlighted = neighbors
	if not color_by_density:
		for j in neighbors:
			_write_color(j, COLOR_NEIGHBOR)
	_write_color(selected, COLOR_SELECTED)
	mm.buffer = buf

	print("Clicked agent ID: %d  pos: %s  vel: %s  (pick %.3f ms, %s)" % [
		best, pos[best], vel[best], pick_ms, method])
	print("  %d neighbour(s) within %.1f: %s" % [
		neighbors.size(), neighbor_radius, _format_ids(neighbors, 20)])


func _format_ids(ids: PackedInt32Array, max_shown: int) -> String:
	var parts := PackedStringArray()
	for k in mini(ids.size(), max_shown):
		parts.append(str(ids[k]))
	var s := ", ".join(parts)
	if ids.size() > max_shown:
		s += ", ... (+%d)" % (ids.size() - max_shown)
	return "[" + s + "]"


func _write_color(i: int, c: Color) -> void:
	var o := i * STRIDE + 8
	buf[o] = c.r; buf[o + 1] = c.g; buf[o + 2] = c.b; buf[o + 3] = c.a
