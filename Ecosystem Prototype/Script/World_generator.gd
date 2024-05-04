'''
This Script deal with block and world generator

For optimisation purpose the block system are not using godot game engine physics.

One block have different variables:
	ID (in case)
	Position X
	Position Y
	Density Z (0 to 1, how much it slow mouvement 1 means cannot go there)
	Color (a list of different color the block can have )
	Elements (array of different component used by Life entities. )
	

Element have different variable and state:
	ID /index in block
	State: 0 (solid), 1 (liquid),2 (gas) ; according to its state it will move to different Sphere (Hydro, Litho, Atmo) at a certain rate
	
	I start with 10 elements: 3 liquide, 4 solid, 3 gas
	Element can be transform into each other at certain condition.
	Life need at least 1 gas, 1 liquid and 1 solid to survive
'''

extends Node2D


'NOT USE'
var element_saturation = [100,100,100,100,100,100,100,100,100,100] #above this number element "change state", it transform itself in another element
var element_saturation_transition = [9,0,0,0,1,2,3,4,5,6] #to which element they change
var element_min_temperature = [0,0,0,0,1,2,3,4,5,6] #below this number element "change state", it transform itself in another element
var element_max_temperature = [0,0,0,0,1,2,3,4,5,6] #above this number element "change state", it transform itself in another element
var element_min_temp_transition = [0,1,2,3,4,5,6,7,8,9] #to which element they change
var element_max_temp_transition = [0,1,2,3,4,5,6,7,8,9] #to which element they change




var block_scene = load("res://Scene/world_block.tscn")
#block parameter: ID, Density, Color, Elements


#stone
var stone_element = [0,0,0,0,0,0,0,0,0,0]


var maxenergy_forcolor = 10.
var colormax = Color(0.3, 0.2, 0.1, 1)
var colormin = Color(0.8, 0.6, 0.4, 1)


#debug
var sum0 = 0


# Load GLSL shader

var rd := RenderingServer.create_local_rendering_device()
var shader_file := load("res://Script//compute_spheretoblock.glsl")
var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
var shader := rd.shader_create_from_spirv(shader_spirv)


# Called when the node enters the scene tree for the first time.
func _ready():
	
	$Timer.wait_time = 1 / World.World_Speed
	BuildWorld()
	

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for b in World.Block_to_update:
		UpdateInstantiateBlock(b[0],b[1])
	World.Block_to_update = []
	#ElementTransform()
	pass

func BuildWorld():
	InitWorldMatrix()
	InitBlockType()


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


func FromSphereToBlocksGPU():
	

	# Prepare our data.
	var BlockMatrixbuffer = init_buffer(World.Block_Matrix)
	var BlockMatrixuniform = init_uniform(BlockMatrixbuffer,0)	
	
	var SphereBuffer = init_buffer(World.Abioticsphere)
	var Elementuniform = init_uniform(SphereBuffer,1)
	
	var buffer1 = init_buffer(World.element_flow_in)
	var Flowinuniform = init_uniform(buffer1,2)
	
	var buffer2 =init_buffer(World.element_flow_out)
	var Flowoutuniform = init_uniform(buffer2,3)
	
	var buffer3 = init_buffer(World.element_flow_btw)
	var Flowbtwuniform = init_uniform(buffer3,4)
	
	var buffer4 = init_buffer(World.Block_Matrix)
	var bbuniform = init_uniform(buffer4,5)
	
	var buffer5 = init_buffer(World.element_flow_btw_min)
	var uniform5 = init_uniform(buffer5,6)
	
	var Elementbuffer0 = init_buffer(World.Abioticsphere)
	var Elementuniform0 = init_uniform(Elementbuffer0,7)
	
	var Elementbuffer1 = init_buffer_int([World.worldsize])
	var Elementuniform1 = init_uniform(Elementbuffer0,8)
	#bind them
	var uniform_set := rd.uniform_set_create([BlockMatrixuniform,Elementuniform,Flowinuniform,Flowoutuniform,Flowbtwuniform,bbuniform,uniform5,Elementuniform0,Elementuniform1], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd.compute_pipeline_create(shader)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list,ceil(World.Block_Matrix.size()/32), 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	# Read back the data from the buffer
	var output_bytes := rd.buffer_get_data(BlockMatrixbuffer)
	var output := output_bytes.to_float32_array()
	World.Block_Matrix = output
	
'	var output_bytes2 := rd.buffer_get_data(SphereBuffer)
	var output2 := output_bytes2.to_float32_array()
	World.Abioticsphere = output2'
	

	
	#sphere_buffer.data[gid % lengthElement] =  total; //element_flow_out.data[gid % lengthElement]*blockmatrix_buffer_0.data[gid]; // - qtetogive;

	#sphere_buffer.data[gid % lengthElement] =  blockmatrix_buffer_0.data[gid]; //element_flow_out.data[gid % lengthElement]*blockmatrix_buffer_0.data[gid]; // - qtetogive;



	

func InitWorldMatrix():
	
	World.Block_Matrix.resize(World.worldsize*World.worldsize*stone_element.size())
	
	#World.Block_Matrix_ElementState.resize(World.worldsize*World.worldsize*stone_element.size())
'	for i in range(World.Map_size[0]):
		World.Block_Matrix[i]=[]
		World.Block_Matrix[i].resize(World.Map_size[1])'
	
		 # Replace with function body.

func InitBlockType():
	var stonesize =  World.instantiateRange + 2
	var watersize = 2 + stonesize
	var index=0	

	for i in range(World.worldsize):
		for j in range(World.worldsize):
			for e in range(stone_element.size()):
					World.Block_Matrix[i*World.worldsize*stone_element.size()+e+j*stone_element.size()] = 0
					if e == 0:
						World.Block_Matrix[i*World.worldsize*stone_element.size()+e+j*stone_element.size()] = 10
					if e == 4 or e == 1:
						World.Block_Matrix[i*World.worldsize*stone_element.size()+e+j*stone_element.size()] = 10


	
'func FromSphereToBlocks(sphere,stateID):
	var NumberofBlock = World.Map_size[0]*World.Map_size[1]
	var maxtransfer = 0
	var total = sphere.duplicate(true)
	for i in range(World.Map_size[0]):
		for j in range(World.Map_size[1]):
			var index=0
			for e in element_state:
				maxtransfer = min(sphere[index], element_flow*NumberofBlock)
				if e== stateID:
						World.Block_Matrix[i][j][3][index] += maxtransfer/NumberofBlock
						sphere[index] -= maxtransfer/NumberofBlock
						World.Block_to_update.append([i,j])
				index +=1'


func RemoveOutScreenInstantiatedBlock(player_pos,distance):
	player_pos = Vector2i(player_pos/World.tile_size)
	var count = 0
	for n in get_children():
		if n.name != "Timer":
			var n_pos = Vector2i(n.position/World.tile_size)
			if  n_pos[1] < int(player_pos[1])-World.instantiateRange-distance:
				n.queue_free() 
			if n_pos[1] > int(player_pos[1])+World.instantiateRange+distance:
				n.queue_free() 
			if  n_pos[0] > int(player_pos[0])+World.instantiateRange+distance:
				n.queue_free()
			if  n_pos[0] < int(player_pos[0])-World.instantiateRange-distance:
				n.queue_free()

func instantiateBlockClose(player_pos, dir_vector, distance):
	player_pos = Vector2i(player_pos/World.tile_size)

	if dir_vector[0]>0:	
		for i in range(player_pos[0]+World.instantiateRange-distance, player_pos[0]+World.instantiateRange+distance):
			for j in range(player_pos[1]-World.instantiateRange+1,player_pos[1]+World.instantiateRange):
				if has_node(str(i)+"_"+str(j)) == false:
					InstantiateBlock(i,j)
	if dir_vector[0]<0:	
		for i in range(player_pos[0]-World.instantiateRange-distance+1, player_pos[0]-World.instantiateRange+distance):
			for j in range(player_pos[1]-World.instantiateRange+1,player_pos[1]+World.instantiateRange):
				if has_node(str(i)+"_"+str(j)) == false:
					InstantiateBlock(i,j)
				
	if dir_vector[1]>0:	
		for j in range(player_pos[1]+World.instantiateRange-distance, player_pos[1]+World.instantiateRange+distance):
			for i in range(player_pos[0]-World.instantiateRange+1,player_pos[0]+World.instantiateRange):
				if has_node(str(i)+"_"+str(j)) == false:
					InstantiateBlock(i,j)
	if dir_vector[1]<0:	
		for j in range(player_pos[1]-World.instantiateRange-distance+1, player_pos[1]-World.instantiateRange+distance):
			for i in range(player_pos[0]-World.instantiateRange+1,player_pos[0]+World.instantiateRange):
				if has_node(str(i)+"_"+str(j)) == false:
					InstantiateBlock(i,j)


func instantiateClose(player_pos, dir_vector):
	player_pos = Vector2i(player_pos/World.tile_size)
	for n in get_children():
		if n.name != "Timer":
			var n_pos = Vector2i(n.position/World.tile_size)
			if  n_pos[1] < int(player_pos[1])-World.instantiateRange-1*dir_vector[1]:
				n.queue_free() 
			if n_pos[1] > int(player_pos[1])+World.instantiateRange-1*dir_vector[1]:
				n.queue_free() 
			if  n_pos[0] > int(player_pos[0])+World.instantiateRange-1*dir_vector[0]:
				n.queue_free()
			if  n_pos[0] < int(player_pos[0])-World.instantiateRange-1*dir_vector[0]:
				n.queue_free()
	for n in range(World.instantiateRange*2):
		if dir_vector[0]!=0:	
			var i = player_pos[0] + World.instantiateRange*dir_vector[0] 
			var j = player_pos[1] - World.instantiateRange +n
			#print(str(i) + " " +str(j))
			InstantiateBlock(i,j)
		if dir_vector[1]!=0:	
			var i = player_pos[0] - World.instantiateRange +n
			var j = player_pos[1]  + World.instantiateRange*dir_vector[1]
			InstantiateBlock(i,j)


			
func instantiateNewblock(player_pos, dir_vector):
	var x = 0
	var y = 0
	player_pos = Vector2i(player_pos/World.tile_size)
	for i in range(World.instantiateRange):
		for j in range(World.instantiateRange):
			x = player_pos[0] + World.instantiateRange*2*dir_vector[0] + i
			y = player_pos[1] + World.instantiateRange*2*dir_vector[1] + j
			if get_node(str(x)+"_"+str(y)) == null:
				InstantiateBlock(x,y)
			
		
	
	if dir_vector[0]<0:
		pass
	pass
							
func InstantiateAround(player_pos):	

		player_pos = Vector2i(player_pos/World.tile_size)
		for i in range(int(player_pos[0])-World.instantiateRange,int(player_pos[0])+World.instantiateRange):
			for j in range(int(player_pos[1])-World.instantiateRange,int(player_pos[1])+World.instantiateRange):
					InstantiateBlock(i,j)

func InstantiateAllBlock():	

		for i in range(World.Map_size[0]):
			for j in range(World.Map_size[1]):
					InstantiateBlock(i,j)

					
func InstantiateBlock(i,j):
	if i >= 0 and j >= 0 and i < World.worldsize and j < World.worldsize:
		var new_block = block_scene.instantiate()
		new_block.position.x = i*World.tile_size
		new_block.position.y = j*World.tile_size
		new_block.color = getBlockColor(i,j)
		new_block.name =str(i)+"_"+str(j)
		new_block.posx = i 
		new_block.posy = j
		var debug = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 0]
		#new_block.setDebug(str("%.2f" % debug))
		add_child(new_block)
		
func UpdateInstantiateBlock(i,j):
	#if get_children().has.name()
	if get_node(str(i)+"_"+str(j)) != null:
		var block = get_node(str(i)+"_"+str(j))
		block.color = getBlockColor(i,j)

func UpdateAllInstantiateBlock():
	#if get_children().has.name()
	var i = 0
	var j = 0
	for b in get_children():
		if b.name != "Timer":
			if b.name.split("_").size()>1:				
				i = int(b.name.split("_")[0])
				j = int(b.name.split("_")[1])
				b.color = getBlockColor(i,j)
				var debug = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 0]
				#b.setDebug(str("%.2f" % debug))
	

					
func getAdjustedSoilColor(i,j):
	var x = min(1, World.Block_Matrix[i*World.Map_size[1]*stone_element.size()+j*stone_element.size()+1]/maxenergy_forcolor )
	var col = lerp(colormin, colormax, x)
	return col

func getBlockColor(i,j):
	#var b_element =[]
	var color = Color(0, 0, 0)
	var valueR = 0
	var valueG = 0
	var valueB = 0
	var count = 0
	var size = World.element_state.size()
	for e in range(World.element_state.size()):
		if World.visibleElementToggle[e]:
			color = World.color_mapping.get(e, Color(0, 0, 0))	
			valueR += min(color.r, color.r * World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + e])
			valueG += min(color.g, color.g * World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + e])
			valueB += min(color.b, color.b * World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + e])
			'var value = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + e]
			var value2 = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 1]
			var value3 = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 2]
			color = Color(value/10,value2/10,value3/10)'
			count += 1
	if count >0:
		color = Color(valueR,valueG,valueB)
	#print("final color :" + str(color))
	return color

func UpdateAround(player_pos, tiles_array):	
		player_pos = Vector2i(player_pos/World.tile_size)
		for i in range(int(player_pos[0])-World.instantiateRange,int(player_pos[0])+World.instantiateRange):
			for j in range(int(player_pos[1])-World.instantiateRange,int(player_pos[1])+World.instantiateRange):
				if tiles_array.has([i,j]):
					UpdateInstantiateBlock(i,j)



func GeoChemicalCycle():
	'This function describe the flow of element'
	var index = 0
	var totransfer = 0
	for e in World.element_state:
		'if e == 0: #solid
			Lithosphere[index] += max(0,min(element_flow,Hydroshpere[index]) + min(element_flow , Atmosphere[index]))
			Hydroshpere[index] = max(0,Hydroshpere[index] - element_flow)
			Atmosphere[index] = max(0,Atmosphere[index] - element_flow)	

			#FromSphereToBlocks(World.Lithosphere,0)
			FromSphereToBlocksGPU()
		if e == 1: #liquid
			Hydroshpere[index] += max(0,min(element_flow,Lithosphere[index]) + min(element_flow , Atmosphere[index]))
			Lithosphere[index] = max(0,Lithosphere[index] - element_flow)
			Atmosphere[index] = max(0,Atmosphere[index] - element_flow)	'

		if e == 2: #gas
			
			World.Atmosphere[index] += max(0,min(World.element_flow_in[index],World.Hydroshpere[index]) + min(World.element_flow_in[index] , World.Lithosphere[index]))
			World.Hydroshpere[index] = max(0,World.Hydroshpere[index] - World.element_flow_in[index])
			World.Lithosphere[index] = max(0,World.Lithosphere[index] - World.element_flow_in[index])	
			
			FromSphereToBlocksGPU()
			#print(str(World.Block_Matrix[0]) + " " + str(World.Block_Matrix[9]))
			#print(World.Abioticsphere)


		index += 1

func UpdateSimulationSpeed():
	#$Timer.wait_time = 1 / World.World_Speed
	$Timer.start(0)

func _on_timer_timeout():
	pass

	#FromSphereToBlocksGPU()

	#UpdateAllInstantiateBlock()


'	var sum = 0
	for element in World.Block_Matrix :
		sum += element

	print(sum)
	sum0 = sum'
	#print(World.Abioticsphere)
	#GeoChemicalCycle() 
