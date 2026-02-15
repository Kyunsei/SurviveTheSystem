extends Node3D

var grass_array = []
var grass_dict = {}
var grass_unique_id = 0
var World : Node3D

@export var max_grass_object = 100
@export var object_scene : PackedScene

var thread: Thread
var mutex: Mutex = Mutex.new()
var thread_is_running: bool = false
var _pending_spawns: Array = []
var _pending_kills: Array = []
var _pending_external_kills: Array = []

#var _pending_light_changes: Dictionary = {}  # index -> new value
var free_id_array = []

var grass_dna = {
	"ID":0,
	"bin_ID":null,
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
	#var ss = Time.get_ticks_msec() 

	World.add_value_in_each_tile(World.light_array,World.light_flux_in,0,World.light_max_value) #should be moved sommewhere else?
	_pending_spawns.clear()
	_pending_kills.clear()
	#_pending_light_changes.clear()	
	for g in grass_dict.values():
		Photosynthesis(g)
		_thread_reproduction(g)
		_thread_homeostasis(g)

	#print("end " + str(Time.get_ticks_msec() -ss))
	call_deferred("_on_work_finished")

func update():
	start_thread()
	#_update_on_thread()
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

	for g in _pending_spawns:
		g["ID"] = get_free_id()
		grass_dict[g["ID"]] = g
		put_in_world_bin(g)
		draw_new_grass.rpc(g)
	
	var unique_kills := {}

	for g in _pending_external_kills:
		unique_kills[g["ID"]] = g

	for g in _pending_kills:
		unique_kills[g["ID"]] = g

	for g in unique_kills.values() :
		Kill(g)
		erase_grass.rpc(g)
	

		
	_pending_external_kills.clear()
	mutex.lock()
	thread_is_running = false
	mutex.unlock()




############

func get_free_id():
	var id:int
	if free_id_array.size()>0:
		return free_id_array.pop_back()
	else:
		id = grass_unique_id
		grass_unique_id += 1
		return id

func spawn_grass(pos):
	var newgrass = grass_dna.duplicate()
	newgrass["position"] = pos
	newgrass["light_index"] = get_lightIndex(pos)
	newgrass["ID"] = get_free_id()
	#grass_array.append(newgrass)
	grass_dict[newgrass["ID"]] = newgrass
	#grass_unique_id += 1
	


func Kill(grass):
	if grass_dict.has(grass["ID"]):
		free_id_array.append(grass["ID"])
		grass_dict.erase(grass["ID"])
		remove_from_world_bin(grass)
		
	



func get_lightIndex(pos):
	var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
	return World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)	
	 
	
	
'func Homeostasis(grass):
	grass["current_energy"] -= grass["Homeostasis_cost"]  * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if grass["current_energy"] < 0:
		Kill(grass)'


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

'func Reproduction(grass):
	if grass["current_energy"]  > 10:# reproduction_stock + energy_stock:
		var newpos = grass["position"] + Vector3(randf_range(-5,5),
											0,
											randf_range(-5,5)
											) 
		newpos.x = clamp(newpos.x ,-World.World_Size.x/2+1,World.World_Size.x/2-1 )
		newpos.z = clamp(newpos.z ,-World.World_Size.z/2+1,World.World_Size.z/2-1 )
		spawn_grass(newpos)
		grass["current_energy"] -= 8'
		
func _thread_reproduction(grass):
	if grass["current_energy"] > 10:
		var newpos = grass["position"] + Vector3(
			randf_range(-5, 5),
			0,
			randf_range(-5, 5)
		)
		newpos.x = clamp(newpos.x, -World.World_Size.x / 2 + 1, World.World_Size.x / 2 - 1)
		newpos.z = clamp(newpos.z, -World.World_Size.z / 2 + 1, World.World_Size.z / 2 - 1)
		var newgrass = grass_dna.duplicate()
		newgrass["position"] = newpos
		newgrass["light_index"] = get_lightIndex(newpos)
		_pending_spawns.append(newgrass)
		grass["current_energy"] -= 8	
		
			
func Cut(grass):
	Become_object.rpc_id(1,grass)
	_pending_external_kills.append(grass)
	#Kill(grass)
	
@rpc("any_peer","call_local") 
func Become_object(grass):
	if GlobalSimulationParameter.object_grass_number > max_grass_object :
		pass
	else :
		GlobalSimulationParameter.object_grass_number += 1
		var new_object = object_scene.instantiate()
		var pos = grass["position"]
		new_object.position.y = pos.y
		new_object.position.x = pos.x + randf_range(-1,1)
		new_object.position.z = pos.z + randf_range(-1,1)
		new_object.rotation.y = randf_range(deg_to_rad(0),deg_to_rad(360))
		get_parent().add_child(new_object, true)




################################ BIN GESTION

func put_in_world_bin(g):
	var bin_ID = 0
	var w_pos = World.get_PositionInGrid(g["position"],World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	if new_bin_ID < 0 or new_bin_ID >= World.bin_array.size():
		print("life out of world")
		remove_from_world_bin(g)
		return
	if bin_ID != new_bin_ID:
		remove_from_world_bin(g)
		#g["bin_ID"] = new_bin_ID
	if World.bin_array[new_bin_ID] == null:
		World.bin_array[new_bin_ID] = [g]
	else:	
		World.bin_array[new_bin_ID].append(g) 
	g["bin_ID"] = new_bin_ID

func remove_from_world_bin(g):
	if g["bin_ID"]:
		if World.bin_array[g["bin_ID"]].has(g):
			World.bin_array[g["bin_ID"]].erase(g)
			g["bin_ID"] = null



##########################MULTIMESH GESTION

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(g):
		$grass_multimesh.draw_new_grass(g)

@rpc("authority", "call_remote", "reliable") 
func erase_grass(g):
		$grass_multimesh.remove_grass(g)
	


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
