extends MeshInstance3D
class_name CloudLayer
## Fake cloud layer over the little planet (uses cloud_layer.gdshader).
##
## Setup: add a MeshInstance3D to the scene, attach this script, set Material Override
## to a new ShaderMaterial using cloud_layer.gdshader, and assign the camera / sim manager.
## The mesh is created here: a subdivided plane that follows the view, at cloud height.
## The clouds themselves are fixed in the world (noise in world coordinates) and drift
## with the wind.

@export var camera: FlyCamera
@export var sim_manager: SimulationManager

@export var height := 25.0                 # above the ground (y = 0)
@export var radius := 220.0                # half size of the cloud sheet, around the view
@export var subdivisions := 96             # vertices per side: smooth bend over the planet
@export var wind := Vector2(2.0, 0.8)      # drift in world units / s (x, z)
@export var follow_sim_speed := true       # wind faster with simulation_speed, stops on pause
@export var only_when_planet := true       # visible only in control mode (round planet)

var _offset := Vector2.ZERO


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	mesh = plane
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The sheet is always around the camera: never culled for being "off screen"
	extra_cull_margin = height + radius
	if not (material_override is ShaderMaterial):
		push_warning("CloudLayer: set Material Override to a ShaderMaterial with cloud_layer.gdshader")


func _process(delta: float) -> void:
	if only_when_planet:
		visible = WorldWrap.planet_radius > 0.0
	if not visible or camera == null:
		return

	# Follow the view (the noise is in world coordinates, so the clouds don't move with it)
	var c: Vector3 = camera.get_wrap_center()
	global_position = Vector3(c.x, height, c.z)

	# Wind
	var speed := 1.0
	if follow_sim_speed and sim_manager != null:
		speed = sim_manager.simulation_speed if sim_manager.running else 0.0
	_offset += wind * delta * speed
	var ws: Vector3 = WorldWrap.size
	_offset = Vector2(fposmod(_offset.x, ws.x), fposmod(_offset.y, ws.z))   # noise repeats on the world size

	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("wrap_center", c)
	mat.set_shader_parameter("world_size", Vector2(ws.x, ws.z))
	mat.set_shader_parameter("cloud_offset", _offset)
	mat.set_shader_parameter("fade_start", radius * 0.6)
	mat.set_shader_parameter("fade_end", radius)
