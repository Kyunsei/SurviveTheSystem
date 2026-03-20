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
	pass

static func on_use_secondary(player, state):
	pass
	
static func eat(_player):
		_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
		_player.lifedata["Max_energy"] += 50
		_player.lifedata["current_energy"] += 50
		_player.show_label_above_player.rpc_id(int(_player.name),50, Color(0.0, 1.0, 0.0, 1.0), 3.0, " maximum energy")
		print(_player.lifedata["Max_energy"])
		print("You eat the Mango")
		pass
