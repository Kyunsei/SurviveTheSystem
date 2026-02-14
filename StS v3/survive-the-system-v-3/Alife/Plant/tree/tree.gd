extends Alife

var Photosynthesis_absorbtion = 1.0
var light_index = []
var Photosynthesis_range = 3
var species = "tree"
var total_light_tile = 0
var alife_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	size = Vector3(1,1,1) #Temporary...
	alife_manager = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			if isActive:
				Photosynthesis()
				Reproduction()
				Homeostasis()

func Desactivate():
	hide()
	LifeManager.current_life_count_by_species[2] -= 1

func Die():
	#print("heelo")
	Desactivate()

func special_activation():
	var pos = position
	total_light_tile = 0
	for i in range(-Photosynthesis_range,Photosynthesis_range):
		for j in range(-Photosynthesis_range,Photosynthesis_range):
			total_light_tile += 1
			pos.x = position.x + i * World.light_tile_size.x
			pos.z = position.z + j * World.light_tile_size.z
			if pos.x <= -World.World_Size.x/2 or pos.x >= World.World_Size.x/2:
				return
			if pos.z <= -World.World_Size.z/2 or pos.z >= World.World_Size.z/2:
				return
				
			var w_pos = World.get_PositionInGrid(pos,World.light_tile_size)
			var idx =  World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
			light_index.append(idx)
	#light_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.light_tile_size)
	

func Homeostasis():
	current_energy -= 0.8 * total_light_tile * size.x * size.z * GlobalSimulationParameter.simulation_speed
	#current_energy = max(0,current_energy)
	if current_energy < 0:
		
		Die()

func Photosynthesis():
	
	for l_i in light_index:
		if l_i <  World.light_array.size():
			var energy_absorbed = World.light_array[l_i] * Photosynthesis_absorbtion * GlobalSimulationParameter.simulation_speed 
			energy_absorbed = min(World.light_array[l_i],energy_absorbed)
			#print(energy_absorbed)
			#print(energy_absorbed)
			if energy_absorbed <= 0:
				return
			current_energy += energy_absorbed
			var shadow_effect = 1.0
			World.light_array[l_i] = max(World.light_array[l_i]-shadow_effect,0)
			#print(World.light_array[light_index])
func Reproduction():
	if current_energy > 200:# reproduction_stock + energy_stock:
		var newpos = position + Vector3(randf_range(-15,15),
											0,
											randf_range(-15,15)
											) 
		#var scene = load(get_scene_file_path())
		newpos.x = clamp(newpos.x ,-World.World_Size.x/2+1,World.World_Size.x/2-1 )
		newpos.z = clamp(newpos.z ,-World.World_Size.z/2+1,World.World_Size.z/2-1 )
		alife_manager.Spawn_life_without_pool.rpc_id(1,newpos, "tree")

		#reproduction_asked.emit(newpos,"tree")
		current_energy -= 180
		
		
