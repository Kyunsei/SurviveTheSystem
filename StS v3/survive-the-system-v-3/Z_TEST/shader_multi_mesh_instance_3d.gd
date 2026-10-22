class_name AlifeRenderer3D
extends MultiMeshInstance3D

var sprite: Texture2D
var hframes := 1
var vframes := 1
var pixel_size := 0.01  # world units per pixel, same idea as Sprite3D
var billboard := true
var billboard_y_only := false
var selected_id := -1


func setup(agent_data: AlifeRenderingData, sprite:Texture2D, world_size: Vector3, color: Color) -> void:
	assert(agent_data.tex != null, "AgentData.resize() must be called before renderer setup")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D     # 12 floats per instance
	mm.use_colors = false
	
	'var mesh := SphereMesh.new()
	mesh.radial_segments = 6                         # keep it low-poly: there are 1M of them
	mesh.rings = 3
	mesh.radius = 1.5
	mesh.height = 1.0'
	
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
	mat.shader = preload("res://Z_TEST/test3d.gdshader")
	mat.set_shader_parameter("agent_data", agent_data.tex)
	mat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	mat.set_shader_parameter("alive_color", color)
	mat.set_shader_parameter("sprite_texture", sprite)
	mat.set_shader_parameter("billboard", billboard)
	mat.set_shader_parameter("billboard_y_only", billboard_y_only)
	mat.set_shader_parameter("selected_id", selected_id)

	#mat.set_shader_parameter("hframes", hframes)
	#mat.set_shader_parameter("vframes", vframes)
	material_override = mat
	


	ensure_instances3D(agent_data.capacity())



func set_frame(index: int, frame: int) -> void:
	multimesh.set_instance_custom_data(index, Color(frame, 0, 0, 0))


func ensure_instances3D(n: int) -> void:
	if n <= multimesh.instance_count:
		return
	multimesh.instance_count = n
	var b := PackedFloat32Array([1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0])   # 3D identity
	while b.size() < n * 12:
		b.append_array(b)
	b.resize(n * 12)
	multimesh.buffer = b

func set_count(n: int) -> void:
	multimesh.visible_instance_count = n
