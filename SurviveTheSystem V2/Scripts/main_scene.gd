extends Node2D

'This Script is for the main game loop'


# Called when the node enters the scene tree for the first time.
func _ready():
	Life.Init_matrix()
	Life.Init_Genome()
	for i in World.world_size:
		for j in World.world_size:
			World.InstantiateBlock(i,j,$Blocks)
			if i == 5 and j == 5:
				Life.world_matrix[i*World.world_size + j] = 0
				Life.Init_Parameter(0,0)
			if i == 1 and j == 5:
				Life.world_matrix[i*World.world_size + j] = 1
				Life.Init_Parameter(1,0)
			if i == 7 and j == 15:
				Life.world_matrix[i*World.world_size + j] = 2
				Life.Init_Parameter(2,0)							
			if i == 10 and j == 13:
				Life.world_matrix[i*World.world_size + j] = 3
				Life.Init_Parameter(3,0)	
	Life.InstantiateLife(0,$Life)
	Life.InstantiateLife(1,$Life)
	Life.InstantiateLife(2,$Life)
	Life.InstantiateLife(3,$Life)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$StarBackground.position = $Life/Player.position  #background follow player
	$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
	pass
	
	

