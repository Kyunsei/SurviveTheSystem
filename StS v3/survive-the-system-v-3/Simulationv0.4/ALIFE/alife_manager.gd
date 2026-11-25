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
var maxLife = 70000# 0#80000 #0 # 0
var total_time := 0.0


#cross reference---------
@export var world: WorldManager
@export var sim_manager : SimulationManager
#@export var renderer : AlifeRendererManager 


#Alife Section---------
var codex : ALIFE_CODEX

var species_array : Array[ALIFE] 
var global_position_array : PackedVector3Array
var global_species_offset:PackedInt32Array
var global_active : PackedInt32Array    #collect index and status of all
var global_entity_count := 0
var global_active_entity_count := 0 #track number only


#contactGRID
var cell_size := Vector3(5,20,5)
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

#FIELD GRID
var field_cell_size := Vector3(20,20,20)
#other var are stored in species 

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
	codex =ALIFE_CODEX.new()
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

func run_simulation(dt: float, sim_speed: float):
	
	var t0:= Time.get_ticks_usec()
	build_grid(global_position_array, global_active)
	var t1:= Time.get_ticks_usec()

	start_simulation(dt,sim_speed)
	var t2:= Time.get_ticks_usec()

	wait_simulation()
	var t3:= Time.get_ticks_usec()
	update_alife()
	var t4:= Time.get_ticks_usec()
	#print("build: %f, start : %f, wait %f, update %f"  % [t1-t0,t2-t1,t3-t2,t4-t3])


func start_simulation(dt: float, sim_speed: float):
	#update 
	var m := get_viewport().get_mouse_position()
	var mouse := Vector3(m.x, 0.0, m.y)
	
	#COUNT NEW NUMBER OF ENTITY 
	#UPDATE BEFORE RUNING FOR EACH SPECIES 
	#TODO maybe move this 5 lines in new function for clarity
	global_entity_count = 0
	global_active_entity_count = 0

	for s in species_array:
		global_entity_count += s.entity_count
		global_active_entity_count += s.active_entity_count

		s.mouse_target =  mouse
		s.build_field() #TODO call in thread?
	

	#setup thread/chunk/jobs
	jobs.clear()
	chunk_size = compute_chunk(global_entity_count) #need full entity count to work
	for s in species_array:
		var local_id:= 0
		var n: int = s.entity_count
		for start in range(0, n, chunk_size):
			jobs.append([s, start, mini(start + chunk_size, n),local_id, dt, sim_speed])
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
	
	update_carried()
	
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

func Store_all_alife():
	for sp in species_array:
		for i in sp.entity_count:
			sp.Stock_Life(i)

func update_alife_position_to_world_settings(ratio: Vector3):
		#return
	#update world size and grid size to new value
	#var c_speed = sim_manager.simulation_speed
	#sim_manager.simulation_speed = 0
	#wait_simulation()
	#await get_tree().create_timer(1.0).timeout  #dirty fix? the issue is that if the grid is updated during a thra
	#Store_all_alife()

	for sp in species_array:
		for i in sp.position_array.size():
			sp.position_array[i] = sp.position_array[i]*ratio

	init_GRID(world.size)
	#Release_all_alife()
	#sim_manager.simulation_speed = c_speed





func Release_all_alife():

	for sp in species_array:
		for i in sp.entity_count:
			sp.Release_Life(i)

#Species generation-------------------------------------------------------------------------------------------


func init_default_species(worldd:WorldManager,alifem:AlifeManager):	
	init_species_from_codex(worldd,alifem)
	
	SpawnRandomAlife(0,30000) #GRASS
	SpawnRandomAlife(1,10) #TREE
	SpawnRandomAlife(2,1000) #clovermoss
	#SpawnRandomAlife(3,10) #glowberry
	#SpawnRandomAlife(4,3) #spikyflower
	SpawnRandomAlife(5,30) #bugsheep 
	SpawnRandomAlife(6,1) #spidercrab



func init_species_from_codex(worldd:WorldManager,alifem:AlifeManager):
	species_array = []
	for sp in codex.species_list:
		sp.init(worldd,alifem)
		sp.species_id = species_array.size()
		species_array.append(sp)



func SpawnRandomAlife(alifeID : int, nb:int):
	var Alife := species_array[alifeID]
	for n in nb:# 100:
		var pos :Vector3= Alife.pick_random_position(Vector3(world.size.x/2,0,world.size.z/2),
											Vector3(world.size.x/2,0,world.size.z/2))
		#var energy := randf_range(0,5)
		Alife.Build_New_Life(pos)


#Contact GRID-------------------------------------------------------------------------------------------


		

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
	
func set_field_cell(key: String, value:float):
	var c_speed :float= sim_manager.simulation_speed
	sim_manager.set_simulation_speed(0)
	wait_simulation()
	match key:
		"x":
			field_cell_size.x = value
		"y":
			field_cell_size.y = value
		"z":
			field_cell_size.z = value

	for sp in species_array:
		sp._init_field_grid()
	sim_manager.set_simulation_speed(c_speed)

## Local index -> global id
func g_id(sp, i: int) -> int:
	return global_species_offset[species_array.find(sp)] + i


## Global id -> [species, local index]
func split_id(id: int) -> Array:
	var s :=  global_species_offset.bsearch(id, false) - 1
	return [ species_array[s], id -  global_species_offset[s]]

	

const ACTIVE := 1
const HELD := 2
const FLYING := 4

var carriers: Array[int] = []                    # global ids of agents carrying something


func pick_up(c_sp, c: int, i_sp, i: int) -> bool:
	#c = carrier
	if c_sp.holding[c] != -1 or i_sp.active_alife_array[i] != ACTIVE:
		return false     
								# hands full, or item not free in the world
	c_sp.holding[c] = g_id(i_sp, i)
	i_sp.held_by[i] = g_id(c_sp, c)
	i_sp.Stock_Life(i)
	#i_sp.active_alife_array[i] = HELD                         # simulation stops moving / colliding it
	carriers.append(g_id(c_sp, c))
	return true


func drop(c_sp, c: int, at: Vector3) -> void:
	var item: int = c_sp.holding[c]
	if item == -1:
		return
	var t := split_id(item)
	t[0].held_by[t[1]] = -1
	t[0].Release_Life(t[1])
	#t[0].active_alife_array[t[1]] = ACTIVE
	t[0].position_array[t[1]] = at
	c_sp.holding[c] = -1
	carriers.erase(g_id(c_sp, c))


## Call from Remove_Life and on death
func unlink(sp, i: int) -> void:
	if sp.holding[i] != -1:                      # I carried something: it falls here
		drop(sp, i, sp.position_array[i])
	var c: int = sp.held_by[i]
	if c != -1:                                  # I was carried: free my carrier's hands
		var t := split_id(c)
		t[0].holding[t[1]] = -1
		carriers.erase(c)
		sp.held_by[i] = -1


## Once per tick, AFTER the movement pass
func update_carried() -> void:
	for c in carriers:
		var t := split_id(c)
		var item := split_id(t[0].holding[t[1]])
		item[0].position_array[item[1]] = carry_position(t[0], t[1])


## In front of the carrier (its movement direction), at half its height
func carry_position(sp, i: int) -> Vector3:
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var h := maxf(q.y * sp.current_size[i], 0.2)
	var v: Vector3 = sp.current_velocity[i]
	v.y = 0.0
	var fwd := v.normalized() if v.length_squared() > 1e-6 else Vector3.FORWARD
	var p: Vector3 = sp.position_array[i] + fwd * 0.5 * h + Vector3.UP * 0.5 * h
	return WorldWrap.wrap_into(p)
	
	
## Let go of the carried item without putting it back in the world (throws).
## Returns [species, local index] of the item, or [] if the hands were empty.
func release_flying(c_sp, c: int) -> Array:
	var t := _let_go(c_sp, c)
	if not t.is_empty():
		t[0].active_alife_array[t[1]] = FLYING
	return t


## A thrown item touches the ground: back in the world.
func land(sp, i: int, at: Vector3) -> void:
	sp.active_alife_array[i] = ACTIVE
	sp.position_array[i] = at


func _let_go(c_sp, c: int) -> Array:
	var item: int = c_sp.holding[c]
	if item == -1:
		return []
	var t := split_id(item)
	t[0].held_by[t[1]] = -1
	c_sp.holding[c] = -1
	carriers.erase(g_id(c_sp, c))
	return t
