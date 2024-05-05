extends Node2D

'This Script is for the main game loop'


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in World.world_size:
		for j in World.world_size:
			World.InstantiateBlock(i,j,$Blocks)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$StarBackground.position = $Player.position  #background follow player
	$UI/FPS.text = "  " + str(Engine.get_frames_per_second()) + " FPS" #FPS
	pass
