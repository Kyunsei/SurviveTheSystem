extends Alife

var Photosynthesis_absorbtion = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = Vector3(1,1,1) #Temporary...


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			Homeostasis()
			Photosynthesis()
			Reproduction()


func Die():
	Desactivate()

func Homeostasis():
	current_energy -= 0.2 * size.x * size.z * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if current_energy <= 0:
		Die()

func Photosynthesis():
	var w_pos = World.get_PositionInGrid(position,World.light_tile_size)
	var w_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
	var energy_absorbed = World.light_array[w_index] * Photosynthesis_absorbtion * GlobalSimulationParameter.simulation_speed 
	energy_absorbed = min(World.light_array[w_index],energy_absorbed)
	current_energy += energy_absorbed
	World.light_array[w_index] = max(World.light_array[w_index]-energy_absorbed,0)

func Reproduction():
	print(current_energy)
	if current_energy > 10:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-5,5),
											0,
											randf_range(-5,5)
											) 
		var scene = load(get_scene_file_path())
		reproduction_asked.emit(newpos,scene)
		current_energy -= 8
		
		
