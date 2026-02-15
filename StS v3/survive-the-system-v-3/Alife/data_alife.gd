extends Node
class_name Alifedata


enum enum_speciesID {GRASS,TREE}

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
	new_life["ID"] = _id
	new_life["position"] = _pos
	new_life["current_energy"] = 0.0
	new_life["Species"] = sp
	new_life["light_index"] = null
	new_life["bin_ID"] = null
	match sp:
		enum_speciesID.GRASS:		
			new_life["Homeostasis_cost"] = 0.3
			new_life["Photosynthesis_absorbtion"] = 1.
			#light_index = []
	return new_life
