extends MultiMeshInstance3D
class_name grid_3d
## 3D world map — step 1: draws only the border (wireframe) of each grid cell.
## One wire-box instance per cell. Values inside cells will come later.
## Place this node where cell (0,0,0)'s corner should be, or use `origin`.

@export var activated := false: set = set_activated
@export var MaxDrawn := 100000
@export var current_layer := -1: set = set_layer   # -1 = all y layers, otherwise only that y layer
@export var box_scale := 1.0                       # < 1 (e.g. 0.95) leaves a gap so each cell is distinct
@export var border_color := Color(0.2, 1.0, 0.4, 0.5)
@export var origin := Vector3.ZERO                 # local offset of cell (0,0,0)'s corner

var W: int
var H: int
var D: int
var cell_size := Vector3.ONE


func _ready() -> void:
	visible = activated


## Turn the display on/off.
func set_activated(on: bool) -> void:
	activated = on
	visible = on
	if on:
		draw_borders()


func toggle() -> void:
	set_activated(not activated)


## Change which y layer is shown (-1 = all) and redraw.
func set_layer(layer: int) -> void:
	current_layer = layer
	draw_borders()


func setup(p_cell_size: Vector3, world_size: Vector3) -> void:
	cell_size = p_cell_size
	var dims := Vector3i((world_size / cell_size).ceil())
	W = dims.x    # cells along x
	H = dims.y    # cells along y
	D = dims.z    # cells along z

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D   # must be set before instance_count
	multimesh.use_colors = true
	multimesh.instance_count = mini(W * H * D, MaxDrawn)
	multimesh.visible_instance_count = 0
	multimesh.mesh = build_wire_box(cell_size * box_scale)
	material_override = _make_material()

	print("world_map_3d: grid %d x %d x %d = %d cells, cell size %s" % [W, H, D, W * H * D, cell_size])
	draw_borders()


## Fills the instances: one wire box per cell (static, only needs redrawing on setup/layer change).
func draw_borders() -> void:
	if not activated or not is_inside_tree() or multimesh == null or multimesh.mesh == null:
		return

	var y0 := 0
	var y1 := H
	if current_layer >= 0:
		y0 = clampi(current_layer, 0, H - 1)
		y1 = y0 + 1

	var limit := multimesh.instance_count
	var half := Vector3(0.5, 0.5, 0.5)
	var ii := 0

	for cz in D:
		for cy in range(y0, y1):
			for cx in W:
				if ii >= limit:
					push_warning("world_map_3d: MaxDrawn (%d) reached, rest not drawn" % limit)
					multimesh.visible_instance_count = ii
					return
				var p := (Vector3(cx, cy, cz) + half) * cell_size + origin
				multimesh.set_instance_transform(ii, Transform3D(Basis.IDENTITY, p))
				multimesh.set_instance_color(ii, border_color)
				ii += 1

	multimesh.visible_instance_count = ii


## 12-edge wireframe box centred on the origin.
func build_wire_box(size: Vector3) -> ArrayMesh:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z),   Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z),  Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z),    Vector3(-h.x, h.y, h.z),
	]
	var edges := [
		0, 1, 1, 2, 2, 3, 3, 0,   # bottom
		4, 5, 5, 6, 6, 7, 7, 4,   # top
		0, 4, 1, 5, 2, 6, 3, 7,   # verticals
	]
	var verts := PackedVector3Array()
	for i in edges:
		verts.append(c[i])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true          # uses the per-instance colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m
