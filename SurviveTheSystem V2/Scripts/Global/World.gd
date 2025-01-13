extends Node2D

'This is the global Script for all the variable and function defining the world'

var world_size = 500 #The size in tile of the World
var tile_size = 32#128 # the size in pixel of each tile
var fieldofview = Vector2(0,0) #in tile

var debug_mode = false

#chall
var ID_chal = 0

#ENERGY SUN
var energy_flow_in = 2.0 #how much energy added by day by tile
var sun_energy_block_array = []
var sun_energy_occupation_array = []
var n_sun_level = 3

#OLD SOIL ENERGY
var block_element_array = [] #1D matrix of the block composing the world
var block_element_state = [] #1D matrix of the block state composing the world

var world_array = [] #1D matrix of occupation

var block_scene = preload("res://Scenes/world_block.tscn") #load scene of block


#different variable for the "element"
#var max_element = 100 #max quantities
var element = 1000.0 #current value

var speed = 1.0
var day = 0
var isNight = false


#30 min max (in second) / nb jours total * proprtion nuit/jour
var daytime = 30. *60 / 20 * 2/3
var nighttime = 30. *60 / 20 * 1/3

var one_day_length = daytime + nighttime

var isReady = false

var life_instance_thread = []
var life_position_thread = []

# Load GLSL shader
var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://Scripts//compute_worldblock.glsl")
var shader_file_sun := load("res://Scripts//compute_sun_block.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


#Diffusion Control
var diffusion_speed = 10. #in sec
var diffusion_quantity_style = false # false = factor true = number #not implemented.
var diffusion_factor = 0.5

var diffusion_number = 1. #not implemented.
var diffusion_min_limit = 1. #cannot diffuse lower than 1
var diffusion_block_limit = 2 #how many block energy move. #not implemented.

var block_diffusion_par = []



func Init_World(folder):
	Init_matrix()
	Init_shader()

	speed = 1.0
	day = 0
	isReady = true
	fieldofview = get_viewport().get_visible_rect().size / tile_size

func Init_matrix():
	element = 1000
	block_element_array.resize(world_size*world_size)
	block_element_state.resize(world_size*world_size)

	block_element_array.fill(0)
	block_element_state.fill(0)
	

	for i in range(n_sun_level): 
		sun_energy_block_array.append([])
		sun_energy_occupation_array.append([])
		for j in range(world_size*world_size): 
			sun_energy_block_array[i].append(0)
			sun_energy_occupation_array[i].append(0)

	for i in range(n_sun_level): 
		sun_energy_block_array[i].fill(energy_flow_in)
	#sun_energy_occupation_array.fill(0)




func build_world_shape(folder):


	make_and_instatiate_round_island(47,120,12,folder)	
	
	make_and_instatiate_round_island(140,140,20,folder)
	
	make_and_instatiate_round_island(124,124,12,folder)
	make_and_instatiate_round_island(76,124,12,folder)
	make_and_instatiate_round_island(100,100,25,folder)
	make_and_instatiate_round_island(124,76,12,folder)	
	make_and_instatiate_round_island(76,76,12,folder)
	
	
	make_and_instatiate_round_island(40,40,40,folder)				
	make_and_instatiate_round_island(110,60,12,folder)	
	make_and_instatiate_round_island(115,40,12,folder)			
					
func make_and_instatiate_round_island(x,y,radius,folder):
	x=  x-radius
	y=  y-radius
	var center = Vector2(radius,radius)
	for w in range(0,radius*2+1):
		for h in range(0,radius*2+1):
			if block_element_state[(x+w)*world_size +y+h ] == 0 :
				var distance = center.distance_to(Vector2(w, h))
				if distance < radius :
						block_element_state[(x+w)*world_size +y+h ]= 1
						#set_cell(x+w, y+h, 0)
						World.InstantiateBlock(x+w,y+h,folder)
				if Vector2(w, h).distance_to(center) >= radius and Vector2(w, h).distance_to(center) < radius +2:
						block_element_state[(x+w)*world_size +y+h ]= 0
						World.InstantiateBlock(x+w,y+h,folder)
						#set_cell(x+w, y+h, 1)
			else:
				#merge temporary only
				block_element_state[(x+w)*world_size +y+h ]= 1
				#set_cell(x+w, y+h, 2)
				folder.get_node(str(x+w)+"_"+str(y+h)).BlockUpdate()
	'x=  5
	y=  125

	radius= 35
	center = Vector2(radius/2,radius/2)
	for w in range(-radius,radius*2):
		for h in range(-radius,radius*2):
			var distance = center.distance_to(Vector2(w, h))
			if distance < radius :
				block_element_state[(x+w)*world_size +y+h ]= 1
	x=  40
	y=  70
	radius= 40
	center = Vector2(radius/2,radius/2)
	for w in range(-radius,radius*2):
		for h in range(-radius,radius*2):
			var distance = center.distance_to(Vector2(w, h))
			if distance < radius :
				block_element_state[(x+w)*world_size +y+h ]= 1'
			
				
	


func Init_shader():
	rd = RenderingServer.create_local_rendering_device()
	#shader_file = load("res://Scripts//compute_worldblock.glsl")
	shader_file = load("res://Scripts//compute_sun_block.glsl")
	shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	

	

func InstantiateBlock(i,j,folder):
	if i >= 0 and j >= 0 and i < world_size and j < world_size:
		var new_block = block_scene.instantiate()
		new_block.get_node("ColorRect").size = Vector2(tile_size,tile_size)
		new_block.position.x = i*tile_size
		new_block.position.y = j*tile_size
		new_block.name =str(i)+"_"+str(j)
		folder.add_child(new_block)
		new_block.BlockUpdate()

func getWorldPos(position):
	var x = int(round(position.x/tile_size))
	var y = int(round(position.y/tile_size))
	return Vector2(x,y)

func InstantiateBlockAroundPlayer(x,y,folder):

	for i in range(-fieldofview,fieldofview):
		for j in range(-fieldofview,fieldofview):
			var xpos = x + i
			var ypos = y + j
			World.InstantiateBlock(xpos,ypos,folder)

func InstantiateBlockAroundPlayer2(x,y,folder,zoom):
	fieldofview = round(fieldofview / zoom)
	for i in range(-fieldofview.x,fieldofview.x):
		for j in range(-fieldofview.y,fieldofview.y):
			var xpos = x + i
			var ypos = y + j
			World.InstantiateBlock(xpos,ypos,folder)


func InstantiateALLBlock(folder):
	for i in range(0,world_size):
		for j in range(0,world_size):
			var xpos =  i
			var ypos =  j
			World.InstantiateBlock(xpos,ypos,folder)





func ActivateAndDesactivateBlockAround(direction,x,y,allblocks):
	var playerpos = Vector2(x,y)
		
	if direction.x > 0 :
		var leftblocks = allblocks.filter(getLeftBlock.bind(playerpos))
		for b in leftblocks:
			var b_pos = b.position.x + fieldofview.x*2*tile_size
			b.position.x = min(world_size*tile_size-1, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()	

	
	if direction.x < 0:
		var rightblocks = allblocks.filter(getRightBlock.bind(playerpos))
		for b in rightblocks:
			var b_pos = b.position.x - fieldofview.x*2*tile_size
			b.position.x = max(0, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()
			
	if direction.y < 0:
		var bottomblocks = allblocks.filter(getBottomBlock.bind(playerpos))
		for b in bottomblocks:
			var b_pos = b.position.y - fieldofview.y*2*tile_size
			b.position.y = max(0, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()
	if direction.y > 0:	
		var topblocks = allblocks.filter(getTopBlock.bind(playerpos))
		for b in topblocks:
			var b_pos = b.position.y + fieldofview.y*2*tile_size
			b.position.y =  min(world_size*tile_size-1, b_pos)
			var newpos = getWorldPos(b.position)
			var newposindex = newpos.y*World.world_size + newpos.x
			b.posindex = newposindex
			b.BlockUpdate()

	

	




func getRightBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.x >  fieldofview.x*2 - 1:
		return blockpos.x > (playerpos.x + fieldofview.x)
	else:
		return false

func getBottomBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.y >  fieldofview.y*2 - 1:
		return blockpos.y > (playerpos.y + fieldofview.y)
	else:
		return false

func getTopBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.y < world_size - fieldofview.y*2:
		return blockpos.y < (playerpos.y - fieldofview.y)
	else:
		return false



func getLeftBlock(block,playerpos):
	var blockpos = getWorldPos(block.position)
	if blockpos.x < world_size - fieldofview.x * 2:
		return blockpos.x < (playerpos.x - fieldofview.x)
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
	

	World.block_diffusion_par = [diffusion_factor,diffusion_number,diffusion_min_limit,diffusion_block_limit]

	var BlockArraybuffer_par = init_buffer(World.block_diffusion_par)
	var Blockuniform1 = init_uniform(BlockArraybuffer_par,2)
	
	var BlockArraybuffer1 = init_buffer(World.block_element_state)
	var Blockuniform2 = init_uniform(BlockArraybuffer1,3)
	
	#bind them
	var uniform_set := rd.uniform_set_create([Blockuniform,Blockuniform0,Blockuniform1,Blockuniform2], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list,World.block_element_array.size()/32, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(BlockArraybuffer)
	var output := output_bytes.to_float32_array()
	World.block_element_array = output	



func add_energy_in_sun_level():
	sun_energy_block_array[0].fill(energy_flow_in)
	for l in range(1,n_sun_level):
		for i in range(sun_energy_block_array[l].size()):
			sun_energy_block_array[l][i] = sun_energy_block_array[l-1][i] - sun_energy_occupation_array[l-1][i]



func SunLayerFillGPU():
	sun_energy_block_array[0].fill(energy_flow_in)
	sun_energy_block_array[1].fill(energy_flow_in)
	sun_energy_block_array[2].fill(energy_flow_in)
	var uniform_array = []
	


	var sun_energy_block_array_buffer_0 = init_buffer(sun_energy_block_array[0])
	var sun_energy_occupation_array_buffer_0 = init_buffer(sun_energy_occupation_array[0])

	
	var Occupationuniform_0 = init_uniform(sun_energy_occupation_array_buffer_0,0)	
	var Energyuniform_0 = init_uniform(sun_energy_block_array_buffer_0,1)	
	uniform_array.append(Occupationuniform_0)
	uniform_array.append(Energyuniform_0)
	
	var sun_energy_block_array_buffer_1 = init_buffer(sun_energy_block_array[1])
	var sun_energy_occupation_array_buffer_1 = init_buffer(sun_energy_occupation_array[1])
	
	var Occupationuniform_1 = init_uniform(sun_energy_occupation_array_buffer_1,2)	
	var Energyuniform_1 = init_uniform(sun_energy_block_array_buffer_1,3)	
	uniform_array.append(Occupationuniform_1)
	uniform_array.append(Energyuniform_1)
	
	var sun_energy_block_array_buffer_2 = init_buffer(sun_energy_block_array[2])
	var sun_energy_occupation_array_buffer_2 = init_buffer(sun_energy_occupation_array[2])

	var Occupationuniform_2 = init_uniform(sun_energy_occupation_array_buffer_2,4)	
	var Energyuniform_2 = init_uniform(sun_energy_block_array_buffer_2,5)	
	uniform_array.append(Occupationuniform_2)
	uniform_array.append(Energyuniform_2)
	#bind them
	var uniform_set := rd.uniform_set_create(uniform_array, shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	##########33
	rd.compute_list_dispatch(compute_list,World.sun_energy_block_array[0].size()/32, 1, 1)
	#########################
	
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer

	var output_bytes := rd.buffer_get_data(sun_energy_block_array_buffer_1)
	var output := output_bytes.to_float32_array()
	sun_energy_block_array[1] = output	
	
	var output_bytes2 := rd.buffer_get_data(sun_energy_block_array_buffer_2)
	var output2 := output_bytes2.to_float32_array()
	sun_energy_block_array[2] = output2	



