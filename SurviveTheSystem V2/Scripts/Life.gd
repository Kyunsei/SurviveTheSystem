extends Node

'This is the global Script for all the variable and function defining the Life'

var life_size_unit = 32
var life_scene = load("res://Scenes/life.tscn") #load scene of block

var parameters_array = [] 
var world_matrix = []
var par_number = 4 # Genome_ID, PV, Element, LifeCycle
var Genome = {}

func Init_matrix():
	parameters_array.resize(World.world_size*World.world_size*par_number)
	world_matrix.resize(World.world_size*life_size_unit*World.world_size*life_size_unit)
	world_matrix.fill(-1)

func Init_Parameter(INDEX,genome_index):
	parameters_array[INDEX*par_number + 0] = genome_index #G_ID
	parameters_array[INDEX*par_number + 1] = 1 #PV
	parameters_array[INDEX*par_number + 2] = 0 #ELEMENT
	parameters_array[INDEX*par_number + 3] = 0 #LIFECYCLE

func InstantiateLife(INDEX,folder):
	var posIndex = world_matrix.find(INDEX)
	var x = (posIndex % World.world_size) *life_size_unit
	var y = (floor(posIndex/World.world_size))*life_size_unit

	var genome_index = parameters_array[INDEX*par_number + 0]
	#if isOnScreen(Life.Life_Matrix_PositionX[index],Life.Life_Matrix_PositionY[index]):
	if x >= 0 and y >= 0 and x < World.world_size*life_size_unit and y < World.world_size*life_size_unit :
			var new_life = life_scene.instantiate()
			new_life.position = Vector2(x,y)
			new_life.name =str(INDEX)
			new_life.INDEX = INDEX
			folder.add_child(new_life)


func Duplicate(INDEX):
	pass
	
func RemoveInstance(INDEX):
	pass
	

func Init_Genome():
	#This function create different life form
	Genome[0] = {
		"sprite" : [load("res://Art/grass_1.png"),load("res://Art/grass_2.png")],
		"a" : 0
	}
	pass
	

	
