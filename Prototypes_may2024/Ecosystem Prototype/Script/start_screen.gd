extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_input_world_size_text_changed(new_text):
	if int(new_text) >0 :
		World.worldsize = int(new_text)

	pass # Replace with function body.


'func _on_input_tile_size_text_changed(new_text):
	if int(new_text) >0 :
		World.tile_size= int(new_text) # Replace with function body.
		World.instantiateRange =  15.0 *64/World.tile_size
'

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://Scene/main.tscn")
 # Replace with function body.
