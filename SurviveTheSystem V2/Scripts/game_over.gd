extends Control


var gameover_type



# Called when the node enters the scene tree for the first time.
func _ready():
	if World.debug_mode:
		$Button4.show()



func SetUp_GameOver_Screen():
	print("call")
	$Label.text =  " You're Dead =( "
	match Life.player.cause_of_death:
		Life.player.deathtype.VOID:
			$Label.text = $Label.text + "\n You felt into the void"
			World.achievement_dic["fall_death"] = 1
		Life.player.deathtype.AGE:
			$Label.text = $Label.text + "\n Too old now"
			World.achievement_dic["age_death"] = 1	
		Life.player.deathtype.DAMMAGE:
			$Label.text = $Label.text + "\n You got killed"
			World.achievement_dic["dammage_death"] = 1			
		Life.player.deathtype.EATEN:
			$Label.text = $Label.text + "\n You got eaten"
			World.achievement_dic["eat_death"] = 1
		Life.player.deathtype.HUNGER:
			$Label.text = $Label.text + "\n You starved to death"
			World.achievement_dic["hunger_death"] = 1
	#$Button.text = "Continue to Survive"
	#$Label.text = "Number of grass alive : "+str(Life.plant_number) +"\nNumber of crab-spider alive : " +str(Life.spidercrab_number)+ "\nNumber of sheep alive : "+str(Life.sheep_number) +"\nNumber of berry bush alive : " +str(Life.berry_number)+"\nNumber of Player alive : " +str(Life.player_number)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed(): #Continue to Survive
	if 	Life.player.isActive:
		get_tree().paused = false
		#get_parent().get_parent().gameover = false
		hide()
	else:
		$Button.text = "Player dead"
	

func _on_button_2_pressed(): #Return to start menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")



func _on_button_3_pressed(): #Close the Game
	get_tree().quit()


func _on_button_4_pressed(): # Respawn for debugging only
	Life.player.Activate()
	#get_parent().get_parent().gameover = false
	get_tree().paused = false
	hide()


