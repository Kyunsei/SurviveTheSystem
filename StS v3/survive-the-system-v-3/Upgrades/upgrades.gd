extends Area3D

var p
var credits = 0
var step = 3 #0


func display_text(dialogue_box, text):
	dialogue_box.show()
	dialogue_box.show_text(text)

func _ready():
	$PopupMenu.add_item("Inventory maximum capacity up", 0)
	$PopupMenu.add_item("More maximum health", 1)
	$PopupMenu.add_item("", 2)
	$PopupMenu.add_item("", 3)
	$PopupMenu.add_item("", 4)
	$PopupMenu.set_item_disabled(4, true)

			
func interact(player):
	p = player
	update_credits.rpc_id(int(player.name), p.catnation_credits)
	show_popup.rpc_id(int(player.name))
	update_inventory_costs.rpc_id(int(p.name), p.inventory_upgrade_cost)
	update_health_costs.rpc_id(int(p.name), p.health_upgrade_cost)
	update_energy_costs.rpc_id(int(p.name), p.energy_upgrade_cost)
	update_range_costs.rpc_id(int(p.name), p.range_upgrade_cost)

@rpc("any_peer","call_remote")
func _on_popup_menu_id_pressed(id):
	match id:
		0:
			upgrade_inventory_capacity.rpc_id(1)
		1:
			upgrade_health.rpc_id(1)
		2:
			upgrade_energy.rpc_id(1)
		3:
			upgrade_range.rpc_id(1)
		4:
			pass
	await get_tree().process_frame
	$PopupMenu.popup()


func _on_popup_menu_popup_hide() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

@rpc("any_peer","call_remote")
func show_popup():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$PopupMenu.popup() # Display the menu
	
@rpc("any_peer","call_remote")
func upgrade_health():
	if p.catnation_credits >=p.health_upgrade_cost:
		p.catnation_credits -=p.health_upgrade_cost
		p.health_upgrade_cost += 1
		p.lifedata["Max_health"] += 20
		p.lifedata["current_health"] = p.lifedata["Max_health"]
		print("your max health is now " +str(p.lifedata["Max_health"]))
		update_credits.rpc_id(int(p.name), p.catnation_credits)
		update_health_costs.rpc_id(int(p.name), p.health_upgrade_cost)

@rpc("any_peer","call_remote")
func upgrade_energy():
	if p.catnation_credits >=p.energy_upgrade_cost:
		p.catnation_credits -=p.energy_upgrade_cost
		p.energy_upgrade_cost += 1
		p.lifedata["Max_energy"] += 20
		p.lifedata["current_energy"] = p.lifedata["Max_energy"]
		print("your max energy is now " +str(p.lifedata["Max_energy"]))
		update_credits.rpc_id(int(p.name), p.catnation_credits)
		update_energy_costs.rpc_id(int(p.name), p.energy_upgrade_cost)

@rpc("any_peer","call_remote")
func upgrade_inventory_capacity():
	if p.catnation_credits >=p.inventory_upgrade_cost:
		p.catnation_credits -=p.inventory_upgrade_cost
		p.inventory_upgrade_cost += 1
		p.inv_capacity += 1.0
		p.inventory_capacity_upgrade = p.inv_capacity/5 + 1.0
		print("your maximum inventory capacity is " +str(p.inventory_capacity_upgrade) +" times bigger")
		update_credits.rpc_id(int(p.name), p.catnation_credits)
		update_inventory_costs.rpc_id(int(p.name), p.inventory_upgrade_cost)
		
@rpc("any_peer","call_remote")
func upgrade_range():
	if p.catnation_credits >=p.range_upgrade_cost:
		p.catnation_credits -=p.range_upgrade_cost
		p.range_upgrade_cost += 1
		p.pickup_capacity += 1.0
		p.pickup_range_upgrade = p.pickup_capacity*5 + 1.0
		print("your maximum pick-up range is " +str(p.pickup_range_upgrade) +" times bigger")
		update_credits.rpc_id(int(p.name), p.catnation_credits)
		update_range_costs.rpc_id(int(p.name), p.range_upgrade_cost)

@rpc("any_peer","call_remote")
func update_credits(new_credits):
	credits = new_credits
	$PopupMenu.set_item_text(4, str(credits) + " Cat Nation Imperial Credits")


@rpc("any_peer","call_remote")
func update_inventory_costs(new_cost):
	print(new_cost)
	$PopupMenu.set_item_text(0, "Inventory maximum capacity up /// COST : "+ str(new_cost))
	#$PopupMenu.set_item_text(1, "More maximum health /// COST : "+ str(health_upgrade_cost))
	
@rpc("any_peer","call_remote")
func update_health_costs(new_cost):
	print(new_cost)
	$PopupMenu.set_item_text(1, "More maximum health /// COST : " + str(new_cost))

@rpc("any_peer","call_remote")
func update_energy_costs(new_cost):
	print(new_cost)
	$PopupMenu.set_item_text(2, "More maximum energy /// COST : " + str(new_cost))
	
@rpc("any_peer","call_remote")
func update_range_costs(new_cost):
	print(new_cost)
	$PopupMenu.set_item_text(3, "Increased pick-up range /// COST : " + str(new_cost))
