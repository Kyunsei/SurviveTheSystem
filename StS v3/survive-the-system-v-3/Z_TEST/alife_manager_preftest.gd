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





#### Duplicate
var duplicate_on := true
var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array


##RENDERING
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

### ALIFE GRID - agent - agent close detection

#old?
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


#############################################################################################
##############################################################################################

func _ready() -> void:
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))

func init(world):
	#time
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
	#bin_ids_array.clear()
	LifeBin_array.clear()
	#bin_ids_array.resize(10) #TODO
	#current_bin_id = []
	#FLOW not yet there
	flowbin_dic.clear()	
	
	init_GRID(world.size)


func init_GRID(world_size):
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	GRID_WD = GRID_W * GRID_D
	GRID_WH = GRID_W * GRID_H
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	write_pos.resize(NUM_CELLS)


func setup():  #FOR multhithread redimension
	@warning_ignore("integer_division")
	chunk_size = (entity_count + chunk_count - 1) / chunk_count  # ceil
	chunk_usec.resize(chunk_count)
	chunk_tid.resize(chunk_count)

func validate_grid(position_array: PackedVector3Array) -> void:
	var n := position_array.size()
	if cell_start[NUM_CELLS] != n:
		push_error("prefix sum wrong: last = %d, n = %d" % [cell_start[NUM_CELLS], n])

	# every cell's range should hold only particles of that cell
	for c in NUM_CELLS:
		for s in range(cell_start[c], cell_start[c + 1]):
			var i := cell_items[s]
			if current_cell_id[i] != c:
				push_error("particle %d stored in cell %d but belongs to %d" % [i, c, current_cell_id[i]])
			if sorted_pos[s] != position_array[i]:
				push_error("sorted_pos out of sync at %d" % s)

	# grid count vs brute force for particle 0
	var p := position_array[0]
	var brute := 0
	for k in n:
		if p.distance_squared_to(position_array[k]) < 64:
			brute += 1
	print("brute force count for particle 0: ", brute)	
	var c0 := current_cell_id[0]
	print("particle_cell[0] = ", c0, "   current_cell_id[0] = ", current_cell_id[0])
	print("own cell range: ", cell_start[c0], " -> ", cell_start[c0 + 1])

	var cx := c0 % GRID_W
	var cy := (c0 / GRID_W) % GRID_H
	var cz := c0 / GRID_WH
	print("decoded: ", Vector3i(cx, cy, cz),
		"   re-encoded: ", cx + GRID_W * (cy + GRID_H * cz))
	print("GRID_WH = ", GRID_WH, "   GRID_W * GRID_H = ", GRID_W * GRID_H)
	print("GRID: ", GRID_W, " x ", GRID_H, " x ", GRID_D, "   NUM_CELLS = ", NUM_CELLS)


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
	
	#AI
	mouse_target =  Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	var full := 0.0
	var hungry := 0.0
	var target_far := 0.0
	var target_close  := 0.0
	var best_action := 0
	
	var bin_t0 = Time.get_ticks_usec()
	if bin_on:
		build_grid(position_array)
	bin_update_usec =  Time.get_ticks_usec() - bin_t0
	
	
	for i in active_alife_array.size():
		
		#TODO bin things
		if bin_on:
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
					if duplicate_on:
						temp_spawn_id.append(i)
					current_energy_array[i] -= 5
				
				Action.MOVE:
					dir = diff.normalized() * sp_Action_weight[species_id[i]]
					position_array[i] += dir * 2
			uai_usec +=  Time.get_ticks_usec() - uai_t0
		else:
			current_energy_array[i] += (1) * delta * sim_speed #* active_alife_array[i]
			if current_energy_array[i] >= 5:
				if duplicate_on:
					temp_spawn_id.append(i)
				current_energy_array[i] -= 5
			
				
		current_energy_array[i] += -0.5 * delta * sim_speed #* active_alife_array[i]
				#WRAP or CLAMP
		#if !wrap : 
		position_array[i].x = clamp(position_array[i].x, 0.0 , GRID_W*cell_size)
		position_array[i].y = clamp(position_array[i].y, 0.0 , GRID_H*cell_size)
		position_array[i].z = clamp(position_array[i].z, 0.0 , GRID_D*cell_size)

		
		
		if flow_on:
			pass
			'if flowbin_dic.has(current_bin_id[i]):
				flowbin_dic[current_bin_id[i]] += 1
			else:
				flowbin_dic[current_bin_id[i]] = 1'

	

	
	_jhead = j
	if duplicate_on:
		for i in temp_spawn_id:
			Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, species_id[i],color_array[i],)

	
	if flow_on:
		flow_diffusion()


	time += delta
	total_time += 1
	main_usec = Time.get_ticks_usec() - t0
	

func run_simulation_multithread(delta, sim_speed):
	var bin_t0 = Time.get_ticks_usec()
	if bin_on:
		build_grid(position_array)
	bin_update_usec =  Time.get_ticks_usec() - bin_t0
	
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
'
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
	main_usec = Time.get_ticks_usec() - t0'
	



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
		if bin_on:
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
					if duplicate_on:
						local_pending_spawn_id.append(i)
					current_energy_array[i] -= 5
				
				Action.MOVE:
					dir =  diff.normalized()
					position_array[i] += dir * 2
		else:
			current_energy_array[i] += (1-0.5) * 0.16 * 1 * active_alife_array[i]
			if current_energy_array[i] > 5:
				if duplicate_on:
					local_pending_spawn_id.append(i)		
				current_energy_array[i] -= 5	
		#WRAP or CLAMP
		#if !wrap : 
		position_array[i].x = clamp(position_array[i].x, 0.0 , GRID_W*cell_size)
		position_array[i].y = clamp(position_array[i].y, 0.0 , GRID_H*cell_size)
		position_array[i].z = clamp(position_array[i].z, 0.0 , GRID_D*cell_size)

	
	if duplicate_on:
		mutex.lock()
		for i in local_pending_spawn_id:
			pending_spawn_id.append(i)
		mutex.unlock()
		
	chunk_usec[chunk] = Time.get_ticks_usec() - t0
	chunk_tid[chunk] = OS.get_thread_caller_id()	
'
func doChunk(chunk: int) -> void:
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
	chunk_tid[chunk] = OS.get_thread_caller_id()'	
	
	

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
		#current_bin_id.append(get_binID(pos,bin_size,world.size))

		#update_bin_array(i)
		entity_count += 1


		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = 1
		position_array[i] = pos
		current_action[i] = 0
		species_id[i] = sp
		color_array[i]=col
		#current_bin_id[i] = get_binID(pos,bin_size,world.size)
		#update_bin_array(i)

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


func get_binID(p: Vector3, bin_size: float, world_size: Vector3) -> int:
	var dims := Vector3i((world_size / bin_size).ceil())
	var cx := clampi(floori(p.x / bin_size), 0, dims.x - 1)
	var cy := clampi(floori(p.y / bin_size), 0, dims.y - 1)
	var cz := clampi(floori(p.z / bin_size), 0, dims.z - 1)
	return cx + dims.x * (cy + dims.y * cz)



func build_grid(position_array: PackedVector3Array) -> void:
	var n := position_array.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	var inv := 1.0 / cell_size

	# 1. Count particles per cell
	for i in n:
		var p := (position_array[i] - bin_origin) * inv
		var cx := clampi(floori(p.x), 0, GRID_W - 1)
		var cy := clampi(floori(p.y), 0, GRID_H - 1)
		var cz := clampi(floori(p.z), 0, GRID_D - 1)
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
		sorted_pos[w] = position_array[i]
		write_pos[c] = w + 1
	
'func update_bin_array(i, world):
	var bin_id := get_binID(position_array[i], bin_size, world.size)
	if current_bin_id[i] == bin_id:
		return
	if not bin_ids_array.has(bin_id):
		bin_ids_array[bin_id] = []
	bin_ids_array[bin_id].append(i)
	if bin_ids_array.has(current_bin_id[i]):
		bin_ids_array[current_bin_id[i]].erase(i)
	current_bin_id[i] = bin_id'

'func update_bin_array(i):
	var bin_id := get_binID(position_array[i], bin_size, world_size)
	if current_bin_id[i] == bin_id:
		return
	if not LifeBin_array.has(bin_id):
		bin_ids_array[bin_id] = []
	bin_ids_array[bin_id].append(i)
	if bin_ids_array.has(current_bin_id[i]):
		bin_ids_array[current_bin_id[i]].erase(i)
	current_bin_id[i] = bin_id'


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
