extends ALIFE
class_name ALIFE_GRASS


func _init() -> void:
	moves = false

	species_name = "GRASS"
	#PHOT
	photosynthesis_on = true
	photo_layer_y = 0
	photo_range = 0
	photo_optimal_value = 1
	photo_optimal_width = 0.2
	
	#LIFECYCLE/DUP
	duplication_range = 50
	init_size = 0.5
	seed_energy = 50
	seed_biomass = 5
	max_life_cycle = 3
	max_health = 5
	growth_cost = [50,50,50,50] #Should be size of max_life
	growth_rate = 0.4

func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)

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
			_energy -= g_cost



	#--------maintain cost
		_energy += -0.7  *  dt * sim_speed  # - (side * side - side) *dt #* active_alife_array[i]
		
		#--------DEATH
		if _energy < 0 or current_health[i] <0 :
			alive_array[i] = 0
			
		#--------Duplicate
		if _energy >= seed_energy*1.5:
			local_pending_spawn_id.append(i)
			_energy -= seed_energy
			
			
			
			
		#update energy
		current_energy_array[i] = _energy
		
		
		
		
		
			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id

func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
	
	var d_range:= duplication_range
	for i in pending_spawn_id:
		var newpos := pick_random_position(Vector3(d_range,0,d_range),position_array[i])
		if photosynthesis_on and !has_seed:
			var s_c := get_cell_id(newpos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
			var s_c_up := s_c + world.SUN_GRID_W
			if world.SUN_stamp[s_c] > 0 or world.SUN_stamp[s_c_up] > 0:
				continue
		Build_New_Life(newpos,seed_energy,0, current_color[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	



	pending_spawn_id.clear()
	pending_remove_id.clear()
