extends Node3D

@rpc("any_peer","call_local")
func spawn_item(itemdata,pos):
	var scene = load(itemdata["inventory_path"])
	var newitem = scene.instantiate()
	newitem.position = pos
	add_child(newitem)
	newitem.Add()


@rpc("any_peer","call_local")
func spawn_new_item(path,pos):
	var scene = load(path)
	var newitem = scene.instantiate()
	newitem.position = pos
	add_child(newitem,true)
	newitem.Add()
