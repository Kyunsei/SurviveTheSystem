extends Control
@export var possible_items: Array[ItemResource]
@export var shop_size: int = 5
@export var shop_item_scene: PackedScene 
var current_stock: Array = []
@onready var grid = $Panel/GridContainer
var player


func _ready():
	generate_shop()
	populate_grid()

func generate_shop():
	current_stock.clear()

	var pool = possible_items.duplicate()
	pool.shuffle()

	for i in range(shop_size):
		if pool.is_empty():
			break

		var item = pool.pop_back()
		var entry = {
		"item": item,
		"quantity": randi_range(1, item.Max_quantity_in_shop)
		}

		current_stock.append(entry)
		
		
		
		
func populate_grid():
	for child in grid.get_children():
		child.queue_free()

	for entry in current_stock:
		var item_instance = shop_item_scene.instantiate()
		item_instance.setup(entry["item"], entry["quantity"])
		grid.add_child(item_instance)
		#
		#
		
		
		
func shop_interacted():
	show()

var playerz_id
@rpc("any_peer", "call_local")
func _on_quit_pressed() -> void:
	#var local_id = multiplayer.get_unique_id()
	var peer_id = multiplayer.get_unique_id()
	#print(str(player)+str("called on quit"))
	block.rpc_id(1, peer_id, false)
	#player.set_input_blocked.rpc_id(playerz_id,false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_parent().hide()
	
@rpc("any_peer", "call_local")
func know_who_is_player(player_id):
	var player_list = get_parent().get_parent().get_parent().get_parent().get_node("Alife manager").player_array
	print(str("player list:")+str(player_list))
	for p in player_list:
		if int(p.name) == player_id:
			player = p
			print(str("player from for loop :")+str(player))

@rpc("any_peer", "call_remote")
func block(peer_id, state:bool):
	player.set_input_blocked.rpc_id(peer_id,state)
