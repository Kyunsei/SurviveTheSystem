extends DNA
class_name SHEEP



@export var state_array : Array[STATE]
var current_state : STATE

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

func Update(_manager, _i, _delta):
	choose_action(_manager, _i)	
	update_action(_manager, _i, _delta)
			
func choose_action(manager, i):
	if state_array.size() <= 0:
		
		return
	var best_score : float = 0
	var score : float
	var best_action : int
	for si in range(state_array.size()):
		score = state_array[si].evaluate(manager, i,self)		
		if score > best_score:
			best_score = score
			best_action = si
		
		elif score == best_score:
			if randi() == 1:
				best_action = si
	if best_action != null:
		if best_action == manager.current_finite_state_array[i]:
			#if current_state.isFinish == false:
				return
		#get_parent().get_node("debugLabel").text =best_action.name

		if state_array[manager.current_finite_state_array[i]]:
			state_array[manager.current_finite_state_array[i]].exit(manager, i,self)
			
		state_array[best_action].enter(manager, i,self)
		manager.current_finite_state_array[i] = best_action


func update_action(_manager, _i, _delta):
	state_array[_manager.current_finite_state_array[_i]].update(_manager, _i,self, _delta)
