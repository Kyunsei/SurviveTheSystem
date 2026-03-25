extends ColorRect

func _ready() -> void:
	var player = get_parent().get_parent()
	if player.is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_button_pressed() -> void:
	var player = get_parent().get_parent()
	if player.is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hide()
