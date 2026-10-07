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

var current_worldpos_cell_id : PackedInt32Array

#### Duplicate
var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array
var pending_update_id: PackedInt32Array #check if in use


##RENDERING
var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array
var pending_multimesh_update_id : PackedInt32Array #check if in use

var renderer2D : AlifeRenderer2D
var renderer3D : AlifeRenderer3D
var rend_data : AlifeRenderingData

'var gid_r : int
var rendering_data : PackedFloat32Array
var r_data_per_chunk : Array[PackedFloat32Array] = []
var writting_rendering_buffer_usec:= 0.0'

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


var photo_range := 0

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
var photo_rate_per_chunk : Array[PackedFloat32Array] = []

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
	current_worldpos_cell_id = []
	
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
	build_offsets()

	##Rendering
	#rend_data = AlifeRenderingData.new()
	#rendering_buffer.resize(rendering.multimesh.instance_count * STRIDE)




	
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
	photo_rate_per_chunk.resize(n)
	#REndering
	#r_data_per_chunk.resize(n)
	for i in n:
		spawn_per_chunk[i] = []   # clear the previous frame's results
		remove_per_chunk[i] = []
		photo_rate_per_chunk[i] = []
		#r_data_per_chunk[i] = []
	


func run_chunk_simulation( start: int, end: int,local_id:int, dt: float) -> void:
	dt = 0.16 * 1 #TODO
	var dup_on := alifemanager.duplicate_on
	var homeo_on := alifemanager.homeostasis_on
	#var visu_on := alifemanager.visualisation_on
	var photo_on := alifemanager.photosynthesis_on
	var remove_on := alifemanager.remove_on
	var grow_on := alifemanager.grow_on
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	
	if !photo_on:
		for i in range(start, end):
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue	
			var _energy:= current_energy_array[i]
			if _energy < 5:		
				current_energy_array[i] += (1) * dt											
	if photo_on:
		var global_photo_rate := alifemanager.current_global_photosynthesis_rate
		var sun_grid := world.SUN_GRID 
		var photo_rate := 1.0
		for i in range(start, end):
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue		
			var _energy:= current_energy_array[i]
			if _energy < 5:
				var sun_c := current_worldpos_cell_id[i]
				#var total := global_photo_rate[sun_c]
				var r:= photo_range
				var total := 0.0
				var ry := 0
				if r == 0:
					var d:= global_photo_rate[sun_c]
					current_energy_array[i] += ( sun_grid[sun_c] * photo_rate *  dt) /   maxf(d, photo_rate) 
					
				else:			
					for off in offsets[r * (RY_MAX + 1) + ry]:
							var cc := sun_c + off
							if cc >= global_photo_rate.size():
								continue
							var d := global_photo_rate[cc]
							if d > 1e-6:
								total += world.SUN_GRID[cc] * photo_rate/ maxf(d, photo_rate)  	
					current_energy_array[i] += total * dt
					
	if homeo_on:
		var side := 2 * photo_range + 1 #not account of y dimension
		for i in range(start, end):
			
			current_energy_array[i] += -0.5  * dt  - (side * side - side) *dt #* active_alife_array[i]
			if current_energy_array[i] < 0 :
				alive_array[i] = 0
		#photo_rate_per_chunk[local_id] = local_photo_rate
			

				
	if grow_on:	
		for i in range(start, end):
			var ei:= current_energy_array[i]
			var cls := current_life_state[i]
			current_age[i] += 1
			if cls <3:
				if ei > 3:
					current_life_state[i] += 1
					current_energy_array[i] -= 3
					current_size[i]+= growth_rate
					current_biomass[i] += 2
			#current_age[i]+=1
	if dup_on:
		for i in range(start, end):
			var _energy:= current_energy_array[i]
			if _energy >= 5:
				local_pending_spawn_id.append(i)
				_energy -= 5
			current_energy_array[i] = _energy

		spawn_per_chunk[local_id] = local_pending_spawn_id
	if remove_on:
		for i in range(start, end):
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				local_pending_remove_id.append(i)
				
		remove_per_chunk[local_id] = local_pending_remove_id
	
	


####################RENDERING#################################################
################################################################################


func write_rendering_buffer_in_chunk(start: int, end: int) -> void:
	var visu_on := alifemanager.visualisation_on #Can be set before probably
	var r_data:= rend_data.data
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
			r_data[o + 2] = active_alife_array[i]
			r_data[o + 3] = alive_array[i]
		#r_data_per_chunk[local_id] = r_data

'func update_renderer():
	#for c in r_data_per_chunk.size():
	#	rendering_data.append_array(r_data_per_chunk[c]) #NOT IN GOOD ORDER?? yes becuas elocal ID?
	#renderer.data = rendering_data
	renderer2D.upload(entity_count)
	#rendering_data.clear()'
	
	

##########################################################################

	
func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
	
	var d_range:= alifemanager.duplication_range
	for i in pending_spawn_id:
		Build_New_Life(pick_random_position(Vector3(d_range,0,d_range)) + position_array[i],0.0, color_array[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	



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
		current_worldpos_cell_id.append(get_world_cell_id(pos,world))
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
		current_worldpos_cell_id[i] = get_world_cell_id(pos,world)
		#current_bin_id[i] = get_binID(pos,bin_size,world.size)
		#update_bin_array(i)
		current_life_state[i]=0
		current_biomass[i]=0
		current_age[i]=0
		current_size[i]=1.0

	active_entity_count += 1
	if alifemanager.photosynthesis_on:
			var r := photo_range
			var c := current_worldpos_cell_id[i]
			stamp(c,r,0,1.0)
	
	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 0
	free_indices.append(i)
	active_entity_count -= 1
	
	if alifemanager.photosynthesis_on:
			var r := photo_range
			var c := current_worldpos_cell_id[i]
			stamp(c,r,0,-1.0)
	
	
	pending_multimesh_erase_id.append(i)


##########################################################################################
####SUN/GRID MANAGEMENT
##########################################################################################

func stamp(c: int, r: int, ry: int, w: float) -> void:
	for off in offsets[r * (RY_MAX + 1) + ry]:
		if c+ off >= alifemanager.current_global_photosynthesis_rate.size():
			continue
		alifemanager.current_global_photosynthesis_rate[c + off] += w


func stamp2(c: int, r: int, w: float, ry: int = -1) -> void:
	if ry < 0:
		#ry = r  # cube by default; pass ry = 0 for a flat square on one level
		ry = 0
	var W := world.SUN_GRID_W
	var H := world.SUN_GRID_H
	var D := world.SUN_GRID_D
	var plane := W * H

	# decode the central cell
	var cx := c % W
	var cy := (c / W) % H
	var cz := c / plane

	# clamp the box to the grid
	var x0 := maxi(cx - r, 0)
	var x1 := mini(cx + r, W - 1)
	var y0 := maxi(cy - ry, 0)
	var y1 := mini(cy + ry, H - 1)
	var z0 := maxi(cz - r, 0)
	var z1 := mini(cz + r, D - 1)

	for z in range(z0, z1 + 1):
		var zoff := z * plane
		for y in range(y0, y1 + 1):
			var row := zoff + y * W
			for x in range(x0, x1 + 1):
				
				alifemanager.current_global_photosynthesis_rate[row + x] += w

func get_world_cell_id(pos: Vector3,worldd:World)-> int :
		var inv := Vector3.ONE / worldd.SUN_cell_size   # (1/x, 1/y, 1/z)
		var p := (pos - worldd.bin_origin) * inv
		var cx := clampi(roundi(p.x), 0, worldd.SUN_GRID_W - 1)
		var cy := clampi(roundi(p.y), 0, worldd.SUN_GRID_H - 1)
		var cz := clampi(roundi(p.z), 0, worldd.SUN_GRID_D - 1)
		var c := cx + worldd.SUN_GRID_W * (cy + worldd.SUN_GRID_H * cz)   # inline, no second division
		return c
		
func collect(c: int, r: int, ry: int, w: float) -> float:
	var total := 0.0
	for off in offsets[r * (RY_MAX + 1) + ry]:
			var cc := c + off
			var d := alifemanager.current_global_photosynthesis_rate[cc]
			if d > 1e-6:
				total += world.SUN_GRID[cc] * w / d
	return total		
		
		
const R_MAX := 3
const RY_MAX := 3
var offsets: Array[PackedInt32Array] = []   # index = r * (RY_MAX + 1) + ry

func build_offsets() -> void:
	print(world)
	var W := world.SUN_GRID_W
	var H := world.SUN_GRID_H
	var D := world.SUN_GRID_D
	var PLANE := W * H

	offsets.resize((R_MAX + 1) * (RY_MAX + 1))
	for r in R_MAX + 1:
		for ry in RY_MAX + 1:
			var list := PackedInt32Array()
			for dz in range(-r, r + 1):
				for dy in range(-ry, ry + 1):
					for dx in range(-r, r + 1):
						list.append(dx + dy * W + dz* PLANE)
			offsets[r * (RY_MAX + 1) + ry] = list		
		
		
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
