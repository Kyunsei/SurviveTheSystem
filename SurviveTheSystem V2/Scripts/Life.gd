extends Node

'This is the global Script for all the variable and function defining the Life'

var life_size_unit = 32
var life_scene = load("res://Scenes/life.tscn") #load scene of block

var parameters_array = [] 
var state_array = [] 
var world_matrix = []
var par_number = 9 # Genome_ID, PV, Element, LifeCycle, DirectionX, DirectionY, positionX, positionnY, Age
var Genome = {}

var plant_number = 0

var max_life = 400


var action_list = {
	"0" : "none",
	"1" : "pick",
	"2" : "drop",
	"3" : "use"
} 


func Init_matrix():
	plant_number = 0
	parameters_array.resize(max_life*par_number)
	parameters_array.fill(-1)
	world_matrix.resize(World.world_size*World.world_size)
	world_matrix.fill(-1)
	state_array.resize(max_life)
	state_array.fill(-1)

func Init_Parameter(INDEX,genome_index):
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) *life_size_unit
	var y = (floor(posIndex/World.world_size))*life_size_unit
	
	parameters_array[INDEX*par_number + 0] = genome_index #G_ID
	parameters_array[INDEX*par_number + 1] = Genome[genome_index]["PV"][0] #PV
	parameters_array[INDEX*par_number + 2] = Genome[genome_index]["lifecycle"][0] #ELEMENT
	parameters_array[INDEX*par_number + 3] = 0 #LIFECYCLE
	parameters_array[INDEX*par_number + 4] = 0 #DirectionX
	parameters_array[INDEX*par_number + 5] = 0 #DirectionY
	parameters_array[INDEX*par_number + 6] = x #PositionX
	parameters_array[INDEX*par_number + 7] = y #PositionY
	parameters_array[INDEX*par_number + 8] = 0 #Age
	

	
	plant_number+=1
	
func InstantiateLife(INDEX,folder):
	var posIndex = world_matrix.find(INDEX)
	var x = parameters_array[INDEX*par_number + 6]
	var y = parameters_array[INDEX*par_number + 7]
	#state_array[INDEX] = 1
	var genome_index = parameters_array[INDEX*par_number + 0]
	#if isOnScreen(Life.Life_Matrix_PositionX[index],Life.Life_Matrix_PositionY[index]):
	if x >= 0 and y >= 0 and x < World.world_size*life_size_unit and y < World.world_size*life_size_unit :
			var new_life = life_scene.instantiate()
			new_life.position = Vector2(x,y)
			new_life.name =str(INDEX)
			new_life.INDEX = INDEX
			folder.add_child(new_life)



func deleteLoopCPU(folder):
	var temp = state_array.duplicate()
	var l = 0
	while l != -1:
		l = temp.find(0)
		temp[l] += 1
		if l >= 0:
			RemoveLife(l,folder)


func LifeLoopCPU(folder):
	#this function is the main loop for life entities, will be move to GPU
	var temp = state_array.duplicate()

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
						Duplicate(l,folder)
						pass
	
	var temp2 = state_array.duplicate()
	l = 0
	while l != -1:
		l = temp2.find(0)
		temp2[l] += 1
		if l >= 0:
			RemoveLife(l,folder)






func Metabocost2(INDEX):
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
		parameters_array[INDEX*par_number+1]-= 1 * Genome[genome_index]["metabospeed"][current_cycle]

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
	var posindex = x*World.world_size + y
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

	
func Duplicate(INDEX,folder):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var x = parameters_array[INDEX*par_number+6]
	var y = parameters_array[INDEX*par_number+7]
	x = int(x/World.tile_size)
	y = int(y/World.tile_size)

	'var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) 
	var y = (floor(posIndex/World.world_size))'
	if Genome[genome_index]["childnumber"][current_cycle] > 0 :
	#if current_cycle+1 >=  Genome[genome_index]["lifecycle"].size():
		if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][0]*2*Genome[genome_index]["childnumber"][current_cycle]:
			if parameters_array[INDEX*par_number+8] >= Genome[genome_index]["lifecycle_time"][0]: # *2 because give energy to new life
				'print("----------")
				print(INDEX)
				var debug = ""
				for i in range(-2,10):
					debug = debug + " " + str(parameters_array[INDEX*par_number+i])
				print(debug)
				print(x,0,y)'

				for i in range(Genome[genome_index]["childnumber"][current_cycle]):
					var newpos = PickRandomPlaceWithRange(y,x,4)
					if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
						parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0] *2
						BuildLife(newpos[0],newpos[1],genome_index,folder)
						parameters_array[INDEX*par_number+8] = 0



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

func BuildPlayer(folder):
	var newindex = state_array.find(-1)
	#var newindex = 0
	#world_matrix[0*World.world_size + 0] = newindex
	Init_Parameter(newindex,3) 
	#parameters_array[newindex + 2] = 100
	#InstantiatePlayer(newindex,folder)
	state_array[newindex] = 1
	return newindex

	



func RemoveLife(INDEX, folder):
	var posindex = world_matrix.find(INDEX)
	if folder.has_node(str(INDEX)):
		folder.get_node(str(INDEX)).queue_free()
	world_matrix[posindex] = -1
	state_array[INDEX] = -1
	Brain.state_array[INDEX] = -1
	for p in range(par_number):
		parameters_array[INDEX*par_number+p]=-1
	plant_number -= 1
	
func PickRandomPlace():
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(0,World.world_size-1)
	var random_y = rng.randi_range(0,World.world_size-1)
	return [random_x, random_y]

func PickRandomPlaceWithRange(centerx,centery,range):
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(max(0,centerx-range),min(World.world_size-1,centerx+range))
	var random_y = rng.randi_range(max(0,centery-range),min(World.world_size-1,centery+range))
	return [random_x, random_y]

func TakeFruit(INDEX,INDEX2,folder):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0] *2
	BuildLife(0,0,genome_index,folder)
	parameters_array[INDEX*par_number+8] = 0


func Init_Genome():
	#This function create different life form
	Genome[0] = {
		"sprite" : [load("res://Art/grass_1.png"),load("res://Art/grass_2.png")],
		"dead_sprite" : [load("res://Art/grass_dead.png"),load("res://Art/grass_dead.png")],
		"lifecycle" : [1,1],
		"childnumber" : [0,1],
		"lifecycle_time" : [0,0],
		"metabospeed": [1,1],
		"maxenergy": [2,2],
		
		
		"movespeed" : [0,0],
		"take_element" :[3,3],
		"PV":[5,5],
		"interaction": [1,0],
		"use": [0,0],
		"composition": ["plant","plant"],
		"digestion": ["nothing","nothing"],
		
		"category":[0,0]
	}
	Genome[1] = {
	"sprite" : [load("res://Art/sheep1.png"),load("res://Art/sheep2.png"),load("res://Art/sheep3.png")],
	"dead_sprite" : [load("res://Art/sheep_dead1.png"),load("res://Art/sheep_dead2.png"),load("res://Art/sheep_dead3.png")],
	"lifecycle" : [10,10,20],
	"lifecycle_time" : [5,15,30],
	"maxenergy": [10,20,10*5*2],
	"childnumber" : [0,0,5],
	"movespeed" : [0,70,50],
	"take_element" :[0,0,0],
	"PV":[5,5,10],
	"interaction": [1,1,0],
	"use": [1,0,0],
	"metabospeed": [0,1,1],
	"composition": ["plant2","meat","meat"],
	"digestion": ["Nothing","plant","plant"],
	"category":[0,1,2]
	}
	
	
	
	Genome[2] = {
	"sprite" : [load("res://Art/berry_1.png"),load("res://Art/berry_3.png"),load("res://Art/berry_4.png"),load("res://Art/berry_5.png")],
	"dead_sprite" :[load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png"),load("res://Art/berry_dead.png")],
	"lifecycle" : [2,2,4,4],
	"lifecycle_time" : [0,10,0,0],
	"childnumber" : [0,0,0,0],
	"metabospeed": [0,1,1,1],
	"movespeed" : [0,0,0,0],
	"take_element" :[3,4,5,6],
	"maxenergy": [4,4,8,8],
	"PV":[5,5,5,5],
	"interaction": [1,0,0,2],
	"use": [1,0,0,2],
	"composition": ["berry","plant2","plant2","plant2"],
	"digestion": ["nothing","nothing","nothing","nothing"],
	"category":[3,3,3]
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
		"use": [0],
		"composition": ["meat"],
		"digestion": ["berry"],
		"category":[2]
	}
	
	Genome[4] = {
	"sprite" : [load("res://Art/spider.png")],
	"dead_sprite" : [load("res://Art/spider_dead.png")],
	"action_sprite" : [load("res://Art/spider_atk1.png")],
	"lifecycle" : [40],
	"movespeed" : [20],
	"take_element" :[0],
	"PV":[50],
	"lifecycle_time" : [0],
	"childnumber" : [1],
	"metabospeed": [1],
	"maxenergy": [100],
	"composition": ["chitin"],
	"digestion": ["meat"],
	"category":[4]
	}
	
	Genome[5] = {
	"sprite" : [load("res://Art/seed_tree_radalyp_1.png"),load("res://Art/seed_tree_radalyp_2.png"),load("res://Art/seed_tree_radalyp_3.png")],
	"action_sprite" : [load("res://Art/seed_tree_radalyp_1.png"),load("res://Art/seed_tree_radalyp_2.png"),load("res://Art/seed_tree_radalyp_3.png")],
	"lifecycle" : [2,4,8],
	"movespeed" : [0,0,0],
	"take_element" :[5,8,10],
	"PV":[5,30,50],
	"composition": ["plant","plant","plant2"],
	"digestion": ["nothing","nothing","nothing"]
	}
	
