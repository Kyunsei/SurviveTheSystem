extends STATE
class_name REPRODUCE_STATE

func evaluate(_manager,_i, _DNA):
	var score = 0.0
	#ENERGy
	#print(_manager.current_energy_array[_i])
	if _manager.current_energy_array[_i] >= 1000:
		score = 1.5
	
	return score

func enter(_manager,_i, _DNA):
	if _manager.current_energy_array[_i] >= 1000:
		
		var newpos_ori = _manager.position_array[_i]
		for i in range(3):
			var newpos = newpos_ori + Vector3(randf_range(-15,15),0,randf_range(-15, 15)) 
			newpos.x = clamp(newpos.x, -_manager.World.World_Size.x / 2 + 1, _manager.World.World_Size.x / 2 - 1)
			newpos.z = clamp(newpos.z, -_manager.World.World_Size.z / 2 + 1, _manager.World.World_Size.z / 2 - 1)
			
			_manager._pending_spawns_positions.append(newpos)
			_manager._pending_spawns_species.append(_DNA.species_id)
			
		_manager.current_energy_array[_i] =- 800

		

func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA,_delta):
	pass
