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


func _init(_id:int, _pos:Vector3, sp:enum_speciesID):
	ID = _id
	position = _pos
	current_energy = 0.0
	Species = sp
	match sp:
		enum_speciesID.GRASS:		
			Homeostasis_cost = 0.3
			Photosynthesis_absorbtion = 1.
			#light_index = []
