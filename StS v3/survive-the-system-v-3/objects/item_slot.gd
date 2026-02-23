extends TextureRect

@onready var item_icon = self
@onready var item_label: Label = $Item_label

var slot_number : Vector2i
var item : Dictionary
var item_count = 0


func add_item(new_item, peer_id):
	if (item_count != 0 and (item["name"] == new_item["name"]) and item_count < item["stack_amount"]) or item == {}:
		item_count += 1
		item = new_item
		#item_icon.texture = item["inventory_icon"]
		change_icon_multiplayer.rpc_id(peer_id, item["inventory_icon"])
		refresh_label()
		print(item["inventory_icon"])
		return true
	
	return false

func refresh_label():
	item_label.text = str(item_count)
	

@rpc("any_peer", "call_local")
func change_icon_multiplayer(texture_path):
	item_icon.texture = load(texture_path)
