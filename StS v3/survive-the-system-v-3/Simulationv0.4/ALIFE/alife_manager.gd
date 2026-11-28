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
	init_species_from_codex(world,self)

	#init_default_species(world,self)
	


	
var _grid_dirty := true                     # grid must be rebuilt before the next use

func init_GRID(world_size):
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	_grid_dirty = true                       # new cell layout: old cell ids are meaningless
	write_pos.resize(NUM_CELLS)


func compute_chunk(total:int) -> int:
	nThreads = OS.get_processor_count()
	#threads = clamp( nThread_max,1,OS.get_processor_count()) 
	@warning_ignore("integer_division")
	var chunk := total / (nThreads * JOBS_PER_THREAD)
	return clampi(chunk, MIN_CHUNK, MAX_CHUNK)
	

#main loop -------------------------------------------------------------------------------------------
#
# Two ways to run a tick (SimulationManager.pipelined_tick picks one):
#   run_simulation()          start + wait in the same frame (the frame waits for the tick)
#   begin_tick() ... later finish_tick()   the tick runs on the worker threads while the
#                             main thread renders; it is finished on a later frame, once done.
# While a tick runs, the main thread must NOT write species arrays (spawn, remove, carry,
# positions...): put such work in when_free(callable), or in a between_ticks(delta) method
# of a node in the "between_ticks" group (called by SimulationManager when arrays are free).

## Set by SimulationManager: true when ticks run in the background (begin / finish).
var pipelined := false
var _free_queue: Array[Callable] = []

## True while a tick runs on the worker threads (species arrays are busy).
func tick_running() -> bool:
	return _stage != Stage.IDLE


## The running tick is done (or none is running): finish_tick() won't wait.
## Also moves the tick to its next stage when the current one is done (no waiting).
func tick_done() -> bool:
	while _stage != Stage.IDLE:
		if gid != -1 and not WorkerThreadPool.is_group_task_completed(gid):
			return false
		if _stage == Stage.CHUNKS:
			return true                          # finish_tick() collects it
		_next_stage()
	return true


## Runs `c` now if no tick is running, else right after the running tick is finished.
## Use it for anything that changes species arrays from the main thread.
func when_free(c: Callable) -> void:
	if tick_running():
		_free_queue.append(c)
	else:
		c.call()


## Starts a tick on the worker threads and returns at once (pipelined mode).
func begin_tick(delta: float, dt: float, sim_speed: float) -> void:
	if _grid_dirty:
		build_grid(global_position_array, global_active)
	_snapshot_walkers()
	start_simulation(delta, dt, sim_speed)


## Finishes the running tick: waits for it (no wait if tick_done()), the walk pass,
## spawns / removes, offsets and contact grid, then the queued when_free calls.
func finish_tick() -> void:
	wait_simulation()
	var t0 := Time.get_ticks_usec()
	_constrain_walkers()
	timings["walk"] = Time.get_ticks_usec() - t0
	update_alife()
	_drain_free_queue()
	_print_timings()


func _print_timings() -> void:
	if not print_timings and not collect_profile:
		return
	_timing_tick += 1
	var every := 15 if collect_profile else 60    # on screen: refreshed more often
	if _timing_tick % every != 0:
		return
	var parts := PackedStringArray()
	for k in timings:
		parts.append("%s %.1f" % [k, timings[k] / 1000.0])
	var stages := "tick ms:  " + "   ".join(parts)
	var species := _species_timings_text()
	profile_text = stages + "\n" + species
	if print_timings and _timing_tick % 60 == 0:
		print(stages)
		print(species)


## Per species: CPU time of its jobs this tick, summed over the threads (so the total can be
## more than the stage's wall time: 8 threads x 3 ms = 24 ms of work in a 3 ms stage).
##   chunks    its run_chunk_simulation        fields   cells + deposits + diffusion
func _species_timings_text() -> String:
	var n := species_array.size()
	var chunk_t := PackedInt64Array(); chunk_t.resize(n); chunk_t.fill(0)
	var field_t := PackedInt64Array(); field_t.resize(n); field_t.fill(0)
	var nfields := PackedInt32Array(); nfields.resize(n); nfields.fill(0)
	var index := {}
	for s in n:
		index[species_array[s]] = s
	for k in mini(jobs.size(), _chunk_us.size()):
		chunk_t[index[jobs[k][0]]] += _chunk_us[k]
	for s in mini(n, _fc_us.size()):
		field_t[s] += _fc_us[s]
	for k in mini(_field_jobs.size(), _dep_us.size()):
		var s: int = index[_field_jobs[k][0]]
		field_t[s] += _dep_us[k]
		if k < _deposit_ok.size() and _deposit_ok[k]:
			nfields[s] += 1
	for k in mini(_slice_jobs.size(), _slice_us.size()):
		field_t[index[_slice_jobs[k][0]]] += _slice_us[k]

	var order: Array = range(n)
	order.sort_custom(func(a, b): return chunk_t[a] + field_t[a] > chunk_t[b] + field_t[b])
	var total := 0
	for s in n:
		total += chunk_t[s] + field_t[s]
	var lines := PackedStringArray()
	for s in order:
		var sp: ALIFE = species_array[s]
		var t: int = chunk_t[s] + field_t[s]
		if t <= 0:
			continue
		lines.append("  %-14s %6.1f ms  %3d%%   chunks %6.1f   fields %6.1f (%d)   agents %d / %d" % [
				sp.species_name, t / 1000.0, roundi(100.0 * t / maxf(total, 1)),
				chunk_t[s] / 1000.0, field_t[s] / 1000.0, nfields[s],
				sp.active_entity_count, sp.entity_count])
	return "species (CPU ms, all threads):\n" + "\n".join(lines)


func _drain_free_queue() -> void:
	while not _free_queue.is_empty():
		var q := _free_queue.duplicate()
		_free_queue.clear()
		for c in q:
			if c.is_valid():
				c.call()


func run_simulation(delta:float, dt: float, sim_speed: float):
	
	var t0:= Time.get_ticks_usec()
	# The grid is rebuilt at the end of update_alife (same ids as the offsets).
	# Only rebuilt here if something invalidated it in between (grid resized...).
	if _grid_dirty:
		build_grid(global_position_array, global_active)
	var t1:= Time.get_ticks_usec()

	_snapshot_walkers()                      # where every walking agent was before this tick
	start_simulation(delta, dt,sim_speed)
	var t2:= Time.get_ticks_usec()

	wait_simulation()
	var tw := Time.get_ticks_usec()
	_constrain_walkers()                     # their moves, through the walkable area
	var t3:= Time.get_ticks_usec()
	timings["walk"] = t3 - tw
	update_alife()
	_drain_free_queue()
	var t4:= Time.get_ticks_usec()
	_print_timings()
	#print("build: %f, start : %f, wait %f, update %f"  % [t1-t0,t2-t1,t3-t2,t4-t3])


## A tick, in four stages on the worker threads:
##   FIELD_CELLS  each species: the field cell of its agents (fields_begin), in parallel
##   DEPOSIT      every field of every species: its agents' deposits (field_deposit)
##   DIFFUSE      every field, cut in ranges of cells: spread + fade (field_diffuse_slice)
##   CHUNKS       the species simulation, in chunks (run_chunk_simulation)
## One tick per frame: start_simulation runs them one after the other (waiting, but each in
## parallel). Pipelined: tick_done() starts the next stage when one is done, no waiting.
enum Stage { IDLE, FIELD_CELLS, DEPOSIT, DIFFUSE, CHUNKS }
var _stage := Stage.IDLE
var _tick_args: Array = []                       # [delta, dt, sim_speed] of the running tick
var _field_species: Array = []                   # species that build their fields this tick
var _field_jobs: Array = []                      # [species, field index]
var _deposit_ok: Array = []                      # per field job: something to diffuse
var _slice_jobs: Array = []                      # [species, field index, start, end]
const DIFFUSE_SLICE_MIN := 2048                  # cells per diffusion job, at least

## Timings of the last tick, in µs (see print_timings)
var timings := {}
@export var print_timings := false               # prints `timings` every 60 ticks
## Set by SimulationManager when its on-screen profile is shown: profile_text is filled.
var collect_profile := false
var profile_text := ""                           # the last timings, per stage and per species
var _timing_tick := 0
# Per job, its time in µs (each job writes only its own slot), summed per species after
var _chunk_us := PackedInt64Array()
var _fc_us := PackedInt64Array()
var _dep_us := PackedInt64Array()
var _slice_us := PackedInt64Array()
var _stage_t0 := 0


func start_simulation(delta:float,dt: float, sim_speed: float):
	var m := get_viewport().get_mouse_position()
	var mouse := Vector3(m.x, 0.0, m.y)

	#COUNT NEW NUMBER OF ENTITY 
	#UPDATE BEFORE RUNING FOR EACH SPECIES 
	global_entity_count = 0
	global_active_entity_count = 0

	for s in species_array:
		global_entity_count += s.entity_count
		global_active_entity_count += s.active_entity_count
		s.mouse_target =  mouse

	_tick_args = [delta, dt, sim_speed]
	_fb_flags.resize(species_array.size())
	_fb_flags.fill(false)
	_fc_us.resize(species_array.size())
	_fc_us.fill(0)
	_stage = Stage.FIELD_CELLS
	_stage_t0 = Time.get_ticks_usec()
	gid = -1
	if species_array.size() > 0:
		gid = WorkerThreadPool.add_group_task(_field_cells_job, species_array.size(),
				nThreads, true, "field_cells")
	if not pipelined:
		while _stage != Stage.CHUNKS:            # one tick per frame: each stage in turn
			if gid != -1:
				WorkerThreadPool.wait_for_group_task_completion(gid)
				gid = -1
			_next_stage()


var _fb_flags: Array = []                        # per species: builds its fields this tick


func _field_cells_job(k: int) -> void:
	var t0 := Time.get_ticks_usec()
	_fb_flags[k] = species_array[k].fields_begin()   # builds this tick?
	_fc_us[k] = Time.get_ticks_usec() - t0


func _deposit_job(k: int) -> void:
	var job = _field_jobs[k]
	var t0 := Time.get_ticks_usec()
	_deposit_ok[k] = job[0].field_deposit(job[1])
	_dep_us[k] = Time.get_ticks_usec() - t0


func _slice_job(k: int) -> void:
	var job = _slice_jobs[k]
	var t0 := Time.get_ticks_usec()
	job[0].field_diffuse_slice(job[1], job[2], job[3])
	_slice_us[k] = Time.get_ticks_usec() - t0


## The current stage is done: collect it (main thread), start the next one.
func _next_stage() -> void:
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)   # done: returns at once
		gid = -1
	var now := Time.get_ticks_usec()
	match _stage:
		Stage.FIELD_CELLS:
			timings["field_cells"] = now - _stage_t0
			_field_species.clear()
			_field_jobs.clear()
			for si in species_array.size():
				var sp: ALIFE = species_array[si]
				if _fb_flags[si]:
					_field_species.append(sp)
					for f in sp.fields.size():
						_field_jobs.append([sp, f])
			_deposit_ok.resize(_field_jobs.size())
			_deposit_ok.fill(false)
			_dep_us.resize(_field_jobs.size())
			_dep_us.fill(0)
			_stage = Stage.DEPOSIT
			if _field_jobs.size() > 0:
				gid = WorkerThreadPool.add_group_task(_deposit_job, _field_jobs.size(),
						nThreads, true, "field_deposit")
		Stage.DEPOSIT:
			timings["deposit"] = now - _stage_t0
			# Cut every field to diffuse in ranges of cells, one job each
			_slice_jobs.clear()
			for j in _field_jobs.size():
				if not _deposit_ok[j]:
					continue
				var sp: ALIFE = _field_jobs[j][0]
				var f: int = _field_jobs[j][1]
				sp.field_prepare_diffuse(f)              # fresh output buffer (main thread)
				var n_cells := sp.FIELD_NUM_CELLS
				var step := maxi(DIFFUSE_SLICE_MIN, n_cells / maxi(nThreads, 1) + 1)
				for start in range(0, n_cells, step):
					_slice_jobs.append([sp, f, start, mini(start + step, n_cells)])
			_slice_us.resize(_slice_jobs.size())
			_slice_us.fill(0)
			_stage = Stage.DIFFUSE
			if _slice_jobs.size() > 0:
				gid = WorkerThreadPool.add_group_task(_slice_job, _slice_jobs.size(),
						nThreads, true, "field_diffuse")
		Stage.DIFFUSE:
			timings["diffuse"] = now - _stage_t0
			for j in _field_jobs.size():
				if _deposit_ok[j]:
					_field_jobs[j][0].field_diffuse_end(_field_jobs[j][1])
			for sp in _field_species:
				sp.fields_end()
			_stage = Stage.CHUNKS
			_launch_chunks()
	_stage_t0 = Time.get_ticks_usec()


func _launch_chunks() -> void:
	var delta: float = _tick_args[0]
	var dt: float = _tick_args[1]
	var sim_speed: float = _tick_args[2]
	#setup thread/chunk/jobs
	jobs.clear()
	chunk_size = compute_chunk(global_entity_count) #need full entity count to work
	for s in species_array:
		var local_id:= 0
		var n: int = s.entity_count
		for start in range(0, n, chunk_size):
			jobs.append([s, start, mini(start + chunk_size, n),local_id,delta, dt, sim_speed])
			local_id += 1
		s.set_chunk(local_id)
	
	_chunk_us.resize(jobs.size())
	_chunk_us.fill(0)
	#run working group	
	gid = -1	
	if jobs.size() > 0:
		gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), nThreads, true, "species_update")

#SEND JOBS TO DNA
func run_chunk(k: int) -> void:
	var job = jobs[k]
	var t0 := Time.get_ticks_usec()
	job[0].run_chunk_simulation(job[1], job[2],job[3], job[4], job[5],job[6])
	_chunk_us[k] = Time.get_ticks_usec() - t0     # own slot: no two jobs write the same

## Waits for the running tick, every stage left included.
func wait_simulation() -> void:
	while _stage != Stage.IDLE and _stage != Stage.CHUNKS:
		_next_stage()
	if gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(gid)
		gid = -1
	if _stage == Stage.CHUNKS:
		timings["chunks"] = Time.get_ticks_usec() - _stage_t0
	_stage = Stage.IDLE


#UPDATE AFTER
func update_alife() -> void:
	#TODO optmisation possible if agent write themself in global instead of recomputing each frame? to check
	var species_count := species_array.size()
	global_species_offset.resize(species_count + 1)
	global_position_array.clear()
	global_active.clear()
	var total := 0

	# Walk areas: agents that stepped out are put back inside (before the carried items
	# follow their carriers, and before the grid is rebuilt)
	var u0 := Time.get_ticks_usec()
	for area in get_tree().get_nodes_in_group("walk_areas"):
		area.constrain(self)

	update_carried()
	var u1 := Time.get_ticks_usec()
	timings["carried"] = u1 - u0
	
	for si in species_count:
		var sp: ALIFE = species_array[si] #TODO CHANGE TYPE HERE
		sp.Build_and_remove_pendings()
		_ensure_carry_arrays(sp)                 # new lives: grow holding / held_by / facing

		assert(sp.position_array.size() == sp.entity_count)
		assert(sp.active_alife_array.size() == sp.entity_count)

		global_species_offset[si] = total
		global_position_array.append_array(sp.position_array)
		global_active.append_array(sp.active_alife_array)
		total += sp.entity_count

	global_species_offset[species_count] = total
	var u2 := Time.get_ticks_usec()
	timings["spawn_remove"] = u2 - u1

	# Grid ids ARE global ids: rebuild the grid now, with the new offsets.
	# Built at the start of the next tick instead, it would be correct during the tick
	# but wrong between ticks (player pick up / attack / picker), because births shift
	# the offsets of every species after them: a close agent's id would point to
	# another agent, far away.
	build_grid(global_position_array, global_active)
	timings["grid"] = Time.get_ticks_usec() - u2

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
	SpawnRandomAlife(3,10,2000,4) #glowberry5
	SpawnRandomAlife(1,3) #TREE
	sim_manager.set_simulation_speed(5000)
	await get_tree().create_timer(1.5).timeout
	sim_manager.set_simulation_speed(100)
	SpawnRandomAlife(0,3000,100,2) #GRASS
	await get_tree().create_timer(3.0).timeout
	#sim_manager.set_simulation_speed(10)
	SpawnRandomAlife(2,1000,100,2) #clovermoss
	#await get_tree().create_timer(10.0).timeout
	#sim_manager.set_simulation_speed(5)
	await get_tree().create_timer(2.0).timeout
	SpawnRandomAlife(5,20,1000,2) #bugsheep 
	SpawnRandomAlife(6,1) #spidercrab
	sim_manager.set_simulation_speed(1)
	print("finished")

	#SpawnRandomAlife(4,3) #spikyflower

	#SpawnRandomAlife(6,1) #spidercrab



func init_species_from_codex(worldd:WorldManager,alifem:AlifeManager):
	species_array = []
	for sp in codex.species_list:
		sp.init(worldd,alifem)
		sp.species_id = species_array.size()
		species_array.append(sp)



func SpawnRandomAlife(alifeID : int, nb:int, e:float=0.0, lc:int=0.0):
	var Alife := species_array[alifeID]
	for n in nb:# 100:
		var pos :Vector3= Alife.pick_random_position(Vector3(world.size.x/2,0,world.size.z/2),
											Vector3(world.size.x/2,0,world.size.z/2))
		#var energy := randf_range(0,5)
		if e == 0:
			e = Alife.seed_energy
		Alife.Build_New_Life(pos,e,lc)


#Contact GRID-------------------------------------------------------------------------------------------


		

var _grid_pos := PackedVector3Array()           # build_grid inputs for the worker jobs
var _grid_active := PackedInt32Array()
var _grid_chunk := 8192                         # agents per job
var _grid_jobs := 1
var _grid_hist := PackedInt32Array()            # per job and cell: count, then write offset
var _grid_count := PackedInt32Array()           # per cell: agents in it
var _grid_cell_step := 4096                     # cells per merge job


## Counting sort of every agent into the contact grid, in parallel:
##   1. per job of agents: their cell + a count per cell (its own row of _grid_hist)
##   2. per range of cells: total per cell, and where each job's agents start in that cell
##   3. (main thread) prefix sum over the cells -> cell_start
##   4. per job of agents: write them at their place (cell_items, sorted_pos)
## Few agents for many cells: the serial version is cheaper (no per-job rows to merge).
func build_grid(positions: PackedVector3Array, active: PackedInt32Array) -> void:
	var n := positions.size()
	current_cell_id.resize(n)
	cell_items.resize(n)
	sorted_pos.resize(n)
	cell_start.fill(0)
	_grid_pos = positions
	_grid_active = active
	var threads := maxi(nThreads, 1)
	_grid_jobs = clampi(n / (MIN_CHUNK * 8), 1, threads)
	if _grid_jobs < 2 or n * 2 < NUM_CELLS:          # parallel pays off unless cells >> agents
		_build_grid_serial(n)
	else:
		_grid_chunk = (n + _grid_jobs - 1) / _grid_jobs
		_grid_hist = PackedInt32Array()
		_grid_hist.resize(_grid_jobs * NUM_CELLS)       # zeros
		_grid_count = PackedInt32Array()
		_grid_count.resize(NUM_CELLS)
		_grid_cell_step = maxi(1024, NUM_CELLS / threads + 1)
		var n_merge := (NUM_CELLS + _grid_cell_step - 1) / _grid_cell_step

		var g := WorkerThreadPool.add_group_task(_grid_count_job, _grid_jobs, threads, true, "grid_count")
		WorkerThreadPool.wait_for_group_task_completion(g)
		g = WorkerThreadPool.add_group_task(_grid_merge_job, n_merge, threads, true, "grid_merge")
		WorkerThreadPool.wait_for_group_task_completion(g)
		var total := 0
		for c in NUM_CELLS:                              # the only serial pass: cells, not agents
			cell_start[c] = total
			total += _grid_count[c]
		cell_start[NUM_CELLS] = total
		g = WorkerThreadPool.add_group_task(_grid_scatter_job, _grid_jobs, threads, true, "grid_scatter")
		WorkerThreadPool.wait_for_group_task_completion(g)
		_grid_hist = PackedInt32Array()
		_grid_count = PackedInt32Array()
	_grid_pos = PackedVector3Array()
	_grid_active = PackedInt32Array()
	_grid_dirty = false


## 1. Cell of agents [k*chunk, (k+1)*chunk) and their count per cell (row k).
func _grid_count_job(k: int) -> void:
	var positions := _grid_pos
	var active := _grid_active
	var inv := Vector3.ONE / cell_size
	var last_x := GRID_W - 1
	var last_y := GRID_H - 1
	var last_z := GRID_D - 1
	var row := k * NUM_CELLS
	var start := k * _grid_chunk
	var end := mini(start + _grid_chunk, positions.size())
	for i in range(start, end):
		if active[i] == 0:
			current_cell_id[i] = -1
			continue
		var p := positions[i]
		var c := clampi(int(p.x * inv.x), 0, last_x) \
				+ GRID_W * (clampi(int(p.y * inv.y), 0, last_y) \
				+ GRID_H * clampi(int(p.z * inv.z), 0, last_z))
		current_cell_id[i] = c
		_grid_hist[row + c] += 1


## 2. Cells [k*step, (k+1)*step): total per cell; each row becomes the offset of that job's
## agents inside the cell (job 0 first, then job 1...).
func _grid_merge_job(k: int) -> void:
	var start := k * _grid_cell_step
	var end := mini(start + _grid_cell_step, NUM_CELLS)
	var jobs_n := _grid_jobs
	for c in range(start, end):
		var sum := 0
		for j in jobs_n:
			var idx := j * NUM_CELLS + c
			var cnt := _grid_hist[idx]
			_grid_hist[idx] = sum
			sum += cnt
		_grid_count[c] = sum


## 4. Agents of job k at their place: cell start + this job's offset in the cell.
func _grid_scatter_job(k: int) -> void:
	var positions := _grid_pos
	var row := k * NUM_CELLS
	var start := k * _grid_chunk
	var end := mini(start + _grid_chunk, positions.size())
	for i in range(start, end):
		var c := current_cell_id[i]
		if c < 0:
			continue
		var idx := row + c
		var w := cell_start[c] + _grid_hist[idx]
		_grid_hist[idx] += 1
		cell_items[w] = i
		sorted_pos[w] = positions[i]


## Serial counting sort (few agents for the number of cells).
func _build_grid_serial(n: int) -> void:
	var positions := _grid_pos
	var active := _grid_active
	var inv := Vector3.ONE / cell_size
	var last_x := GRID_W - 1
	var last_y := GRID_H - 1
	var last_z := GRID_D - 1
	for i in n:
		if active[i] == 0:
			current_cell_id[i] = -1
			continue
		var p := positions[i]
		var c := clampi(int(p.x * inv.x), 0, last_x) \
				+ GRID_W * (clampi(int(p.y * inv.y), 0, last_y) \
				+ GRID_H * clampi(int(p.z * inv.z), 0, last_z))
		current_cell_id[i] = c
		cell_start[c + 1] += 1
	for c in NUM_CELLS:
		cell_start[c + 1] += cell_start[c]
	write_pos = cell_start.slice(0, NUM_CELLS)
	for i in n:
		var c := current_cell_id[i]
		if c < 0:
			continue
		var w := write_pos[c]
		cell_items[w] = i
		sorted_pos[w] = positions[i]
		write_pos[c] = w + 1


#Walkable area (generic) ----------------------------------------------------------------------------
# NavWorld sets walk_grid and walk_species: every species that doesn't handle the walkable
# area itself (no `height_grid` variable). After each tick, the moves of their agents are
# corrected through the grid: walls block (agents slide along them), and agents stand on
# the floor where they end up (ship deck, platform, ground). Species with `height_grid`
# (cat, cattle, NPC) do it themselves, with gravity, jumps and head room.

var walk_grid: HeightGrid = null               # null: no walkable area, nobody limited
var walk_species := {}                         # ALIFE -> true: limited by the generic pass
var _prev := {}                                # ALIFE -> positions before the tick
var _walk_jobs: Array = []                     # [species, start, end]


func _snapshot_walkers() -> void:
	_prev.clear()
	if walk_grid == null:
		return
	for sp in walk_species:
		_prev[sp] = sp.position_array.duplicate()   # one native copy per species


func _constrain_walkers() -> void:
	if walk_grid == null or _prev.is_empty():
		return
	_walk_jobs.clear()
	var size := maxi(chunk_size, MIN_CHUNK)
	for sp in _prev:
		var n: int = mini(sp.entity_count, (_prev[sp] as PackedVector3Array).size())
		for start in range(0, n, size):
			_walk_jobs.append([sp, start, mini(start + size, n)])
	if _walk_jobs.is_empty():
		return
	var g := WorkerThreadPool.add_group_task(_walk_job, _walk_jobs.size(), nThreads, true, "walk_area")
	WorkerThreadPool.wait_for_group_task_completion(g)


## One chunk: every agent of it that moved this tick, back through the grid.
func _walk_job(k: int) -> void:
	var job = _walk_jobs[k]
	var sp = job[0]
	var prev: PackedVector3Array = _prev[sp]
	var hg := walk_grid
	for i in range(job[1], job[2]):
		if sp.active_alife_array[i] != ACTIVE:
			continue                             # pool, carried, thrown, hanging...
		var p := prev[i]
		var q: Vector3 = sp.position_array[i]
		if p.x == q.x and p.z == q.z and p.y == q.y:
			continue                             # didn't move
		var r := hg.move(p, q, p.y)              # (x, floor, z)
		sp.position_array[i] = Vector3(r.x, r.y, r.z)   # on the floor where it ends up


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

## Local index -> global id (contact grid ids, find_nearest...)
## Only valid for the current tick: offsets move when a species grows.
func g_id(sp, i: int) -> int:
	return global_species_offset[species_array.find(sp)] + i


## Global id -> [species, local index]
func split_id(id: int) -> Array:
	var s :=  global_species_offset.bsearch(id, false) - 1
	return [ species_array[s], id -  global_species_offset[s]]


#Carry-------------------------------------------------------------------------------------------
# One agent (the carrier) holds another (the item). The link is stored on both sides:
#   carrier_sp.holding[carrier] = carry id of the item     (-1 = empty hands)
#   item_sp.held_by[item]       = carry id of the carrier  (-1 = not carried)
# Carry ids pack (species_id, local index) in one int. Unlike global ids they never
# change: global_species_offset moves every time a species earlier in the list grows.
#
# States in active_alife_array: 0 pool, 1 in the world, 2 held, 4 flying (thrown).
# The species simulation must only move / run AI for agents in state ACTIVE (1),
# and the renderer should still draw states 2 and 4.

const ACTIVE := 1
const HELD := 2
const FLYING := 4

const CARRY_SHIFT := 20                          # up to ~1 million agents per species
const CARRY_MASK := (1 << CARRY_SHIFT) - 1

@export var carry_forward := 0.5                 # how far in front of the carrier (x its height)
@export var carry_height := 0.5                  # how high (fraction of the carrier's height)

var carriers: Array[int] = []                    # carry ids of agents carrying something


## Local index -> carry id (stable)
func cid(sp, i: int) -> int:
	return (sp.species_id << CARRY_SHIFT) | i


## Carry id -> [species, local index]
func split_cid(id: int) -> Array:
	return [species_array[id >> CARRY_SHIFT], id & CARRY_MASK]


## The carrier picks up the item. False if its hands are full or the item isn't free.
func pick_up(carrier_sp, carrier: int, item_sp, item: int) -> bool:
	if carrier_sp == item_sp and carrier == item:
		return false                             # can't carry yourself
	if carrier_sp.holding[carrier] != -1 or item_sp.active_alife_array[item] != ACTIVE:
		return false                             # hands full, or item not free in the world
	if carrier_sp.has_method("can_carry") and not carrier_sp.can_carry(carrier, item_sp, item):
		return false                             # too heavy for this carrier
	carrier_sp.holding[carrier] = cid(item_sp, item)
	item_sp.held_by[item] = cid(carrier_sp, carrier)
	item_sp.Stock_Life(item)                     # your own "leave the world" logic
	item_sp.active_alife_array[item] = HELD      # then marked held: out of the grid and the
												 # simulation, and update_carried knows it's carried
	carriers.append(cid(carrier_sp, carrier))
	return true


## Carry class of an agent: the carrying_power needed to lift it = its size, rounded up.
## (size 0.5 -> 1, size 1.0 -> 1, size 1.5 -> 2, size 2.0 -> 2, size 3.5 -> 4)
func item_carry_class(sp, j: int) -> int:
	return ceili(sp.current_size[j])


## Put the carried item back in the world at `at`.
func drop(carrier_sp, carrier: int, at: Vector3) -> void:
	var t := _let_go(carrier_sp, carrier)
	if not t.is_empty():
		land(t[0], t[1], at)


## Let go of the carried item without putting it back in the world (throws).
## Returns [species, local index] of the item, or [] if the hands were empty.
func release_flying(carrier_sp, carrier: int) -> Array:
	var t := _let_go(carrier_sp, carrier)
	if not t.is_empty():
		t[0].active_alife_array[t[1]] = FLYING
	return t


## A thrown (or dropped) item is back in the world.
func land(sp, i: int, at: Vector3) -> void:
	sp.position_array[i] = keep_in_world(at)
	sp.Release_Life(i)                           # your own "back in the world" logic
	sp.active_alife_array[i] = ACTIVE


func _let_go(carrier_sp, carrier: int) -> Array:
	var item: int = carrier_sp.holding[carrier]
	if item == -1:
		return []
	var t := split_cid(item)
	t[0].held_by[t[1]] = -1
	carrier_sp.holding[carrier] = -1
	carriers.erase(cid(carrier_sp, carrier))
	return t


## Breaks every link of this agent. Call it before removing an agent
## (update_carried also cleans up on its own if you forget).
func unlink(sp, i: int) -> void:
	if sp.holding[i] != -1:                      # I carried something: it falls here
		drop(sp, i, sp.position_array[i])
	var c: int = sp.held_by[i]
	if c != -1:                                  # I was carried: free my carrier's hands
		var t := split_cid(c)
		if t[0].holding[t[1]] == cid(sp, i):
			t[0].holding[t[1]] = -1
			carriers.erase(c)
		sp.held_by[i] = -1


## Once per tick, after the simulation: carried items follow their carrier.
## Also cleans up links broken by deaths and removals.
func update_carried() -> void:
	for c in carriers.duplicate():
		var t := split_cid(c)
		var c_sp = t[0]
		var ci: int = t[1]
		var item_id: int = c_sp.holding[ci]
		if item_id == -1:
			carriers.erase(c)                    # hands emptied elsewhere
			continue

		var it := split_cid(item_id)
		var i_sp = it[0]
		var ii: int = it[1]
		if i_sp.active_alife_array[ii] != HELD:
			# The item was removed (or its slot reused) while carried: forget it
			c_sp.holding[ci] = -1
			if i_sp.held_by[ii] == c:
				i_sp.held_by[ii] = -1
			carriers.erase(c)
			continue

		if c_sp.active_alife_array[ci] != ACTIVE or c_sp.alive_array[ci] == 0:
			drop(c_sp, ci, c_sp.position_array[ci])   # carrier removed or dead: item falls
			continue

		i_sp.position_array[ii] = carry_position(c_sp, ci)


## In front of the carrier, at a fraction of its height.
## Direction: the species' `facing` array if it has one, else where it moves.
func carry_position(sp, i: int) -> Vector3:
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var h := maxf(q.y * sp.current_size[i], 0.2)
	var fwd := Vector3.ZERO
	if "facing" in sp:
		fwd = sp.facing[i]
	if fwd.length_squared() < 1e-6:
		fwd = sp.current_velocity[i]
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
	var p: Vector3 = sp.position_array[i] + fwd * carry_forward * h + Vector3.UP * h * carry_height
	return WorldWrap.wrap_into(p)                # stays inside the world near a border


## Brings a position back inside the world: wrapped on WRAP borders, clamped on walls.
func keep_in_world(p: Vector3) -> Vector3:
	var s: Vector3 = world.size
	p.x = fposmod(p.x, s.x) if world.border_type_x == world.Border.WRAP else clampf(p.x, 0.0, s.x)
	p.y = fposmod(p.y, s.y) if world.border_type_y == world.Border.WRAP else clampf(p.y, 0.0, s.y)
	p.z = fposmod(p.z, s.z) if world.border_type_z == world.Border.WRAP else clampf(p.z, 0.0, s.z)
	return p


## Keeps holding / held_by (and facing, if the species has it) as long as the species'
## arrays: new lives get -1 (nothing carried, not carried).
func _ensure_carry_arrays(sp) -> void:
	var n: int = sp.entity_count
	if sp.holding.size() != n:
		sp.holding = _grow_ints(sp.holding, n)   # packed arrays are copies: assign back
	if sp.held_by.size() != n:
		sp.held_by = _grow_ints(sp.held_by, n)
	if "facing" in sp and sp.facing.size() != n:
		var f: PackedVector3Array = sp.facing
		f.resize(n)                              # new entries are Vector3.ZERO
		sp.facing = f


func _grow_ints(arr: PackedInt32Array, n: int) -> PackedInt32Array:
	var old := arr.size()
	arr.resize(n)
	for k in range(old, n):
		arr[k] = -1
	return arr
