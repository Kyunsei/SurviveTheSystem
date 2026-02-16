extends Node3D

var Biomass_collected = 0
var max_biomass = 100

var factor =  0.002
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()

#@rpc("any_peer","call_local")
func interact(player):
	var temp = player.inventory
	for o in player.inventory:		
		Biomass_collected += player.inventory[o]["current_energy"]*factor
		#player.remove_from_inventory(o,1)
	player.inventory = {}
	update_label()
	if Biomass_collected >= max_biomass:
		print("BRAVO")
		player.go_back_to_ship.rpc_id(int(player.name))
		#GlobalSimulationParameter.simulation_speed = 0.5
		Biomass_collected = 0
		max_biomass = max_biomass * 2
		#end_of_quest.rpc_id(int(player.name),player)
	#p.grass_in_inventory = 0
	#print ("item collected")
	#print (Biomass_collected)'

@rpc("any_peer","call_remote")
func end_of_quest(player):
	player.go_back_to_ship()
	



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(round(Biomass_collected)) + " /" + str(max_biomass)
