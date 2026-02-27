extends Node3D


var isInit = false

#MOUVMENT
var speed = 5 #* 1000 # gamespeed is 0.001
var maxspeed = 100 * 1000
var direction : Vector3


#SIMULATION
var alife_manager: Node3D


#DNA
#var species = "sheep"
var lifedata = {}


#VISON array
var World
var vision_danger ={ }
var vision_food = {}
var vision_friend ={ }



#var target
var wandertimer = 0



func _enter_tree() -> void:
	lifedata["current_speed"] = 0.5
	print("hello Mr sheep")
	#size = Vector3(1,1,1) #Temporary...
	#max_energy = 1000
	alife_manager = get_parent()
	isInit = true


func choose_action():
	$StateManager.choose_action()
