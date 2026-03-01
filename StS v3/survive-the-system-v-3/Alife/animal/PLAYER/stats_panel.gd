extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func update_status():
	var player = get_parent().get_parent()
	if player.lifedata.has("current_health") and player.lifedata.has("Max_health"):
		$VBoxContainer/HealthLabel.text = "Health : " +str(int(player.lifedata["current_health"])) + "/" + str(player.lifedata["Max_health"])
		$VBoxContainer/EnergyLabel.text = "Energy : " + str(int(player.lifedata["current_energy"])) + "/" + str(player.lifedata["Max_energy"])
		$VBoxContainer/InventoryLabel.text = str("Inventory size : " +str(player.inventory_capacity_upgrade) +" times bigger")
		
	else:
		print("lifedata not ready yet to update status: ", player.lifedata)
