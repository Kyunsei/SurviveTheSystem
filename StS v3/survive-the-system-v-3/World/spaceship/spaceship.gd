extends Node3D

@export var alifemanager: Node3D

var catration_path = "res://objects/cat_ration/cat_ration.tscn"

var init = false
# Called when the node enters the scene tree for the first time.
func Init() -> void:
	if multiplayer.is_server():
		var pos = global_position
		pos.y +=0.5
		pos.z += 8
		pos.x -= 6
		
		for i in range(3):
			pos.x += 3
			alifemanager.get_node("Item_Manager").spawn_new_item(catration_path,pos)
		print("spawn")


func _process(_delta: float) -> void:
	if !init and GlobalSimulationParameter.SimulationStarted:
		Init()
		init = true
	
@rpc("any_peer","call_local")
func block_entrance():
	$ship/moving_ground3.position.z -= 7
	$ship/moving_ground2.position.z += 7
	#print("entrance blocked")
	pass
	
@rpc("any_peer","call_local")
func open_entrance():
	$ship/moving_ground3.position.z += 7
	$ship/moving_ground2.position.z -= 7
	#print("entrance freed")
	pass
