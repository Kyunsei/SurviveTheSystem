class_name TESTDNA
extends RefCounted



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
#var time := 0.0
var dt := 0.0#.32
var total_time := 0
#var time_counter := 1

#cross reference
var world: World
var alife_GRID : PackedInt32Array
var alifemanager : AlifeManager

#entity managemnt
var free_indices : Array =[]
var entity_count : int
var active_entity_count : int

#ECS STATS
var position_array : PackedVector3Array
var current_energy_array : PackedFloat64Array
var active_alife_array : PackedInt32Array  #To reuse some 
var alive_array : PackedInt32Array

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
var pending_update_id: PackedInt32Array #check if in use


##RENDERING
var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array
var pending_multimesh_update_id : PackedInt32Array #check if in use

var renderer : AlifeRenderer2D
var gid_r : int
var rendering_data : PackedFloat32Array
var r_data_per_chunk : Array[PackedFloat32Array] = []
var writting_rendering_buffer_usec:= 0.0

#var rendering_buffer : PackedFloat32Array
#const STRIDE := 12  #buffer + colors

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

'var bin_on = false
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
var sorted_pos := PackedVector3Array()'

###SpeciesParameters
var growth_rate := 0.25
var colour := Color(0.193, 0.404, 0.283, 1.0)
const CORPSE_COLOR := Color(0.488, 0.077, 0.15, 0.2)


#Randomness
const JITTER_COUNT := 4096
var _jitter: PackedVector3Array
var _jhead: int = 0

###multithread things
var gid := -1
#var nThread_max := 8#1  #store on alifemnager
var chunk_count: int
var chunk_size: int
var mutex := Mutex.new()
var spawn_per_chunk : Array[PackedInt32Array] = []
var remove_per_chunk : Array[PackedInt32Array] = []
var update_per_chunk : Array[PackedInt32Array] = [] #NEED TO check if needed


#Perf Measurmnt #TODO
var chunk_usec: PackedInt64Array
var chunk_tid: PackedInt64Array
var	total_thread_usec := 0.
var thread_usec := 0.
var	multithread_efficiency := 0.
var	nThreadused := 0

var main_usec = 0
var uai_usec = 0
var bin_screen_usec = 0
var bin_action_usec = 0
var bin_update_usec = 0


#############################################################################################
##############################################################################################


func init(worldd,alifm):
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))

	
	entity_count = 0
	active_entity_count =0
	free_indices = [] 
	
	#alife 
	position_array = [] 
	current_energy_array = [] 
	active_alife_array = []   #To reuse some 
	alive_array = []
	
	pending_multimesh_drawn_id = []
	pending_multimesh_update_id = []
	pending_multimesh_erase_id = []
	
	pending_spawn_id = []
	pending_update_id = []
	pending_remove_id = []
	
	color_array = []	
	current_life_state= []
	current_biomass= []
	current_age= []
	current_size= []
		
	
	#AI
	action_scores.resize(ACTION_COUNT)
	current_action = []
	
	#Bin??
	#TODO
	
	##WORLD
	world = worldd
	alifemanager = alifm
	#init_GRID(world.size)
	
	##Rendering
	init_renderer()
	#rendering_buffer.resize(rendering.multimesh.instance_count * STRIDE)

func init_renderer():
	renderer = AlifeRenderer2D.new()
#	renderer.init()
	renderer.setup( 0, world.size, colour)
	alifemanager.add_child.call_deferred(renderer)
	rendering_data.clear()
	#r.setup(s.capacity, 10000.0, s.colour)


	
	#rendering = RenderingALife2D.new()
	#rendering.init(self,world)
	#multimesh.species = self
	#species_array[s].rendering = mm









####MULTITHREAD
func set_chunk(n:int):
	#for perf tracking 
	chunk_usec.resize(n)
	chunk_tid.resize(n)	
	#reshape temp chunk array
	spawn_per_chunk.resize(n)
	remove_per_chunk.resize(n)
	update_per_chunk.resize(n)	
	#REndering
	r_data_per_chunk.resize(n)
	for i in n:
		spawn_per_chunk[i] = []   # clear the previous frame's results
		remove_per_chunk[i] = []
		r_data_per_chunk[i] = []
	

func run_chunk_simulation( start: int, end: int,local_id:int, dt: float) -> void:
	var dup_on := alifemanager.duplicate_on
	var visu_on := alifemanager.visualisation_on
	var local_pending_spawn_id : PackedInt32Array

	if true:
		for i in range(start, end):
			var _energy:= current_energy_array[i]
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue			
			#if !_sun_on:
			_energy += (1) * 0.16 * 1 #* active_alife_array[i]	
			_energy += -0.5 *  0.16 * 1 #* active_alife_array[i]
			if _energy >= 5:
				if dup_on:
					local_pending_spawn_id.append(i)
				_energy -= 5
			if _energy < 0 :
				alive_array[i] = 0

			current_energy_array[i] = _energy

	if dup_on:
		spawn_per_chunk[local_id] = local_pending_spawn_id
	
	
	
func run_chunk_simulation2(chunk: int) -> void:
	var _sun_on := world.SUN_on
	var n := _jitter.size()
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id : PackedInt32Array
	var t0 := Time.get_ticks_usec()
	var from := chunk * chunk_size
	var to := mini(from + chunk_size, entity_count)
	var j := (from + total_time) % n

	'if bin_on:
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
			#bin_action_usec +=  Time.get_ticks_usec() - bin_t1'

	'if AI_on:
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
			position_array[i] = pi.clamp(Vector3.ZERO, bounds_max)'
			
			
	#else:
	if true:
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
	'if remove_on:
		for i in range(from, to):
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				local_pending_remove_id.append(i)
				
		remove_per_chunk[chunk] = local_pending_remove_id'	
		
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

''
####################RENDERING#################################################
################################################################################


func write_rendering_buffer_in_chunk(start: int, end: int,local_id:int) -> void:
	var visu_on := alifemanager.visualisation_on #Can be set before probably
	var r_data:= renderer.data # PackedFloat32Array
	#r_data.resize((end-start)*4)
	if visu_on:
		#var r_data:= renderer.data
		for i in range(start, end):
			var p:= position_array[i]
			var o := i * 4 #need to match STRIDE of renderer
			'if renderer.data[o + 3] != active_alife_array[i]:
				continue'
			r_data[o]     = p.x #* dt     # x
			r_data[o + 1] = p.z # * dt     # y
		#r_data_per_chunk[local_id] = r_data

func update_renderer():
	#for c in r_data_per_chunk.size():
	#	rendering_data.append_array(r_data_per_chunk[c]) #NOT IN GOOD ORDER?? yes becuas elocal ID?
	#renderer.data = rendering_data
	renderer.upload(entity_count)
	#rendering_data.clear()
	
	

##########################################################################

	
func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
		
	for i in pending_spawn_id:
		Build_New_Life(pick_random_position(Vector3(15,0,15)) + position_array[i],0.0, color_array[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	

	#renderer.ensure_capacity(entity_count)

	pending_spawn_id.clear()
	pending_remove_id.clear()


func Build_New_Life(pos: Vector3, e: float, col := Color(0.159, 0.555, 0.215, 1.0)):

	if alifemanager.entity_count >= alifemanager.maxLife and alifemanager.maxLife>0:
		return
	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(1)
		position_array.append(pos)
		current_action.append(0)
		#species_id.append(sp)
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
		#species_id[i] = sp
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
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 0
	free_indices.append(i)
	active_entity_count -= 1
	pending_multimesh_erase_id.append(i)





##########################################################################################
####ARRAY MANAGEMENT
##########################################################################################



func find_free_index():
	var i : int
	if free_indices.size()> 0:
		i = free_indices.pop_back()
	else:
		i = entity_count
	return i 	



func pick_random_position(rangee: Vector3)-> Vector3: # should be 3
	var x = randf_range(-rangee.x,rangee.x)
	var z = randf_range(-rangee.z,rangee.z)
	var y = randf_range(-rangee.y,rangee.y)

	return Vector3(x,y,z)






#####################################OLD BELOW##############################
#############################################################################

func _ready() -> void:
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))



'func init_GRID(world_size):
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	GRID_WD = GRID_W * GRID_D
	GRID_WH = GRID_W * GRID_H
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	write_pos.resize(NUM_CELLS)'






	
	

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
####BIN FUNCTION
##########################################################################################

'func get_binID(p : Vector3, binS : float) -> Vector3i:	
	#var array_size = World_Size/tile_size
	return Vector3i(floori(p.x / binS), floori(p.y / binS), floori(p.z / binS))'

	#return int(pos.x + array_size.x * (pos.y + array_size.y * pos.z))


'func cell_id(cx: int, cy: int, cz: int) -> int:
	#USE here grid coordinate
	return cx + GRID_W * (cy + GRID_H * cz)'





'func build_grid(position_array: PackedVector3Array) -> void:
	var n := position_array.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	var inv := 1.0 / cell_size

	# 1. Count particles per cell
	for i in n:
		var p := (position_array[i] - bin_origin) * inv
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
		sorted_pos[w] = position_array[i]
		write_pos[c] = w + 1'
	
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
