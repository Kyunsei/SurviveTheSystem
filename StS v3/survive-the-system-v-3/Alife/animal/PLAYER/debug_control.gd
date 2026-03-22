extends Node
class_name DEBUG_control

@export var DEBUG_ACTIVE = false
var player : Node3D
var player_action_area : Node3D
var camera_anchor : Node3D
var alife_manager: Node3D

var direction = Vector3(0,0,0)
var total = 0
var tuto_HUD : Control


var timer_count = 10
var isWorldAccelerated = false


#signal grid_called

func _ready() -> void:
	player = get_parent()
	alife_manager = player.get_parent()
	player_action_area = %Area3D
	tuto_HUD = player.get_node("Player_HUD").get_node("Label")

	if player.has_node("camera_anchor"):
		camera_anchor = player.get_node("camera_anchor")
	

func _physics_process(_delta: float) -> void:

	if player.is_multiplayer_authority():
		if player.isdebuging:
			if Input.is_action_just_pressed("f1"):
				if DEBUG_ACTIVE == false:
					return
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
				if DEBUG_ACTIVE == false:
					return
				change_server_simulation_speed.rpc_id(1,600)
			if Input.is_action_just_pressed("F4"):
				if DEBUG_ACTIVE == false:
					return
				grant_player_money.rpc_id(1, int(player.name))
				
			if Input.is_action_just_pressed("F5"):
				player.get_parent().get_node("Grass_Manager2").send_full_state_to_peer.rpc_id(1,multiplayer.get_unique_id())
	
@rpc("any_peer","call_remote")
func grant_player_money(id):
	player.catnation_credits += 100
	player.update_status_of_player.rpc_id(id)
	
	
func _process(_delta: float) -> void:
	if DEBUG_ACTIVE == false:
		return
	if multiplayer.is_server():
		if isWorldAccelerated:
			if get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time <0 :
				GlobalSimulationParameter.simulation_speed = 1
				#get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time = 2000 
				isWorldAccelerated = false 
				var spaceship = player.get_parent().get_parent().get_node("SPACESHIP")
				spaceship.open_entrance.rpc_id(1)
				for p in player.get_parent().player_array:
					var p_id = int(p.name)
					player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 5.0,"Special","Shop got new items for sale")
					player.get_parent().get_node("Grass_Manager2").send_full_state_to_peer(int(p.name))




@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	if isWorldAccelerated == false:
		get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time = 1000
		GlobalSimulationParameter.simulation_speed = value
		isWorldAccelerated = true
		
@rpc("any_peer","call_local")
func change_server_simulation_speed2(value):
	if isWorldAccelerated == false:
		var spaceship = player.get_parent().get_parent().get_node("SPACESHIP")
		spaceship.block_entrance.rpc_id(1)
		get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time = 250
		GlobalSimulationParameter.simulation_speed = value
		isWorldAccelerated = true
