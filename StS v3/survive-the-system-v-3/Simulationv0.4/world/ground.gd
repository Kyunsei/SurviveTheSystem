extends MeshInstance3D
## Endless-looking ground, shown ONLY while an agent is controlled (any control mode).
## The rest of the time it hides and `normal_ground` is shown instead.
##
## A big plane follows the camera; its texture is read in WORLD coordinates and repeats
## every world size (wrap_ground.gdshader), so it never slides and the borders are seamless.

@export var picker: Node                 # the agent picker: tells whether an agent is controlled
@export var normal_ground: Node3D        # your usual ground (e.g. the GridMap), hidden in control mode
@export var plane_size := 600.0          # should be about 2x how far the camera sees
@export var ground_y := 0.0
@export var ground_texture: Texture2D    # the whole world in one texture (e.g. 1 pixel per cell)
@export var tint := Color.WHITE
@export var grid_cell := 0.0             # > 0: grid lines every grid_cell units (1.0 for 1 m tiles)
@export var show_border := false         # draw a line where the world repeats (debug)
@export var env :WorldEnvironment
var _mat := ShaderMaterial.new()
var _shown := true                       # forces the first update


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(plane_size, plane_size)
	mesh = plane
	steal_texture()
	_mat.shader = preload("res://Simulationv0.4/DEBUG/world/ground_shader.gdshader")
	_mat.set_shader_parameter("ground_texture", ground_texture)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("grid_cell", grid_cell)
	_mat.set_shader_parameter("border_color", Color(1, 1, 1, 0.6 if show_border else 0.0))
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_shown(false)

func steal_texture():
	if normal_ground:
		var mesh = normal_ground.mesh_library.get_item_mesh(0)       # the item's mesh
		var mat := mesh.surface_get_material(0) as BaseMaterial3D      # its material
		var tex := mat.albedo_texture  
		ground_texture = tex
		

func _process(_delta: float) -> void:
	var on := picker != null and picker.controlled_species != null
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
	env.environment.fog_enabled = _shown

	if normal_ground != null:
		normal_ground.visible = not on
