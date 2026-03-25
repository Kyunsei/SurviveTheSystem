extends LineEdit

func _gui_input(event):
	if event.is_action_pressed("ui_cancel"):
		release_focus()
		hide()
