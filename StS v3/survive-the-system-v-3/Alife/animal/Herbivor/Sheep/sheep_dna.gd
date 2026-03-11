extends DNA
class_name SHEEP


func Init():
		
	species_id = 3
	display_name = "SHEEP"

	# --- Core metabolism ---
	Max_energy =[1100,1100]
	Max_health  =[4,4]
	Max_age  = [100,100]
	Homeostasis_cost  =[0.00]
	Decomposition_speed =[1]

	# --- Plant Related ----
	Photosynthesis_absorption =[0]
	Photosynthesis_range =[0]


	# --- Movement Related ----
	Max_speed =[5]


	# --- Life Cycle ---
	Reproduction_cost  =[500,500]
	Reproduction_spread  =[5,5]
	Reproduction_number =[1,1]
	Biomass =[5,10] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????


#INVENTORY

	Sprite_path = "res://Alife/animal/Herbivor/sheep2.png"
	Stack_amount = 100


func Growth(manager, i, _delta):
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
