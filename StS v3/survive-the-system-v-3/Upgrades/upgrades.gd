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
	$PopupMenu.set_item_disabled(2, true)

			
func interact(player):
	p = player
	update_credits.rpc_id(int(player.name), p.catnation_credits)
	show_popup.rpc_id(int(player.name))

@rpc("any_peer","call_remote")
func _on_popup_menu_id_pressed(id):
	match id:
		0:
			upgrade_inventory_capacity.rpc_id(1)
			
		1:
			upgrade_health.rpc_id(1)
		2:
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
	var cost = 2
	if p.catnation_credits >=cost:
		p.catnation_credits -=cost
		p.lifedata["Max_health"] += 20
		p.lifedata["current_health"] = p.lifedata["Max_health"]
		print("your max health is now " +str(p.lifedata["Max_health"]))
		update_credits.rpc_id(int(p.name), p.catnation_credits)

@rpc("any_peer","call_remote")
func upgrade_inventory_capacity():
	var cost = 2
	if p.catnation_credits >=cost:
		p.catnation_credits -=cost
		p.capacity += 1.0
		p.inventory_capacity_upgrade = p.capacity/5 + 1.0
		print("your maximum inventory capacity is " +str(p.inventory_capacity_upgrade) +" times bigger")
		update_credits.rpc_id(int(p.name), p.catnation_credits)

@rpc("any_peer","call_remote")
func update_credits(new_credits):
	credits = new_credits
	$PopupMenu.set_item_text(2, str(credits) + " Cat Nation Imperial Credits")
