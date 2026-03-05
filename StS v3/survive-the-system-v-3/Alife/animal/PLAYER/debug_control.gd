extends Node
class_name DEBUG_control


var player : Node3D
var player_action_area : Node3D
var camera_anchor : Node3D
var alife_manager: Node3D

var direction = Vector3(0,0,0)
var total = 0
var tuto_HUD : Control


var timer_count = 10
var isWorldAccelerated = false

signal grid_called

func _ready() -> void:
	player = get_parent()
	alife_manager = player.get_parent()
	player_action_area = %Area3D
	tuto_HUD = player.get_node("Player_HUD").get_node("Label")

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
			if Input.is_action_just_pressed("F2"):
				if tuto_HUD.visible:
					tuto_HUD.hide()
					
				else:	
					tuto_HUD.show()
			if Input.is_action_just_pressed("F3"):
				Time_Speed()


func _process(delta: float) -> void:
	if isWorldAccelerated:
		timer_count -= delta
		if timer_count <0 :
			change_server_simulation_speed.rpc_id(1,1)
			isWorldAccelerated = false 


func Time_Speed():
	if isWorldAccelerated == false:
		timer_count =  10
		isWorldAccelerated = true 
		change_server_simulation_speed.rpc_id(1,200)

	

@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	GlobalSimulationParameter.simulation_speed = value

@rpc("any_peer","call_remote")
func set_world_readiness(yesorno):
		GlobalSimulationParameter.WorldReady = yesorno
