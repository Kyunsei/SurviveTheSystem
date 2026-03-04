extends Node3D

#################
#
# v2 of grass/plant manager  
# fully ECS here hopefully will help performance gain...
#
#######################

#NEED TO PUT IN WORLD BIN !!!!!!!!!!!!!

var FPS : float
#var id : PackedInt32Array

#WORLD
var position_array : PackedVector3Array
var size_array: PackedVector3Array  #NOT IN USE? 
var binID_array: PackedInt32Array

#STATS
var current_energy_array : PackedFloat32Array
var current_health_array : PackedFloat32Array
var current_life_state_array : PackedInt32Array
var current_age_array : PackedInt32Array
var Alive_array : PackedInt32Array
var current_biomass_array : PackedFloat32Array
var Species_array : PackedInt32Array

#SPECIES SPECIFICIC
@export var species_list : Array[DNA]
var species_id_array : Array =[]
var species_max_energy : Array = [] 
var species_max_health : Array = [] 
var species_max_age : Array = [] 
var species_homeostasis_cost : Array = [] 
var species_decomposition_speed : Array = [] 
var species_photosynthesis_absorption  : Array = []
var species_photosynthesis_range : Array = []
var species_reproduction_cost : Array = [] 
var species_reproduction_spread : Array = [] 
var species_reproduction_number : Array = [] 
var species_biomass : Array = [] 



#PLANT SPECIFIC 
var light_index_array : Array = []
#var Photosynthesis_absorbtion_array : PackedFloat32Array
#var Photosynthesis_range_array : PackedFloat32Array


#FOR MANAGER
var Active : PackedInt32Array
var _pending_spawns_species: PackedInt32Array
var _pending_spawns_positions: PackedVector3Array
var _pending_kills: PackedInt32Array
var _pending_update: PackedInt32Array


var World
var free_indices : Array =[]
var entity_count := 0 
var isInit = false

#THREAD
var simulation_thread : Thread
var thread_running := false
var thread_should_stop := false
var thread_delta : float = 0.0
var mutex := Mutex.new()
var thread_result_ready = false


func start_simulation_thread():
	if thread_running:
		return

	thread_should_stop = false
	simulation_thread = Thread.new()
	simulation_thread.start(_thread_loop)
	thread_running = true	

func stop_simulation_thread():
	if not thread_running:
		return

	thread_should_stop = true
	simulation_thread.wait_to_finish()
	thread_running = false

func _exit_tree():
	stop_simulation_thread()

func _thread_loop():
	while not thread_should_stop:

		var delta := 0.016  # fixed timestep (important!)

		mutex.lock()
		update(delta)
		thread_result_ready = true
		mutex.unlock()

		OS.delay_msec(1)  # prevent CPU burning

func _process(delta):
	if GlobalSimulationParameter.DEBUG_grass_sim == 0:
		return
	if !multiplayer.is_server():
		return
	
	if _pending_spawns_species.size() == 0 \
	and _pending_kills.size() == 0 \
	and _pending_update.size() == 0:
		return

	mutex.lock()
	Spawn_and_Kill()
	mutex.unlock()	



func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func Init():
	if GlobalSimulationParameter.DEBUG_grass_sim == 0:
		return
	if multiplayer.is_server():
		if !World:
			print("please set the world")
		build_species_tables()
		for i in range(1):
			Spawn_New_Grass(Vector3(0+0*i,0,0),0)
		isInit = true
		start_simulation_thread()



func update(delta):
	if !isInit:
		print("grass manger not initialised")
		return
	if GlobalSimulationParameter.SimulationStarted  == true: # and isInit == false:

		var ss = Time.get_ticks_msec() 
		if GlobalSimulationParameter.simulation_speed > 0:
			if World:
				World.add_value_in_each_tile(World.light_array,World.light_flux_in,0,World.light_max_value) #should be moved sommewhere else?

			PhotosynthesisSystem(delta)
			#LightSystem_to_plant(delta)

			HomeostasisSystem(delta)
			GrowthSystem(delta)
			ReproductionSystem(delta)
			GerminationSystem(delta)
			DecomposeSystem(delta)

			

		#call_deferred("Spawn_and_Kill")
		#Spawn_and_Kill()
		FPS = Time.get_ticks_msec() - ss
	

	
		
func PhotosynthesisSystem(delta):


	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 0:
			continue
		if current_life_state_array[i] == 0:
			continue
		Photosynthesis(i, delta)
		
		
func HomeostasisSystem(delta):

	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 0:
			continue
		if current_life_state_array[i] == 0:
			continue
		Homeostasis(i, delta)
func GrowthSystem(delta):
	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 0:
			continue
		if current_life_state_array[i] == 0:
			continue
		Growth(i, delta)
func ReproductionSystem(delta):	
	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 0:
			continue
		if current_life_state_array[i] == 0:
			continue
		Reproduction(i, delta)	
func DecomposeSystem(delta):	
	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 1:
			continue
		Decompose(i, delta)	
		
func GerminationSystem(delta):
	for i in range(entity_count):
		if Active[i] == 0:
			continue
		if Alive_array[i] == 0:
			continue
		if current_life_state_array[i] > 0:
			continue
		Germination(i)	


func LightSystem_to_plant(delta): #THIS SCRIPT IS NOT USED

	for bi in range(World.light_bin.size()):
		var light_value = World.light_array[bi]
		if light_value <= 0:
			continue
		
		var grass = World.light_bin[bi]
		if !grass:
			continue

		var share = light_value/World.light_bin[bi].size()
		for gi in grass:
			if Active[gi]==0:
				continue
			if Alive_array[gi]==0:
				continue
			if current_life_state_array[gi]==0:
				continue
			var s = Species_array[gi]
			var t = min(current_life_state_array[gi],species_photosynthesis_absorption[s].size()-1)		
			var photo_factor = species_photosynthesis_absorption[s][t] * GlobalSimulationParameter.simulation_speed * delta
			current_energy_array[gi] +=  light_value * photo_factor
			current_energy_array[gi] = clamp(current_energy_array[gi],0 ,species_max_energy[s][t])
			World.light_array[bi] = 0
			break


		'for gi in grass:

			var s = Species_array[gi]
			var t = current_life_state_array[gi]		
			var photo_factor = species_photosynthesis_absorption[s][t] * GlobalSimulationParameter.simulation_speed * delta
			current_energy_array[gi] += share * photo_factor

			current_energy_array[gi] = clamp(current_energy_array[gi],0 ,species_max_energy[s][t])'	
		'var gi = grass[0]
		var s = Species_array[gi]
		var t = current_life_state_array[gi]		
		var photo_factor = species_photosynthesis_absorption[s][t] * GlobalSimulationParameter.simulation_speed * delta
		current_energy_array[gi] +=  light_value * photo_factor
		current_energy_array[gi] = clamp(current_energy_array[gi],0 ,species_max_energy[s][t])'
		
		
		
			
func Photosynthesis(i,delta):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_photosynthesis_absorption[s].size()-1)
	var time_value = species_photosynthesis_absorption[s][t] * GlobalSimulationParameter.simulation_speed * delta
	for l_i in light_index_array[i]:		
		if l_i <  World.light_array.size():
			var energy_absorbed = World.light_array[l_i] * time_value
			if energy_absorbed <= 0:
				return
			current_energy_array[i] = clamp(current_energy_array[i] + energy_absorbed,0 ,species_max_energy[s][t])
			var shadow_effect = 1.0
			World.light_array[l_i] = max(World.light_array[l_i]-shadow_effect,0)

func Homeostasis(i,delta):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_photosynthesis_range[s].size()-1)
	if current_health_array[i] <= 0:
		Death(i)
		#grass["last_step"] = int(grass["Biomass"] / 10)
		_pending_update.append(i)
		return
	var area = max(1,(species_photosynthesis_range[s][t] * 2) * (species_photosynthesis_range[s][t] * 2 ))
	current_energy_array[i] -= species_homeostasis_cost[s][t] * area * GlobalSimulationParameter.simulation_speed * delta
	Regenerate_Health(i,delta)

	if current_energy_array[i] <= 0:
		current_health_array[i] -= species_homeostasis_cost[s][t]  * GlobalSimulationParameter.simulation_speed * delta


	

func Regenerate_Health(i,delta):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_max_health[s].size()-1)
	if current_health_array[i] != species_max_health[s][t]:
		var value_regen = min(current_energy_array[i]/2, species_max_health[s][t] - current_health_array[i]) * GlobalSimulationParameter.simulation_speed * delta
		current_health_array[i] += value_regen
		current_energy_array[i] -= value_regen	
	
func Growth(i,delta):
	var s = Species_array[i]
	if species_list[s].Growth(self,i,delta):
		_pending_update.append(i)

func Death(i):
	Alive_array[i] = 0
	remove_from_light_bin(i)

	
func Reproduction(i,delta):
		var s = Species_array[i]
		var t = min(current_life_state_array[i],species_reproduction_cost[s].size()-1)
		if current_energy_array[i] > species_reproduction_cost[s][t]*2:
			var newpos = position_array[i] + Vector3(
				randf_range(-species_reproduction_spread[s][t], species_reproduction_spread[s][t]),
				0,
				randf_range(-species_reproduction_spread[s][t], species_reproduction_spread[s][t])
			)
			newpos.x = clamp(newpos.x, -World.World_Size.x / 2 + 1, World.World_Size.x / 2 - 1)
			newpos.z = clamp(newpos.z, -World.World_Size.z / 2 + 1, World.World_Size.z / 2 - 1)
			current_energy_array[i] -= species_reproduction_cost[s][t]	

			if check_if_lighttile_free(newpos):
				_pending_spawns_positions.append(newpos)
				_pending_spawns_species.append(s)


func check_if_lighttile_free(pos):

	var light_index : int 
	var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
	if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
			return false
	if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
			return false
	light_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
	if !World.light_bin[light_index]:
		return true
	if World.light_bin[light_index].size()> 0:
		return false
	return true
	


func Germination(i):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_photosynthesis_range[s].size()-1)
	var area = max(1,(species_photosynthesis_range[s][t] * 2) * (species_photosynthesis_range[s][t] * 2 ))
	var light_available = 0
	for l_i in light_index_array[i]:	
		if l_i <  World.light_array.size():
			if World.light_array[l_i] > 0:
				light_available += 1
	if light_available == area:
		current_life_state_array[i] = 1
		_pending_update.append(i)
		
	if current_life_state_array[i] == 0:
			Alive_array[i] = 0	
func Decompose(i,delta):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_decomposition_speed[s].size()-1)
	current_biomass_array[i] -= species_decomposition_speed[s][t]  * GlobalSimulationParameter.simulation_speed   *delta
	'var current_step = int(Biomass_array[i] / 10)
	if  grass.has("last_step"):
		if current_step != grass["last_step"]:
			grass["last_step"] = current_step
			_pending_update.append(grass)
	else:
		grass["last_step"] = current_step'
	if current_biomass_array[i] < 0:
		if _pending_kills.has(i):
			return
		_pending_kills.append(i)


		
func Spawn_and_Kill():
	if !multiplayer.is_server():
		return
		
	var spawned_ids := PackedInt32Array()
	var spawned_positions := PackedVector3Array()
	var killed_ids := PackedInt32Array()
	var updated_ids := PackedInt32Array()	


	#var unique_kills :PackedInt32Array = remove_duplicate_in_index_array(_pending_external_kills,_pending_kills)
	#var unique_updates :PackedInt32Array = remove_duplicate_in_index_array(_pending_external_update,_pending_update)

	for i in _pending_kills:
		Kill_Grass(i)
		killed_ids.append(i)
		
	for i in range(_pending_spawns_species.size()):
		var new_id = Spawn_New_Grass(_pending_spawns_positions[i], _pending_spawns_species[i])
		spawned_ids.append(new_id)
		spawned_positions.append(_pending_spawns_positions[i])
				
	'for i in range(_pending_external_spawns_id.size()):
		Spawn_Grass(_pending_external_spawns_id[i],_pending_external_spawns_positions[i])
		#Spawn_Grass(i)
		#Build_New_Grass(i, pos, sp)'


	for i in _pending_update:
		updated_ids.append(i)
	
# ---- SEND TO CLIENTS ----
	if spawned_ids.size() > 0:
		draw_new_grass.rpc(spawned_ids,spawned_positions)#, state_array, alive_array)
		
	if killed_ids.size() > 0:
		erase_grass.rpc(killed_ids)

	if updated_ids.size() > 0:
		var pos_array := PackedVector3Array()
		var state_array := PackedInt32Array()
		var alive_array := PackedInt32Array()
		var actives := PackedInt32Array()

		for id in updated_ids:
			pos_array.append(position_array[id])
			state_array.append(current_life_state_array[id])
			alive_array.append(Alive_array[id])
			actives.append(Active[id])

		update_drawn_grass.rpc(updated_ids, pos_array, state_array, alive_array,actives)

	
	
	_pending_spawns_positions.clear()
	_pending_spawns_species.clear()
	_pending_kills.clear()
	_pending_update.clear()


	


func Build_New_Grass(i:int,pos: Vector3, sp:int):
	if i >= Species_array.size():
		Species_array.append(sp)
		current_energy_array.append(0) #HERE MAYBE
		current_health_array.append(species_max_health[sp][0])
		current_life_state_array.append(0)
		current_age_array.append(0)
		Alive_array.append(1)
		Active.append(1)
		current_biomass_array.append(species_biomass[sp][0])
		position_array.append(pos)
		#size_array[i]  = Vector3(1,1,1)  #HERE NOT IN USE? 
		binID_array.append(get_worldbin_index(pos))	
		light_index_array.append(get_lightIndex(i))
		put_in_light_bin(i)
		put_in_world_bin(i)


	else:
		Species_array[i] = sp
		current_energy_array[i] = 0 #HERE MAYBE
		current_health_array[i] = species_max_health[sp][0]
		current_life_state_array[i] = 0
		current_age_array[i] = 0
		Alive_array[i] = 1
		Active[i] = 1
		current_biomass_array[i] = species_biomass[sp][0]
		position_array[i] = pos
		#size_array[i]  = Vector3(1,1,1)  #HERE NOT IN USE? 
		binID_array[i] =  get_worldbin_index(pos)
		light_index_array[i] = get_lightIndex(i)
		put_in_light_bin(i)
		put_in_world_bin(i)


func Spawn_Grass(i,pos):
	Active[i] = 1
	position_array[i] = pos
	binID_array[i] =  get_worldbin_index(pos)
	light_index_array[i] = get_lightIndex(i)
	put_in_light_bin(i)
	put_in_world_bin(i)

func Spawn_New_Grass(newpos:Vector3,s:int):
	#print("new")
	var i : int
	if free_indices.size()> 0:
		i = free_indices.pop_back()
	else:
		i = entity_count
		entity_count += 1
		
	Build_New_Grass(i, newpos, s)
	species_id_array[s].append(i)
	if 	get_parent().current_life_count_by_species.has(Species_array[i]):
		get_parent().current_life_count_by_species[Species_array[i]] += 1
	else:
		get_parent().current_life_count_by_species[Species_array[i]] = 1
	return i 
	
func Kill_Grass(i):
	var s = Species_array[i]

	if species_id_array[s].has(i):
		species_id_array[s].erase(i)
		
	free_indices.append(i)
	Active[i] = 0
	remove_from_light_bin(i)
	remove_from_world_bin(i)

	if 	get_parent().current_life_count_by_species.has(Species_array[i]):
		get_parent().current_life_count_by_species[Species_array[i]] -= 1
####HELPER FUNCTION

func remove_duplicate_in_index_array(A,B):
	var unique := {}
	var unique_array := PackedInt32Array()
	for id in A:
		unique[id] = true
	for id in B:
		unique[id] = true
	unique_array = PackedInt32Array(unique.keys())
	for k in unique.keys():
		unique_array.append(k)
	return unique_array


func build_species_tables():
	var count = species_list.size()

	species_max_energy.resize(count)
	species_max_health.resize(count)
	species_max_age.resize(count)
	species_homeostasis_cost.resize(count)
	species_decomposition_speed.resize(count)
	species_photosynthesis_absorption.resize(count)
	species_photosynthesis_range.resize(count)
	species_reproduction_cost.resize(count)
	species_reproduction_spread.resize(count)
	species_reproduction_number.resize(count)
	species_biomass.resize(count)


	for s in species_list:
		s.Init()
		var id = s.species_id	
		species_max_energy[id] = s.Max_energy
		species_max_health[id] = s.Max_health
		species_max_age[id] = s.Max_age
		species_homeostasis_cost[id] = s.Homeostasis_cost
		species_decomposition_speed[id] = s.Decomposition_speed
		species_photosynthesis_absorption[id] = s.Photosynthesis_absorption
		species_photosynthesis_range[id] = s.Photosynthesis_range
		species_reproduction_cost[id] = s.Reproduction_cost
		species_reproduction_spread[id] = s.Reproduction_spread
		species_reproduction_number[id] = s.Reproduction_number
		species_biomass[id] = s.Biomass
		species_id_array.append([])

###CONECT TO WORLD

func get_worldbin_index(current_pos):
	var bin_index
	if World:
		if current_pos.x > -World.World_Size.x/2  and current_pos.x < World.World_Size.x/2 :
			if current_pos.z > -World.World_Size.z/2  and current_pos.z < World.World_Size.z/2 :			
				var w_pos = World.get_PositionInGrid(current_pos,World.bin_size)
				bin_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
				if bin_index < World.bin_array.size() and bin_index >= 0 :
					return bin_index
		return null
		

func get_lightIndex(idx):
	var s = Species_array[idx]
	var t = min(current_life_state_array[idx],species_photosynthesis_range[s].size()-1)
	var pos = position_array[idx]
	var light_index = []
	if species_photosynthesis_range[s][t] == 0:
		var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
		if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
				return
		if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
				return
		light_index.append(World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size))
	else:
		for i in range(-species_photosynthesis_range[s][t],species_photosynthesis_range[s][t]):
			for j in range(-species_photosynthesis_range[s][t],species_photosynthesis_range[s][t]):
				pos.x = position_array[idx].x + i * World.light_tile_size.x
				pos.z = position_array[idx].z + j * World.light_tile_size.z
				if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
					continue
				if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
					continue
					
				var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
				var idx_bin =  World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
				light_index.append(idx_bin)
	return light_index


func put_in_light_bin(idx):

	var s = Species_array[idx]
	var t = min(current_life_state_array[idx], species_photosynthesis_range[s].size()-1)
	var pos = position_array[idx]
	if species_photosynthesis_range[s][t] == 0:
		var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
		if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
				return
		if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
				return
		var bi = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
		if World.light_bin[bi]:
			World.light_bin[bi].append(idx)
		else:
			World.light_bin[bi]= [idx]
		#light_index.append(World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size))

	else:
		for i in range(-species_photosynthesis_range[s][t],species_photosynthesis_range[s][t]):
			for j in range(-species_photosynthesis_range[s][t],species_photosynthesis_range[s][t]):
				pos.x = position_array[idx].x + i * World.light_tile_size.x
				pos.z = position_array[idx].z + j * World.light_tile_size.z
				if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
					continue
				if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
					continue				
				var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
				var idx_bin =  World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
				if World.light_bin[idx_bin]:
					World.light_bin[idx_bin].append(idx)
				else:
					World.light_bin[idx_bin]= [idx]


func remove_from_world(i):
	remove_from_light_bin(i)
	remove_from_world_bin(i)
	light_index_array[i] = []
	Active[i] = 0
	_pending_update.append(i)
	
func add_to_world(i):
	put_in_world_bin(i)
	put_in_light_bin(i)
	light_index_array[i] = get_lightIndex(i)
	Active[i] = 1
	_pending_update.append(i)


func remove_from_light_bin(idx):	
	for li in light_index_array[idx]:
		if World.light_bin[li].has(idx):
			World.light_bin[li].erase(idx)
	light_index_array[idx].clear()


func put_in_world_bin(i):
	var bin_ID = binID_array[i]
	var w_pos = World.get_PositionInGrid(position_array[i],World.bin_size)
	#var w_pos = World.get_PositionInGrid(g.position,World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	if new_bin_ID < 0 or new_bin_ID >= World.bin_array.size():
		print("life out of world")
		#remove_from_world_bin(i)
		return
	if bin_ID != new_bin_ID:
		remove_from_world_bin(i)
		binID_array[i] = new_bin_ID
		#g["bin_ID"] = new_bin_ID
	if World.bin_array[new_bin_ID] == null:
		World.bin_array[new_bin_ID] = [i]
		World.bin_sum_array[Species_array[i]][new_bin_ID] += 1
	else:	
		World.bin_array[new_bin_ID].append(i) 
		World.bin_sum_array[Species_array[i]][new_bin_ID] += 1

	#binID_array[i] = new_bin_ID
	
	
func remove_from_world_bin(i):
	if binID_array[i] >= 0:
		if World.bin_array[binID_array[i]].has(i):
			World.bin_array[binID_array[i]].erase(i)
			World.bin_sum_array[Species_array[i]][binID_array[i]] -= 1
			binID_array[i] = -1
			
			
############################### RPC
##########################MULTIMESH GESTION

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(id_array, pos_array):#, state_array, alive_array):	
		$grass.draw_new_grass(id_array, pos_array)#, state_array, alive_array)
		
			
@rpc("authority", "call_remote", "reliable") 			
func update_drawn_grass(id_array, pos_array, state_array, alive_array,active):
		$grass.update_drawn_grass(id_array, pos_array, state_array, alive_array,active)
				
@rpc("authority", "call_remote", "reliable") 
func erase_grass(id_array):
	$grass.remove_grass(id_array)
			

@rpc("any_peer","call_remote")
func send_and_draw_array(id_array, pos_array, state_array, alive_array, Active_array):
	#$grass.init()
	$grass.draw_all_grass(id_array, pos_array, state_array, alive_array, Active_array)



func _on_peer_connected(id):
	if multiplayer.is_server():
		send_full_state_to_peer(id)

func send_full_state_to_peer(peer_id):

	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var states := PackedInt32Array()
	var alive := PackedInt32Array()
	var active := PackedInt32Array()

	for i in range(entity_count):
		#if Active[i] == 1:
			ids.append(i)
			positions.append(position_array[i])
			states.append(current_life_state_array[i])
			alive.append(Alive_array[i])
			active.append(Active[i])

	send_and_draw_array.rpc_id(peer_id, ids, positions, states, alive,active)			
