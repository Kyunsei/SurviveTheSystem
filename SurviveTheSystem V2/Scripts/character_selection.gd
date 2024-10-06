extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_char_1_pressed():
	print("text button 1 is pressed")
	#Life.player_skin_ID = 0
	Life.char_selected = "planty"
	pass # Replace with function body.


func _on_button_char_2_pressed():
	print("text button 2 is pressed")
	#Life.player_skin_ID = 1
	Life.char_selected = "cat"
	pass # Replace with function body.


func _on_button_back_pressed():
	print("text button return/back is pressed")
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
	pass # Replace with function body.


func _on_button_start_pressed():
	if $CheckBox.button_pressed == true :
		get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	elif $CheckBox.button_pressed == false:
		get_tree().change_scene_to_file("res://Scenes/intro_story.tscn")
	print("text button start is pressed")
	pass # Replace with function body.


func _on_check_box_toggled(toggled_on):
	print("toggled on is pressed")
	pass # Replace with function body.

#get_tree().change_scene_to_file("res://Scenes/battle_mode.tscn")


func _on_button_char_3_pressed():
	Life.char_selected = "sheep"


func _on_check_box_2_toggled(toggled_on):
	World.debug_mode = toggled_on
	print(World.debug_mode)
