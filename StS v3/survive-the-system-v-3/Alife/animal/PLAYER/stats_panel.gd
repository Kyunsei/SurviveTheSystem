extends Panel



@rpc ("any_peer","call_remote")
func update_status(peer_id):
	var player = get_parent().get_parent()
	#var alife_manager = player.get_parent()
	#get_parent()
	#for p in player.get_parent()
	#print("Reading player:", player.name)
	#print("Authority:", player.get_multiplayer_authority())
	#print("Local ID:", multiplayer.get_unique_id())
	#print("Inventory value:", player.inventory_capacity_upgrade)
	var c_health = player.manager.current_health_array[player.alifemanager_id]
	var M_health = player.max_health
	var M_energy = player.max_energy
	var c_energy = player.manager.current_energy_array[player.alifemanager_id]
	#if player.lifedata.has("current_health") and player.lifedata.has("Max_health"):
	$VBoxContainer/HealthLabel.text = "Health : " +str(int(c_health)) + "/" + str(M_health)
	$VBoxContainer/EnergyLabel.text = "Energy : " + str(int(c_energy)) + "/" + str(M_energy)
	$VBoxContainer/InventoryLabel.text = str("Inventory size : " +str(player.lifedata["Inventory_capacity"]) +" times bigger")
	$VBoxContainer/CreditLabel.text = "Money : " +str(player.lifedata["Money"]) 
	update_status_client.rpc_id(peer_id, c_health, M_health, M_energy,c_energy)

@rpc ("any_peer","call_remote")
func update_status_client(c_health, M_health, M_energy,c_energy):
	var player = get_parent().get_parent()
	$VBoxContainer/HealthLabel.text = "Health : " +str(int(c_health)) + "/" + str(M_health)
	$VBoxContainer/EnergyLabel.text = "Energy : " + str(int(c_energy)) + "/" + str(M_energy)
	$VBoxContainer/InventoryLabel.text = str("Inventory size : " +str(player.lifedata["Inventory_capacity"]) +" times bigger")
	$VBoxContainer/CreditLabel.text = "Money : " +str(player.lifedata["Money"]) 
