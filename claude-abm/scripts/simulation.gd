extends Node
## GPU agent-based ecosystem. Owns all RenderingDevice resources and runs the
## compute kernels in res://shaders/sim.comp. Every agent lives on the GPU; the
## CPU only dispatches kernels and reads back small buffers asynchronously.
##
## Work is scheduled as a queue of phases. A tick is `think_chunks` THINK phases
## (the first also runs PLAYER/SPAWN, the last BIRTH..FIELD), and every
## SORT_INTERVAL ticks five sort phases follow. The 2D view runs whole ticks per
## frame; the 3D explorer spreads phases over frames to keep frame times smooth.
##
## One Simulation lives in the Launch autoload and survives scene changes, so the
## 2D and 3D views are just two ways of looking at it (set_view switches).

signal stats_updated(stats: Dictionary)
signal readback_updated(data: PackedByteArray) ## 3D: near agents, inspected agent
signal heightmap_ready(heights: PackedFloat32Array) ## terrain heights (m) per cell
signal restarted ## build(), reset() or load_world() started a (new) world
signal saved(path: String) ## save_world() finished writing
## The agent or plant storage was enlarged (populations are limited by energy,
## not by storage: it grows when they approach it).
signal grown(capacity: int, plant_capacity: int)

enum Brain { UTILITY, NEURAL, MIXED }
enum Cmd { NONE, KILL, FEED, SOW, TRACK, UNTRACK, SPAWN }

const Meshes := preload("res://scripts/meshes.gd")
const SHADER_PATH := "res://shaders/sim.comp"
const KERNELS := [
	"INIT_FIELD", "INIT_AGENTS", "REGISTER", "THINK", "BIRTH", "FINALIZE", "COMMIT",
	"FIELD", "RENDER_FIELD", "RENDER_AGENTS", "CLEAR_STATS", "STATS",
	"SCAN1", "SCAN2", "SCAN3", "PERM", "SCATTER_GENES", "SCATTER_W1", "SCATTER_W2",
	"SCATTER_AGENTS", "SORT_TAIL", "CLEAR_GRID_W", "SCATTER_PREV",
	"PLAYER", "SPAWN", "VIS_RESET", "NEARBY", "CLEAR_INSTANCES", "INSPECT",
	"SCATTER_CARRY", "INIT_PLANTS", "PLANT_TICK", "PLANT_FINALIZE", "PLANT_COMMIT",
	"P_CLEAR_INDEX", "P_COUNT", "PSCAN1", "PSCAN2", "PSCAN3", "P_DEST", "P_SCATTER_A",
	"P_SCATTER_B", "P_COPY_A", "P_COPY_B", "P_TAIL", "P_COVER_ADD", "P_VIS_RESET", "P_NEARBY", "P_CLEAR_INST",
]
const ACTIONS := ["graze", "hunt", "flee", "flock", "wander", "rest", "scavenge",
		"hide", "care", "mark", "home", "recall"]
const COLOR_MODES := ["Species (hue)", "Diet", "Brain type", "Action", "Energy"]

# Must match the #defines in sim.comp.
const AGENT_BYTES := 64
const GENES := 24
const W1_WORDS := 42
const W2_WORDS := 16
const STATS_WORDS := 96
const FIELD_STRIDE := 4
const PLAYER_BYTES := 80
const PC_BYTES := 112 ## Params in sim.comp (104 bytes), padded to 16
## Longest vision (m) the spatial hash must cover; see vision in sim.comp.
const MAX_VISION_M := 30.0
const MAX_VIS := 32768 ## 3D creatures drawn at most
const MAX_NEAR := 4096 ## agents reported to the CPU for picking
const READBACK_WORDS := 64 + MAX_NEAR * 8
const MAX_SPAWN := 16
const COUNTER_WORDS := 32
# Plants (must match sim.comp).
const PSTRIDE := 8 ## each tick updates 1/PSTRIDE of the plants
const MAX_PVIS := 32768 ## 3D plant instances per form
const PLANT_VIEW := 260.0 ## trees are drawn this far (m); smaller forms nearer
const PLANT_SORT_INTERVAL := 16 ## the plant index is rebuilt this often (ticks)
const PLANT_SORT_STEPS := 3
## Agents are physically re-sorted by position this often (in ticks). The 3D
## view sorts less often: the sort briefly holds up the ticks spread over frames.
const SORT_INTERVAL := 32
const SORT_INTERVAL_3D := 128
const SORT_STEPS := 5
const SAVE_MAGIC := "ABM-WORLD"
const SAVE_VERSION := 3 ## 2: individual plants, 3: calls, postures, parental care, scent, places
const SAVE_DIR := "user://worlds"
## Storage grows by half when a population passes this share of it...
const GROW_AT := 0.85
## ...up to these safety limits (GPU memory: ~570 MB of buffers at 1M agents,
## ~50 bytes per plant).
const MAX_CAPACITY := 2_000_000
const MAX_PLANT_CAPACITY := 12_000_000
const _GROW_SNAPSHOT := "<grow>" # save_world() target that rebuilds instead of writing

# Structural settings: changing these needs build().
var capacity := 300_000
var world_size := 1024 ## cells per side
var cell_size := 8.0 ## metres per cell
var plant_capacity := 6_000_000
var explorer := false ## 3D mode (see set_view): agents go to the MultiMesh, not 2D dots
## The 3D creatures. The GPU writes their instances directly; owned here so the
## buffer (bound in every kernel's uniform set) outlives the 3D scene.
var agent_multimesh: MultiMesh
## The 3D plants (grass, flowers, bushes, trees), also written by the GPU.
var plant_multimeshes: Array[MultiMesh] = []

# Run settings: applied on reset().
var initial_pop := 60_000
var initial_plants := 3_000_000
var brain_mode := Brain.MIXED
var seed_value := 1

# Live settings.
var steps_per_frame := 1 ## 2D: ticks per frame
var paused := false
var color_mode := 0
var show_fields := true
var stats_interval := 10
var think_chunks := 1 ## THINK is split over this many phases
var phase_budget := 0 ## 3D: THINK phases the explorer allows (leftover is kept here)
var phase_fraction := 0.0 ## 3D: progress towards the next phase, for interpolation
var field_interval := 1 ## redraw the field texture every N frames
var player := {
	"pos": Vector2.ZERO, "vis_radius": 200.0, "near_radius": 60.0, "presence": 0,
	"presence_pheno": 0, "target": -1, "target_pos": Vector2.ZERO, "inspect_tracked": false,
	"speed": 0.0,
}
var params := {
	"plant_growth": 0.1,
	"season_strength": 0.35,
	"season_length": 4000.0,
	"mutation_scale": 1.0,
	"metabolism": 0.016,
	"move_cost": 0.01,
	"attack_power": 0.8,
	"meat_decay": 0.004,
	"plant_efficiency": 0.5,
	"meat_efficiency": 1.0,
	"max_age": 3000.0,
	"mate_distance": 0.12,
	"vision_cost": 0.0015,
	"detox_cost": 0.025,
	"plant_mutation": 0.04,
	"sun_energy": 0.001,
	"compute_cost": 0.0006,
}

var texture := Texture2DRD.new()
var heights := PackedFloat32Array() ## CPU copy of the terrain heights, once read back
var tick := 0 ## ticks planned so far
var ready_to_run := false
var profile := false ## print GPU timings per phase type (for benchmarking)

var _rd: RenderingDevice
var _shaders := {}
var _pipelines := {}
var _sets := [{}, {}] # [parity][kernel]: parity p reads grid p and writes grid 1 - p
var _buffers := {}
var _view_tex := RID()
var _psort_busy := false ## a plant sort is spread over frames (3D): hold the plant models
var _frame := 0
var _queue: Array[Dictionary] = []
var _think_done := 0
var _last_chunk := 0 ## chunk index of the last THINK phase run (3D interpolation clock)
var _pending_cmd := {}
var _stats_pending := false
var _readback_pending := false
var _last_stats_tick := 0
var _saving := "" ## path of a save in progress (the world is paused meanwhile)
var _save_blobs := {}
var _last_stats_msec := 0
var _growing := false ## the world is being rebuilt with bigger storage
var land_m2 := 0.0 ## land area (m2), from the height map


func _ready() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		push_error("This simulation needs the Forward+ or Mobile renderer (RenderingDevice).")


func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(_free_rt)


func build(load_data := {}) -> void:
	ready_to_run = false
	if agent_multimesh == null:
		agent_multimesh = MultiMesh.new()
		agent_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		agent_multimesh.use_colors = true
		agent_multimesh.use_custom_data = true
		agent_multimesh.mesh = Meshes.creature()
		agent_multimesh.instance_count = MAX_VIS
		agent_multimesh.custom_aabb = AABB(Vector3(-1e6, -1000, -1e6), Vector3(2e6, 3000, 2e6))
	var instances := RenderingServer.multimesh_get_buffer_rd_rid(agent_multimesh.get_rid())
	if plant_multimeshes.is_empty():
		for mesh in [Meshes.grass_tussock(), Meshes.flower_plant(), Meshes.bush(), Meshes.tree()]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = MAX_PVIS
			mm.custom_aabb = AABB(Vector3(-1e6, -1000, -1e6), Vector3(2e6, 3000, 2e6))
			plant_multimeshes.append(mm)
	var plant_instances: Array[RID] = []
	for mm in plant_multimeshes:
		plant_instances.append(RenderingServer.multimesh_get_buffer_rd_rid(mm.get_rid()))
	RenderingServer.call_on_render_thread(_build_rt.bind(capacity, world_size, cell_size, instances,
			plant_capacity, plant_instances))
	if load_data.is_empty():
		reset()
	else:
		_start_loaded(load_data)


## Switch between the 2D overview (whole ticks per frame, 2D dots) and the 3D
## explorer (ticks split over frames, creatures around the player). Takes effect
## at once; a tick already in progress finishes with the chunking it started with.
func set_view(three_d: bool) -> void:
	explorer = three_d
	think_chunks = 4 if three_d else 1
	field_interval = 6 if three_d else 1
	phase_budget = 0
	_pending_cmd = {}
	player.target = -1
	player.inspect_tracked = false


func reset() -> void:
	tick = 0
	_think_done = 0
	_queue.clear()
	_pending_cmd = {}
	_last_stats_tick = 0
	_last_stats_msec = Time.get_ticks_msec()
	heights = PackedFloat32Array()
	RenderingServer.call_on_render_thread(_init_rt.bind(_push_constants(0)))
	ready_to_run = true
	restarted.emit()


## 3D: run a player command at the start of the next tick.
func send_command(cmd: int, spawn_n := 0) -> void:
	_pending_cmd = {"cmd": cmd, "spawn_n": mini(spawn_n, MAX_SPAWN)}


func _process(_delta: float) -> void:
	if not ready_to_run or _saving != "":
		return
	_frame += 1
	var budget := phase_budget if explorer else (0 if paused else steps_per_frame * think_chunks)
	var max_sort_steps := 1 if explorer else SORT_STEPS
	var phases: Array[Dictionary] = []
	var sort_steps := 0
	while true:
		if _queue.is_empty():
			if budget <= 0:
				break
			_plan_tick()
		var ph: Dictionary = _queue[0]
		if ph.kind == "sort" or ph.kind == "psort":
			if sort_steps >= max_sort_steps:
				break
			sort_steps += 1
			if ph.kind == "psort":
				_psort_busy = ph.step < PLANT_SORT_STEPS - 1
		else:
			if budget <= 0:
				break
			budget -= 1
			_think_done += 1
			_last_chunk = ph.chunk
		phases.append(_queue.pop_front())
	phase_budget = budget if explorer else 0

	var player_bytes := _player_bytes(phases, budget > 0)
	var want_stats := not _stats_pending and _frame % stats_interval == 0
	_stats_pending = _stats_pending or want_stats
	var want_readback := explorer and not _readback_pending
	_readback_pending = _readback_pending or want_readback
	var render_field := _frame % field_interval == 0
	var render_plants := explorer and not _psort_busy and not phases.any(
			func(ph: Dictionary) -> bool: return ph.kind == "psort")
	RenderingServer.call_on_render_thread(_frame_rt.bind(
			phases, _push_constants(tick), want_stats, player_bytes, want_readback, render_field, render_plants))


# ---------------------------------------------------------------------------
# Saving and loading worlds
# ---------------------------------------------------------------------------

## Save the whole world (live agents with genomes and brains, plants, carrion,
## settings) to a compressed file. The world pauses for the few frames it takes;
## `saved` is emitted when the file is written.
func save_world(path: String) -> void:
	if _saving != "" or not ready_to_run:
		return
	_saving = path
	_save_blobs = {}
	# Start on a fresh frame: callers may be inside a readback callback (e.g. a
	# stats signal), where new readbacks would get the wrong data.
	await get_tree().process_frame
	# Finish the tick in progress first, so the snapshot is between ticks.
	while not _queue.is_empty():
		await get_tree().process_frame
		_run_pending_phases()
	RenderingServer.call_on_render_thread(_save_rt.bind(tick))


func _run_pending_phases() -> void:
	var phases: Array[Dictionary] = []
	while not _queue.is_empty():
		var ph: Dictionary = _queue.pop_front()
		if ph.kind == "think":
			_think_done += 1
		phases.append(ph)
	RenderingServer.call_on_render_thread(_frame_rt.bind(
			phases, _push_constants(tick), false, _player_bytes([], false), false, false, false))


func _save_rt(t: int) -> void:
	# Compact the live agents to [0, N) with a full spatial sort. The write grid
	# of the last finished tick holds them all (or grid 0 before the first tick).
	var parity := ((t - 1) & 1) if t > 0 else 1
	for step in PLANT_SORT_STEPS:
		_plant_sort_step_rt(_push_constants(t), step)
	for step in SORT_STEPS:
		_sort_step_rt(_push_constants(t), parity, step)
	_rd.buffer_get_data_async(_buffers.counters, _on_save_counters)


func _on_save_counters(data: PackedByteArray) -> void:
	var n := data.decode_s32(6 * 4)
	var np := data.decode_s32(21 * 4)
	_save_blobs["n"] = n
	_save_blobs["np"] = np
	var cells := world_size * world_size
	var reads := {
		"agents": n * AGENT_BYTES, "genes": n * GENES * 4, "w1": n * W1_WORDS * 4,
		"w2": n * W2_WORDS * 4, "meat": cells * 4, "plant_a": np * 16, "plant_b": np * 16,
	}
	_save_blobs["pending"] = reads.keys()
	_save_blobs["sizes"] = reads
	# One buffer at a time: overlapping large async downloads can come back mixed
	# up (part of one buffer's data in another's). And requesting a read from
	# inside a readback callback misbehaves, so each goes out on the next frame.
	_request_next_save_read.call_deferred()


func _request_next_save_read() -> void:
	var k: String = _save_blobs.pending[0]
	var size: int = _save_blobs.sizes[k]
	RenderingServer.call_on_render_thread(func() -> void:
		if size == 0:
			_on_save_blob.call_deferred(PackedByteArray(), k)
		else:
			_rd.buffer_get_data_async(_buffers[k], _on_save_blob.bind(k), 0, size))


func _on_save_blob(data: PackedByteArray, key: String) -> void:
	_save_blobs[key] = data
	_save_blobs.pending.erase(key)
	if not _save_blobs.pending.is_empty():
		_request_next_save_read.call_deferred()
		return
	if _saving == _GROW_SNAPSHOT:
		_finish_grow.call_deferred() # not inside a readback callback (see above)
		return
	DirAccess.make_dir_recursive_absolute(_saving.get_base_dir())
	var f := FileAccess.open_compressed(_saving, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("Cannot write " + _saving)
	else:
		f.store_var(save_header(_save_blobs.n, _save_blobs.np))
		for k in SAVE_BLOBS:
			var blob: PackedByteArray = _save_blobs[k]
			f.store_64(blob.size())
			f.store_buffer(blob)
		f.close()
	var path := _saving
	_saving = ""
	_save_blobs = {}
	saved.emit(path)


const SAVE_BLOBS := ["agents", "genes", "w1", "w2", "meat", "plant_a", "plant_b"]


## Enlarge the agent and/or plant storage without interrupting the world: take
## an in-memory snapshot (like a save) and rebuild the buffers around it.
func grow(new_capacity: int, new_plant_capacity: int) -> void:
	if _saving != "" or not ready_to_run:
		return
	_growing = true
	set_meta("grow_to", [new_capacity, new_plant_capacity])
	save_world(_GROW_SNAPSHOT)


func _finish_grow() -> void:
	var data := {"header": save_header(_save_blobs.n, _save_blobs.np)}
	for k in SAVE_BLOBS:
		data[k] = _save_blobs[k]
	var to: Array = get_meta("grow_to")
	print("Storage grows: agents %d -> %d, plants %d -> %d (snapshot: %d agents, %d plants, %d bytes of plants)" % [
			capacity, to[0], plant_capacity, to[1], _save_blobs.n, _save_blobs.np, _save_blobs.plant_a.size()])
	capacity = to[0]
	plant_capacity = to[1]
	_saving = ""
	_save_blobs = {}
	build(data)


## Called with each stats read: grow the storage when a population nears it.
func _check_growth(alive: int, plants: int) -> void:
	if _saving != "" or not ready_to_run:
		return
	var cap := capacity
	var pcap := plant_capacity
	if alive > capacity * GROW_AT and capacity < MAX_CAPACITY:
		cap = mini(ceili(capacity * 1.5 / 50_000.0) * 50_000, MAX_CAPACITY)
	if plants > plant_capacity * GROW_AT and plant_capacity < MAX_PLANT_CAPACITY:
		pcap = mini(ceili(plant_capacity * 1.5 / 500_000.0) * 500_000, MAX_PLANT_CAPACITY)
	if cap != capacity or pcap != plant_capacity:
		grow(cap, pcap)


func save_header(alive: int, plants: int) -> Dictionary:
	return {
		"magic": SAVE_MAGIC, "version": SAVE_VERSION, "tick": tick, "alive": alive, "plants": plants,
		"capacity": capacity, "plant_capacity": plant_capacity, "world": world_size,
		"cell": cell_size, "seed": seed_value,
		"brain": brain_mode, "params": params.duplicate(),
		"time": Time.get_datetime_string_from_system(false, true),
	}


## Header of a saved world (empty if the file is not one).
static func read_header(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var h: Variant = f.get_var()
	if not (h is Dictionary) or h.get("magic", "") != SAVE_MAGIC or h.get("version", 0) != SAVE_VERSION:
		return {}
	return h


## Load a saved world (rebuilding the GPU buffers for its size). Returns false if
## the file cannot be read.
func load_world(path: String) -> bool:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var h: Variant = f.get_var()
	if not (h is Dictionary) or h.get("magic", "") != SAVE_MAGIC:
		return false
	if h.get("version", 0) != SAVE_VERSION:
		return false
	var data := {"header": h}
	for k in SAVE_BLOBS:
		var size := f.get_64()
		data[k] = f.get_buffer(size)
	capacity = h.capacity
	plant_capacity = h.plant_capacity
	world_size = h.world
	cell_size = h.cell
	seed_value = h.seed
	brain_mode = h.brain
	for k in h.params:
		params[k] = h.params[k]
	build(data)
	return true


func _start_loaded(data: Dictionary) -> void:
	var h: Dictionary = data.header
	tick = h.tick
	_think_done = 0
	_queue.clear()
	_pending_cmd = {}
	_last_stats_tick = tick
	_last_stats_msec = Time.get_ticks_msec()
	heights = PackedFloat32Array()
	RenderingServer.call_on_render_thread(_load_rt.bind(data, _push_constants(tick)))
	ready_to_run = true
	if _growing:
		_growing = false
		grown.emit(capacity, plant_capacity)
	else:
		restarted.emit()


func _load_rt(data: Dictionary, pc: PackedByteArray) -> void:
	if _shaders.is_empty():
		return
	var n: int = data.header.alive
	# Terrain (fertility, height) comes back from the seed; then the saved state.
	var cl := _rd.compute_list_begin()
	_dispatch(cl, "INIT_FIELD", world_size * world_size, pc)
	_rd.compute_list_end()
	# Everything past the saved plants must read as dead. Clear only that part:
	# clearing a range and then uploading into it can lose part of the upload.
	var saved_plants := int(data.header.plants) * 16
	if plant_capacity * 16 > saved_plants:
		_rd.buffer_clear(_buffers.plant_a, saved_plants, plant_capacity * 16 - saved_plants)
		_rd.buffer_clear(_buffers.plant_b, saved_plants, plant_capacity * 16 - saved_plants)
	for k in SAVE_BLOBS:
		var blob: PackedByteArray = data[k]
		if blob.size() > 0:
			_rd.buffer_update(_buffers[k], 0, blob.size(), blob)
	_rd.buffer_clear(_buffers.damage, 0, capacity * 4)
	_rd.buffer_clear(_buffers.gift, 0, capacity * 4)
	_rd.buffer_clear(_buffers.prev, 0, capacity * 16)
	_rd.buffer_clear(_buffers.carry, 0, capacity * 16)
	var counters := PackedByteArray()
	counters.resize(COUNTER_WORDS * 4)
	counters.encode_s32(6 * 4, n)
	counters.encode_s32(10 * 4, -1)
	counters.encode_s32(11 * 4, -1)
	counters.encode_s32(20 * 4, int(data.header.plants))
	_rd.buffer_update(_buffers.counters, 0, counters.size(), counters)
	# Agents [0, n) are alive: rebuild the free stack and register them in the
	# grid the next tick reads (grid tick & 1 is the write grid of parity 1 - that).
	var parity := 1 - (int(data.header.tick) & 1)
	cl = _rd.compute_list_begin()
	_dispatch(cl, "SORT_TAIL", capacity, pc, parity)
	_dispatch(cl, "CLEAR_GRID_W", _bucket_count(), pc, parity)
	_dispatch(cl, "REGISTER", capacity, pc, parity)
	_rd.compute_list_end()
	# Plants: rebuild the index, free stack and canopy map.
	for step in PLANT_SORT_STEPS:
		_plant_sort_step_rt(pc, step)
	cl = _rd.compute_list_begin()
	_dispatch(cl, "P_COVER_ADD", plant_capacity, pc)
	_dispatch(cl, "RENDER_FIELD", world_size * world_size, pc)
	if not explorer:
		_dispatch(cl, "RENDER_AGENTS", capacity, pc)
	_rd.compute_list_end()
	_rd.buffer_get_data_async(_buffers.height, _on_height_read)


func _plan_tick() -> void:
	var chunk := ceili(float(capacity) / think_chunks)
	for c in think_chunks:
		var pc := _push_constants(tick, c * chunk, chunk if think_chunks > 1 else 0)
		_queue.append({"kind": "think", "tick": tick, "chunk": c, "chunks": think_chunks, "pc": pc})
	var interval := SORT_INTERVAL_3D if explorer else SORT_INTERVAL
	if tick % interval == interval - 1:
		for s in SORT_STEPS:
			_queue.append({"kind": "sort", "tick": tick, "step": s, "pc": _push_constants(tick)})
	if tick % PLANT_SORT_INTERVAL == PLANT_SORT_INTERVAL - 1:
		for s in PLANT_SORT_STEPS:
			_queue.append({"kind": "psort", "tick": tick, "step": s, "pc": _push_constants(tick)})
	tick += 1


func _player_bytes(phases: Array[Dictionary], behind: bool) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(PLAYER_BYTES)
	if not explorer:
		return b # all zero: no player, no command, 2D field colours
	var p: Vector2 = player.pos
	# Interpolation clock, in ticks: the last THINK phase that ran started at
	# last_chunk / chunks of its tick. It stays below 1 so that, while waiting
	# (e.g. during a sort step), chunk-0 agents hold at the end of their motion
	# instead of wrapping back to its start.
	var frac := 0.999 if behind else clampf(phase_fraction, 0.0, 0.999)
	var phase := (mini(_last_chunk, think_chunks - 1) + frac) / think_chunks
	b.encode_float(0, p.x)
	b.encode_float(4, p.y)
	b.encode_float(8, phase)
	b.encode_float(12, player.vis_radius)
	b.encode_u32(16, player.presence)
	b.encode_u32(20, player.presence_pheno)
	# A command runs at the next tick start that happens this frame.
	for ph in phases:
		if not _pending_cmd.is_empty() and ph.kind == "think" and ph.chunk == 0:
			b.encode_u32(24, _pending_cmd.cmd)
			b.encode_u32(28, ph.tick & 0xffffffff)
			b.encode_u32(36, _pending_cmd.spawn_n)
			_pending_cmd = {}
			break
	b.encode_u32(32, player.target if player.target >= 0 else 0xffffffff)
	var tp: Vector2 = player.target_pos
	b.encode_float(40, tp.x)
	b.encode_float(44, tp.y)
	b.encode_u32(48, 1 if player.inspect_tracked else 0)
	b.encode_float(52, player.near_radius)
	b.encode_float(56, player.speed)
	b.encode_u32(60, 1)
	b.encode_u32(64, think_chunks)
	return b


# ---------------------------------------------------------------------------
# Render-thread work
# ---------------------------------------------------------------------------

func _build_rt(cap: int, world: int, cell: float, instances: RID, pcap: int, plant_instances: Array[RID]) -> void:
	_free_rt()
	var src_file := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if src_file == null:
		push_error("Cannot open " + SHADER_PATH)
		return
	var code := src_file.get_as_text()

	var cells := world * world
	var bucket := bucket_size(world, cell)
	var buckets := (world / bucket) * (world / bucket)
	var slots := slots_per_bucket(world, cell)
	var zero_player := PackedByteArray()
	zero_player.resize(PLAYER_BYTES)
	_buffers = {
		"agents": _rd.storage_buffer_create(cap * AGENT_BYTES),
		"genes": _rd.storage_buffer_create(cap * GENES * 4),
		"w1": _rd.storage_buffer_create(cap * W1_WORDS * 4),
		"w2": _rd.storage_buffer_create(cap * W2_WORDS * 4),
		"count0": _rd.storage_buffer_create(buckets * 4),
		"slot0": _rd.storage_buffer_create(buckets * slots * 16),
		"count1": _rd.storage_buffer_create(buckets * 4),
		"slot1": _rd.storage_buffer_create(buckets * slots * 16),
		"plant_a": _rd.storage_buffer_create(pcap * 16),
		"meat": _rd.storage_buffer_create(cells * 4),
		"fert": _rd.storage_buffer_create(cells * 4),
		"damage": _rd.storage_buffer_create(cap * 4),
		"free_stack": _rd.storage_buffer_create(cap * 4),
		"counters": _rd.storage_buffer_create(COUNTER_WORDS * 4),
		"stats": _rd.storage_buffer_create(STATS_WORDS * 4),
		# Sort scratch: tmp must hold the largest per-agent buffer (w1) or plant buffer.
		"tmp": _rd.storage_buffer_create(maxi(cap * maxi(W1_WORDS, maxi(GENES, AGENT_BYTES / 4)) * 4, pcap * 16)),
		"perm": _rd.storage_buffer_create(cap * 4),
		"offsets": _rd.storage_buffer_create(maxi(buckets, cells) * 4),
		"block_sums": _rd.storage_buffer_create(maxi(maxi(buckets, cells) / 256, 1) * 4),
		"lists": _rd.storage_buffer_create((cap + cap / 8) * 4),
		"height": _rd.storage_buffer_create(cells * 4),
		"player": _rd.storage_buffer_create(PLAYER_BYTES, zero_player),
		"readback": _rd.storage_buffer_create(READBACK_WORDS * 4),
		"plant_b": _rd.storage_buffer_create(pcap * 16),
		"cover": _rd.storage_buffer_create(cells * 3 * 4),
		"prev": _rd.storage_buffer_create(cap * 16),
		"pcell": _rd.storage_buffer_create(cells * 8),
		"pperm": _rd.storage_buffer_create(pcap * 4),
		"pfree": _rd.storage_buffer_create(pcap * 4),
		"plists": _rd.storage_buffer_create((pcap / PSTRIDE + 1024) * 4),
		"carry": _rd.storage_buffer_create(cap * 16),
		"pcount": _rd.storage_buffer_create(cells * 4),
		"gift": _rd.storage_buffer_create(cap * 4),
		"scent": _rd.storage_buffer_create(cells * 4),
	}

	# Binding order: 0..14 grid-parity dependent, 15 view image, 16.. extras.
	var order := [["agents", "genes", "w1", "w2", "count0", "slot0", "count1", "slot1", "plant_a",
			"meat", "fert", "damage", "free_stack", "counters", "stats"], []]
	order[1] = order[0].duplicate()
	order[1][4] = "count1"
	order[1][5] = "slot1"
	order[1][6] = "count0"
	order[1][7] = "slot0"
	# Bindings 16..37 (26 was the old plant image; now the canopy map).
	var extras := [_buffers.tmp, _buffers.perm, _buffers.offsets, _buffers.block_sums, _buffers.lists,
			_buffers.height, _buffers.player, instances, _buffers.readback, _buffers.plant_b,
			_buffers.cover, _buffers.prev, _buffers.pcell, _buffers.pperm, _buffers.pfree,
			_buffers.plists, _buffers.carry, plant_instances[0], plant_instances[1],
			plant_instances[2], plant_instances[3], _buffers.pcount, _buffers.gift, _buffers.scent]

	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.width = world
	fmt.height = world
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
			| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
			| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	_view_tex = _rd.texture_create(fmt, RDTextureView.new())
	texture.texture_rd_rid = _view_tex

	var uniforms: Array = [[], []]
	for parity in 2:
		for b in order[parity].size():
			uniforms[parity].append(_storage_uniform(b, _buffers[order[parity][b]]))
		var img := RDUniform.new()
		img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		img.binding = 15
		img.add_id(_view_tex)
		uniforms[parity].append(img)
		for e in extras.size():
			uniforms[parity].append(_storage_uniform(16 + e, extras[e]))

	var header := "#version 450\n#define CAPACITY %d\n#define WORLD %d\n#define CELL %.4f\n#define BUCKET %d\n#define SLOTS %d\n#define MAX_VIS %d\n#define MAX_NEAR %d\n" % [
			cap, world, cell, bucket, slots, MAX_VIS, MAX_NEAR]
	header += "#define PCAP %d\n#define PINIT %d\n#define MAX_PVIS %d\n#define PLANT_VIEW %.1f\n" % [
			pcap, mini(initial_plants, pcap), MAX_PVIS, PLANT_VIEW]
	for k in KERNELS:
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = header + "#define K_%s\n" % k + code
		var spirv := _rd.shader_compile_spirv_from_source(source)
		if spirv.compile_error_compute != "":
			push_error("Kernel %s failed to compile:\n%s" % [k, spirv.compile_error_compute])
			return
		var shader := _rd.shader_create_from_spirv(spirv, "abm_" + k)
		_shaders[k] = shader
		_pipelines[k] = _rd.compute_pipeline_create(shader)
		if not _pipelines[k].is_valid():
			push_error("Pipeline failed: " + k)
		for parity in 2:
			_sets[parity][k] = _rd.uniform_set_create(uniforms[parity], shader, 0)


func _storage_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u


## Buckets of the spatial hash are this many cells wide. The 3x3 bucket scan
## covers at least one bucket in every direction, so buckets should span the
## longest vision; on fine grids (small cells) they are capped at 4 cells and
## vision is limited to that. At most 1024^2 buckets.
static func bucket_size(world: int, cell: float) -> int:
	var b := 2
	while b < 4 and b * cell < MAX_VISION_M:
		b *= 2
	return maxi(b, world / 1024)


## Agents a bucket can list (more are counted but invisible to neighbours).
static func slots_per_bucket(world: int, cell: float) -> int:
	var b := bucket_size(world, cell)
	return 8 if b >= 4 and (world / b) * (world / b) <= 512 * 512 else 4


func _init_rt(pc: PackedByteArray) -> void:
	if _shaders.is_empty():
		return
	var cl := _rd.compute_list_begin()
	_dispatch(cl, "INIT_FIELD", world_size * world_size, pc)
	_dispatch(cl, "INIT_AGENTS", capacity, pc)
	_dispatch(cl, "INIT_PLANTS", plant_capacity, pc)
	_rd.compute_list_end()
	_rd.buffer_clear(_buffers.prev, 0, capacity * 16)
	cl = _rd.compute_list_begin()
	_dispatch(cl, "REGISTER", capacity, pc, 1) # parity 1 writes grid 0, which tick 0 reads
	_rd.compute_list_end()
	for step in SORT_STEPS:
		_sort_step_rt(pc, 1, step)
	for step in PLANT_SORT_STEPS:
		_plant_sort_step_rt(pc, step)
	cl = _rd.compute_list_begin()
	_dispatch(cl, "RENDER_FIELD", world_size * world_size, pc)
	if not explorer:
		_dispatch(cl, "RENDER_AGENTS", capacity, pc)
	_rd.compute_list_end()
	_rd.buffer_get_data_async(_buffers.height, _on_height_read)


## One step of the counting sort of all agent storage by grid bucket. The steps
## must run in order, between ticks, once the write grid of `parity` holds every
## live agent (end of a tick, or after REGISTER).
func _sort_step_rt(pc: PackedByteArray, parity: int, step: int) -> void:
	var cl := _rd.compute_list_begin()
	match step:
		0:
			var buckets := _bucket_count()
			_dispatch(cl, "SCAN1", buckets, pc, parity)
			_dispatch(cl, "SCAN2", 256, pc, parity)
			_dispatch(cl, "SCAN3", buckets, pc, parity)
			_dispatch(cl, "PERM", capacity, pc, parity)
			_rd.compute_list_end()
			return
		1: _dispatch(cl, "SCATTER_GENES", capacity * GENES, pc, parity)
		2: _dispatch(cl, "SCATTER_W1", capacity * W1_WORDS, pc, parity)
		3:
			# Previous poses first (for smooth 3D motion), then the output layer.
			_dispatch(cl, "SCATTER_PREV", capacity, pc, parity)
			_rd.compute_list_end()
			_rd.buffer_copy(_buffers.tmp, _buffers.prev, 0, 0, capacity * 16)
			cl = _rd.compute_list_begin()
			_dispatch(cl, "SCATTER_CARRY", capacity, pc, parity)
			_rd.compute_list_end()
			_rd.buffer_copy(_buffers.tmp, _buffers.carry, 0, 0, capacity * 16)
			cl = _rd.compute_list_begin()
			_dispatch(cl, "SCATTER_W2", capacity * W2_WORDS, pc, parity)
		4: _dispatch(cl, "SCATTER_AGENTS", capacity, pc, parity)
	_rd.compute_list_end()
	var target: String = ["", "genes", "w1", "w2", "agents"][step]
	var words: int = [0, GENES, W1_WORDS, W2_WORDS, AGENT_BYTES / 4][step]
	_rd.buffer_copy(_buffers.tmp, _buffers[target], 0, 0, capacity * words * 4)
	if step == 4:
		cl = _rd.compute_list_begin()
		_dispatch(cl, "SORT_TAIL", capacity, pc, parity)
		_dispatch(cl, "CLEAR_GRID_W", _bucket_count(), pc, parity)
		_dispatch(cl, "REGISTER", capacity, pc, parity)
		_rd.compute_list_end()


## One step of the counting sort of the plants by cell, which also rebuilds the
## per-cell plant index. Runs between ticks.
func _plant_sort_step_rt(pc: PackedByteArray, step: int) -> void:
	var cells := world_size * world_size
	var cl := _rd.compute_list_begin()
	match step:
		0:
			_dispatch(cl, "P_CLEAR_INDEX", cells, pc)
			_dispatch(cl, "P_COUNT", plant_capacity, pc)
			_dispatch(cl, "PSCAN1", cells, pc)
			_dispatch(cl, "PSCAN2", 256, pc)
			_dispatch(cl, "PSCAN3", cells, pc)
			_dispatch(cl, "P_DEST", plant_capacity, pc)
		1:
			_dispatch(cl, "P_SCATTER_A", plant_capacity, pc)
			_dispatch(cl, "P_COPY_A", plant_capacity, pc)
			_dispatch(cl, "P_SCATTER_B", plant_capacity, pc)
			_dispatch(cl, "P_COPY_B", plant_capacity, pc)
		2:
			_dispatch(cl, "P_TAIL", plant_capacity, pc)
	_rd.compute_list_end()


func _bucket_count() -> int:
	var bw := world_size / bucket_size(world_size, cell_size)
	return bw * bw


func _frame_rt(phases: Array[Dictionary], render_pc: PackedByteArray, want_stats: bool,
		player_bytes: PackedByteArray, want_readback: bool, render_field: bool, render_plants := false) -> void:
	if _shaders.is_empty():
		return
	if profile:
		_print_profile()
		_rd.capture_timestamp("TICKS")
	_rd.buffer_update(_buffers.player, 0, player_bytes.size(), player_bytes)
	var cl := _rd.compute_list_begin()
	var sorted := false
	for ph in phases:
		var pc: PackedByteArray = ph.pc
		var parity: int = ph.tick & 1
		if ph.kind == "sort" or ph.kind == "psort":
			_rd.compute_list_end()
			if profile and not sorted:
				_rd.capture_timestamp("SORT")
			sorted = true
			if ph.kind == "sort":
				_sort_step_rt(pc, parity, ph.step)
			else:
				_plant_sort_step_rt(pc, ph.step)
			cl = _rd.compute_list_begin()
			continue
		if ph.chunk == 0:
			_dispatch(cl, "PLAYER", 1, pc, parity)
			_dispatch(cl, "SPAWN", MAX_SPAWN, pc, parity)
		_dispatch(cl, "THINK", pc.decode_u32(28) if ph.chunks > 1 else capacity, pc, parity)
		if ph.chunk == ph.chunks - 1:
			_dispatch(cl, "BIRTH", capacity / 8, pc, parity)
			_dispatch(cl, "FINALIZE", capacity, pc, parity)
			_dispatch(cl, "COMMIT", 1, pc, parity)
			_dispatch(cl, "PLANT_TICK", ceili(plant_capacity / float(PSTRIDE)), pc, parity)
			_dispatch(cl, "PLANT_FINALIZE", ceili(plant_capacity / float(PSTRIDE)) + 1024, pc, parity)
			_dispatch(cl, "PLANT_COMMIT", 1, pc, parity)
			_dispatch(cl, "FIELD", ceili(world_size * world_size / float(FIELD_STRIDE)), pc, parity)
	if profile:
		_rd.compute_list_end()
		_rd.capture_timestamp("RENDER")
		cl = _rd.compute_list_begin()
	if render_field:
		_dispatch(cl, "RENDER_FIELD", world_size * world_size, render_pc)
	if explorer:
		_dispatch(cl, "VIS_RESET", 1, render_pc)
		_dispatch(cl, "NEARBY", capacity, render_pc)
		_dispatch(cl, "CLEAR_INSTANCES", MAX_VIS, render_pc)
		if render_plants:
			var side := 2 * ceili(PLANT_VIEW / cell_size) + 1
			_dispatch(cl, "P_VIS_RESET", 4, render_pc)
			_dispatch(cl, "P_NEARBY", side * side, render_pc)
			_dispatch(cl, "P_CLEAR_INST", 4 * MAX_PVIS, render_pc)
		_dispatch(cl, "INSPECT", 1, render_pc)
	else:
		_dispatch(cl, "RENDER_AGENTS", capacity, render_pc)
	if want_stats:
		_dispatch(cl, "CLEAR_STATS", STATS_WORDS, render_pc)
		_dispatch(cl, "STATS", capacity, render_pc)
	_rd.compute_list_end()
	if profile:
		_rd.capture_timestamp("END")
	if want_stats:
		_rd.buffer_get_data_async(_buffers.stats, _on_stats_read)
	if want_readback:
		_rd.buffer_get_data_async(_buffers.readback, _on_readback)


var _profile_acc := {}
var _profile_frames := 0


func _print_profile() -> void:
	var n := _rd.get_captured_timestamps_count()
	if n < 2:
		return
	for t in n - 1:
		var k := _rd.get_captured_timestamp_name(t)
		var dt := (_rd.get_captured_timestamp_gpu_time(t + 1) - _rd.get_captured_timestamp_gpu_time(t)) / 1000.0
		_profile_acc[k] = _profile_acc.get(k, 0.0) + dt
	_profile_frames += 1
	if _profile_frames == 30:
		var parts := []
		for k in _profile_acc:
			parts.append("%s=%.2fms" % [k, _profile_acc[k] / _profile_frames / 1000.0])
		print("GPU per frame: ", " ".join(parts))
		_profile_acc.clear()
		_profile_frames = 0


func _dispatch(cl: int, kernel: String, count: int, pc: PackedByteArray, parity := 0) -> void:
	_rd.compute_list_bind_compute_pipeline(cl, _pipelines[kernel])
	_rd.compute_list_bind_uniform_set(cl, _sets[parity][kernel], 0)
	_rd.compute_list_set_push_constant(cl, pc, pc.size())
	var groups := ceili(count / 256.0)
	var gx := mini(groups, 32768)
	_rd.compute_list_dispatch(cl, gx, ceili(float(groups) / gx), 1)
	_rd.compute_list_add_barrier(cl)


func _free_rt() -> void:
	if _rd == null:
		return
	texture.texture_rd_rid = RID()
	for k in _shaders:
		_rd.free_rid(_shaders[k]) # also frees dependent pipelines and uniform sets
	if _view_tex.is_valid():
		_rd.free_rid(_view_tex)
	for k in _buffers:
		_rd.free_rid(_buffers[k])
	_shaders.clear()
	_pipelines.clear()
	_sets = [{}, {}]
	_buffers.clear()
	_view_tex = RID()


# ---------------------------------------------------------------------------

func _push_constants(t: int, chunk_offset := 0, chunk_count := 0) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(PC_BYTES)
	b.encode_u32(0, t & 0xffffffff)
	b.encode_u32(4, seed_value)
	b.encode_u32(8, brain_mode)
	b.encode_u32(12, color_mode)
	b.encode_u32(16, initial_pop)
	b.encode_u32(20, 1 if show_fields else 0)
	b.encode_u32(24, chunk_offset)
	b.encode_u32(28, chunk_count)
	var keys := ["plant_growth", "season_strength", "season_length", "mutation_scale",
			"metabolism", "move_cost", "attack_power", "meat_decay",
			"plant_efficiency", "meat_efficiency", "max_age", "mate_distance",
			"vision_cost", "detox_cost", "plant_mutation", "sun_energy", "compute_cost"]
	for k in keys.size():
		b.encode_float(32 + k * 4, params[keys[k]])
	return b


## Same packing as pack_pheno() in the shader.
static func pack_pheno(size: float, diet: float, hue: float, nn: int, speed: float) -> int:
	var s := int(clampf((size - 0.4) / 2.1, 0.0, 1.0) * 255.0 + 0.5)
	var d := int(clampf(diet, 0.0, 1.0) * 255.0 + 0.5)
	var h := int(fposmod(hue, 1.0) * 255.0 + 0.5) & 255
	var v := int(clampf((speed - 0.1) / 1.9, 0.0, 1.0) * 127.0 + 0.5)
	return s | (d << 8) | (h << 16) | ((nn & 1) << 24) | (v << 25)


static func unpack_pheno(p: int) -> Dictionary:
	return {
		"size": 0.4 + (p & 255) / 255.0 * 2.1,
		"diet": ((p >> 8) & 255) / 255.0,
		"hue": ((p >> 16) & 255) / 255.0,
		"neural": ((p >> 24) & 1) == 1,
	}


func _on_readback(data: PackedByteArray) -> void:
	_readback_pending = false
	readback_updated.emit(data)


var _flow_sums := {} ## key -> [energy, ticks] over the recent stats reads


## Per-tick average of an energy flow over roughly the last 64 ticks.
func _smooth(key: String, amount: float, dticks: int) -> float:
	var acc: Array = _flow_sums.get(key, [0.0, 0.0])
	var keep := clampf(1.0 - dticks / 64.0, 0.0, 1.0)
	acc = [acc[0] * keep + amount, acc[1] * keep + dticks]
	_flow_sums[key] = acc
	return acc[0] / maxf(acc[1], 1.0)


func _on_height_read(data: PackedByteArray) -> void:
	heights = data.to_float32_array()
	var land := 0
	for h in heights:
		if h > 0.0:
			land += 1
	land_m2 = land * cell_size * cell_size
	heightmap_ready.emit(heights)


func _on_stats_read(data: PackedByteArray) -> void:
	_stats_pending = false
	if data.size() < STATS_WORDS * 4:
		return
	var w := func(k: int) -> int: return data.decode_u32(k * 4)
	var alive: int = w.call(0)
	var n := maxf(alive, 1.0)
	var now := Time.get_ticks_msec()
	var dticks := tick - _last_stats_tick
	var tps := dticks * 1000.0 / maxf(now - _last_stats_msec, 1.0)
	_last_stats_tick = tick
	_last_stats_msec = now
	var actions := {}
	for a in ACTIONS.size():
		actions[ACTIONS[a]] = w.call(10 + a) if a < 7 else w.call(82 + a - 7)
	var hues := PackedInt32Array()
	for h in 32:
		hues.append(w.call(32 + h))
	var species := 0
	for h in hues:
		if h > alive * 0.01:
			species += 1
	stats_updated.emit({
		"tick": tick,
		"tps": tps,
		"alive": alive,
		"utility": w.call(1),
		"neural": w.call(2),
		"herbivores": w.call(3),
		"omnivores": w.call(4),
		"carnivores": w.call(5),
		"avg_energy": w.call(6) / 10.0 / n,
		"avg_size": w.call(7) / 1000.0 / n,
		"avg_speed": w.call(8) / 1000.0 / n,
		"max_generation": w.call(9),
		"actions": actions,
		"avg_diet": w.call(17) / 1000.0 / n,
		"avg_sense": w.call(18) / 1000.0 / n,
		"avg_repro": w.call(19) / 10.0 / n,
		"avg_mutation": w.call(20) / 1000.0 / n,
		"births_per_tick": w.call(21) / maxf(dticks, 1.0),
		"deaths_per_tick": w.call(22) / maxf(dticks, 1.0),
		"free_slots": w.call(23),
		"high_water": w.call(24),
		"avg_detox": w.call(25) / 1000.0 / maxf(w.call(3), 1.0),
		"plants": w.call(26) * w.call(73), # sampled every stride-th plant
		"plant_growth": w.call(27) / 1000.0 / maxf(w.call(26), 1.0),
		"plant_defence": w.call(28) / 1000.0 / maxf(w.call(26), 1.0),
		"plant_biomass": w.call(29) / 1000.0 / maxf(w.call(26), 1.0), # fill: biomass / max
		"plant_forms": [w.call(64), w.call(65), w.call(66), w.call(67)], # grass, flowers, bushes, trees
		"pollinated": w.call(68) / maxf(w.call(26), 1.0),
		"fruiting": w.call(69) / maxf(w.call(26), 1.0),
		"fruit_dispersed": w.call(70) / maxf(w.call(26), 1.0),
		"seed_size": w.call(71) / 1000.0 / maxf(w.call(26), 1.0),
		"flowering": w.call(72) / maxf(w.call(26), 1.0),
		"plant_births_per_tick": w.call(74) / maxf(dticks, 1.0),
		"plant_deaths_per_tick": w.call(75) / maxf(dticks, 1.0),
		# Energy flows per tick (see flow_add in sim.comp), smoothed: plants are
		# updated in 8 unequal slices, so single reads jump around.
		"sun_on_land": land_m2 * params.sun_energy,
		"sun_captured": _smooth("sun_captured", w.call(77) / 10.0, dticks),
		"plant_compute": _smooth("plant_compute", w.call(78) / 1000.0, dticks),
		"animal_intake": _smooth("animal_intake", w.call(79) / 100.0, dticks),
		"animal_compute": _smooth("animal_compute", w.call(80) / 100.0, dticks),
		"animal_upkeep": _smooth("animal_upkeep", w.call(81) / 100.0, dticks),
		"capacity": capacity,
		"plant_capacity": plant_capacity,
		# Social behaviour (see sim.comp): agents calling, hiding, displaying, young
		# following a parent, gifts to young and scent marks per tick.
		"calling": w.call(87),
		"hiding": w.call(88),
		"displaying": w.call(89),
		"young": w.call(90),
		"gifts_per_tick": w.call(91) / maxf(dticks, 1.0),
		"marks_per_tick": w.call(92) / maxf(dticks, 1.0),
		"hues": hues,
		"species": species,
	})
	# Deferred: a readback requested inside a readback callback gets the wrong data.
	_check_growth.call_deferred(alive, w.call(26) * w.call(73))
