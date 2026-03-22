extends DNA
class_name SHEEP



@export var state_array : Array[STATE]
var current_state : STATE

func Init():
		
	species_id = AlifeRegistry.SPECIES_ID.SHEEP

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
	Biomass =[1000,1000] #MAYBE NO LONGER IN USE

#--- BEHAVIOUR ----
	food_species_id  = [AlifeRegistry.SPECIES_ID.GRASS]
	danger_species_id = [AlifeRegistry.SPECIES_ID.CAT]
	friend_species_id = [AlifeRegistry.SPECIES_ID.SHEEP]
#????
	for si in range(state_array.size()):
		state_array[si].state_internal_id = si

#INVENTORY

	Sprite_path = "res://Alife/animal/Herbivor/sheep2.png"
	Stack_amount = 100
	
	
func Update(_manager, _i, _delta):

	if _manager.Alive_array[_i] == 1:
		choose_action(_manager, _i)	
		update_action(_manager, _i, _delta)
		Homeostasis(_manager,_i,_delta)
			

func Growth(manager, i, _delta):
	if manager.current_life_state_array[i] < 6:
		if manager.current_energy_array[i] > 500:
			manager.current_life_state_array[i] += 1
			manager.current_energy_array[i] -=  500
			manager.current_biomass_array[i] += 5
			return true


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


func Homeostasis(manager,i,delta):
	var s = manager.Species_array[i]
	var t = 0 # min(t,manager.species_photosynthesis_range[s].size()-1)
	if manager.current_health_array[i] <= 0:
		manager.Death(i)
		manager._pending_update.append(i)
		return
		
	var area = max(1,(manager.species_photosynthesis_range[s][t] * 2) * (manager.species_photosynthesis_range[s][t] * 2 ))
	t = min(manager.current_life_state_array[i],manager.species_homeostasis_cost[s].size()-1)
	manager.current_energy_array[i] -= manager.species_homeostasis_cost[s][t] * area * GlobalSimulationParameter.simulation_speed * delta
	#Regenerate_Health(i,s,t,delta)
		
	if manager.current_energy_array[i] <= 0:
		manager.current_health_array[i] -= manager.species_homeostasis_cost[s][t]  * GlobalSimulationParameter.simulation_speed * delta


func update_action(_manager, _i, _delta):
	state_array[_manager.current_finite_state_array[_i]].update(_manager, _i,self, _delta)
