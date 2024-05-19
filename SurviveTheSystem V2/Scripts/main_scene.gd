extends Node2D

'This Script is for the main game loop'


# Called when the node enters the scene tree for the first time.
func _ready():
	Life.Init_matrix()
	Life.Init_Genome()
	Item.Init_Item()
	$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	for i in World.world_size:
		for j in World.world_size:
			World.InstantiateBlock(i,j,$Blocks)
			if i == 0 and j == 0:
				#Life.BuildLife(i,j,4,$Life)
				pass
			if i == int(World.world_size-1) and j == int(World.world_size-1):
				Life.BuildLife(i,j,0,$Life)
				pass
			if i == int(World.world_size-1) and j == 0:
				Life.BuildLife(i,j,2,$Life)
				pass
			if i == 1 and j == 5:
				Item.BuildItem(i,j,0,$Items)
			if i == int(World.world_size-1) and j == 10:
				Life.BuildLife(i,j,1,$Life)
				pass

			'if i == 7 and j == 15:
				Life.world_matrix[i*World.world_size + j] = 2
				Life.Init_Parameter(2,0)							
			if i == 10 and j == 13:
				Life.world_matrix[i*World.world_size + j] = 3
				Life.Init_Parameter(3,0)'	
	#Life.InstantiateLife(0,$Life)
	#Life.InstantiateLife(1,$Life)
	#Life.InstantiateLife(2,$Life)
	#Life.InstantiateLife(3,$Life)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$StarBackground.position = $Life/Player.position  #background follow player
	$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
	$UI/Debug.text = "  " + str(Life.plant_number) + " plants " + str(World.element) + " element"
	'var idx = Life.state_array.find(0)
	if idx >= 0:
		Life.InstantiateLife(idx,$Life)
		Life.InstantiateLife(idx)
		pass'
	
	



func _on_life_timer_timeout():
	Life.LifeLoopCPU($Life) 
	pass

