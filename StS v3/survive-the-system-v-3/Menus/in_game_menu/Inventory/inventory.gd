extends Control

const ITEM_SLOT = preload("res://Menus/in_game_menu/Inventory/item_slot.tscn")


var row_size = 4
var column_size = 1
var items = []
var player

var current_index = null

func _ready():
	player = get_parent().get_parent()
	if player.is_multiplayer_authority() or multiplayer.is_server():

		for x in range(row_size):
			items.append([])
			
			for y in range(column_size):
				items[x].append([])
				var instance = ITEM_SLOT.instantiate()
				instance.global_position = Vector2(x*150,y*150)
				instance.slot_number = Vector2i(x,y)
				add_child(instance, true)
				items[x][y] = instance
			

				
			
			
func prep_item(new_item):
	print("prep_item is working")
	var item ={}
	#print(new_item.item_ressources.name)
	#print(new_item.item_ressources.inventory_icon)
	#print(new_item.item_ressources.item_path)
	#print(new_item.item_ressources.stack_amount)
	item["name"] = new_item.item_ressources.name
	item["inventory_icon"] = new_item.item_ressources.inventory_icon.resource_path
	#item["inventory_path"] = new_item.item_ressources.item_path
	item["stack_amount"] = new_item.item_ressources.stack_amount
	
	new_item.itemData["inventory_path"] = new_item.item_ressources.item_path
	item["Data"] = [new_item.itemData]

	#print(item)
	return item
	
func prep_alife(alife):

	var item ={}

	item["name"] = str(alife["Species"])
	item["inventory_icon"] = alife["Sprites"]

	item["Data"] = [alife]
	#item["inventory_path"] = null
	item["stack_amount"] = floori(player.inventory_capacity_upgrade*1000.0/alife["Max_energy"]) #update here
	return item


func prep_newgrass(i):
	var grassmanager = player.get_parent().get_node("Grass_Manager2")
	var item ={}
	var s = grassmanager.Species_array[i]
	item["name"] =grassmanager.species_list[s].display_name
	item["inventory_icon"] =grassmanager.species_list[s].Sprite_path
	item["Data"] = [i]
	#item["inventory_path"] = null
	item["stack_amount"] = floori(player.inventory_capacity_upgrade*grassmanager.species_list[s].Stack_amount) #update here
	return item

func add_item(item, peer_id):
	for y in range(column_size):
		for x in range(row_size):
			var slot = items[x][y]
			
			if slot.add_item(item, peer_id):
				return true
	return false


@rpc("authority","call_remote")
func remove_last_item(peer_id):
	for y in range(column_size):
		for x in range(row_size):
			var slot = items[x][y]
			
			var item_rmv = slot.remove_item(peer_id)

			if item_rmv:
				return item_rmv
	return null


@rpc("authority","call_remote")
func remove_selected(peer_id):
	if current_index != null:
		var slot = items[current_index][0]		
		var item_rmv = slot.remove_item(peer_id)
		if item_rmv != null:
			if slot.item == {}:
				player.equip_item(null)
				player.equip_item.rpc_id(peer_id,null)
				slot.is_deselected.rpc_id(int(player.name))	
			return item_rmv
		return null
	else:
		return null

func get_selected(_peer_id):
	if current_index != null:
		var slot = items[current_index][0].item["Data"][0]		
		print(slot["inventory_path"])
		return slot
		
func show_selected(idx, peer_id):
	if current_index != null:
		var spear_path = "res://objects/cat_ration/Object_spear.tscn"
		var slot = items[current_index][0].item["Data"][0]		
		if slot["inventory_path"] == spear_path:
				player.get_node("MeshInstance3D").get_node("spear").show()

func hide_selected(idx, peer_id):
	if current_index != null:
		var spear_path = "res://objects/cat_ration/Object_spear.tscn"
		var slot = items[current_index][0].item["Data"][0]		
		if slot["inventory_path"] == spear_path:
			player.get_node("MeshInstance3D").get_node("spear").hide()



'@rpc("authority","call_remote")
func equip_item_at_index(idx):
	var slot = items[idx][0]		
	#var item_eqp = slot.remove_item(peer_id)
	if slot:
		return slot
	return null'
#old version
func select_item(idx, peer_id):
	if idx != null:   #mean unselected	
		var slot = items[idx][0]
		if  slot:
			slot.is_selected()
			#show_selected(idx,peer_id)
			
	if current_index  != null:
		if current_index != idx:
			items[current_index][0].is_deselected()	
			#hide_selected(idx, peer_id)
	
	current_index = idx
	change_index.rpc_id(1,peer_id,idx)



@rpc("authority","call_remote")
func change_index(peer_id,idx):
	current_index = idx
	var item
	if idx != null:	
		item = items[idx][0].item
	player.equip_item(item)
	player.equip_item.rpc_id(peer_id,item)





func _process(_delta: float) -> void:
	if player.is_multiplayer_authority():
		#print(player.inventory_capacity_upgrade)
		#print(multiplayer.get_unique_id())
		#print ("----")
		if Input.is_action_just_pressed("slot1"):
			select_item(0,int(player.name))
			#show_selected(0, int(player.name))
		if Input.is_action_just_pressed("slot2"):
			select_item(1,int(player.name))
		if Input.is_action_just_pressed("slot3"):
			select_item(2,int(player.name))
		if Input.is_action_just_pressed("slot4"):
			select_item(3,int(player.name))
		if Input.is_action_just_pressed("unequip"):
			select_item(null,int(player.name))
			#current_index = null
