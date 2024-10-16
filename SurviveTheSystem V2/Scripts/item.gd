extends Node
'Global script for item'

var item_scene = load("res://Scenes/item.tscn") #load scene of block

var item_array = []
var state_array = []
var par_number = 3  #item_INDEX, equipped, itemstate

var number_item = 10

var item_information = {}





func Init_matrix():
	item_array.resize(number_item*par_number)
	item_array.fill(-1)
	state_array.resize(number_item)
	state_array.fill(-1)
	
func init_parameter(INDEX,item_index):
	item_array[INDEX*par_number + 0] = item_index
	item_array[INDEX*par_number + 1] = 0
	item_array[INDEX*par_number + 2] = 0
	pass
	
func BuildItem(x,y,item_index,folder):
	var newindex = state_array.find(-1)
#	world_matrix[x*World.world_size + y] = newindex
	init_parameter(newindex,item_index)
	state_array[newindex] = 1
	InstantiateItem(x,y,newindex,folder)

func InstantiateItem(x,y,INDEX,folder):
	var new_item = item_scene.instantiate()
	new_item.position = Vector2(x*World.tile_size,y*World.tile_size)
	new_item.name =str(INDEX)
	new_item.INDEX = INDEX
	folder.add_child(new_item)



func Init_Item():
	Init_matrix()
	item_information[0] = { #sprite 0 , scythe
		'sprite' : [load("res://Art/scythe.png")],
		'sprite_empty' : [load("res://Art/scythe.png")],
		'use' : [1],
		'damagevalue': [10],
		'throw':[10],
		'eat':[1],
		'attack':[1]
	}
	
	item_information[1] = { #sprite 1 , star
		'sprite' : [load("res://Art/poop_star.png")],
		'sprite_empty' : [load("res://Art/poop_star_0.png")],
		'use' : [2], # 0 : nothing , 1: on , 2 : earth retrieval and disposal
		'damagevalue': [1],
		'throw':[5], # 0 : can't be launched , 1: throw 100 , 5 : throw 500
		'eat':[0],
		'attack':[1]
	}


	item_information[2] = { #sprite 2 , crystal spear
		'sprite' : [load("res://Art/scythe.png")],
		'sprite_empty' : [load("res://Art/scythe.png")],
		'use' : [1],
		'damagevalue': [10],
		'throw':[1],
		'eat':[0],
		'attack':[1]
	}
