extends ALIFE
class_name ALIFE_SPIDERCRAB


		#debug
var shp:=0
var sh:= 0
var stopp:=0
var stop:=0

func _init() -> void:
	photosynthesis_on = false
	init_size = 1.5
	species_name = "SPIDERCRAB"
	sprite =preload("res://Alife/animal/Spider/Spidercrab.png")
	hframes = 1
	vframes=1
	colour = Color(0.609, 0.09, 0.557, 1.0)
	
	max_energy = 2500
	max_speed = 2.

	#LIFECYCLE/DUP
	duplication_range = 1
	seed_energy = 1000
	seed_biomass = 100
	max_life_cycle = 4
	growth_cost = [1000,1000,1000,1000,1000] #Should be size of max_life+1
	growth_rate = 2
	
	

	#food part
	
	#Flock par
	#contact par
	view_radius = 100 #19.0	 #need to be < that contact cell grid
	separation_radius = 100# 3.0
	

	w_separation = 2.0 #dont merge
	w_alignment =0. #follow other
	w_cohesion = 0.# stay in group
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
	
	#FIELD GRID
	var H := FIELD_H
	var W := FIELD_W
	var D := FIELD_D
	#print(alifemanager.W)

	#var fnx := W if (wrap_x and W < 3) else 3
	#var fny := H if (wrap_y and H < 3) else 3
	#var fnz := D if (wrap_z and D < 3) else 3
	
	#contact grid
	var grid_cell_size := alifemanager.cell_size
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
	var base := offs[species_id]		
	
	#FOOD
	var target_dist := 1.0
	var t_sp :ALIFE= alifemanager.codex.species.get("BUGSHEEP")
	var target_id := t_sp.species_id
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count
	
	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius
	



	for i in range(start, end):
		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
		var _energy:= current_energy_array[i]
		
		if active_alife_array[i] == 0:
			continue
		if alive_array[i] == 0:
			if active_alife_array[i] == 1:
				var b = current_biomass[i]
				b -= 1 * dt *sim_speed
				current_biomass[i] = b
				if b < 0:
					local_pending_remove_id.append(i)
					if lifecycle >= max_life_cycle:
						local_pending_spawn_id.append(i)
						local_pending_spawn_id.append(i)
						local_pending_spawn_id.append(i)
						local_pending_spawn_id.append(i)
						local_pending_spawn_id.append(i)
				continue
		


#EGG TIME---------		
		'if lifecycle == 0:
			_energy -= 2 * dt * sim_speed
			if _energy < 0:
				current_life_state[i]+=1
				_energy = seed_energy
			current_energy_array[i] = _energy
			continue'
			
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
		#2500 time frame between 20 to 5, eat 15 sheep = 1500 energy
		if t_sp.active_entity_count > 20 and current_action[i]!=1:
			#stop = _energy
		#if current_energy_array[i] < 1000:
			current_action[i] = 1
			#print("start: energy win %d" % [stop-stopp])
			#stopp = stop
		if t_sp.active_entity_count < 6 and current_action[i]!=0:
		#if current_energy_array[i] > 2000:
			#sh = _energy
			current_action[i] = 0
			v = Vector3.ZERO
			#print(" stop: loose %d between hunt" % [sh -stop])
			#shp = sh

			
		if current_action[i] ==1:
			if tc < 1:
				var g := scent_gradient(t_diff, c)
				if g.length_squared() > 1e-6:
					steer += (g.normalized() * max_speed - v) * w_seek
					#steer += (g.normalized() * 1 - v) * w_seek

			else:
				var me := i + base
				var found := find_nearest(p, me, target_id, 4)
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

		#--------NEIGHBOURS
#--------NEIGHBOURS
		var n := 0                          # neighbours counted for alignment / cohesion (capped)
		var sum_d := Vector3.ZERO      # cohesion: sum of offsets
		var sum_v := Vector3.ZERO      # alignment: sum of velocities
		var sep := Vector3.ZERO        # separation: every close agent (not capped)
		var g_cx := mini(int(p.x / grid_cell_size.x), C_W - 1)
		var g_cy := mini(int(p.y / grid_cell_size.y), C_H - 1)
		var g_cz := mini(int(p.z / grid_cell_size.z), C_D - 1)
		for dz in range(-1, -1 + nz):
			var z := g_cz + dz
			var sz := 0.0
			if z < 0:
				if not wrap_z: continue
				z += C_D; sz = -world_size.z
			elif z >= C_D:
				if not wrap_z: continue
				z -= C_D; sz = world_size.z

			for dy in range(-1, -1 + ny):
				var y := g_cy + dy
				var sy := 0.0
				if y < 0:
					if not wrap_y: continue
					y += C_H; sy = -world_size.y
				elif y >= C_H:
					if not wrap_y: continue
					y -= C_H; sy = world_size.y

				for dx in range(-1, -1 + nx):
					var x := g_cx + dx
					var sx := 0.0
					if x < 0:
						if not wrap_x: continue
						x += C_W; sx = -world_size.x
					elif x >= C_W:
						if not wrap_x: continue
						x -= C_W; sx = world_size.x

					var cell := x + C_W * (y + C_H * z)

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
		#var damp :=  -Vector3(-0.5,0,-0.5) #exp(-0.5 * dt * sim_speed)

		steer = steer.limit_length(max_force)      # "=" not "+="
		var new_v := v + steer * dt *sim_speed #- damp* dt *sim_speed
		new_v = new_v.limit_length(max_speed)
		if new_v.length_squared() < 1e-8:
			pass
			#new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) #* 0.1   # small nudge
		
		if i == player_index:
			new_v = player_velocity #* dt *sim_speed     # player-controlled: the AI is ignored
			#new_v = new_v.limit_length(max_speed)

		new_velocity[i] = new_v

	#--------Growth

	
		if _energy >= 2000 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += 1000/10
			current_life_state[i] +=1
			_energy -= 1000


	#--------maintain cost
		#need to loose around 1500 energy in 2500 frames? 
		_energy += -1. *  dt * sim_speed  # - (side * side - side) *dt #* active_alife_array[i]
		
	#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
	#--------Duplicate
		if _energy >= 5*seed_energy and lifecycle >= max_life_cycle:
			alive_array[i] = 0
			#_energy -= seed_energy
			
			
			
			
		#update Value
		
		current_energy_array[i] = _energy	
		##
		var nv := new_velocity[i]
		var q := p + nv * dt * sim_speed
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
