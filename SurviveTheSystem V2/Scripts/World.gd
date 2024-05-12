extends Node

'This is the global Script for all the variable and function defining the world'

var world_size = 20 #The size in tile of the World
var tile_size = 32 # the size in pixel of each tile

var block_matrix_element = [] #1D matrix of the block composing the world

var block_scene = load("res://Scenes/world_block.tscn") #load scene of block

#different variable for the "element"
#var max_element = 100 #max quantities
var element = 100.0 #current value


func Init_matrix():
	block_matrix_element.resize(world_size)
	block_matrix_element.fill(0)
	

	

func InstantiateBlock(i,j,folder):
	if i >= 0 and j >= 0 and i < world_size and j < world_size:
		var new_block = block_scene.instantiate()
		new_block.get_node("outsideline").size = Vector2(tile_size,tile_size)
		new_block.get_node("ColorRect").size = Vector2(tile_size-1,tile_size-1)
		new_block.position.x = i*tile_size
		new_block.position.y = j*tile_size
		#new_block.color = getBlockColor(i,j)
		new_block.name =str(i)+"_"+str(j)
		folder.add_child(new_block)
		
