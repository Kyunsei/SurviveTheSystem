extends STATE
class_name GOTO_STATE

@export var speed = 10
@export var positive_species_id : PackedInt32Array

#@export var target_species : int = 0
@export var final_distance_to_target : float = 0.0
@export var bin_vision_range : int = 1


func evaluate(_manager,_i, _DNA):
	#ENERGY PART
	var bin = _manager.binID_array[_i]
	var t = _manager.current_life_state_array[_i] 
	var score = 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]

	#TARGET PART???
	var dist_score = 1
	for p in positive_species_id:
		var dscore = 1
		var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,p)
		if _manager.Species_array[_i] == 6:
			print (close_target_id)
		if close_target_id:
			var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
			#var dir2 = Vector2(dir.x,dir.z)

			if dir.length() < final_distance_to_target:
				dscore = 0.0#1# _manager.sum_species_world_array[0][bin]/25.  #25 is the max life in a place...
			
		if dist_score < dscore:
			dist_score =dscore
		
			
	score*= dist_score
	if _manager.Species_array[_i] == 6:
		print( "GoTo score is " + str(score))
	return score

func enter(_manager,_i, _DNA):
	#print("goto")
	pass


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	var bin = _manager.binID_array[_i]
	var dir := Vector3(0,0,0)
	var target_species : int
	var field_score = 0
	for s in positive_species_id:
		var subfield_score = _manager.field_world_array[s][bin]
		if subfield_score > field_score:
			field_score = subfield_score
			target_species = s
			
	var bin_flow = _manager.calculate_flow_at_bin(target_species,bin)
	var step =  bin_flow.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
	
	var count = _manager.sum_species_world_array[target_species][bin]
	#print(field)
	if count > 0 :
		var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,target_species)
		if close_target_id:
			dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
			step =  dir.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
			if step.length() > dir.length():
				_manager.position_array[_i] = _manager.position_array[close_target_id]
			else:
				_manager.position_array[_i] += step	
	else:
		_manager.position_array[_i] += step	
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2, _manager.World.World_Size.x/2)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2 , _manager.World.World_Size.z/2)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	

	
