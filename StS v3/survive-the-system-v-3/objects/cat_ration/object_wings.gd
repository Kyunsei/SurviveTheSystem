extends Item

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


static func on_use(_player): #NOT IMPLEMENTED YET.  need to HAVE ITEM SLECTION BEFORE
	if _player.has_wings == false:
		_player.first_ascension.rpc_id(int(_player.name))
		_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
		_player.show_label_above_player.rpc_id(int(_player.name),1, Color(1.0, 1.0, 0.0, 1.0), 8.0,"Special", " Ascension granted.")
	else :
		_player.show_label_above_player.rpc_id(int(_player.name),1, Color(1.0, 1.0, 0.0, 1.0), 3.0,"Special", " Ascension already granted.")

static func on_use_secondary(_player, _state):
	pass
	
static func eat(_player):
	if _player.has_wings == false:
		_player.first_ascension.rpc_id(int(_player.name))
		_player.get_node("Player_HUD").get_node("Inventory").remove_selected(int(_player.name))
		_player.show_label_above_player.rpc_id(int(_player.name),1, Color(1.0, 1.0, 0.0, 1.0), 8.0,"Special", " Ascension granted.")
	else :
		_player.show_label_above_player.rpc_id(int(_player.name),1, Color(1.0, 1.0, 0.0, 1.0), 3.0,"Special", " Ascension already granted.")
