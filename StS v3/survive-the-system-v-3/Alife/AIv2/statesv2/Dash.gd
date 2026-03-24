extends STATE
class_name DASH_STATE

@export var dash_speed = 10000
#var dash_speed = 10

@export var Previous_State_ID : int = 3
@export var bin_vision_range : int = 4

func evaluate(_manager,_i, _DNA):
	var score = 0
	if _manager.current_finite_state_array[_i] == 	state_internal_id:
		score = 100		
	return score

func enter(_manager,_i, _DNA):
	_manager.timer_array[_i] =0.3
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)
	for s in _DNA.food_species_id : #HERE TAKE THE LAST OF LIST , CAN TRIGGER PRIORITY HERE
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,s)
		if close_target_id:
			var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
			dir.y = 0
			var speed = dir.normalized() * dash_speed/50.
			_manager.current_velocity_array[_i] = speed #* _delta * GlobalSimulationParameter.simulation_speed
	pass


func exit(_manager,_i, _DNA):
	_manager.current_finite_state_array[_i] = 0 #DEFAULT?
	_manager.timer_array[_i] = 0

func update(_manager,_i, _DNA, _delta):
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)


	_manager.position_array[_i] += _manager.current_velocity_array[_i]	* _delta * GlobalSimulationParameter.simulation_speed#SIMULATION SPEED?
	
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2, _manager.World.World_Size.x/2)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2 , _manager.World.World_Size.z/2)
	
	for s in _DNA.food_species_id : #CAN BE A LITTLE STRANGE HERE??
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,s)	
		if close_target_id:
			if (_manager.position_array[close_target_id] - _manager.position_array[_i]).length() < 2:
				self.exit(_manager,_i, _DNA)
				print("here")

	
	
	_manager._pending_update.append(_i)
	change_bin(_manager,_i)
		
		
	_manager.timer_array[_i] -=  _delta
	if _manager.timer_array[_i] <= 0:
		print("end of time")
		self.exit(_manager,_i, _DNA)


	
