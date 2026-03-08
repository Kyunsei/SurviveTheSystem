extends DNA
class_name TREE


func Init():
		
	species_id = 1
	display_name = "TREE"

	# --- Core metabolism ---
	Max_energy =[220000]
	Max_health  =[5,10,20,30,40]
	Max_age  = [100]
	Homeostasis_cost  =[0.]
	Decomposition_speed =[1.]

	# --- Plant Related ----
	Photosynthesis_absorption =[1.]
	Photosynthesis_range =[4]


	# --- Life Cycle ---
	Reproduction_cost  =[50000]
	Reproduction_spread  =[15]
	Reproduction_number =[1]
	Biomass =[10,20,30,40,50,60] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????



#INVENTORY

	Sprite_path ="res://Alife/Plant/tree/tree.png"  #TO DEFINE HERE BEST WAY
	Stack_amount = 10




func Growth(manager, i, delta):
	if manager.current_life_state_array[i] < 6:
		if manager.current_energy_array[i] > 20000:
			manager.current_life_state_array[i] += 1
			manager.current_energy_array[i] -=  10000
			manager.current_biomass_array[i] += 100
			#manager.put_in_light_bin(i)
			return true
				
					
	'# Simple linear growth
	var s = manager.Species_array[i]
	var t = manager.current_life_state_array[i]

	manager.current_biomass_array[i] += 0.5 * delta'
