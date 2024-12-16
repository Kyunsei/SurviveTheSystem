extends Node

'This is the global Script for all the variable and function defining the Life'
var player_skin = [load("res://Art/player_bulbi.png"),load("res://Art/player_cat.png")]
var player_skin_ID = 0
var player = null

var life_size_unit = 32
#var life_scene = preload("res://Scenes/life.tscn") #load scene of block
var life_grass_scene = load("res://Scenes/life_grass.tscn")
var life_spiky_grass_scene = load("res://Scenes/life_spiky_grass.tscn")
var life_sheep_scene = load("res://Scenes/life_sheep.tscn")
var life_berry_scene = load("res://Scenes/life_berry.tscn")
var life_cat_scene = load("res://Scenes/life_cat.tscn")
var life_stingtree_scene = load("res://Scenes/life_stingtree.tscn")
var life_spidercrab_scene = load("res://Scenes/life_spidercrab.tscn")
var spidercrab_leg_scene = load("res://Scenes/sublife_spidercrab_leg.tscn")
var spidercrab_claw_scene = load("res://Scenes/sublife_spidercrab_claw.tscn")
var petal_scene = load("res://Scenes/sublife_spiky_grass_petal.tscn")
var life_debug_scene = load("res://Scenes/life_debug.tscn")
var life_jellybee_scene = load("res://Scenes/life_jellybee.tscn")
var life_rock_scene = load("res://Scenes/rock.tscn")

var parameters_array = [] 
var state_array = [] 
var world_matrix = []
var par_number = 9 # 0: Genome_ID, 1: PV, 2: Element, 3: LifeCycle, 4: DirectionX, 5: DirectionY, 6: positionX, 7: positionnY, 8: Age
var Genome = {}

var plant_number = 0
var sheep_number = 0
var spidercrab_number = 0
var berry_number = 0
var player_number = 0
var cat_number = 0
var stingtree_number = 0
var crab_leg_number = 0

var char_selected = "cat"
var player_index = 0

var max_life = 1000
var new_max_life = 0

var score = 0

##VARIABLE for BATCH instance
var new_lifes = []
var new_lifes_position = []
var life_to_spawn = []
var life_to_spawn_position =[]
var current_batch = 0.
var nb_by_batch = 1.
var min_time_by_batch = .001 #in sec

#variable for pooling
var life_scene = {
	'grass': load("res://Scenes/life_grass.tscn"),
	'spiky_grass': load("res://Scenes/life_spiky_grass.tscn"),
	'sheep' : load("res://Scenes/life_sheep.tscn"),
	'berry' : load("res://Scenes/life_berry.tscn"),
	'cat' : load("res://Scenes/life_cat.tscn"),
	'stingtree' : load("res://Scenes/life_stingtree.tscn"),
	'spidercrab' : load("res://Scenes/life_spidercrab.tscn"),
	'sc_boss' : load("res://Scenes/spidercrab_boss_prototype.tscn"),
	'jellybee' : load("res://Scenes/life_jellybee.tscn")
}

var life_number = {
	"cat" : 0,
	"grass": 0,
	"spiky_grass":0,
	"spidercrab": 0,
	"sc_boss": 0,
	"sheep": 0,
	"jellybee": 0,
	"berry": 0,
	"stingtree":0
}

var pool_state = {
	"cat" : [],
	"grass": [],
	"spiky_grass": [],
	"spidercrab": [],
	"sc_boss":[],
	"sheep": [],
	"jellybee": [],
	"berry": [],
	"stingtree":[]
}

var pool_scene = {
	"cat" : [],
	"slime" : [],
	"grass": [],
	"spiky_grass": [],
	"spidercrab": [],
	"sc_boss":[],
	"sheep": [],
	"jellybee": [],
	"berry": [],
	"stingtree":[]
}


func Calculate_score():
	score += 1


	
'func Instantiate_emptyLife_pool_in_Batch(folder,current_batch,nb_by_call):
	for i in range(current_batch,current_batch + nb_by_call):
			var nl = life_grass_scene.instantiate() #need to write code according to genome ID
			grass_pool_state.append(0)
			nl.position = Vector2(-100,-100)#Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
			nl.pool_index = i
			grass_pool_scene.append(nl)
			folder.add_child(nl)'


func Init_life_pool(folder):


	for i in pool_scene:
		pool_scene[i] = []
	for i in pool_state:
		pool_state[i] = []
	for i in life_number:
		life_number[i] = 0
		

	Life.Instantiate_emptyLife_pool(folder, 3500, "grass")

	Life.Instantiate_emptyLife_pool(folder, 100, "spiky_grass")
	Life.Instantiate_emptyLife_pool(folder, 10, "sheep")
	Life.Instantiate_emptyLife_pool(folder, 100, "berry")
	Life.Instantiate_emptyLife_pool(folder, 3, "cat")
	Life.Instantiate_emptyLife_pool(folder, 100, "stingtree")
	Life.Instantiate_emptyLife_pool(folder, 10, "spidercrab")
	Life.Instantiate_emptyLife_pool(folder, 2, "sc_boss")
	Life.Instantiate_emptyLife_pool(folder, 30, "jellybee")
	
	



#THIS ONE IS USED
func Instantiate_emptyLife_pool(folder, N, ID):

	for i in range(0,N):
		var nl = life_scene[ID].instantiate()
		nl.position = Vector2(-100,-100)
		pool_state[ID].append(0)
		pool_scene[ID].append(nl)
		nl.pool_index = i	
		folder.add_child(nl)

	'var nl = 0
			if ID == "grass":
				nl = life_grass_scene.instantiate() #need to write code according to genome ID
				grass_pool_state.append(0)
				nl.position = Vector2(-100,-100)#Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
				nl.pool_index = i
				grass_pool_scene.append(nl)
			if ID == "spiky_grass":
				nl = life_spiky_grass_scene.instantiate() #need to write code according to genome ID
				spiky_grass_pool_state.append(0)
				#nl.position = Vector2(-100,-100)#Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
				nl.pool_index = i
				spiky_grass_pool_scene.append(nl)
			if ID == "sheep":
				nl = life_sheep_scene.instantiate() #need to write code according to genome ID
				sheep_pool_state.append(0)
				sheep_pool_scene.append(nl)
			if ID == "berry":	
				nl = life_berry_scene.instantiate() #need to write code according to genome ID
				berry_pool_state.append(0)
				berry_pool_scene.append(nl)
			if ID == "cat":	
				nl = life_cat_scene.instantiate() #need to write code according to genome ID
				cat_pool_state.append(0)
				cat_pool_scene.append(nl)
			if ID == "stingtree":	
				nl = life_stingtree_scene.instantiate() #need to write code according to genome ID
				stingtree_pool_state.append(0)
				stingtree_pool_scene.append(nl)
			if ID == "spidercrab":	
				nl = life_spidercrab_scene.instantiate() #need to write code according to genome ID
				spidercrab_pool_state.append(0)
				spidercrab_pool_scene.append(nl)	
			if ID == "jellybee":
				nl = life_jellybee_scene.instantiate() #need to write code according to genome ID
				jellybee_pool_state.append(0)
				jellybee_pool_scene.append(nl)'		

			
	
#THIS ONE TOOO			
'func Extend_emptyLife_pool(folder, N):
	var old_size = Life.grass_pool_state.size()
	for i in range(0,N):
		
			#var nl = temp_lifes[i].instantiate()
			var nl = life_grass_scene.instantiate() #need to write code according to genome ID
			grass_pool_state.append(0)
			nl.position = Vector2(-100,-100)#Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
			nl.pool_index = i + old_size
			grass_pool_scene.append(nl)
			folder.add_child(nl)
			#nl.Activate()'

#THIS ONE is USE
'func Instantiate_Life_in_pool(folder,N,ID):
	for i in range(0,N):
		if ID == "grass":
			var li = grass_pool_state.find(0)
			Life.grass_pool_scene[li].Activate()
			#Life.grass_pool_scene[li].energy = 2
			Life.grass_pool_scene[li].age = randi_range(0,10)
			Life.grass_pool_scene[li].current_life_cycle = 0# randi_range(0,1)
			Life.grass_pool_scene[li].PV = Life.grass_pool_scene[li].Genome["maxPV"][0]
			Life.plant_number += 1	
			var newpos = PickRandomPlace() * World.tile_size
			Life.grass_pool_scene[li].global_position = newpos# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
		if ID == "spiky_grass":
			var li = spiky_grass_pool_state.find(0)
			Life.spiky_grass_pool_scene[li].Activate()
			#Life.grass_pool_scene[li].energy = 2
			Life.spiky_grass_pool_scene[li].age = randi_range(0,10)
			Life.spiky_grass_pool_scene[li].current_life_cycle = 0# randi_range(0,1)
			Life.spiky_grass_pool_scene[li].PV = Life.spiky_grass_pool_scene[li].Genome["maxPV"][0]
			#Life.plant_number += 1	
			var newpos = PickRandomPlace() * World.tile_size
			Life.spiky_grass_pool_scene[li].global_position = newpos# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))

		if ID == "sheep":	
			var li = sheep_pool_state.find(0)
			Life.sheep_pool_scene[li].Activate()
			Life.sheep_pool_scene[li].age = randi_range(0,20)
			Life.sheep_pool_scene[li].current_life_cycle = 0#2
			Life.sheep_number += 1
			Life.sheep_pool_scene[li].global_position =PickRandomPlace() * World.tile_size# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
		if ID == "jellybee":	
			var li = jellybee_pool_state.find(0)
			Life.jellybee_pool_scene[li].Activate()
			Life.jellybee_pool_scene[li].age = randi_range(0,2)
			Life.jellybee_pool_scene[li].current_life_cycle = 0#2
			#Life.sheep_number += 1
			Life.jellybee_pool_scene[li].global_position =PickRandomPlace() * World.tile_size

		if ID == "berry":	
			var li = berry_pool_state.find(0)
			Life.berry_pool_scene[li].Activate()
			Life.berry_pool_scene[li].age = randi_range(12,20)
			Life.berry_pool_scene[li].current_life_cycle = 0#randi_range(0,3)
			Life.berry_number += 1
			Life.berry_pool_scene[li].global_position =PickRandomPlace() * World.tile_size# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
		if ID == "cat":	
			var li = cat_pool_state.find(0)
			Life.cat_pool_scene[li].Activate()
			Life.cat_pool_scene[li].age = 0#randi_range(0,20)
			Life.cat_pool_scene[li].current_life_cycle = 0
			Life.cat_number += 1
			Life.cat_pool_scene[li].global_position = PickRandomPlace() * World.tile_size# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
		if ID == "stingtree":	
			var li = stingtree_pool_state.find(0)
			Life.stingtree_pool_scene[li].Activate()
			Life.stingtree_pool_scene[li].age = 0#randi_range(0,20)
			Life.stingtree_pool_scene[li].current_life_cycle = 0
			Life.stingtree_number += 1
			Life.stingtree_pool_scene[li].global_position = PickRandomPlace() * World.tile_size# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
		if ID == "spidercrab":	
			var li = spidercrab_pool_state.find(0)
			Life.spidercrab_pool_scene[li].Activate()
			Life.spidercrab_pool_scene[li].age = 0#randi_range(0,20)
			Life.spidercrab_pool_scene[li].current_life_cycle = 0
			Life.spidercrab_number += 1
			Life.spidercrab_pool_scene[li].global_position = PickRandomPlace() * World.tile_size# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))'



func build_life(ID, newposition: Vector2 = Vector2(0,0), life_cycle: int = 0):
	var life: LifeEntity
	var li = pool_state[ID].find(0)

	if li != -1:
			life = Life.pool_scene[ID][li]
			life.pool_index = li			
			life.Activate()
			life.position = newposition
			life.current_life_cycle = life_cycle
	return life


func Build_life_in_World():

	var island_center = [Vector2i(38,38),Vector2i(162,38),Vector2i(100,100),Vector2i(38,162),Vector2i(162,162)]
	var island_size = [20,20,40,20,20]
	#var island_energy = [5,5,5,5,5]
	
	build_life("cat")
	#var life2 = build_life("grass")
	#life2.position = Vector2(100*32,100*32)
	#life2.age = (90 + 44)/5'


	for i in range(island_size.size()):
	#for i in range(3):
		for n in range(0):

			var life = build_life("grass")
			if life != null:
				var pos = PickRandomPlaceWithRange(island_center[i].x,island_center[i].y,island_size[i])
				life.global_position = pos  

				life.age= 1 #randi_range(0,10)
				life.energy = 0#randi_range(2,life.maxEnergy)

		for n in range(3):

				var life = build_life("sheep")
				if life != null:
					var pos = PickRandomPlaceWithRange(island_center[i].x,island_center[i].y,island_size[i])
					life.global_position = pos  

					life.age= randi_range(0,life.lifespan)
					life.energy = 5 #randi_range(5,life.maxEnergy)
					
		for n in range(3):

			var life = build_life("berry")
			if life != null:
				var pos = PickRandomPlaceWithRange(island_center[i].x,island_center[i].y,island_size[i])
				life.global_position = pos 
				life.age = randi_range(0,life.lifespan)
				life.energy = 20
				
		for n in range(0):
			var life = build_life("spidercrab")
			if life != null:
				var pos = PickRandomPlaceWithRange(island_center[i].x,island_center[i].y,island_size[i])
				life.global_position = pos 
				life.age = 0
				life.energy = 20
	
	for i in [3,4]:
		for n in range(5):
			var life = build_life("spiky_grass")
			if life != null:
				var pos = PickRandomPlaceWithRange(island_center[i].x,island_center[i].y,island_size[i])
				life.global_position = pos 
				life.age = 5
				life.energy = 15			
	
	for n in [4]:
			var life = build_life("spidercrab")
			if life != null:
				var pos = PickRandomPlaceWithRange(island_center[n].x,island_center[n].y,island_size[n])
				life.global_position = pos
			for n2 in range(10):
				life = build_life("sheep")
				if life != null:
					var pos = PickRandomPlaceWithRange(island_center[n].x,island_center[n].y,island_size[n])
					life.global_position = pos  

					life.age= randi_range(0,life.lifespan)
					life.energy = 5 #randi_range(5,life.maxEnergy)
			
#Vector2(100,100) #
func PickRandomPlace():
	#var rng = RandomNumberGenerator.new()
	var random_x = randi_range(0,World.world_size-1)
	var random_y = randi_range(0,World.world_size-1)

	var posindex = random_y*World.world_size + random_x
	var newpos = Vector2(random_x, random_y)
	if World.block_element_state[posindex] != 1:
		newpos = PickRandomPlace()
		#newpos = Vector2(randf_range(World.world_size/2-5,World.world_size/2+5),randf_range(World.world_size/2-5,World.world_size/2+5))
	return newpos

func PickRandomPlaceWithRange(x,y,range):	
	var random_x = randi_range(max(0,x-range),min((World.world_size) ,x+range))
	var random_y = randi_range(max(0,y-range),min((World.world_size) ,y+range))
	var newpos = Vector2(random_x*World.tile_size, random_y*World.tile_size)
	if World.block_element_state[int(random_y)*World.world_size + int(random_x)] != 1:
		#newpos = PickRandomPlaceWithRange(position,range)
		newpos = PickRandomPlaceWithRange(x,y,range)  #+ Vector2(randi_range(0,8),randi_range(0,8))
		#newpos = Vector2(x*World.tile_size,y*World.tile_size)
		return newpos
	else:
		return newpos


'func Instantiate_fullLife_pool(folder, N):
	for i in range(0,N):
			#var nl = temp_lifes[i].instantiate()
			var nl = life_grass_scene.instantiate() #need to write code according to genome ID
			grass_pool_state.append(1)
			nl.position = Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
			nl.pool_index = i
			nl.age = randi_range(0,20)
			plant_number += 1
			#inactive_grass.append(nl)
			grass_pool_scene.append(nl)


			folder.add_child(nl)
			nl.Activate()'

'func setFinished():
	thread_finished = true'



'func deleteLoopCPU():
	var temp = state_array.duplicate()
	var l = 0
	while l != -1:
		l = temp.find(0)
		temp[l] += 1
		if l >= 0:
			RemoveLife(l)'


'func LifeLoopCPU(folder):
	#var s1 = Time.get_ticks_msec() 
	#this function is the main loop for life entities, will be move to GPU
	var temp = state_array.duplicate()
	new_lifes = []

	var l = 0
	while l != -1:
		l = temp.find(1)
		temp[l] += 1
		if l >= 0:
		#if parameters_array[l*par_number+0] != -1:
			if isDead(l):		
				NaturalKill(l)
			else:
				GetOlder(l)
				TakeBlockElement(l)
				Metabocost(l)
				PassiveHealing(l)
				Hunger(l)
				#if l != 0: #player		
				if isGrowthing(l):
						Growth(l)
				else:
						Duplicate(l)
						pass
	
	var temp2 = state_array.duplicate()
	l = 0
	while l != -1:
		l = temp2.find(0)
		temp2[l] += 1
		if l >= 0:
			RemoveLife(l)

	#var s2 = Time.get_ticks_msec() 
	#thread.call_deferred("wait_to_finish")
	#print("loop ended with " + str(s2-s1))
	#print(state_array)
	#print("hello?")
	#thread_finished = true
	#call_deferred("setFinished")'


'func InstantiateNewLifeBatchCPU(folder):
	#var s1 = Time.get_ticks_msec() 
	var temp = state_array.duplicate()
	new_lifes = []
	var l = 0
	#while l != -1:
	for i in range(10):
		l = temp.find(5)
		temp[l] += 1
		InstantiateLife(l,folder)'
	
'func Instantiate_NewLife_in_Batch(folder,current_batch,nb_by_call,temp_lifes,temp_lifes_position):
	for i in range(current_batch,current_batch + nb_by_call):
		if i < temp_lifes.size():
			#var nl = temp_lifes[i].instantiate()
			var nl = life_grass_scene.instantiate() #need to write code according to genome ID
			nl.position = temp_lifes_position[i]
			#nl.Activate() #test for pooling
			folder.add_child(nl)
			Life.plant_number += 1'



'func Init_matrix():
	plant_number = 0
	parameters_array.resize(max_life*par_number)
	parameters_array.fill(-1)
	world_matrix.resize(World.world_size*World.world_size)
	world_matrix.fill(-1)
	state_array.resize(max_life)
	state_array.fill(-1)'

'func Init_Parameter(INDEX,genome_index):
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) *World.tile_size
	var y = (floor(posIndex/World.world_size))*World.tile_size
	
	parameters_array[INDEX*par_number + 0] = genome_index #G_ID
	parameters_array[INDEX*par_number + 1] = Genome[genome_index]["PV"][0] #PV
	parameters_array[INDEX*par_number + 2] = Genome[genome_index]["lifecycle"][0] #ELEMENT
	parameters_array[INDEX*par_number + 3] = 0 #LIFECYCLE
	parameters_array[INDEX*par_number + 4] = 0 #DirectionX
	parameters_array[INDEX*par_number + 5] = 0 #DirectionY
	parameters_array[INDEX*par_number + 6] = x #PositionX
	parameters_array[INDEX*par_number + 7] = y #PositionY
	parameters_array[INDEX*par_number + 8] = 0 #Age
	

	
	plant_number+=1'
	
'func InstantiateEmptyLife(INDEX,folder):
	if folder.has_node(str(INDEX))==false:
			var new_life = life_scene.instantiate()
			new_life.name =str(INDEX)
			new_life.INDEX = INDEX
			folder.add_child(new_life)
	else:
		print("already instantiated")
		#new_life.name =str(INDEX)
		#new_life.INDEX = INDEX'
	
'func InstantiateLife(INDEX,folder):
	var posIndex = world_matrix.find(INDEX)
	var x = parameters_array[INDEX*par_number + 6]
	var y = parameters_array[INDEX*par_number + 7]
	state_array[INDEX] = 1
	var genome_index = parameters_array[INDEX*par_number + 0]
	if folder.has_node(str(INDEX))==false:

		#if isOnScreen(Life.Life_Matrix_PositionX[index],Life.Life_Matrix_PositionY[index]):
		if x >= 0 and y >= 0 and x < World.world_size*World.tile_size and y < World.world_size*World.tile_size :
				var new_life = life_scene.instantiate()
				new_life.position = Vector2(x,y)
				new_life.name =str(INDEX)
				new_life.INDEX = INDEX
				folder.add_child(new_life)
	else:
		var new_life2 = folder.get_node(str(INDEX))
		new_life2.position = Vector2(x,y)
		new_life2.show()
		#new_life.name =str(INDEX)
		#new_life.INDEX = INDEX'


###################################################################
#TO delete?
##########################################################3

'func Metabocost2(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var value = 1 * Genome[genome_index]["metabospeed"][current_cycle]
	var value_2 = min(value,parameters_array[INDEX*par_number+2])
	parameters_array[INDEX*par_number+2] -= value_2 

	World.element += value_2 

func Metabocost(INDEX):
		var genome_index = parameters_array[INDEX*par_number+0]
		var current_cycle = parameters_array[INDEX*par_number+3]
		var value = 1 * Genome[genome_index]["metabospeed"][current_cycle]
		var value_2 = min(value,parameters_array[INDEX*par_number+2])
		parameters_array[INDEX*par_number+2] -= value_2 
		#World.element += value_2 	
		var x = parameters_array[INDEX*par_number + 6] 
		var y = parameters_array[INDEX*par_number + 7] 
		x = int(x/World.tile_size)
		y = int(y/World.tile_size)
		var posindex = y*World.world_size + x
		posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
		if posindex >= 0:
			World.block_element_array[posindex] += value_2


func PassiveHealing(INDEX):
	var value = 1
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+1] < Genome[genome_index]["PV"][current_cycle]:
		if parameters_array[INDEX*par_number+2] > 0:
			#var value_2 = min(value,parameters_array[INDEX*par_number+2])
			#parameters_array[INDEX*par_number+2]-= value_2
			parameters_array[INDEX*par_number+1]+= value
			#World.element += value_2 

func Hunger(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+2] <= 0:
		parameters_array[INDEX*par_number+1]-= (Genome[genome_index]["PV"][current_cycle]*0.05+1) * Genome[genome_index]["metabospeed"][current_cycle]

func NaturalKill(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var sum = 0 + max(0,parameters_array[INDEX*par_number+2])
	for i in range(current_cycle+1):
		sum += Genome[genome_index]["lifecycle"][i]		
	#World.element += sum
	var x = parameters_array[INDEX*par_number + 6] 
	var y = parameters_array[INDEX*par_number + 7] 
	x = int(x/World.tile_size)
	y = int(y/World.tile_size)
	var posindex = y*World.world_size + x
	posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
	World.block_element_array[posindex] += sum
	state_array[INDEX] = 0


func GetOlder(INDEX):
	parameters_array[INDEX*par_number+8] += 1

func isDead(INDEX):
		if parameters_array[INDEX*par_number+1] <= 0:
			return true
		else:
			return false


func TakeElement(INDEX):

	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+2] <= Genome[genome_index]["maxenergy"][current_cycle]:
		var value = Genome[genome_index]["take_element"][current_cycle] * Genome[genome_index]["metabospeed"][current_cycle]
		parameters_array[INDEX*par_number+2] += min(value,World.element/plant_number)
		World.element -= min(value,World.element/plant_number)
		
func TakeBlockElement(INDEX):

	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+2] <= Genome[genome_index]["maxenergy"][current_cycle]:
		var value = Genome[genome_index]["take_element"][current_cycle] * Genome[genome_index]["metabospeed"][current_cycle]	
		var x = parameters_array[INDEX*par_number + 6] 
		var y = parameters_array[INDEX*par_number + 7] 
		x = int(x/World.tile_size)
		y = int(y/World.tile_size)
		var posindex = y*World.world_size + x
		posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
		var block_value = World.block_element_array[posindex]
		parameters_array[INDEX*par_number+2] += min(value,block_value)
		World.block_element_array[posindex] -= min(value,block_value)

 
	


func Action(INDEX):
	pass

func Eat(INDEX,c_INDEX):
	var c_genome_index = parameters_array[c_INDEX*par_number+0]
	var genome_index = parameters_array[INDEX*par_number+0]
	var c_current_cycle = parameters_array[c_INDEX*par_number+3]
	var current_cycle = parameters_array[INDEX*par_number+3]
	#if genome_index != 0 and c_genome_index == 0:
	if Genome[genome_index]["digestion"][current_cycle] == Genome[c_genome_index]["composition"][c_current_cycle]:
		if parameters_array[INDEX*par_number+2] < Genome[genome_index]["maxenergy"][current_cycle]:

		#var genome_index = parameters_array[c_INDEX*par_number+0]		
			var sum = 0
			for i in range(c_current_cycle+1):
				sum += Genome[c_genome_index]["lifecycle"][i]
			parameters_array[INDEX*par_number+2] += parameters_array[c_INDEX*par_number+2]
			parameters_array[INDEX*par_number+2] += sum
			
			parameters_array[c_INDEX*par_number+2] -= parameters_array[c_INDEX*par_number+2]
			parameters_array[c_INDEX*par_number+1] = 0# parameters_array[c_INDEX*par_number+2]
			#RemoveLife(c_INDEX,folder)

			state_array[c_INDEX] = 0
			pass

func isGrowthing(INDEX):
	var output = false
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+1] >= Genome[genome_index]["PV"][current_cycle]:
		if current_cycle+1 <  Genome[genome_index]["lifecycle"].size():
			if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][current_cycle+1]: 
				if parameters_array[INDEX*par_number+8] >= Genome[genome_index]["lifecycle_time"][current_cycle+1]:
					output = true
	return output
	
func Growth(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][current_cycle+1]
	parameters_array[INDEX*par_number+3] += 1
	parameters_array[INDEX*par_number+1] = Genome[genome_index]["PV"][current_cycle+1]

	
func Duplicate(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var x = parameters_array[INDEX*par_number+6]
	var y = parameters_array[INDEX*par_number+7]
	x = int(x/World.tile_size)
	y = int(y/World.tile_size)

	if Genome[genome_index]["childnumber"][current_cycle] > 0 :
	#if current_cycle+1 >=  Genome[genome_index]["lifecycle"].size():
		if parameters_array[INDEX*par_number+2] > Genome[genome_index]["lifecycle"][0]*2*Genome[genome_index]["childnumber"][current_cycle]:
			if parameters_array[INDEX*par_number+8] >= Genome[genome_index]["lifecycle_time"][0]: # *2 because give energy to new life


				for i in range(Genome[genome_index]["childnumber"][current_cycle]):
					var newpos = PickRandomPlaceWithRange(y,x,10)
					if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
						var newidex = BuildLife_noInstance(newpos[0],newpos[1],genome_index)
						if newidex >= 0:
							parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0] *2
							parameters_array[INDEX*par_number+8] = 0
						else:
							print("life array FULL")


func BuildLifeAtRandomplace(genome_index,cycle,folder):
	var newpos = PickRandomPlace()
	if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
		var idx = BuildLife(newpos[0],newpos[1],genome_index,folder)
		parameters_array[idx*par_number + 3] = cycle


func BuildLife(x,y,genome_index,folder):
	var newindex = state_array.find(-1)
	if newindex >= 0:
		world_matrix[x*World.world_size + y] = newindex
		Init_Parameter(newindex,genome_index)
		state_array[newindex] = 1
		InstantiateLife(newindex,folder)
	return newindex

func BuildLife_noInstance(x,y,genome_index):
	var newindex = state_array.find(-1)
	if newindex >= 0:
		world_matrix[x*World.world_size + y] = newindex
		Init_Parameter(newindex,genome_index)
		state_array[newindex] = 5 # need to add
		#InstantiateLife(newindex,folder)
	return newindex

func BuildLifeinThread(x,y,genome_index):
	var newindex = state_array.find(-1)
	if newindex >= 0: # and newindex != Life.player_index:
		world_matrix[x*World.world_size + y] = newindex
		Init_Parameter(newindex,genome_index)
		state_array[newindex] = 1
		#InstantiateLifeinThread(newindex,folder)
	return newindex

func BuildLifeRDinThread(x,y,genome_index):
	var newpos = PickRandomPlace()
	if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
		var newindex = state_array.find(-1)
		if newindex >= 0: # and newindex != Life.player_index:
			world_matrix[x*World.world_size + y] = newindex
			Init_Parameter(newindex,genome_index)
			state_array[newindex] = 1
			#InstantiateLifeinThread(newindex,folder)


func BuildPlayer(folder):
	var newindex = state_array.find(-1)
	#var newindex = 0
	#world_matrix[0*World.world_size + 0] = newindex
	Init_Parameter(newindex,3) 
	#parameters_array[newindex + 2] = 100
	#InstantiatePlayer(newindex,folder)
	state_array[newindex] = 1
	return newindex

	



func RemoveLife(INDEX):
	var posindex = world_matrix.find(INDEX)
	world_matrix[posindex] = -1
	state_array[INDEX] = -1
	Brain.state_array[INDEX] = -1
	plant_number -= 1
	


func TakeFruit(INDEX,INDEX2,folder):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0] *2
	BuildLife(0,0,genome_index,folder)
	parameters_array[INDEX*par_number+8] = 0'



func Init_Genome():
	#This function create different life form
	#Nouvelle description : Les objets commence par 1, les entités vivantes par 2. exemple Genome[10] -> Premier objet. Genome[20] -> Première entité 
	# 0: Grass /1: bugsheep /2: Bush /3: Player /4: CrabSpider /5: Tree
	Genome[0] = {
		"sprite" : [load("res://Art/grass_1.png"),load("res://Art/grass_2.png")],
		"dead_sprite" : [load("res://Art/grass_dead.png"),load("res://Art/grass_dead.png")],
		"lifecycle" : [1,1],
		"childnumber" : [0,1],
		"lifecycle_time" : [0,0],
		"metabospeed": [1,1],
		"maxenergy": [2,3],
		
		
		"movespeed" : [0,0],
		"take_element" :[3,3],
		"PV":[5,5],
		"interaction": [1,0],
		"composition": ["plant","plant"],
		"digestion": ["nothing","nothing"],
		
		"category":[0,0],
		
		'use' : [0,0],
		'damagevalue': [1,1],
		'throw':[1,2],
		'eat':[1,0],
		'attack':[1,0]
	}
	Genome[1] = {
	"sprite" : [load("res://Art/sheep1.png"),load("res://Art/sheep2.png"),load("res://Art/sheep3.png")],
	"dead_sprite" : [load("res://Art/sheep_dead1.png"),load("res://Art/sheep_dead2.png"),load("res://Art/sheep_dead3.png")],
	"lifecycle" : [10,10,20],
	"lifecycle_time" : [5,2,15],
	"maxenergy": [10,20,10*5*2],
	"childnumber" : [0,0,5],
	"movespeed" : [0,70,50],
	"take_element" :[0,0,0],
	"PV":[5,5,10],
	"interaction": [1,1,0],
	
	"metabospeed": [0,1,1],
	"composition": ["plant2","meat","meat"],
	"digestion": ["Nothing","plant","plant"],
	"category":[0,1,2],
	"use": [1,0,0],
	'damagevalue': [0,0,0],
	'throw':[0,0,0],
	'eat':[0,0,0],
	'attack':[0,0,0]
	}
	
	
	
	Genome[2] = {
	"sprite" : [load("res://Art/berry_1.png"),load("res://Art/berry_3.png"),load("res://Art/berry_4.png"),load("res://Art/berry_5.png")],
	"dead_sprite" :[load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png")],
	"lifecycle" : [2,2,4,4],
	"lifecycle_time" : [0,2,0,0],
	"childnumber" : [0,0,0,0],
	"metabospeed": [0,1,1,1],
	"movespeed" : [0,0,0,0],
	"take_element" :[3,4,5,6],
	"maxenergy": [4,4,8,8],
	"PV":[5,5,5,5],
	"interaction": [1,0,0,2],

	"composition": ["berry","plant2","plant2","plant2"],
	"digestion": ["nothing","nothing","nothing","nothing"],
	"category":[3,3,3,3],
	"use": [1,0,0,2],
	'damagevalue': [1,0,0,2],
	'throw':[1,0,0,2],
	'eat':[1,0,0,2],
	'attack':[1,0,0,2]
	}
	
	
	Genome[3] = {
		"sprite" : [load("res://Art/player_bulbi.png")],
		"dead_sprite" : [load("res://Art/player_bulbi.png")],	
		"lifecycle" : [10],
		"lifecycle_time" : [0],
		"childnumber" : [0],
		"metabospeed": [1],
		"movespeed" : [0],
		"take_element" :[0],
		"maxenergy": [10],
		"PV":[10],
		"interaction": [0],
		"composition": ["meat"],
		"digestion": ["berry"],
		"category":[2],
		"use": [0],
		'damagevalue': [1],
		'throw':[1],
		'eat':[1],
		'attack':[1]
	}
	
	Genome[4] = {
	"sprite" : [load("res://Art/spider.png")],
	"dead_sprite" : [load("res://Art/spider_dead.png")],
	"action_sprite" : [load("res://Art/spider_atk1.png")],
	"lifecycle" : [40],
	"movespeed" : [30],
	"take_element" :[0],
	"PV":[50],
	"lifecycle_time" : [0],
	"childnumber" : [1],
	"metabospeed": [1],
	"maxenergy": [100],
	"composition": ["chitin"],
	"digestion": ["meat"],
	"category":[4],
	"use": [0],
	'damagevalue': [1],
	'throw':[1],
	'eat':[1],
	'attack':[1]
	}
	
	Genome[5] = {
	"sprite" : [load("res://Art/seed_tree_radalyp_1.png"),load("res://Art/seed_tree_radalyp_2.png"),load("res://Art/seed_tree_radalyp_3.png")],
	"action_sprite" : [load("res://Art/seed_tree_radalyp_1.png"),load("res://Art/seed_tree_radalyp_2.png"),load("res://Art/seed_tree_radalyp_3.png")],
	"lifecycle" : [2,4,8],
	"movespeed" : [0,0,0],
	"take_element" :[5,8,10],
	"PV":[5,30,50],
	"composition": ["plant","plant","plant2"],
	"digestion": ["nothing","nothing","nothing"],
	"use": [0,0,0],
	'damagevalue': [0,0,0],
	'throw':[0,0,0],
	'eat':[0,0,0],
	'attack':[0,0,0]
	}

