extends Node2D

const ITEM_SLOT = preload("res://objects/item_slot.tscn")


var row_size = 4
var column_size = 1
var items = []


func _ready():
	for x in range(row_size):
		items.append([])
		
		for y in range(column_size):
			items[x].append([])
			var instance = ITEM_SLOT.instantiate()
			instance.global_position = Vector2(x*150,y*150)
			instance.slot_number = Vector2i(x,y)
			add_child(instance)
			items[x][y] = instance
			
			
			
func prep_item(new_item):
	print("prep_item is working")
	var item ={}
	#print(new_item.item_ressources.name)
	#print(new_item.item_ressources.inventory_icon)
	#print(new_item.item_ressources.item_path)
	#print(new_item.item_ressources.stack_amount)
	item["name"] = new_item.item_ressources.name
	item["inventory_icon"] = new_item.item_ressources.inventory_icon
	item["inventory_path"] = new_item.item_ressources.item_path
	item["stack_amount"] = new_item.item_ressources.stack_amount
	#print(item)
	return item
	
func prep_alife(alife):

	var item ={}

	item["name"] = str(alife["Species"])
	item["inventory_icon"] = alife["Sprites"]

	item["Data"] = [alife]
	#item["inventory_path"] = null
	item["stack_amount"] = floori(100.0/alife["Max_energy"])
	#print(item)
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
