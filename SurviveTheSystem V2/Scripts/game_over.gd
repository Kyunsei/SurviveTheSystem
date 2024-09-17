extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	

func SetUp_GameOver_Screen():
	$Button.text = "Continue to Survive"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = "Number of grass alive : "+str(Life.plant_number) +"\nNumber of crab-spider alive : " +str(Life.spidercrab_number)+ "\nNumber of sheep alive : "+str(Life.sheep_number) +"\nNumber of berry bush alive : " +str(Life.berry_number)+"\nNumber of Player alive : " +str(Life.player_number)


func _on_button_pressed(): #Continue to Survive
	if 	get_parent().get_parent().player.isActive:
		get_tree().paused = false
		hide()
	else:
		$Button.text = "Player dead"
	

func _on_button_2_pressed(): #Return to start menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")



func _on_button_3_pressed(): #Close the Game
	get_tree().quit()


func _on_button_4_pressed(): # Respawn for debugging only
	get_parent().get_parent().player.Activate()
	get_parent().get_parent().gameover = false
	get_tree().paused = false
	hide()


