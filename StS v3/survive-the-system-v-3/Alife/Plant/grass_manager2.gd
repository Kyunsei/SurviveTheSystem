extends Node3D

#################
#
# v2 of grass/plant manager  
# fully ECS here hopefully will help performance gain...
# v3 MULTITHREAD!!!!
#######################


var FPS : float
var Grass_simulator_time = 0
#var id : PackedInt32Array

#WORLD
var flow_world_array : Array[PackedVector3Array]
var field_world_array : Array[PackedFloat64Array]
var species_world_array : Array[PackedInt32Array]
var sum_species_world_array : Array[PackedInt32Array]






#STATS
var position_array : PackedVector3Array
var size_array: PackedVector3Array  #NOT IN USE? 
var binID_array: PackedInt32Array

var current_energy_array : PackedFloat64Array
var current_health_array : PackedFloat32Array
var current_life_state_array : PackedInt32Array
var current_age_array : PackedInt32Array
var Alive_array : PackedInt32Array
var current_biomass_array : PackedFloat32Array
var Species_array : PackedInt32Array
var current_speed : PackedFloat32Array
var current_finite_state_array :  PackedInt32Array

#PLANT SPECIFIC 
var light_index_array : Array = []

#SPECIES SPECIFICIC WILL ALL MOVE TO DNA?
@export var species_list : Array[DNA]
#var species_id_array : Array =[]
var species_max_energy : Array[PackedFloat32Array]
var species_max_health : Array[PackedFloat32Array]
var species_max_age :Array[PackedInt32Array]
var species_homeostasis_cost : Array[PackedFloat32Array]
var species_decomposition_speed : Array[PackedFloat32Array]
var species_photosynthesis_absorption  : Array[PackedFloat32Array]
var species_photosynthesis_range : Array[PackedInt32Array]
var species_reproduction_cost : Array[PackedFloat32Array]
var species_reproduction_spread : Array[PackedFloat32Array]
var species_reproduction_number : Array[PackedInt32Array]
var species_biomass : Array[PackedFloat32Array]






#FOR MANAGER
var Active : PackedInt32Array
var _pending_spawns_positions: PackedVector3Array
var _pending_spawns_species: PackedInt32Array
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

class WorkerData:
	var start : int
	var end : int
	var delta : float

var workers : Array = []
var worker_threads : Array = []
var worker_count := 8
var threads_done := 0
var semaphore := Semaphore.new()

##########MULTITHREADS HERE

func start_threads():
	for i in range(worker_count):
		var t = Thread.new()
		worker_threads.append(t)
		var worker = WorkerData.new()
		workers.append(worker)
		t.start(worker_loop.bind(i))


func worker_loop(id):
	while true:
		semaphore.wait() # wait until work assigned
		var w = workers[id]
		update_in_range(w.start, w.end, w.delta)
		mutex.lock()
		threads_done += 1
		#Grass_simulator_time -= 1
		#call_deferred("update_grass_time")
		mutex.unlock()

#

func update_smth(delta):

	@warning_ignore("integer_division")
	var chunk = int(entity_count / worker_count)
	threads_done = 0
	for i in range(worker_count):
		var start = i * chunk
		var end = start + chunk
		if i == worker_count - 1:
			end = entity_count
		workers[i].start = start
		workers[i].end = end
		workers[i].delta = delta
		semaphore.post()
	# wait for all threads
	while threads_done < worker_count:
		OS.delay_usec(50)
		
		
		
func update_in_range(start, end, delta):
	for i in range(start,end):
			if i > entity_count-1:
				continue
			if Active[i]:
				var s = Species_array[i]
				var t = current_life_state_array[i]
				if Alive_array[i] == 1:
					if current_life_state_array[i] == 0:
						Germination(i,s,t)
					else:
						
						Homeostasis(i,s,t,delta)
						Growth(i,s,t,delta)
						Reproduction(i,s,t,delta)
				else:
					Decompose(i,s,t, delta)


func start_simulation_multithread():
	start_threads()

		
####################################

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
	for t in worker_threads:
		t.wait_to_finish()

func _thread_loop():
	
	while not thread_should_stop:
		
		var delta := 0.016  
		mutex.lock()
		update(delta)
		thread_result_ready = true
		Grass_simulator_time -= 1
		call_deferred("update_grass_time")
		mutex.unlock()

		OS.delay_msec(1)  # prevent CPU burning

func _process(_delta):
	if GlobalSimulationParameter.DEBUG_grass_sim == 0:
		return
	if !multiplayer.is_server():
		return
	

	# Check if any species has pending work
	var has_pending = false
	if _pending_spawns_positions.size() > 0 \
	or _pending_kills.size() > 0 \
	or _pending_update.size() > 0:
		has_pending = true

	if !has_pending:
		return

	mutex.lock()
	Spawn_and_Kill()
	'for w in workers:
		print(w.start)'
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
		build_world_bin_tables()
		#for i in range(1):
		#	Spawn_New_Grass(Vector3(0+0*i,0,0),0)
		isInit = true
		start_simulation_thread()
		#start_simulation_multithread()



'func batch_work():
	var worker_count = 5
	var start : int
	var end : int
	var delta : float
	var chunk = int(entity_count / worker_count)'

func update(delta):
	if !isInit:
		print("grass manger not initialised")
		return
	if GlobalSimulationParameter.SimulationStarted  == true: # and isInit == false:
		#var oldv = 0
		var ss = Time.get_ticks_msec() 
		if GlobalSimulationParameter.simulation_speed > 0:
			if World:
				World.add_value_in_each_tile(World.light_array,World.light_flux_in,0,World.light_max_value) #should be moved sommewhere else?
			update_field()
			LightSystem_to_plant(delta)
			#print(flow_world_array[0])
			for i in range(entity_count):
				if Active[i] == 1:
					#continue
					entity_update(i,delta)
					
					'var s = Species_array[i]
					var t = current_life_state_array[i]
					if Alive_array[i] == 1:
						if current_life_state_array[i] == 0:
							Germination(i,s,t)
						else:
							
							Homeostasis(i,s,t,delta)
							Growth(i,s,t,delta)
							Reproduction(i,s,t,delta)
							Move(i,delta)
					else:
						Decompose(i,s,t, delta)'
		
		FPS = Time.get_ticks_msec() - ss
	
	
# World system — runs once per tick
func update_field() -> void:
	# Decay existing field
	for s in range(field_world_array.size()):
		for i in range(field_world_array[s].size()):
			field_world_array[s][i] *= 0.85  # evaporate over time
	
	for i in range(entity_count):
		if Active[i] == 0:
			continue
		var bin = binID_array[i]
		var s = Species_array[i]
		field_world_array[s][bin] += 1
		#field_world_array[s][bin] = min(field_world_array[s][bin],10.0)

		
	for s in range(field_world_array.size()):
		field_world_array[s] = diffuse(field_world_array[s])
		
	for s in range(species_list.size()):
		flow_world_array[s] = get_flow(field_world_array[s],flow_world_array[s] )

func diffuse(field: PackedFloat64Array) :
	var next := field.duplicate()
	var GRID_WIDTH: int =  int(World.World_Size.x/ World.bin_size.x)
	var GRID_HEIGHT: int =  int(World.World_Size.z/ World.bin_size.z)
	var diffusion_rate = 0.25
	for cell in range(field.size()):
		@warning_ignore("integer_division")
		var row = cell / GRID_WIDTH
		var col = cell % GRID_WIDTH
		var sum  := 0.0
		var count := 0
		
		if row > 0:                
			sum += field[cell - GRID_WIDTH]; count += 1  # up
		if row < GRID_HEIGHT - 1:  
			sum += field[cell + GRID_WIDTH]; count += 1  # down
		if col > 0:                
			sum += field[cell - 1];          count += 1  # left
		if col < GRID_WIDTH - 1:   
			sum += field[cell + 1];          count += 1  # right

		next[cell] = lerp(field[cell], sum / count, diffusion_rate) #CHECK DIFFUSION RATE HERE
	
	return next

func get_flow(field: PackedFloat64Array, flow:PackedVector3Array):
	var GRID_WIDTH: int =  int(World.World_Size.x/ World.bin_size.x)
	var GRID_HEIGHT: int =  int(World.World_Size.z/ World.bin_size.z)
	var flow2 = flow.duplicate()
	for i in GRID_WIDTH * GRID_HEIGHT:
		@warning_ignore("integer_division")
		var row := i / GRID_WIDTH
		var col := i % GRID_WIDTH
	
	# Skip all edges — any would cause out-of-bounds
		if row == 0 or row == GRID_HEIGHT - 1:
			continue
		if col == 0 or col == GRID_WIDTH - 1:
			continue

		flow[i] = Vector3(
		field[i + 1]    - field[i - 1],     # x gradient
		0,
		field[i + GRID_WIDTH] - field[i - GRID_WIDTH]  # z gradient
		)
	return flow2


func calculate_flow_at_bin(s: int, bin: int):
	var GRID_WIDTH: int =  int(World.World_Size.x/ World.bin_size.x)
	var GRID_HEIGHT: int =  int(World.World_Size.z/ World.bin_size.z)
	var row := bin / GRID_WIDTH
	var col := bin % GRID_WIDTH
	var dx := 0.0
	var dz := 0.0

	# X gradient
	if col > 0 and col < GRID_WIDTH - 1:
		dx = field_world_array[s][bin + 1] - field_world_array[s][bin - 1]  # central
	elif col == 0:
		dx = field_world_array[s][bin + 1] - field_world_array[s][bin]      # forward
	else:
		dx = field_world_array[s][bin] - field_world_array[s][bin - 1]      # backward


	# Z gradient
	if row > 0 and row < GRID_HEIGHT - 1:
		dz = field_world_array[s][bin + GRID_WIDTH] - field_world_array[s][bin - GRID_WIDTH]
	elif row == 0:
		dz = field_world_array[s][bin + GRID_WIDTH] - field_world_array[s][bin]
	else:
		dz = field_world_array[s][bin] - field_world_array[s][bin - GRID_WIDTH]


	var flow = Vector3(dx, 0, dz)
	return flow



func LightSystem_to_plant(delta): #THIS SCRIPT IS NOT USED
	for bi in range(World.light_bin.size()):
		var light_value = World.light_array[bi]
		if light_value <= 0:
			continue
		
		var grass = World.light_bin[bi]
		if !grass:
			continue

		#var share = light_value/World.light_bin[bi].size()
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
			current_energy_array[gi] = clamp(current_energy_array[gi],0 ,species_max_energy[s][t]* GlobalSimulationParameter.simulation_speed)
			World.light_array[bi] = 0
			break

		
func entity_update(i,delta):
	species_list[Species_array[i]].Update(self,i,delta)
	
		
			
func Photosynthesis(i,delta):
	var s = Species_array[i]
	var t = min(current_life_state_array[i],species_photosynthesis_absorption[s].size()-1)
	var time_value = species_photosynthesis_absorption[s][t] * GlobalSimulationParameter.simulation_speed * delta
	for l_i in light_index_array[i]:		
		if l_i <  World.light_array.size():
			var energy_absorbed = World.light_array[l_i] * time_value
			if energy_absorbed <= 0:
				return
			current_energy_array[i] = clamp(current_energy_array[i] + energy_absorbed,0 ,species_max_energy[s][t]* GlobalSimulationParameter.simulation_speed)
			var shadow_effect = 1.0
			World.light_array[l_i] = max(World.light_array[l_i]-shadow_effect,0)

func Homeostasis(i,s,t,delta):
	t = min(t,species_photosynthesis_range[s].size()-1)
	if current_health_array[i] <= 0:
		Death(i)
		_pending_update.append(i)
		return
		
	var area = max(1,(species_photosynthesis_range[s][t] * 2) * (species_photosynthesis_range[s][t] * 2 ))
	t = min(current_life_state_array[i],species_homeostasis_cost[s].size()-1)
	current_energy_array[i] -= species_homeostasis_cost[s][t] * area * GlobalSimulationParameter.simulation_speed * delta
	Regenerate_Health(i,s,t,delta)
		
	

	if current_energy_array[i] <= 0:
		current_health_array[i] -= species_homeostasis_cost[s][t]  * GlobalSimulationParameter.simulation_speed * delta


func Move(i,delta):
	if current_speed[i] == 0.:
		return
	var direction = Vector3(randf_range(-1,1),0,randf_range(-1,1))
	position_array[i] += direction * current_speed[i] * GlobalSimulationParameter.simulation_speed * delta
	position_array[i].x = clamp(position_array[i].x ,-World.World_Size.x/2,World.World_Size.x/2 )
	position_array[i].z = clamp(position_array[i].z ,-World.World_Size.z/2,World.World_Size.z/2 )
	
	
	if get_real_current_bin(i) != binID_array[i]:
		put_in_world_bin(i)
	_pending_update.append(i)

func Regenerate_Health(i,s,t,delta):

	t = min(t,species_max_health[s].size()-1)

	if current_health_array[i] != species_max_health[s][t]:
		var value_regen = min(current_energy_array[i]/2 * GlobalSimulationParameter.simulation_speed * delta, species_max_health[s][t] - current_health_array[i]) 		
		current_health_array[i] += value_regen
		current_energy_array[i] -= value_regen	

	
func Growth(i,s,_t,delta):
	if species_list[s].Growth(self,i,delta):
		_pending_update.append(i)

func Death(i):
	Alive_array[i] = 0
	remove_from_light_bin(i)

	
func Reproduction(i,s,t,_delta):	
		t = min(t,species_reproduction_cost[s].size()-1)
		if current_energy_array[i] >= species_reproduction_cost[s][t]*2:
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
	


func Germination(i,s,t):

	t = min(t,species_photosynthesis_range[s].size()-1)
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
func Decompose(i,s,t,delta):
	t = min(t,species_decomposition_speed[s].size()-1)
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
	var spawned_species := PackedInt32Array()  # NEW
	var killed_ids := PackedInt32Array()
	var killed_species := PackedInt32Array()   # NEW
	var updated_ids := PackedInt32Array()	


	#var unique_kills :PackedInt32Array = remove_duplicate_in_index_array(_pending_external_kills,_pending_kills)
	#var unique_updates :PackedInt32Array = remove_duplicate_in_index_array(_pending_external_update,_pending_update)
	#print(_pending_kills)
	for i in _pending_kills:
			Kill_Grass(i)
			killed_ids.append(i)
			killed_species.append(Species_array[i])  
			
	for i in range(_pending_spawns_positions.size()):
			var new_id = Spawn_New_Grass(_pending_spawns_positions[i], _pending_spawns_species[i])
			spawned_ids.append(new_id)
			spawned_positions.append(_pending_spawns_positions[i])
			spawned_species.append(_pending_spawns_species[i])  # NEW
				
	'for i in range(_pending_external_spawns_id.size()):
		Spawn_Grass(_pending_external_spawns_id[i],_pending_external_spawns_positions[i])
		#Spawn_Grass(i)
		#Build_New_Grass(i, pos, sp)'

	for i in _pending_update:
			updated_ids.append(i)
	
# ---- SEND TO CLIENTS ----
	if spawned_ids.size() > 0:
		draw_new_grass.rpc(spawned_ids,spawned_positions,spawned_species)#, state_array, alive_array)
		
	if killed_ids.size() > 0:
		erase_grass.rpc(killed_ids,killed_species)

	if updated_ids.size() > 0:
		var pos_array := PackedVector3Array()
		var state_array := PackedInt32Array()
		var alive_array := PackedInt32Array()
		var actives := PackedInt32Array()
		var update_species := PackedInt32Array()  # NEW
		
		for id in updated_ids:
			pos_array.append(position_array[id])
			state_array.append(current_life_state_array[id])
			alive_array.append(Alive_array[id])
			actives.append(Active[id])
			update_species.append(Species_array[id])  

		update_drawn_grass.rpc(updated_ids, pos_array, state_array, alive_array,actives,update_species)

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
		current_speed.append(species_list[sp].Max_speed[0])
		Alive_array.append(1)
		Active.append(1)
		current_biomass_array.append(species_biomass[sp][0])
		position_array.append(pos)
		#size_array[i]  = Vector3(1,1,1)  #HERE NOT IN USE? 
		binID_array.append(get_worldbin_index(pos))	
		light_index_array.append(get_lightIndex(i))
		current_finite_state_array.append(0)
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
		current_finite_state_array[i] = 0
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
	var i : int
	if free_indices.size()> 0:
		i = free_indices.pop_back()
	else:
		i = entity_count
		entity_count += 1
		
	Build_New_Grass(i, newpos, s)
	#species_id_array[s].append(i)
	if 	get_parent().current_life_count_by_species.has(Species_array[i]):
		get_parent().current_life_count_by_species[Species_array[i]] += 1
	else:
		get_parent().current_life_count_by_species[Species_array[i]] = 1
	return i 
	
func Kill_Grass(i):

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

func build_world_bin_tables():
	var count = species_list.size()

	field_world_array.resize(count)
	flow_world_array.resize(count)
	species_world_array.resize(count)
	sum_species_world_array.resize(count)

	for s in range(species_list.size()):
		for t in range(World.bin_array.size()):
			field_world_array[s].append(0.0)
			flow_world_array[s].append(Vector3(0,0,0))
			sum_species_world_array[s].append(0)
			#species_world_array[s].append([])


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
		#species_id_array.append([])


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
	if 	get_parent().current_life_count_by_species.has(Species_array[i]):
		get_parent().current_life_count_by_species[Species_array[i]] -= 1
	
func add_to_world(i,pos):
	position_array[i] = pos
	put_in_world_bin(i)
	put_in_light_bin(i)
	light_index_array[i] = get_lightIndex(i)
	Active[i] = 1
	_pending_update.append(i)
	if 	get_parent().current_life_count_by_species.has(Species_array[i]):
		get_parent().current_life_count_by_species[Species_array[i]] += 1
	else:
		get_parent().current_life_count_by_species[Species_array[i]] = 1

func remove_from_light_bin(idx):	
	for li in light_index_array[idx]:
		if World.light_bin[li].has(idx):
			World.light_bin[li].erase(idx)
	light_index_array[idx].clear()


func get_real_current_bin(i):
	var w_pos = World.get_PositionInGrid(position_array[i],World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)	
	return new_bin_ID

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
		#World.bin_sum_array[Species_array[i]][new_bin_ID] += 1
		#species_world_array[Species_array[i]][new_bin_ID] += 1
		sum_species_world_array[Species_array[i]][new_bin_ID] += 1
	else:	
		World.bin_array[new_bin_ID].append(i) 
		#World.bin_sum_array[Species_array[i]][new_bin_ID] += 1
		#species_world_array[Species_array[i]][new_bin_ID] += 1
		sum_species_world_array[Species_array[i]][new_bin_ID] += 1

	#binID_array[i] = new_bin_ID
	
	
func remove_from_world_bin(i):
	if binID_array[i] >= 0:
		if World.bin_array[binID_array[i]].has(i):
			World.bin_array[binID_array[i]].erase(i)
			#World.bin_sum_array[Species_array[i]][binID_array[i]] -= 1
			sum_species_world_array[Species_array[i]][binID_array[i]] -= 1
			field_world_array[Species_array[i]][binID_array[i]] -= 1
			binID_array[i] = -1


			
			
############################### RPC
##########################MULTIMESH GESTION


######### UPDATE HERE. NEW SYSTEM IS: HAVING 2D new ARRAY , one by species
### having after
#### grass draw id_array[0] , pos_array[0]
#### tree draw id_array[0] , pos_array[0]

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(id_array, pos_array, sp_array):#, state_array, alive_array):	
	for c in range(id_array.size()):
		var i = id_array[c]
		var si = sp_array[c]
		if si == 0:
				$grass.draw_new_grass(i, pos_array[c])#, state_array, alive_array)
		elif si == 1:
				$tree.draw_new_grass(i, pos_array[c])#, state_array, alive_array)
		elif si == 2:
				$moss.draw_new_grass(i, pos_array[c])#, state_array, alive_array)
		elif si == 3:
				$sheep.draw_new_grass(i, pos_array[c])#, state_array, alive_array)
	$grass.multimesh.visible_instance_count = $grass.instance_number
	$tree.multimesh.visible_instance_count = $tree.instance_number		
	$moss.multimesh.visible_instance_count = $moss.instance_number	
	$sheep.multimesh.visible_instance_count = $sheep.instance_number		
	

@rpc("authority", "call_remote", "reliable") 			
func update_drawn_grass(id_array, pos_array, state_array, alive_array,active,species_array):
	for c in range(id_array.size()):
		var s = species_array[c]
		if s == 0:
			$grass.update_drawn_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active[c])
		elif s == 1:
			$tree.update_drawn_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active[c])
		elif s == 2:
			$moss.update_drawn_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active[c])
		elif s == 3:
			$sheep.update_drawn_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active[c])

@rpc("authority", "call_remote", "reliable") 
func erase_grass(id_array,species_array):
	for c in range(id_array.size()):
		var s = species_array[c]
		if s == 0:
			$grass.remove_grass(id_array[c])
		elif s == 1:
			$tree.remove_grass(id_array[c])
		elif s == 2:
			$moss.remove_grass(id_array[c])
		elif s == 3:
			$sheep.remove_grass(id_array[c])			
			

@rpc("any_peer","call_remote")
func send_and_draw_array(id_array, pos_array, state_array, alive_array, active_array,species_array):
	$grass.init()
	$tree.init()
	$moss.init()
	$sheep.init()
	for c in range(id_array.size()):
		var s = species_array[c]
		if s == 0:
			$grass.draw_all_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active_array[c])
		elif s == 1:
			$tree.draw_all_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active_array[c])
		elif s == 2:
			$moss.draw_all_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active_array[c])
		elif s == 3:
			$sheep.draw_all_grass(id_array[c], pos_array[c], state_array[c], alive_array[c], active_array[c])
		
	$grass.multimesh.visible_instance_count = $grass.instance_number
	$tree.multimesh.visible_instance_count = $tree.instance_number
	$moss.multimesh.visible_instance_count = $moss.instance_number
	$sheep.multimesh.visible_instance_count = $sheep.instance_number

func update_grass_time():
	if Grass_simulator_time > 0:
		$CanvasLayer.show()
	else:
		$CanvasLayer.hide()
	$CanvasLayer/ProgressBar.value = 2000 - Grass_simulator_time


func _on_peer_connected(id):
	if multiplayer.is_server():
		send_full_state_to_peer(id)

@rpc("any_peer","call_remote")
func send_full_state_to_peer(peer_id):

	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var states := PackedInt32Array()
	var alive := PackedInt32Array()
	var active := PackedInt32Array()
	var species := PackedInt32Array()

	for i in range(entity_count):
		#if Active[i] == 1:
			ids.append(i)
			positions.append(position_array[i])
			states.append(current_life_state_array[i])
			alive.append(Alive_array[i])
			active.append(Active[i])
			species.append(Species_array[i])

	send_and_draw_array.rpc_id(peer_id, ids, positions, states, alive,active,species)			
