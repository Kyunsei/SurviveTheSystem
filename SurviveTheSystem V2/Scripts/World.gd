extends Node

'This is the global Script for all the variable and function defining the world'

var world_size = 100 #The size in tile of the World
var tile_size = 32#128 # the size in pixel of each tile
var fieldofview = 25 #in tile


var block_element_array = [] #1D matrix of the block composing the world

var world_array = [] #1D matrix of occupation

var block_scene = preload("res://Scenes/world_block.tscn") #load scene of block

#different variable for the "element"
#var max_element = 100 #max quantities
var element = 1000.0 #current value

var speed = 1.0
var day = 0

#30 min max (in second) / nb jours total * proprtion nuit/jour
var daytime = 30. *60 / 20 * 2/3
var nighttime = 30. *60 / 20 * 2/3

var isReady = false

var life_instance_thread = []
var life_position_thread = []

# Load GLSL shader
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://Scripts//compute_worldblock.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


func Init_World():
	Init_matrix()
	Init_shader()
	speed = 1.0
	day = 0
	isReady = true

func Init_matrix():
	element = 1000
	block_element_array.resize(world_size*world_size)
	block_element_array.fill(6)
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
		#new_block.get_node("outsideline").size = Vector2(tile_size,tile_size)
		#new_block.get_node("ColorRect").size = Vector2(tile_size-1,tile_size-1)
		new_block.get_node("ColorRect").size = Vector2(tile_size,tile_size)
		new_block.position.x = i*tile_size
		new_block.position.y = j*tile_size
		#new_block.color = getBlockColor(i,j)
		new_block.name =str(i)+"_"+str(j)
		folder.add_child(new_block)

func getWorldPos(position):
	var x = int(position.x/tile_size)
	var y = int(position.y/tile_size)
	return Vector2(x,y)

func InstantiateBlockAroundPlayer(x,y,folder):
	for i in range(-fieldofview,fieldofview):
		for j in range(-fieldofview,fieldofview):
			var xpos = x + i
			var ypos = y + j
			World.InstantiateBlock(xpos,ypos,folder)


func ActivateAndDesactivateBlockAround(direction,x,y,allblocks):


	var playerpos = Vector2(x,y)
		#if direction.x != 0 or direction.y != 0 :
		#var s = Time.get_ticks_msec() 
		#var rightblocks = allblocks.filter(getRightBlock.bind(playerpos))
		#var s2 = Time.get_ticks_msec() 
		#if direction.x < 0:
			#print("left")
			#for b in allblocks:
				#if b.position.x > tile_size*fieldofview*2 - 1 and b.position.x > (playerpos.x*tile_size + tile_size*fieldofview):
					#var b_pos = b.position.x - fieldofview*2*tile_size
					#b.position.x = max(0, b_pos)
					#var newpos = getWorldPos(b.position)
					#var newposindex = newpos.y*World.world_size + newpos.x
					#b.posindex = newposindex
					#b.BlockUpdate()
			##if direction.y < 0:
		#if direction.y < 0:
			#print("top")
			#for b in allblocks:
				#if b.position.y > tile_size*fieldofview*2 - 1 and b.position.y > (playerpos.x*tile_size + tile_size*fieldofview):
					#var b_pos = b.position.y - fieldofview*2*tile_size
					#b.position.y = max(0, b_pos)
					#var newpos = getWorldPos(b.position)
					#var newposindex = newpos.y*World.world_size + newpos.x
					#b.posindex = newposindex
					#b.BlockUpdate()
		##	if direction.y > 0:
		#if direction.y > 0:
			#print("bot")
			#for b in allblocks:
				#if b.position.y > tile_size*world_size - tile_size*fieldofview*2 and b.position.y > (playerpos.y*tile_size - tile_size*fieldofview):
#
					#var b_pos = b.position.y + fieldofview*2*tile_size
					#b.position.y = min(world_size*tile_size-1, b_pos)
					#var newpos = getWorldPos(b.position)
					#var newposindex = newpos.y*World.world_size + newpos.x
					#b.posindex = newposindex
					#b.BlockUpdate()
		##	if direction.x > 0:	
		#if direction.x > 0:
			#print("right")
			#for b in allblocks:
				#if b.position.x > tile_size*world_size - tile_size*fieldofview*2 and b.position.x > (playerpos.x*tile_size - tile_size*fieldofview):
#
					#var b_pos = b.position.x + fieldofview*2*tile_size
					#b.position.x = min(world_size*tile_size-1, b_pos)
					#var newpos = getWorldPos(b.position)
					#var newposindex = newpos.y*World.world_size + newpos.x
					#b.posindex = newposindex
					#b.BlockUpdate()
		#var s5 = Time.get_ticks_msec() 
		#print("loop ALL is " + str(s5-s4))
	if direction.x > 0 :
		var leftblocks = allblocks.filter(getLeftBlock.bind(playerpos))
		for b in leftblocks:
			var b_pos = b.position.x + fieldofview*2*tile_size
			b.position.x = min(world_size*tile_size-1, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()	

	
	if direction.x < 0:
		var rightblocks = allblocks.filter(getRightBlock.bind(playerpos))
		for b in rightblocks:
			var b_pos = b.position.x - fieldofview*2*tile_size
			b.position.x = max(0, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()
			
	if direction.y < 0:
		var bottomblocks = allblocks.filter(getBottomBlock.bind(playerpos))
		for b in bottomblocks:
			var b_pos = b.position.y - fieldofview*2*tile_size
			b.position.y = max(0, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()
	if direction.y > 0:	
		var topblocks = allblocks.filter(getTopBlock.bind(playerpos))
		for b in topblocks:
			var b_pos = b.position.y + fieldofview*2*tile_size
			b.position.y =  min(world_size*tile_size-1, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()

	

	




func getRightBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.x >  fieldofview*2 - 1:
		return blockpos.x > (playerpos.x + fieldofview)
	else:
		return false

func getBottomBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.y >  fieldofview*2 - 1:
		return blockpos.y > (playerpos.y + fieldofview)
	else:
		return false

func getTopBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.y < world_size - fieldofview*2:
		return blockpos.y < (playerpos.y - fieldofview)
	else:
		return false



func getLeftBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.x < world_size - fieldofview*2:
		return blockpos.x < (playerpos.x - fieldofview)
	else:
		return false
	
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
