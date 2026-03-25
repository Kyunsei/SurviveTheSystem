extends DNA
class_name BERRY


func Init():
		
	species_id = 4
	display_name = "BERRY"

	# --- Core metabolism ---
	Max_energy =[1100,1100]
	Max_health  =[15,15]
	Max_age  = [100,100]
	Homeostasis_cost  =[0.9,0.9]
	Decomposition_speed =[2.,2.]

	# --- Plant Related ----
	Photosynthesis_absorption =[1,1]
	Photosynthesis_range =[1,1]


	# --- Life Cycle ---
	Reproduction_cost  =[500,500]
	Reproduction_spread  =[15,15]
	Reproduction_number =[1,1]
	Biomass =[2000,15,25,35,45,55,65,75,85] #MAYBE NO LONGER IN USE

#--- RENDERING ----

#????

#INVENTORY
	Sprite_path ="res://assets/Art from STS2/berry_1.png"#"res://Alife/Plant/Bush/berry_5.png" 
	Stack_amount = 50




func isPickable(manager, i):
	if manager.current_life_state_array[i] == 4:
		manager.current_life_state_array[i] -= 1
		manager.current_energy_array[i] -=  1000
		manager._pending_update.append(i)
		var new_pos = manager.position_array[i] + Vector3(randf_range(-0.2,0.2),0,randf_range(-0.2,0.2))
		manager._pending_spawns_positions.append(new_pos)
		manager._pending_spawns_species.append(manager.Species_array[i])
		return false 
		
	elif manager.current_life_state_array[i] == 0:
		return true
	else:
		return 1-manager.Alive_array[i]

func isPickablebutstaying(_manager, _i): #WILL DISAPPEAR
	#TRUE MEAN NOT SATYING < CLASSIC WAY
	#_manager.Spawn_New_Grass(newpos:Vector3,s:int)
	return true

func Growth(manager, i, _delta):

	if manager.current_life_state_array[i] < 3:
		if manager.current_energy_array[i] > 1000:
			manager.current_life_state_array[i] += 1
			manager.current_energy_array[i] -=  1000
			manager.current_biomass_array[i] = Biomass[manager.current_life_state_array[i]]
			#return true
			manager._pending_update.append(i)
	if manager.current_life_state_array[i] == 3:
			if manager.current_energy_array[i] > 1000:
				manager.current_life_state_array[i] += 1
				manager.current_energy_array[i] -=1000
				manager.current_biomass_array[i] = Biomass[manager.current_life_state_array[i]]
				#return true
				manager._pending_update.append(i)		
func Update(manager, i, delta):
	
	var s = manager.Species_array[i]
	var t = manager.current_life_state_array[i]
	if manager.Alive_array[i] == 1:		
			Homeostasis(manager,i,s,t,delta)
			Growth(manager,i,delta)
			#Reproduction(manager,i,s,t,delta)
	else:
		Decompose(manager,i,s,t, delta)




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






func Take_fruit(manager,i,s,t,_delta):
	pass

	
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

			if manager.check_if_lighttile_free(newpos):
				manager._pending_spawns_positions.append(newpos)
				manager._pending_spawns_species.append(s)




		

			
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
