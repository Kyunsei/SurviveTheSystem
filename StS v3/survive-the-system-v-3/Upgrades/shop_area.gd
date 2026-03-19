extends Area3D

var shop
var local_p_id

func _ready() -> void:
	pass

@rpc("any_peer", "call_remote")
func set_player_currently_interacting(id):
	local_p_id = id

func interact(player):
	#capture_mouse.rpc_id(int(player.name))
	set_player_currently_interacting.rpc_id(int(player.name), int(player.name))
	#var peer_id = player.get_multiplayer_authority()
	#print("Sending to peer:", peer_id)
	rpc_id(int(player.name), "rpc_show_shop")

#@rpc("any_peer", "call_remote")
#func capture_mouse():
	#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


@rpc("any_peer", "call_remote")
func rpc_show_shop():
	$shopCanvas.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("Shop shown on:", multiplayer.get_unique_id())
