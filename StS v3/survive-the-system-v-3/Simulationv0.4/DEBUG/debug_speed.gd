extends Control

var world : WorldManager
var alifemanager : AlifeManager
var render : AlifeRendererManager 
var simulation_manager  : SimulationManager

var current_speed := 1.0
var active := false



func _unhandled_input(event: InputEvent) -> void:
	if get_parent().visible:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.physical_keycode == KEY_SPACE:
					pause_start()
			#ui.visible = not ui.visible
			#get_viewport().set_input_as_handled()


func pause_start():
	if simulation_manager.simulation_speed > 0:
		simulation_manager.set_simulation_speed(0)
		$Panel/LineEdit.text = "0"
		$Panel/Label2.text =  "SPACE to Run"
	else:
		simulation_manager.set_simulation_speed(current_speed)
		$Panel/LineEdit.text = str(current_speed)
		$Panel/Label2.text =  "SPACE to Pause"


func _on_line_edit_text_submitted(new_text: String) -> void:
	var value := maxf(float(new_text),0)
	current_speed = value
	simulation_manager.set_simulation_speed(value)
	
 # Replace with function body.
