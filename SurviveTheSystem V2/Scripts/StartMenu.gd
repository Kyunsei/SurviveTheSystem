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
	get_tree().change_scene_to_file("res://Scenes/main_scene.tscn")



func _on_worldsize_text_changed(new_text):
	if int(new_text) > 0:
		World.world_size = int(new_text)


func _on_tilesize_text_changed(new_text):
	if int(new_text) > 0:
		World.tile_size = int(new_text)
