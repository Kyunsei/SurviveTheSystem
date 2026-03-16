extends STATE
class_name EAT_STATE

@export var food_type : PackedInt32Array

func evaluate(_manager,_i, _DNA):
	var score: float = 0
	var bin = _manager.binID_array[_i]
		
	if bin == null:
		return score 
		

	#ENERGY SCORE
	var t = _manager.current_life_state_array[_i] 
	score += 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]
	#print(_manager.current_energy_array[_i] / _DNA.Max_energy[t])

	#DITANCE OF FOOD SCORE
	#var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,1)
	if _manager.sum_species_world_array[0][bin] > 0:
		var targets = _manager.World.bin_array[bin]
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,0)
		var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
		if dir.length() > 0.2 or targets.size() == 0:
			score *= 0  #25 is the max life in a place...
	else:
		score *= 0

	'for f in food_type:
		score =  _manager.sum_species_world_array[f][bin]'

	#print( "Eat score is " + str(score))
	return  score


func enter(_manager,_i, _DNA):
	#print("Eat selected")
	pass
	

func exit(_manager,_i, _DNA):
	pass

func update(manager,i, _DNA, _delta):
	#print("EATING")
	var bin = manager.binID_array[i]
	#print(manager.field_world_array[0][bin])
	#print(manager.field_world_array[0][bin+1])
	#print(manager.calculate_flow_at_bin(0,bin).normalized())

	var ti = find_closest_in_bin(manager,i, bin,  0)
	if ti != null:


		#manager.current_health_array[ti] = -100
		if manager._pending_kills.has(ti) == false:
			manager._pending_kills.append(ti)
			manager.current_energy_array[i] += manager.current_biomass_array[ti]

			
		#manager.Active[ti] = 0

		#manager.current_energy_array[i] += manager.current_biomass_array[ti]
	#print(manager.current_energy_array[i])


func find_closest_in_bin(manager,i, bin,  t_sp):
	var closest = null
	var closest_distance = INF
	
	for ti in manager.World.bin_array[bin]:
		if ti is Dictionary:
			print("OLD SYSTEM STILL IN BIN")
		else:
			if manager.Active[ti] == 0:
				#print("nonactive")
				continue
			if manager.Species_array[ti] != t_sp:
				#print("nongrass")
				continue
			var t_pos = manager.position_array[ti]
			var distance = manager.position_array[i].distance_to(t_pos)
			if distance < closest_distance:
					closest_distance = distance
					closest = ti
	return closest	
