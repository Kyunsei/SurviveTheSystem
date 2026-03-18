extends STATE
class_name PREP_DASH_STATE

@export var timer_prep = 2.
@export var next_state : STATE
@export var next_state_id : int = 2
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
	if _manager.Species_array[_i] == 6:
		pass#print( "Prep score is " + str(score))
	return score 

func enter(_manager,_i, _DNA):
	_manager.timer_array[_i] = timer_prep
	pass

func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA,_delta):
	_manager.timer_array[_i] -= _delta
	if _manager.timer_array[_i] <=0 :
		#self.exit(_manager,_i, _DNA)
		_manager.timer_array[_i] = 0
		_manager.timer_array[_i] = 0
		next_state.enter(_manager,_i, _DNA)
		_manager.current_finite_state_array[_i] = next_state_id

		#next_state.enter(_manager,_i, _DNA)





###HELPER FUNCTION


	
	

	
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
	
