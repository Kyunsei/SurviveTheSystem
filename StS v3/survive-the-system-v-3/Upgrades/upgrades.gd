extends Area3D

#var p 
var local_p_id
var pop_up_menu_open = false
var credits = 0
var step = 3 #0
var cat_ration_cost = 3
var spearaxe_cost = 5
var vacuum_cost = 5
const CAT_RATION = "res://objects/cat_ration/cat_ration.tscn"
const SPEARAXE = "res://objects/cat_ration/Object_spear.tscn"
const VACUUM = "res://objects/cat_ration/Object_Vacuum.tscn"
var Alife_manager 


var spawned_position = Vector3(-1.3, 0, -4.5)
var object_spawned_position

func display_text(dialogue_box, text):
	dialogue_box.show()
	dialogue_box.show_text(text)

func _ready():
	object_spawned_position = global_position+ spawned_position
	$PopupMenu.add_item("Inventory maximum capacity up", 0)
	$PopupMenu.add_item("More maximum health", 1)
	$PopupMenu.add_item("", 2)
	$PopupMenu.add_item("ONE cat ration /// COST : 3", 3)
	$PopupMenu.add_item("", 4)
	$PopupMenu.set_item_disabled(4, true)
	$PopupMenu.add_item("ONE Spear weapon /// COST : 5", 5)
	$PopupMenu.add_item("ONE Vacuum tool /// COST : 5", 6)
	#$PopupMenu.set_item_disabled(3, true)
	Alife_manager = get_parent().get_parent().get_node("Alife manager")

			
func interact(player):
	#p = player
	set_player_currently_interacting.rpc_id(int(player.name), int(player.name))
	update_credits.rpc_id(int(player.name), player.catnation_credits)
	show_popup.rpc_id(int(player.name))
	update_inventory_costs.rpc_id(int(player.name), player.inventory_upgrade_cost)
	update_health_costs.rpc_id(int(player.name), player.health_upgrade_cost)
	update_energy_costs.rpc_id(int(player.name), player.energy_upgrade_cost)
	#update_range_costs.rpc_id(int(p.name), p.range_upgrade_cost)

@rpc("any_peer","call_remote")
func set_player_currently_interacting(id):
	local_p_id = id

@rpc("any_peer","call_remote")
func _on_popup_menu_id_pressed(id):
	match id:
		0:
			upgrade_inventory_capacity.rpc_id(1, local_p_id)
			#upgrade_inventory_capacity.rpc_id(int(p.name))
		1:
			upgrade_health.rpc_id(1, local_p_id)
		2:
			upgrade_energy.rpc_id(1, local_p_id)
		3:
			buy_cat_ration.rpc_id(1, local_p_id)
		4:
			pass
		5:
			buy_spearaxe.rpc_id(1, local_p_id)
		6:
			buy_vacuum.rpc_id(1, local_p_id)
	await get_tree().process_frame
	$PopupMenu.popup()


func _on_popup_menu_popup_hide() -> void:
	#if pop_up_menu_open == true :
		#pop_up_menu_open = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

@rpc("any_peer","call_remote")
func show_popup():
	#if pop_up_menu_open == false :
		#pop_up_menu_open = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$PopupMenu.popup() # Display the menu
	
@rpc("any_peer","call_local")
func upgrade_health(id):
		for p in Alife_manager.player_array :
			if p.name == str(id) :
				if p.catnation_credits >=p.health_upgrade_cost:
					p.catnation_credits -=p.health_upgrade_cost
					p.health_upgrade_cost += 1
					p.lifedata["Max_health"] += 20
					p.lifedata["current_health"] += 20
					#print("your max health is now " +str(p.lifedata["Max_health"]))
					p.lifedata["Money"] = p.catnation_credits
					update_credits.rpc_id(int(p.name), p.catnation_credits)
					update_health_costs.rpc_id(int(p.name), p.health_upgrade_cost)

@rpc("any_peer","call_local")
func upgrade_energy(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >=p.energy_upgrade_cost:
				p.catnation_credits -=p.energy_upgrade_cost
				p.energy_upgrade_cost += 1
				p.lifedata["Max_energy"] += 50
				p.lifedata["current_energy"] += 50
				#print("your max energy is now " +str(p.lifedata["Max_energy"]))
				p.lifedata["Money"] = p.catnation_credits
				update_credits.rpc_id(int(p.name), p.catnation_credits)
				update_energy_costs.rpc_id(int(p.name), p.energy_upgrade_cost)

#@rpc("any_peer","call_remote")
@rpc("any_peer","call_local")
func upgrade_inventory_capacity(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >=p.inventory_upgrade_cost:
				p.catnation_credits -=p.inventory_upgrade_cost
				p.inventory_upgrade_cost += 1
				p.inventory_capacity_upgrade += 0.5
				p.lifedata["Inventory_capacity"] = p.inventory_capacity_upgrade
				#print("your maximum inventory capacity is " +str(p.inventory_capacity_upgrade) +" times bigger")
				p.lifedata["Money"] = p.catnation_credits
				update_credits.rpc_id(int(p.name), p.catnation_credits)
				update_inventory_costs.rpc_id(int(p.name), p.inventory_upgrade_cost)
		
@rpc("any_peer","call_local")
func upgrade_range(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >=p.range_upgrade_cost:
				p.catnation_credits -=p.range_upgrade_cost
				p.range_upgrade_cost += 1
				p.pickup_capacity += 1.0
				p.pickup_range_upgrade = p.pickup_capacity*5 + 1.0
				#print("your maximum pick-up range is " +str(p.pickup_range_upgrade) +" times bigger")
				p.lifedata["Money"] = p.catnation_credits
				update_credits.rpc_id(int(p.name), p.catnation_credits)
				update_range_costs.rpc_id(int(p.name), p.range_upgrade_cost)

@rpc("any_peer","call_local")
func buy_cat_ration(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >= cat_ration_cost:
				p.catnation_credits -=cat_ration_cost
				p.lifedata["Money"] = p.catnation_credits
				get_parent().alifemanager.get_node("Item_Manager").spawn_new_item(CAT_RATION,object_spawned_position)
				update_credits.rpc_id(int(p.name), p.catnation_credits)

@rpc("any_peer","call_local")
func buy_spearaxe(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >= spearaxe_cost:
				p.catnation_credits -=spearaxe_cost
				p.lifedata["Money"] = p.catnation_credits
				get_parent().alifemanager.get_node("Item_Manager").spawn_new_item(SPEARAXE,object_spawned_position)
				update_credits.rpc_id(int(p.name), p.catnation_credits)

@rpc("any_peer","call_local")
func buy_vacuum(id):
	for p in Alife_manager.player_array :
		if p.name == str(id) :
			if p.catnation_credits >= vacuum_cost:
				p.catnation_credits -=vacuum_cost
				p.lifedata["Money"] = p.catnation_credits
				get_parent().alifemanager.get_node("Item_Manager").spawn_new_item(VACUUM,object_spawned_position)
				update_credits.rpc_id(int(p.name), p.catnation_credits)

@rpc("any_peer","call_remote")
func update_credits(new_credits):
	credits = new_credits

	$PopupMenu.set_item_text(4, str(credits) + " Cat Nation Imperial Credits")
#@rpc("any_peer","call_local")
#func update_money(new_money):
	#p.lifedata["Money"] = new_money

@rpc("any_peer","call_remote")
func update_inventory_costs(new_cost):
	#print(new_cost)
	$PopupMenu.set_item_text(0, "Inventory maximum capacity up /// COST : "+ str(new_cost))
	#$PopupMenu.set_item_text(1, "More maximum health /// COST : "+ str(health_upgrade_cost))
	
@rpc("any_peer","call_remote")
func update_health_costs(new_cost):
	#print(new_cost)
	$PopupMenu.set_item_text(1, "More maximum health /// COST : " + str(new_cost))

@rpc("any_peer","call_remote")
func update_energy_costs(new_cost):
	#print(new_cost)
	$PopupMenu.set_item_text(2, "More maximum energy /// COST : " + str(new_cost))
	
@rpc("any_peer","call_remote")
func update_range_costs(new_cost):
	#print(new_cost)
	$PopupMenu.set_item_text(3, "Increased pick-up range /// COST : " + str(new_cost))
