extends Control

var back_pressed = false
var quit_pressed = false


func _on_resume_button_pressed():
	hide() 
	get_tree().paused = false


func _on_quit_button_pressed():
	'get_tree().quit()'
	quit_pressed = true
	$Confirmation.show()

func _on_back_button_pressed():
	'get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")'
	back_pressed = true
	$Confirmation.show()
		



func _on_yes_pressed():
	if back_pressed:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
	if quit_pressed:
		get_tree().quit()


func _on_no_pressed():
	$Confirmation.hide()
	back_pressed = false
	quit_pressed = false

