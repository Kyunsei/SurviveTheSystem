extends Node3D

var Biomass_collected = 0
var max_biomass = 100
var credit_gain = 0
@onready var spaceship: Node3D = $"../SPACESHIP"

var factor = 0.2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()


#@rpc("any_peer","call_local")
func interact(player):

	
	#var grassmanager = player.get_parent().get_node("Grass_Manager2")
	
	var item_hold = player.item_hold
	var inventory = player.get_node("Player_HUD").get_node("Inventory")

	if item_hold != null:
			if item_hold.size() < 1:
				return
			print(item_hold.size())
			var grassmanager = player.get_parent().get_node("Grass_Manager2")
			#if item_hold["Data"] is Dictionary:
			var temp_duplicate_list = item_hold["Data"].duplicate()
			for  o in temp_duplicate_list:
				if o is Dictionary:
					if item_hold["Data"][0]["Species"] == Alifedata.enum_speciesID.ITEM:
						print("you try to give an item")
						return

					Biomass_collected += o["Biomass"]*factor
					inventory.remove_selected(int(player.name))
				else:
					Biomass_collected += grassmanager.current_biomass_array[o]*factor
					inventory.remove_selected(int(player.name))

		

	
	'for o in player.inventory:		
		Biomass_collected += player.inventory[o]["current_energy"]*factor
		#player.remove_from_inventory(o,1)'
	#player.inventory = {}
	#player.inventory_count = 0
	update_label()
	if Biomass_collected >= max_biomass:
		credit_gain += 10
		print("BRAVO")
		var c = 0
		spaceship.get_node("Collector_ship").go_down()

		#.go_down.rpc_id(1)
		for i in player.get_parent().player_array:
			i.escape_fast_or_die.rpc_id(int(i.name))
			#i.go_back_to_ship.rpc_id(int(i.name),c)
			#set_world_readiness.rpc(false)
			#c +=1
			#GlobalSimulationParameter.simulation_speed = 0.5
			credit_player(i)
		Biomass_collected = 0
		max_biomass = max_biomass * 1.5
		update_label()

		#end_of_quest.rpc_id(int(player.name),player)
	#p.grass_in_inventory = 0
	#print ("item collected")
	#print (Biomass_collected)'

@rpc("any_peer","call_remote")
func end_of_quest(player):
	player.go_back_to_ship()
	
@rpc("any_peer","call_remote")
func set_world_readiness(yesorno):
		GlobalSimulationParameter.WorldReady = yesorno


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(round(Biomass_collected)) + " /" + str(max_biomass)

#@rpc("any_peer","call_local")
func credit_player(player):
	player.catnation_credits += credit_gain 
	player.lifedata["Money"] = player.catnation_credits
