extends STATE
class_name GOTOFLOWER_STATE

@export var speed = 10

@export var final_distance_to_target : float = 0.0
@export var bin_vision_range : int = 1


func evaluate(_manager,_i, _DNA):
	#ENERGY PART
	var bin = _manager.binID_array[_i]
	var t = _manager.current_life_state_array[_i] 
	var score = 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]

	#TARGET PART???
	var dist_score = 1
	for p in _DNA.food_species_id :
		var dscore = 1
		var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,p)

		if close_target_id !=null:
			var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
			#var dir2 = Vector2(dir.x,dir.z)

			if dir.length() < final_distance_to_target:
				dscore = 0.0#1# _manager.sum_species_world_array[0][bin]/25.  #25 is the max life in a place...
			
		if dist_score > dscore:
			dist_score =dscore
		
	score*= dist_score
	return score

func enter(_manager,_i, _DNA):
	pass
	#print("flowr")

func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	var bin = _manager.binID_array[_i]
	var dir := Vector3(0,0,0)
	var target_species : int
	var field_score = 0
	#print("fef")
	'for s in _DNA.food_species_id :
		var subfield_score = _manager.field_world_array[s][bin]
		if subfield_score > field_score:
			field_score = subfield_score
			target_species = s'
			
	var bin_flow = _manager.calculate_anyflow_at_bin(_manager.flower_field,bin)
	#print(bin_flow.normalized())
	var step =  bin_flow.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
	
	#var count = _manager.sum_species_world_array[target_species][bin]
	#print(field)
	#if count > 0 :
	var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,bin_vision_range)
	var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,AlifeRegistry.SPECIES_ID.SPIKYFLOWER)
	if close_target_id != null:
		dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
		step =  dir.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
		if step.length() > dir.length():
			_manager.position_array[_i] = _manager.position_array[close_target_id]
		else:
			_manager.position_array[_i] += step	
	else:
		_manager.position_array[_i] += step	
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2-1, _manager.World.World_Size.x/2-1)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2-1 , _manager.World.World_Size.z/2-1)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	

	
func find_closest(_manager, from_position: Vector3, array: Array,sp):
	var closest = null
	var closest_distance = INF
	
	for element in array:
		if element is Dictionary:
			print("OLD LIFE SYSTEM - DEPRECTED")
		else:
			if _manager.Species_array[element] != sp:
				continue
			if _manager.current_life_state_array[element] != 3:
				continue

			var t_pos = _manager.position_array[element]
			var distance = from_position.distance_to(t_pos)
			if distance < closest_distance:
					closest_distance = distance
					closest = element
	return closest			



func calculate_flow_at_bin(manager, bin: int):
	var GRID_WIDTH: int =  int(manager.World.World_Size.x/ manager.World.bin_size.x)
	var GRID_HEIGHT: int =  int(manager.World.World_Size.z/ manager.World.bin_size.z)
	var row := bin / GRID_WIDTH
	var col := bin % GRID_WIDTH
	var dx := 0.0
	var dz := 0.0
	var flow  = manager.flower_field
	# X gradient
	if col > 0 and col < GRID_WIDTH - 1:
		dx = flow[bin + 1] - flow[bin - 1]  # central
	elif col == 0:
		dx = flow[bin + 1] - flow[bin]      # forward
	else:
		dx = flow[bin] - flow[bin - 1]      # backward


	# Z gradient
	if row > 0 and row < GRID_HEIGHT - 1:
		dz = flow[bin + GRID_WIDTH] - flow[bin - GRID_WIDTH]
	elif row == 0:
		dz =flow[bin + GRID_WIDTH] - flow[bin]
	else:
		dz = flow[bin] - flow[bin - GRID_WIDTH]


	var flow_final = Vector3(dx, 0, dz)
	return flow_final
