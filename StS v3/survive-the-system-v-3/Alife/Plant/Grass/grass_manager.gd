extends Node3D

var grass_array = []
var grass_dict = {}
var grass_unique_id = 0
var World : Node3D

@export var object_scene : PackedScene

var thread: Thread
var mutex: Mutex = Mutex.new()
var thread_is_running: bool = false
var _pending_spawns: Array = []
var _pending_kills: Array = []
var _pending_light_changes: Dictionary = {}  # index -> new value

var grass_dna = {
	"ID":0,
	"Species": "grass",
	"position":Vector3(),
	"current_energy": 0,
	"Homeostasis_cost":0.3,
	"Photosynthesis_absorbtion": 1.0,
	"light_index": []
}


func _ready() -> void:
	if multiplayer.is_server():
		thread = Thread.new()


func _update_on_thread():
	#print("Thread start — grass count: ", grass_dict.size())
	var ss = Time.get_ticks_msec() 
	

	
	#var snapshot = grass_array.duplicate()
	var snapshot = grass_dict.duplicate()
	_pending_spawns.clear()
	_pending_kills.clear()
	_pending_light_changes.clear()	
	for g in snapshot.values():
		Photosynthesis(g)
		_thread_reproduction(g)
		_thread_homeostasis(g)
	#print(_pending_spawns)

	#print("end " + str(Time.get_ticks_msec() -ss))
	call_deferred("_on_work_finished")

func update():
	start_thread()
	'for g in grass_array:
		Photosynthesis(g)
		Reproduction(g)
		Homeostasis(g)'



func start_thread():
	mutex.lock()
	if thread_is_running:
		mutex.unlock()
		#print("Already running!")
		return
	thread_is_running = true
	mutex.unlock()
	
	thread = Thread.new()
	thread.start(_update_on_thread)

	

func _on_work_finished():
	thread.wait_to_finish()  # Clean up
	for g in _pending_kills:
		Kill(g)
	for g in _pending_spawns:
		spawn_grass(g)
	if _pending_spawns.size()>0:
		draw_new_grass.rpc(_pending_spawns)
	mutex.lock()
	thread_is_running = false
	mutex.unlock()

   # emit_signal("work_completed", result)



############

func spawn_grass(pos):
	var newgrass = grass_dna.duplicate()
	newgrass["position"] = pos
	newgrass["light_index"] = get_lightIndex(pos)
	newgrass["ID"] = grass_unique_id
	#grass_array.append(newgrass)
	grass_dict[grass_unique_id] = newgrass
	grass_unique_id += 1
	


func Kill(grass):
	var dead_id = grass["ID"]
	#var grass_unique_id = 0
	if grass_dict.has(grass["ID"]):
		grass_dict.erase(grass["ID"])

	#if grass_array.has(grass):
	#	grass_array.erase(grass)


func get_lightIndex(pos):
	var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
	return World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)	
	 
	
	
func Homeostasis(grass):
	grass["current_energy"] -= grass["Homeostasis_cost"]  * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if grass["current_energy"] < 0:
		Kill(grass)


func _thread_homeostasis(grass):
	grass["current_energy"] -= grass["Homeostasis_cost"] * GlobalSimulationParameter.simulation_speed
	if grass["current_energy"] < 0:
		_pending_kills.append(grass)

func Photosynthesis(grass):
	
	if grass["light_index"] <  World.light_array.size():
		var energy_absorbed = World.light_array[grass["light_index"]] * grass["Photosynthesis_absorbtion"] * GlobalSimulationParameter.simulation_speed 
		energy_absorbed = min(World.light_array[grass["light_index"]],energy_absorbed)
		#print(energy_absorbed)
		if energy_absorbed <= 0:
			return
		grass["current_energy"] += energy_absorbed
		var shadow_effect = 1.0
		World.light_array[grass["light_index"]] = max(World.light_array[grass["light_index"]]-shadow_effect,0)
		#print(World.light_array[light_index])

func Reproduction(grass):
	if grass["current_energy"]  > 10:# reproduction_stock + energy_stock:
		var newpos = grass["position"] + Vector3(randf_range(-5,5),
											0,
											randf_range(-5,5)
											) 
		#var scene = load(get_scene_file_path())
		newpos.x = clamp(newpos.x ,-World.World_Size.x/2+1,World.World_Size.x/2-1 )
		newpos.z = clamp(newpos.z ,-World.World_Size.z/2+1,World.World_Size.z/2-1 )

		#reproduction_asked.emit(newpos,"grass")
		spawn_grass(newpos)
		grass["current_energy"] -= 8
		
func _thread_reproduction(grass):
	if grass["current_energy"] > 10:
		var newpos = grass["position"] + Vector3(
			randf_range(-5, 5),
			0,
			randf_range(-5, 5)
		)
		newpos.x = clamp(newpos.x, -World.World_Size.x / 2 + 1, World.World_Size.x / 2 - 1)
		newpos.z = clamp(newpos.z, -World.World_Size.z / 2 + 1, World.World_Size.z / 2 - 1)
		# Stage the spawn instead of calling spawn_grass() directly
		_pending_spawns.append(newpos)
		grass["current_energy"] -= 8	
		
			
func Cut(grass):
	Become_object.rpc_id(1)
	Kill(grass)
	
@rpc("any_peer","call_local") 
func Become_object():
	var new_object = object_scene.instantiate()
	new_object.position.y = position.y
	new_object.position.x = position.x + randf_range(-1,1)
	new_object.position.z = position.z + randf_range(-1,1)
	new_object.rotation.y = randf_range(deg_to_rad(0),deg_to_rad(360))
	get_parent().add_child(new_object, true)


##########################MULTIMESH GESTION

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(new_grass_pos_array):
	for g in new_grass_pos_array:
		pass
		#print(g)
		#$grass_multimesh.draw_new_grass(g)
	

@rpc("any_peer","call_remote")
func draw_multimesh_on_client(peer_id):
	var dict = grass_dict
	send_and_draw_array.rpc_id(peer_id, dict)

@rpc("any_peer","call_remote")
func send_and_draw_array(dict):
	$grass_multimesh.draw_all_grass(dict)	


func _exit_tree() -> void:
	if thread and thread.is_alive():
		thread.wait_to_finish()
