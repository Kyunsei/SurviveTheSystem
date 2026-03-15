extends Node3D
class_name Item
@export var item_ressources : ItemResource


var itemData = {
	"position": Vector3(),
	"bin_ID": 0,
	"inventory_path": "",
	"Species": Alifedata.enum_speciesID.ITEM,
	"Use": on_use,
	"Use_secondary": on_use_secondary,
	"Eat": eat
}

@rpc("any_peer","call_local")
func Add():
	if multiplayer.is_server():
		itemData["position"] = position
		get_parent().get_parent().put_in_world_bin(itemData)

@rpc("any_peer","call_local")
func Remove():
	get_parent().get_parent().remove_from_world_bin(itemData)
	delete_item.rpc()

@rpc("authority", "call_local")
func delete_item():
	queue_free()


#@rpc("any_peer","call_local")
func add_to_player(body,peer_id):
		var inventory = body.get_node("Player_HUD").get_node("Inventory")
		if inventory.add_item(inventory.prep_item(self),peer_id):
			#print("Cat ration picked up")
			Remove()
			

static func on_use(_player):
	print("used and did something" )

static func on_use_secondary(_player, state):
	print("used secondary and did something" + str(state) )

static func eat(_player):
	print("eat something" )
