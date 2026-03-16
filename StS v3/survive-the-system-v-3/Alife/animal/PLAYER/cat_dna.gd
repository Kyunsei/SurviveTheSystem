extends DNA
class_name CAT



@export var state_array : Array[STATE]
var current_state : STATE

func Init():
		
	species_id = 5 #NEED TO FIX THIS
	display_name = "CAT"

	# --- Core metabolism ---
	Max_energy =[1000,1000]
	Max_health  =[4,4]
	Max_age  = [100,100]
	Homeostasis_cost  =[0.10]
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
	Biomass =[5000,5000] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????


#INVENTORY

	Sprite_path = "res://Alife/animal/PLAYER/player_cat.png"
	Stack_amount = 100
	
	
func Update(_manager, _i, _delta):
	if _manager.Alive_array[_i] == 1:
		change_bin(_manager,_i)
		print("hello")

	
func change_bin(_manager,_i):
	var old_bin = _manager.binID_array[_i]
	var current_bin = _manager.get_real_current_bin(_i)


	if old_bin == current_bin:
		return
	else:		
		_manager.remove_from_world_bin(_i)
		_manager.put_in_world_bin(_i)			
