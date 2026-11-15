extends Node

@export var ui: CanvasLayer



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_O:
		ui.visible = not ui.visible 
		get_viewport().set_input_as_handled()
