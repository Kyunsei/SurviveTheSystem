extends Node3D


@export var player_scene: PackedScene
	

	
	
func on_game_started():
	if multiplayer.is_server() == false:
		spawn_player.rpc_id(1,multiplayer.get_unique_id())
	


@rpc("any_peer","call_local")
func spawn_player(id):
	pass
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	self.call_deferred("add_child",new_player)
	#if id == multiplayer.get_unique_id():
	#new_player.set_multiplayer_authority(id)
