@tool
extends Node3D
class_name WalkArea
## Keeps agents inside an area, and gives them the height of the floor under them
## (stand on top of the shape, jump onto it, fall off it).
##
## Fast path (species with a `height_grid` variable, e.g. CATRONAUTE): the area is baked
## ONCE into a HeightGrid (one height per cell). The species looks its floor up in its own
## tick, on the worker threads: a few divisions and one array read per agent, no
## navigation query at run time. Fine for 100k agents.
## Other species (slow path): put back inside after every tick, horizontally only, with
## navigation queries on the main thread (fine for a few agents).
##
## Two shapes:
##   - Rectangle (default): `size` (x, z), centered on this node, flat at this node's height.
##   - Navigation mesh: assign `navigation_region` (a NavigationRegion3D with a baked
##     NavigationMesh). Bake it with a SMALL agent radius (0 - 0.1): a big radius leaves a
##     gap around each ledge where nothing is walkable.
##
## Called by AlifeManager.update_alife() (group "walk_areas").

@export var enabled := true:
	set(v):
		enabled = v
		_update_outline()
@export var size := Vector2(40.0, 40.0):
	set(v):
		size = v
		_grid = null                           # rebake with the new size
		_update_outline()
@export var navigation_region: NavigationRegion3D:
	set(v):
		navigation_region = v
		_grid = null
## Species kept inside (species_name). Empty = every species.
@export var species_names: PackedStringArray = ["CATRONAUTE"]
## true: only the agent the player controls is kept inside.
@export var only_controlled := false
## Keep this far from the rectangle's edges.
@export var margin := 0.0
@export var show_in_game := false          # the outline is flat: it doesn't follow the planet bend

@export_group("Height grid")
## Cell size of the baked height grid (world units). Smaller = more precise edges,
## more memory (1 float per cell) and a longer bake.
@export var grid_cell := 0.5:
	set(v):
		grid_cell = maxf(v, 0.05)
		_grid = null
## Feet can go up this much without jumping (steps, slopes). Higher surfaces are walls.
@export var max_step_up := 0.5

var _outline := MeshInstance3D.new()
var _grid: HeightGrid = null


func _ready() -> void:
	add_to_group("walk_areas")
	_build_outline()
	_update_outline()


## Bakes the height grid again (call it after moving the area or rebaking the navmesh).
func rebake() -> void:
	_grid = null


## Switch on / off from code (same as the `enabled` checkbox).
func toggle() -> void:
	enabled = not enabled


# --- Every tick (main thread, after the species moved) ---------------------------------

func constrain(am: AlifeManager) -> void:
	if Engine.is_editor_hint():
		return

	var map := RID()
	if navigation_region != null:
		map = navigation_region.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			return                             # navigation map not ready yet (first frames)

	if enabled and _grid == null:
		_grid = _bake(map)                     # once (a short hitch), then only array reads

	var to_local := global_transform.affine_inverse()
	for sp in am.species_array:
		if not species_names.is_empty() and not (sp.species_name in species_names):
			continue
		# Fast path: give (or take back) the grid, the species does the rest in its tick
		if "height_grid" in sp:
			sp.height_grid = _grid if enabled else null
			continue
		if not enabled:
			continue
		# Slow path: horizontal only, agent by agent
		if only_controlled:
			if "player_index" in sp and sp.player_index >= 0:
				_keep_inside(sp, sp.player_index, to_local, map)
			continue
		for i in sp.entity_count:
			_keep_inside(sp, i, to_local, map)


# --- Height grid bake -------------------------------------------------------------------

func _bake(map: RID) -> HeightGrid:
	var g := HeightGrid.new()
	g.cell = grid_cell
	g.inv_cell = 1.0 / grid_cell
	g.max_step_up = max_step_up
	g.player_only = only_controlled

	# Bounds (world x, z) and how high to start the downward search
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var corners: Array[Vector3] = []
	if map.is_valid():
		var nm := navigation_region.navigation_mesh
		if nm == null or nm.get_vertices().is_empty():
			push_warning("WalkArea: the navigation mesh is empty (bake it first)")
			return g
		var xf := navigation_region.global_transform
		for v in nm.get_vertices():
			corners.append(xf * v)
	else:
		var h := size * 0.5 - Vector2(margin, margin)
		for c in [Vector3(-h.x, 0, -h.y), Vector3(h.x, 0, -h.y), Vector3(h.x, 0, h.y), Vector3(-h.x, 0, h.y)]:
			corners.append(global_transform * c)
	for c in corners:
		lo = Vector3(minf(lo.x, c.x), minf(lo.y, c.y), minf(lo.z, c.z))
		hi = Vector3(maxf(hi.x, c.x), maxf(hi.y, c.y), maxf(hi.z, c.z))

	g.origin = Vector2(lo.x, lo.z)
	g.w = maxi(ceili((hi.x - lo.x) * g.inv_cell), 1)
	g.d = maxi(ceili((hi.z - lo.z) * g.inv_cell), 1)
	g.heights.resize(g.w * g.d)

	var to_local := global_transform.affine_inverse()
	var half := size * 0.5 - Vector2(margin, margin)
	var top_y := hi.y + 10.0
	var bottom_y := lo.y - 10.0
	for cz in g.d:
		for cx in g.w:
			var x := g.origin.x + (cx + 0.5) * g.cell
			var z := g.origin.y + (cz + 0.5) * g.cell
			var h := NAN
			if map.is_valid():
				# Highest walkable surface straight below (no hit = not walkable)
				var hit := NavigationServer3D.map_get_closest_point_to_segment(
						map, Vector3(x, top_y, z), Vector3(x, bottom_y, z), true)
				if Vector2(hit.x - x, hit.z - z).length_squared() < 1e-4:
					h = hit.y
			else:
				var l := to_local * Vector3(x, global_position.y, z)
				if absf(l.x) <= half.x and absf(l.z) <= half.y:
					h = global_position.y
			g.heights[cx + g.w * cz] = h

	print("WalkArea: height grid %d x %d (%d cells) baked" % [g.w, g.d, g.w * g.d])
	return g


# --- Slow path (species without height_grid) --------------------------------------------

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
