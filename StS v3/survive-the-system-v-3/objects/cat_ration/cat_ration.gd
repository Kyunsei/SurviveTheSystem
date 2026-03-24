extends Item

#@onready var inventory = %Inventory

######
#
# I change a bit the architecture, hopefully it is more modulable and you can create new item more easily
# class Item = the item in the world, and collection of script to integrate it
# class ItemResource = les data de l'item
#
#HOW TO MAKE NEW ITEM
#
#1.CRWATE A NEW SCENE
#ADD A SCRIPT and put extends Item on top
#Configure a way to pick up with classic collision box
#Item resource configuration are important. the path is used to instance a new object when dropped


######

var timer = 0.5

func _process(delta: float) -> void:
	timer -= delta

func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if timer <0:
			if body.is_in_group("player"):
				add_to_player(body,int(body.name))
			else:
				pass


static func on_use(_player): #NOT IMPLEMENTED YET.  need to HAVE ITEM SLECTION BEFORE
	print("USED CAT RATIO")
	
	
static func eat(player):
	#print ("eaten cat ratio")
	var value = 100
	var inventory = player.get_node("Player_HUD").get_node("Inventory")
	var item_eaten = inventory.remove_selected(int(player.name))
	if item_eaten:
		#player.lifedata["current_energy"] =clamp(player.lifedata["current_energy"]+value,0,player.lifedata["Max_energy"])
		player.manager.current_energy_array[player.alifemanager_id] =	clamp(player.manager.current_energy_array[player.alifemanager_id]+value,0,player.max_energy)
