extends Node
class_name SPECIES_TEST_A

func update(manager,self_index,delta, sim_speed):
	metabolism(manager,self_index,delta, sim_speed)
	homeostasis(manager,self_index,delta,sim_speed)
	#growth(manager,self_index,delta, sim_speed)
	#reproduce(manager,self_index,delta, sim_speed)
	#die(manager,self_index,delta, sim_speed)


func metabolism(manager,self_index,delta, sim_speed):
	manager.current_energy_array[self_index] += 1 * delta * sim_speed * manager.active_alife_array[self_index]
	

var position_array : PackedVector3Array
var current_energy_array : PackedFloat64Array
var active_alife_array
	
func homeostasis(manager,self_index,delta, sim_speed):
	manager.current_energy_array[self_index] -= .5 * delta * sim_speed * manager.active_alife_array[self_index]

	
func growth(manager,self_index,delta, sim_speed):
	if manager.current_energy_array[self_index] > 5:
		pass
	
func reproduce(manager,self_index,delta, sim_speed):
	if manager.current_energy_array[self_index] > 5:
		manager.Build_New_Life(manager.pick_random_position(Vector3(5,0,5) + manager.position_array[self_index]))
		manager.current_energy_array[self_index] -= 5
	
func die(manager,self_index,delta, sim_speed):
	if manager.current_energy_array[self_index] <= 0:
		manager.Remove_Life(self_index)
