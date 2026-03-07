extends DNA
class_name TREE


func Init():
		
	species_id = 1
	display_name = "TREE"

	# --- Core metabolism ---
	Max_energy =[2200]
	Max_health  =[4]
	Max_age  = [100]
	Homeostasis_cost  =[0.3]
	Decomposition_speed =[1.]

	# --- Plant Related ----
	Photosynthesis_absorption =[1.]
	Photosynthesis_range =[0,1.,2.,3.]


	# --- Life Cycle ---
	Reproduction_cost  =[500]
	Reproduction_spread  =[10]
	Reproduction_number =[1]
	Biomass =[10] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????


#INVENTORY

	Sprite_path ="res://Alife/Plant/tree/tree.png"  #TO DEFINE HERE BEST WAY
	Stack_amount = 10




func Growth(manager, i, delta):
	if manager.current_life_state_array[i] < 6:
		if manager.current_energy_array[i] > 500:
			manager.current_life_state_array[i] += 1
			manager.current_energy_array[i] -=  500
			manager.current_biomass_array[i] += 5
			return true
			
			
					
	'# Simple linear growth
	var s = manager.Species_array[i]
	var t = manager.current_life_state_array[i]

	manager.current_biomass_array[i] += 0.5 * delta'
