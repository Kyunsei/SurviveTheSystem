extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_char_1_pressed():
	print("text button 1 is pressed")
	Life.player_skin_ID = 0
	pass # Replace with function body.


func _on_button_char_2_pressed():
	print("text button 2 is pressed")
	Life.player_skin_ID = 1
	pass # Replace with function body.


func _on_button_back_pressed():
	print("text button return/back is pressed")
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
	pass # Replace with function body.


func _on_button_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_scene.tscn")
	print("text button start is pressed")
	pass # Replace with function body.


func _on_check_box_toggled(toggled_on):
	print("toggled on is pressed")
	pass # Replace with function body.

#get_tree().change_scene_to_file("res://Scenes/battle_mode.tscn")
