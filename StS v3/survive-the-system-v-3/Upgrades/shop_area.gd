extends Area3D

var shop
var local_p_id

func _ready() -> void:
	pass



func interact(player):
	
	#set_player_currently_interacting.rpc_id(int(player.name), int(player.name))
	#rpc_id(int(player.name), "rpc_show_shop")
	rpc_show_shop.rpc_id(int(player.name))
	player.set_input_blocked.rpc_id(int(player.name),true)
	

@rpc("any_peer", "call_remote")
func rpc_show_shop():
	$shopCanvas.show()
	$shopCanvas/Node.populate_grid.rpc_id(1,multiplayer.get_unique_id())
	#if multiplayer.get_unique_id() == local_p_id:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#print("Shop shown on:", multiplayer.get_unique_id())
