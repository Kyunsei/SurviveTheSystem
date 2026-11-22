extends ALIFE
class_name ALIFE_BUGSHEEP
## Bugsheep: grazing flock animal.
## Seeks its food species, flocks with its own kind (separation / alignment / cohesion),
## and flees the species listed in avoid_species (predators).


#FOOD (set in _init)
var food_species := ""               # species name; "" = species index 0 (as before)
var eat_distance := 1.0              # eats food closer than this

#AVOID (set in _init)
var avoid_species: Array[String] = []    # species to flee, e.g. ["SPIDERCRAB"]
var avoid_radius := 8.0              # starts fleeing when one is closer than this
var w_avoid := 4.0                   # how strongly it flees (fleeing beats seeking / flocking)
var avoid_scent := 0.0               # > 0: also flees their scent field from further away

#MOVE (set in _init)
var idle_nudge := 0.5                # random push when standing still (0 = none)
var ground_animal := true            # walks on the ground: no vertical movement (AI-driven)
#var ground_y := 0.0


func _init() -> void:
	photosynthesis_on = false
	init_size = 4.0
	species_name = "BUGSHEEP"
	sprite =preload("res://Alife/animal/Herbivor/Sheep/SHEEP-Sheet.png")
	hframes = 3
	vframes=2
	colour = Color(0.772, 0.772, 0.772, 1.0)

	max_energy = 2500
	max_speed = 3.

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 600
	seed_biomass = 60 #
	max_life_cycle = 2
	growth_cost = [1000,1000,1000] #Should be size of max_life+1
	growth_rate = 0.5

	#Food
	food_species = ""            # e.g. "GRASS" (empty = species index 0, as before)
	eat_distance = 1.0

	#Avoid
	avoid_species = ["SPIDERCRAB","CATRONAUTE"]
	avoid_radius = 8.0
	w_avoid = 4.0
	avoid_scent = 0.0            # try 0.5 to make them keep away from crab areas

	#Flock par
	#contact par
	view_radius = 5.0	 #must be <= the contact grid cell size (only 3x3 cells are searched)
	separation_radius = 3.0

	w_separation = 2.0 #dont merge
	w_alignment =0.5 #follow other
	w_cohesion = 0.5# stay in group
	w_seek = 1.0# seek food
	max_force = 2.0 #how much power has steer

	idle_nudge = 0.5


func run_chunk_simulation( start: int, end: int,local_id:int, dt: float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function

	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	var step := dt * sim_speed                # simulation time of this step

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
	var t_sp: ALIFE = alifemanager.codex.species.get(food_species) if food_species != "" \
			else alifemanager.species_array[0]
	var target_id := t_sp.species_id
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count

	#AVOID: the species that exist in this world
	var threats: Array[ALIFE] = []
	for name in avoid_species:
		var s: ALIFE = alifemanager.codex.species.get(name)
		if s != null:
			threats.append(s)
	var avoid_rings := ceili(avoid_radius / maxf(grid_cell_size.x, 0.001)) + 1
	var avoid_r2 := avoid_radius * avoid_radius

	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius


	for i in range(start, end):
		if active_alife_array[i] == 0:
			continue
		if alive_array[i] == 0:
			if active_alife_array[i] == 1:
				var b = current_biomass[i]
				b -= 0.1 * step
				current_biomass[i] = b
				if b < 0:
					local_pending_remove_id.append(i)
				continue

		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
		var _energy:= current_energy_array[i]

#EGG TIME---------
		if lifecycle == 0:
			_energy -= 2 * step
			if _energy < 0:
				current_life_state[i]+=1
				_energy = seed_energy
			current_energy_array[i] = _energy
			continue

		var p := position_array[i]
		# Field cell (scent grid)
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)
		var tc := t_count[c]
		var steer := Vector3.ZERO   # seek + alignment + cohesion (capped by max_force)
		var urgent := Vector3.ZERO  # separation + fleeing: always wins over the rest
		var v:Vector3= current_velocity[i]
		var global_i := i + base


	#--------AVOID (predators): flee away, harder the closer they are
		var fleeing := false
		for s in threats:
			var found := find_nearest(p, global_i, s.species_id, avoid_rings)
			if int(found.w) < 0:
				continue
			var away := -Vector3(found.x, 0.0, found.z)
			var d2 := away.length_squared()
			if d2 < avoid_r2 and d2 > 1e-8:
				var dist := sqrt(d2)
				var panic := 1.0 - dist / avoid_radius            # 0 at the edge, 1 touching
				urgent += (away / dist * max_speed - v) * w_avoid * panic
				fleeing = true
			# From further away: keep out of their scent
			if avoid_scent > 0.0:
				var g := scent_gradient(s.FIELD_c_diffused, c)
				if g.length_squared() > 1e-6:
					steer -= g.normalized() * max_speed * avoid_scent

	#--------FOOD (seek: force toward a desired velocity), not while fleeing
		if not fleeing:
			if tc < 1:
				var g := scent_gradient(t_diff, c)
				if g.length_squared() > 1e-6:
					steer += (g.normalized() * max_speed - v) * w_seek
			else:
				var found := find_nearest(p, global_i, target_id, 4)
				var prey := int(found.w)
				if prey >= 0:
					var delta := Vector3(found.x, found.y, found.z)
					var dist := delta.length()
					if dist < eat_distance:
						var sp := offs.bsearch(prey, false) - 1
						var local := prey - offs[sp]
						var sp_o = alifemanager.species_array[sp]
						if sp_o.active_alife_array[local] == 1:
							sp_o.alive_array[local] = 0
							_energy += sp_o.current_biomass[local]
							sp_o.current_biomass[local] = 0
					elif dist > 0.0:
						steer += (delta / dist * max_speed - v) * w_seek

	#--------NEIGHBOURS (contact grid: NOT the field cell above)
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

		urgent += sep * w_separation
		if n > 0:
			steer += (sum_v / n - v) * w_alignment
			steer += (sum_d / n) * w_cohesion


	#--------APPLY STEERING, once
		# Normal forces are capped; separation and fleeing come on top (they must win)
		steer = steer.limit_length(max_force) + urgent
		steer = steer.limit_length(max_force * (3.0 if fleeing else 2.0))
		var new_v := v + steer * step
		new_v = new_v.limit_length(max_speed)
		if idle_nudge > 0.0 and new_v.length_squared() < 1e-6:
			new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * idle_nudge   # small nudge

		# Ground animals never steer up or down (flocking / scent can have a vertical part)
		if ground_animal:
			new_v.y = 0.0

		if i == player_index:
			new_v = player_velocity     # player-controlled: the AI is ignored (dt is applied below)

	#--------Growth
		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			_energy -= g_cost

	#--------maintain cost
		_energy += -1 * step

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

	#--------MOVE (velocity is per second: dt only here)
		var q := p + new_v * step
		# borders (world is 0..size): wrap, or bounce off the wall
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); new_v.x = -new_v.x
		if ground_animal and i != player_index:
			q.y = ground_y                         # stays on the ground
		elif wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y:
			q.y = clampf(q.y, 0.0, world_size.y)
			new_v.y = 0.0                          # floor / ceiling: stop, never bounce up
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); new_v.z = -new_v.z
		position_array[i] = q
		new_velocity[i] = new_v
		current_velocity[i] = new_v              # the VELOCITY, not the step's displacement

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id
