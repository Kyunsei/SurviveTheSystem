extends Control
@export var basic_item_pool: Array[ItemResource]  # Contains the 3 specific basic items
@export var basic_item_pool2: Array[ItemResource]  # Contains the 3 specific basic items
@export var mango_item_pool: Array[ItemResource] # Contains the 3 rare choices
@export var beltpouch_item_pool: Array[ItemResource] # Contains the 3 rare choices
@export var strawberry_item_pool: Array[ItemResource] # Contains the 3 rare choices
@export var legendary_item_pool: Array[ItemResource] # Contains the 5 super rare choices
@export var legendary_item_pool2: Array[ItemResource] # Contains the 5 super rare choices
@export var legendary_item_pool3: Array[ItemResource] # Contains the 5 super rare choices
@export var shop_size: int = 5
@export var shop_item_scene: PackedScene 
var current_stock: Array = []
@onready var grid = $Panel/GridContainer
#var player
var needupdgrade = false



func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"): #almost working!
		if get_parent().is_visible():
			_on_quit_pressed2()
	##if is_multiplayer_authority():
		#if Input.is_action_just_pressed("ui_cancel"):
			#_on_quit_pressed2()
	if multiplayer.is_server():
		if GlobalSimulationParameter.simulation_speed > 1:
			needupdgrade =  true
		
		if needupdgrade  and GlobalSimulationParameter.simulation_speed == 1:
			generate_shop()
			needupdgrade = false
			
			


func generate_shop():
	current_stock = []
	for item in basic_item_pool:
		current_stock.append({
			"item": item,
			"quantity": randi_range(3, 7)
		})
	for item in basic_item_pool2:
		current_stock.append({
			"item": item,
			"quantity": 1
		})
	# 2. Rare Items: Choose 1 from the pool
	if not mango_item_pool.is_empty():
		var mango_choice = mango_item_pool.duplicate()
		mango_choice.shuffle()
		current_stock.append({
			"item": mango_choice[0],
			"quantity": randi_range(1, 3)
		})
	if not strawberry_item_pool.is_empty():
		var rare_choice = strawberry_item_pool.duplicate()
		rare_choice.shuffle()
		current_stock.append({
			"item": rare_choice[0],
			"quantity": randi_range(1, 3)
		})
	if not beltpouch_item_pool.is_empty():
		var rare_choice = beltpouch_item_pool.duplicate()
		rare_choice.shuffle()
		current_stock.append({
			"item": rare_choice[0],
			"quantity": randi_range(1, 3)
		})

	# 3. Super Rare Items: 1/3 chance to spawn 1 from the pool
	if randi_range(1, 1) == 1 and not legendary_item_pool.is_empty():
		var legendary_choice = legendary_item_pool.duplicate()
		legendary_choice.shuffle()
		current_stock.append({
			"item": legendary_choice[0],
			"quantity": 1
		})
	if randi_range(1, 1) == 1 and not legendary_item_pool2.is_empty():
		var legendary_choice = legendary_item_pool2.duplicate()
		legendary_choice.shuffle()
		current_stock.append({
			"item": legendary_choice[0],
			"quantity": 1
		})
	if randi_range(1, 1) == 1 and not legendary_item_pool3.is_empty():
		var legendary_choice = legendary_item_pool3.duplicate()
		legendary_choice.shuffle()
		current_stock.append({
			"item": legendary_choice[0],
			"quantity": 1
		})

	populate_grid()
	'else:
		if randi_range(1, 3) == 1 and not legendary_item_pool.is_empty():
			var legendary_choice = legendary_item_pool.duplicate()
			legendary_choice.shuffle()
			current_stock.append({
				"item": legendary_choice[0],
				"quantity": 1
			})'

#@rpc("any_peer","call_local")
func populate_grid():
	for child in grid.get_children():
		child.queue_free()
	#get_server_Stock_for.rpc_id(1,multiplayer.get_unique_id())
	#var c = 0
	for entry in current_stock:
		var item_instance = shop_item_scene.instantiate()
		grid.add_child(item_instance,true)
		#item_instance.call_deferred("setup",peer_id, entry["item"], entry["quantity"],c)
		#c+= 1

@rpc("any_peer","call_local")
func update_grid(peer_id):
	get_server_Stock_for.rpc_id(1,multiplayer.get_unique_id())
	var c = 0
	for entry in grid.get_children():
		entry.call_deferred("setup",peer_id, current_stock[c]["item"], current_stock[c]["quantity"],c)
		c+= 1


@rpc("any_peer","call_local")
func get_server_Stock_for(peer_id)	:
	#current_stock = c_stock
	set_client_Stock.rpc_id(peer_id,current_stock)
	
@rpc("any_peer","call_local")
func set_client_Stock(c_stock)	:
	current_stock = c_stock
	



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

func _on_quit_pressed2() -> void:
	#var local_id = multiplayer.get_unique_id()
	var peer_id = multiplayer.get_unique_id()
	#print(str(player)+str("called on quit"))
	block.rpc_id(1, peer_id, false)
	#player.set_input_blocked.rpc_id(playerz_id,false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_parent().hide()
	
@rpc("any_peer", "call_local")
func hide_shop():
	get_parent().hide()
'@rpc("any_peer", "call_local")
func know_who_is_player(player_id):
	var player_list = get_parent().get_parent().get_parent().get_parent().get_node("Alife manager").player_array
	#print(str("player list:")+str(player_list))
	for p in player_list:
		if int(p.name) == player_id:
			player = p
			#print(str("player from for loop :")+str(player))'

@rpc("any_peer", "call_remote")
func block(peer_id, state:bool):
	var player_list = get_parent().get_parent().get_parent().get_parent().get_node("Alife manager").player_array
	var player
	for p in player_list:
		if int(p.name) == peer_id:
			player = p
	if player:
		player.set_input_blocked.rpc_id(peer_id,state)
	else:
		print("ID OF PLAYER LOST / IN shop.gd")
	
