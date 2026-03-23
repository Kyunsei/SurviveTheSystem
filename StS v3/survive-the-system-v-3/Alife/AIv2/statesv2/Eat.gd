extends STATE
class_name EAT_STATE

var target_species : int = 0
@export var distance_to_eat : float = 0.2

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
	var food_score = 0
	for f in _DNA.food_species_id :
		var fscore = 0
		if _manager.sum_species_world_array[f][bin] > 0:
			var targets = _manager.World.bin_array[bin]
			var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,f)
			if close_target_id:
				var dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
				if dir.length() > distance_to_eat or targets.size() == 0:
					fscore = 0  #25 is the max life in a place...
				else:
					fscore = 2
		if fscore > food_score:
			food_score = fscore
	score*= food_score
	'for f in food_type:
		score =  _manager.sum_species_world_array[f][bin]'
	if _manager.Species_array[_i] == 6:
		pass#print( "Eat score is " + str(score))
	return  score


func enter(_manager,_i, _DNA):
	#print("Eat selected")
	pass
	

func exit(_manager,_i, _DNA):
	pass

func update(manager,i, _DNA, _delta):
	#print("EATING")
	#var bin = manager.binID_array[i]
	var targets = manager.get_index_in_bin_around(manager.World.bin_array,i,1)

	#print(manager.field_world_array[0][bin])
	#print(manager.field_world_array[0][bin+1])
	#print(manager.calculate_flow_at_bin(0,bin).normalized())
	for f in _DNA.food_species_id:
		var ti = find_closest(manager,manager.position_array[i], targets,  f)
		if ti != null:


			#manager.current_health_array[ti] = -100
			if manager._pending_kills.has(ti) == false:
				manager._pending_kills.append(ti)
				manager.current_health_array[ti] = -10
				manager.Alive_array[ti] = 0

				manager.current_energy_array[i] += manager.current_biomass_array[ti]
				manager.current_energy_array[i] = min(manager.current_energy_array[i],_DNA.Max_energy[0] )
				
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
