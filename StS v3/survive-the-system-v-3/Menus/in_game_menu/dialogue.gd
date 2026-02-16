extends Control

@export var text_speed := 0.001  # seconds per character

var _typing := false
signal button_pressed

func hide_button():
	$Panel/Button.hide()

func show_button():
	$Panel/Button.show()

func show_text(new_text:String):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Panel/Label.text = new_text
	$Panel/Label.visible_characters = 0
	_typing = true
	_type()

func _type() -> void:
	for i in $Panel/Label.text.length():
		if !_typing:
			return
		$Panel/Label.visible_characters = i + 1
		await get_tree().create_timer(text_speed).timeout
	_typing = false

func skip():
	_typing = false
	$Panel/Label.visible_characters = -1  # show all instantly
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("Action"):
		skip()


func _on_button_pressed() -> void:
	button_pressed.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hide()
