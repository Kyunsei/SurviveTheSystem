extends Area3D

var shop
var local_p_id

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass


func init_shop():
	$shopCanvas/Node.generate_shop()
func interact(player): 
	#update_credits_in_shop.rpc_id(1,int(player.name))
	#set_player_currently_interacting.rpc_id(int(player.name), int(player.name))
	#rpc_id(int(player.name), "rpc_show_shop")
	rpc_show_shop.rpc_id(int(player.name))
	player.set_input_blocked.rpc_id(int(player.name),true)
	

@rpc("any_peer", "call_remote")
func rpc_show_shop():
	$shopCanvas.show()
	#var alife_manager = get_parent().get_parent().get_node("Alife manager")
	#var player_list = alife_manager.player_array
	#for p in player_list:
		#get_node("shopCanvas/Node/TextureRect2/MoneyLabel").text = "Current credits: " + str(p.catnation_credits)
	#var playeur = get_parent().get_parent().get_node("Alife manager").get_node("Player")
	#get_node("shopCanvas/Node/TextureRect2/MoneyLabel").text = "Current credits: " +str(playeur.catnation_credits)
	$shopCanvas/Node.update_grid.rpc_id(1,multiplayer.get_unique_id())
	#if multiplayer.get_unique_id() == local_p_id:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#print("Shop shown on:", multiplayer.get_unique_id())

@rpc("any_peer", "call_local")
func update_credits_in_shop(p_id, value):
	#var playeur = get_parent().get_parent().get_node("Alife manager").get_node("Player")
	#print(playeur)
	#get_node("shopCanvas/Node/TextureRect2/MoneyLabel").text = "Current credits: " + str(playeur.catnation_credits)
	var alife_manager = get_parent().get_parent().get_node("Alife manager")
	var player_list = alife_manager.player_array
	for p in player_list:
		if int(p.name) == p_id:
			update_client_money.rpc_id(p_id, value)
			#get_node("shopCanvas/Node/TextureRect2/MoneyLabel").text = "Current credits: " + str(p.catnation_credits)

@rpc("any_peer", "call_remote")
func update_client_money(value):
	get_node("shopCanvas/Node/TextureRect2/MoneyLabel").text = "Current credits: " + str(value)
