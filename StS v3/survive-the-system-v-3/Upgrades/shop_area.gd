extends Area3D

var shop
var local_p_id

func _ready() -> void:
	pass

@rpc("any_peer", "call_remote")
func set_player_currently_interacting(id):
	local_p_id = id

func interact(player):
	set_player_currently_interacting.rpc_id(int(player.name), int(player.name))
	rpc_id(int(player.name), "rpc_show_shop")
	player.set_input_blocked.rpc_id(int(player.name),true)
	$shopCanvas/Node.know_who_is_player.rpc_id(1,int(player.name))


@rpc("any_peer", "call_remote")
func rpc_show_shop():
	$shopCanvas.show()
	if multiplayer.get_unique_id() == local_p_id:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#print("Shop shown on:", multiplayer.get_unique_id())
