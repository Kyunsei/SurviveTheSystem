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


static func on_use(_player): 
	_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
	var value = 30
	_player.lifedata["Max_health"] += value
	_player.lifedata["current_health"] += value
	_player.show_label_above_player.rpc_id(int(_player.name),value, Color(1.0, 0.4, 0.7, 1.0), 3.0,"", " maximum health")
	print("You eat the Strawberry")
	pass
	
	_player.manager.current_health_array[_player.alifemanager_id] +=value
	_player.max_health += value

static func on_use_secondary(player, state):
	pass
	
static func eat(_player):
	_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
	var value = 30
	_player.lifedata["Max_health"] += value
	_player.lifedata["current_health"] += value
	_player.show_label_above_player.rpc_id(int(_player.name),value, Color(1.0, 0.4, 0.7, 1.0), 3.0,"", " maximum health")
	print("You eat the Strawberry")
	pass
	
	_player.manager.current_health_array[_player.alifemanager_id] +=value
	_player.max_health += value
