extends Node3D

var Biomass_collected = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()

func interact(p):
	print(p.grass_in_inventory)
	Biomass_collected += p.grass_in_inventory
	update_label()
	p.grass_in_inventory = 0
	print ("item collected")
	print (Biomass_collected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(round(Biomass_collected)) + " /100"
