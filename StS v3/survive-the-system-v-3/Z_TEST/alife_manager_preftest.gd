extends Node2D

#TODO make it close more easily? kindof fixed by stopping when FPS too low?
#TODO wait thread?
#TODO fix chunk number/order or make it random?
#TODO simulation time in threads?
#TODO optimise array extension and pending array? maybe more efficient code way -> check claude idea
#TODO sensing alife x alife : wolrd partioning + flow?
#TODO think for Species modularity & perforrmance: add different species
#TODO add physics collision/gravity?
#TODO optimise AI

##Simulation par
var maxLife = 8000 # 0
var time := 0.0
var dt := 0.0#.32
var time_counter := 1
var total_time : = 0


#ECS STATS
var position_array : PackedVector3Array

var current_energy_array : PackedFloat64Array
var active_alife_array : PackedInt32Array  #To reuse some 
var free_indices : Array =[]
var entity_count : int
var active_entity_count : int
var species_id : PackedInt32Array
var color_array : PackedColorArray

var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array

var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array


#####AI THINGS¬¬¬¬¬
var AI_on := true
var current_action :PackedByteArray
var action_scores := PackedFloat32Array()  # allocated once, reused

enum Action { MOVE, EAT, DUPLICATE }
var sp_Action_weight : PackedFloat32Array = [1.,-1.,-0.2]
const ACTION_COUNT := 3
const WEIGHTS := [1.0, 1.0, 1.0] 
var MOMENTUM := 1.2
var mouse_target : Vector3

### BIN - agent agent detection
var bin_on = true
var bin_size := 10.0
var bin_ids_array : Dictionary
var current_bin_id : Array[Vector3i]


### FLOW
var flow_on = true
var flowbin_size := 10.0
var flowbin_dic : Dictionary
#var current_bin_id : Array[Vector3i]
 

###Species?
var spA : SPECIES_TEST_A

#Randomness
const JITTER_COUNT := 4096
var _jitter: PackedVector3Array
var _jhead: int = 0

###multithread things
var gid := -1
var nThread_max := 8#1
var chunk_count: int
var chunk_size: int
var mutex := Mutex.new()

#############################
#for perf of multithread
var chunk_usec: PackedInt64Array
var chunk_tid: PackedInt64Array
var	total_thread_usec := 0.
var thread_usec := 0.
var	multithread_efficiency := 0.
var	nThreadused := 0

#### main loop track perf
var main_usec = 0
var uai_usec = 0
var bin_screen_usec = 0
var bin_action_usec = 0
var bin_update_usec = 0




func _ready() -> void:
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))

func init():
	#world
	total_time = 0
	entity_count = 0
	active_entity_count =0

	#alife 
	position_array = [] 
	current_energy_array = [] 
	active_alife_array = []   #To reuse some 
	free_indices = [] 
	pending_multimesh_drawn_id = []
	pending_multimesh_erase_id = []
	pending_spawn_id = []
	pending_remove_id = []
	color_array = []
	
	#multithread
	chunk_count = clamp( nThread_max,1,OS.get_processor_count()) 
	
	#AI
	action_scores.resize(ACTION_COUNT)
	current_action = []
	
	#Bin
	bin_ids_array.clear()
	#bin_ids_array.resize(10) #TODO
	current_bin_id = []
	
	#FLOW
	flowbin_dic.clear()
	
	#not used?
	spA = SPECIES_TEST_A.new()


func setup():
	@warning_ignore("integer_division")
	chunk_size = (entity_count + chunk_count - 1) / chunk_count  # ceil
	chunk_usec.resize(chunk_count)
	chunk_tid.resize(chunk_count)
	

func run_simulation(delta, sim_speed):
	bin_update_usec = 0.0
	bin_action_usec = 0.0 
	bin_screen_usec = 0.0
	main_usec = 0.0
	uai_usec = 0.0
	
	var t0 := Time.get_ticks_usec()
	var j := _jhead	
	var n := _jitter.size()
	var dir : Vector3
	var temp_spawn_id : PackedInt32Array
	mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	var full := 0.0
	var hungry := 0.0
	var target_far := 0.0
	var target_close  := 0.0
	var best_action := 0
	for i in active_alife_array.size():
		if AI_on:
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
					position_array[i] += _jitter[j]  
					j += 1
					if j >= n:
						j = 0
					
				Action.DUPLICATE:
					temp_spawn_id.append(i)
					current_energy_array[i] -= 5
				
				Action.MOVE:
					dir = diff.normalized() * sp_Action_weight[species_id[i]]
					position_array[i] += dir * 2
			uai_usec +=  Time.get_ticks_usec() - uai_t0

			
				
		current_energy_array[i] += -0.5 * delta * sim_speed #* active_alife_array[i]
		
		
		#TODO bin things
		if bin_on:
			var bin_t0 := Time.get_ticks_usec()

			'if floori(current_bin_id[i].x + current_bin_id[i].z ) % 2 == 0:
				species_id[i] = 0
			else:
				species_id[i] = 1'
			var cc := 0
			var central_bin := current_bin_id[i]
			var new_id : Vector3i

			if bin_ids_array.has(current_bin_id[i]):
				var pos_i = position_array[i]

				for xi in [-1,0,1]:
					for zi in [-1,0,1]:
						#if cc < 20:
							new_id.x = central_bin.x + xi
							new_id.z = central_bin.z + zi
							new_id.y = central_bin.y * 0
							var bin = bin_ids_array.get(new_id)
							if bin:
								for k in bin:
									if pos_i.distance_to(position_array[k])<10:
										cc += 1
										
			bin_screen_usec +=  Time.get_ticks_usec() - bin_t0
			bin_t0 = Time.get_ticks_usec()
			if cc >= 10  and cc <20:
				color_array[i]= Color(0.13, 0.192, 0.516, 1.0)
			elif cc >= 20:
					color_array[i]= Color(0.434, 0.076, 0.137, 1.0)
			else:
				color_array[i]= Color(0.239, 0.545, 0.358, 1.0)
			bin_action_usec +=  Time.get_ticks_usec() - bin_t0
		if flow_on:
			if flowbin_dic.has(current_bin_id[i]):
				flowbin_dic[current_bin_id[i]] += 1
			else:
				flowbin_dic[current_bin_id[i]] = 1

	
	_jhead = j
	for i in temp_spawn_id:
		Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i],color_array[i],)
	if bin_on:
		var bin_t0 = Time.get_ticks_usec()
		for i in entity_count:
			update_bin_array(i)
		bin_update_usec =  Time.get_ticks_usec() - bin_t0
	
	if flow_on:
		flow_diffusion()


	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0
	

func run_simulation_multithread(delta, sim_speed):
	mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	gid = WorkerThreadPool.add_group_task(run_chunk_simulation, chunk_count, chunk_count, true)	
	var t0 := Time.get_ticks_usec()
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1
		Build_and_remove_pendings()
		getChunk_perf()

	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0

func run_simulation_multithread2(delta, sim_speed):
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
	



func run_chunk_simulation(chunk: int) -> void:
	var n := _jitter.size()
	var local_pending_spawn_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var from := chunk * chunk_size
	var to := mini(from + chunk_size, entity_count)
	var j := (from + total_time) % n
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
	for i in range(from, to):
		pi = position_array[i]
		ei = current_energy_array[i]
		diff = pi-mouse_target
		dist = diff.length()
		
		#homeostasis 
		current_energy_array[i] -= 0.5* 0.016 * 1

		
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
				position_array[i] += _jitter[j] 
				j += 1
				if j >= n:
					j = 0
				
			Action.DUPLICATE:
				local_pending_spawn_id.append(i)
				current_energy_array[i] -= 5
			
			Action.MOVE:
				dir =  diff.normalized()
				position_array[i] += dir * 2
		

	
	mutex.lock()
	for i in local_pending_spawn_id:
		pending_spawn_id.append(i)
	mutex.unlock()
	
	chunk_usec[chunk] = Time.get_ticks_usec() - t0
	chunk_tid[chunk] = OS.get_thread_caller_id()	

func doChunk(chunk: int) -> void:
	var sp := spA
	var x = 0
	var n := _jitter.size()
	var local_pending_spawn_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var from := chunk * chunk_size
	var to := mini(from + chunk_size, entity_count)
	
	#var amp := drift_speed * delta
	var j := (from + total_time) % n
	for i in range(from, to):
		current_energy_array[i] += (1-0.5) * 0.16 * 1 * active_alife_array[i]
		position_array[i] +=  _jitter[j] #* amp
		j+= 1
		if j>= n:
			j= 0
		#current_energy_array[i] -= 0.5 * 0.16 * 1 * active_alife_array[i]
		if current_energy_array[i] > 5:
			local_pending_spawn_id.append(i)		
			#Build_New_Life(pick_random_position(Vector3(5,0,5) + position_array[i]))
			current_energy_array[i] -= 5
	#_jhead = j

		#spA.update(self, i, 0.16, 1)

	mutex.lock()
	for i in local_pending_spawn_id:
		pending_spawn_id.append(i)
	mutex.unlock()
	
	chunk_usec[chunk] = Time.get_ticks_usec() - t0
	chunk_tid[chunk] = OS.get_thread_caller_id()	
	
	

	
	
	####HELPER FUNCTION

	
	
func Build_and_remove_pendings():

	for i in pending_spawn_id:
		Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i])
	
	setup()
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
		current_bin_id.append(get_binID(pos,bin_size))
		update_bin_array(i)
		entity_count += 1


		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = 1
		position_array[i] = pos
		current_action[i] = 0
		species_id[i] = sp
		color_array[i]=col
		current_bin_id[i] = get_binID(pos,bin_size)
		update_bin_array(i)

	active_entity_count += 1
	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):
	free_indices.append(i)
	active_entity_count -= 1
	pending_multimesh_erase_id.append(i)

func pick_random_position(rangee: Vector3)-> Vector3: # should be 3
	var x = randf_range(-rangee.x,rangee.x)
	var z = randf_range(-rangee.z,rangee.z)
	var y = randf_range(-rangee.y,rangee.y)

	return Vector3(x,y,z)


####BIN FUNCTION
func get_binID(p : Vector3, binS : float) -> Vector3i:	
	#var array_size = World_Size/tile_size
	return Vector3i(floori(p.x / binS), floori(p.y / binS), floori(p.z / binS))

	#return int(pos.x + array_size.x * (pos.y + array_size.y * pos.z))
	
func update_bin_array(i):
	var bin_id := get_binID(position_array[i], bin_size)
	if current_bin_id[i] == bin_id:
		return
	if not bin_ids_array.has(bin_id):
		bin_ids_array[bin_id] = []
	bin_ids_array[bin_id].append(i)
	if bin_ids_array.has(current_bin_id[i]):
		bin_ids_array[current_bin_id[i]].erase(i)
	current_bin_id[i] = bin_id

func flow_diffusion():
	pass


'func get_index_in_bin_around(bin_array,i,radius):
	var bin_index = binID_array[i]
	var result : PackedInt32Array
	var GRID_WIDTH: int =  int(World.World_Size.x/ World.bin_size.x)
	var GRID_HEIGHT: int =  int(World.World_Size.z/ World.bin_size.z)

	var row = bin_index / GRID_WIDTH
	var col = bin_index % GRID_WIDTH
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nx = col + dx
			var ny = row + dy
			# Edge clamp — skip cells outside grid bounds
			if nx < 0 or nx >= GRID_WIDTH:
				continue
			if ny < 0 or ny >= GRID_HEIGHT:
				continue

			var neighbor_bin = ny * GRID_WIDTH + nx

			# Append all agent indices stored in that bin
			if bin_array[neighbor_bin]:
				var agents_in_bin: PackedInt32Array = bin_array[neighbor_bin]
				for agent_idx in agents_in_bin:
					result.append(agent_idx)
	return result'
'func get_real_current_bin(i):
	var w_pos = World.get_PositionInGrid(position_array[i],World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)	
	return new_bin_ID'

'func put_in_world_bin(i):
	var bin_ID = binID_array[i]
	var w_pos = World.get_PositionInGrid(position_array[i],World.bin_size)
	#var w_pos = World.get_PositionInGrid(g.position,World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	if new_bin_ID < 0 or new_bin_ID >= World.bin_array.size():
		#print("life out of world")
		remove_from_world_bin(i)
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

	#binID_array[i] = new_bin_ID'

'func remove_from_world_bin(i):

	if binID_array[i] >= 0:
		if World.bin_array[binID_array[i]].has(i):
			World.bin_array[binID_array[i]].erase(i)
			#World.bin_sum_array[Species_array[i]][binID_array[i]] -= 1
			sum_species_world_array[Species_array[i]][binID_array[i]] -= 1
			#field_world_array[Species_array[i]][binID_array[i]] -= 1
			binID_array[i] = -1'
