@tool
extends Node3D
class_name NpcSpot
## Place one where an NPC lives and assign its NpcData. When the simulation runs, it
## spawns that NPC here (on the walkable floor if a NavWorld is assigned), and respawns
## it if it disappears. The circle (editor) is how far it wanders.

@export var alifemanager: AlifeManager
## Optional: empty = alifemanager.sim_manager.
@export var sim_manager: SimulationManager
## Optional: spawn on the walkable floor below this node.
@export var nav_world: NavWorld
@export var npc_data: NpcData:
	set(v):
		npc_data = v
		_update_gizmo()
@export var species_name := "NPC"
@export var respawn := true
@export var respawn_delay := 5.0               # real seconds after it disappeared
## Wait until the simulation is ready (SimulationManager.init() done, species built, and
## the NavWorld's grid built if one is assigned) before the first spawn.
@export var wait_for_ready := true

var index := -1                                # its agent index in the species (-1 = none)
var _wait := 0.0
var _warned := false
var sim_is_ready := false                      # true once the simulation was seen ready
var _gizmo := MeshInstance3D.new()


func _ready() -> void:
	add_to_group("between_ticks")
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_update_gizmo()


## Called by SimulationManager right before each tick, when the species arrays are free
## (also with the pipelined tick). Spawning from _process could hit a running tick.
func between_ticks(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if Engine.is_editor_hint() or alifemanager == null or npc_data == null:
		return
	if not multiplayer.is_server():
		return                                 # network client: the host spawns, we mirror
	if not sim_is_ready:
		if wait_for_ready and not _simulation_ready():
			return                             # not ready yet
		if alifemanager.species_array.is_empty():
			return
		sim_is_ready = true
	var sp = alifemanager.codex.species.get(species_name)
	if sp == null or not sp.has_method("setup_npc"):
		if not _warned:
			_warned = true
			push_warning("NpcSpot %s: no NPC species named %s (add ALIFE_NPC to the codex)" % [name, species_name])
		return
	if index >= 0 and _still_there(sp):
		return
	if index >= 0:                             # it was there, and is gone
		if not respawn:
			set_process(false)
			return
		_wait += delta
		if _wait < respawn_delay:
			return
	_wait = 0.0
	index = _spawn(sp)


## True when the simulation is initialised and running, the species exist, and the
## NavWorld's grid is ready (if one is assigned).
func _simulation_ready() -> bool:
	var sm = sim_manager
	if sm == null and "sim_manager" in alifemanager:
		sm = alifemanager.sim_manager
	if sm != null:
		if not sm.running:
			return false
		if "is_ready" in sm and not sm.is_ready:
			return false
	if alifemanager.species_array.is_empty():
		return false
	if nav_world != null and nav_world.enabled and (not nav_world.is_built or nav_world.grid == null):
		return false
	return true


func _still_there(sp) -> bool:
	return index < sp.entity_count and sp.active_alife_array[index] != 0 \
			and sp.alive_array[index] != 0 and sp.npc_data[index] == npc_data


func _spawn(sp) -> int:
	var pos := alifemanager.keep_in_world(global_position)
	if nav_world != null and nav_world.grid != null:
		var h := nav_world.floor_at(pos.x, pos.z, pos.y + 1.0)
		if not is_nan(h):
			pos.y = h
	var i: int = sp.free_indices[sp.free_indices.size() - 1] if sp.free_indices.size() > 0 \
			else sp.entity_count
	var before: int = sp.active_entity_count
	sp.Build_New_Life(pos, sp.seed_energy, 0)
	if sp.active_entity_count == before:
		return -1                              # world full: try again next frame
	sp.setup_npc(i, npc_data, pos)
	return i


# --- Editor circle (wander radius) ---------------------------------------------------------

func _update_gizmo() -> void:
	if not is_inside_tree():
		return
	var r := npc_data.wander_radius if npc_data != null else 0.0
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var seg := 40
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		im.surface_add_vertex(Vector3(cos(a0) * maxf(r, 0.3), 0.05, sin(a0) * maxf(r, 0.3)))
		im.surface_add_vertex(Vector3(cos(a1) * maxf(r, 0.3), 0.05, sin(a1) * maxf(r, 0.3)))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.8, 1.0)
	mat.no_depth_test = true
	_gizmo.mesh = im
	_gizmo.material_override = mat
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gizmo.visible = Engine.is_editor_hint()
