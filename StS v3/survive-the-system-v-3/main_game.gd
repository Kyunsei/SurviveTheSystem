extends Node3D


func _ready() -> void:
	$Network.get_node("client_menu").client_started.connect(on_game_started)
	$Network.get_node("server_menu").server_started.connect(on_server_started)
	
	



func on_game_started():
	#if MultiplayerPeer.CONNECTION_CONNECTED == 1:
	if multiplayer.is_server() == false:
			$"Alife manager".spawn_player.rpc_id(1,multiplayer.get_unique_id())

func on_server_started():
	if multiplayer.is_server():
		$World.generate_world.rpc()
		#$"Alife manager".position = $World.World_Size/2  #to avoid to work with negative coord
		$"Alife manager".Spawn_life.rpc_id(1,Vector3(5,0,5),$"Alife manager".plant_scene)
		$"Alife manager".Spawn_life.rpc_id(1,Vector3(-15,0,-15),$"Alife manager".plant_scene)
		GlobalSimulationParameter.SimulationStarted = true
