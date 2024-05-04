'This Script handle life entities generation and updates

#Life parameter: Genome, PV, Energy, Life_state, Sprite
#Life Genome : G_ID, SpriteList, MoveSpeed, Size, Strength, foodtype, energyLifeCycleCost ,agelimit, energyHomeostasisCost, metabospeed
#Life Brain : TODO
'

extends Node2D

var tiles_to_update = []

var life_scene = load("res://Scene/life_entity.tscn")
var life_array = []
var life_array_to_delete = []
var timercount = 0

#Life parameter: Genome, PV, Energy, Life_state, PosX, PosY
#this is parameter index, just to be less lost with indexing
var pi_PV = Life.pi_PV
#var pi_Elements = Life.pi_Elements
#var pi_LifeState = Life.pi_LifeState
#var pi_Energy = Life.pi_Energy
var pi_PosX = Life.pi_PosX
var pi_PosY = Life.pi_PosY
var pi_SizeX = Life.pi_SizeX
var pi_SizeY = Life.pi_SizeY
#var pi_isAlive = Life.pi_isAlive
#var pi_ToUpdate = Life.pi_ToUpdate


#Life Genome : G_ID, SpriteList, MoveSpeed, Size, Strength, foodtype, energyLifeCycleCost ,agelimit, energyHomeostasisCost, metabospeed
#this is genome index, just to be less lost with indexing
var gi_Sprite = Life.gi_Sprite
var gi_MoveSpeed = 2
var gi_Size = Life.gi_Size
var gi_InnerTimer = Life.gi_InnerTimer
var gi_ElementsIn = Life.gi_ElementsIn
var gi_ElementsBuilt= Life.gi_ElementsBuilt
var gi_ElementsOut= Life.gi_ElementsOut


#Life Brain : TODO

#Life 
#GRASS
var genome_index = 0
var grass_genome_1 = [0,["res://art/grass1.png","res://art/grass2.png","res://art/grass3.png","res://art/grass4.png"], [0], [1.,2.,2.,1.5],[2,0,0,0,0,0,0,0,0,0],[0,1,0,0,1,0,0,0,0,0],[0,0,0,0,1,0,0,0,0,0],1]
#var grass_genome_2 = [1,["res://art/grass3.png","res://art/grass4.png"], [0], [2.,1.],[[0,9],[1,1]],[[1],[1]],[[0,8],[1,1]],1]


# Load GLSL shader
var rd2 := RenderingServer.create_local_rendering_device()
var shader_file2 := load("res://Script//compute_life.glsl")
var shader_spirv2: RDShaderSPIRV = shader_file2.get_spirv()
var shader2 := rd2.shader_create_from_spirv(shader_spirv2)



# Called when the node enters the scene tree for the first time.
func _ready():
	$Timer.wait_time = .1 / World.World_Speed
	BuildLife()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func BuildLife():
	InitLifeMatrix()
	SetWorldLife()

func InitLifeMatrix():
	var maxNumberLife = Life.maximun_life_entities
	Life.Life_Matrix_Element.resize(maxNumberLife*World.element_flow_btw.size())
	Life.Life_Matrix_Element.fill(0)
	Life.Life_Matrix_PositionX.resize(maxNumberLife)
	Life.Life_Matrix_PositionX.fill(0)
	Life.Life_Matrix_PositionY.resize(maxNumberLife)
	Life.Life_Matrix_PositionY.fill(0)
	Life.Life_Matrix_Element_in.resize(maxNumberLife*World.element_flow_btw.size())
	Life.Life_Matrix_Element_in.fill(0)
	Life.Life_Matrix_Element_built.resize(maxNumberLife*World.element_flow_btw.size())
	Life.Life_Matrix_Element_built.fill(0)
	Life.Life_Matrix_Element_out.resize(maxNumberLife*World.element_flow_btw.size())
	Life.Life_Matrix_Element_out.fill(0)
	Life.Life_Matrix_Par.resize(maxNumberLife)
	Life.Life_Matrix_Par.fill(0)
	Life.Life_Matrix_Phenotype.resize(maxNumberLife*Life.ParNumber)
	Life.Life_Matrix_Phenotype.fill(0)
	Life.Life_Matrix_Genotype.resize(maxNumberLife*Life.cycleStateNumber*Life.rulesNumber)
	Life.Life_Matrix_Genotype.fill(0)
	Life.Life_Matrix_Check.resize(maxNumberLife)
	Life.Life_Matrix_Check.fill(0)


#Life parameter: Genome, PV, Energy, Elements, Life_state, Age, is Alive, PosX, PosY
func SetWorldLife():
	Life.Init_Genome()
	Life.InitSprites()
	for i in range(200):
		var newPos = PickRandomPlace()
		InitLife(i ,1, newPos[0],newPos[1])
	for j in range(200):
		var newPos = PickRandomPlace()
		j = j + 300
		InitLife(j ,0, newPos[0],newPos[1])

'		newPos = PickRandomPlace()
		par = [grass_genome_2, 1,1, [0,0,0,0,0,0,0,0,0,0], 0, 0 ,true, newPos[0],newPos[1],0]
		InitLife(par)'


func InitLife(index, genome_index, posX, posY):
		var rng = RandomNumberGenerator.new()

		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 0] = genome_index #grass genome index
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 1] = 10 #PV
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 2] = 0 #AGE
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 3] =  posX #PosX
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 4] =  posY #PosY
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 5] = 1 #SizeX
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 6] = 1 #SizeY
		Life.Life_Matrix_Phenotype[index*Life.ParNumber + 7] = 0 #Lifecycleindex
		#var par = [grass_genome_1, 1, 0 , newPos[0],newPos[1],1,1]
		#var genome_index = Life.Life_Matrix_Phenotype[index*Life.ParNumber]
		var newlife = life_scene.instantiate()
		#Life.Life_Matrix[par[pi_PosX]][par[pi_PosY]] =  par #GenomeID, PV, Energy, Life_state, posX, posY

		for e in range(World.element_flow_btw.size()):
			Life.Life_Matrix_Element[World.element_flow_btw.size()*index + e]= (Life.Life_Genome[genome_index][gi_ElementsIn][e] + Life.Life_Genome[genome_index][gi_ElementsBuilt][e]) * Life.Life_Genome[genome_index][Life.gi_GrowthCycle][0] #* Life.Life_Genome[genome_index][gi_Size][0] #par[pi_Elements][e]
			Life.Life_Matrix_Element_in[World.element_flow_btw.size()*index + e] =  Life.Life_Genome[genome_index][gi_ElementsIn][e]
			Life.Life_Matrix_Element_built[World.element_flow_btw.size()*index + e] =    Life.Life_Genome[genome_index][gi_ElementsBuilt][e]
			Life.Life_Matrix_Element_out[World.element_flow_btw.size()*index + e] =  Life.Life_Genome[genome_index][gi_ElementsOut][e]
						
		Life.Life_Matrix_PositionX[index] = (roundi(Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosX]/World.tile_size))
		Life.Life_Matrix_PositionY[index] = (roundi(Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosY]/World.tile_size))
		Life.Life_Matrix_Check[index] = 1
		

		for c in range(Life.cycleStateNumber):
				Life.Life_Matrix_Genotype[index*Life.rulesNumber*Life.cycleStateNumber + Life.gri_maxage*Life.cycleStateNumber + c] =  rng.randi_range(Life.Life_Genome[genome_index][Life.gi_MaxAge][c]-10,Life.Life_Genome[genome_index][Life.gi_MaxAge][c]+10)
				Life.Life_Matrix_Genotype[index*Life.rulesNumber*Life.cycleStateNumber + Life.gri_growthcycle*Life.cycleStateNumber + c] = Life.Life_Genome[genome_index][Life.gi_GrowthCycle][c]
				Life.Life_Matrix_Genotype[index*Life.rulesNumber*Life.cycleStateNumber + Life.gri_movespeed*Life.cycleStateNumber + c] = Life.Life_Genome[genome_index][Life.gi_MoveSpeed][c]

		
		'for p in range(par.size()):
			print(par.size())
			print(par[p])'
		#Life.Life_Matrix_Par[index] = par







func PickRandomPlace():
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(0,World.worldsize*World.tile_size)
	var random_y = rng.randi_range(0,World.worldsize*World.tile_size)
	return [random_x, random_y]

func PickRandomPlaceWithRange(centerx,centery,range):
	var rng = RandomNumberGenerator.new()

	var random_x = rng.randi_range(max(0,centerx-range),min(World.worldsize*World.tile_size,centerx+range))
	var random_y = rng.randi_range(max(0,centery-range),min(World.worldsize*World.tile_size,centery+range))

	return [random_x, random_y]




'func InstantiateLife(index):
	var i = Life.Life_Matrix_Phenotype[index][pi_PosX]
	var j = Life.Life_Matrix_Phenotype[index][pi_PosY]
	var gi = Life.Life_Matrix_Phenotype[index][0]
	if i >= 0 and j >= 0 and i < World.worldsize*World.tile_size and j < World.worldsize*World.tile_size :
		var new_life = life_scene.instantiate()
		var sprite = par[0][gi_Sprite][par[pi_LifeState]] #World.Life_Matrix[i][j][0][1][World.Life_Matrix[i][j][3]]
		var size = par[0][gi_Size][par[pi_LifeState]] #World.Life_Matrix[i][j][0][3][World.Life_Matrix[i][j][3]]
		new_life.SetSprite(sprite,size)
		new_life.position = Vector2(i,j)
		new_life.name =str(i)+"_"+str(j)
		add_child(new_life)	'			

func InstantiateLife2(index):
	var i = Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosX]
	var j = Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosY]
	var gi = Life.Life_Matrix_Phenotype[index*Life.ParNumber]
	if isOnScreen(Life.Life_Matrix_PositionX[index],Life.Life_Matrix_PositionY[index]):
		if i >= 0 and j >= 0 and i < World.worldsize*World.tile_size and j < World.worldsize*World.tile_size :
			var new_life = life_scene.instantiate()
			var sprite = Life.Life_Genome[gi][gi_Sprite][0]
			var size = Life.Life_Genome[gi][gi_Size][0]
			new_life.position = Vector2(i,j)
			new_life.name =str(index)
			new_life.INDEX = index
			new_life.SetSprite()
			add_child(new_life)	


				
func UpdateAllInstantiateLife():
	#if get_children().has.name()
	for b in get_children():
		if b.name != "Timer" and b.name != "Player":
			UpdateInstantiateLife(b,int(str(b.name)))

func UpdateInstantiateLife(life,index):
	life.SetSprite()
	pass
	#Life.Life_Matrix_Par[index][pi_PosX] = max(0 ,Life.Life_Matrix_Par[index][pi_PosX]-5)
	#life.position = Vector2(Life.Life_Matrix_Par[index][pi_PosX],Life.Life_Matrix_Par[index][pi_PosY])
	pass
	
func getCenter(i,j,size):		
	return  [i + World.life_size_unit*size/2 , j + World.life_size_unit*size/2  ]
		
		

func InstantiateAround(player_pos):
	player_pos = Vector2i(player_pos/World.tile_size)
	var index = 0;	
	for x in Life.Life_Matrix_PositionX:	
		if x > player_pos[0]-World.instantiateRange and x < player_pos[0]+ World.instantiateRange:
			if Life.Life_Matrix_PositionY[index] > player_pos[1]-World.instantiateRange and Life.Life_Matrix_PositionY[index] < player_pos[1]+ World.instantiateRange:
					InstantiateLife2(index)
		index += 1

func DeleteOutofScreen(player_pos,distance):
	player_pos = Vector2i(player_pos/World.tile_size)
	for n in get_children():
		if n.name != "Timer" and n.name != "Player":
			var n_pos = Vector2i(n.position/World.tile_size)
			if  n_pos[1] < int(player_pos[1])-World.instantiateRange-distance:
				n.queue_free() 
			if n_pos[1] > int(player_pos[1])+World.instantiateRange+distance:
				n.queue_free() 
			if  n_pos[0] > int(player_pos[0])+World.instantiateRange+distance:
				n.queue_free()
			if  n_pos[0] < int(player_pos[0])-World.instantiateRange-distance:
				n.queue_free()
				
func isOnScreen(posx,posy,distance=2):
	var player_pos = Vector2i($Player.position/World.tile_size)
	var value = true
	if  posy < int(player_pos[1])-World.instantiateRange-distance:
		value = false 
	if posy > int(player_pos[1])+World.instantiateRange+distance:
		value = false 
	if  posx > int(player_pos[0])+World.instantiateRange+distance:
		value = false
	if  posx < int(player_pos[0])-World.instantiateRange-distance:
		value = false
	return (value)

func instantiateClose(player_pos, dir_vector,distance):
	player_pos = Vector2i(player_pos/World.tile_size)
				
	var index = 0;	
	for x in Life.Life_Matrix_PositionX:
		if Life.Life_Matrix_Check[index] != 0:
			if dir_vector[0]!=0:	
				var min = min(player_pos[0] + (World.instantiateRange+distance)*dir_vector[0],player_pos[0] + (World.instantiateRange)*dir_vector[0])
				var max = max(player_pos[0] + (World.instantiateRange+distance)*dir_vector[0],player_pos[0] + (World.instantiateRange)*dir_vector[0])
				if x > min and x < max:
					if Life.Life_Matrix_PositionY[index] > player_pos[1]-World.instantiateRange and Life.Life_Matrix_PositionY[index] < player_pos[1]+ World.instantiateRange:
						InstantiateLife2(index)
			if dir_vector[1]!=0:	
				var min = min(player_pos[1] + (World.instantiateRange+distance)*dir_vector[1],player_pos[1] + (World.instantiateRange)*dir_vector[1])
				var max = max(player_pos[1] + (World.instantiateRange+distance)*dir_vector[1],player_pos[1] + (World.instantiateRange)*dir_vector[1])
				if Life.Life_Matrix_PositionY[index] > min and Life.Life_Matrix_PositionY[index] < max:
					if x > player_pos[0]-World.instantiateRange and x < player_pos[0]+World.instantiateRange:
						InstantiateLife2(index)
		
		index += 1
		
func InstantiateAll():
	var index= 0
	for l in Life.Life_Matrix_Check:
		if l != 0:
			InstantiateLife2(index)
		index += 1
		

func init_buffer(A):
	var input := PackedFloat32Array(A)
	var input_bytes := input.to_byte_array()
	var Buffer := rd2.storage_buffer_create(input_bytes.size(), input_bytes)
	return Buffer

func init_buffer_int(A):
	var input := PackedInt32Array(A)
	var input_bytes := input.to_byte_array()
	var Buffer := rd2.storage_buffer_create(input_bytes.size(), input_bytes)
	return Buffer
	
func init_uniform(Buffer, binding):

	var Uniform := RDUniform.new()
	Uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	Uniform.binding = binding # this needs to match the "binding" in our shader file
	Uniform.add_id(Buffer)
	return (Uniform)


func LifeGPU():
	
	# Prepare our data.
	var BlockMatrixbuffer = init_buffer(World.Block_Matrix)
	var BlockMatrixuniform = init_uniform(BlockMatrixbuffer,0)	
	
	var LifeMatrixBuffer = init_buffer(Life.Life_Matrix_Element)
	var LifeMatrixuniform = init_uniform(LifeMatrixBuffer,1)
	

	var bufferX = init_buffer_int(Life.Life_Matrix_PositionX)
	var posXuniform = init_uniform(bufferX,2)
	
	var bufferY =init_buffer_int(Life.Life_Matrix_PositionY)
	var posYuniform = init_uniform(bufferY,3)
	

	var bufferIN =init_buffer(Life.Life_Matrix_Element_in)
	var INuniform = init_uniform(bufferIN,4)
	
	var bufferBT =init_buffer(Life.Life_Matrix_Element_built)
	var BTuniform = init_uniform(bufferBT,5)
	
	var bufferOUT =init_buffer(Life.Life_Matrix_Element_out)
	var OUTuniform = init_uniform(bufferOUT,6)
	
	var LifeParbuffer =init_buffer(Life.Life_Matrix_Phenotype)
	var LifeParuniform = init_uniform(LifeParbuffer,7)

	var LifeCheckbuffer = init_buffer(Life.Life_Matrix_Check)
	var LifeCheckuniform = init_uniform(LifeCheckbuffer,8)

	var LifeGenebuffer = init_buffer(Life.Life_Matrix_Genotype)
	var LifeGeneuniform = init_uniform(LifeGenebuffer,9)
	
	var uniform_set := rd2.uniform_set_create([BlockMatrixuniform,LifeMatrixuniform,posXuniform,posYuniform,INuniform,BTuniform,OUTuniform,LifeParuniform,LifeCheckuniform,LifeGeneuniform], shader2, 0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	var pipeline := rd2.compute_pipeline_create(shader2)
	var compute_list := rd2.compute_list_begin()
	rd2.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd2.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	#rd2.compute_list_dispatch(compute_list,ceil(Life.Life_Matrix_PositionX.size()/32), 1, 1)
	rd2.compute_list_dispatch(compute_list,ceil(Life.Life_Matrix_PositionX.size()/32), 1, 1)
	rd2.compute_list_end()

	# Submit to GPU and wait for sync
	rd2.submit()
	rd2.sync()

	# Read back the data from the buffer
	var output_bytes := rd2.buffer_get_data(BlockMatrixbuffer)
	var output := output_bytes.to_float32_array()
	World.Block_Matrix = output
	
	var output_bytes2 := rd2.buffer_get_data(LifeMatrixBuffer)
	var output2 := output_bytes2.to_float32_array()
	Life.Life_Matrix_Element = Array(output2)

	var output_bytes3 := rd2.buffer_get_data(LifeCheckbuffer)
	var output3 := output_bytes3.to_float32_array()
	Life.Life_Matrix_Check = Array(output3)

	var output_bytes4 := rd2.buffer_get_data(LifeParbuffer)
	var output4 := output_bytes4.to_float32_array()
	Life.Life_Matrix_Phenotype = Array(output4)

func DuplicateLife():
	var index= 0
	var ii = 0
	while index >= 0:
		index = Life.Life_Matrix_Check.find(2.0)
		if index >= 0:
			ii = Life.Life_Matrix_Check.find(0.0)
			if ii >= 0:
					var x = Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosX]
					var y = Life.Life_Matrix_Phenotype[index*Life.ParNumber + pi_PosY]
					var newPos = PickRandomPlaceWithRange(x,y,World.tile_size*2)
					var genome_index = Life.Life_Matrix_Phenotype[index*Life.ParNumber]
					InitLife(ii,genome_index,newPos[0],newPos[1])
					
					Life.Life_Matrix_Check[index] = 1
					for e in range(World.element_flow_btw.size()):
						Life.Life_Matrix_Element[index*World.element_flow_btw.size()+e] -= Life.Life_Matrix_Genotype[index*Life.rulesNumber*Life.cycleStateNumber + Life.gri_growthcycle*Life.cycleStateNumber + 0]*2*(Life.Life_Matrix_Element_built[index*10+e] - Life.Life_Matrix_Element_out[index*10+e])
					InstantiateLife2(ii)
					

			else:
				print("maximun life reached")
				index = -1
	#index += 1

func DeleteLife():
	var index = 0
	while index >= 0:
		index = Life.Life_Matrix_Check.find(-1.0)
		if index >= 0:
			Life.Life_Matrix_Check[index]= 0
			var x = Life.Life_Matrix_PositionX[index]
			var y = Life.Life_Matrix_PositionY[index]
			'for e in range(World.element_flow_btw.size()):
				World.Block_Matrix[x*World.element_flow_btw.size()*World.worldsize + y*World.element_flow_btw.size()]'
			if has_node(str(index)):
				get_node(str(index)).queue_free()
	
	
'	life_array_to_delete = []
	timercount += 1
	World.Block_to_update = []
	#print(World.Abioticsphere)
	
	for l in life_array:
		if timercount % l[0][gi_InnerTimer]  == 0:
			if l[pi_isAlive]:
				Life.TakeBlockElement(l)
				#Life.TakeSphereElement(l)
				Life.ProduceEnergy(l)
				Life.MetabolicCost(l)
				#Life.CheckDeath(l)
			if l[pi_isAlive] == false:
				Life.Dying(l)			
			if l[pi_ToUpdate]:
				UpdateInstantiateLife(l)
				l[pi_ToUpdate] = 0
			if Life.isDead(l):
				life_array_to_delete.append(l)		
		if get_node(str(l[pi_PosX])+"_"+str(l[pi_PosY])) != null:
				get_node(str(l[pi_PosX])+"_"+str(l[pi_PosY])).get_node("DebugLabel").text = (str(l[pi_Energy]) +"\n" + str(l[pi_Elements]))
	
	for d in life_array_to_delete:
		life_array.erase(d)
		if get_node(str(d[pi_PosX])+"_"+str(d[pi_PosY])) != null:
			get_node(str(d[pi_PosX])+"_"+str(d[pi_PosY])).queue_free()
'
 # Replace with function body.
