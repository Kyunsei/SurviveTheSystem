extends STATE
class_name WANDER_STATE

@export var speed = 10
@export var threshold_detection =  0.000000000001
@export var isFlower = false


func evaluate(_manager,_i, _DNA):
	#ENERGY PART
	var bin = _manager.binID_array[_i]
	var t = _manager.current_life_state_array[_i] 
	var score = 0

	for p in _DNA.food_species_id :
		var bin_flow = _manager.field_world_array[p][bin]
		if isFlower:
			bin_flow = float(_manager.flower_field[bin])####(p,bin)
		#print(bin_flow)
		if bin_flow < threshold_detection:
			score = 1.
					
			
	return score

func enter(_manager,_i, _DNA):
	var dir = Vector3(randf_range(-1,1),0,randf_range(-1,1))
	_manager.current_velocity_array[_i] = speed * dir
	_manager.timer_array[_i] = randf_range(0.5,1)
	#print(dir)
	pass


func exit(_manager,_i, _DNA):
	_manager.current_finite_state_array[_i] = 0 #DEFAULT?
	_manager.timer_array[_i] = 0

func update(_manager,_i, _DNA, _delta):
	_manager.timer_array[_i] -= _delta
	_manager.position_array[_i] += _manager.current_velocity_array[_i] * _delta
		
	_manager.position_array[_i].x = clamp(_manager.position_array[_i].x , -(_manager.World.World_Size.x/2-1), _manager.World.World_Size.x/2-1)
	_manager.position_array[_i].z = clamp(_manager.position_array[_i].z , -(_manager.World.World_Size.z/2-1) , _manager.World.World_Size.z/2-1)

	_manager._pending_update.append(_i)

	change_bin(_manager,_i)
	if _manager.timer_array[_i] <= 0:
		exit(_manager,_i,_DNA)
	

	
