extends Area3D
var factor = 0.01

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func interact(player):
	print("interacted by " + str(player))
	var item_hold = player.item_hold
	var inventory = player.get_node("Player_HUD").get_node("Inventory")
	if item_hold != null:
			if item_hold.size() < 1:
				return
			print(item_hold.size())
			var grassmanager = player.get_parent().get_node("Grass_Manager2")
			#if item_hold["Data"] is Dictionary:
			var temp_duplicate_list = item_hold["Data"].duplicate()
			var total :float = 0.0
			for  o in temp_duplicate_list:
				if o is Dictionary:
					if item_hold["Data"][0]["Species"] == Alifedata.enum_speciesID.ITEM:
						print("you try to give an item")
						return
					total += o["Biomass"]*factor
					inventory.remove_selected(int(player.name))
				else:
					total += grassmanager.current_biomass_array[o]*factor
					inventory.remove_selected(int(player.name))
			player.catnation_credits += total
