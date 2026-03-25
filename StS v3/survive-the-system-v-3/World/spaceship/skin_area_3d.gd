extends Area3D
var p
var Super_p
#var skins = [
	#preload("res://assets/assets kyun/ground_texture128.png"), # skin 1
	#preload("res://assets/assets kyun/grass_texture128.png"),  # skin 2
	#preload("res://assets/assets kyun/collector_texture.png"),  # skin 3
	#preload("res://assets/assets kyun/shiptexture_1.png"),  # skin 4
	#preload("res://assets/assets kyun/spaceship_texture1.png"), # skin 5
#]
 #MOVE INTO PLAYER.GD
# Called when the node enters the scene tree for the first time.
func _ready():
	$PopupMenu.add_item("Deep blue", 0)
	$PopupMenu.add_item("Orange camo", 1)
	$PopupMenu.add_item("Green camo", 2)
	$PopupMenu.add_item("Snow camo", 3)
	$PopupMenu.add_item("Orange striped", 4)
	$PopupMenu.add_item("Deep blue striped", 5)

@rpc("any_peer","call_remote")
func _on_popup_menu_id_pressed(id):
	#if p == null:
		#print("Player not set")
		#return
	match id:
		0:
			change_player_skin.rpc(0, multiplayer.get_unique_id())
		1:
			change_player_skin.rpc(1, multiplayer.get_unique_id())
		2:
			change_player_skin.rpc(2, multiplayer.get_unique_id())
		3:
			change_player_skin.rpc(3, multiplayer.get_unique_id())
		4:
			change_player_skin.rpc(4, multiplayer.get_unique_id())
		5:
			change_player_skin.rpc(5, multiplayer.get_unique_id())
		6:
			change_player_skin.rpc(6, multiplayer.get_unique_id())
	await get_tree().process_frame
	$PopupMenu.popup()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		$PopupMenu.hide()


@rpc("any_peer","call_remote")
func show_popup():
	#p = multiplayer.get_unique_id()
	print("show_popup called on peer: ", multiplayer.get_unique_id())
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$PopupMenu.popup()

func attribute_skin(player):
	p = player
	print(p)
	show_popup.rpc_id(int(p.name))
	print("attributing skin")
	pass

@rpc("any_peer","call_local")
func change_player_skin(skin_index: int, player_id):
	#if p == null:
		#print("Player not set")
		#return
	Super_p = get_parent().get_parent().get_node("Alife manager").get_node(str(player_id))
	print(Super_p)
	Super_p.skin_index = skin_index

	

func _on_popup_menu_popup_hide() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
