extends Node

'This is the global Script for all the variable and function defining the world'

var world_size = 80 #The size in tile of the World
var tile_size = 32 # the size in pixel of each tile

var block_element_array = [] #1D matrix of the block composing the world

var world_array = [] #1D matrix of occupation

var block_scene = load("res://Scenes/world_block.tscn") #load scene of block

#different variable for the "element"
#var max_element = 100 #max quantities
var element = 1000.0 #current value

var speed = 5.0

# Load GLSL shader
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://Scripts//compute_worldblock.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


func Init_World():
	Init_matrix()
	Init_shader()

func Init_matrix():
	element = 1000
	block_element_array.resize(world_size*world_size)
	block_element_array.fill(5)
	world_array.resize(world_size*world_size)
	world_array.fill(-1)
	
	


func Init_shader():
	rd = RenderingServer.create_local_rendering_device()
	shader_file = load("res://Scripts//compute_worldblock.glsl")
	shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	

	

func InstantiateBlock(i,j,folder):
	if i >= 0 and j >= 0 and i < world_size and j < world_size:
		var new_block = block_scene.instantiate()
		new_block.get_node("outsideline").size = Vector2(tile_size,tile_size)
		new_block.get_node("ColorRect").size = Vector2(tile_size-1,tile_size-1)
		new_block.position.x = i*tile_size
		new_block.position.y = j*tile_size
		#new_block.color = getBlockColor(i,j)
		new_block.name =str(i)+"_"+str(j)
		folder.add_child(new_block)



func init_buffer(A):
	var input := PackedFloat32Array(A)
	var input_bytes := input.to_byte_array()
	var Buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	return Buffer
	
func init_buffer_int(A):
	var input := PackedInt32Array(A)
	var input_bytes := input.to_byte_array()
	var Buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	return Buffer

func init_uniform(Buffer, binding):

	var Uniform := RDUniform.new()
	Uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	Uniform.binding = binding # this needs to match the "binding" in our shader file
	Uniform.add_id(Buffer)
	return (Uniform)
	
func BlockLoopGPU():
	# Prepare our data.
	var BlockArraybuffer = init_buffer(World.block_element_array)
	var Blockuniform = init_uniform(BlockArraybuffer,0)	
	
	var BlockArraybuffer0 = init_buffer(World.block_element_array)
	var Blockuniform0 = init_uniform(BlockArraybuffer0,1)	
	
	#bind them
	var uniform_set := rd.uniform_set_create([Blockuniform,Blockuniform0], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list,World.block_element_array.size()/2, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(BlockArraybuffer)
	var output := output_bytes.to_float32_array()
	World.block_element_array = output	
