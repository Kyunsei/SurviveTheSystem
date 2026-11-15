extends Node3D
class_name WorldRender3D

var ground_gridmap : GridMap
var tile_size := Vector3(5,0.5,5)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ground_gridmap = $GROUND_GridMap
	pass # Replace with function body.



func DrawWorld(world:WorldManager):
	ground_gridmap.clear()
	var W := world.size.x/tile_size.x
	var H := world.size.y
	var D := world.size.z/tile_size.z
	var tile_id := 0 

	var y := -1 #tile_size.y  #Skip for moment because flat world
	for x in W:
		#for y in H:
			for z in D:
				ground_gridmap.set_cell_item(Vector3i(x, y, z), tile_id)
