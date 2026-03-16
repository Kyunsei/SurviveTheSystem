extends STATE
class_name AVOID_STATE

var speed = 50

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
	var bin_flow = _manager.calculate_flow_at_bin(5,bin)
	var step =  -bin_flow.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)

	_manager.position_array[_i] += step	
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2+1, _manager.World.World_Size.x/2-1)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2+1 , _manager.World.World_Size.z/2-1)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	

	
