class_name AlifeRenderer2D
extends MultiMeshInstance2D

const TEX_W := 1024                 # 1024 × 1024 = 1,048,576 agents max per texture
const STRIDE := 4					#according to texture format here FORMAT_RGBAF
var capacity := 0
var tex_h := 0
var data := PackedFloat32Array()    # 4 floats per agent: x, y, size, state #TODO bigger datatex or multiple
var img: Image
var tex: ImageTexture
const MIN_CAP := 16 * TEX_W          # start with 16,384 slots



func setup(agent_data: AlifeRenderingData, world_size: Vector3, color: Color) -> void:
	# --- MultiMesh: identity transforms, set ONCE ---
	assert(agent_data.tex != null, "AgentData.resize() must be called before renderer setup")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = false #can be changed
	mm.use_custom_data = false
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)       # base size; the shader multiplies by the agent's size
	mm.mesh = quad
	#NEED TO TEST HERE TODO
	#mm.custom_aabb = AABB(Vector3(-world_size, -world_size, -1.0),
	#					Vector3(world_size * 2.0, world_size * 2.0, 2.0))
	multimesh = mm

	# --- Material ---
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Z_TEST/test.gdshader")
	mat.set_shader_parameter("agent_data", agent_data.tex)
	mat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	mat.set_shader_parameter("alive_color", color)
	material = mat	
	
	# --- buffer, data size  ---
	ensure_instances2D(agent_data.capacity())
	
# Called once per frame, on the main thread, after the simulation
func upload(n: int) -> void:
	img.set_data(TEX_W, tex_h, false, Image.FORMAT_RGBAF, data.to_byte_array())
	tex.update(img) 
	multimesh.visible_instance_count = n

func set_count(n: int) -> void:
	multimesh.visible_instance_count = n


'func ensure_capacity(n: int) -> void:
	if n <= capacity:
		return
	var new_cap := maxi(capacity * 2, MIN_CAP)
	while new_cap < n:
		new_cap *= 2
	_resize(new_cap)'

func ensure_instances2D(n: int) -> void:
	if n <= multimesh.instance_count:
		return
	multimesh.instance_count = n
	var b := PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0])
	while b.size() < n * 8:
		b.append_array(b)                    # doubles each step: fast
	b.resize(n * 8)
	multimesh.buffer = b

'func _resize(new_cap: int) -> void:
	tex_h = ceili(float(new_cap) / TEX_W)
	var old_cap := capacity
	capacity = tex_h * TEX_W                 # round up to full rows, no wasted pixels

	# 1. Data: keep the existing agents, add zeros (= FREE) at the end
	var pad := PackedFloat32Array()
	pad.resize((capacity - old_cap) * 4)
	pad.fill(0.0)
	data.append_array(pad)

	# 2. Texture: set_image accepts a new size; the material keeps the same resource
	img = Image.create_from_data(TEX_W, tex_h, false, Image.FORMAT_RGBAF, data.to_byte_array())
	if tex == null:
		tex = ImageTexture.create_from_image(img)
		material.set_shader_parameter("agent_data", tex)
	else:
		tex.set_image(img)

	# 3. MultiMesh: changing instance_count resets the buffer, so set identity again
	multimesh.instance_count = capacity 
	multimesh.buffer = _identity(capacity)

func _identity(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0])
	while b.size() < n * 8:
		b.append_array(b)                    # doubles each step: fast
	b.resize(n * 8)
	return b'
