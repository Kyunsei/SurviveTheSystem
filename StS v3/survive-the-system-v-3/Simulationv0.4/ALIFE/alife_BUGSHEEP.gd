extends ALIFE
class_name ALIFE_BUGSHEEP


func _init() -> void:
	photosynthesis_on = false
	init_size = 4.0
	species_name = "BUGSHEEP"
	sprite =preload("res://Alife/animal/Herbivor/Sheep/SHEEP-Sheet.png")
	hframes = 3
	vframes=2
	colour = Color(0.772, 0.772, 0.772, 1.0)
	
	max_energy = 2500
	max_speed = 30.

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 600
	seed_biomass = 2000
	max_life_cycle = 2
	growth_cost = [1000,1000,1000] #Should be size of max_life+1
	growth_rate = 0.5	
	
	
	#Flock par
	#contact par
	view_radius = 19.0	 #need to be < that contact cell grid
	separation_radius = 18.0
	

	w_separation = 2.0 #dont merge
	w_alignment =0.5 #follow other
	w_cohesion = 0.5# stay in group
	w_seek = 1.0# seek food
	max_force = 2.0 #how much power has steer

	
func run_chunk_simulation( start: int, end: int,local_id:int, dt: float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function
	
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	
	#MAP
	var field_cell_size := alifemanager.field_cell_size
	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	var H := FIELD_H
	var W := FIELD_W
	var D := FIELD_D

	
	#contact grid
	var C_H := alifemanager.GRID_H
	var C_W := alifemanager.GRID_W
	var C_D := alifemanager.GRID_D
	var nx := C_W if (wrap_x and C_W < 3) else 3
	var ny := C_H if (wrap_y and C_H < 3) else 3
	var nz := C_D if (wrap_z and C_D < 3) else 3
	var global_sorted_pos: PackedVector3Array = alifemanager.sorted_pos
	var cell_start: PackedInt32Array = alifemanager.cell_start
	var cell_items: PackedInt32Array = alifemanager.cell_items
	#GLOBAL ID
	var offs: PackedInt32Array = alifemanager.global_species_offset
	var my_end := offs[species_id + 1]
	var base := offs[alifemanager.species_array.size()-1]		
	
	#FOOD
	var target_dist := 1.0
	var target_id := 0
	var t_sp := alifemanager.species_array[target_id]
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count
	
	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius
	


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
		
		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
		var _energy:= current_energy_array[i]

#EGG TIME---------		
		if lifecycle == 0:
			_energy -= 2 * dt * sim_speed
			if _energy < 0:
				current_life_state[i]+=1
				_energy = seed_energy
			current_energy_array[i] = _energy
			continue
			
		var p := position_array[i]		
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)	
		var tc := t_count[c]
		var steer := Vector3.ZERO   # sum of forces (acceleration), NOT a velocity
		var v:Vector3= current_velocity[i]
		var global_i := i + base
		
		
	#--------MOVE & AI
		#--------FOOD (seek: force toward a desired velocity)
		if tc < 1:
			var g := scent_gradient(t_diff, c)
			if g.length_squared() > 1e-6:
				steer += (g.normalized() * max_speed - v) * w_seek
				#steer += (g.normalized() * 1 - v) * w_seek

		else:
			var me := i + base
			var found := find_nearest(p, me, 0, 4)
			var prey := int(found.w)
			if prey >= 0:
				var delta := Vector3(found.x, found.y, found.z)
				var dist := delta.length()
				if dist < target_dist:
					var sp := offs.bsearch(prey, false) - 1
					var local := prey - offs[sp]
					var sp_o = alifemanager.species_array[sp]
					if sp_o.active_alife_array[local] == 1:
						sp_o.alive_array[local] = 0
						_energy += sp_o.current_biomass[local]
						sp_o.current_biomass[local] = 0

				elif dist > 0.0:
					steer += (delta / dist * max_speed - v) * w_seek
					#steer += (delta / dist * 1 - v) * w_seek

		#--------NEIGHBOURS
		#--------NEIGHBOURS
		var n := 0                          # neighbours counted for alignment / cohesion (capped)
		var sum_d := Vector3.ZERO      # cohesion: sum of offsets
		var sum_v := Vector3.ZERO      # alignment: sum of velocities
		var sep := Vector3.ZERO        # separation: every close agent (not capped)

		for dz in range(-1, -1 + nz):
			var z := cz + dz
			var sz := 0.0
			if z < 0:
				if not wrap_z: continue
				z += D; sz = -world_size.z
			elif z >= D:
				if not wrap_z: continue
				z -= D; sz = world_size.z

			for dy in range(-1, -1 + ny):
				var y := cy + dy
				var sy := 0.0
				if y < 0:
					if not wrap_y: continue
					y += H; sy = -world_size.y
				elif y >= H:
					if not wrap_y: continue
					y -= H; sy = world_size.y

				for dx in range(-1, -1 + nx):
					var x := cx + dx
					var sx := 0.0
					if x < 0:
						if not wrap_x: continue
						x += W; sx = -world_size.x
					elif x >= W:
						if not wrap_x: continue
						x -= W; sx = world_size.x

					var cell := x + W * (y + H * z)
					var shift_p := Vector3(sx, sy, sz) - p   # one shift per cell
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var other: int = cell_items[k]
						if other < base or other >= my_end or other == global_i:   # same species only
							continue
						var d: Vector3 = global_sorted_pos[k] + shift_p
						var dist2 := d.length_squared()
						if dist2 > view_r2:
							continue

						# Separation: every close agent, never capped
						if dist2 < sep_r2:
							if dist2 < 1e-8:
								# exactly on top of each other: push in a direction based on the ids
								var a := float(global_i * 7 + other * 13)
								sep += Vector3(sin(a), 0.0, cos(a))
							else:
								sep -= d / dist2

						# Alignment / cohesion: capped
						if n < max_neighbors:
							n += 1
							sum_d += d
							sum_v += current_velocity[other - base]
		if n > 0:
			steer += sep * w_separation
			steer += (sum_v / n - v) * w_alignment
			steer += (sum_d / n) * w_cohesion


	#--------APPLY STEERING, once
		steer = steer.limit_length(max_force)      # "=" not "+="
		var new_v := v + steer * dt *sim_speed
		new_v = new_v.limit_length(max_speed)
		if new_v.length_squared() < 1e-8:
			new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) #* 0.1   # small nudge
		
		if i == player_index:
			new_v = player_velocity* dt *sim_speed     # player-controlled: the AI is ignored
			#new_v = new_v.limit_length(max_speed)

		new_velocity[i] = new_v

	#--------Growth

	
		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			_energy -= g_cost


	#--------maintain cost
		_energy += -1 *  dt * sim_speed  # - (side * side - side) *dt #* active_alife_array[i]
		
	#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
	#--------Duplicate
		if _energy >= 1.5*seed_energy*3:
			local_pending_spawn_id.append(i)
			local_pending_spawn_id.append(i)
			local_pending_spawn_id.append(i)
			_energy -= seed_energy*3
			
			
			
			
		#update Value
		
		current_energy_array[i] = _energy	
		##
		var nv := new_velocity[i] * dt * sim_speed
		var q := p + nv
		# borders (world is 0..size)
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y: q.y = clampf(q.y, 0.0, world_size.y); v.y = -v.y
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z
		position_array[i] = q
		current_velocity[i] = nv		

			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id
