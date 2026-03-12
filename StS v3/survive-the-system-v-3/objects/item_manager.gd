extends Node3D

@rpc("any_peer","call_local")
func spawn_item(itemdata,pos):
	var scene = load(itemdata["inventory_path"])
	var newitem = scene.instantiate()
	newitem.position = pos
	add_child(newitem,true)
	newitem.Add()



@rpc("any_peer","call_local")
#@rpc("any_peer")
func spawn_new_item(path,pos):
	#if !multiplayer.is_server():
		#return
	#if multiplayer.is_server():
	var scene = load(path)
	var newitem = scene.instantiate()
	newitem.position = pos
	add_child(newitem,true)
	#add_child(newitem)
	newitem.Add()
