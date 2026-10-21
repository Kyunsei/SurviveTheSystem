extends Node2D
## 100k-agent performance test for Godot 4.x
## Usage: create a new scene with a single Node2D, attach this script, press F6.
##
## Controls:
##   Left click      -> print the ID of the nearest agent under the mouse (it turns red)
##   Mouse wheel     -> zoom
##   Right/Middle drag -> pan
##   Space           -> pause / resume simulation
##   T               -> toggle multithreaded update (WorkerThreadPool)

@export var agent_count: int = 100_000
@export var world_size: Vector2 = Vector2(4000, 2400)
@export var agent_size: float = 3.0
@export var min_speed: float = 10.0
@export var max_speed: float = 60.0
@export var pick_radius_px: float = 6.0      ## click radius in screen pixels
@export var use_threads: bool = true
@export var chunk_size: int = 4096           ## agents per thread task
@export var disable_vsync: bool = true       ## uncapped FPS for benchmarking

# MultiMesh 2D buffer layout per instance:
# [x.x, y.x, 0, origin.x,  x.y, y.y, 0, origin.y,  r, g, b, a]
const STRIDE := 12
const COLOR_DEFAULT := Color(0.4, 0.8, 1.0, 1.0)
const COLOR_SELECTED := Color(1.0, 0.15, 0.15, 1.0)

# --- Agent data (Structure of Arrays, no per-agent Nodes) ---
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var buf := PackedFloat32Array()   # GPU instance buffer, written in-place

var mm: MultiMesh
var mmi: MultiMeshInstance2D
var cam: Camera2D
var label: Label

var paused := false
var selected := -1
var sim_ms := 0.0
var upload_ms := 0.0
var pick_ms := 0.0
var _panning := false


func _ready() -> void:
	if disable_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var t0 := Time.get_ticks_usec()
	_init_agents()
	_init_rendering()
	_init_camera()
	_init_ui()
	print("Init %d agents in %.1f ms" % [agent_count, (Time.get_ticks_usec() - t0) / 1000.0])


func _init_agents() -> void:
	pos.resize(agent_count)
	vel.resize(agent_count)
	buf.resize(agent_count * STRIDE)

	for i in agent_count:
		var p := Vector2(randf() * world_size.x, randf() * world_size.y)
		pos[i] = p
		vel[i] = Vector2.from_angle(randf() * TAU) * randf_range(min_speed, max_speed)

		var o := i * STRIDE
		buf[o + 0] = 1.0; buf[o + 1] = 0.0; buf[o + 2] = 0.0; buf[o + 3] = p.x
		buf[o + 4] = 0.0; buf[o + 5] = 1.0; buf[o + 6] = 0.0; buf[o + 7] = p.y
		_write_color(i, COLOR_DEFAULT)


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
		var t0 := Time.get_ticks_usec()
		if use_threads:
			var tasks := ceili(float(agent_count) / chunk_size)
			var id := WorkerThreadPool.add_group_task(_update_chunk.bind(delta), tasks, -1, true)
			WorkerThreadPool.wait_for_group_task_completion(id)
		else:
			_step(0, agent_count, delta)
		sim_ms = (Time.get_ticks_usec() - t0) / 1000.0

		var t1 := Time.get_ticks_usec()
		mm.buffer = buf   # one bulk upload instead of 100k set_instance_transform_2d calls
		upload_ms = (Time.get_ticks_usec() - t1) / 1000.0

	label.text = "FPS: %d\nAgents: %d\nSim: %.2f ms (%s)\nUpload: %.2f ms\nLast pick: %.2f ms\nSelected: %s\n[Space] pause  [T] threads" % [
		Engine.get_frames_per_second(), agent_count, sim_ms,
		"threads" if use_threads else "single", upload_ms, pick_ms,
		str(selected) if selected >= 0 else "-"
	]


func _update_chunk(chunk: int, delta: float) -> void:
	var start := chunk * chunk_size
	_step(start, mini(start + chunk_size, agent_count), delta)


## Hot loop. Writes go straight to the member arrays (never copy them into a
## local var first: that triggers copy-on-write and kills performance).
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
			KEY_SPACE: paused = not paused
			KEY_T: use_threads = not use_threads


func _zoom_at(factor: float) -> void:
	var before := get_global_mouse_position()
	cam.zoom = (cam.zoom * factor).clamp(Vector2(0.05, 0.05), Vector2(20, 20))
	cam.position += before - get_global_mouse_position()   # keep point under cursor


## Brute-force nearest search. ~100k distance checks only on click, which is
## acceptable for a one-off. See notes for a spatial grid if you query every frame.
func _pick(world_pos: Vector2) -> void:
	var t0 := Time.get_ticks_usec()
	var r := pick_radius_px / cam.zoom.x
	var best := -1
	var best_d := r * r
	for i in agent_count:
		var d := pos[i].distance_squared_to(world_pos)
		if d < best_d:
			best_d = d
			best = i
	pick_ms = (Time.get_ticks_usec() - t0) / 1000.0

	if best < 0:
		print("No agent at %s (pick took %.2f ms)" % [world_pos, pick_ms])
		return

	if selected >= 0:
		_write_color(selected, COLOR_DEFAULT)
	selected = best
	_write_color(selected, COLOR_SELECTED)
	mm.buffer = buf
	print("Clicked agent ID: %d  pos: %s  vel: %s  (pick took %.2f ms)" % [best, pos[best], vel[best], pick_ms])


func _write_color(i: int, c: Color) -> void:
	var o := i * STRIDE + 8
	buf[o] = c.r; buf[o + 1] = c.g; buf[o + 2] = c.b; buf[o + 3] = c.a
