extends STATE
class_name GOTO_STATE


func evaluate(_manager,_i, _DNA):
	var t = _manager.current_life_state_array[_i] 
	var score = 1 -  _manager.current_energy_array[_i] / _DNA.Max_energy[t]
	print( "GoTo score is " + str(score))
	return score

func enter(_manager,_i, _DNA):
	pass


func exit(_manager,_i, _DNA):
	pass

func update(_manager,_i, _DNA, _delta):
	print("here")
	var bin = _manager.binID_array[_i]
	_manager.position_array[_i] += _manager.calculate_flow_at_bin(0,bin).normalized()  * 0.2
	#_manager.calculate_flow_at_bin(0,bin)
	_manager.put_in_world_bin(_i)
	
	#print(_manager.calculate_flow_at_bin(0,bin))
	#print(_manager.position_array[_i])
