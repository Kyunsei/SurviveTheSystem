extends Node2D
var r_gid := -1
var jobs: Array = []     # each entry: [species, chunk_index]

var nThread_max := 8
var chunk_count: int
var chunk_size: int

#TODO adjust these number to see performance difference!
const MIN_CHUNK := 256      # never smaller: avoids overhead
const MAX_CHUNK := 8192     # never bigger: keeps balance
const JOBS_PER_THREAD := 4

var mutex := Mutex.new()

var entity_count := 0
var renderer_count := 0

#crossREF in case
var world: World
var alifemanager: AlifeManager

var write_usec:= 0.0
var update_usec:= 0.0
var main_visu_usec:= 0.0
	
func init(worldd,alifm):
	
	entity_count = 0
	renderer_count = 0
	chunk_count = clamp( nThread_max,1,OS.get_processor_count()) 
	world = worldd
	alifemanager = alifm


func run_visualisation():
	var t0 := Time.get_ticks_usec()
	start_write_rendering_buffer()
	wait_rendering_buffer()
	write_usec = Time.get_ticks_usec() - t0
	var t1 := Time.get_ticks_usec()
	upload_buffer()
	update_usec = Time.get_ticks_usec() -t1
	main_visu_usec = Time.get_ticks_usec() - t0


func start_write_rendering_buffer():

	entity_count = 0
	for s in alifemanager.species_array:
		entity_count += s.entity_count
		s.renderer.ensure_capacity(s.entity_count)

	renderer_count = alifemanager.species_array.size() #TODO move renderer in visualisation
	#setup thread/chunk/jobs
	jobs.clear()
	chunk_size = compute_chunk(entity_count) #need full entity count to work
	for s in alifemanager.species_array:
		var local_id:= 0
		var n: int = s.entity_count
		for start in range(0, n, chunk_size):
			jobs.append([s, start, mini(start + chunk_size, n),local_id])
			local_id += 1
		s.set_chunk(local_id)
	
	#run working group	
	r_gid = -1	
	if jobs.size() > 0:
		#gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), -1, true, "species_update")
		r_gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), nThread_max, true, "species_update")

func run_chunk(k: int) -> void:
	var job = jobs[k]
	job[0].write_rendering_buffer_in_chunk(job[1], job[2],job[3])

func wait_rendering_buffer() -> void:
	if r_gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(r_gid)
		r_gid = -1

func upload_buffer()-> void:
	for s in alifemanager.species_array:
		s.renderer.upload(s.entity_count)


	

func compute_chunk(total:int) -> int:
	var threads := OS.get_processor_count()
	threads = clamp( nThread_max,1,OS.get_processor_count()) 
	@warning_ignore("integer_division")
	var chunk := total / (threads * JOBS_PER_THREAD)
	return clampi(chunk, MIN_CHUNK, MAX_CHUNK)
