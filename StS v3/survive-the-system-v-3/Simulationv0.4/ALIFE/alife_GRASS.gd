extends ALIFE
class_name ALIFE_GRASS


func _init() -> void:
	photosynthesis_on = true
	duplication_range = 10
	init_size = Vector3(1.3,1.,1.3)
	

func run_chunk_simulation( start: int, end: int,local_id:int, delta: float, sim_speed:float) -> void:
	var dt := 0.16 * 1 #TODO
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)

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
			continue
		var _energy:= current_energy_array[i]
		
		#EAT
		# Photosynthesis (cached per cell for this frame)
		if _energy < 10:
			#_energy += photo(i,sun_W,sun_stamp, sun_grid) * dt

			var sun_c := current_sungrid_id[i]
			var sun_c_up := sun_c + sun_W #WORK ONLY IF THERE IS A LAYER ABOVE
			var d:= sun_stamp[sun_c]
			var d_up := sun_stamp[sun_c_up] +1
			value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
			var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
			_energy += value2 /maxf(d, photo_rate) *dt

		#maintain cost
		_energy += -0.7  * dt # - (side * side - side) *dt #* active_alife_array[i]
		
		#DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
		#Duplicate
		if _energy >= 8:
			local_pending_spawn_id.append(i)
			_energy -= 5
		#update energy
		current_energy_array[i] = _energy	
		
		#CHECK to free entity
		if alive_array[i] == 0 and active_alife_array[i] == 1:
			local_pending_remove_id.append(i)
			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id




#TEST
func photo(i:int,sun_W:int,sun_stamp:PackedFloat32Array, sun_grid:PackedFloat32Array):
	var photo_rate:= 1.0
	var sun_c := current_sungrid_id[i]
	var sun_c_up := sun_c + sun_W #WORK ONLY IF THERE IS A LAYER ABOVE
	var d:= sun_stamp[sun_c]
	var d_up := sun_stamp[sun_c_up] +1
	var value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
	var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
	return value2 /maxf(d, photo_rate) 
