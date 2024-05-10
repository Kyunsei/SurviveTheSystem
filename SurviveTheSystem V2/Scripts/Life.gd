extends Node

'This is the global Script for all the variable and function defining the Life'

var life_size_unit = 32
var life_scene = load("res://Scenes/life.tscn") #load scene of block

var parameters_array = [] 
var state_array = [] 
var world_matrix = []
var par_number = 8 # Genome_ID, PV, Element, LifeCycle, DirectionX, DirectionY, positionX, positionnY
var Genome = {}

func Init_matrix():
	parameters_array.resize(World.world_size*life_size_unit*World.world_size*life_size_unit*par_number)
	parameters_array.fill(-1)
	world_matrix.resize(World.world_size*World.world_size)
	world_matrix.fill(-1)
	state_array.resize(World.world_size*life_size_unit*World.world_size*life_size_unit)
	state_array.fill(-1)

func Init_Parameter(INDEX,genome_index):
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) *life_size_unit
	var y = (floor(posIndex/World.world_size))*life_size_unit
	
	parameters_array[INDEX*par_number + 0] = genome_index #G_ID
	parameters_array[INDEX*par_number + 1] = Genome[genome_index]["PV"][0] #PV
	parameters_array[INDEX*par_number + 2] = 0 #ELEMENT
	parameters_array[INDEX*par_number + 3] = 0 #LIFECYCLE
	parameters_array[INDEX*par_number + 4] = 0 #DirectionX
	parameters_array[INDEX*par_number + 5] = 0 #DirectionY
	parameters_array[INDEX*par_number + 6] = x #PositionX
	parameters_array[INDEX*par_number + 7] = y #PositionY
	
func InstantiateLife(INDEX,folder):
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) *life_size_unit
	var y = (floor(posIndex/World.world_size))*life_size_unit
	state_array[INDEX] = 1
	var genome_index = parameters_array[INDEX*par_number + 0]
	#if isOnScreen(Life.Life_Matrix_PositionX[index],Life.Life_Matrix_PositionY[index]):
	if x >= 0 and y >= 0 and x < World.world_size*life_size_unit and y < World.world_size*life_size_unit :
			var new_life = life_scene.instantiate()
			new_life.position = Vector2(x,y)
			new_life.name =str(INDEX)
			new_life.INDEX = INDEX
			folder.add_child(new_life)



func LifeLoopCPU():
	#this function is the main loop for life entities, will be move to GPU
	var temp = state_array.duplicate()

	var l = 0
	while l != -1:
		l = temp.find(1)
		if parameters_array[l*par_number] != -1:
			temp[l] += 1
			Metabocost(l)
			setDirection(l)
			TakeElement(l)
			PassiveHealing(l)
			if isGrowthing(l):
				Growth(l)
			else:
				Duplicate(l)
				pass	
			#Hunger(l)
			if isDead(l):
				NaturalKill(l)





func Metabocost(INDEX):
	var value = 1
	var value_2 = min(value,parameters_array[INDEX*par_number+2])
	parameters_array[INDEX*par_number+2] -= value_2 
	World.element += value_2 

func PassiveHealing(INDEX):
	var value = 1
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+1] < Genome[genome_index]["PV"][current_cycle]:
		if parameters_array[INDEX*par_number+2] > 0:
			var value_2 = min(value,parameters_array[INDEX*par_number+2])
			#parameters_array[INDEX*par_number+2]-= value_2
			parameters_array[INDEX*par_number+1]+= value_2
			#World.element += value_2 

func Hunger(INDEX):
	if parameters_array[INDEX*par_number+2] <= 0:
		parameters_array[INDEX*par_number+1]-= 1

func NaturalKill(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var sum = 0 + parameters_array[INDEX*par_number+2]
	for i in range(current_cycle+1):
		sum += Genome[genome_index]["lifecycle"][i]		
		World.element += sum
	RemoveLife(INDEX)
	

func isDead(INDEX):
		if parameters_array[INDEX*par_number+1] <= 0:
			return true
		else:
			return false


func TakeElement(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var value = Genome[genome_index]["take_element"][current_cycle]
	parameters_array[INDEX*par_number+2] += min(value,World.element)
	World.element -= min(value,World.element)

func Eat(INDEX,c_INDEX):
	var c_genome_index = parameters_array[c_INDEX*par_number+0]
	var genome_index = parameters_array[INDEX*par_number+0]
	if genome_index != 0 and c_genome_index == 0:
		#var genome_index = parameters_array[c_INDEX*par_number+0]
		var current_cycle = parameters_array[c_INDEX*par_number+3]
		
		var sum = 0
		for i in range(current_cycle+1):
			sum += Genome[c_genome_index]["lifecycle"][i]
		parameters_array[INDEX*par_number+2] += parameters_array[c_INDEX*par_number+2]
		parameters_array[INDEX*par_number+2] += sum
		
		parameters_array[c_INDEX*par_number+2] -= parameters_array[c_INDEX*par_number+2]
		RemoveLife(c_INDEX)
		#state_array[c_INDEX] = -1
		pass

func isGrowthing(INDEX):
	var output = false
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if parameters_array[INDEX*par_number+1] >= Genome[genome_index]["PV"][current_cycle]:
		if current_cycle+1 <  Genome[genome_index]["lifecycle"].size():
			if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][current_cycle+1]:
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

	'var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) 
	var y = (floor(posIndex/World.world_size))'
	if current_cycle+1 >=  Genome[genome_index]["lifecycle"].size():
		if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][0]:
			'print("----------")
			print(INDEX)
			var debug = ""
			for i in range(-2,10):
				debug = debug + " " + str(parameters_array[INDEX*par_number+i])
			print(debug)
			print(x,0,y)'
			var newpos = PickRandomPlaceWithRange(x,y,2)
			if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
				parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0]
				BuildLife(newpos[0],newpos[1],genome_index)


func BuildLife(x,y,genome_index):
	var newindex = state_array.find(-1)
	world_matrix[x*World.world_size + y] = newindex
	Init_Parameter(newindex,genome_index)
	state_array[newindex] = 0


func Move(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if Genome[genome_index]["movespeed"][current_cycle] > 0:
		setDirection(INDEX)
		var posIndex = world_matrix.find(INDEX)
		var directionx = parameters_array[INDEX*par_number+4]
		var directiony = parameters_array[INDEX*par_number+5]
		var x = posIndex % (World.world_size*life_size_unit) 
		var y = floor(posIndex/(World.world_size*life_size_unit))				
		var newPosX =  x + Genome[genome_index]["movespeed"][current_cycle]*directionx
		var newPosY =  y + Genome[genome_index]["movespeed"][current_cycle]*directiony
		newPosX = max(0,newPosX)
		newPosX = min(newPosX, World.world_size*life_size_unit)
		newPosY = max(0,newPosY)
		newPosY = min(newPosY, World.world_size*life_size_unit)
		#world_matrix[posIndex] = -1
		if y != newPosY or x != newPosX:
			world_matrix[newPosX + newPosY*World.world_size] = INDEX
			world_matrix[posIndex] = -1
	

func setDirection(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if Genome[genome_index]["movespeed"][current_cycle] > 0:
		var rng = RandomNumberGenerator.new()
		parameters_array[INDEX*par_number+4] =rng.randi_range(-1,1)
		parameters_array[INDEX*par_number+5] =rng.randi_range(-1,1)
	else:
		parameters_array[INDEX*par_number+4] =0
		parameters_array[INDEX*par_number+5] =0
		
	
func RemoveLife(INDEX):
	var posindex = world_matrix.find(INDEX)
	world_matrix[posindex] = -1
	state_array[INDEX] = -1
	
func PickRandomPlace():
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(0,World.worldsize)
	var random_y = rng.randi_range(0,World.worldsize)
	return [random_x, random_y]

func PickRandomPlaceWithRange(centerx,centery,range):
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(max(0,centerx-range),min(World.world_size-1,centerx+range))
	var random_y = rng.randi_range(max(0,centery-range),min(World.world_size-1,centery+range))
	return [random_x, random_y]





func Init_Genome():
	#This function create different life form
	Genome[0] = {
		"sprite" : [load("res://Art/grass_1.png"),load("res://Art/grass_2.png")],
		"lifecycle" : [2,2],
		"movespeed" : [0,0],
		"take_element" :[3,3],
		"PV":[5,5]
	}
	Genome[1] = {
	"sprite" : [load("res://Art/sheep1.png"),load("res://Art/sheep2.png"),load("res://Art/sheep3.png")],
	"lifecycle" : [4,4,8],
	"movespeed" : [0,1,1],
	"take_element" :[1,0,0],
	"PV":[5,10,20]
	}
	
	Genome[2] = {
	"sprite" : [load("res://Art/berry_1.png"),load("res://Art/berry_3.png")],#,load("res://Art/berry_3.png"),load("res://Art/berry_4.png"),load("res://Art/berry_5.png")],
	"lifecycle" : [2,2],#,2,2,2],
	"movespeed" : [0,0],#0,0,0],
	"take_element" :[3,3],#3,3,3],
	"PV":[5,5]#,5,5,5]
	}
	pass
	

	
