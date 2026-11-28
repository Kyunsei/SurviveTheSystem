extends Node
class_name AlifeRendererManager

#TODO move core class in new FOLDER from test !!!

@export var alifemanager : AlifeManager
@export var world : WorldManager
@export var sun: DirectionalLight3D



#var activated := true

## Smooth movement between ticks (set every frame by SimulationManager: on with the
## pipelined tick). Off: agents are drawn at the newest tick, exactly as before.
##
## Playback clock: each finished tick is stamped with its simulated time (the sum of the
## tick deltas). A render clock runs at real speed about one tick interval behind the
## newest stamp, gently speeding up / slowing down to stay there (never jumping), and each
## frame the agents are drawn between the two ticks around it. Uneven tick times then give
## no jump forward and no pause: movement stays continuous.
var interpolate := false
@export var interp_max_jump := 8.0              # a move longer than this between ticks: no blend
## How far behind the newest tick the render clock aims, in tick intervals (1 = one tick).
@export var interp_delay := 1.1
var interp_alpha := 1.0
var tick_delta := 0.0                           # set by SimulationManager: delta of the tick being uploaded
var _stamp := PackedFloat64Array([0.0, 0.0, 0.0])   # per buffer slot: simulated time of its tick
var _sim_t := 0.0                               # simulated time of the newest tick
var _render_t := 0.0                            # the playback clock
var _interval := 1.0 / 30.0                     # average time between ticks
var _ticks := 0                                 # ticks uploaded since interpolation started
var _interp_was := false


func _ready() -> void:
	# After SimulationManager (0, which uploads a finished tick), before the camera (10)
	# and the player's HUD (20): they all use this frame's blend
	process_priority = 5


func _process(delta: float) -> void:
	if not interpolate or _ticks < 3:
		# Not blending (or not enough ticks yet): the newest tick, as before
		var changed := interp_alpha != 1.0 or _interp_was != interpolate
		interp_alpha = 1.0
		_interp_was = interpolate
		for s in alifemanager.species_array:
			if s.renderer3D != null:
				s.renderer3D.bind_pair(s.renderer3D.buffer_back(1), s.renderer3D.newest)
				if changed:
					s.renderer3D.set_interp(1.0, interp_max_jump)
		if not interpolate:
			_ticks = 0
		return
	_interp_was = true

	# Playback clock: real speed, nudged toward (newest - delay) so it neither runs out of
	# ticks nor falls behind; never jumps unless far off (freeze, pause)
	var target := _sim_t - _interval * interp_delay
	var err := target - _render_t
	if absf(err) > _interval * 4.0:
		_render_t = target                         # far off: resync
	else:
		_render_t += delta * clampf(1.0 + err / maxf(_interval * 2.0, 0.001), 0.75, 1.25)

	# The two ticks around the render time (newest, previous, the one before)
	var r: ALIFE = null
	for s in alifemanager.species_array:
		if s.renderer3D != null:
			r = s
			break
	if r == null:
		return
	var n0: int = r.renderer3D.buffer_back(0)
	var n1: int = r.renderer3D.buffer_back(1)
	var n2: int = r.renderer3D.buffer_back(2)
	var a := n1
	var b := n0
	if _render_t < _stamp[n1]:
		a = n2
		b = n1
	var span := _stamp[b] - _stamp[a]
	var alpha := clampf((_render_t - _stamp[a]) / span, 0.0, 1.0) if span > 1e-6 else 1.0
	interp_alpha = alpha
	for s in alifemanager.species_array:
		if s.renderer3D != null:
			s.renderer3D.bind_pair(a, b)
			s.renderer3D.set_interp(alpha, interp_max_jump)


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


## Where agent i of sp is drawn right now (blended like the shaders): for the camera,
## the arrow, bars... Without blending: its simulation position.
func visual_position(sp, i: int) -> Vector3:
	if not interpolate or sp.renderer3D == null:
		return sp.position_array[i]
	var v: Vector3 = sp.renderer3D.visual_position(i, interp_alpha, interp_max_jump,
			world.size.y, world.size)
	return sp.position_array[i] if v.x == INF else v

var r_gid := -1
var jobs: Array = []     # each entry: [species, chunk_index]

var nThread_max := 16
var chunk_count: int
var chunk_size: int

#TODO adjust these number to see performance difference!
const MIN_CHUNK := 256      # never smaller: avoids overhead
const MAX_CHUNK := 8192     # never bigger: keeps balance
const JOBS_PER_THREAD := 4

#var mutex := Mutex.new()

var entity_count := 0
var renderer_count := 0

var activated := true



#TODO bug reinit doesnt make old thing disapear. check if still case?

#init part -------------------------------------------

func init():
	if sun:
		sun.shadow_enabled = true

	entity_count = 0
	renderer_count = 0
	nThread_max = OS.get_processor_count()
	chunk_count = clamp( nThread_max,1,OS.get_processor_count()) 
	init_renderer()
	
	#set_3d(false)
	#get_viewport().set_input_as_handled()



func init_renderer():
	for c in get_children():
		if c is AlifeRenderer3D:
			c.queue_free()
	for s in alifemanager.species_array:
		s.rend_data = AlifeRenderingData.new()
		s.rend_data.resize(s.entity_count)	
		s.renderer3D = AlifeRenderer3D.new()
		s.renderer3D.setup( s.rend_data,s, world.size, s.colour)
		if s.species_name == "SPIDERCRAB":
			s.setup_hunt_visuals()
		add_child.call_deferred(s.renderer3D)

		#s.renderer2D = AlifeRenderer2D.new()
		#s.renderer2D.setup(s.rend_data, world.size, s.colour)
		#add_child.call_deferred(s.renderer2D)


#main looop -------------------------------------------------------

func run_visualisation():	
	if !activated:
		return
	if interpolate:
		for s in alifemanager.species_array:
			s.renderer3D.swap_buffers()            # write the new tick into the older buffer
	var t0 := Time.get_ticks_usec()
	start_write_rendering_buffer()
	var t1 := Time.get_ticks_usec()
	wait_rendering_buffer()
	var t2 := Time.get_ticks_usec()
	upload_buffer()
	var t3 := Time.get_ticks_usec()
	if interpolate:
		# Stamp the new tick with its simulated time; the playback clock does the rest
		var d := clampf(tick_delta, 0.001, 0.5)
		_sim_t += d
		_interval = lerpf(_interval, d, 0.2)
		for s in alifemanager.species_array:
			if s.renderer3D != null:
				_stamp[s.renderer3D.newest] = _sim_t   # (all renderers swap together)
				break
		for s in alifemanager.species_array:
			if s.renderer3D != null:
				s.renderer3D.rebind()          # textures may have been recreated by upload
		_ticks += 1
		if _ticks == 1:
			_render_t = _sim_t - _interval * interp_delay
		_process(0.0)                          # bind this frame's pair right away

	#print("strat %f, wait %f, upload %f" % [t1-t0,t2-t1,t3-t2])

#multithread part -------------------------------------------------------


func start_write_rendering_buffer():

	entity_count = 0
	#RESIZE CHUNK and renderdata and multimesh
	for s in alifemanager.species_array:
		entity_count += s.entity_count
		s.rend_data.resize(s.entity_count)
		#s.renderer2D.ensure_instances2D(s.entity_count)
		s.renderer3D.ensure_instances3D(s.entity_count)
		

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
		r_gid = WorkerThreadPool.add_group_task(run_chunk, jobs.size(), nThread_max, true, "species_update")

func run_chunk(k: int) -> void:
	var job = jobs[k]
	job[0].write_rendering_buffer_in_chunk(job[1], job[2])

func wait_rendering_buffer() -> void:
	if r_gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(r_gid)
		r_gid = -1

func upload_buffer()-> void:
	for s in alifemanager.species_array:
		s.rend_data.upload()
		#s.renderer2D.set_count(s.entity_count)
		s.renderer3D.set_count(s.entity_count)

	

func compute_chunk(total:int) -> int:
	var threads := OS.get_processor_count()
	threads = clamp( nThread_max,1,OS.get_processor_count()) 
	@warning_ignore("integer_division")
	var chunk := total / (threads * JOBS_PER_THREAD)
	return clampi(chunk, MIN_CHUNK, MAX_CHUNK)
	
	
	
'# on Main
@onready var view2d: Node2D = $Rendering2D
@onready var view3d: Node3D = $Rendering3D
@onready var cam2d: Camera2D = $Camera2D
@onready var cam3d: Camera3D = $Camera3D

var is_3d := false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		set_3d(not is_3d)
		get_viewport().set_input_as_handled()

func set_3d(on: bool) -> void:
	is_3d = on
	view2d.visible = not on
	view3d.visible = on
	cam2d.enabled = not on
	cam3d.current = on
	if on:
		cam3d.init()
	else:
		cam2d.init()
	

	if on and world:
		cam3d.frame_world(Vector2(0, 0), Vector2(world.size.x, world.size.z))'
