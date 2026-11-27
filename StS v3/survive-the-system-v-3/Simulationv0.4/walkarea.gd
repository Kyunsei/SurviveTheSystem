@tool
extends Node3D
class_name WalkArea
## Keeps agents inside an area: after every simulation tick, any agent of the chosen
## species that stepped out is put back on the closest point inside. Walking into the
## edge slides along it.
##
## Two shapes:
##   - Rectangle (default): `size` (x, z), centered on this node. Move / rotate the node
##     to place it. Shown as an outline in the editor.
##   - Navigation mesh: assign `navigation_region` (a NavigationRegion3D with a baked
##     NavigationMesh, e.g. baked from your 3D shape). The agent is kept on the mesh.
##     The rectangle is then ignored.
##
## Only the horizontal position (x, z) is constrained: jumping / height are unchanged.
## Called by AlifeManager.update_alife() (group "walk_areas"), so the contact grid
## and carried items already use the corrected positions.

## Off: agents can leave the area (it does nothing). Can be switched while the game runs.
@export var enabled := true:
	set(v):
		enabled = v
		_update_outline()
@export var size := Vector2(40.0, 40.0):
	set(v):
		size = v
		_update_outline()
@export var navigation_region: NavigationRegion3D
## Species kept inside (species_name). Empty = every species.
@export var species_names: PackedStringArray = ["CATRONAUTE"]
## true: only the agent the player controls is kept inside.
@export var only_controlled := false
## Keep this far from the rectangle's edges.
@export var margin := 0.0
@export var show_in_game := false          # the outline is flat: it doesn't follow the planet bend

var _outline := MeshInstance3D.new()


func _ready() -> void:
	add_to_group("walk_areas")
	_build_outline()
	_update_outline()


## Switch on / off from code (same as the `enabled` checkbox).
func toggle() -> void:
	enabled = not enabled


## Called once per tick, main thread, after the species have moved.
func constrain(am: AlifeManager) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	var map := RID()
	if navigation_region != null:
		map = navigation_region.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			return                             # navigation map not ready yet (first frames)
	var to_local := global_transform.affine_inverse()

	for sp in am.species_array:
		if not species_names.is_empty() and not (sp.species_name in species_names):
			continue
		if only_controlled:
			if "player_index" in sp and sp.player_index >= 0:
				_keep_inside(sp, sp.player_index, to_local, map)
			continue
		for i in sp.entity_count:
			_keep_inside(sp, i, to_local, map)


func _keep_inside(sp, i: int, to_local: Transform3D, map: RID) -> void:
	if sp.active_alife_array[i] != AlifeManager.ACTIVE:
		return                                 # pool, carried, thrown...: not walking
	var p: Vector3 = sp.position_array[i]
	var q := p
	if map.is_valid():
		var c := NavigationServer3D.map_get_closest_point(map, p)
		q.x = c.x
		q.z = c.z
	else:
		var l := to_local * p
		var h := size * 0.5 - Vector2(margin, margin)
		l.x = clampf(l.x, -maxf(h.x, 0.0), maxf(h.x, 0.0))
		l.z = clampf(l.z, -maxf(h.y, 0.0), maxf(h.y, 0.0))
		var back := global_transform * l
		q.x = back.x
		q.z = back.z
	if not q.is_equal_approx(p):
		sp.position_array[i] = q


# --- Outline (rectangle mode) -----------------------------------------------------------

func _build_outline() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.no_depth_test = true
	_outline.material_override = mat
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline, false, Node.INTERNAL_MODE_FRONT)   # not saved in the scene


func _update_outline() -> void:
	if not is_inside_tree():
		return
	var h := size * 0.5
	var c := [Vector3(-h.x, 0.05, -h.y), Vector3(h.x, 0.05, -h.y),
			Vector3(h.x, 0.05, h.y), Vector3(-h.x, 0.05, h.y)]
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 4:
		im.surface_add_vertex(c[k])
		im.surface_add_vertex(c[(k + 1) % 4])
	im.surface_end()
	_outline.mesh = im
	_outline.visible = navigation_region == null and (Engine.is_editor_hint() or show_in_game)
	var mat := _outline.material_override as StandardMaterial3D
	if mat != null:                                   # green when on, grey when off
		mat.albedo_color = Color(0.2, 1.0, 0.4) if enabled else Color(0.5, 0.5, 0.5)
