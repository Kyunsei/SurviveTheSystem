extends ALIFE
class_name ALIFE_GLOWBERRY


func _init() -> void:


	species_name = "GLOWBERRY"

	#Rendering
	sprite = preload("res://Alife/Plant/Bush/berry-Sheet.png")
	hframes = 5
	vframes =2
	colour =Color(0.525, 0.114, 0.635, 1.0)
	
	#PHOT0
	photosynthesis_on = true
	photo_range = 2
	photo_layer_y = 0
	photo_optimal_value = 1
	photo_optimal_width = 0.2
	
	#LIFECYCLE/DUP
	duplication_range = 1
	init_size = 4
	seed_energy = 50
	seed_biomass = 5
	max_life_cycle = 5
	growth_cost = [50,50,50,50,50,50] #Should be size of max_life+1
	growth_rate = 0.0
	has_seed = true  #just allow to spam even if not light available


func run_chunk_simulation( start: int, end: int,local_id:int, dt: float, sim_speed:float) -> void:
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	
	var field_cell_size := alifemanager.field_cell_size
	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	#var H := alifemanager.GRID_H
	#var D := alifemanager.GRID_D
	var sun_stamp := world.SUN_stamp
	var sun_grid := world.SUN_GRID
	var sun_W := world.SUN_GRID_W
	var photo_rate := 1.0
	var value:= 0.0


	#Photosynthesis(start,end,dt)
	
	for i in range(start, end):
		if active_alife_array[i] == 0:
			continue
		if alive_array[i] == 0:
			if active_alife_array[i] == 1:
				var b = current_biomass[i]
				b -= 0.1 * dt *sim_speed
				current_biomass[i] = b
				if b < 0:
					local_pending_remove_id.append(i)
				continue
		
		var _energy:= current_energy_array[i]
		
		#--------EAT
		# Photosynthesis (cached per cell for this frame)
		if _energy < seed_energy*2:
			#_energy += photo(i,sun_W,sun_stamp, sun_grid) * dt

			var sun_c := current_sungrid_id[i]
			var sun_c_up := sun_c + sun_W #WORK ONLY IF THERE IS A LAYER ABOVE
			var d:= sun_stamp[sun_c]
			var d_up := sun_stamp[sun_c_up] +1
			value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
			var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
			_energy += value2 /maxf(d, photo_rate)  *  dt * sim_speed
	
	#--------Growth
		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
	
		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += 5
			current_life_state[i] +=1
			if lifecycle != max_life_cycle:
				_energy -= g_cost



	#--------maintain cost
		_energy += -0.7  *  dt * sim_speed  # - (side * side - side) *dt #* active_alife_array[i]
		
		#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
		#--------Duplicate
		'if _energy >= seed_energy*1.5:
			local_pending_spawn_id.append(i)
			_energy -= seed_energy'
			
			
			
			
		#update energy
		current_energy_array[i] = _energy
		
		
		
		
		
			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


			
			

func Interact(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])
	#print(current_life_state[i],max_life_cycle)
	if current_life_state[i] == max_life_cycle:
		current_life_state[i] -= 1
		current_energy_array[i] -= seed_energy
		pending_spawn_id.append(i)
