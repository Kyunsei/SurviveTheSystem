extends Node3D

var Biomass_collected = 0

var factor = 0.01
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()

#@rpc("any_peer","call_local")
func interact(player):
	for o in player.inventory:		
		Biomass_collected += player.inventory[o]["current_energy"]*factor
		player.remove_from_inventory(o,1)
	update_label()
	#p.grass_in_inventory = 0
	#print ("item collected")
	#print (Biomass_collected)'

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(round(Biomass_collected)) + " /100"
