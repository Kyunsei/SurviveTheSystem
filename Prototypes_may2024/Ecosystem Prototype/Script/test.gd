extends Node2D

var rd := RenderingServer.create_local_rendering_device()

# Load GLSL shader
var shader_file := load("res://Script//compute_spheretoblock.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


# Prepare our data. We use floats in the shader, so we need 32 bit.
var input := PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10,70])
var input_bytes := input.to_byte_array()

# Create a storage buffer that can hold our float values.
# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)


var input2 := PackedFloat32Array([10])
var input_bytes2 := input2.to_byte_array()
var buffer2 := rd.storage_buffer_create(input_bytes2.size(), input_bytes2)


func _ready():

	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)


	# Create a uniform to assign the buffer to the rendering device
	var uniform2 := RDUniform.new()
	uniform2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform2.binding = 1 # this needs to match the "binding" in our shader file
	uniform2.add_id(buffer2)

	var uniform_set := rd.uniform_set_create([uniform, uniform2], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file



	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	#var size = blocks.size() / local_size
	rd.compute_list_dispatch(compute_list, 5, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(buffer)
	var output := output_bytes.to_float32_array()
	print("Input: ", input)
	print("Output: ", output)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass