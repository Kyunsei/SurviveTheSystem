extends Node2D

var x = 0
var y = 0
var posindex

# Called when the node enters the scene tree for the first time.
func _ready():
	x = int(position.y/World.tile_size)
	y = int(position.x/World.tile_size)
	posindex = x*World.world_size + y
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$debug.text = str(Life.world_matrix[posindex])
	if Life.world_matrix[posindex] == -1:
		$ColorRect.hide()
	else:
		$ColorRect.show()
	pass
