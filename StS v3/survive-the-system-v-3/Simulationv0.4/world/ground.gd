extends MeshInstance3D
## Endless-looking ground, shown ONLY while an agent is controlled (any control mode).
## The rest of the time it hides and `normal_ground` is shown instead.
##
## A big plane follows the camera; its texture is read in WORLD coordinates and repeats
## every world size (ground shader), so it never slides and the borders are seamless.
## It bends with the little-planet curve, so the plane is subdivided (subdivisions).

@export var controller: PlayerController # tells whether an agent is controlled
@export var normal_ground: GridMap       # your usual ground, hidden in control mode
@export var plane_size := 600.0          # should be about 2x how far the camera sees
@export var subdivisions := 150          # vertices per side: more = smoother planet curve
@export var ground_y := 0.0
@export var ground_texture: Texture2D    # empty: taken from the GridMap's first tile
## World units covered by one copy of the texture. -1: the GridMap's cell size (one tile
## repeated, as with steal_texture). 0: the texture is the whole world.
@export var tile_size := -1.0
@export var tint := Color.WHITE
@export var grid_cell := 0.0             # > 0: grid lines every grid_cell units (1.0 for 1 m tiles)
@export var show_border := false         # draw a line where the world repeats (debug)
@export var env: WorldEnvironment        # its fog is on only while this ground is shown
var _mat := ShaderMaterial.new()
var _shown := true                       # forces the first update


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(plane_size, plane_size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	# The planet curve moves vertices in the shader: never let the plane be culled too early
	extra_cull_margin = plane_size

	if ground_texture == null:
		steal_texture()
	_mat.shader = preload("res://Simulationv0.4/DEBUG/world/ground_shader.gdshader")
	_mat.set_shader_parameter("ground_texture", ground_texture)
	_mat.set_shader_parameter("tint", tint)
	var tile := tile_size
	if tile < 0.0:
		tile = normal_ground.cell_size.x if normal_ground != null else 1.0
	_mat.set_shader_parameter("tile_size", tile)
	_mat.set_shader_parameter("grid_cell", grid_cell)
	_mat.set_shader_parameter("border_color", Color(1, 1, 1, 0.6 if show_border else 0.0))
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Run AFTER the camera every frame: when it jumps across a border, this plane
	# follows in the same frame (no frame drawn half on the old spot)
	process_priority = 100
	_set_shown(false)


## Use the texture of the GridMap's first MeshLibrary item.
func steal_texture() -> void:
	if normal_ground == null or normal_ground.mesh_library == null:
		return
	var item_mesh := normal_ground.mesh_library.get_item_mesh(0)    # the item's mesh
	if item_mesh == null:
		return
	var mat := item_mesh.surface_get_material(0) as BaseMaterial3D  # its material
	if mat != null:
		ground_texture = mat.albedo_texture


func _process(_delta: float) -> void:
	var on := controller != null and controller.is_controlling()
	_set_shown(on)
	if not on:
		return

	_mat.set_shader_parameter("world_size", WorldWrap.size)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = Vector3(cam.global_position.x, ground_y, cam.global_position.z)


## Swap between this endless ground and the normal one (only when it changes).
func _set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	visible = on
	if env != null and env.environment != null:
		env.environment.fog_enabled = on

	if normal_ground != null:
		normal_ground.visible = not on
