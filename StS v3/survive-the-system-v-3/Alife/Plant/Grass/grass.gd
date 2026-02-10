extends Alife

var Photosynthesis_absorbtion = 1.0
var light_index : int
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = Vector3(1,1,1) #Temporary...
	species = "grass"


# Called every frame. 'delta' is the elapsed time since the previous frame.
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
	current_energy -= 0.2 * size.x * size.z * GlobalSimulationParameter.simulation_speed
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
		World.light_array[light_index] = max(World.light_array[light_index]-energy_absorbed,0)

func Reproduction():
	if current_energy > 10:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-5,5),
											0,
											randf_range(-5,5)
											) 
		#var scene = load(get_scene_file_path())
		reproduction_asked.emit(newpos,"grass")
		current_energy -= 8
		
		
