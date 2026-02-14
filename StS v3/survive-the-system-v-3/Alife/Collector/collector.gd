extends Node3D

var Biomass_collected = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_label()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(Biomass_collected) + " /100"
