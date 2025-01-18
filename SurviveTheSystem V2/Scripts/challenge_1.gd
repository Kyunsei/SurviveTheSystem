extends Node2D

var rocket_scene = load("res://Scenes/rocket.tscn")
var playerindex = 0
var gameover = false

#to load the map
var initialized = false




func initChallenges(ID):
	Life.Instantiate_emptyLife_pool($Life, 1, "cat")
	if ID == 1:
		Life.Instantiate_emptyLife_pool($Life, 10, "spidercrab")
		Life.Instantiate_emptyLife_pool($Life, 100, "berry")
		var pl = Life.build_life("cat")
		if pl:
			Life.player = pl
			Life.player.age = 0
			Life.player.isPlayer = true 
			Life.player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
			
	if ID == 2:
		Life.red = 0
		Life.blue = 0
		Life.Instantiate_emptyLife_pool($Life, 1000, "grass")
		Life.Instantiate_emptyLife_pool($Life, 100, "berry")
		var pl = Life.build_life("cat")
		if pl:
			Life.player = pl
			Life.player.age = 0
			Life.player.isPlayer = true 
			Life.player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
		for i in range(0):
			var life = Life.build_life("grass")
			life.sub_species = 1
			life.test_col = Color(0,0,1)
			life.modulate = life.test_col
			life.energy= 5
			Life.red -= 1
			Life.blue += 1
			life.position = Vector2(randi_range(World.tile_size*25,World.tile_size*30),randi_range(World.tile_size*10,World.tile_size*15))
	if ID == 3:

		Life.Instantiate_emptyLife_pool($Life, 3000, "grass")
		Life.Instantiate_emptyLife_pool($Life, 100, "berry")
		Life.Instantiate_emptyLife_pool($Life, 100, "bigtree")
		Life.Instantiate_emptyLife_pool($Life, 100, "sheep")
		var pl = Life.build_life("cat")
		if pl:
			Life.player = pl
			Life.player.age = 0
			Life.player.isPlayer = true 
			Life.player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
		for i in range(0):
			var life = Life.build_life("grass")
			life.sub_species = 2
			life.Build_Stat()
			life.modulate = life.test_col
			life.position = Vector2(randi_range(10*World.tile_size,World.tile_size*World.world_size-10),randi_range(10*World.tile_size,World.tile_size*World.world_size-10))
	
	if ID == 4:

		Life.Instantiate_emptyLife_pool($Life, 300, "spiky_grass")
		Life.Instantiate_emptyLife_pool($Life, 100, "berry")
		Life.Instantiate_emptyLife_pool($Life, 100, "jellybee")
		var pl = Life.build_life("cat")
		if pl:
			Life.player = pl
			Life.player.age = 0
			Life.player.isPlayer = true 
			Life.player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))

															
									
func _ready(): 
	World.world_size = 140
	InitNewGame()

	

	
func _process(delta):
		if Life.player != null:
			$StarBackground.position = Life.player.position  #background follow player
			$Camera2D.position = Life.player.position
			
		$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
		wincondition(World.ID_chal)
		#dead player
		if Life.player != null:
			if Life.player.isActive != true:# and gameover == false:
				CallGameOver()
		
func wincondition(ID):
	if ID == 1:
		$UI/Score.text = "spidercrab dead: " + str(Life.pool_scene["spidercrab"][0].isDead)
		#20 days
		if Life.pool_scene["spidercrab"][0].isDead and gameover == false:
			if Life.player.isActive == true:
				var rocket = rocket_scene.instantiate()
				rocket.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
				add_child(rocket)
				gameover = true
				$UI/Label_annoncemnt.text = "Sucess !! Go to the ship to finish"
				$UI/Label_annoncemnt.show()
				await get_tree().create_timer(2.).timeout
				$UI/Label_annoncemnt.hide()
	if ID == 2:
		$UI/Score.text = "RED: " + str(Life.red) + " BLUE: " + str(Life.blue)
		#20 days
		if Life.blue >= 100 and gameover == false:
			if Life.player.isActive == true:
				var rocket = rocket_scene.instantiate()
				rocket.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
				add_child(rocket)
				gameover = true
				$UI/Label_annoncemnt.text = "Sucess !! Go to the ship to finish"
				$UI/Label_annoncemnt.show()
				await get_tree().create_timer(2.).timeout
				$UI/Label_annoncemnt.hide()

	if ID == 3:
		$UI/Score.text = "IDK"
		

	if ID == 4:
		$UI/Score.text = "JellyBee Test"







func init_debug_feature():
	if World.debug_mode:
		$UI/Debug_Menu.show()

func InitNewGame():
	init_debug_feature()
	
	#Init the World
	Life.Init_life_pool()
	World.Init_World($Blocks)
	
	initChallenges(World.ID_chal)

	#FUTURE PROCEDURAL FUNCTIOM
	$World_TileMap.instantiate_the_tiles_function()
	
	
	UpdateSimulationSpeed()
	



	




func UpdateSimulationSpeed():
	$BlockTimer.wait_time = World.diffusion_speed / World.speed
	$BlockTimer.start(0)
		
	$DayTimer.wait_time= World.daytime / World.speed
	$NightTimer.stop()
	#$DirectionalLight2D.hide()
	light_out.emit()
	$DayTimer.start(0)
	
	$NightTimer.wait_time= World.nighttime / World.speed
	#$NightTimer.start(0)
	$UI/Clock.Uptade_timesimulation()	




	
signal light_on
signal light_out

func _on_day_timer_timeout():
	
	#$UI/Night_filtre.show()
	#$DirectionalLight2D.show()
	decrease_light_intensity()
	$NightTimer.start()
	light_on.emit()
	World.isNight = true


func decrease_light_intensity():
	var i = 0
	while i <= 1:
		i = i + 0.1
		$DirectionalLight2D.energy = i
		await wait(.5)

func increase_light_intensity():
	var i = 1
	while i > 0:
		i = i - 0.1
		$DirectionalLight2D.energy = i
		await wait(.5)
	light_out.emit()
		
func wait(seconds: float):
	var timer = Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout  # Wait until the "timeout" signal is emitted
	timer.queue_free()  # Remove the timer after use
		


func _on_night_timer_timeout():
	World.day += 1 # Replace with function body.
	#$DirectionalLight2D.hide()
	#$UI/Night_filtre.hide()
	increase_light_intensity()

	$DayTimer.start()
	$UI/DayCount.show()
	$UI/DayCount.text = "Day " + str(World.day)
	$UI/DayCount/Timer.start()
	World.isNight = false
	

func CallGameOver():

	$UI/GameOver.SetUp_GameOver_Screen()
	$UI/GameOver.show()
	#gameover = true
	get_tree().paused = true


	
func _input(event): #gameover fonction
	if event.is_action_pressed("interact"):
		pass
	

	if event.is_action_pressed("Esc"):
		print("Esc")
		if 	get_tree().paused == true:
			get_tree().paused = false
			$UI/Pause_menu.hide()
		else:
			get_tree().paused = true
			$UI/Pause_menu.show()	

func _on_timer_timeout():
	$UI/DayCount.hide() # Replace with function body.
