@tool
extends Node3D
class_name Spawner
## Place it in the world: while the simulation runs, it spawns agents of one species
## around itself, once or every N ticks (one tick = one simulation cycle).
##
##   mode ONCE:   `count` agents, start_delay ticks after the simulation starts
##   mode REPEAT: `count` agents every `interval` ticks (repeat_times rounds, 0 = forever)
##
## Agents appear at random inside the circle (`radius`), on the ground at this node's
## height, or on the walkable floor below if a NavWorld is assigned (never in walls).
## The circle is drawn in the editor. Ticks don't advance while the simulation is paused,
## so neither does the spawner.

signal spawned(species, indices: PackedInt32Array)

enum Mode { ONCE, REPEAT }

@export var alifemanager: AlifeManager
@export var sim_manager: SimulationManager
## Optional: spawn on its walkable floors only (and at their height).
@export var nav_world: NavWorld

@export_group("What")
@export var species_name := "BUGSHEEP"         # species_name of what to spawn
@export var count := 5                         # agents per spawn
## Starting energy (0 = the species' seed_energy).
@export var energy := 0.0
## Starting life cycle stage (0 = egg / seed / newborn).
@export var life_stage := 0

@export_group("When")
@export var mode := Mode.ONCE
## Wait until the simulation is ready (SimulationManager.init() done, species built, and
## the NavWorld's grid built if one is assigned) before counting start_delay.
@export var wait_for_ready := true
## Ticks to wait after the simulation is ready before the first spawn.
@export var start_delay := 0
## REPEAT: ticks between two spawns.
@export var interval := 600
## REPEAT: how many spawns in total (0 = forever).
@export var repeat_times := 0
## Skip a spawn while the species already has this many agents (0 = no limit).
@export var species_limit := 0
@export var enabled := true

@export_group("Where")
@export var radius := 3.0:
	set(v):
		radius = maxf(v, 0.0)
		_update_gizmo()
## Also draw the circle while the game runs (debug). It's flat: in control mode (bent
## planet view) it won't sit exactly on the ground.
@export var show_in_game := false:
	set(v):
		show_in_game = v
		_update_gizmo()

var spawns_done := 0                           # how many spawns so far
var _next_tick := -1                           # simulation tick of the next spawn (-1 = not set)
var sim_is_ready := false                      # true once the simulation was seen ready
var _gizmo := MeshInstance3D.new()


func _ready() -> void:
	add_to_group("between_ticks")
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_update_gizmo()


## Spawns `count` agents now (whatever the mode). Returns their indices.
func spawn_now() -> PackedInt32Array:
	var out := PackedInt32Array()
	var sp = _species()
	if sp == null:
		return out
	for k in count:
		if species_limit > 0 and sp.active_entity_count >= species_limit:
			break
		var pos = _random_spot()
		if pos == null:
			continue                               # no walkable spot found: skip this one
		var i: int = sp.free_indices[sp.free_indices.size() - 1] if sp.free_indices.size() > 0 \
				else sp.entity_count               # Build_New_Life uses this slot
		var before: int = sp.active_entity_count
		sp.Build_New_Life(pos, energy if energy > 0.0 else sp.seed_energy, life_stage)
		if sp.active_entity_count > before:
			out.append(i)
		else:
			break                                  # world full (maxLife)
	if not out.is_empty():
		spawned.emit(sp, out)
	return out


## Starts counting again (as if the simulation had just started).
func reset() -> void:
	spawns_done = 0
	_next_tick = -1
	sim_is_ready = false


## True when everything the spawner needs exists: simulation initialised and running,
## species built, and the NavWorld's grid ready (if one is assigned).
func _simulation_ready() -> bool:
	if sim_manager == null or alifemanager == null:
		return false
	if not sim_manager.running:
		return false
	if "is_ready" in sim_manager and not sim_manager.is_ready:
		return false
	if alifemanager.species_array.is_empty():
		return false
	if nav_world != null and nav_world.enabled and (not nav_world.is_built or nav_world.grid == null):
		return false                               # the grid is still being built/loaded
	return true


## Called by SimulationManager right before each tick, when the species arrays are free
## (also with the pipelined tick). Spawning from _process could hit a running tick.
func between_ticks(delta: float) -> void:
	_step(delta)


func _step(_delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or sim_manager == null or alifemanager == null:
		return
	if not multiplayer.is_server():
		return                                 # network client: the host spawns, we mirror
	if not sim_is_ready:
		if wait_for_ready and not _simulation_ready():
			return                                 # not ready yet: don't start counting
		if not wait_for_ready and alifemanager.species_array.is_empty():
			return
		sim_is_ready = true
		_next_tick = -1                            # start_delay counts from now
	if mode == Mode.ONCE and spawns_done >= 1:
		return
	if mode == Mode.REPEAT and repeat_times > 0 and spawns_done >= repeat_times:
		return

	var tick: int = sim_manager.total_time
	if _next_tick < 0:
		_next_tick = tick + maxi(start_delay, 0)   # first time: wait start_delay ticks
	if tick < _next_tick:
		return

	spawn_now()
	spawns_done += 1
	_next_tick = tick + maxi(interval, 1)


func _species():
	var sp = alifemanager.codex.species.get(species_name)
	if sp == null:
		push_warning("Spawner %s: no species named %s" % [name, species_name])
		enabled = false                            # warn once
	return sp


## A random point in the circle, inside the world. With a NavWorld: only walkable spots,
## at the floor's height (a few tries, null if none).
func _random_spot():
	var c := global_position
	for attempt in 10:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius            # uniform over the disc
		var p := Vector3(c.x + cos(a) * r, c.y, c.z + sin(a) * r)
		p = alifemanager.keep_in_world(p)
		if nav_world == null or nav_world.grid == null:
			return p
		var h := nav_world.floor_at(p.x, p.z, c.y + 1.0)   # the floor at (or just above) this node
		if is_nan(h):
			continue
		p.y = h
		return p
	return null


# --- Editor circle ----------------------------------------------------------------------

func _update_gizmo() -> void:
	if not is_inside_tree():
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var seg := 48
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		im.surface_add_vertex(Vector3(cos(a0) * radius, 0.05, sin(a0) * radius))
		im.surface_add_vertex(Vector3(cos(a1) * radius, 0.05, sin(a1) * radius))
	# a small cross at the center
	im.surface_add_vertex(Vector3(-0.3, 0.05, 0.0))
	im.surface_add_vertex(Vector3(0.3, 0.05, 0.0))
	im.surface_add_vertex(Vector3(0.0, 0.05, -0.3))
	im.surface_add_vertex(Vector3(0.0, 0.05, 0.3))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.no_depth_test = true
	_gizmo.mesh = im
	_gizmo.material_override = mat
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gizmo.visible = Engine.is_editor_hint() or show_in_game
