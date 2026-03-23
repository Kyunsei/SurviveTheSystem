extends STATE
class_name REPRODUCE_STATE

@export var child_number : int = 3
@export var max = 100
var c = 0

func evaluate(_manager,_i, _DNA):
	var score = 0.0
	#ENERGy
	#print(_manager.current_energy_array[_i])
	if _manager.current_energy_array[_i] >= _DNA.Reproduction_cost[0]*1.5:
		score = 1.5
	'if c > max:
		score = 0'
	return score

func enter(_manager,_i, _DNA):
	'if c > max:
		return'
	if _manager.current_energy_array[_i] >=  _DNA.Reproduction_cost[0]*1.5:
		
		var newpos_ori = _manager.position_array[_i]
		for i in range(child_number):
			var newpos = newpos_ori + Vector3(randf_range(-15,15),0,randf_range(-15, 15)) 
			newpos.x = clamp(newpos.x, -_manager.World.World_Size.x / 2 + 1, _manager.World.World_Size.x / 2 - 1)
			newpos.z = clamp(newpos.z, -_manager.World.World_Size.z / 2 + 1, _manager.World.World_Size.z / 2 - 1)
			
			_manager._pending_spawns_positions.append(newpos)
			_manager._pending_spawns_species.append(_DNA.species_id)
		_manager.current_energy_array[_i] =-  _DNA.Reproduction_cost[0]
		c+= 1
		

func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA,_delta):
	pass
