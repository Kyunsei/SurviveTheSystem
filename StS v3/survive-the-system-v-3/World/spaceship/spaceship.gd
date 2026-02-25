extends Node3D

@export var alifemanager: Node3D

var catration_path = "res://objects/cat_ration/cat_ration.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if multiplayer.is_server():
		var pos = global_position
		print(pos)
		pos.y=0.5
		pos.z += 8
		
		for i in range(3):
			pos.x = 3*i -3
			alifemanager.get_node("Item_Manager").spawn_new_item.rpc(catration_path,pos)
