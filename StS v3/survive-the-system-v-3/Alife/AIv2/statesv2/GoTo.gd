extends STATE
class_name GOTO_STATE

var speed = 5

func evaluate(_manager,_i, _DNA):
	var t = _manager.current_life_state_array[_i] 
	var score = 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]
	#print( "GoTo score is " + str(score))
	return score

func enter(_manager,_i, _DNA):
	pass


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	var bin = _manager.binID_array[_i]
	var bin_flow = _manager.calculate_flow_at_bin(0,bin)

	var field = _manager.field_world_array[0][bin]
	#print(field)
	var step =  bin_flow.normalized()  * speed * _delta * GlobalSimulationParameter.simulation_speed 
	var target_distance  =  log(field / 10.0) / 0.15 
	#print(target_distance)
	var estimated_target = _manager.position_array[_i] + bin_flow.normalized() * target_distance
	
	if step.length() > abs(target_distance):
		_manager.position_array[_i] = estimated_target
	else:
		_manager.position_array[_i] += step
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2+1, _manager.World.World_Size.x/2-1)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2+1 , _manager.World.World_Size.z/2-1)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	
	#_manager.calculate_flow_at_bin(0,bin)
	#_manager.put_in_world_bin(_i)
	
	#print(_manager.calculate_flow_at_bin(0,bin))
	#print(_manager.position_array[_i])
	
func change_bin(_manager,_i):
	var old_bin = _manager.binID_array[_i]
	var current_bin = _manager.get_real_current_bin(_i)


	if old_bin == current_bin:
		return
	else:		
		_manager.remove_from_world_bin(_i)
		_manager.put_in_world_bin(_i)
	
	
	
	
	
