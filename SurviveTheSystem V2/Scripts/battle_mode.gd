extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	World.Init_World()
	Life.Init_matrix()
	Life.Init_Genome()
	Brain.Init_Brain()
	Item.Init_Item()
	$Life/Player.INDEX = Life.BuildPlayer($Life)
	$Life/Player.global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))
	for i in World.world_size:
		for j in World.world_size:
			World.InstantiateBlock(i,j,$Blocks)

	Item.BuildItem($Life/Player.global_position.x/32,$Life/Player.global_position.y/32+3,0,$Items)
	Item.BuildItem($Life/Player.global_position.x/32,$Life/Player.global_position.y/32-3,1,$Items)
	 # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _input(event):
	if event.is_action_pressed("Spawn"):
		
		Life.BuildLifeAtRandomplace($SpawnWindow.genome_ID,$SpawnWindow.current_cycle,$Life)

