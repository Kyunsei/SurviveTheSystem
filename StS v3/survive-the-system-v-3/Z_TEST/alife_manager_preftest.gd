extends Node2D
class_name AlifeManager

#THIS SCRIPT MANAGE THE DIFFERENT ALIFE SPECIES and connect them together and with other simulation element [player/world/rendering]
#A bit similar to the one above (SimulationManager) but more focus on Alife

#TODO wait thread?
#TODO fix chunk number/order or make it random?
#TODO simulation time in threads?
#TODO sensing alife x alife : wolrd partioning + flow?
#TODO think for Species modularity & perforrmance: add different species
#TODO add physics collision/gravity?
#TODO optimise AI

##Simulation par
var maxLife = 0 # 0
var time := 0.0
var dt := 0.0#.32
var time_counter := 1
var total_time : = 0

#cross reference
var world: World

#ECS STATS
var position_array : PackedVector3Array
var current_energy_array : PackedFloat64Array
var active_alife_array : PackedInt32Array  #To reuse some 
var alive_array : PackedInt32Array

var free_indices : Array =[]
var entity_count : int
var active_entity_count : int


var species_id : PackedInt32Array
var color_array : PackedColorArray
var current_life_state : PackedInt32Array
var current_biomass : PackedFloat32Array
var current_age : PackedInt32Array
var current_size : PackedFloat32Array
var grow_on := true

#### Duplicate
var duplicate_on := true
var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array

#Reusing agent?
var remove_on:= true

##RENDERING
var visualisation_on := true
var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array

#####AI THINGS¬¬¬¬¬
var AI_on := false
var current_action :PackedByteArray
var action_scores := PackedFloat32Array()  # allocated once, reused

enum Action { MOVE, EAT, DUPLICATE }
var sp_Action_weight : PackedFloat32Array = [1.,-1.,-0.2]
const ACTION_COUNT := 3
const WEIGHTS := [1.0, 1.0, 1.0] 
var MOMENTUM := 1.2
var mouse_target : Vector3

### ALIFE GRID - agent - agent close detection

#old? CHECK THSI ONE?
var LifeBin_array : Array[PackedInt32Array]  #HERE CAN BE COOL TO SEE IF REORDERING MATTERS

var bin_on = true
var cell_size := 10.0

var GRID_W := 32          # cells along x
var GRID_H := 16          # cells along y
var GRID_D := 32          # cells along z
var GRID_WD := GRID_W * GRID_D
var GRID_WH := GRID_W * GRID_H
var NUM_CELLS := GRID_W * GRID_H * GRID_D

var bin_origin := Vector3.ZERO   # min corner of the grid in world space

var cell_start := PackedInt32Array()     # size NUM_CELLS + 1
var write_pos := PackedInt32Array()      # size NUM_CELLS (scratch)
var cell_items := PackedInt32Array()     # size = alife count
var current_cell_id := PackedInt32Array()  # size = alife count
var sorted_pos := PackedVector3Array()



### FLOW
var flow_on = true
var flowbin_size := 10.0
var flowbin_dic : Dictionary
#var current_bin_id : Array[Vector3i]
 



#Randomness
const JITTER_COUNT := 4096
var _jitter: PackedVector3Array
var _jhead: int = 0

###multithread things
var gid := -1
var jobs: Array = []     # each entry: [species, chunk_index]

var nThread_max := 8#1
var chunk_count: int
var chunk_size: int
#TODO adjust these number to see performance difference!
const MIN_CHUNK := 256      # never smaller: avoids overhead
const MAX_CHUNK := 8192     # never bigger: keeps balance
const JOBS_PER_THREAD := 4
var mutex := Mutex.new()

var spawn_per_chunk : Array[PackedInt32Array] = []
var remove_per_chunk : Array[PackedInt32Array] = []

#############################
#for perf of multithread
var chunk_usec: PackedInt64Array
var chunk_tid: PackedInt64Array
var	total_thread_usec := 0.
var thread_usec := 0.
var	multithread_efficiency := 0.
var	nThreadused := 0

#### main loop track perf
var main_usec = 0.
var uai_usec = 0.
var bin_screen_usec = 0.
var bin_action_usec = 0.
var bin_update_usec = 0.
var multithread_usec = 0.
var merge_usec = 0.


#############################################################################################
##############################################################################################


var switch := true
var species_array : Array[TESTDNA]
var n_species :=2




func _ready() -> void:
	#TODO check how noise is working in different species now... and look to seed it?
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))

	
func init(worldd):
	#time
	total_time = 0
	entity_count = 0
	active_entity_count =0
	#alife 
	position_array = [] 
	current_energy_array = [] 
	active_alife_array = []   #To reuse some 
	alive_array = []
	free_indices = [] 
	pending_multimesh_drawn_id = []
	pending_multimesh_erase_id = []
	pending_spawn_id = []
	pending_remove_id = []
	color_array = []	
	current_life_state= []
	current_biomass= []
	current_age= []
	current_size= []
	#multithread
	chunk_count = clamp( nThread_max,1,OS.get_processor_count()) 
	#AI
	action_scores.resize(ACTION_COUNT)
	current_action = []
	#Bin
	#bin_ids_array.clear()
	LifeBin_array.clear()
	#bin_ids_array.resize(10) #TODO
	#current_bin_id = []
	#FLOW not yet there
	flowbin_dic.clear()	
	
	##WORLD
	world = worldd
	init_GRID(world.size)
	init_species(world,self)
	
			
func init_species(worldd:World,alifem:AlifeManager):
	if switch:
		for c in get_children():
			c.queue_free()
		species_array.resize(n_species)
		for s in n_species:
			species_array[s] = TESTDNA.new()
			species_array[s].colour = Color(randf(),randf(),randf())
			species_array[s].init(worldd,alifem)

			if s == 1:
				species_array[s].growth_rate = 1		
	
func init_GRID(world_size):
	#THIS IS the grid of close agent-agent interaction, where cell_size > range of detection
	
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	GRID_WD = GRID_W * GRID_D
	GRID_WH = GRID_W * GRID_H
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	write_pos.resize(NUM_CELLS)

func compute_chunk(total:int) -> int:
	var threads := OS.get_processor_count()
	threads = clamp( nThread_max,1,OS.get_processor_count()) 
	@warning_ignore("integer_division")
	var chunk := total / (threads * JOBS_PER_THREAD)
	return clampi(chunk, MIN_CHUNK, MAX_CHUNK)

#NEED RENAME THIS FUNCTION
func run_simulation2(delta: float, sim_speed: float):
	var t00 := Time.get_ticks_usec()
	#if sim speed or delta is changed or anything thread is using. safer to change it before start or after wait!
	if bin_on:
		var bin_t0 = Time.get_ticks_usec()
		build_grid(position_array)
		bin_update_usec =  Time.get_ticks_usec() - bin_t0
	var t0 := Time.get_ticks_usec()
	start_simulation(delta,sim_speed)
	wait_simulation()
	multithread_usec = Time.get_ticks_usec() - t0
	var t2 := Time.get_ticks_usec()
	update_alife()
	merge_usec = Time.get_ticks_usec() -t2
	main_usec = Time.get_ticks_usec() - t00

	#MERGE



func start_simulation(delta: float, sim_speed: float):
	dt = delta * sim_speed #TOBE USED LATER	
	#update 
	var m := get_viewport().get_mouse_position()
	var mouse := Vector3(m.x, 0.0, m.y)
	entity_count = 0
	for s in species_array:
		entity_count += s.entity_count
		s.mouse_target =  mouse

	#setup thread/chunk/jobs
	jobs.clear()
	chunk_size = compute_chunk(entity_count) #need full entity count to work
	for s in species_array:
		var local_id:= 0
		var n: int = s.entity_count
		for start in range(0, n, chunk_size):
			jobs.append([s, start, mini(start + chunk_size, n),local_id])
			local_id += 1
		s.set_chunk(local_id)
	
	#run working group	
	gid = -1	
	if jobs.size() > 0:
		#gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), -1, true, "species_update")
		gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), nThread_max, true, "species_update")

func run_chunk(k: int) -> void:
	var job = jobs[k]
	job[0].run_chunk_simulation(job[1], job[2],job[3], dt)

func wait_simulation() -> void:
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1

func update_alife()-> void:
	for s in species_array:
		s.Build_and_remove_pendings()


	

#########################################################################################
######################OLD SCRIPT BELOW###################################################
#########################################################################################


func run_simulation(delta: float, sim_speed: float):
	var t00 := Time.get_ticks_usec()
	bin_update_usec = 0.0
	bin_action_usec = 0.0 
	bin_screen_usec = 0.0
	main_usec = 0.0
	uai_usec = 0.0	
	var j := _jhead	
	var n := _jitter.size()
	var temp_spawn_id : PackedInt32Array
	var temp_remove_id : PackedInt32Array

	
	if bin_on:
		var bin_t0 = Time.get_ticks_usec()
		build_grid(position_array)
		bin_update_usec =  Time.get_ticks_usec() - bin_t0
		for i in active_alife_array.size():
			bin_t0 = Time.get_ticks_usec()

			var pos_i := position_array[i]
			var c := current_cell_id[i]

			# decode cell (matches cx + W * (cy + H * cz))
			var cx := c % GRID_W
			var cy := (c / GRID_W) % GRID_H
			var cz := c / GRID_WH

			# clamp the 3x3x3 neighbourhood to the grid
			var x0 := maxi(cx - 1, 0)
			var x1 := mini(cx + 1, GRID_W - 1)
			var y0 := maxi(cy - 1, 0)
			var y1 := mini(cy + 1, GRID_H - 1)
			var z0 := maxi(cz - 1, 0)
			var z1 := mini(cz + 1, GRID_D - 1)

			var cc := 0
			for nz in range(z0, z1 + 1):
				for ny in range(y0, y1 + 1):
					var row := GRID_W * (ny + GRID_H * nz)
					# x0..x1 cells are contiguous -> one range for all three
					for s in range(cell_start[row + x0], cell_start[row + x1 + 1]):
						
						if pos_i.distance_squared_to(sorted_pos[s]) < 100:# RADIUS_SQ:
							cc += 1
			bin_screen_usec +=  Time.get_ticks_usec() - bin_t0
										
			var bin_t1 = Time.get_ticks_usec()
			if cc >= 10  and cc <20:
				color_array[i]= Color(0.13, 0.192, 0.516, 1.0)
			elif cc >= 20:
					color_array[i]= Color(0.434, 0.076, 0.137, 1.0)
			else:
				color_array[i]= Color(0.239, 0.545, 0.358, 1.0)
			if i == 0 :
				color_array[i]= Color(0.75, 0.78, 0.187, 1.0)

			bin_action_usec +=  Time.get_ticks_usec() - bin_t1
	if AI_on:
		var bounds_max := Vector3(GRID_W, GRID_H, GRID_D) * cell_size
		mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
		var full := 0.0
		var hungry := 0.0
		var target_far := 0.0
		var target_close  := 0.0
		var best_action := 0
		var dir : Vector3

		for i in active_alife_array.size():

			var uai_t0 = Time.get_ticks_usec()
			var pi := position_array[i]
			var ei := current_energy_array[i]
			var diff := pi-mouse_target
			var dist := diff.length()
			
			#Consideration
			full = clampf(ei / 5.0, 0.0, 1.0)
			hungry = 1- full
			target_far = clampf(dist / 1000, 0.0, 1.0)
			target_close = (1- target_far)*0.1

			#action scores
			action_scores[Action.MOVE] = target_close #* full
			action_scores[Action.EAT] = target_far * hungry
			action_scores[Action.DUPLICATE] = target_far * full
			#action_scores[current_action[i]] *= MOMENTUM

			#choose best
			best_action = 0
			for a in range(1, ACTION_COUNT):
				if action_scores[a] > action_scores[best_action]:
					best_action = a
			current_action[i] =  best_action
		
			#DO ACTION
			match best_action:
				Action.EAT:
					current_energy_array[i] += (1) * delta * sim_speed #* active_alife_array[i]
					pi += _jitter[j]  
					j += 1
					if j >= n:
						j = 0
					
				Action.DUPLICATE:
					if duplicate_on:
						temp_spawn_id.append(i)
					current_energy_array[i] -= 5
				
				Action.MOVE:
					dir = diff.normalized() * sp_Action_weight[species_id[i]]
					pi += dir * 2
			current_energy_array[i] += -0.5 * delta * sim_speed #* active_alife_array[i]
			#WRAP or CLAMP
			#if !wrap : 
			position_array[i] = pi.clamp(Vector3.ZERO, bounds_max)

			uai_usec +=  Time.get_ticks_usec() - uai_t0
	if !AI_on:
		#var bounds_max := Vector3(GRID_W, GRID_H, GRID_D) * cell_size
		for i in active_alife_array.size():
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue
				
			if !world.SUN_on:
				current_energy_array[i] += (1) * 0.16 * 1 #* active_alife_array[i]
			
			current_energy_array[i] += -0.5 *  0.16 * 1 #* active_alife_array[i]
			if current_energy_array[i] >= 5:
				if duplicate_on:
					temp_spawn_id.append(i)
				current_energy_array[i] -= 5

			if current_energy_array[i] < 0 :
				alive_array[i] = 0
				#temp_remove_id.append(i)
			
			#WRAP or CLAMP
			#if !wrap : 
			#position_array[i] = position_array[i].clamp(Vector3.ZERO, bounds_max)
	if grow_on:
		for i in active_alife_array.size():
			var ei:= current_energy_array[i]
			var cls := current_life_state[i]
			if cls <3:
				if ei > 3:
					current_life_state[i] += 1
					current_energy_array[i] -= 3
					current_size[i]+= 0.25
					current_biomass[i] += 2
			current_age[i]+=1
					
					
				

	_jhead = j
	
	if duplicate_on:
		for i in temp_spawn_id:
			Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i],color_array[i],)
	if remove_on:
		for i in alive_array.size():
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				Remove_Life(i)
	'if flow_on:
		flow_diffusion()'

	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t00

func run_plant_simulation(delta: float, sim_speed: float)	:
	var n := _jitter.size()
	var temp_spawn_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var j := _jhead	
	for i in entity_count:
		current_energy_array[i] += (1) * 0.16 * 1 #* active_alife_array[i]
		#position_array[i] +=  _jitter[j] #* amp
		#j+= 1
		#if j>= n:
		#	j= 0
		if current_energy_array[i] > 5:
			if duplicate_on:
				temp_spawn_id.append(i)		
			#Build_New_Life(pick_random_position(Vector3(5,0,5) + position_array[i]))
			current_energy_array[i] -= 5
		current_energy_array[i] -= 0.5 * 0.16 * 1 #* active_alife_array[i]

	#	position_array[i].x = clamp(position_array[i].x, 0.0 , GRID_W*cell_size)
	#	position_array[i].y = clamp(position_array[i].y, 0.0 , GRID_H*cell_size)
	#	position_array[i].z = clamp(position_array[i].z, 0.0 , GRID_D*cell_size)

		
	_jhead = j
	
	if duplicate_on:
		for i in temp_spawn_id:
			Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i],color_array[i],)

	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0


func run_simulation_multithread(delta, sim_speed):
	
	var bin_t0 = Time.get_ticks_usec()
	if bin_on:
		build_grid(position_array)
	bin_update_usec =  Time.get_ticks_usec() - bin_t0
	var t0 := Time.get_ticks_usec()

	'if entity_count == 0:
		return
	chunk_count = mini(nThread_max, entity_count)'
	chunk_size = ceili(float(entity_count) / chunk_count) 
	chunk_usec.resize(chunk_count)
	chunk_tid.resize(chunk_count)
	spawn_per_chunk.resize(chunk_count)
	remove_per_chunk.resize(chunk_count)
	for c in chunk_count:
		spawn_per_chunk[c] = PackedInt32Array()
		remove_per_chunk[c] = PackedInt32Array()
	mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	gid = WorkerThreadPool.add_group_task(run_chunk_simulation, chunk_count, chunk_count, true)	
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1
		Build_and_remove_pendings()
		getChunk_perf()

	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0

func run_simulation_multithread2(delta: float, sim_speed: float):
	mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	gid = WorkerThreadPool.add_group_task(doChunk, chunk_count, chunk_count, true)	
	var t0 := Time.get_ticks_usec()
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1
		Build_and_remove_pendings()
		getChunk_perf()

	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0
	

func run_chunk_simulation(chunk: int) -> void:
	var _sun_on := world.SUN_on
	var n := _jitter.size()
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var from := chunk * chunk_size
	var to := mini(from + chunk_size, entity_count)
	var j := (from + total_time) % n

	if bin_on:
		for i in range(from, to):
			#var bin_t0 = Time.get_ticks_usec()
			var pos_i := position_array[i]
			var c := current_cell_id[i]

			# decode cell (matches cx + W * (cy + H * cz))
			var cx := c % GRID_W
			var cy := (c / GRID_W) % GRID_H
			var cz := c / GRID_WH

			# clamp the 3x3x3 neighbourhood to the grid
			var x0 := maxi(cx - 1, 0)
			var x1 := mini(cx + 1, GRID_W - 1)
			var y0 := maxi(cy - 1, 0)
			var y1 := mini(cy + 1, GRID_H - 1)
			var z0 := maxi(cz - 1, 0)
			var z1 := mini(cz + 1, GRID_D - 1)

			var cc := 0
			for nz in range(z0, z1 + 1):
				for ny in range(y0, y1 + 1):
					var row := GRID_W * (ny + GRID_H * nz)
					# x0..x1 cells are contiguous -> one range for all three
					for s in range(cell_start[row + x0], cell_start[row + x1 + 1]):
						
						if pos_i.distance_squared_to(sorted_pos[s]) < 100:# RADIUS_SQ:
							cc += 1
			#bin_screen_usec +=  Time.get_ticks_usec() - bin_t0
										
			#var bin_t1 = Time.get_ticks_usec()
			if cc >= 10  and cc <20:
				color_array[i]= Color(0.13, 0.192, 0.516, 1.0)
			elif cc >= 20:
					color_array[i]= Color(0.434, 0.076, 0.137, 1.0)
			else:
				color_array[i]= Color(0.239, 0.545, 0.358, 1.0)
			if i == 0 :
				color_array[i]= Color(0.75, 0.78, 0.187, 1.0)
			#bin_action_usec +=  Time.get_ticks_usec() - bin_t1

	if AI_on:
		#AI / ALIFE
		var local_action_scores : PackedFloat32Array
		local_action_scores.resize(ACTION_COUNT)
		var full := 0.0
		var hungry := 0.0
		var target_far := 0.0
		var target_close  := 0.0
		var best_action := 0
		var dir : Vector3
		var pi : Vector3
		var ei : float
		var diff : Vector3
		var dist : float
		var bounds_max := Vector3(GRID_W, GRID_H, GRID_D) * cell_size
		for i in range(from, to):
			pi = position_array[i]
			ei = current_energy_array[i]
			diff = pi-mouse_target
			dist = diff.length()

		#Consideration
			full =clampf(current_energy_array[i] / 5.0, 0.0, 1.0)
			hungry = 1- full
			target_far =  clampf(dist / 1000, 0.0, 1.0)
			target_close = (1- target_far)*0.1

			#action scores
			local_action_scores[Action.MOVE] = target_close #* full
			local_action_scores[Action.EAT] = target_far * hungry
			local_action_scores[Action.DUPLICATE] = target_far * full
			#local_action_scores[current_action[i]] *= MOMENTUM

			#choose best
			best_action = 0
			for a in range(1, ACTION_COUNT):
				if local_action_scores[a] > local_action_scores[best_action]:
					best_action = a
			current_action[i] = best_action
			
			#DO ACTION
			match best_action:
				Action.EAT:
					current_energy_array[i] += (1) * 0.016 * 1 #* active_alife_array[i]
					pi += _jitter[j] 
					j += 1
					if j >= n:
						j = 0
					
				Action.DUPLICATE:
					if duplicate_on:
						local_pending_spawn_id.append(i)
					current_energy_array[i] -= 5
				
				Action.MOVE:
					dir =  diff.normalized()
					pi += dir * 2
			current_energy_array[i] -= 0.5* 0.016 * 1				
			position_array[i] = pi.clamp(Vector3.ZERO, bounds_max)
			
			
	else:
		for i in range(from, to):
					var _energy:= current_energy_array[i]
					if active_alife_array[i] == 0:
						continue
					if alive_array[i] == 0:
						continue
						
					if !_sun_on:
						_energy += (1) * 0.16 * 1 #* active_alife_array[i]
					
					_energy += -0.5 *  0.16 * 1 #* active_alife_array[i]
					if _energy >= 5:
						if duplicate_on:
							local_pending_spawn_id.append(i)
						_energy -= 5
					if _energy < 0 :
						alive_array[i] = 0
	
					current_energy_array[i] = _energy
	if grow_on:
		for i in range(from, to):
			var ei:= current_energy_array[i]
			var cls := current_life_state[i]
			if cls <3:
				if ei > 3:
					current_life_state[i] += 1
					current_energy_array[i] -= 3
					current_size[i]+= 0.25
					current_biomass[i] += 2
			current_age[i]+=1
	if duplicate_on:
		spawn_per_chunk[chunk] = local_pending_spawn_id
	if remove_on:
		for i in range(from, to):
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				local_pending_remove_id.append(i)
				
		remove_per_chunk[chunk] = local_pending_remove_id	
		
	'if duplicate_on:
		mutex.lock()
		for i in local_pending_spawn_id:
			pending_spawn_id.append(i)
		mutex.unlock()
		
	if remove_on:
		mutex.lock()
		for i in local_pending_remove_id:
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				pending_remove_id.append(i)
		mutex.unlock()'
	
	chunk_usec[chunk] = Time.get_ticks_usec() - t0
	chunk_tid[chunk] = OS.get_thread_caller_id()	

func doChunk(chunk: int) -> void:
	#var n := _jitter.size()
	var local_pending_spawn_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var from := chunk * chunk_size
	var to := mini(from + chunk_size, entity_count)

	#var amp := drift_speed * delta
	#var j := (from + total_time) % n
	for i in range(from, to):
		current_energy_array[i] += 1 * 0.16 * 1 #* active_alife_array[i]
		#position_array[i] +=  _jitter[j] #* amp
		#j+= 1
		#if j>= n:
		#	j= 0
		#current_energy_array[i] -= 0.5 * 0.16 * 1 * active_alife_array[i]
		if current_energy_array[i] > 5:
			if duplicate_on:

				local_pending_spawn_id.append(i)		
			#Build_New_Life(pick_random_position(Vector3(5,0,5) + position_array[i]))
			current_energy_array[i] -= 5
		current_energy_array[i] += -0.5 * 0.16 #* 1 * active_alife_array[i]

	#_jhead = j
	#	position_array[i].x = clamp(position_array[i].x, 0.0 , GRID_W*cell_size)
	#	position_array[i].y = clamp(position_array[i].y, 0.0 , GRID_H*cell_size)
	#	position_array[i].z = clamp(position_array[i].z, 0.0 , GRID_D*cell_size)

		#spA.update(self, i, 0.16, 1)

	if duplicate_on:
		mutex.lock()
		for i in local_pending_spawn_id:
			pending_spawn_id.append(i)
		mutex.unlock()
	
	chunk_usec[chunk] = Time.get_ticks_usec() - t0
	chunk_tid[chunk] = OS.get_thread_caller_id()
	
func getChunk_perf():
	var threads := {}
	var total := 0
	var max_time := 0.0
	for i in chunk_count:
			threads[chunk_tid[i]] = true
			total += chunk_usec[i]
			max_time = max(max_time,chunk_usec[i])
	total_thread_usec = total
	thread_usec = max_time
	multithread_efficiency = float(total) / maxf(1.0, float(main_usec))
	nThreadused = threads.size() # OS.get_processor_count()
	

##########################################################################################
####ARRAY MANAGEMENT
##########################################################################################

	
func Build_and_remove_pendings():

	for c in chunk_count:
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
		
	for i in pending_spawn_id:
		Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	

	pending_spawn_id.clear()
	pending_remove_id.clear()

func find_free_index():
	var i : int
	if free_indices.size()> 0:
		i = free_indices.pop_back()
	else:
		i = entity_count
	return i 	

func Build_New_Life(pos: Vector3, e: float, sp : int, col := Color(0.159, 0.555, 0.215, 1.0)):

	if entity_count >= maxLife and maxLife>0:
		return
	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(1)
		position_array.append(pos)
		current_action.append(0)
		species_id.append(sp)
		color_array.append(col)
		alive_array.append(1) 
		#current_bin_id.append(get_binID(pos,bin_size,world.size))
		current_life_state.append(0)
		current_biomass.append(0)
		current_age.append(0)
		current_size.append(1.0)
		#update_bin_array(i)
		entity_count += 1


		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = 1
		position_array[i] = pos
		current_action[i] = 0
		species_id[i] = sp
		color_array[i]=col
		alive_array[i] = 1
		#current_bin_id[i] = get_binID(pos,bin_size,world.size)
		#update_bin_array(i)
		current_life_state[i]=0
		current_biomass[i]=0
		current_age[i]=0
		current_size[i]=1.0

	active_entity_count += 1
	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):

	#TEMP : REMOVE =DEAD need to have two searate to see corps vs dispaear
		active_alife_array[i]= 0
		free_indices.append(i)
		active_entity_count -= 1
		pending_multimesh_erase_id.append(i)

func pick_random_position(rangee: Vector3)-> Vector3: # should be 3
	var x = randf_range(-rangee.x,rangee.x)
	var z = randf_range(-rangee.z,rangee.z)
	var y = randf_range(-rangee.y,rangee.y)

	return Vector3(x,y,z)

##########################################################################################
####BIN FUNCTION
##########################################################################################

'func get_binID(p : Vector3, binS : float) -> Vector3i:	
	#var array_size = World_Size/tile_size
	return Vector3i(floori(p.x / binS), floori(p.y / binS), floori(p.z / binS))'

	#return int(pos.x + array_size.x * (pos.y + array_size.y * pos.z))


func cell_id(cx: int, cy: int, cz: int) -> int:
	#USE here grid coordinate
	return cx + GRID_W * (cy + GRID_H * cz)


func build_grid(position_arrayy: PackedVector3Array) -> void:
	var n := position_arrayy.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	var inv := 1.0 / cell_size

	# 1. Count particles per cell
	for i in n:
		var p := (position_arrayy[i] - bin_origin) * inv
		var cx := clampi(roundi(p.x), 0, GRID_W - 1)
		var cy := clampi(roundi(p.y), 0, GRID_H - 1)
		var cz := clampi(roundi(p.z), 0, GRID_D - 1)
		var c := cx + GRID_W * (cy + GRID_H * cz)   # inline, no second division
		current_cell_id[i] = c
		cell_start[c + 1] += 1

	# 2. Prefix sum -> start offset of each cell
	for c in NUM_CELLS:
		cell_start[c + 1] += cell_start[c]
		write_pos[c] = cell_start[c]

	# 3. Scatter indices and positions into sorted order
	for i in n:
		var c := current_cell_id[i]
		var w := write_pos[c]
		cell_items[w] = i
		sorted_pos[w] = position_arrayy[i]
		write_pos[c] = w + 1

func flow_diffusion():
	pass
