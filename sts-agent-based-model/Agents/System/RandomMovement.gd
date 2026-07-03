extends AgentSystem
class_name RANDOM_MOVE_SYSTEM

var _rng_pool: Array[RandomNumberGenerator] = []


@export var speed: float = 100
func _init_rng_pool():
	var n = max(1, OS.get_processor_count())
	for i in range(n):
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		_rng_pool.append(rng)



func update(manager,delta):
	var positions = manager.positions
	var positions_x = manager.positions_x
	var positions_y = manager.positions_y
	var positions_z = manager.positions_z
	var active = manager.active
	var spd = speed * delta
	
	var world_id = 0
	var wm = manager.world_manager
	var boundary = wm.boundary_condition[world_id]
	var w_size_x = wm.size_x[world_id]
	var w_size_y = wm.size_y[world_id]
	var w_size_z = wm.size_z[world_id]
	
	if manager.isthreading:
		run_threaded(positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z)
		'var callable = _update_agent.bind(
			positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z
		)
		var group_id = WorkerThreadPool.add_group_task(callable, positions_x.size())
		WorkerThreadPool.wait_for_group_task_completion(group_id)'
	else:
		for i in range(manager.positions.size()):
			if active[i]:
				var r = Vector3(
					randf() * 2.0 - 1.0,
					randf() * 2.0 - 1.0,
					randf() * 2.0 - 1.0
					)			
				positions_x[i] += r.x * spd
				positions_y[i] += r.y * spd
				positions_z[i] += r.z * spd
				if manager.world_manager.boundary_condition[world_id] == 0:
					pass
				else:
					positions_x[i] = clamp(positions_x[i],0,manager.world_manager.size_x[world_id])
					positions_y[i] = clamp(positions_y[i],0,manager.world_manager.size_y[world_id])
					positions_z[i] = clamp(positions_z[i],0,manager.world_manager.size_z[world_id])

func _update_agent(i,thread_index, positions_x, positions_y, positions_z, active,spd, boundary, size_x, size_y, size_z):
	if not active[i]:
		return
	#var rng = _rng_pool[i % _rng_pool.size()]
	#var rng = RandomNumberGenerator.new()
	#rng.randomize()
	#var rng = randf() * 2.0 - 1.0
	var rng = _rng_pool[thread_index]

	var r = Vector3(
	rng.randf() * 2.0 - 1.0,
	rng.randf() * 2.0 - 1.0,
	rng.randf() * 2.0 - 1.0
	)		
	positions_x[i] += r.x * spd
	positions_y[i] += r.y * spd
	positions_z[i] += r.z * spd
	#positions_x[i] += (rng.randf() * 2.0 - 1.0) * spd
	#positions_y[i] += (rng.randf() * 2.0 - 1.0) * spd
	#positions_z[i] += (rng.randf() * 2.0 - 1.0) * spd
	
	if boundary != 0:
		positions_x[i] = clamp(positions_x[i], 0, size_x)
		positions_y[i] = clamp(positions_y[i], 0, size_y)
		positions_z[i] = clamp(positions_z[i], 0, size_z)

		
'func update_agent():
	for i in range(manager.positions.size()):
		if active[i]:
			var r = Vector3(
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0
			)			
			positions_x[i] += r.x * spd
			positions_y[i] += r.y * spd
			positions_z[i] += r.z * spd
			var world_id = 0
			if manager.world_manager.boundary_condition[world_id] == 0:
				pass
			else:
				positions_x[i] = clamp(positions_x[i],0,manager.world_manager.size_x[world_id])
				positions_y[i] = clamp(positions_y[i],0,manager.world_manager.size_y[world_id])
				positions_z[i] = clamp(positions_z[i],0,manager.world_manager.size_z[world_id])'


var agents: Array = []
var threads: Array[Thread] = []
func run_threaded(positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z):
	if _rng_pool.is_empty():
		_init_rng_pool()
	var thread_count = _rng_pool.size()

	var callable = _process_chunk.bind(
		positions_x, positions_y, positions_z, active,
		spd, boundary, w_size_x, w_size_y, w_size_z, thread_count
	)
	var group_id = WorkerThreadPool.add_group_task(callable, thread_count)
	WorkerThreadPool.wait_for_group_task_completion(group_id)


func _process_chunk(thread_index: int, positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z, thread_count):
	var n = positions_x.size()
	var chunk_size = ceili(float(n) / thread_count)
	var start = thread_index * chunk_size
	var end = min(start + chunk_size, n)
	for i in range(start, end):
		_update_agent(i, thread_index, positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z)

func run_threaded2(positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z):
	if _rng_pool.is_empty():
		_init_rng_pool()
	var thread_count = _rng_pool.size()
	var chunk_size = ceili(float(positions_x.size()) / thread_count)
	threads.clear()
	for t in range(thread_count):
		var start = t * chunk_size
		var end = min(start + chunk_size, positions_x.size())
		if start >= end:
			continue
		var thread = Thread.new()
		thread.start(_process_chunk.bind(start, end,t,positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z))
		threads.append(thread)

		# Wait for all threads to finish (blocking)
	for thread in threads:
		thread.wait_to_finish()
	
	#print("All agents processed!")

func _process_chunk2(start: int, end: int,thread_index:int, positions_x, positions_y, positions_z, active,
			spd, boundary, w_size_x, w_size_y, w_size_z):
	for i in range(start, end):
		_update_agent(i,thread_index, positions_x, positions_y, positions_z, active,spd, boundary, w_size_x, w_size_y, w_size_z)
