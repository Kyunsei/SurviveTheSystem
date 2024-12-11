extends Node2D

'This Script is for the main game loop'
var life_rock_scene = load("res://Scenes/rock.tscn")
var jellyhive_scene = load("res://Scenes/jelly_hive.tscn")
var rocket_scene = load("res://Scenes/rocket.tscn")
var playerindex = 0
var gameover = false


#to load the map
var batch_size = 20
var current_batch = 0
var initialized = false

#var thread = Thread.new()

var allblocks = []



signal world_speed_changed

# Called when the node enters the scene tree for the first time.
func _ready():

  
	InitNewGame()
	#$Life/Player/Sprite2D.texture = Life.player_skin[Life.player_skin_ID]
	
	'Life.current_batch = 0
	$Life/SpawnTimer.wait_time = Life.min_time_by_batch
	$Life/SpawnTimer.start(0)
	get_tree().paused = true'
	

	

	
func _process(delta):

		if Life.player != null:
			var playerworldpos = World.getWorldPos(Life.player.global_position)
			#World.ActivateAndDesactivateBlockAround(Life.player.input_dir, playerworldpos.x,playerworldpos.y,allblocks)
			$StarBackground.position = Life.player.position  #background follow player
			
		$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
		#$UI/Debug.text = str(World.day) + " day \n" +"berry: " +   str(Life.berry_number) + " / " + str(Life.berry_pool_state.size()) + " \n" + "sheep: " +   str(Life.sheep_number) + " / " + str(Life.sheep_pool_state.size()) + " \n" + "grass: "  + str(Life.plant_number) + " / " + str(Life.max_life)  + "\n stingtree: " +   str(Life.stingtree_number) + " / " + str(Life.stingtree_pool_state.size()) + " \n" + "crabspider: " +   str(Life.spidercrab_number) + " / " + str(Life.spidercrab_pool_state.size())   

	
		#20 days
		if World.day == 0 and gameover == false:
			if Life.player.isActive == true:
				var rocket = rocket_scene.instantiate()
				rocket.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
				add_child(rocket)
				gameover = true
				#CallGameOver()
				

		#dead player
		if Life.player != null:
			if Life.player.isActive != true:# and gameover == false:
				CallGameOver()


func init_debug_feature():
	if World.debug_mode:
		#$UI/speedContainer.show()
		$UI/Debug.show()
		#$UI/Wspeed.show()
		$UI/Debug_Menu.show()

func InitNewGame():
	init_debug_feature()
	
	#Init the World
	Life.Init_life_pool($Life)
	World.Init_World($Blocks)

	#FUTURE PROCEDURAL FUNCTIOM
	$World_TileMap.instantiate_the_tiles_function()
	
	#$World_TileMap.build_world()
	#Life.Build_life_in_World()
		
	#var s = Time.get_ticks_msec()
	#var ss = Time.get_ticks_msec()
	#print("new: " + str(ss-s) + "ms")
	UpdateSimulationSpeed()
	


	
	'for i in range(10):
		var rock = life_rock_scene.instantiate()
		add_child(rock)
		rock.global_position = Life.PickRandomPlace()*World.tile_size
		rock.show()'
		
	
	for i in range(0):
		var h = jellyhive_scene.instantiate()
		add_child(h)
		h.global_position = Life.PickRandomPlace()*World.tile_size



	'Life.Instantiate_Life_in_pool($Life,1,"grass")
	Life.Instantiate_Life_in_pool($Life,50,"spiky_grass")
	Life.Instantiate_Life_in_pool($Life,15,"berry")

	Life.Instantiate_Life_in_pool($Life,40,"grass")
	Life.Instantiate_Life_in_pool($Life,40,"spiky_grass")
	Life.Instantiate_Life_in_pool($Life,15,"berry")

	Life.Instantiate_Life_in_pool($Life,10,"sheep")
	Life.Instantiate_Life_in_pool($Life,1,"cat")
	#Life.Instantiate_Life_in_pool($Life, 10, "stingtree")
	Life.Instantiate_Life_in_pool($Life, 2, "spidercrab")
	#Life.Instantiate_Life_in_pool($Life, 10, "jellybee")'


	if Life.char_selected != "scoobyDoo":
		var pl = Life.build_life("cat")
		if pl:
			Life.player = pl
		else:
			Life.player = Life.pool_scene['cat'][0]
	else:
		var pl = Life.build_life("sheep")
		if pl:
			Life.player = pl
		else:
			Life.player = Life.pool_scene['sheep'][0]
			
	Life.player.age = 0
	Life.player.isPlayer = true 
	Life.player.get_node("Camera2D").enabled = true
	

	#player.get_node("Camera2D").enabled = true 
	Life.player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	var playerworldpos = World.getWorldPos(Life.player.global_position)
	#World.InstantiateBlockAroundPlayer2(playerworldpos.x,playerworldpos.y,$Blocks,1)
	#World.InstantiateALLBlock($Blocks)
	#World.InstantiateALLBlock($Blocks)
	
	allblocks = $Blocks.get_children()
	

	#instantiate Life
	#for i in range(Life.max_life):
		#Life.BuildLifeAtRandomplace(0,1,$Life)

	#instantaite Item
	#Item.BuildItem(playerworldpos.x,playerworldpos.y-1,0,$Items)
	#Item.BuildItem(playerworldpos.x,playerworldpos.y+1,1,$Items)




	

func UpdateSimulationSpeed():
	$BlockTimer.wait_time = World.diffusion_speed / World.speed
	$BlockTimer.start(0)
		
	'$Life/LifeTimer.wait_time = 10.0 / World.speed
	$Life/LifeTimer.start(0)'

	'$Life/SpawnTimer.wait_time = 1.#2.0 / World.speed
	#$Life/SpawnTimer.start(0)'
	
	'$Life/BrainTimer.wait_time = 2.0 / World.speed
	$Life/BrainTimer.start(0)'
	

	

	$DayTimer.wait_time= World.daytime / World.speed
	$NightTimer.stop()
	$DirectionalLight2D.hide()
	light_out.emit()
	$DayTimer.start(0)
	
	$NightTimer.wait_time= World.nighttime / World.speed
	#$NightTimer.start(0)
	
	$UI/Clock.Uptade_timesimulation()
	
	$UI/Wspeed.text = "World speed = " + str(World.speed) 



func _on_life_timer_timeout():
		pass
		'pass
		Life.life_to_spawn = Life.new_lifes.duplicate()
		Life.life_to_spawn_position = Life.new_lifes_position.duplicate()
		Life.new_lifes = []
		Life.new_lifes_position = []
		Life.current_batch = 0
		print("....................")
		if Life.life_to_spawn.size()>0:
			#var idealtime = $Life/LifeTimer.wait_time / (Life.life_to_spawn.size()/Life.nb_by_batch)
			$Life/SpawnTimer.wait_time = Life.min_time_by_batch
			
			
		#$Life/SpawnTimer.wait_time = Life.min_time_by_batch
			var nbcycle = $Life/LifeTimer.wait_time / $Life/SpawnTimer.wait_time
			if Life.life_to_spawn.size()/Life.nb_by_batch > nbcycle :
				var idealtime = $Life/LifeTimer.wait_time / (Life.life_to_spawn.size()/Life.nb_by_batch)
				var mintime = Life.min_time_by_batch
				World.speed =  World.speed * idealtime/Life.min_time_by_batch
				UpdateSimulationSpeed()
				$Life/SpawnTimer.wait_time = max(idealtime,mintime)
			
			$Life/SpawnTimer.start(0)
			
		print($Life/SpawnTimer.wait_time)
		print(str(Engine.get_frames_per_second()) + " FPS")
		print(str(Life.life_to_spawn.size()) + " spawn")'
		
		'if Engine.get_frames_per_second() < 30:
			#Life.min_time_by_batch = Life.min_time_by_batch*2
			World.speed =  World.speed / 2
			UpdateSimulationSpeed()'
		'else:
			Life.min_time_by_batch = 0.1'
		



		'Life.LifeLoopCPU($Life)
		Life.InstantiateNewLifeBatchCPU($Life)'
		#for l in Life.new_lifes:
			#$Life.add_child(l)
	#Life.LifeLoopCPU($Life) 
	

func _on_spawn_timer_timeout():
	Life.Extend_emptyLife_pool($Life,1)
	Life.current_batch += 1	
	$UI/ProgressBar.value = (Life.current_batch - Life.max_life ) * 100 / (Life.new_max_life - Life.max_life )
	
	if Life.current_batch > Life.new_max_life:
		Life.max_life = Life.new_max_life
		$UI/ProgressBar.hide()
		$Life/SpawnTimer.stop()
		get_tree().paused = false
		


		
	
	'Life.Instantiate_emptyLife_pool_in_Batch($Life,Life.current_batch,Life.nb_by_batch)
	#var s = Time.get_ticks_msec()
	#Life.Instantiate_NewLife_in_Batch($Life,Life.current_batch,Life.nb_by_batch,Life.life_to_spawn,Life.life_to_spawn_position) # Replace with function body.
	#print(Life.current_batch)
	$ProgressBar.value = Life.current_batch * 100 / Life.max_life
	Life.current_batch += Life.nb_by_batch
	#print(Life.current_batch)
	#var ss = Time.get_ticks_msec()
	#print(str(ss-s) + " ms passed in spawn cycle")


	if Life.current_batch > Life.max_life:
		Life.Instantiate_Life_in_pool($Life,15,0)
		initialized = true
		get_tree().paused = false
		$ProgressBar.hide()
		$Life/SpawnTimer.stop()'




'func _on_brain_timer_timeout():
	pass
	#Brain.BrainLoopCPU($Life)'

func _on_block_timer_timeout():
	pass
	#World.BlockLoopGPU() 

	'for b in $Blocks.get_children():
		b.BlockUpdate()'


	
signal light_on
signal light_out

func _on_day_timer_timeout():
	
	#$UI/Night_filtre.show()
	$DirectionalLight2D.show()
	$NightTimer.start()
	light_on.emit()
	World.isNight = true

	


func _on_night_timer_timeout():
	World.day += 1 # Replace with function body.
	$DirectionalLight2D.hide()
	#$UI/Night_filtre.hide()
	light_out.emit()
	$DayTimer.start()
	$UI/DayCount.show()
	$UI/DayCount.text = "Day " + str(World.day)
	$UI/DayCount/Timer.start()
	World.isNight = false
'func _exit_tree():
	thread.wait_to_finish()
	

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		thread.wait_to_finish()
		get_tree().quit() # default behavior'

func CallGameOver():

	$UI/GameOver.SetUp_GameOver_Screen()
	$UI/GameOver.show()
	#gameover = true
	get_tree().paused = true

'func _on_speed_1_pressed():	
	World.speed = 1
	UpdateSimulationSpeed() # Replace with function body.
	world_speed_changed.emit()

func _on_speed_2_pressed():

	World.speed = 2
	UpdateSimulationSpeed() # Replace with function body.
	world_speed_changed.emit()
 # Replace with function body.

func _on_speed_10_pressed():

	World.speed = 10
	emit_signal("world_speed_changed")
	UpdateSimulationSpeed() # Replace with function body.


func _on_speed_100_pressed():
	World.speed = 100
	world_speed_changed.emit()
	emit_signal("world_speed_changed")

	UpdateSimulationSpeed() # Replace with function body.'

 # Replace with function body.


'func _on_button_restart_pressed():
	pass # Replace with function body.
	gameover = false
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
	#$UI/GameOverPanel.hide()
	
func _on_button_respawn_pressed():
	Life.player_index = Life.BuildPlayer($Life)
	#$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	$Life/Player.INDEX = Life.player_index # Replace with function body.
	$Life/Player/Sprite2D.show()
	$UI/GameOverPanel.hide()
	gameover = false'
	
func _input(event): #gameover fonction
	if event.is_action_pressed("interact"):
		pass
		'for b in $Blocks.get_children():
			b.queue_free()
		
		World.InstantiateALLBlock($Blocks)'
		#var playerworldpos = World.getWorldPos(player.global_position)
		#World.InstantiateBlockAroundPlayer2(playerworldpos.x,playerworldpos.y,$Blocks,player.get_node("Camera2D").zoom)

		pass
		'Life.sheep_pool_scene[0].isPlayer = true
		#Life.sheep_pool_scene[0].set_physics_process(true)
		var camera = $Life/Camera2D
		$Life.remove_child($Life/Camera2D)
		Life.sheep_pool_scene[0].add_child(camera)'

		#.isPlayer = true
	#	$UI/GameOver.show()
	#	get_tree().paused = true
	'if event.is_action_pressed("Spawn"):
		var posmouse =	get_global_mouse_position()
		var x = int(get_global_mouse_position().y/World.tile_size)
		var y = int(get_global_mouse_position().x/World.tile_size)
		if (x >= 0 and y >= 0 and x < World.world_size and y < World.world_size):
			var idx = Life.BuildLife(x,y,$SpawnWindow.genome_ID,$Life)
			if idx != null :
				Life.parameters_array[idx*Life.par_number + 3] = $SpawnWindow.current_cycle
'

	if event.is_action_pressed("Spawn"):
		pass
		'Life.current_batch = Life.grass_pool_scene.size()
		Life.new_max_life = Life.max_life + 100
		$UI/ProgressBar.show()
		$Life/SpawnTimer.wait_time = Life.min_time_by_batch
		$Life/SpawnTimer.start(0)
		get_tree().paused = true'

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
