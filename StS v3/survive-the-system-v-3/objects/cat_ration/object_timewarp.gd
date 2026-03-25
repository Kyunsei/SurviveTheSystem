extends Item

var area
var timer = 0.5

func _ready():
	pass

func _process(delta: float) -> void:
	timer -= delta

func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if timer <0:
			if body.is_in_group("player"):
				add_to_player(body,int(body.name))
			else:
				pass


static func on_use(player):
	var player_list = player.get_parent().player_array
	var spaceship = player.get_parent().get_parent().get_node("SPACESHIP")
	var spaceship_height = spaceship.global_position.y
	var all_above = true
	var mission_finished = false
	for p in player_list:
		if p.global_position.y < spaceship_height:
			all_above = false
			break
		if p.finished_their_mission == true:
			all_above = false
			mission_finished = true
			break
	if all_above:
		var inventory = player.get_node_or_null("Player_HUD/Inventory")
		if inventory:
			inventory.remove_selected(int(player.name))
		var debug_ctrl = player.get_node_or_null("DEBUG_CONTROL")
		if debug_ctrl:
			debug_ctrl.change_server_simulation_speed2.rpc_id(1, 600)
			for p in player_list:
				p.show_label_above_player.rpc_id(int(p.name),1, Color(1.0, 1.0, 1.0, 1.0), 10.0,"Special" ,"Timewarp activated. Please wait")
			#print("Timewarp activated: All players are above threshold.")
	else:
		if mission_finished:
			player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 2.0,"Special","Timewarp unusable, you finished your mission!")
		else:
			player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 2.0,"Special","Timewarp failed: All players must be in the ship.")


static func on_use_secondary(player, state):
	pass
	
static func eat(player):
	var player_list = player.get_parent().player_array
	var spaceship = player.get_parent().get_parent().get_node("SPACESHIP")
	var spaceship_height = spaceship.global_position.y
	var all_above = true
	var mission_finished = false
	for p in player_list:
		if p.global_position.y < spaceship_height:
			all_above = false
			break
		if p.finished_their_mission == true:
			all_above = false
			mission_finished = true
			break
	if all_above:
		var inventory = player.get_node_or_null("Player_HUD/Inventory")
		if inventory:
			inventory.remove_selected(int(player.name))
		var debug_ctrl = player.get_node_or_null("DEBUG_CONTROL")
		if debug_ctrl:
			debug_ctrl.change_server_simulation_speed2.rpc_id(1, 600)
			for p in player_list:
				p.show_label_above_player.rpc_id(int(p.name),1, Color(1.0, 1.0, 1.0, 1.0), 10.0,"Special" ,"Timewarp activated. Please wait")
			#print("Timewarp activated: All players are above threshold.")
	else:
		if mission_finished:
			player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 2.0,"Special","Timewarp unusable, you finished your mission!")
		else:
			player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 2.0,"Special","Timewarp failed: All players must be in the ship.")
		
