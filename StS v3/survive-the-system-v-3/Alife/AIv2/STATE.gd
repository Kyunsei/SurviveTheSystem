extends Resource
class_name STATE

var state_manager
var player 
var isFinish = true

var state_internal_id : int

func evaluate(_manager,_i, _DNA):
	pass

func enter(_manager,_i, _DNA):
	pass

func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA,_delta):
	pass




###HELPER FUNCTION


	
	
func change_bin(_manager,_i):
	var old_bin = _manager.binID_array[_i]
	var current_bin = _manager.get_real_current_bin(_i)


	if old_bin == current_bin:
		return
	else:		
		_manager.remove_from_world_bin(_i)
		_manager.put_in_world_bin(_i)
	
	
func find_closest(_manager, from_position: Vector3, array: Array,sp):
	var closest = null
	var closest_distance = INF
	
	for element in array:
		if element is Dictionary:
			print("OLD LIFE SYSTEM - DEPRECTED")
		else:
			if _manager.Species_array[element] != sp:
				continue
			var t_pos = _manager.position_array[element]
			var distance = from_position.distance_to(t_pos)
			if distance < closest_distance:
					closest_distance = distance
					closest = element
	return closest		
	
