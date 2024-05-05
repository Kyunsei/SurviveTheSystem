extends Node

'This is the global Script for all the variable and function defining the Life'

var life_size_unit = 32
var life_scene = load("res://Scenes/life.tscn") #load scene of block

var parameters_array = [] 
var state_array = [] 
var world_matrix = []
var par_number = 4 # Genome_ID, PV, Element, LifeCycle
var Genome = {}

func Init_matrix():
	parameters_array.resize(World.world_size*life_size_unit*World.world_size*life_size_unit*par_number)
	parameters_array.fill(-1)
	world_matrix.resize(World.world_size*life_size_unit*World.world_size*life_size_unit)
	world_matrix.fill(-1)
	state_array.resize(World.world_size*life_size_unit*World.world_size*life_size_unit)
	state_array.fill(-1)

func Init_Parameter(INDEX,genome_index):
	parameters_array[INDEX*par_number + 0] = genome_index #G_ID
	parameters_array[INDEX*par_number + 1] = 1 #PV
	parameters_array[INDEX*par_number + 2] = 0 #ELEMENT
	parameters_array[INDEX*par_number + 3] = 0 #LIFECYCLE

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


func LifeLoopCPU2():
	#this function is the main loop for life entities, will be move to GPU
	for l in range(parameters_array.size()/ par_number):
		if parameters_array[l*par_number] != -1:
			TakeElement(l)
			if isGrowthing(l):
				Growth(l)
			else:
				Duplicate(l)

func LifeLoopCPU():
	#this function is the main loop for life entities, will be move to GPU
	var temp = state_array.duplicate()
	var l = 0
	while l != -1:
		l = temp.find(1)
		if parameters_array[l*par_number] != -1:
			temp[l] += 1
			TakeElement(l)
			if isGrowthing(l):
				Growth(l)
			else:
				Duplicate(l)



func TakeElement(INDEX):
	parameters_array[INDEX*par_number+2] += min(1,World.element)
	World.element -= min(1,World.element)

func isGrowthing(INDEX):
	var output = false
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	if current_cycle+1 <  Genome[genome_index]["lifecycle"].size():
		if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][current_cycle+1]:
			output = true
	return output
	
func Growth(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][current_cycle+1]
	parameters_array[INDEX*par_number+3] += 1

func Duplicate(INDEX):
	var genome_index = parameters_array[INDEX*par_number+0]
	var current_cycle = parameters_array[INDEX*par_number+3]
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) 
	var y = (floor(posIndex/World.world_size))
	if current_cycle+1 >=  Genome[genome_index]["lifecycle"].size():
		if parameters_array[INDEX*par_number+2] >= Genome[genome_index]["lifecycle"][0]:
			var newpos = PickRandomPlaceWithRange(x,y,3)
			if world_matrix[newpos[0]*World.world_size + newpos[1]] == -1:
				parameters_array[INDEX*par_number+2] -= Genome[genome_index]["lifecycle"][0]
				BuildLife(newpos[0],newpos[1],genome_index)


func BuildLife(x,y,genome_index):
	var newindex = state_array.find(-1)
	world_matrix[x*World.world_size + y] = newindex
	Init_Parameter(newindex,genome_index)
	state_array[newindex] = 0



	
	
func RemoveInstance(INDEX):
	pass
	
	
func PickRandomPlace():
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randi_range(0,World.worldsize*World.tile_size)
	var random_y = rng.randi_range(0,World.worldsize*World.tile_size)
	return [random_x, random_y]

func PickRandomPlaceWithRange(centerx,centery,range):
	var rng = RandomNumberGenerator.new()

	var random_x = rng.randi_range(max(0,centerx-range),min(World.world_size*World.tile_size,centerx+range))
	var random_y = rng.randi_range(max(0,centery-range),min(World.world_size*World.tile_size,centery+range))

	return [random_x, random_y]

func Init_Genome():
	#This function create different life form
	Genome[0] = {
		"sprite" : [load("res://Art/grass_1.png"),load("res://Art/grass_2.png")],
		"lifecycle" : [2,4]
	}
	pass
	

	
