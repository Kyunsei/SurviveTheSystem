extends Alife

var target: Node3D
var alife_manager: Node3D
var direction : Vector3
var speed = 10

func _ready() -> void:
	print("hello Mr sheep")
	size = Vector3(1,1,1) #Temporary...
	species = "sheep"
	max_energy = 100
	alife_manager = get_parent()

func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			Homeostasis()
			if current_energy < 500:
				target = checkfood_around()
					
			if target:
				if position.distance_to(target.position) < 2:
					Eat(target)
					target = null
				else:
					GoTo(target,delta)
					#print(target)
				
			else:
				direction = Vector3(0,0,0)
				#print(direction)
			Reproduction()


func Homeostasis():
	current_energy -= 0.2 * size.x * size.z * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if current_energy < 0:
		pass
		#Die()


func find_closest(from_position: Vector3, array: Array) -> Node3D:
	var closest = null
	var closest_distance = INF
	
	for element in array:
		var distance = from_position.distance_to(element.position)
		if distance < closest_distance:
			closest_distance = distance
			closest = element
	
	return closest	

func checkfood_around():
	var targets = alife_manager.get_alife_in_area(position,size)
	if targets.size() > 0 :
		return find_closest(position,targets)
													
func GoTo(t,delta):
	direction = (t.position - position).normalized()
	global_position += direction * speed * delta * GlobalSimulationParameter.simulation_speed

func Eat(t):
	current_energy += t.current_energy
	t.current_energy = 0
	t.Die()

func Reproduction():
	if current_energy > 400:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-15,15),
											0,
											randf_range(-15,15)
											) 
		#var scene = load(get_scene_file_path())
		alife_manager.Spawn_life_without_pool.rpc_id(1,newpos, "sheep")
		#reproduction_asked.emit(newpos,"sheep")
		current_energy -= 400
		
