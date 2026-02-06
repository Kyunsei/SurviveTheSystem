extends CanvasLayer

signal client_started

func _ready():
	call_deferred("_decide_start_scene")

func _decide_start_scene():
	var args = OS.get_cmdline_args()

	if "--server" in args:
		$client_menu.hide()
		$server_menu.show()
	elif "--client" in args:
		$client_menu.show()
		$server_menu.hide()
