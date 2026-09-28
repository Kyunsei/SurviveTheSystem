extends Node
## Unified life: one kind of organism whose organs (leaves, legs, eyes, brain,
## mouth) evolve. Kernels in res://shaders/life.comp.
##
## Every organism has a 48-byte core. Legs and brains come from separate pools,
## so only organisms that have them pay memory for them, and each pass only runs
## the organs an organism has: mobile organisms are updated every tick, sessile
## ones every 8 ticks. The GPU work an organism causes is paid in energy.
##
## A tick: CLEAR_GRID -> REGISTER (mobile organisms into the spatial hash) ->
## MOBILE -> SESSILE -> BIRTH -> FINALIZE -> COMMIT -> FIELD, and every
## SORT_INTERVAL ticks a counting sort of all organisms by cell (which also
## rebuilds the per-cell index sessile organisms are found by).

signal stats_updated(stats: Dictionary)
signal restarted
signal heightmap_ready(heights: PackedFloat32Array)

enum Start { PRIMORDIAL, SEEDED }

const SHADER_PATH := "res://shaders/life.comp"
const KERNELS := [
	"INIT_FIELD", "INIT_ORGS", "INIT_POOLS", "CLEAR_GRID", "REGISTER", "MOBILE", "SESSILE",
	"BIRTH", "FINALIZE", "COMMIT", "FIELD",
	"S_CLEAR", "S_COUNT", "S_SCAN1", "S_SCAN2", "S_SCAN3", "S_DEST",
	"S_SCATTER0", "S_SCATTER1", "S_SCATTER2", "S_SCATTER3", "S_SCATTERD",
	"S_COPY0", "S_COPY1", "S_COPY2", "S_COPY3", "S_COPYD",
	"S_TAIL", "S_COMMIT",
	"RENDER_FIELD", "RENDER_SESSILE", "RENDER_MOBILE", "CLEAR_STATS", "STATS",
	"NEAR_RESET", "NEAR_MOBILE", "NEAR_SESSILE", "CLEAR_INST", "FIRE",
]
const Rig := preload("res://scripts/life/rig.gd")
const MAX_VIS := 32768 ## 3D mobile organisms drawn at most
const MAX_SVIS := 49152 ## 3D sessile organisms drawn at most
const PLANT_VIEW := 260.0
const ACTIONS := ["eat", "hunt", "flee", "bask", "wander", "rest", "flock"]
const COLOR_MODES := ["Lifestyle", "Lineage", "Organs", "Energy", "Body plan"]
const STATS_WORDS := 256
const GUILDS := ["plants", "creepers", "traps", "sessile_feeders", "sessile_bare",
		"grazers", "predators", "omnivores", "mobile_leafy", "mobile_mouthless"]
const SWITCHES := ["anchorage", "axis", "symmetry", "growth", "actuation"]
const COUNTER_WORDS := 64
const PC_BYTES := 112
const PSTRIDE := 8
const SORT_INTERVAL := 16
const BRAIN_WORDS := 36
const SSTRIDE := 32
const MAX_VISION_M := 28.0

# Structural settings (need build()).
var world_size := 1024
var cell_size := 8.0
var capacity := 6_000_000 ## organisms
var leg_capacity := 1_000_000 ## mobile organisms at most (leg pool)
var brain_capacity := 500_000 ## organisms with a brain at most (brain pool)
# Run settings (applied on reset()).
var start_mode := Start.PRIMORDIAL
var initial := 2_000_000
var initial_mobile := 60_000 ## seeded start only
var seed_value := 1

var steps_per_frame := 1
var paused := false
var active := false ## runs only while its view is open
## 3D view: set by the explorer. Ticks are paced (ticks_per_second) and the
## organisms near viewer_pos (cells) are written into the MultiMeshes below.
var explorer := false
var ticks_per_second := 12.0
var viewer_pos := Vector2.ZERO
var view_radius := 180.0
var creature_multimesh: MultiMesh ## mobile organisms (body rig)
var sessile_multimesh: MultiMesh ## sessile organisms (same rig)
var _tick_acc := 0.0
var color_mode := 0
var show_fields := true
var stats_interval := 10
## Defaults from an automatic search (tools/life_experiment.py, 24 random
## settings x 2 seeds x both start modes, scored on diversity and robustness).
var params := {
	"sun_energy": 0.0014,
	"compute_cost": 0.0004,
	"season_strength": 0.35,
	"season_length": 4000.0,
	"mutation_scale": 1.6,
	"organ_jump": 0.0013,
	"metabolism": 0.012,
	"move_cost": 0.01,
	"attack_power": 0.6,
	"meat_decay": 0.004,
	"plant_efficiency": 0.45,
	"meat_efficiency": 1.05,
	"vision_cost": 0.0015,
	"detox_cost": 0.025,
	"max_age": 3000.0,
	"kin_distance": 0.19,
	"fire_rate": 0.03, ## fires started per tick
	"jc_strength": 0.28, ## seedlings fail near adults of their own lineage (per adult)
	"trample_strength": 1.27,
	"climate_strength": 0.75, ## how much being off the preferred temperature costs (0-1)
}
const PARAM_ORDER := ["sun_energy", "compute_cost", "season_strength", "season_length",
		"mutation_scale", "organ_jump", "metabolism", "move_cost", "attack_power", "meat_decay",
		"plant_efficiency", "meat_efficiency", "vision_cost", "detox_cost", "max_age", "kin_distance",
		"jc_strength", "trample_strength", "climate_strength"]

var texture := Texture2DRD.new()
var heights := PackedFloat32Array()
var land_m2 := 0.0
var tick := 0
var ready_to_run := false

var _rd: RenderingDevice
var _shaders := {}
var _pipelines := {}
var _sets := {}
var _buffers := {}
var _view_tex := RID()
var _frame := 0
var _stats_pending := false
var _last_stats_tick := 0
var _last_stats_msec := 0
var _flow_sums := {}
## Optional CSV log (one row per stats read), see log_to().
var _log: FileAccess
const LOG_KEYS := ["tick", "tps", "organisms", "sessile", "mobile", "plants", "creepers", "traps",
		"sessile_feeders", "sessile_bare", "grazers", "predators", "omnivores", "mobile_leafy",
		"mobile_mouthless", "with_brain", "with_eyes", "lineages_sessile", "lineages_mobile",
		"lineage_entropy", "bodyplan_diversity", "settled_per_tick", "uprooted_per_tick",
		"births_per_tick", "deaths_per_tick", "max_generation", "sun_captured", "mobile_intake",
		"sexual_births_per_tick"]


## Append one CSV row per stats read to `path` (headless experiments).
func log_to(path: String) -> void:
	_log = FileAccess.open(path, FileAccess.WRITE)
	if _log != null:
		_log.store_line(",".join(LOG_KEYS))


func _ready() -> void:
	_rd = RenderingServer.get_rendering_device()


func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(_free_rt)


func build() -> void:
	ready_to_run = false
	if creature_multimesh == null:
		var rig := Rig.build()
		creature_multimesh = _multimesh(rig, MAX_VIS)
		sessile_multimesh = _multimesh(rig, MAX_SVIS)
	var inst: Array[RID] = [RenderingServer.multimesh_get_buffer_rd_rid(creature_multimesh.get_rid()),
			RenderingServer.multimesh_get_buffer_rd_rid(sessile_multimesh.get_rid())]
	RenderingServer.call_on_render_thread(_build_rt.bind(capacity, leg_capacity, brain_capacity,
			world_size, cell_size, mini(initial, capacity), _initial_mobile(), inst))
	reset()


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-1e6, -1000, -1e6), Vector3(2e6, 3000, 2e6))
	return mm


func _initial_mobile() -> int:
	return 0 if start_mode == Start.PRIMORDIAL else mini(initial_mobile, mini(leg_capacity, brain_capacity))


## Start a new world. The initial counts are compiled into the shaders, so a
## different start rebuilds.
func reset() -> void:
	tick = 0
	_last_stats_tick = 0
	_last_stats_msec = Time.get_ticks_msec()
	_flow_sums = {}
	heights = PackedFloat32Array()
	RenderingServer.call_on_render_thread(_init_rt.bind(_push_constants(0)))
	ready_to_run = true
	restarted.emit()


func restart(mode: int) -> void:
	start_mode = mode as Start
	build()


func _process(_delta: float) -> void:
	if not ready_to_run or not active:
		return
	_frame += 1
	var ticks: Array[int] = []
	if explorer:
		# 3D: a steady pace, at most one tick per frame; phase interpolates motion.
		if not paused:
			_tick_acc += _delta * ticks_per_second
		if _tick_acc >= 1.0:
			_tick_acc = minf(_tick_acc - 1.0, 1.0)
			ticks.append(tick)
			tick += 1
	elif not paused:
		for s in steps_per_frame:
			ticks.append(tick)
			tick += 1
	var want_stats := not _stats_pending and _frame % stats_interval == 0
	_stats_pending = _stats_pending or want_stats
	var v := PackedByteArray()
	v.resize(32)
	v.encode_float(0, viewer_pos.x)
	v.encode_float(4, viewer_pos.y)
	v.encode_float(8, view_radius)
	v.encode_float(12, clampf(_tick_acc, 0.0, 1.0))
	v.encode_u32(16, 1 if explorer else 0)
	RenderingServer.call_on_render_thread(_frame_rt.bind(ticks, _push_constants(tick), want_stats, v))


# ---------------------------------------------------------------------------
# Render-thread work
# ---------------------------------------------------------------------------

static func bucket_size(world: int, cell: float) -> int:
	var b := 2
	while b < 4 and b * cell < MAX_VISION_M:
		b *= 2
	return maxi(b, world / 1024)


static func slots_per_bucket(world: int, cell: float) -> int:
	var b := bucket_size(world, cell)
	return 8 if b >= 4 and (world / b) * (world / b) <= 512 * 512 else 4


func _build_rt(cap: int, lcap: int, bcap: int, world: int, cell: float, n_init: int, n_mob: int, inst: Array[RID]) -> void:
	_free_rt()
	var src := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if src == null:
		push_error("Cannot open " + SHADER_PATH)
		return
	var code := src.get_as_text()
	var cells := world * world
	var bucket := bucket_size(world, cell)
	var slots := slots_per_bucket(world, cell)
	var nb := (world / bucket) * (world / bucket)
	var dead_max := cap / 4
	_buffers = {
		"core0": _rd.storage_buffer_create(cap * 16),
		"core1": _rd.storage_buffer_create(cap * 16),
		"core2": _rd.storage_buffer_create(cap * 16),
		"core3": _rd.storage_buffer_create(cap * 16),
		"damage": _rd.storage_buffer_create(cap * 4),
		"legs": _rd.storage_buffer_create(lcap * 16),
		"brains": _rd.storage_buffer_create(bcap * BRAIN_WORDS * 4),
		"grid_count": _rd.storage_buffer_create(nb * 4),
		"grid_slot": _rd.storage_buffer_create(nb * slots * 16),
		"fert": _rd.storage_buffer_create(cells * 4),
		"height": _rd.storage_buffer_create(cells * 4),
		"meat": _rd.storage_buffer_create(cells * 4),
		"cover": _rd.storage_buffer_create(cells * 12),
		"ofree": _rd.storage_buffer_create(cap * 4),
		"lfree": _rd.storage_buffer_create(lcap * 4),
		"bfree": _rd.storage_buffer_create(bcap * 4),
		"counters": _rd.storage_buffer_create(COUNTER_WORDS * 4),
		"stats": _rd.storage_buffer_create(STATS_WORDS * 4),
		"tmp": _rd.storage_buffer_create(cap * 16),
		"pperm": _rd.storage_buffer_create(cap * 4),
		"offsets": _rd.storage_buffer_create(cells * 4),
		"block_sums": _rd.storage_buffer_create(maxi(cells / 256, 1) * 4),
		"pcell": _rd.storage_buffer_create(cells * 8),
		"pcount": _rd.storage_buffer_create(cells * 4),
		"lists": _rd.storage_buffer_create((dead_max + lcap + bcap + cap / 8) * 4),
		"trample": _rd.storage_buffer_create(cells * 4),
		"litter": _rd.storage_buffer_create(cells * 4),
		"burn": _rd.storage_buffer_create(cells * 4),
		"legprev": _rd.storage_buffer_create(lcap * 8),
		"viewer": _rd.storage_buffer_create(32),
	}
	var order := ["core0", "core1", "core2", "damage", "legs", "brains", "grid_count", "grid_slot",
			"fert", "height", "meat", "cover", "ofree", "lfree", "bfree", "counters", "stats"]
	var order2 := ["tmp", "pperm", "offsets", "block_sums", "pcell", "pcount", "lists"]

	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.width = world
	fmt.height = world
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
			| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
			| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	_view_tex = _rd.texture_create(fmt, RDTextureView.new())
	texture.texture_rd_rid = _view_tex

	var uniforms: Array[RDUniform] = []
	for b in order.size():
		uniforms.append(_storage_uniform(b, _buffers[order[b]]))
	var img := RDUniform.new()
	img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	img.binding = 17
	img.add_id(_view_tex)
	uniforms.append(img)
	for b in order2.size():
		uniforms.append(_storage_uniform(18 + b, _buffers[order2[b]]))
	uniforms.append(_storage_uniform(25, _buffers.legprev))
	uniforms.append(_storage_uniform(26, _buffers.viewer))
	for b in inst.size(): # MultiMesh buffers: not ours to free
		uniforms.append(_storage_uniform(27 + b, inst[b]))
	uniforms.append(_storage_uniform(32, _buffers.core3))
	uniforms.append(_storage_uniform(33, _buffers.trample))
	uniforms.append(_storage_uniform(34, _buffers.litter))
	uniforms.append(_storage_uniform(35, _buffers.burn))

	var header := "#version 450\n#define OCAP %d\n#define LCAP %d\n#define BCAP %d\n#define WORLD %d\n#define CELL %.4f\n#define BUCKET %d\n#define SLOTS %d\n#define NINIT %d\n#define NMOB %d\n" % [
			cap, lcap, bcap, world, cell, bucket, slots, n_init, n_mob]
	for k in KERNELS:
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = header + "#define K_%s\n" % k + code
		var spirv := _rd.shader_compile_spirv_from_source(source)
		if spirv.compile_error_compute != "":
			push_error("Kernel %s failed to compile:\n%s" % [k, spirv.compile_error_compute])
			return
		var shader := _rd.shader_create_from_spirv(spirv, "life_" + k)
		_shaders[k] = shader
		_pipelines[k] = _rd.compute_pipeline_create(shader)
		_sets[k] = _rd.uniform_set_create(uniforms, shader, 0)


func _storage_uniform(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u


func _free_rt() -> void:
	if _rd == null:
		return
	texture.texture_rd_rid = RID()
	for k in _shaders:
		_rd.free_rid(_shaders[k])
	if _view_tex.is_valid():
		_rd.free_rid(_view_tex)
	for k in _buffers:
		_rd.free_rid(_buffers[k])
	_shaders.clear()
	_pipelines.clear()
	_sets.clear()
	_buffers.clear()
	_view_tex = RID()


func _init_rt(pc: PackedByteArray) -> void:
	if _shaders.is_empty():
		return
	var cl := _rd.compute_list_begin()
	_dispatch(cl, "INIT_FIELD", world_size * world_size, pc)
	_dispatch(cl, "INIT_ORGS", capacity, pc)
	_dispatch(cl, "INIT_POOLS", maxi(leg_capacity, brain_capacity), pc)
	_rd.compute_list_end()
	_rd.buffer_clear(_buffers.meat, 0, world_size * world_size * 4)
	_sort_rt(pc)
	_rd.buffer_get_data_async(_buffers.height, _on_height_read)


func _dispatch(cl: int, kernel: String, count: int, pc: PackedByteArray) -> void:
	_rd.compute_list_bind_compute_pipeline(cl, _pipelines[kernel])
	_rd.compute_list_bind_uniform_set(cl, _sets[kernel], 0)
	_rd.compute_list_set_push_constant(cl, pc, pc.size())
	var groups := maxi(ceili(count / 256.0), 1)
	var gx := mini(groups, 32768)
	_rd.compute_list_dispatch(cl, gx, ceili(float(groups) / gx), 1)
	_rd.compute_list_add_barrier(cl)


func _tick_rt(cl: int, pc: PackedByteArray) -> void:
	var nb := (world_size / bucket_size(world_size, cell_size)) ** 2
	_dispatch(cl, "CLEAR_GRID", nb, pc)
	_dispatch(cl, "REGISTER", leg_capacity, pc)
	_dispatch(cl, "MOBILE", leg_capacity, pc)
	_dispatch(cl, "SESSILE", ceili(capacity / float(PSTRIDE)), pc)
	_dispatch(cl, "BIRTH", capacity / 8, pc)
	_dispatch(cl, "FINALIZE", maxi(capacity / 4, maxi(leg_capacity, brain_capacity)), pc)
	_dispatch(cl, "COMMIT", 1, pc)
	_dispatch(cl, "FIELD", world_size * world_size / 4, pc)


## Counting sort of all organisms by cell, in one compute list (the copies back
## are compute passes, ordered by the barriers between dispatches).
func _sort_rt(pc: PackedByteArray) -> void:
	var cells := world_size * world_size
	var cl := _rd.compute_list_begin()
	_dispatch(cl, "S_CLEAR", cells, pc)
	_dispatch(cl, "S_COUNT", capacity, pc)
	_dispatch(cl, "S_SCAN1", cells, pc)
	_dispatch(cl, "S_SCAN2", 256, pc)
	_dispatch(cl, "S_SCAN3", cells, pc)
	_dispatch(cl, "S_DEST", capacity, pc)
	# core0 last: the scatters check it to find live organisms.
	for part in ["1", "2", "3", "D", "0"]:
		_dispatch(cl, "S_SCATTER" + part, capacity, pc)
		_dispatch(cl, "S_COPY" + part, capacity, pc)
	_dispatch(cl, "S_TAIL", capacity, pc)
	_dispatch(cl, "S_COMMIT", 1, pc)
	_rd.compute_list_end()


func _frame_rt(ticks: Array[int], render_pc: PackedByteArray, want_stats: bool, viewer: PackedByteArray) -> void:
	if _shaders.is_empty():
		return
	_rd.buffer_update(_buffers.viewer, 0, viewer.size(), viewer)
	for t in ticks:
		var pc := _push_constants(t)
		var cl := _rd.compute_list_begin()
		_tick_rt(cl, pc)
		# Fires: started at random in the dry half of each place's season (simplified:
		# the global season), more often with fire_rate.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, t])
		if rng.randf() < params.fire_rate:
			var r := rng.randf_range(20.0, 140.0)
			var fpc := pc.duplicate()
			var cx := rng.randf() * world_size
			var cy := rng.randf() * world_size
			fpc.encode_u32(20, (int(cx / world_size * 65536.0) & 0xffff) | ((int(cy / world_size * 65536.0) & 0xffff) << 16))
			fpc.encode_float(24, r)
			var side := 2 * ceili(r / cell_size) + 1
			_dispatch(cl, "FIRE", side * side, fpc)
		_rd.compute_list_end()
		if t % SORT_INTERVAL == SORT_INTERVAL - 1:
			_sort_rt(pc)
	var cl := _rd.compute_list_begin()
	if not explorer:
		_dispatch(cl, "RENDER_FIELD", world_size * world_size, render_pc)
		_dispatch(cl, "RENDER_SESSILE", capacity, render_pc)
		_dispatch(cl, "RENDER_MOBILE", leg_capacity, render_pc)
	else:
		if _frame % 6 == 0: # ground colours change slowly
			_dispatch(cl, "RENDER_FIELD", world_size * world_size, render_pc)
		var side := 2 * ceili(PLANT_VIEW / cell_size) + 1
		_dispatch(cl, "NEAR_RESET", 2, render_pc)
		_dispatch(cl, "NEAR_MOBILE", leg_capacity, render_pc)
		_dispatch(cl, "NEAR_SESSILE", side * side, render_pc)
		_dispatch(cl, "CLEAR_INST", MAX_VIS + MAX_SVIS, render_pc)
	if want_stats:
		_dispatch(cl, "CLEAR_STATS", STATS_WORDS, render_pc)
		_dispatch(cl, "STATS", maxi(leg_capacity, capacity / SSTRIDE), render_pc)
	_rd.compute_list_end()
	if want_stats:
		_rd.buffer_get_data_async(_buffers.stats, _on_stats_read)
	if explorer:
		_rd.buffer_get_data_async(_buffers.counters, _on_counters_read, 31 * 4, 2 * 4)


## Dev: find a live mobile organism; `found` gets its position in metres.
func find_mobile(found: Callable) -> void:
	RenderingServer.call_on_render_thread(func() -> void:
		_rd.buffer_get_data_async(_buffers.legs, func(d: PackedByteArray) -> void:
			var words := d.to_int32_array()
			for k in range(0, words.size(), 4):
				if words[k] != -1:
					_read_core0.call_deferred(words[k], found)
					return, 0, 4096 * 16))


func _read_core0(i: int, found: Callable) -> void:
	RenderingServer.call_on_render_thread(func() -> void:
		_rd.buffer_get_data_async(_buffers.core0, func(d: PackedByteArray) -> void:
			var packed := d.decode_u32(0)
			var p := (Vector2(packed & 0xffff, packed >> 16) + Vector2(0.5, 0.5)) * (world_size / 65536.0) * cell_size
			found.call_deferred(p), i * 16, 16))


## 3D: draw only as many instances as the GPU wrote (plus room to grow).
func _on_counters_read(data: PackedByteArray) -> void:
	if data.size() < 8 or creature_multimesh == null:
		return
	var n := data.decode_s32(0)
	creature_multimesh.visible_instance_count = mini(MAX_VIS, n + n / 8 + 256)
	var m := data.decode_s32(4)
	sessile_multimesh.visible_instance_count = mini(MAX_SVIS, m + m / 8 + 256)


func _push_constants(t: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(PC_BYTES)
	b.encode_u32(0, t & 0xffffffff)
	b.encode_u32(4, seed_value)
	b.encode_u32(8, start_mode)
	b.encode_u32(12, color_mode)
	b.encode_u32(16, 1 if show_fields else 0)
	for k in PARAM_ORDER.size():
		b.encode_float(32 + k * 4, params[PARAM_ORDER[k]])
	return b


# ---------------------------------------------------------------------------
# Readbacks
# ---------------------------------------------------------------------------

func _on_height_read(data: PackedByteArray) -> void:
	heights = data.to_float32_array()
	var land := 0
	for h in heights:
		if h > 0.0:
			land += 1
	land_m2 = land * cell_size * cell_size
	heightmap_ready.emit(heights)


func _smooth(key: String, amount: float, dticks: int) -> float:
	var acc: Array = _flow_sums.get(key, [0.0, 0.0])
	var keep := clampf(1.0 - dticks / 64.0, 0.0, 1.0)
	acc = [acc[0] * keep + amount, acc[1] * keep + dticks]
	_flow_sums[key] = acc
	return acc[0] / maxf(acc[1], 1.0)


func _on_stats_read(data: PackedByteArray) -> void:
	_stats_pending = false
	if data.size() < STATS_WORDS * 4:
		return
	var w := func(k: int) -> int: return data.decode_u32(k * 4)
	var now := Time.get_ticks_msec()
	var dticks := tick - _last_stats_tick
	var tps := dticks * 1000.0 / maxf(now - _last_stats_msec, 1.0)
	_last_stats_tick = tick
	_last_stats_msec = now
	var mobile: int = w.call(0)
	var nm := maxf(mobile, 1.0)
	var stride: int = w.call(31)
	var sessile: int = w.call(20) * stride
	var ns := maxf(w.call(20), 1.0)
	var actions := {}
	for a in ACTIONS.size():
		actions[ACTIONS[a]] = w.call(8 + a)
	var hues := PackedInt32Array()
	for h in 32:
		hues.append(w.call(64 + h))
	var species := 0
	for h in hues:
		if h > mobile * 0.02:
			species += 1
	var dt := maxf(dticks, 1.0)
	# Diversity: lineages (hue bins over 1 % of their group), entropy over all
	# 64 bins (sessile and mobile, each weighted by its share of the bins), and
	# body-plan diversity (mean standard deviation of the five switches).
	var s_hues := PackedInt32Array()
	var s_total := 0
	for h in 32:
		s_hues.append(w.call(128 + h))
		s_total += s_hues[h]
	var lin_s := 0
	var lin_m := 0
	var entropy := 0.0
	for h in 32:
		if s_hues[h] > s_total * 0.01:
			lin_s += 1
		if hues[h] > mobile * 0.01 and mobile > 20:
			lin_m += 1
		for v in [float(s_hues[h]) / maxf(s_total, 1.0), float(hues[h]) / maxf(mobile, 1.0)]:
			if v > 0.0:
				entropy -= 0.5 * v * log(v)
	var guilds := {}
	for gi in GUILDS.size():
		guilds[GUILDS[gi]] = w.call(160 + gi) * (stride if gi < 5 else 1)
	var nsw := maxf(w.call(180), 1.0)
	var div := 0.0
	var switches := {}
	for k in 5:
		var mean: float = w.call(170 + k) / 1000.0 / nsw
		var sq: float = w.call(175 + k) / 1000.0 / nsw
		switches[SWITCHES[k]] = mean
		div += sqrt(maxf(sq - mean * mean, 0.0)) / 5.0
	var st := {
		"tick": tick, "tps": tps,
		"organisms": mobile + sessile,
		"mobile": mobile,
		"mobile_plant_eaters": w.call(1),
		"mobile_carnivores": w.call(2),
		"mobile_with_leaves": w.call(3),
		"mobile_mouthless": w.call(4),
		"with_eyes": w.call(5),
		"with_brain": w.call(6),
		"avg_neurons": w.call(7) / maxf(w.call(6), 1.0),
		"actions": actions,
		"mobile_size": w.call(15) / 1000.0 / nm,
		"mobile_speed": w.call(16) / 1000.0 / nm,
		"mobile_sense": w.call(17) / 1000.0 / nm,
		"mobile_carni": w.call(18) / 1000.0 / nm,
		"mobile_photo": w.call(19) / 1000.0 / nm,
		"sessile": sessile,
		"sessile_leaves": w.call(21) * stride,
		"sessile_mouth": w.call(22) * stride,
		"sessile_traps": w.call(23) * stride,
		"sessile_no_leaves": w.call(30) * stride,
		"sessile_forms": [w.call(24), w.call(25), w.call(26), w.call(27)], # by height: <0.5, <2, <6 m, taller
		"sessile_size": w.call(28) / 1000.0 / ns,
		"sessile_photo": w.call(29) / 1000.0 / ns,
		"births_per_tick": w.call(32) / dt,
		"deaths_per_tick": w.call(33) / dt,
		"organism_hwm": w.call(34),
		"leg_hwm": w.call(35),
		"brain_hwm": w.call(36),
		"max_generation": w.call(37),
		"sun_on_land": land_m2 * params.sun_energy,
		"sun_captured": _smooth("sun", w.call(38) / 10.0, dticks),
		"sessile_compute": _smooth("scomp", w.call(39) / 1000.0, dticks),
		"sessile_upkeep": _smooth("supk", w.call(40) / 10.0, dticks),
		"mobile_intake": _smooth("mint", w.call(41) / 100.0, dticks),
		"mobile_compute": _smooth("mcomp", w.call(42) / 100.0, dticks),
		"mobile_upkeep": _smooth("mupk", w.call(43) / 100.0, dticks),
		# Organs gained / lost at birth, per tick (legs, brain, mouth, leaves).
		"gained": [w.call(44) / dt, w.call(46) / dt, w.call(48) / dt, w.call(50) / dt],
		"lost": [w.call(45) / dt, w.call(47) / dt, w.call(49) / dt, w.call(51) / dt],
		# Body plans and plant <-> animal transitions.
		"settled_per_tick": w.call(52) / dt, # mobile -> rooted during life (metamorphosis)
		"sexual_births_per_tick": w.call(98) / dt,
		"uprooted_per_tick": w.call(53) / dt, # rooted -> mobile during life
		"mobile_life_cycle": w.call(54),
		"sessile_life_cycle": w.call(55) * stride,
		"mobile_anchor": w.call(56) / 1000.0 / nm,
		"mobile_axis": w.call(57) / 1000.0 / nm,
		"mobile_radial": w.call(58) / 1000.0 / nm,
		"mobile_segments": w.call(59) / 1000.0 / nm,
		"sessile_actuation": w.call(60) / 1000.0 / ns,
		"sessile_axis": w.call(61) / 1000.0 / ns,
		"sessile_radial": w.call(62) / 1000.0 / ns,
		"sessile_creepers": w.call(63) * stride,
		"sessile_muscular": w.call(96) * stride,
		"mobile_upright": w.call(97),
		"hues": hues,
		"species": species,
		"guilds": guilds,
		"lineages_sessile": lin_s,
		"lineages_mobile": lin_m,
		"lineage_entropy": entropy,
		"bodyplan_diversity": div,
		"switches": switches,
	}
	st.merge(guilds)
	stats_updated.emit(st)
	if _log != null:
		var row := PackedStringArray()
		for k in LOG_KEYS:
			row.append(str(snappedf(float(st[k]), 0.0001)))
		_log.store_line(",".join(row))
		_log.flush()
