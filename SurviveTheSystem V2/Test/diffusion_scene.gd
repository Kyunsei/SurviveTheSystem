extends Node2D

'This Script is for the diffusion test game loop'

var playerindex = 0
var gameover = false


#to load the map
var batch_size = 20
var current_batch = 0
var initialized = false

#var thread = Thread.new()

var allblocks

var player


# Called when the node enters the scene tree for the first time.
func _ready():

	InitNewGame()
	#$Life/Player/Sprite2D.texture = Life.player_skin[Life.player_skin_ID]
	
	'Life.current_batch = 0
	$Life/SpawnTimer.wait_time = Life.min_time_by_batch
	$Life/SpawnTimer.start(0)
	get_tree().paused = true'

	

	

	
func _process(delta):

		if player != null:
			var playerworldpos = World.getWorldPos(player.global_position)
			World.ActivateAndDesactivateBlockAround(player.input_dir, playerworldpos.x,playerworldpos.y,allblocks)
			$StarBackground.position = player.position  #background follow player
			
		$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
		#$UI/Debug.text = str(World.day) + " day \n" +"berry: " +   str(Life.berry_number) + " / " + str(Life.berry_pool_state.size()) + " \n" + "sheep: " +   str(Life.sheep_number) + " / " + str(Life.sheep_pool_state.size()) + " \n" + "grass: "  + str(Life.plant_number) + " / " + str(Life.max_life)  + "\n stingtree: " +   str(Life.stingtree_number) + " / " + str(Life.stingtree_pool_state.size()) + " \n" + "crabspider: " +   str(Life.spidercrab_number) + " / " + str(Life.spidercrab_pool_state.size())   
		$UI/Debug.text = "grass: " +   str(Life.plant_number) + " / " + str(Life.grass_pool_state.size())
		



func InitNewGame():
	#Init the World
	World.world_size = 25
	World.Init_World()
	for i in range(World.block_element_array.size()):
		if i < 25*25-150:
			World.block_element_array[i] = 0

		else: 
			World.block_element_array[i] = 6
	
	UpdateSimulationSpeed()
	
	#init Life
	Life.Init_life_pool()
	
	Life.Instantiate_emptyLife_pool($Life, 1500, "grass")
	player = Life.life_debug_scene.instantiate() #need to write code according to genome ID
	$Life.add_child(player)
	player.isPlayer = true #HERE
	player.Activate()
	#player.get_node("Camera2D").enabled = true 
	player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	var playerworldpos = World.getWorldPos(player.global_position)
	World.InstantiateBlockAroundPlayer2(playerworldpos.x,playerworldpos.y,$Blocks,1)
	#World.InstantiateALLBlock($Blocks)
	allblocks = $Blocks.get_children()
	



	

func UpdateSimulationSpeed():
	$BlockTimer.wait_time = World.diffusion_speed / World.speed
	$BlockTimer.start(0)

	
	$UI/Wspeed.text = "World speed = " + str(World.speed) 




func _on_spawn_timer_timeout():
	Life.Extend_emptyLife_pool($Life,1)
	Life.current_batch += 1	
	$UI/ProgressBar.value = (Life.current_batch - Life.max_life ) * 100 / (Life.new_max_life - Life.max_life )
	
	if Life.current_batch > Life.new_max_life:
		Life.max_life = Life.new_max_life
		$UI/ProgressBar.hide()
		$Life/SpawnTimer.stop()
		get_tree().paused = false
		


		



func _on_block_timer_timeout():
	pass
	World.BlockLoopGPU() 
	for b in $Blocks.get_children():
		b.BlockUpdate()



func _on_speed_1_pressed():	
	World.speed = 1
	UpdateSimulationSpeed() # Replace with function body.


func _on_speed_2_pressed():

	World.speed = 2
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.

func _on_speed_10_pressed():

	World.speed = 10
	emit_signal("world_speed_changed")
	UpdateSimulationSpeed() # Replace with function body.


func _on_speed_100_pressed():
	World.speed = 100

	emit_signal("world_speed_changed")

	UpdateSimulationSpeed() # Replace with function body.


func SpawnGrass():
	var li = Life.grass_pool_state.find(0)	
			#+ Life.grass_pool_state.size()*0.05
	if li > -1 and Life.plant_number  < Life.grass_pool_state.size():
				Life.grass_pool_scene[li].Activate()
				Life.grass_pool_scene[li].energy = 1
				Life.grass_pool_scene[li].age = 0
				Life.grass_pool_scene[li].current_life_cycle = 0
				Life.grass_pool_scene[li].PV = 5
				Life.plant_number += 1
				Life.grass_pool_scene[li].global_position = player.position
	else:
				print("pool empty")
	
func _input(event): #gameover fonction
	if event.is_action_pressed("interact"):
		SpawnGrass()
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



func _on_diffusion_button_pressed():
		if $UI/DiffusionButton.text == "Hide":
			$UI/DiffusionButton.text = "Show"
			$UI/DiffussionPanel.hide()
		elif $UI/DiffusionButton.text == "Show":
			$UI/DiffusionButton.text = "Hide"
			$UI/DiffussionPanel.show()


