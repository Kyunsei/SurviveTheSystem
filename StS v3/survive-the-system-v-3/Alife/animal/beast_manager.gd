extends Node3D


#var grass_array = []
var beast_dict = {}
var beast_instance_dict = {}

var beast_unique_id = 0
var alifedata :Alifedata
var World : Node3D

@export var sheep_scene : PackedScene

var thread_beast: Thread
var mutex: Mutex = Mutex.new()
var thread_is_running: bool = false
var _pending_spawns: Array = []
var _pending_kills: Array = []
var _pending_external_kills: Array = []
var _pending_external_spawns: Array = []

#var _pending_light_changes: Dictionary = {}  # index -> new value
var free_id_array = []

var beast_dna = {
	"ID":0,
	"bin_ID":null,
	"Species": "sheep",
	"position":Vector3(),
	"current_energy": 0,
	"Homeostasis_cost":0.3,
	#"Photosynthesis_absorbtion": 1.0,
	#"light_index": []
}



func _ready() -> void:
	if multiplayer.is_server():
		thread_beast = Thread.new()
		alifedata = Alifedata.new()
		


func _update_on_thread():

	#World.add_value_in_each_tile(World.light_array,World.light_flux_in,0,World.light_max_value) #should be moved sommewhere else?
	_pending_spawns.clear()
	_pending_kills.clear()
	for g in beast_dict.values():
		#Photosynthesis(g)
		#_thread_reproduction(g)
		homeostasis(g)
	
	for b in beast_instance_dict.values():
		b.move()

	#print("end " + str(Time.get_ticks_msec() -ss))
	call_deferred("_on_work_finished")


func update():
	#start_thread()
	'for g in beast_dict.values():
		homeostasis(g)'
	for b in beast_instance_dict.values():
		#vision(b)
		vision(b)
		choose_action(b)
		homeostasis(b)

		#move(b)


func start_thread():
	mutex.lock()
	if thread_is_running:
		mutex.unlock()
		return
	thread_is_running = true
	mutex.unlock()
	
	thread_beast = Thread.new()
	thread_beast.start(_update_on_thread)

	

func _on_work_finished():
	thread_beast.wait_to_finish()  # Clean up

	var unique_spawn := {}
	
	for g in _pending_external_spawns:
		unique_spawn[g["ID"]] = g
	for g in _pending_spawns:
		unique_spawn[g["ID"]] = g

	for g in unique_spawn.values():
		g["ID"] = get_free_id()
		beast_dict[g["ID"]] = g
		get_parent().put_in_world_bin(g)
		draw_new_grass.rpc(g)
	
	var unique_kills := {}

	for g in _pending_external_kills:
		unique_kills[g["ID"]] = g
		
	for g in _pending_kills:
		unique_kills[g["ID"]] = g
	
	for g in unique_kills.values() :
		Kill(g)
		erase_grass.rpc(g)
	

	_pending_external_spawns.clear()	
	_pending_external_kills.clear()
	mutex.lock()
	thread_is_running = false
	mutex.unlock()

################

func choose_action(b):
	b.choose_action()

func move(b):
	b.direction = Vector3(randf_range(-1,1),0,randf_range(-1,1))
	b.position += b.direction * b.current_speed  #* GlobalSimulationParameter.simulation_speed
	b.position.x = clamp(b.position.x ,-World.World_Size.x/2,World.World_Size.x/2 )
	b.position.z = clamp(position.z ,-World.World_Size.z/2,World.World_Size.z/2 )

func vision(b):
	#got closest element in friend/danger and food
	for f in b.lifedata["Food_type"]:
		var food = view_closest(b.lifedata["Vision_range"],World.bin_sum_array[f],b,f)
		b.vision_food[f] = food  
	for d in b.lifedata["Danger_type"]:
		var danger = view_closest(b.lifedata["Vision_range"],World.bin_sum_array[d],b,d)
		b.vision_danger[d] = danger

	#return target


########VISION CODE



func view_closest(view_range,array_num,b,sp):
	var current_pos = b.position
	var closest = null
	var closest_in_bin =  null
	var closest_distance = INF

	var origin_x = 0#int(current_pos.x)
	var origin_y = 0#int(current_pos.y)
	var bin_index

	for r in range(view_range + 1):
		# Special case: center bin
		if r == 0:
			current_pos.x = b.position.x 
			current_pos.z = b.position.z
			bin_index = get_worldbin_index(current_pos)
			if bin_index and array_num[bin_index] >0:			
				closest_in_bin = find_closest(b.position, World.bin_array[bin_index],sp)
				var distance = b.position.distance_to(closest_in_bin.position)
				if distance < closest_distance:
					closest = closest_in_bin
					closest_distance = distance			
			
			if closest != null:
				break
			continue

		# Walk perimeter of square ring
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				current_pos.x = b.position.x + World.bin_size.x*dx
				current_pos.z = b.position.z + World.bin_size.z*dy
				bin_index = get_worldbin_index(current_pos)
				if bin_index and array_num[bin_index] >0:			
					closest_in_bin = find_closest(b.position, World.bin_array[bin_index],sp)
					var distance = b.position.distance_to(closest_in_bin.position)
					if distance < closest_distance:
						closest = closest_in_bin
						closest_distance = distance			
				#find_closest(b.position, World.bin_array[bin_index])
				#check_bin(origin_x + dx, origin_y + dy)
		for dy in range(-r + 1, r):
			for dx in [-r, r]:
				current_pos.x = b.position.x + World.bin_size.x*dx
				current_pos.z = b.position.z + World.bin_size.z*dy
				bin_index = get_worldbin_index(current_pos)
				if bin_index and array_num[bin_index] >0:			
					closest_in_bin = find_closest(b.position, World.bin_array[bin_index],sp)
					var distance = b.position.distance_to(closest_in_bin.position)
					if distance < closest_distance:
						closest = closest_in_bin
						closest_distance = distance
				#check_bin(origin_x + dx, origin_y + dy)



		if closest != null:
			break
	return closest



func get_worldbin_index(current_pos):
	var bin_index
	if current_pos.x > -World.World_Size.x/2  and current_pos.x < World.World_Size.x/2 :
		if current_pos.z > -World.World_Size.z/2  and current_pos.z < World.World_Size.z/2 :			
			var w_pos = World.get_PositionInGrid(current_pos,World.bin_size)
			bin_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
			if bin_index < World.bin_array.size():
				return bin_index
	return null







func find_closest(from_position: Vector3, array: Array,sp):
	var closest = null
	var closest_distance = INF
	
	for element in array:
		if element["Species"] == sp:
			var distance = from_position.distance_to(element["position"])
			if distance < closest_distance:
				closest_distance = distance
				closest = element
	return closest	
############

func get_free_id():
	var id:int
	if free_id_array.size()>0:
		return free_id_array.pop_back()
	else:
		id = beast_unique_id
		beast_unique_id += 1
		return id

@rpc("any_peer","call_local")
func add_grass(pos, sp):
	var newgrass = alifedata.build_lifedata(get_free_id(),pos,sp)
	_pending_spawns.append(newgrass)	
	#get_lightIndex(newgrass)

@rpc("any_peer","call_local")
func ask_for_adding_grass(pos, sp):
	var newgrass = alifedata.build_lifedata(get_free_id(),pos,sp)
	_pending_external_spawns.append(newgrass)

@rpc("any_peer","call_local")

func Kill_Beast(beast):
	print("DDDD")
	var ID = int(beast.name)
	'if beast_dict.has(ID):
		free_id_array.append(ID)
		beast_dict.erase(ID)
		#remove_from_world_bin(grass)
		
		#beast_instance_dict[grass["ID"]].queue_free()
		beast_instance_dict.erase(ID)
		#beast.queue_free()'

func Kill(grass):
	if beast_dict.has(grass["ID"]):
		free_id_array.append(grass["ID"])
		beast_dict.erase(grass["ID"])
		get_parent().remove_from_world_bin(grass)
		
		#beast_instance_dict[grass["ID"]].queue_free()
		beast_instance_dict.erase(grass["ID"])
		
	
'func get_lightIndex(grass):
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
				grass["light_index"].append(idx)'	 
	



func homeostasis_TRUE(grass):
	var area = 1# max(1,(grass["Photosynthesis_range"] * 2) * (grass["Photosynthesis_range"] * 2 ))
	grass["current_energy"] -= grass["Homeostasis_cost"] * area * GlobalSimulationParameter.simulation_speed 
	if grass["current_energy"] < 0:
		_pending_kills.append(grass)

func homeostasis(grass):
	var area = 1# max(1,(grass["Photosynthesis_range"] * 2) * (grass["Photosynthesis_range"] * 2 ))
	grass.current_energy -= 0.5 * GlobalSimulationParameter.simulation_speed 
	#if grass["current_energy"] < 0:
	#	_pending_kills.append(grass)

		
func _thread_reproduction(grass):
	if grass["current_energy"] > grass["Reproduction_cost"]*2:
		var newpos = grass["position"] + Vector3(
			randf_range(-grass["Reproduction_spread"], grass["Reproduction_spread"]),
			0,
			randf_range(-grass["Reproduction_spread"], grass["Reproduction_spread"])
		)
		newpos.x = clamp(newpos.x, -World.World_Size.x / 2 + 1, World.World_Size.x / 2 - 1)
		newpos.z = clamp(newpos.z, -World.World_Size.z / 2 + 1, World.World_Size.z / 2 - 1)
		add_grass(newpos, grass["Species"])

		grass["current_energy"] -= grass["Reproduction_cost"]	
		
	
func interact(grass,player):
	player.add_to_inventory(grass,1)
	_pending_external_kills.append(grass)	

			
func Cut(grass):
	#Become_object.rpc_id(1,grass)
	_pending_external_kills.append(grass)
	#Kill(grass)
	
'@rpc("any_peer","call_local") 
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
		get_parent().add_child(new_object, true)'

#########################

@rpc("any_peer","call_local")
func Spawn_Beast(new_position: Vector3,sp:Alifedata.enum_speciesID):
	var alife_scene : PackedScene
	match sp:
		Alifedata.enum_speciesID.SHEEP:
			alife_scene = sheep_scene
			var newlife = alife_scene.instantiate()
			var id = get_free_id()
			newlife.name = str(id)
			newlife.position = new_position #- Vector2(nal.size/2,nal.size/2)
			newlife.World = World #temp
			newlife.current_energy = 50
			add_child.call_deferred(newlife)	
			var newgrass = alifedata.build_lifedata(get_free_id(),new_position,sp)
			newlife.lifedata = newgrass
			beast_dict[id] = newgrass
			beast_instance_dict[id] = newlife
			get_parent().put_in_world_bin(newgrass)

			
			#_pending_spawns.append(newgrass)



			
	






##########################MULTIMESH GESTION

@rpc("authority", "call_remote", "reliable") 
func draw_new_grass(g):
	match g["Species"]:
		Alifedata.enum_speciesID.GRASS:
			$grass.draw_new_grass(g)
		Alifedata.enum_speciesID.TREE:
			$tree.draw_new_grass(g)
		Alifedata.enum_speciesID.BUSH:
			$bush.draw_new_grass(g)
@rpc("authority", "call_remote", "reliable") 
func erase_grass(g):
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
	var dict = beast_dict
	send_and_draw_array.rpc_id(peer_id, dict)

@rpc("any_peer","call_remote")
func send_and_draw_array(dict):
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
	if thread_beast and thread_beast.is_alive():
		thread_beast.wait_to_finish()
		
		
		
		
		
		
		
		
		
##################OLD



'func return_closest_target(b):
	var current_pos = b.position
	var bin_index: int
	var closest = null
	var closest_in_bin = null
	var closest_distance = INF
	for i in [-1,0,1]:
		for j in [-1,0,1]:
			current_pos.x = b.position.x + World.bin_size.x*i
			current_pos.z = b.position.z + World.bin_size.z*j		
			if current_pos.x > -World.World_Size.x/2  and current_pos.x < World.World_Size.x/2 :
				if current_pos.z > -World.World_Size.z/2  and current_pos.z < World.World_Size.z/2 :
					
					var w_pos = World.get_PositionInGrid(current_pos,World.bin_size)
					bin_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
					if bin_index < World.bin_array.size():
						if World.bin_array[bin_index]:
							closest_in_bin = find_closest(b.position, World.bin_array[bin_index])
							var distance = b.position.distance_to(closest_in_bin.position)
							if distance < closest_distance:
								closest = closest_in_bin
								closest_distance = distance
	return closest'
