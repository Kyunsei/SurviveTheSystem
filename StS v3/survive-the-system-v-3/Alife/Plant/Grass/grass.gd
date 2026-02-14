extends Alife
@export var object_scene : PackedScene

var Photosynthesis_absorbtion = 1.0
var light_index : int
var species = "grass"
@export var max_grass_object = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = Vector3(1,1,1) #Temporary...
	


func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			if isActive:
				Photosynthesis()
				Reproduction()
				Homeostasis()




func Die():
	#print("heelo")
	Desactivate()

func special_activation():
	var w_pos = World.get_PositionInGrid(position,World.light_tile_size)
	light_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
	

func Homeostasis():
	current_energy -= 0.3 * size.x * size.z * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if current_energy < 0:
		Die()

func Photosynthesis():

	if light_index <  World.light_array.size():
		var energy_absorbed = World.light_array[light_index] * Photosynthesis_absorbtion * GlobalSimulationParameter.simulation_speed 
		energy_absorbed = min(World.light_array[light_index],energy_absorbed)
		#print(energy_absorbed)
		if energy_absorbed <= 0:
			return
		current_energy += energy_absorbed
		var shadow_effect = 1.0
		World.light_array[light_index] = max(World.light_array[light_index]-shadow_effect,0)
		#print(World.light_array[light_index])

func Reproduction():
	if current_energy > 10:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-5,5),
											0,
											randf_range(-5,5)
											) 
		#var scene = load(get_scene_file_path())
		newpos.x = clamp(newpos.x ,-World.World_Size.x/2+1,World.World_Size.x/2-1 )
		newpos.z = clamp(newpos.z ,-World.World_Size.z/2+1,World.World_Size.z/2-1 )

		reproduction_asked.emit(newpos,"grass")
		current_energy -= 8
		
func Cut():
	Become_object.rpc_id(1)
	Die()
	
@rpc("any_peer","call_local") 
func Become_object():
	if GlobalSimulationParameter.object_grass_number > max_grass_object :
		pass
	else :
		GlobalSimulationParameter.object_grass_number += 1
		var new_object = object_scene.instantiate()
		new_object.position.y = position.y
		new_object.position.x = position.x + randf_range(-1,1)
		new_object.position.z = position.z + randf_range(-1,1)
		new_object.rotation.y = randf_range(deg_to_rad(0),deg_to_rad(360))
		get_parent().add_child(new_object, true)
