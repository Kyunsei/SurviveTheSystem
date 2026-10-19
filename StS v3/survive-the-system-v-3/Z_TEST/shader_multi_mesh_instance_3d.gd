class_name AlifeRenderer3D
extends MultiMeshInstance3D

func setup(agent_data: AlifeRenderingData, world_size: Vector3, color: Color) -> void:
	assert(agent_data.tex != null, "AgentData.resize() must be called before renderer setup")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D     # 12 floats per instance
	mm.use_colors = false
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6                         # keep it low-poly: there are 1M of them
	mesh.rings = 3
	mesh.radius = 1.5
	mesh.height = 1.0
	mm.mesh = mesh
	mm.custom_aabb = AABB(-world_size, world_size * 2.0) #STILL NEED TO CHECK THIS
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Z_TEST/test3d.gdshader")
	mat.set_shader_parameter("agent_data", agent_data.tex)
	mat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	mat.set_shader_parameter("alive_color", color)
	material_override = mat

	ensure_instances3D(agent_data.capacity())

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
