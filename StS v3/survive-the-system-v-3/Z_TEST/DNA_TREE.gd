extends TESTDNA
class_name TREE_DNA


func _init() -> void:
	sprite = preload("res://Alife/Plant/tree/tree.png")



func run_chunk_simulation( start: int, end: int,local_id:int, dt: float) -> void:
	dt = 0.16 * 1 #TODO
	var dup_on := alifemanager.duplicate_on
	var homeo_on := alifemanager.homeostasis_on
	#var visu_on := alifemanager.visualisation_on
	var photo_on := alifemanager.photosynthesis_on
	var agent_photo_calculate := alifemanager.agent_calculated_photo_value
	var remove_on := alifemanager.remove_on
	var grow_on := alifemanager.grow_on
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array

									

	if !photo_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()

			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue	
			var _energy:= current_energy_array[i]
			if _energy < 5:		
				current_energy_array[i] += (1) * dt	
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									
	if photo_on:

		var global_photo_rate := alifemanager.current_global_photosynthesis_rate
		var sun_grid := world.SUN_GRID 
		var photo_rate = alifemanager.photo_absorption_rate
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue		
			var _energy:= current_energy_array[i]
			if _energy < 5:
				var sun_c := current_worldpos_cell_id[i]
				#var total := global_photo_rate[sun_c]
				var r:= photo_range
				var total := 0.0
				var ry := 0
				var d:= global_photo_rate[sun_c]
				if !agent_photo_calculate or r==0:
					current_energy_array[i] += ( sun_grid[sun_c] * photo_rate *  dt) /   maxf(d, photo_rate) 
				else:
						for off in offsets[r * (RY_MAX + 1) + ry]:
								var cc := sun_c + off
								if cc >= global_photo_rate.size():
									continue
								var d2 := global_photo_rate[cc]
								if d2 > 1e-6:
									total += world.SUN_GRID[cc] * photo_rate/ maxf(d2, photo_rate)  	
						current_energy_array[i] += total * dt
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									
	
	
	if homeo_on:

		var side := 2 * photo_range + 1 #not account of y dimension
		for i in range(start, end):
			var _energy:= current_energy_array[i]

			#var t := Time.get_ticks_usec()
			_energy += -0.5  * dt # - (side * side - side) *dt #* active_alife_array[i]
			if _energy < 0 :
				alive_array[i] = 0
			current_energy_array[i] = _energy
		#photo_rate_per_chunk[local_id] = local_photo_rate
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

				
	if grow_on:	
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			var ei:= current_energy_array[i]
			var cls := current_life_state[i]
			current_age[i] += 1
			if cls <30:
				if ei > 3:
					current_life_state[i] += 1
					current_energy_array[i] -= 3
					current_size[i]+= 1.
					current_biomass[i] += 2
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

			#current_age[i]+=1
	if dup_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			var _energy:= current_energy_array[i]
			if _energy >= 5:
				local_pending_spawn_id.append(i)
				_energy -= 5
			current_energy_array[i] = _energy
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									


		spawn_per_chunk[local_id] = local_pending_spawn_id
	if remove_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				local_pending_remove_id.append(i)
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

		remove_per_chunk[local_id] = local_pending_remove_id
