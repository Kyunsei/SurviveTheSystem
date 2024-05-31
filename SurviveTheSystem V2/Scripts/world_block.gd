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
	$debug.text = str("%.1f" % World.block_element_array[posindex])
	'if Life.world_matrix[posindex] == -1:
		$ColorRect.hide()
	else:
		$ColorRect.show()
	pass'
	$ColorRect.color = getAdjustedSoilColor()
	#$outsideline.color = getAdjustedSoilColor()

func getAdjustedSoilColor():
	var colormax = Color(0.3, 0.2, 0.1, 1)
	var colormin = Color(0.8, 0.6, 0.4, 1)
	var x = min(1, World.block_element_array[posindex]/10 )
	var col = lerp(colormin, colormax, x)
	return col
