extends Alife

var target
var alife_manager: Node3D
var direction : Vector3
var speed = 10
var species = "sheep"
var wandertimer = 0
func _ready() -> void:
	print("hello Mr sheep")
	size = Vector3(1,1,1) #Temporary...

	max_energy = 1000
	alife_manager = get_parent()

func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			if current_energy < 500:
				target = return_closest_target() #may eat sheep too...
					
			if target:
				if position.distance_to(target.position) < 2:
					Eat(target)
					target = null
				else:
					GoTo(target,delta)
					#print(target)
				
			else:
				wandertimer -= delta
				if wandertimer <= 0:
					wandertimer = 5
					direction = Vector3(randf_range(-1,1),0,randf_range(-1,1))
				global_position += direction * speed * delta * GlobalSimulationParameter.simulation_speed
				global_position.x = clamp(global_position.x ,-World.World_Size.x/2,World.World_Size.x/2 )
				global_position.z = clamp(global_position.z ,-World.World_Size.z/2,World.World_Size.z/2 )
				#print(direction)
			Reproduction()
			Homeostasis()

func Activate():
	#show()
	isActive = true
	#put_in_world_bin()
	#special_activation()
	
func Die():
	pass
	Desactivate()
	queue_free()

func Desactivate():
	hide()
	LifeManager.current_life_count_by_species[1] -= 1
	#isActive = false
	#remove_from_world_bin()
	#desactivated.emit()
	#LifeManager.life_inactive_index.append(ID)

func Homeostasis():
	current_energy -= 5 * size.x * size.z * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if current_energy < 0:
		pass
		Die()


func find_closest(from_position: Vector3, array: Array):
	var closest = null
	var closest_distance = INF
	
	for element in array:
		var distance = from_position.distance_to(element["position"])
		if distance < closest_distance:
			closest_distance = distance
			closest = element
	return closest	

func checkfood_around():
	var targets = alife_manager.get_alife_in_area(position,size)
	if targets:
		if targets.size() > 0 :
			return find_closest(position,targets)




													
func GoTo(t,delta):
	direction = (t.position - position).normalized()
	global_position += direction * speed * delta * GlobalSimulationParameter.simulation_speed
	global_position.x = clamp(global_position.x ,-World.World_Size.x/2,World.World_Size.x/2 )
	global_position.z = clamp(global_position.z ,-World.World_Size.z/2,World.World_Size.z/2 )
func Eat(t):
	current_energy += t["current_energy"]
	t["current_energy"]= 0
	#t.Die()
	alife_manager.get_node("Grass_Manager")._pending_external_kills.append(t)


func return_closest_target():
	var current_pos = position
	var bin_index: int
	var closest = null
	var closest_in_bin = null
	var closest_distance = INF
	for i in [-1,0,1]:
		for j in [-1,0,1]:
			current_pos.x = position.x + World.bin_size.x*i
			current_pos.z = position.z + World.bin_size.z*j		
			if current_pos.x > -World.World_Size.x/2 and current_pos.x < World.World_Size.x/2:
				if current_pos.z > -World.World_Size.z/2 and current_pos.z < World.World_Size.x/2:
					
					var w_pos = World.get_PositionInGrid(current_pos,World.bin_size)
					bin_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
					
					if World.bin_array[bin_index]:
						closest_in_bin = find_closest(position, World.bin_array[bin_index])
						var distance = position.distance_to(closest_in_bin.position)
						if distance < closest_distance:
							closest = closest_in_bin
							closest_distance = distance
	return closest



func Reproduction():
	if current_energy > 400:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-15,15),
											0,
											randf_range(-15,15)
											) 
		#var scene = load(get_scene_file_path())
		alife_manager.Spawn_life_without_pool.rpc_id(1,newpos, "sheep")
		#reproduction_asked.emit(newpos,"sheep")
		current_energy -= 300
		
