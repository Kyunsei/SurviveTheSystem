extends Node
class_name DEBUG_control


var player : Node3D
var player_action_area : Node3D
var camera_anchor : Node3D
var alife_manager: Node3D

var direction = Vector3(0,0,0)
var total = 0

signal grid_called

func _ready() -> void:
	player = get_parent()
	alife_manager = player.get_parent()
	player_action_area = %Area3D
	if player.has_node("camera_anchor"):
		camera_anchor = player.get_node("camera_anchor")
	

func _physics_process(delta: float) -> void:

	if player.is_multiplayer_authority():
		if player.isdebuging:
			if Input.is_action_just_pressed("f1"):
				if player.World.light_grid_visible :
					player.World.light_grid_visible = false
					
				else:	
					player.World.light_grid_visible = true

				
