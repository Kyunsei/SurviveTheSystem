extends Resource
class_name Alifedata
@export var item_ressources : Item
#THIS COULD BE SPLIT BY SPECIES FOR CALRIFICATION 

enum enum_speciesID {GRASS,TREE,BUSH,SHEEP,SPIDERCRAB,CAT}

var ID:int
var bin_ID: int
var Species: enum_speciesID
var position: Vector3
var current_energy: float
var Homeostasis_cost: float
var Photosynthesis_absorbtion: float
var light_index: int

'func _init(_id:int, _pos:Vector3, sp:enum_speciesID):
	ID = _id
	position = _pos
	current_energy = 0.0
	Species = sp
	match sp:
		enum_speciesID.GRASS:		
			Homeostasis_cost = 0.3
			Photosynthesis_absorbtion = 1.
			#light_index = []'


func build_lifedata(_id:int, _pos:Vector3, sp:enum_speciesID):
	var new_life : Dictionary
	
	#IDENTITY STUFF
	new_life["ID"] = _id
	new_life["Species"] = sp	
	
	#WORLDSTUF
	new_life["position"] = _pos
	new_life["size"] = 1
	new_life["current_speed"] = 0.0
	new_life["light_index"] = []
	new_life["bin_ID"] = null

	#Metabolism/Growth
	new_life["current_energy"] = 0.0
	new_life["biomass"] = 0.0
	new_life["current_energy"] = 0.0
	new_life["current_age"] = 0.0

	
	#FIGHT
	new_life["current_HP"] = 10.0
	new_life["Max_HP"] = 10.0

	
	#PHENOTYPE
	new_life["current_life_state"] = 0
	new_life["Alive"] = 1



	match sp:
		enum_speciesID.GRASS:		
			new_life["Homeostasis_cost"] = 0.3
			new_life["Photosynthesis_absorbtion"] = 1.
			new_life["Photosynthesis_range"] = 0
			new_life["Reproduction_cost"] = 8
			new_life["Reproduction_spread"] = 5
			new_life["Max_energy"] = 20
			new_life["Max_age"] = 100.0
			new_life["Sprites"] = "res://Alife/Plant/Grass/grass.png"

			#light_index = []
		enum_speciesID.TREE:
			new_life["Homeostasis_cost"] = 0.7
			new_life["Photosynthesis_absorbtion"] = 1.
			new_life["Photosynthesis_range"] = 3
			new_life["Reproduction_cost"] = 200
			new_life["Reproduction_spread"] = 20
			new_life["Max_energy"] = 500
			new_life["Max_age"] = 100.0
			new_life["Sprites"] = "res://Alife/Plant/tree/tree.png"

		enum_speciesID.BUSH:
			new_life["Homeostasis_cost"] = 0.6
			new_life["Photosynthesis_absorbtion"] = 1.
			new_life["Photosynthesis_range"] = 2
			new_life["Reproduction_cost"] = 300
			new_life["Reproduction_spread"] = 10
			new_life["Max_energy"] = 1000
			new_life["Max_age"] = 100.0
			new_life["Sprites"] = "res://assets/Art from STS2/berry_1.png"

		enum_speciesID.SHEEP:
			new_life["Homeostasis_cost"] = 0.6
			#new_life["Photosynthesis_absorbtion"] = 0.
			#new_life["Photosynthesis_range"] = 2
			new_life["Reproduction_cost"] = 100
			new_life["Reproduction_spread"] = 2
			new_life["Max_speed"] = 100 
			new_life["Vision_range"] = 3
			new_life["Food_type"] = [enum_speciesID.GRASS]
			new_life["Love_type"] = [enum_speciesID.SHEEP]
			new_life["Danger_type"] = [enum_speciesID.TREE, enum_speciesID.CAT]
			new_life["Max_age"] = 100.0
			new_life["Sprites"] = "res://assets/Art from STS2/sheep2.png"
		enum_speciesID.CAT:
			new_life["Homeostasis_cost"] = 0.6
			new_life["Reproduction_cost"] = 100
			new_life["Reproduction_spread"] = 2
			new_life["Max_speed"] = 80 
			new_life["Vision_range"] = 5
			new_life["Food_type"] = [enum_speciesID.SHEEP]
			new_life["Love_type"] = [enum_speciesID.CAT]
			new_life["Danger_type"] = [enum_speciesID.SPIDERCRAB]
			new_life["Max_age"] = 100.0
			new_life["Sprites"] = "res://assets/Art from STS2/player_cat.png"


	return new_life





func Growth():
	print("growth")
