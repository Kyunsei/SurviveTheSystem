extends TextureRect

@onready var item_icon = self
@onready var item_label: Label = $Item_label

var slot_number : Vector2i
var item : Dictionary
var item_count = 0


func add_item(new_item, peer_id):
	if (item_count != 0 and (item["name"] == new_item["name"]) and item_count < item["stack_amount"]) or item == {}:
		item = new_item
		item_count += 1
		#item_icon.texture = item["inventory_icon"]
		Update_info_multiplayer.rpc_id(peer_id,item_count, new_item)
		refresh_label( )
		return true
	
	return false

func refresh_label():
	item_label.text = str(item_count)

@rpc("any_peer", "call_local")
func Update_info_multiplayer(count, new_item):
	item_icon.texture = load(new_item["inventory_icon"])
	item_count = count
