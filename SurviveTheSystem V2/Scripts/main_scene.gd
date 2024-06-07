extends Node2D

'This Script is for the main game loop'

var playerindex = 0
var gameover = false

#to load the map
var batch_size = 20
var current_batch = 0
var initialized = false

var thread = Thread.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	World.Init_World()
	
	Life.Init_matrix()
	Life.Init_Genome()
	Brain.Init_Brain()
	
	Item.Init_Item()

	for i in range(Life.max_life):
		Life.BuildLifeAtRandomplace(0,1,$Life)
	Life.player_index = Life.BuildPlayer($Life)
	$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	$Life/Player.INDEX = Life.player_index
	var playerworldpos = World.getWorldPos($Life/Player.global_position)
	World.InstantiateBlockAroundPlayer(playerworldpos.x,playerworldpos.y,$Blocks)
	Item.BuildItem(playerworldpos.x,playerworldpos.y-1,0,$Items)
	Item.BuildItem(playerworldpos.x,playerworldpos.y+1,1,$Items)



	
func InitEmptyLife():
	for i in range(current_batch, current_batch + batch_size):
		if i < Life.max_life:
			print(i)
			if i != Life.player_index: #player
				Life.InstantiateEmptyLife(i,$Life)
	current_batch = (current_batch + batch_size)
	if current_batch > Life.max_life:
		initialized = true
	'for n in range(20):
		Life.BuildLifeRDinThread(0,1,$Life)
	for n in range(5):
		Life.BuildLifeRDinThread(1,2,$Life)
	for n in range(20):
		Life.BuildLifeRDinThread(2,2,$Life)
	for n in range(0):
		Life.BuildLifeRDinThread(4,0,$Life)'


	
	


func _process(delta):
	if initialized != true:
		pass
		InitEmptyLife()
		#InstatiateAllLifeScene()
	
	var playerworldpos = World.getWorldPos($Life/Player.global_position)
	#World.ActivateAndDesactivateBlockAround($Life/Player.input_dir, playerworldpos.x,playerworldpos.y,$Blocks)
	
	if Life.state_array[playerindex] <= 0:
		$UI/GameOverPanel.show()
		gameover = true
	if World.day > 10 and  gameover== false:
		$UI/VictoryPanel.show()
		$UI/VictoryPanel/Label.text = "Victory! \n" + "You survived " +  str(World.day) + " days\n" + "score: " + str(Life.score)
		
	if $Life/Player != null:
		$StarBackground.position = $Life/Player.position  #background follow player
	$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
	$UI/Debug.text = "  " + str(Life.plant_number) + " plants "  + str(World.day) + " day"
	'var idx = Life.state_array.find(0)
	if idx >= 0:
		Life.InstantiateLife(idx,$Life)
		Life.InstantiateLife(idx)
		pass'
	#Life.deleteLoopCPU($Life)
	

func UpdateSimulationSpeed():
	$BlockTimer.wait_time = 5. / World.speed
	$BlockTimer.start(0)
	
	
	$Life/LifeTimer.wait_time = 10.0 / World.speed
	$Life/LifeTimer.start(0)
	
	$Life/BrainTimer.wait_time = 2.0 / World.speed
	$Life/BrainTimer.start(0)
	
	$DayTimer.wait_time= 20. / World.speed
	$DayTimer.start(0)

func _on_life_timer_timeout():
	if initialized:
		pass
		'var s1 = Time.get_ticks_msec() 
		#print("loop started")
		thread = Thread.new()
		thread.start(Life.LifeLoopCPU.bind(thread))
		var s2 = Time.get_ticks_msec() 
		print("Scene with " + str(s2-s1))'
		
		Life.LifeLoopCPU($Life)
		#for l in Life.new_lifes:
			#$Life.add_child(l)
	#Life.LifeLoopCPU($Life) 
	
	
func _on_brain_timer_timeout():
	pass
	#Brain.BrainLoopCPU($Life)

func _on_block_timer_timeout():
	pass
	#World.BlockLoopGPU() 
	

func _on_day_timer_timeout():
	World.day += 1 # Replace with function body.


func _exit_tree():
	thread.wait_to_finish()
	

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		thread.wait_to_finish()
		get_tree().quit() # default behavior

func GameOver():
	pass

func _on_speed_1_pressed():
	World.speed = 1
	UpdateSimulationSpeed() # Replace with function body.


func _on_speed_2_pressed():
	World.speed = 2
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.


func _on_speed_100_pressed():
	World.speed = 100
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.


func _on_button_restart_pressed():
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
	gameover = false
	
func _input(event):
	if event.is_action_pressed("Spawn"):
		var posmouse =	get_global_mouse_position()
		var x = int(get_global_mouse_position().y/World.tile_size)
		var y = int(get_global_mouse_position().x/World.tile_size)
		if (x >= 0 and y >= 0 and x < World.world_size and y < World.world_size):
			var idx = Life.BuildLife(x,y,$SpawnWindow.genome_ID,$Life)
			if idx != null :
				Life.parameters_array[idx*Life.par_number + 3] = $SpawnWindow.current_cycle




func _on_button_continue_pressed():
	$UI/VictoryPanel.hide()
	gameover = true # Replace with function body.


func _on_speed_10_pressed():

	World.speed = 10
	UpdateSimulationSpeed() # Replace with function body.

 # Replace with function body.
