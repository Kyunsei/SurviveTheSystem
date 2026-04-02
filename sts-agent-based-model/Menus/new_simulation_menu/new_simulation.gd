extends Control

var is2Dor3D : bool = false




func _on_start_pressed() -> void:
	if is2Dor3D:
		get_tree().change_scene_to_file("res://Simulations/3D/3d_simulation.tscn")

	else:
		print("2d not here yet")
		get_tree().change_scene_to_file("res://Simulations/3D/3d_simulation.tscn")


func _on_check_button_toggled(toggled_on: bool) -> void:
	is2Dor3D = toggled_on
