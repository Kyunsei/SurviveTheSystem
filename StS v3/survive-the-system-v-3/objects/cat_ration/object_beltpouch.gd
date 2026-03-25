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
		var value = 0.5
		_player.inventory_capacity_upgrade += value
		_player.lifedata["Inventory_capacity"] = _player.inventory_capacity_upgrade
		_player.show_label_above_player.rpc_id(int(_player.name),value, Color(1.0, 1.0, 1.7, 1.0), 3.0, ""," inventory capacity")
		print("You equip the beltpouch")
		pass

static func on_use_secondary(_player, _state):
	pass
	
static func eat(_player):
		_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
		var value = 0.5
		_player.inventory_capacity_upgrade += value
		_player.lifedata["Inventory_capacity"] = _player.inventory_capacity_upgrade
		_player.show_label_above_player.rpc_id(int(_player.name),value, Color(1.0, 1.0, 1.7, 1.0), 3.0, ""," inventory capacity")
		print("You equip the beltpouch")
		pass
