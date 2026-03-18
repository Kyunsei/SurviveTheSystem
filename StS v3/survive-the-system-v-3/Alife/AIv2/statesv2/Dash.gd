extends STATE
class_name DASH_STATE

@export var dash_speed = 10000
#var dash_speed = 10

@export var target_species : int = 4

func evaluate(_manager,_i, _DNA):
	var score = 0
	var t = _manager.current_life_state_array[_i] 

	score += 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]

	var bin = _manager.binID_array[_i]
	var field = _manager.field_world_array[target_species][bin]
	#print(field)
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,2)
	var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,target_species)
	if close_target_id:
		if _manager.position_array[close_target_id].distance_to(_manager.position_array[_i]) > 3:	
			score *= 0.0
	return score

func enter(_manager,_i, _DNA):
	pass


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,2)
	var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,target_species)
	if close_target_id:
		var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
		dir.y = 0
		var speed = dir.normalized() * dash_speed
		_manager.current_velocity_array[_i] = speed * _delta * GlobalSimulationParameter.simulation_speed
		_manager.position_array[_i] += _manager.current_velocity_array[_i]	* _delta * GlobalSimulationParameter.simulation_speed#SIMULATION SPEED?
		
		_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2, _manager.World.World_Size.x/2)
		_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2 , _manager.World.World_Size.z/2)

		_manager._pending_update.append(_i)

		change_bin(_manager,_i)
	

	
