extends STATE
class_name AVOID_STATE

var speed = 50
@export var target_species : int = 5

func evaluate(_manager,_i, _DNA):
	#return 0.0
	var bin = _manager.binID_array[_i]
	#var bin_flow = _manager.calculate_flow_at_bin(1,bin)
	var field = _manager.field_world_array[5][bin]

	var score = field * 10
	#print( "AVOID score is " + str(score))

	return score

func enter(_manager,_i, _DNA):
	pass


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	var bin = _manager.binID_array[_i]
	var bin_flow = _manager.calculate_flow_at_bin(target_species,bin)
	var step =  -bin_flow.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
	#var count = _manager.sum_species_world_array[target_species][bin]
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,1)
	var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,target_species)

	#print(field)
	if close_target_id:
			var dir = ( _manager.position_array[_i] - _manager.position_array[close_target_id])
			dir.y = 0
			step =  dir.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)	


	_manager.position_array[_i] += step	
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2+1, _manager.World.World_Size.x/2-1)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2+1 , _manager.World.World_Size.z/2-1)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	

	
