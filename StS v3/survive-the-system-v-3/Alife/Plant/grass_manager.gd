extends Node3D


###########################
#
#
# HERE GRASS MEANS PLANT !!!!!!!!! just dont want ot change it everywhere
#
#
#
#############################

#var grass_array = []
var grass_dict = {}
var grass_unique_id = 0
var alifedata :Alifedata
var World : Node3D

@export var max_grass_object = 100
@export var object_scene : PackedScene

var thread: Thread
var mutex: Mutex = Mutex.new()
var thread_is_running: bool = false
var _pending_spawns: Array = []
var _pending_kills: Array = []
var _pending_external_kills: Array = []
var _pending_external_spawns: Array = []
var _pending_update: Array = []

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
		alifedata = Alifedata.new()
		


func _update_on_thread(delta):
	#print("Thread start — grass count: ", grass_dict.size())
	#var ss = Time.get_ticks_msec() 
	#var newvalue = World.light_flux_in * GlobalSimulationParameter.simulation_speed * delta
	#print(newvalue)
	#var newmaxvalue = World.light_max_value * GlobalSimulationParameter.simulation_speed 
	if GlobalSimulationParameter.simulation_speed > 0:
		World.add_value_in_each_tile(World.light_array,World.light_flux_in,0,World.light_max_value) #should be moved sommewhere else?
		_pending_spawns.clear()
		_pending_kills.clear()
		#_pending_light_changes.clear()	
		for g in grass_dict.values():
			if g["Alive"]==1 :
				if  g["current_life_state"]> 0:
					Photosynthesis(g,delta)
					Reproduction(g,delta)
					Homeostasis(g,delta)
					Growth(g,delta)
				else:
					Germination(g)
					if g["current_life_state"] == 0:
						g["Alive"] = 0
			else:
				Decompose(g,delta)

	#print("end " + str(Time.get_ticks_msec() -ss))
	call_deferred("_on_work_finished")

func update(delta):
	start_thread(delta)
	#_update_on_thread()
	'for g in grass_array:
		Photosynthesis(g)
		Reproduction(g)
		Homeostasis(g)'



func start_thread(delta):
	mutex.lock()
	if thread_is_running:
		mutex.unlock()
		#print("Already running!")
		return
	thread_is_running = true
	mutex.unlock()
	
	thread = Thread.new()
	thread.start(_update_on_thread.bind(delta))

	

func _on_work_finished():
	thread.wait_to_finish()  # Clean up

	var unique_spawn := {}
	
	for g in _pending_external_spawns:
		unique_spawn[g["ID"]] = g
	for g in _pending_spawns:
		unique_spawn[g["ID"]] = g

	for g in unique_spawn.values():
		g["ID"] = get_free_id()
		grass_dict[g["ID"]] = g
		#g.ID = get_free_id()
		#grass_dict[g.ID] = g
		get_parent().put_in_world_bin(g)
		if 	get_parent().current_life_count_by_species.has(g["Species"]):
			get_parent().current_life_count_by_species[g["Species"]] += 1
		else:
			get_parent().current_life_count_by_species[g["Species"]] = 1

	draw_new_grass.rpc(unique_spawn)
	
	var unique_kills := {}

	for g in _pending_external_kills:
		unique_kills[g["ID"]] = g
		#unique_kills[g.ID] = g

	for g in _pending_kills:
		unique_kills[g["ID"]] = g
		#unique_kills[g.ID] = g

	for g in unique_kills.values() :
		Kill(g)
	erase_grass.rpc(unique_kills)
	
	send_update_batch(_pending_update)
	#update_drawn_grass.rpc(_pending_update)
		
	_pending_update.clear()
	_pending_external_spawns.clear()	
	_pending_external_kills.clear()
	mutex.lock()
	thread_is_running = false
	mutex.unlock()



	
func send_update_batch(batch):
	var CHUNK_SIZE = 100  # tune this
	
	for i in range(0, batch.size(), CHUNK_SIZE):
		var slice = batch.slice(i, i + CHUNK_SIZE)
		update_drawn_grass.rpc(slice)
############

func get_free_id():
	var id:int
	if free_id_array.size()>0:
		return free_id_array.pop_back()
	else:
		id = grass_unique_id
		grass_unique_id += 1
		return id

func spawn_grass(pos, sp):
	#var newgrass = grass_dna.duplicate()
	var newgrass = alifedata.build_lifedata(get_free_id(),pos,sp)
	#newgrass["position"] = pos
	get_lightIndex(newgrass)
	#newgrass["ID"] = get_free_id()
	#grass_dict[newgrass["ID"]] = newgrass
	_pending_spawns.append(newgrass)
	
	
	#var newgrass:= Alifedata.new(get_free_id(),pos,Alifedata.enum_speciesID.GRASS)
	#newgrass.light_index = get_lightIndex(pos)
	#grass_dict[newgrass.ID] = newgrass

func ask_for_spawn_grass(pos, sp):
	#var newgrass = grass_dna.duplicate()
	var newgrass = alifedata.build_lifedata(get_free_id(),pos,sp)
	#newgrass["position"] = pos
	get_lightIndex(newgrass)
	#newgrass["ID"] = get_free_id()
	#grass_dict[newgrass["ID"]] = newgrass
	_pending_external_spawns.append(newgrass)
	
func Ask_for_spawn(grass):
	get_lightIndex(grass)
	_pending_external_spawns.append(grass)		
		

func Kill(grass):
	if grass_dict.has(grass["ID"]):
		free_id_array.append(grass["ID"])
		grass_dict.erase(grass["ID"])
		get_parent().remove_from_world_bin(grass)
		if 	get_parent().current_life_count_by_species.has(grass["Species"]):
			get_parent().current_life_count_by_species[grass["Species"]] -= 1
		#	get_parent().current_life_count_by_species[g["Species"]] = 1



func get_lightIndex(grass):
	var pos = grass["position"]
	grass["light_index"] = []
	if grass["Photosynthesis_range"] == 0:
		var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
		grass["light_index"].append(World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size))
	else:
		for i in range(-grass["Photosynthesis_range"],grass["Photosynthesis_range"]):
			for j in range(-grass["Photosynthesis_range"],grass["Photosynthesis_range"]):
				pos.x = grass["position"].x + i * World.light_tile_size.x
				pos.z = grass["position"].z + j * World.light_tile_size.z
				if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
					return
				if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
					return
					
				var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
				var idx =  World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
				grass["light_index"].append(idx)	 

'func Homeostasis(grass):
	grass["current_energy"] -= grass["Homeostasis_cost"]  * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if grass["current_energy"] < 0:
		Kill(grass)'


func Decompose(grass,delta):
	#var area = max(1,(grass["Photosynthesis_range"] * 2) * (grass["Photosynthesis_range"] * 2 ))
	grass["current_energy"] -= 10000 * GlobalSimulationParameter.simulation_speed   *delta
	#print(grass)
	if grass["current_energy"] < 0:
		_pending_kills.append(grass)

func Homeostasis(grass, delta):
	var area = max(1,(grass["Photosynthesis_range"] * 2) * (grass["Photosynthesis_range"] * 2 ))
	grass["current_energy"] -= grass["Homeostasis_cost"] * area * GlobalSimulationParameter.simulation_speed * delta
	if grass["current_energy"] < 0:
		grass["Alive"] = 0
		#_pending_kills.append(grass)
	#print("cost: " +str(grass["Homeostasis_cost"] * area * GlobalSimulationParameter.simulation_speed * delta))
	#grass.current_energy -= grass.Homeostasis_cost * GlobalSimulationParameter.simulation_speed
	#if grass.current_energy < 0:
	#	_pending_kills.append(grass)

func Photosynthesis(grass,delta):
	var tt = 0
	var time_value = grass["Photosynthesis_absorbtion"] * GlobalSimulationParameter.simulation_speed * delta
	for l_i in grass["light_index"]:		
		if l_i <  World.light_array.size():
			var energy_absorbed = World.light_array[l_i] * time_value
			#energy_absorbed = min(World.light_array[l_i],energy_absorbed)
			if energy_absorbed <= 0:
				return
			grass["current_energy"]  += energy_absorbed
			var shadow_effect = 1.0
			World.light_array[l_i] = max(World.light_array[l_i]-shadow_effect,0)
			tt += energy_absorbed
	#print(tt)
	#print(grass["current_energy"]) #* area * GlobalSimulationParameter.simulation_speed * delta)

'func Photosynthesis_old(grass):
	
	if grass["light_index"] <  World.light_array.size():
		var energy_absorbed = World.light_array[grass["light_index"]] * grass["Photosynthesis_absorbtion"] * GlobalSimulationParameter.simulation_speed 
		energy_absorbed = min(World.light_array[grass["light_index"]],energy_absorbed)
		#print(energy_absorbed)
		if energy_absorbed <= 0:
			return
		grass["current_energy"] += energy_absorbed
		var shadow_effect = 1.0
		World.light_array[grass["light_index"]] = max(World.light_array[grass["light_index"]]-shadow_effect,0)
		#print(World.light_array[light_index])'
		
		
	
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
		
func Reproduction(grass,delta):
		if grass["current_energy"] > grass["Reproduction_cost"]*2:
			var newpos = grass["position"] + Vector3(
				randf_range(-grass["Reproduction_spread"], grass["Reproduction_spread"]),
				0,
				randf_range(-grass["Reproduction_spread"], grass["Reproduction_spread"])
			)
			newpos.x = clamp(newpos.x, -World.World_Size.x / 2 + 1, World.World_Size.x / 2 - 1)
			newpos.z = clamp(newpos.z, -World.World_Size.z / 2 + 1, World.World_Size.z / 2 - 1)
			spawn_grass(newpos, grass["Species"])
			#var newgrass = grass_dna.duplicate()
			#newgrass["position"] = newpos
			#newgrass["light_index"] = get_lightIndex(newpos)
			#_pending_spawns.append(newgrass)
			grass["current_energy"] -= grass["Reproduction_cost"]	

func Germination(g):
	var area = max(1,(g["Photosynthesis_range"] * 2) * (g["Photosynthesis_range"] * 2 ))
	var light_available = 0
	for l_i in g["light_index"]:		
		if l_i <  World.light_array.size():
			if World.light_array[l_i] > 0:
				light_available += 1
	
	if light_available == area:
		print("Germinate")
		g["current_life_state"] = 1
			

func Growth(g,delta):
	#if g["current_energy"] % 5 == 0:
	if g["current_life_state"]*3 < g["current_energy"]:	
		g["current_life_state"] += 1
		#_pending_update.append([g["ID"],g["current_energy"],g["Species"]])


	


	
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
		new_object.current_energy = grass["current_energy"]
		get_parent().add_child(new_object, true)




	#if g.bin_ID:
	#	if World.bin_array[g.bin_ID].has(g):
	#		World.bin_array[g.bin_ID].erase(g)
	#		g.bin_ID = null


##########################MULTIMESH GESTION

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(g_array):
	for g in g_array.values():

		match g["Species"]:
			Alifedata.enum_speciesID.GRASS:
				$grass.draw_new_grass(g)
			Alifedata.enum_speciesID.TREE:
				$tree.draw_new_grass(g)
			Alifedata.enum_speciesID.BUSH:
				$bush.draw_new_grass(g)
			
@rpc("authority", "call_remote", "reliable") 			
func update_drawn_grass(g_array):
	for info in g_array:
			match info[2]:
				Alifedata.enum_speciesID.GRASS:
					$grass.update_drawn_grass(info)
				Alifedata.enum_speciesID.TREE:
					$tree.update_drawn_grass(info)
				Alifedata.enum_speciesID.BUSH:
					$bush.update_drawn_grass(info)
	

@rpc("authority", "call_remote", "reliable") 
func erase_grass(g_array):
	for g in g_array.values():

		#$grass_multimesh.remove_grass(g)
		match g["Species"]:
			Alifedata.enum_speciesID.GRASS:
				$grass.remove_grass(g)
			Alifedata.enum_speciesID.TREE:
				$tree.remove_grass(g)
			Alifedata.enum_speciesID.BUSH:
				$bush.remove_grass(g)

@rpc("any_peer","call_remote")
func draw_multimesh_on_client(peer_id):
	var dict = grass_dict
	send_and_draw_array.rpc_id(peer_id, dict)

@rpc("any_peer","call_remote")

func send_and_draw_array(dict):
	#$grass.multimesh.visible_instance_count = 0
	#$tree.multimesh.visible_instance_count = 0
	#$bush.multimesh.visible_instance_count = 0
	$grass.init()
	$tree.init()
	$bush.init()

	for g in dict.values():
		match g["Species"]:
			Alifedata.enum_speciesID.GRASS:
				$grass.draw_new_grass(g)
			Alifedata.enum_speciesID.TREE:
				$tree.draw_new_grass(g)
			Alifedata.enum_speciesID.BUSH:
				$bush.draw_new_grass(g)			
	#$grass_multimesh.draw_all_grass(dict)	




func _exit_tree() -> void:
	if thread and thread.is_alive():
		thread.wait_to_finish()
