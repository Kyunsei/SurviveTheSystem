extends Control


func _ready():
	call_deferred("_decide_start_scene")

func _decide_start_scene():
	var args = OS.get_cmdline_args()

	if "--server" in args:
		get_tree().change_scene_to_file("res://Menus/launcher_menu/sever_menu.tscn")
	elif "--client" in args:
		get_tree().change_scene_to_file("res://Menus/launcher_menu/landing_client_menu.tscn")
