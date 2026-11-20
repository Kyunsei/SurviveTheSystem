class_name AlifeRenderer3D
extends MultiMeshInstance3D

var sprite: Texture2D
var hframes := 1
var vframes := 1
var pixel_size := 0.01  # world units per pixel, same idea as Sprite3D
var billboard := true
var billboard_y_only := false
var selected_id := -1

const SHADOW_SHADER :=preload("uid://cm0rwd0o8onrb")
var _shadow: MultiMeshInstance3D
var is_plant = true

func setup(agent_data: AlifeRenderingData, alife:ALIFE, world_size: Vector3, color: Color) -> void:
	assert(agent_data.tex != null, "AgentData.resize() must be called before renderer setup")
	
	sprite =  alife.sprite
	is_plant = alife.photosynthesis_on
	hframes= alife.hframes
	vframes = alife.vframes
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D     # 12 floats per instance
	mm.use_colors = false
	
	#sprite = preload("res://Alife/Plant/Grass/grass.png") #TODO
	var frame_px := sprite.get_size() / Vector2(hframes, vframes)
	var quad := QuadMesh.new()
	quad.size = frame_px * pixel_size
	# Put the pivot at the sprite's feet instead of its centre
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)

	
	mm.mesh = quad #mesh
	mm.custom_aabb = AABB(-world_size, world_size * 2.0) #STILL NEED TO CHECK THIS
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = preload("uid://w65faynydapu")
	mat.set_shader_parameter("agent_data", agent_data.tex)
	mat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	mat.set_shader_parameter("alive_color", color)
	mat.set_shader_parameter("sprite_texture", sprite)
	mat.set_shader_parameter("billboard", billboard)
	mat.set_shader_parameter("billboard_y_only", billboard_y_only)
	mat.set_shader_parameter("selected_id", selected_id)
	mat.set_shader_parameter("wind_strength", 0.3 if is_plant else 0.0)
	mat.set_shader_parameter("hframes", hframes)
	mat.set_shader_parameter("vframes", vframes)
	mat.set_shader_parameter("world_height", world_size.y)

	material_override = mat
	ensure_instances3D(agent_data.capacity())

# At the end of setup():
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.mesh = QuadMesh.new()                      # 1 x 1, centered
	smm.custom_aabb = mm.custom_aabb

	var smat := ShaderMaterial.new()
	smat.shader = SHADOW_SHADER
	smat.set_shader_parameter("agent_data", agent_data.tex)
	smat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	smat.set_shader_parameter("world_height", world_size.y)
	_shadow = MultiMeshInstance3D.new()
	_shadow.multimesh = smm
	_shadow.material_override = smat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	ensure_instances3D(agent_data.capacity())

func set_frame(index: int, frame: int) -> void:
	multimesh.set_instance_custom_data(index, Color(frame, 0, 0, 0))


func _ensure(mm : MultiMesh, n: int) -> void:
	if n <= mm.instance_count:
		return
	mm.instance_count = n
	var b := PackedFloat32Array([1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0])   # 3D identity
	while b.size() < n * 12:
		b.append_array(b)
	b.resize(n * 12)
	mm.buffer = b

func set_count(n: int) -> void:
	multimesh.visible_instance_count = n
	if _shadow:
		_shadow.multimesh.visible_instance_count = n

func ensure_instances3D(n: int) -> void:
	_ensure(multimesh, n)
	if _shadow:
		_ensure(_shadow.multimesh, n)
