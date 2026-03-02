extends Node3D


var isInit = false

#MOUVMENT
var direction : Vector3


#SIMULATION
var beast_manager: Node3D


#DNA
#var species = "sheep"
var lifedata = {}


#VISON array
var World
var vision_danger ={ }
var vision_food = {}
var vision_friend ={ }






func _enter_tree() -> void:
	#size = Vector3(1,1,1) #Temporary...
	#max_energy = 1000
	beast_manager = get_parent()
	isInit = true


func choose_action():
	$StateManager.choose_action()
