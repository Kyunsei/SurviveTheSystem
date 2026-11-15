extends Node
class_name AlifeManager

#THIS SCRIPT MANAGE THE DIFFERENT ALIFE SPECIES and connect them together and
# with other simulation element [player/world/rendering]
#RUN ALL SPECIES HERE
#COLLECT GLOABL GRID HERE TOO

#TODO wait thread?
#TODO fix chunk number/order or make it random?
#TODO simulation time in threads?



#Simulation par---------
var maxLife = 0#80000 #0 # 0
var total_time := 0.0


#cross reference---------
@export var world: WorldManager
#@export var renderer : AlifeRendererManager 
var simulation_speed := 1


#Alife Section---------
var species_array : Array[ALIFE] 
var global_position_array : PackedVector3Array
var global_species_offset:PackedInt32Array
var global_active : PackedInt32Array   
var global_entity_count := 0

#contactGRID
var cell_size := Vector3(20,20,20)
var GRID_W :int          # cells along x
var GRID_H :int        # cells along y
var GRID_D :int       # cells along z
var NUM_CELLS := GRID_W * GRID_H * GRID_D

#PrefixSUM
var cell_start := PackedInt32Array()     # size NUM_CELLS + 1
var write_pos := PackedInt32Array()      # size NUM_CELLS (scratch)
var cell_items := PackedInt32Array()     # size = alife count
var current_cell_id := PackedInt32Array()  # size = alife count
var sorted_pos := PackedVector3Array()

#MULTITHREAD
var gid := -1
var jobs: Array = []     # each entry: [species, chunk_index]
var nThreads := 1
var chunk_size: int

#TODO adjust these number to see performance difference!
const MIN_CHUNK := 256      # never smaller: avoids overhead
const MAX_CHUNK := 8192     # never bigger: keeps balance
const JOBS_PER_THREAD := 4

#OTHER---------

var mouse_target : Vector3




#############################################################################################
##############################################################################################


#INIT part-------------------------------------------------------------------------------------------


func init():

	total_time = 0
	global_entity_count = 0
	global_position_array = []
	global_species_offset = []
	global_active = []
	init_GRID(world.size)
	init_default_species(world,self)
	


	
func init_GRID(world_size):
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	write_pos.resize(NUM_CELLS)


func compute_chunk(total:int) -> int:
	nThreads = OS.get_processor_count()
	#threads = clamp( nThread_max,1,OS.get_processor_count()) 
	@warning_ignore("integer_division")
	var chunk := total / (nThreads * JOBS_PER_THREAD)
	return clampi(chunk, MIN_CHUNK, MAX_CHUNK)
	

#main loop -------------------------------------------------------------------------------------------

func run_simulation(delta: float, sim_speed: float):	
	var t0:= Time.get_ticks_usec()
	build_grid(global_position_array, global_active)
	var t1:= Time.get_ticks_usec()

	start_simulation(delta,sim_speed)
	var t2:= Time.get_ticks_usec()

	wait_simulation()
	var t3:= Time.get_ticks_usec()

	update_alife()
	var t4:= Time.get_ticks_usec()

	print("build: %f, start : %f, wait %f, update %f"  % [t1-t0,t2-t1,t3-t2,t4-t3])


func start_simulation(delta: float, sim_speed: float):
	#update 
	var m := get_viewport().get_mouse_position()
	var mouse := Vector3(m.x, 0.0, m.y)
	
	#COUNT NEW NUMBER OF ENTITY 
	#UPDATE BEFORE RUNING FOR EACH SPECIES 
	#TODO maybe move this 5 lines in new function for clarity
	global_entity_count = 0
	for s in species_array:
		global_entity_count += s.entity_count
		s.mouse_target =  mouse
		s.build_field() #TODO call in thread?
	

	#setup thread/chunk/jobs
	jobs.clear()
	chunk_size = compute_chunk(global_entity_count) #need full entity count to work
	for s in species_array:
		var local_id:= 0
		var n: int = s.entity_count
		for start in range(0, n, chunk_size):
			jobs.append([s, start, mini(start + chunk_size, n),local_id, delta, sim_speed])
			local_id += 1
		s.set_chunk(local_id)
	
	#run working group	
	gid = -1	
	if jobs.size() > 0:
		gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), nThreads, true, "species_update")

#SEND JOBS TO DNA
func run_chunk(k: int) -> void:
	var job = jobs[k]
	job[0].run_chunk_simulation(job[1], job[2],job[3], job[4], job[5])

func wait_simulation() -> void:
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1


#UPDATE AFTER
func update_alife() -> void:
	#TODO optmisation possible if agent write themself in global instead of recomputing each frame? to check
	var species_count := species_array.size()
	global_species_offset.resize(species_count + 1)
	global_position_array.clear()
	global_active.clear()
	var total := 0
	for si in species_count:
		var sp: ALIFE = species_array[si] #TODO CHANGE TYPE HERE
		sp.Build_and_remove_pendings()

		assert(sp.position_array.size() == sp.entity_count)
		assert(sp.active_alife_array.size() == sp.entity_count)

		global_species_offset[si] = total
		global_position_array.append_array(sp.position_array)
		global_active.append_array(sp.active_alife_array)
		total += sp.entity_count

	global_species_offset[species_count] = total

#Species generation-------------------------------------------------------------------------------------------


func init_default_species(worldd:WorldManager,alifem:AlifeManager):
	var n_sp = ALIFE_GRASS.new()
	n_sp.init(worldd,alifem)
	species_array.append(n_sp)
	
	var start_quantity:= 500
	
	for n in start_quantity:
		var pos := n_sp.pick_random_position(Vector3(world.size.x/2,0,world.size.z/2),
											Vector3(world.size.x/2,0,world.size.z/2))
		var energy := randf_range(0,5)
		n_sp.Build_New_Life(pos,energy)




#Contact GRID-------------------------------------------------------------------------------------------

func build_grid2(position_arrayy: PackedVector3Array) -> void: #ADAPT TO GLOBAL POS ARRAY  #TODO move to world
	var n := position_arrayy.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	#var inv := 1.0 / cell_size
	var inv := Vector3.ONE / cell_size   # (1/x, 1/y, 1/z)

	# 1. Count particles per cell
	for i in n:
		var p := (position_arrayy[i]) * inv
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
		

func build_grid(positions: PackedVector3Array, active: PackedInt32Array) -> void:
	var n := positions.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)

	var inv := Vector3.ONE / cell_size
	var last_x := GRID_W - 1
	var last_z := GRID_D - 1

	# 1. Cell id + count per cell (inactive agents skipped)
	#Can be moved in multihtread
	for i in n:
		if active[i] == 0:
			current_cell_id[i] = -1
			continue
		var p := positions[i]
		var c :int = clampi(int(p.x * inv.x), 0, last_x) + GRID_W * clampi(int(p.z * inv.z), 0, last_z)		
		current_cell_id[i] = c
		cell_start[c + 1] += 1

	# 2. Prefix sum -> start offset of each cell
	for c in NUM_CELLS:
		cell_start[c + 1] += cell_start[c]
	write_pos = cell_start.slice(0, NUM_CELLS)   # one native copy

	# 3. Scatter into sorted order
	for i in n:
		var c := current_cell_id[i]
		if c < 0:
			continue
		var w := write_pos[c]
		cell_items[w] = i
		sorted_pos[w] = positions[i]
		write_pos[c] = w + 1
#Helper function-------------------------------------------------------------------------------------------

func set_contact_cell_size(new_size:Vector3):
	cell_size = new_size
	init_GRID(world.size)
	
	
	


	
