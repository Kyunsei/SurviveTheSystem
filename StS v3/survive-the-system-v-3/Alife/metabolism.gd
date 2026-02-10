extends Node

var World : Node3D #maybe load from save ?

func Update():
	if multiplayer.is_server():
		Photosynthesis()


func Photosynthesis():
	'var array_current_energy_plant = [0,0,0]
	for life in array_current_energy_plant:'
		
	pass



'func plant_process():
	for p in plant_array.size():
		plant_energy[p] += 1 * simualtion_speed
		plant_age[p] += 1 * simualtion_speed
		if plant_energy[p] == 10 and index_plant < max_plant:
			plant_energy[p] = 0
			duplicate_life(plant_array[p])'
			
