extends Node2D

'This Script is for the main game loop'

var playerindex = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	Life.Init_matrix()
	Life.Init_Genome()
	Item.Init_Item()
	playerindex = Life.BuildPlayer($Life)
	$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	$Life/Player.INDEX = playerindex
	for i in World.world_size:
		for j in World.world_size:
			World.InstantiateBlock(i,j,$Blocks)

	Item.BuildItem(10,10,0,$Items)
	
	for n in range(100):
		Life.BuildLifeAtRandomplace(0,1,$Life)
	for n in range(10):
		Life.BuildLifeAtRandomplace(1,2,$Life)
	for n in range(5):
		Life.BuildLifeAtRandomplace(2,2,$Life)
	for n in range(1):
		Life.BuildLifeAtRandomplace(4,0,$Life)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Life.state_array[playerindex] <= 0:
		$UI/GameOverPanel.show()
	if $Life/Player != null:
		$StarBackground.position = $Life/Player.position  #background follow player
	$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
	$UI/Debug.text = "  " + str(Life.plant_number) + " plants " + str(World.element) + " element"
	'var idx = Life.state_array.find(0)
	if idx >= 0:
		Life.InstantiateLife(idx,$Life)
		Life.InstantiateLife(idx)
		pass'
	#Life.deleteLoopCPU($Life)
	

func UpdateSimulationSpeed():
	$Life/LifeTimer.wait_time = 10.0 / World.speed
	$Life/LifeTimer.start(0)

func _on_life_timer_timeout():
	Life.LifeLoopCPU($Life) 
	pass


func GameOver():
	pass

func _on_speed_1_pressed():
	World.speed = 5
	UpdateSimulationSpeed() # Replace with function body.


func _on_speed_10_pressed():
	World.speed = 10
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.


func _on_speed_100_pressed():
	World.speed = 100
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.


func _on_button_restart_pressed():
	pass # Replace with function body.
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
	#$UI/GameOverPanel.hide()
	
func _on_button_respawn_pressed():
	playerindex = Life.BuildPlayer($Life)
	#$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	$Life/Player.INDEX = playerindex # Replace with function body.
	$Life/Player/Sprite2D.show()
	$UI/GameOverPanel.hide()
