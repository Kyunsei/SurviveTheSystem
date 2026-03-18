extends STATE
class_name FLOCK_STATE


@export var max_speed := 10.0
@export var max_force := 10.0

@export var neighbor_radius := 10.0
@export var separation_radius := 4.0

@export var weight_separation := 100.0
@export var weight_alignment := .0
@export var weight_cohesion := 1.0

@export var target_species : int = 4# _manager.SPECIES_ID.SHEEP


func evaluate(_manager,_i, _DNA):
	#ENERGY PART
	#var bin = _manager.binID_array[_i]
	var bin = _manager.binID_array[_i]
	var t = _manager.current_life_state_array[_i] 
	var count = min(1,_manager.sum_species_world_array[target_species][bin] - 1)
	var score =   _manager.current_energy_array[_i] / _DNA.Max_energy[t] * count

	#score = 2.0
	return score

func enter(_manager,_i, _DNA):
	_manager.current_velocity_array[_i] = Vector3.ZERO


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	#var velocity: Vector3 = Vector3.ZERO
	var bin = _manager.binID_array[_i]
	var count = _manager.sum_species_world_array[target_species][bin]
	var bin_flow = _manager.calculate_flow_at_bin(target_species,bin)
	var acceleration = Vector3.ZERO #bin_flow.normalized() *max_speed 
	if count > 1 :
		var boids = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,1)
		var sep = separation(_manager,_i,boids) * weight_separation
		var ali = alignment(_manager,_i,boids) * weight_alignment
		var coh = cohesion(_manager,_i,boids) * weight_cohesion
		acceleration = sep + ali + coh
		
		if acceleration ==  Vector3(0,0,0):
			_manager.current_velocity_array[_i] = acceleration
	'elif _manager.current_velocity_array[_i]  ==  Vector3(0,0,0):
		_manager.current_velocity_array[_i] = Vector3(randf_range(-1,1),0,randf_range(-1,1))'
		
	#var step = acceleration * _delta
	_manager.current_velocity_array[_i] += acceleration * _delta * GlobalSimulationParameter.simulation_speed
	_manager.current_velocity_array[_i] = _manager.current_velocity_array[_i].limit_length(max_speed* GlobalSimulationParameter.simulation_speed)
	_manager.position_array[_i] += _manager.current_velocity_array[_i]	* _delta * GlobalSimulationParameter.simulation_speed#SIMULATION SPEED?
	#rotation = velocity.angle()
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -_manager.World.World_Size.x/2, _manager.World.World_Size.x/2)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -_manager.World.World_Size.z/2 , _manager.World.World_Size.z/2)
	_manager._pending_update.append(_i)
	change_bin(_manager,_i)
	'var bin = _manager.binID_array[_i]
	var bin_flow = _manager.calculate_flow_at_bin(target_species,bin)
	var dir := Vector3(0,0,0)
	var field = _manager.field_world_array[target_species][bin]
	var step =  bin_flow.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
	var count = _manager.sum_species_world_array[target_species][bin]
	#print(field)
	if count > 0 :
		var targets = _manager.get_index_in_bin_around(_manager.World.bin_array,_i,1)
		var close_target_id = find_closest(_manager, _manager.position_array[_i], targets,target_species)
		if close_target_id:
			dir = (_manager.position_array[close_target_id] - _manager.position_array[_i])
			step =  dir.normalized()  * speed * _delta #* log(GlobalSimulationParameter.simulation_speed)
			if step.length() > dir.length():
				_manager.position_array[_i] = _manager.position_array[close_target_id]
			else:
				_manager.position_array[_i] += step	'


func separation(_manager,i, boids):	
	var steer = Vector3.ZERO
	var count = 0
	for bi in boids:
		if bi == i:
			continue
		if _manager.Species_array[bi] != target_species:
			continue
		
		var d = _manager.position_array[i].distance_to(_manager.position_array[bi])
		if d < separation_radius and d >0:
			var diff  = (_manager.position_array[i]- _manager.position_array[bi]).normalized()
			diff /= d
			steer += diff
			count += 1
	if count > 0:
		steer /= count
	
	return steer.limit_length(max_force)
		
	
func alignment(_manager,i, boids):
	var avg_velocity = Vector3.ZERO
	var count = 0
	for bi in boids:
		if bi == i:
			continue
		if _manager.Species_array[bi] != target_species:
			continue
		var d = _manager.position_array[i].distance_to(_manager.position_array[bi])
		if d < neighbor_radius:
			avg_velocity += _manager.current_velocity_array[bi] 
			count +=1 
	if count > 0:
		avg_velocity /= count	
		avg_velocity = avg_velocity.normalized() * max_speed
		var steer = avg_velocity -  _manager.current_velocity_array[i]
		return steer.limit_length(max_force)
	return Vector3.ZERO

func cohesion(_manager,i, boids):
	var center = Vector3.ZERO
	var count = 0
	
	for bi in boids:
		if bi == i:
			continue
		if _manager.Species_array[bi] != target_species:
			continue
		var d = _manager.position_array[i].distance_to(_manager.position_array[bi])
		if d < neighbor_radius:
			center +=  _manager.position_array[bi] 
			count += 1
	if count > 0:
		center /= count
		return seek(_manager,i,center)	
	return Vector3.ZERO
	
func seek(_manager,i,target):
	var desired = (target - _manager.position_array[i]).normalized() * max_speed *GlobalSimulationParameter.simulation_speed
	var steer = desired -  _manager.current_velocity_array[i]
	return steer.limit_length(max_force)
	
'func get_highest_flow(_manager, bin: Vector2i, target_species):
	var best_flow := Vector3.ZERO
	var best_strength := -INF
	
	for dx in range(-1,1):
		for dz in range(-1,1):
			var neighbor = Vector2i(bin.x + dx, bin.y + dz)
			
			# --- border check ---
			if not is_in_bounds(neighbor):
				continue
			
			var flow = _manager.calculate_flow_at_bin(target_species, neighbor)
			var strength = flow.length()
			
			if strength > best_strength:
				best_strength = strength
				best_flow = flow
	
	return best_flow'
	

'func is_in_bounds(_manager,bin: Vector2i) -> bool:
	return bin.x >= 0 \
		and bin.y >= 0 \
		and bin.x < _manager.World.bin_count.x \
		and bin.y < _manager.World.bin_count.y'
