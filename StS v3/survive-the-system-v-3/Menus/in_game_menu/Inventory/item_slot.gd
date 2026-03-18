extends TextureRect

@onready var item_icon = self
@onready var item_label: Label = $Item_label

var slot_number : Vector2i
var item : Dictionary
var item_count = 0
var player



func _ready():
	player = get_parent().get_parent().get_parent()
#old
func add_item(new_item, peer_id):
	if (item_count != 0 and (item["name"] == new_item["name"]) and item_count < item["stack_amount"]) or item == {}:
		#item_icon.texture = item["inventory_icon"]
		if item_count != 0:
			for d in item["Data"]:	
				new_item["Data"].append(d)
				
		item = new_item
		item_count += 1
		Update_info_multiplayer.rpc_id(peer_id, new_item)
		if new_item["inventory_icon"] is String:
			item_icon.texture = load(new_item["inventory_icon"])
		else:
			print("not yet implemnted or TRUN IT into alifedata...")
		#print(item_icon.texture)
		#refresh_label( )
		return true
	
	return false
	
#
@rpc("any_peer","call_local")
func is_selected():
	$ColorRect.show()
	show_durability()
	#if 

@rpc("any_peer","call_local")
func is_deselected():
	$ColorRect.hide()
	hide_durability()

func remove_item(peer_id):
	if  item != {}:
		var rmv_item = item["Data"].pop_back()
		item_count -= 1
		if item_count == 0:
			item = {}
			item_icon.texture = null
		send_remove_info.rpc_id(peer_id)

		return rmv_item

	return null

	


func refresh_label():
	item_label.text = str(item_count)

#old
@rpc("any_peer", "call_remote")
func Update_info_multiplayer( new_item):
	item = new_item
	item_count += 1
	if new_item["inventory_icon"] is String:
			item_icon.texture = load(new_item["inventory_icon"])

	refresh_label( )

	#item_count = count


	if new_item["inventory_icon"] is String:
		item_icon.texture = load(new_item["inventory_icon"])

	refresh_label()
@rpc("any_peer", "call_remote")
func send_remove_info():
	item_count -= 1
	if item_count == 0:
		item = {}
		item_icon.texture = null
	refresh_label( )

@rpc("any_peer", "call_local")
func show_durability():
	if item:
		if item["Durability"] == 100000.0:
			return
		$ProgressBar.show()
		if player.item_hold:
			$ProgressBar.max_value = player.item_hold["Init_durability"]
			$ProgressBar.value = player.item_hold["Durability"]
	print(str($ProgressBar.max_value)+"/"+str($ProgressBar.value) )
func hide_durability():
	if item:
		$ProgressBar.hide()
