extends Control

'This Script deal with the Start Menu

it define the different fonction of the buttons'


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/character_selection.tscn")




func _on_worldsize_text_changed(new_text):
	if int(new_text) > 0:
		World.world_size = int(new_text)


func _on_tilesize_text_changed(new_text):
	if int(new_text) > 0:
		World.tile_size = int(new_text)


func _on_total_element_text_changed(new_text):
	if int(new_text) > 0:
		Life.max_life = int(new_text) # Replace with function body.


func _on_battle_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/battle_mode.tscn") # Replace with function body.


func _on_fo_v_text_changed(new_text):
	if int(new_text) > 0:
			World.fieldofview = int(new_text) # Replace with function body.

 # Replace with function body.


func _on_button_test_pressed():
	get_tree().change_scene_to_file("res://Test/node_3d.tscn") # Replace with function body.


func _on_button_4_pressed():
	get_tree().change_scene_to_file("res://Scenes/challenges_menu.tscn") # Replace with function body.


func _on_button_5_pressed():
	get_tree().change_scene_to_file("res://Test/test.tscn") # Replace with function body.


func _on_achiev_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/achievement_menu.tscn")
