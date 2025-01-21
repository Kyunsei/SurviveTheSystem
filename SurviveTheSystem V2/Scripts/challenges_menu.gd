extends Control

var ID_chal
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_return_pressed():
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")

func _on_button_pressed():
	World.ID_chal = 1
	$Level_text.text = "Kill the predator!"


func _on_button_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/Challenges/challenge_" + str(World.ID_chal)+ ".tscn")


func _on_check_box_2_toggled(toggled_on):
	World.debug_mode = toggled_on 


func _on_button_2_pressed():
	World.ID_chal = 2
	$Level_text.text = "Get 100 blue specimens!"


func _on_button_3_pressed():
	World.ID_chal = 3
	$Level_text.text = "Green one ?!"


func _on_button_4_pressed():
	World.ID_chal = 4
	$Level_text.text = "JellyBee Testing ground"


func _on_button_5_pressed():
	World.ID_chal = 5
	$Level_text.text = "Procedural Testing ground"


func _on_button_6_pressed():
	World.ID_chal = 6
	$Level_text.text = "TigerFox Testing ground"
