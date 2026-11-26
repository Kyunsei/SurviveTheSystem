extends ALIFE
class_name ALIFE_BUGSHEEP
## Bugsheep: grazing flock animal, driven by a small finite state machine.
##
## States (stored in current_action, also read by the shader):
##   IDLE     fed (above hunger_threshold): flocks; alone, it follows the sheep scent
##            (juvenile + adult fields) to find the others
##   HUNGRY   below hunger_threshold: goes to the grass (food scent), grazes on contact,
##            and keeps eating until full_threshold, then back to IDLE
##   AVOID    a predator is close: flees, until it is well away
##
## Transitions, checked every step (first match wins):
##   predator closer than avoid_radius                          -> AVOID
##   already AVOID, predator still within avoid_radius*calm_ratio -> AVOID (no flickering)
##   energy < hunger_threshold                                  -> HUNGRY
##   already HUNGRY, energy < full_threshold                    -> HUNGRY (eats until full)
##   otherwise                                                  -> IDLE
##
## Every state keeps separation (no merging) and flocks, with its own flock weight.
## Eggs (life cycle 0) and corpses don't run the machine. The player-controlled agent
## doesn't either: the player decides (its action stays IDLE).
##
## Neighbours, by life cycle:
##   eggs                 only push other eggs apart (no flocking, no walking)
##   juveniles / adults   ignore eggs: separate and flock between themselves only

enum action { IDLE, HUNGRY, AVOID }   # = current_action values (same numbers as before)


#FOOD (set in _init): one entry per food
#   species    species_name ("" = species index 0, the grass)
#   fields     its fields to smell and count ([] = its whole density field)
#   max_stage  only its agents up to this life cycle stage (-1 = any)
#   dead_max_stage  its corpses are eaten too, up to this stage (-1 = never, default)
# Food on the ground is eaten; carried food (state 2) is followed but not eaten.
var foods: Array[Dictionary] = []
var eat_distance := 1.0              # eats food closer than this

#STATE MACHINE (set in _init)
var hunger_threshold := 1500.0       # IDLE -> HUNGRY below this energy
var full_threshold := 2800.0         # HUNGRY -> IDLE above this energy
var calm_ratio := 1.5                # AVOID ends once predators are beyond avoid_radius * this
var flock_weight_idle := 1.0         # alignment + cohesion strength, per state
var flock_weight_hungry := 0.3       # hungry: food first, loose flock
var w_friend := 1.0                  # IDLE and alone: how strongly it follows the sheep scent
var flock_weight_avoid := 1.0        # fleeing: stick together (selfish herd)

#AVOID (set in _init)
var avoid_species: Array[String] = []    # species to flee, e.g. ["SPIDERCRAB"]
var avoid_radius := 8.0              # starts fleeing when one is closer than this
var w_avoid := 4.0                   # how strongly it flees (fleeing beats seeking / flocking)
var avoid_scent := 0.0               # > 0: also flees their scent field from further away

#LIFE CYCLE FIELDS (created in _init): living sheep at each stage, per field cell
# Read them with field_now(id)[c] (this frame) or field_diffused(id)[c] (lasting scent),
# from here or from any other species: sheep.field_id("adult")
var egg_field := -1                  # life state 0
var juvenile_field := -1             # life state 1
var adult_field := -1                # life state 2

#MOVE (set in _init)
var egg_push_speed := 1.0            # max speed of eggs pushed apart by other eggs
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
	max_speed = 12.

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 600
	seed_biomass = 60 #
	max_life_cycle = 2
	growth_cost = [1000,1000,1000] #Should be size of max_life+1
	growth_rate = 0.5

	#Food
	foods = [
		{"species": "", "fields": [], "max_stage": -1},                       # grass
		{"species": "tree", "fields": ["fruit", "sapling"], "max_stage": 1,   # fruits + saplings
				"dead_max_stage": 0},                                         # + dead fruits
	]
	eat_distance = 1.0

	#State machine
	# full_threshold must stay above the duplication energy (1.5 * seed_energy * 3 = 2700),
	# or sheep stop eating before they can reproduce
	hunger_threshold = 1500.0
	full_threshold = 2800.0
	calm_ratio = 1.5
	flock_weight_idle = 1.0
	flock_weight_hungry = 0.3
	w_friend = 1.0
	flock_weight_avoid = 1.0

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

	#Life cycle fields: one per stage, living sheep only
	egg_field = add_field("egg", FieldSource.COUNT, -1.0, -1.0, true, 0, 0)
	juvenile_field = add_field("juvenile", FieldSource.COUNT, -1.0, -1.0, true, 1, 1)
	adult_field = add_field("adult", FieldSource.COUNT, -1.0, -1.0, true, 2)     # 2 and above


## The state machine: next state from the current one, energy and closest predator.
func _next_state(state: int, energy: float, threat_d: float) -> int:
	if threat_d < avoid_radius:
		return action.AVOID
	if state == action.AVOID and threat_d < avoid_radius * calm_ratio:
		return action.AVOID
	if energy < hunger_threshold:
		return action.HUNGRY
	if state == action.HUNGRY and energy < full_threshold:
		return action.HUNGRY
	return action.IDLE


func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function

	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	var step := dt                            # fixed simulated time per tick (speed = more ticks)

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

	#FOOD: the food species that exist in this world (missing names are skipped)
	var food_sps: Array[ALIFE] = []
	var food_fids: Array[PackedInt32Array] = []   # per food: the fields to smell / count
	var food_max := PackedInt32Array()            # per food: max life stage eaten
	var food_dead_max := PackedInt32Array()       # per food: max life stage of eaten corpses
	for f in foods:
		var fs: ALIFE = alifemanager.species_array[0] if f["species"] == "" \
				else _species_named(f["species"])
		if fs == null:
			continue
		var ids := PackedInt32Array()
		for fname in f["fields"]:
			var fid := fs.field_id(fname)
			if fid >= 0:
				ids.append(fid)
		if ids.is_empty():
			ids.append(fs.field_id(FIELD_DENSITY))
		food_sps.append(fs)
		food_fids.append(ids)
		food_max.append(f["max_stage"])
		food_dead_max.append(f.get("dead_max_stage", -1))

	#AVOID: the species that exist in this world
	var threats: Array[ALIFE] = []
	for name in avoid_species:
		var s: ALIFE = alifemanager.codex.species.get(name)
		if s != null:
			threats.append(s)
	var calm_radius := avoid_radius * calm_ratio   # sensing reaches the end of AVOID too
	var avoid_rings := ceili(calm_radius / maxf(grid_cell_size.x, 0.001)) + 1

	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius


	for i in range(start, end):
		if active_alife_array[i] != 1:           # pool, held, thrown...: not in the world
			continue
		if alive_array[i] == 0:
			var b = current_biomass[i]
			b -= 0.1 * step * sim_speed
			current_biomass[i] = b
			if b < 0:
				local_pending_remove_id.append(i)
			continue


		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
		var _energy:= current_energy_array[i]
		var is_egg := lifecycle == 0
		var is_player := i == player_index

		var p := position_array[i]
		var v:Vector3= current_velocity[i]
		var global_i := i + base


	#--------NEIGHBOURS (contact grid), filtered by life cycle:
	#   eggs see only eggs (separation only), juveniles / adults see only each other
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
						if active_alife_array[other - base] != 1:
							continue                 # carried / thrown sheep: no flocking with them
						var other_is_egg := current_life_state[other - base] == 0
						if other_is_egg != is_egg:
							continue                 # eggs and the others ignore each other
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

						# Alignment / cohesion: juveniles and adults only, capped
						if not is_egg and n < max_neighbors:
							n += 1
							sum_d += d
							sum_v += current_velocity[other - base]


	#EGG TIME---------
		if is_egg:
			_energy -= 2 * step * sim_speed
			if _energy < 0:
				current_life_state[i]+=1
				_energy = seed_energy
			current_energy_array[i] = _energy

			# Eggs don't walk: they're only pushed apart by other eggs
			var egg_v := (sep * w_separation).limit_length(egg_push_speed)
			if ground_animal:
				egg_v.y = 0.0
			if is_player:
				egg_v = player_velocity
			_move(i, p, egg_v, step, world_size, wrap_x, wrap_y, wrap_z, is_player)
			continue

		# Field cell (scent grid)
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)
		var steer := Vector3.ZERO   # seek + alignment + cohesion (capped by max_force)
		var urgent := Vector3.ZERO  # separation + fleeing: always wins over the rest

		# Food in my field cell this frame (all foods)
		var food_here := 0.0
		for k in food_sps.size():
			for fid in food_fids[k]:
				food_here += food_sps[k].field_now(fid)[c]


	#--------SENSE: closest predator (any listed species)
		var threat_d := INF
		var flee_dir := Vector3.ZERO           # away from the closest predator, on the ground
		for s in threats:
			var found := find_nearest(p, global_i, s.species_id, avoid_rings)
			if int(found.w) >= 0:
				var away := -Vector3(found.x, 0.0, found.z)
				var d := away.length()
				if d < threat_d and d > 1e-4:
					threat_d = d
					flee_dir = away / d
			# From further away: keep out of their scent (background, any state)
			if avoid_scent > 0.0:
				var g := scent_gradient(s.FIELD_c_diffused, c)
				if g.length_squared() > 1e-6:
					steer -= g.normalized() * max_speed * avoid_scent


	#--------DECIDE: state machine
		var state: int = action.IDLE
		if not is_player:
			state = _next_state(current_action[i], _energy, threat_d)
		current_action[i] = state


	#--------ACT: what each state does
		var flock_w := flock_weight_idle
		match state:
			action.AVOID:
				# Flee: harder the closer the predator, still a little until calm again
				var panic := clampf(1.0 - threat_d / calm_radius, 0.2, 1.0)
				urgent += (flee_dir * max_speed - v) * w_avoid * panic
				flock_w = flock_weight_avoid

			action.HUNGRY:
				# Go to the grass and eat until full (the hysteresis above)
				flock_w = flock_weight_hungry
				if food_here < 1.0:
					# No food in this field cell: follow the scents (each food counts the same)
					var g := Vector3.ZERO
					for k in food_sps.size():
						var gk := Vector3.ZERO
						for fid in food_fids[k]:
							gk += food_sps[k].field_gradient(fid, c)
						if gk.length_squared() > 1e-6:
							g += gk.normalized()
					if g.length_squared() > 1e-6:
						steer += (g.normalized() * max_speed - v) * w_seek
				else:
					# Closest food of any kind
					var best_d2 := INF
					var best_sp: ALIFE = null
					var best_local := -1
					var best_delta := Vector3.ZERO
					for k in food_sps.size():
						var found := _nearest_food(p, global_i, food_sps[k], food_max[k],
								food_dead_max[k], 4)
						var id := int(found.w)
						if id < 0:
							continue
						var _delta := Vector3(found.x, found.y, found.z)
						if _delta.length_squared() < best_d2:
							best_d2 = _delta.length_squared()
							best_sp = food_sps[k]
							best_local = id - offs[food_sps[k].species_id]
							best_delta = _delta
					if best_sp != null:
						var dist := sqrt(best_d2)
						if dist < eat_distance:
							if best_sp.active_alife_array[best_local] == 1:   # on the ground only
								best_sp.alive_array[best_local] = 0
								_energy += best_sp.current_biomass[best_local]
								best_sp.current_biomass[best_local] = 0
						elif dist > 0.0:
							steer += (best_delta / dist * max_speed - v) * w_seek

			action.IDLE:
				flock_w = flock_weight_idle
				if n == 0:
					# Alone: follow the scent of the other sheep (juveniles + adults) to the flock
					var fg := field_gradient(juvenile_field, c) + field_gradient(adult_field, c)
					if fg.length_squared() > 1e-6:
						steer += (fg.normalized() * max_speed - v) * w_friend


	#--------FLOCK (juveniles / adults, from the neighbours above)
		urgent += sep * w_separation
		if n > 0:
			steer += (sum_v / n - v) * w_alignment * flock_w
			steer += (sum_d / n) * w_cohesion * flock_w


	#--------APPLY STEERING, once
		# Normal forces are capped; separation and fleeing come on top (they must win)
		steer = steer.limit_length(max_force) + urgent
		steer = steer.limit_length(max_force * (3.0 if state == action.AVOID else 2.0))
		var new_v := v + steer #* delta
		new_v = new_v.limit_length(max_speed)
		if idle_nudge > 0.0 and new_v.length_squared() < 1e-6:
			new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * idle_nudge   # small nudge

		# Ground animals never steer up or down (flocking / scent can have a vertical part)
		if ground_animal:
			new_v.y = 0.0

		if is_player:
			new_v = player_velocity     # player-controlled: the AI is ignored (dt is applied below)

	#--------Growth
		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			_energy -= g_cost

	#--------maintain cost
		_energy += -1 * step * sim_speed

	#--------DEATH
		if _energy < 0 or current_health[i] <0 :
			alive_array[i] = 0

	#--------Duplicate
		var sheep_here := FIELD_count[c]        # sheep in my field cell this frame
		var grass_here := food_here             # food in my field cell
		var max_sheep_per_cell := 4.0
		var min_grass_per_cell := 100
		if active_entity_count < 20:
			if _energy >= 1.5 * seed_energy * 3 and sheep_here < max_sheep_per_cell and grass_here > min_grass_per_cell:
				local_pending_spawn_id.append(i)
				local_pending_spawn_id.append(i)
				local_pending_spawn_id.append(i)
				_energy -= seed_energy*3

		#update Value
		current_energy_array[i] = _energy

	#--------MOVE (velocity is per second: dt only here)
		_move(i, p, new_v, delta, world_size, wrap_x, wrap_y, wrap_z, is_player)

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


## Moves agent i by velocity v for this step: wraps or bounces off the world's borders,
## keeps ground animals on the ground. Stores the new position and velocity.
func _move(i: int, p: Vector3, v: Vector3, delta: float, world_size: Vector3,
		wrap_x: bool, wrap_y: bool, wrap_z: bool, is_player: bool) -> void:
	var q := p + v * delta 
	if wrap_x: q.x = fposmod(q.x, world_size.x)
	elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
	if ground_animal and not is_player:
		q.y = ground_y                         # stays on the ground
	elif wrap_y: q.y = fposmod(q.y, world_size.y)
	elif q.y < 0.0 or q.y > world_size.y:
		q.y = clampf(q.y, 0.0, world_size.y)
		v.y = 0.0                              # floor / ceiling: stop, never bounce up
	if wrap_z: q.z = fposmod(q.z, world_size.z)
	elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z
	position_array[i] = q
	new_velocity[i] = v
	current_velocity[i] = v                  # the VELOCITY, not the step's displacement


## A species of this world by its species_name, or null.
func _species_named(sname: String) -> ALIFE:
	for sp in alifemanager.species_array:
		if sp.species_name == sname:
			return sp
	return null


## Closest edible agent of food_sp around p, on the ground or carried:
##   living ones up to max_stage (-1 = any stage),
##   dead ones up to dead_max_stage (-1 = no corpses), if anything is left of them.
## Ring search on the contact grid (wrap-aware), stops early once nothing closer can
## exist. Returns Vector4(dx, dy, dz, global_id), id = -1 if none.
func _nearest_food(p: Vector3, me: int, food_sp: ALIFE, max_stage: int, dead_max_stage: int,
		max_rings: int) -> Vector4:
	var am := alifemanager
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var offs: PackedInt32Array = am.global_species_offset
	var lo := offs[food_sp.species_id]
	var hi := offs[food_sp.species_id + 1]
	var alive := food_sp.alive_array
	var active := food_sp.active_alife_array
	var life := food_sp.current_life_state
	var biomass := food_sp.current_biomass
	var ws: Vector3 = world.size
	var wx: bool = world.border_type_x == world.Border.WRAP
	var wz: bool = world.border_type_z == world.Border.WRAP

	var cx := clampi(int(p.x / cs.x), 0, W - 1)
	var cz := clampi(int(p.z / cs.z), 0, D - 1)
	var lim_x := mini(max_rings, (W - 1) / 2) if wx else max_rings
	var lim_z := mini(max_rings, (D - 1) / 2) if wz else max_rings
	var cmin := minf(cs.x, cs.z)

	var best := -1
	var best_d2 := INF
	var best_d := Vector3.ZERO
	for r in max_rings + 1:
		if best >= 0 and best_d2 <= pow((r - 1) * cmin, 2):
			break
		for dz in range(-mini(r, lim_z), mini(r, lim_z) + 1):
			var z := cz + dz
			if not wz and (z < 0 or z >= D): continue
			var zw := posmod(z, D)
			for dx in range(-mini(r, lim_x), mini(r, lim_x) + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue                               # only this ring's shell
				var x := cx + dx
				if not wx and (x < 0 or x >= W): continue
				var xw := posmod(x, W)
				for y in H:
					var cell := xw + W * (y + H * zw)
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var j: int = cell_items[k]
						if j < lo or j >= hi or j == me:
							continue
						var local := j - lo
						var st := active[local]
						if st != 1 and st != AlifeManager.HELD:
							continue                       # not on the ground nor carried
						if alive[local] == 0:
							# corpse: only the allowed stages, and not already eaten
							if dead_max_stage < 0 or life[local] > dead_max_stage \
									or biomass[local] <= 0.0:
								continue
						elif max_stage >= 0 and life[local] > max_stage:
							continue                       # too grown (e.g. a tree)
						var d: Vector3 = sorted_pos[k] - p
						if wx: d.x -= ws.x * roundf(d.x / ws.x)
						if wz: d.z -= ws.z * roundf(d.z / ws.z)
						var d2 := d.length_squared()
						if d2 < best_d2:
							best_d2 = d2
							best = j
							best_d = d
	return Vector4(best_d.x, best_d.y, best_d.z, float(best))
