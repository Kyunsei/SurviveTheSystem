extends DNA
class_name MOSS


func Init():
		
	species_id = 2
	display_name = "MOSS"

	# --- Core metabolism ---
	Max_energy =[1100,1100]
	Max_health  =[4,4]
	Max_age  = [100,100]
	Homeostasis_cost  =[0.3,0.3]
	Decomposition_speed =[2.,2.]

	# --- Plant Related ----
	Photosynthesis_absorption =[0.,0.]
	Photosynthesis_range =[0,0]
	Shadow_tolerance = 1.0
	#Shadow_generation = 1.0

	# --- Life Cycle ---
	Reproduction_cost  =[400,400]
	Reproduction_spread  =[5,5]
	Reproduction_number =[1,1]
	Biomass =[5,10] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????


#INVENTORY

	Sprite_path = "res://Alife/Plant/Grass/grass.png"  #TO DEFINE HERE BEST WAY
	Stack_amount = 100

func Update(manager, i, delta):	
	var s = manager.Species_array[i]
	var t = manager.current_life_state_array[i]
	if manager.current_life_state_array[i] == 0:
			Germination(manager,i,s,t)
	if manager.Alive_array[i] == 1:			
			Homeostasis(manager,i,s,t,delta)
			Growth(manager,i,delta)
			Reproduction(manager,i,s,t,delta)
	else:
		Decompose(manager,i,s,t, delta)




func Growth(manager, i, _delta):
	if manager.current_life_state_array[i] < 6:
		if manager.current_energy_array[i] > 500:
			manager.current_life_state_array[i] += 1
			manager.current_energy_array[i] -=  500
			manager.current_biomass_array[i] += 5
			return true
			
			



func Homeostasis(manager,i,s,t,delta):
	t = min(t,manager.species_photosynthesis_range[s].size()-1)
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




	
func Reproduction(manager,i,s,t,_delta):	
		t = min(t,manager.species_reproduction_cost[s].size()-1)
		if manager.current_energy_array[i] >= manager.species_reproduction_cost[s][t]*2:
			var newpos = manager.position_array[i] + Vector3(
				randf_range(-manager.species_reproduction_spread[s][t], manager.species_reproduction_spread[s][t]),
				0,
				randf_range(-manager.species_reproduction_spread[s][t], manager.species_reproduction_spread[s][t])
			)
			newpos.x = clamp(newpos.x, -manager.World.World_Size.x / 2 + 1, manager.World.World_Size.x / 2 - 1)
			newpos.z = clamp(newpos.z, -manager.World.World_Size.z / 2 + 1, manager.World.World_Size.z / 2 - 1)
			manager.current_energy_array[i] -= manager.species_reproduction_cost[s][t]	

			if check_if_tile_free(manager,newpos):
				manager._pending_spawns_positions.append(newpos)
				manager._pending_spawns_species.append(s)


func check_if_tile_free(manager,pos):
	var result = true
	var light_index : int 
	var w_pos = manager.World.get_PositionInGrid(pos,manager.World.light_tile_size)
	if pos.x <= -manager.World.World_Size.x/2 or pos.x >= manager.World.World_Size.x/2:
			return false
	if pos.z <= -manager.World.World_Size.z/2 or pos.z >= manager.World.World_Size.z/2:
			return false
	light_index = manager.World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, manager.World.light_tile_size)
	if manager.World.light_bin[light_index]:
		for gi in manager.World.light_bin[light_index]:
			if manager.Species_array[gi] == AlifeRegistry.SPECIES_ID.MOSS:
				result = false
	
	
	return result
	

func Germination(manager,i,s,t):
	manager.current_life_state_array[i] = 1
	't = min(t,manager.species_photosynthesis_range[s].size()-1)
	var area = max(1,(manager.species_photosynthesis_range[s][t] * 2) * (manager.species_photosynthesis_range[s][t] * 2 ))
	var light_available = 0
	for l_i in manager.light_index_array[i]:	
		if l_i <  manager.World.light_array.size():
			if manager.World.light_array[l_i] > 0:
				light_available += 1
	if light_available == area:
		manager.current_life_state_array[i] = 1
		manager._pending_update.append(i)
		
	if manager.current_life_state_array[i] == 0:
			manager.Alive_array[i] = 0	'
			
func Decompose(manager,i,s,t,delta):
	t = min(t,manager.species_decomposition_speed[s].size()-1)
	manager.current_biomass_array[i] -= manager.species_decomposition_speed[s][t]  * GlobalSimulationParameter.simulation_speed   *delta
	'var current_step = int(Biomass_array[i] / 10)
	if  grass.has("last_step"):
		if current_step != grass["last_step"]:
			grass["last_step"] = current_step
			_pending_update.append(grass)
	else:
		grass["last_step"] = current_step'
	if manager.current_biomass_array[i] < 0:
		if manager._pending_kills.has(i):
			return
		manager._pending_kills.append(i)
