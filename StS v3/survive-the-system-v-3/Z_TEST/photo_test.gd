extends Node
## Standalone test for the photosynthesis summed-area-table approach.
## Attach to a plain Node in a new scene and press Play (F6).
## Everything prints to the Output panel.
##
## On start:
##   1. Correctness: SAT income vs brute-force box sum for sample agents.
##   2. Benchmark: old per-agent offsets gather vs SAT build + 8 lookups.
## Then each frame: runs the fused simulation and prints stats every second.

# ------------------------------------------------------------------ settings
@export var grid_w := 64
@export var grid_h := 4               # vertical layers (y)
@export var grid_d := 64
@export var agent_count := 10000     # initial population
@export var capacity_factor := 2      # max population = agent_count * this
@export var max_range := 3            # per-agent r is random in [0, max_range]
@export var max_ry := 0               # per-agent ry is random in [0, max_ry]
@export var rebuild_interval := 1     # rebuild light field every N frames
@export var use_threads := true
@export var chunk_count := 8
@export var sim_dt := 0.016

@export var photo_on := true
@export var homeo_on := true
@export var grow_on := true
@export var dup_on := true
@export var remove_on := true

@export var run_correctness_test := true
@export var correctness_samples := 500
@export var run_benchmark := true

const PHOTO_RATE := 1.0
const GROWTH_RATE := 0.1

# ------------------------------------------------------------------ world
var sun_grid: PackedFloat32Array

# ------------------------------------------------------------------ agents
var capacity := 0
var active: PackedByteArray
var alive: PackedByteArray
var energy: PackedFloat32Array
var cell_id: PackedInt32Array
var agent_range: PackedInt32Array
var agent_ry: PackedInt32Array
var agent_income: PackedFloat32Array
var age: PackedInt32Array
var life_state: PackedInt32Array
var size_arr: PackedFloat32Array
var biomass: PackedFloat32Array
var free_slots: PackedInt32Array
var population := 0

var spawn_per_chunk: Array = []
var remove_per_chunk: Array = []

# ------------------------------------------------------------------ SAT grid
var photo_grid: PackedFloat64Array
var _sw := 0
var _sh := 0
var _sd := 0
var _splane := 0
var _photo_frame := 0
var _photo_rebuild_now := true

# ------------------------------------------------------------------ stats
var _t_pre := 0
var _t_chunks := 0
var _t_post := 0
var _frames := 0
var _stat_timer := 0.0
var _spawned := 0
var _removed := 0


func _ready() -> void:
	return
	randomize()
	_init_world()
	_init_agents()
	_init_photo_grid()
	print("--- photo SAT test ---")
	print("grid %dx%dx%d  agents %d  capacity %d  max_range %d  max_ry %d" % [
		grid_w, grid_h, grid_d, population, capacity, max_range, max_ry])

	if run_correctness_test:
		_correctness_test()
	if run_benchmark:
		_benchmark()

	print("--- simulation running (stats every second) ---")


# =====================================================================
#  Setup
# =====================================================================

func _init_world() -> void:
	var n := grid_w * grid_h * grid_d
	sun_grid.resize(n)
	for z in grid_d:
		for y in grid_h:
			for x in grid_w:
				var c := x + y * grid_w + z * grid_w * grid_h
				var pattern := 0.5 + 0.5 * sin(x * 0.15) * cos(z * 0.15)
				sun_grid[c] = pattern * float(y + 1) / float(grid_h)


func _init_agents() -> void:
	capacity = agent_count * capacity_factor
	active.resize(capacity)
	alive.resize(capacity)
	energy.resize(capacity)
	cell_id.resize(capacity)
	agent_range.resize(capacity)
	agent_ry.resize(capacity)
	agent_income.resize(capacity)
	age.resize(capacity)
	life_state.resize(capacity)
	size_arr.resize(capacity)
	biomass.resize(capacity)
	active.fill(0)
	alive.fill(0)

	var ncells := grid_w * grid_h * grid_d
	for i in agent_count:
		active[i] = 1
		alive[i] = 1
		energy[i] = randf_range(0.0, 5.0)
		cell_id[i] = randi() % ncells
		agent_range[i] = randi_range(0, max_range)
		agent_ry[i] = randi_range(0, max_ry)
		age[i] = 0
		life_state[i] = 0
		size_arr[i] = 1.0
		biomass[i] = 1.0
	population = agent_count

	free_slots = PackedInt32Array()
	for i in range(capacity - 1, agent_count - 1, -1):
		free_slots.append(i)

	spawn_per_chunk.resize(chunk_count)
	remove_per_chunk.resize(chunk_count)


func _init_photo_grid() -> void:
	_sw = grid_w + 2
	_sh = grid_h + 2
	_sd = grid_d + 2
	_splane = _sw * _sh
	photo_grid.resize(_splane * _sd)
	photo_grid.fill(0.0)


# =====================================================================
#  Light field: density stamp -> prefix -> weight -> prefix (SAT)
# =====================================================================

func _build_photo_field() -> void:
	photo_grid.fill(0.0)
	_stamp_density()
	_prefix_photo_grid()
	_density_to_weight()
	_prefix_photo_grid()


@warning_ignore("integer_division")
func _stamp_density() -> void:
	var W := grid_w
	var H := grid_h
	var D := grid_d
	var PLANE := W * H
	var SW := _sw
	var SP := _splane
	for i in capacity:
		if active[i] == 0 or alive[i] == 0:
			continue
		var cell := cell_id[i]
		var r := agent_range[i]
		var ry := agent_ry[i]
		var x := cell % W
		var y := (cell / W) % H
		var z := cell / PLANE
		var a0 := maxi(x - r, 0) + 1
		var a1 := mini(x + r + 1, W) + 1
		var b0 := (maxi(y - ry, 0) + 1) * SW
		var b1 := (mini(y + ry + 1, H) + 1) * SW
		var c0 := (maxi(z - r, 0) + 1) * SP
		var c1 := (mini(z + r + 1, D) + 1) * SP
		photo_grid[a0 + b0 + c0] += 1.0
		photo_grid[a1 + b0 + c0] -= 1.0
		photo_grid[a0 + b1 + c0] -= 1.0
		photo_grid[a0 + b0 + c1] -= 1.0
		photo_grid[a1 + b1 + c0] += 1.0
		photo_grid[a1 + b0 + c1] += 1.0
		photo_grid[a0 + b1 + c1] += 1.0
		photo_grid[a1 + b1 + c1] -= 1.0


func _prefix_photo_grid() -> void:
	var SW := _sw
	var SH := _sh
	var SD := _sd
	var SP := _splane
	for z in SD:
		for y in SH:
			var row := y * SW + z * SP
			for x in range(1, SW):
				photo_grid[row + x] += photo_grid[row + x - 1]
	for z in SD:
		for y in range(1, SH):
			var row := y * SW + z * SP
			for x in SW:
				photo_grid[row + x] += photo_grid[row + x - SW]
	for z in range(1, SD):
		var base := z * SP
		for k in SP:
			photo_grid[base + k] += photo_grid[base + k - SP]


func _density_to_weight() -> void:
	var W := grid_w
	var H := grid_h
	var D := grid_d
	var SW := _sw
	var SP := _splane
	for z in D:
		for y in H:
			var src := y * W + z * W * H
			var dst := (y + 1) * SW + (z + 1) * SP + 1
			for x in W:
				var d := photo_grid[dst + x]
				if d > 1e-6:
					photo_grid[dst + x] = sun_grid[src + x] * PHOTO_RATE / maxf(d, PHOTO_RATE)


@warning_ignore("integer_division")
func _photo_box_sum(i: int) -> float:
	var W := grid_w
	var H := grid_h
	var D := grid_d
	var SW := _sw
	var SP := _splane
	var cell := cell_id[i]
	var r := agent_range[i]
	var ry := agent_ry[i]
	var x := cell % W
	var y := (cell / W) % H
	var z := cell / (W * H)
	var a0 := maxi(x - r, 0)
	var a1 := mini(x + r + 1, W)
	var b0 := maxi(y - ry, 0) * SW
	var b1 := mini(y + ry + 1, H) * SW
	var c0 := maxi(z - r, 0) * SP
	var c1 := mini(z + r + 1, D) * SP
	return photo_grid[a1 + b1 + c1] \
		- photo_grid[a0 + b1 + c1] - photo_grid[a1 + b0 + c1] - photo_grid[a1 + b1 + c0] \
		+ photo_grid[a0 + b0 + c1] + photo_grid[a0 + b1 + c0] + photo_grid[a1 + b0 + c0] \
		- photo_grid[a0 + b0 + c0]


# =====================================================================
#  Simulation
# =====================================================================

func _process(delta: float) -> void:
	if photo_grid.size() == 0 or _sw == 0:
		return
	# --- main thread: light field ---
	var t0 := Time.get_ticks_usec()
	if photo_on:
		_photo_rebuild_now = (_photo_frame % rebuild_interval) == 0
		_photo_frame += 1
		if _photo_rebuild_now:
			_build_photo_field()
	else:
		_photo_rebuild_now = false
		_photo_frame = 0
	var t1 := Time.get_ticks_usec()

	# --- chunks ---
	if use_threads:
		var id := WorkerThreadPool.add_group_task(_chunk_task, chunk_count)
		WorkerThreadPool.wait_for_group_task_completion(id)
	else:
		for k in chunk_count:
			_chunk_task(k)
	var t2 := Time.get_ticks_usec()

	# --- main thread: spawn / remove ---
	_apply_spawn_remove()
	var t3 := Time.get_ticks_usec()

	_t_pre += t1 - t0
	_t_chunks += t2 - t1
	_t_post += t3 - t2
	_frames += 1
	_stat_timer += delta
	if _stat_timer >= 1.0:
		_print_stats()


func _chunk_task(k: int) -> void:
	var per := ceili(float(capacity) / chunk_count)
	var start := k * per
	var end := mini(start + per, capacity)
	run_chunk_simulation(start, end, k, sim_dt)


func run_chunk_simulation(start: int, end: int, local_id: int, dt: float) -> void:
	var rebuild := _photo_rebuild_now
	var spawn := PackedInt32Array()
	var remove := PackedInt32Array()

	for i in range(start, end):
		if active[i] == 0:
			continue
		if alive[i] == 0:
			if remove_on:
				remove.append(i)
			continue

		var e := energy[i]

		if photo_on:
			if rebuild:
				agent_income[i] = _photo_box_sum(i)
			if e < 5.0:
				e += agent_income[i] * dt
		elif e < 5.0:
			e += dt

		if homeo_on:
			e -= 0.5 * dt
			if e < 0.0:
				alive[i] = 0
				energy[i] = e
				if remove_on:
					remove.append(i)
				continue

		if grow_on:
			age[i] += 1
			if life_state[i] < 3 and e > 3.0:
				life_state[i] += 1
				e -= 3.0
				size_arr[i] += GROWTH_RATE
				biomass[i] += 2.0

		if dup_on and e >= 5.0:
			spawn.append(i)
			e -= 5.0

		energy[i] = e

	spawn_per_chunk[local_id] = spawn
	remove_per_chunk[local_id] = remove


@warning_ignore("integer_division")
func _apply_spawn_remove() -> void:
	var W := grid_w
	var H := grid_h
	var D := grid_d
	var PLANE := W * H

	if remove_on:
		for k in chunk_count:
			var list: PackedInt32Array = remove_per_chunk[k]
			for i in list:
				active[i] = 0
				alive[i] = 0
				free_slots.append(i)
				population -= 1
				_removed += 1

	if dup_on:
		for k in chunk_count:
			var list: PackedInt32Array = spawn_per_chunk[k]
			for parent in list:
				if free_slots.is_empty():
					break
				var j := free_slots[free_slots.size() - 1]
				free_slots.resize(free_slots.size() - 1)
				# child lands in a random neighbouring cell (same layer)
				var pc := cell_id[parent]
				var x := clampi(pc % W + randi_range(-1, 1), 0, W - 1)
				var y := (pc / W) % H
				var z := clampi(pc / PLANE + randi_range(-1, 1), 0, D - 1)
				cell_id[j] = x + y * W + z * PLANE
				agent_range[j] = agent_range[parent]
				agent_ry[j] = agent_ry[parent]
				active[j] = 1
				alive[j] = 1
				energy[j] = 1.0
				age[j] = 0
				life_state[j] = 0
				size_arr[j] = 1.0
				biomass[j] = 1.0
				agent_income[j] = _photo_box_sum(j) if photo_on else 0.0
				population += 1
				_spawned += 1

	for k in chunk_count:
		spawn_per_chunk[k] = PackedInt32Array()
		remove_per_chunk[k] = PackedInt32Array()


func _print_stats() -> void:
	var f := maxi(_frames, 1)
	print("fps %d | pop %d | +%d -%d | light %.2f ms | chunks %.2f ms | spawn/remove %.2f ms" % [
		Engine.get_frames_per_second(), population, _spawned, _removed,
		_t_pre / 1000.0 / f, _t_chunks / 1000.0 / f, _t_post / 1000.0 / f])
	_t_pre = 0
	_t_chunks = 0
	_t_post = 0
	_frames = 0
	_stat_timer = 0.0
	_spawned = 0
	_removed = 0


# =====================================================================
#  Tests
# =====================================================================

## Independent brute force: count competitors by walking every box,
## then sum weights over a sample of agents' boxes. Compare with SAT.
@warning_ignore("integer_division")
func _correctness_test() -> void:
	print("correctness: brute force density (may take a few seconds)...")
	var W := grid_w
	var H := grid_h
	var D := grid_d
	var PLANE := W * H
	var n := W * H * D

	var dens := PackedFloat64Array()
	dens.resize(n)
	dens.fill(0.0)
	for i in capacity:
		if active[i] == 0 or alive[i] == 0:
			continue
		var cell := cell_id[i]
		var r := agent_range[i]
		var ry := agent_ry[i]
		var x := cell % W
		var y := (cell / W) % H
		var z := cell / PLANE
		for zz in range(maxi(z - r, 0), mini(z + r + 1, D)):
			for yy in range(maxi(y - ry, 0), mini(y + ry + 1, H)):
				for xx in range(maxi(x - r, 0), mini(x + r + 1, W)):
					dens[xx + yy * W + zz * PLANE] += 1.0

	var wgt := PackedFloat64Array()
	wgt.resize(n)
	for c in n:
		var d := dens[c]
		wgt[c] = sun_grid[c] * PHOTO_RATE / maxf(d, PHOTO_RATE) if d > 1e-6 else 0.0

	_build_photo_field()

	var max_err := 0.0
	var max_val := 0.0
	var samples := mini(correctness_samples, population)
	for s in samples:
		var i := randi() % agent_count
		var cell := cell_id[i]
		var r := agent_range[i]
		var ry := agent_ry[i]
		var x := cell % W
		var y := (cell / W) % H
		var z := cell / PLANE
		var brute := 0.0
		for zz in range(maxi(z - r, 0), mini(z + r + 1, D)):
			for yy in range(maxi(y - ry, 0), mini(y + ry + 1, H)):
				for xx in range(maxi(x - r, 0), mini(x + r + 1, W)):
					brute += wgt[xx + yy * W + zz * PLANE]
		var sat := _photo_box_sum(i)
		max_err = maxf(max_err, absf(sat - brute))
		max_val = maxf(max_val, absf(brute))

	var ok := max_err <= 1e-6 * maxf(max_val, 1.0)
	print("correctness: %d samples, max abs error %.3e (max value %.3f) -> %s" % [
		samples, max_err, max_val, "OK" if ok else "MISMATCH"])


## Old method: per-agent flat offsets loop, density counted on own cell only.
## New method: full SAT rebuild + one 8-lookup query per agent.
@warning_ignore("integer_division")
func _benchmark() -> void:
	var W := grid_w
	var H := grid_h
	var PLANE := W * H
	var n := W * H * grid_d

	# old offsets (same layout as your build_offsets, ry = 0)
	var offsets: Array = []
	for r in max_range + 1:
		var list := PackedInt32Array()
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				list.append(dx + dz * PLANE)
		offsets.append(list)

	var old_dens := PackedFloat32Array()
	old_dens.resize(n)
	old_dens.fill(0.0)
	for i in capacity:
		if active[i] == 1 and alive[i] == 1:
			old_dens[cell_id[i]] += 1.0

	var t0 := Time.get_ticks_usec()
	var checksum_old := 0.0
	for i in capacity:
		if active[i] == 0 or alive[i] == 0:
			continue
		var sun_c := cell_id[i]
		var total := 0.0
		for off in offsets[agent_range[i]]:
			var cc: int = sun_c + off
			if cc < 0 or cc >= n:
				continue
			var d := old_dens[cc]
			if d > 1e-6:
				total += sun_grid[cc] * PHOTO_RATE / maxf(d, PHOTO_RATE)
		checksum_old += total
	var t1 := Time.get_ticks_usec()

	_build_photo_field()
	var t2 := Time.get_ticks_usec()
	var checksum_new := 0.0
	for i in capacity:
		if active[i] == 0 or alive[i] == 0:
			continue
		checksum_new += _photo_box_sum(i)
	var t3 := Time.get_ticks_usec()

	print("benchmark (single thread, %d agents, ranges 0..%d):" % [population, max_range])
	print("  old offsets gather : %.2f ms" % ((t1 - t0) / 1000.0))
	print("  new SAT build      : %.2f ms" % ((t2 - t1) / 1000.0))
	print("  new SAT queries    : %.2f ms" % ((t3 - t2) / 1000.0))
	print("  new total          : %.2f ms" % ((t3 - t1) / 1000.0))
	print("  (totals differ on purpose: old counts competitors on own cell only, new on whole box)")
