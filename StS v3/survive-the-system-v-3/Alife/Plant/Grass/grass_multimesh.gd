extends MultiMeshInstance3D

var World:Node3D

var instance_number = 0


func draw_all_grass(grass_dict):
	multimesh.instance_count = grass_dict.size()
	multimesh.visible_instance_count = grass_dict.size()
	var index = 0
	for g in grass_dict.values():
		var pos = g["position"]
		g["Instance_ID"] = index
		multimesh.set_instance_transform(index, Transform3D(Basis(), pos))
		index += 1

	
var instance_data: Array = []  # mirrors multimesh slots

func draw_new_grass(g_pos):
	var index = multimesh.instance_count 
	print(index,g_pos)
	multimesh.instance_count +=  1
	multimesh.set_instance_transform(index, Transform3D(Basis(), g_pos))
	#g["Instance_ID"] = index
	#instance_data.append(data)


func remove_grass(g, grass_dict):
	var index = g["Instance_ID"] 
	var last = multimesh.instance_count - 1
	# Swap with last
	if index != last:
		multimesh.set_instance_transform(index, multimesh.get_instance_transform(last))
		#instance_data[index] = instance_data[last]
	#instance_data.pop_back()
	grass_dict[g["ID"]]["Instance_ID"] = index
	multimesh.instance_count -= 1

	
	
