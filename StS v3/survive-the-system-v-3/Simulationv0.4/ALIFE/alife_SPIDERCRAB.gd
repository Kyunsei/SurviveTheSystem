extends ALIFE
class_name ALIFE_SPIDERCRAB
## Spidercrab: ambush hunter.
##
## Hunt, per crab, stored in current_action (also sent to the shader for visuals):
##   0 IDLE      not hunting: full (see hunt_start_energy / hunt_stop_energy)
##   1 APPROACH  follow the prey's scent field, then walk toward the best prey in sight
##   2 CHARGE    prey within strike_range: stop and aim for charge_time (the "tell")
##   3 DASH      rush in a straight line, direction LOCKED when the charge ends.
##               Any prey within catch_radius during the dash is eaten.
##               -> prey that moves sideways at the right moment is missed
##   4 RECOVER   out of breath for recover_time, then back to APPROACH
##
## Prey: several species, each with an affinity (1 = favourite). The scent fields are
## mixed by affinity, and the target is the prey with the best distance / affinity.
## Eggs are never food: not smelled, not targeted, not caught. A prey species has eggs
## when it has an "egg" field (+ "juvenile" / "adult", smelled instead of its density).
## A species with only its default field (e.g. cats) has no eggs: every agent is food.
##
## TIME, three clocks:
##   delta           tick time (1 / ticks_per_second, the same for every tick):
##                   movement, steering, braking, charge / dash / recover timers
##   dt * sim_speed  simulated time: metabolism (energy, biomass, growth)
##   frame delta     never used here (it changes with the FPS, and a frame can run 0..n ticks)
##
## Visuals: call setup_hunt_visuals() once the renderer exists (sprite shader action_* uniforms).

enum Hunt { IDLE, APPROACH, CHARGE, DASH, RECOVER }   # = current_action values

## Steering and braking were tuned "per tick" at 60 ticks / s. Scaling them by
## delta * REF_TPS keeps exactly that feel, and keeps it if ticks_per_second changes.
const REF_TPS := 60.0

#HUNT (per agent)   the state itself is current_action (Hunt)
var hunt_timer := PackedFloat32Array()    # time left in DASH / RECOVER (tick time, s)
var charge_end := PackedFloat64Array()    # CHARGE: real time (sim_manager.real_time) when it dashes
var hunt_dir := PackedVector3Array()      # dash direction, locked at the end of the charge
var hunt_target := PackedInt32Array()     # global id of the aimed prey (-1 = none)

#HUNT (settings)
var prey_species: Array[String] = []      # species names, favourite first
var prey_affinity: Array[float] = []      # same order: 1.0 = favourite, lower = less attractive
var strike_range := 10.0                  # starts charging when a prey is this close
var lose_range := 15.0                    # aborts the charge if the prey gets this far
var charge_time := 0.5                    # the "tell": REAL seconds standing still before dashing
										  # (always 0.5 s on the clock, even when the game freezes)
var dash_speed := 100.0                   # units / s
var dash_distance := 20.0                 # straight-line length of the dash
var catch_radius := 0.9                   # how close a prey must be during the dash to be eaten
var recover_time := 1.0                   # seconds out of breath after a dash (hit or miss)
var hunt_corpses := true                  # dead prey can be targeted, charged and eaten too
var hunt_eggs := false                    # eggs (life cycle 0) can be targeted and eaten
var hunt_start_energy := 1500.0           # IDLE -> hunting when energy drops below this
#EAT 10 sheep = 60 (tny), 160(big) *10
var hunt_stop_energy := 2100.0            # hunting -> IDLE once energy reaches this
var corpse_affinity := 0.8                # 0..1: how attractive a corpse is vs a living prey

#DEFENCE
var damage_reduction := 20.0              # removed from every hit it takes (armoured shell)

# Braking: velocity kept per tick at REF_TPS (0.85 = keeps 85 % each 1/60 s)
var no_food_brake := 0.85                 # no prey nor scent anywhere: slows to a stop
var charge_brake := 0.5                   # standing still to aim
var recover_brake := 0.85                 # out of breath after the dash


func _init() -> void:
	photosynthesis_on = false
	init_size = 1.5
	species_name = "SPIDERCRAB"
	sprite =preload("res://Alife/animal/Spider/Spidercrab.png")
	hframes = 1
	vframes=1
	colour = Color(0.609, 0.09, 0.557, 1.0)

	max_energy = 2500
	max_speed = 24.

	#LIFECYCLE/DUP
	duplication_range = 1
	seed_energy = 1000
	seed_biomass = 100
	max_life_cycle = 4
	growth_cost = [1000,1000,1000,1000,1000] #Should be size of max_life+1
	growth_rate = 2

	#food part
	prey_species = ["BUGSHEEP", "CATRONAUTE"]
	prey_affinity = [1.0, 0.6]                   # cats attract much less than sheep

	#Hunger: hunts below hunt_start_energy, keeps hunting until hunt_stop_energy.
	# hunt_stop_energy must stay above the duplication energy (5 * seed_energy = 5000),
	# or adults stop eating before they can reproduce
	hunt_start_energy = 1500.0
	hunt_stop_energy = 3500.0

	#Flock par
	#contact par
	view_radius = 100 #19.0	 #need to be < that contact cell grid
	separation_radius = 100# 3.0

	w_separation = 2.0 #dont merge
	w_alignment =0. #follow other
	w_cohesion = 0.# stay in group
	w_seek = 1.0# seek food
	max_force = 2.0 #how much power has steer (per tick at REF_TPS)


# --- Hunt arrays (main thread) -------------------------------------------------

func ensure_hunt_arrays(n: int) -> void:
	var old := hunt_timer.size()
	if n <= old:
		return
	hunt_timer.resize(n)
	charge_end.resize(n)
	hunt_dir.resize(n)
	hunt_target.resize(n)
	for i in range(old, n):
		reset_hunt(i)


## Back to walking around: APPROACH if it was hunting, IDLE stays IDLE.
func reset_hunt(i: int) -> void:
	if current_action.size() > i and current_action[i] != Hunt.IDLE:
		current_action[i] = Hunt.APPROACH
	hunt_timer[i] = 0.0
	charge_end[i] = 0.0
	hunt_dir[i] = Vector3.ZERO
	hunt_target[i] = -1


## Tell the sprite shader which current_action values are the charge / dash / recover,
## so it can show them (flash + crouch, stretch, tired). Call once the renderer exists.
func setup_hunt_visuals() -> void:
	var mat: ShaderMaterial = renderer3D.material_override
	mat.set_shader_parameter("action_charge", Hunt.CHARGE)
	mat.set_shader_parameter("action_dash", Hunt.DASH)
	mat.set_shader_parameter("action_recover", Hunt.RECOVER)


# --- Simulation ------------------------------------------------------------------

func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array

	var step := dt * sim_speed                  # simulated time: metabolism only
	var now: float = alifemanager.sim_manager.real_time   # real time: the charge only
	var k_tick := delta * REF_TPS               # 1.0 at 60 ticks / s: scales per-tick tuning
	# Braking, once per chunk: the same slowdown per second whatever the tick rate
	var keep_no_food := pow(no_food_brake, k_tick)
	var keep_charge := pow(charge_brake, k_tick)
	var keep_recover := pow(recover_brake, k_tick)

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

	#FOOD: the prey species that exist in this world (missing names are skipped)
	var preys: Array[ALIFE] = []
	var prey_fields: Array[PackedInt32Array] = []   # per prey: the fields to smell / count
	var pr_aff := PackedFloat32Array()
	for k in prey_species.size():
		var s: ALIFE = alifemanager.codex.species.get(prey_species[k])
		if s == null:
			continue
		preys.append(s)
		pr_aff.append(prey_affinity[k] if k < prey_affinity.size() else 1.0)
		prey_fields.append(_prey_field_ids(s))

	# Hunt arrays not sized yet: no strike, simple seek
	var strike_ok := hunt_timer.size() >= end

	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius
	var catch_r2 := catch_radius * catch_radius

	for i in range(start, end):
		# Only crabs standing in the world (held = 2 / flying = 4 are moved elsewhere)
		if active_alife_array[i] != AlifeManager.ACTIVE:
			continue

		var lifecycle := current_life_state[i]
		var _energy:= current_energy_array[i]

	#--------CORPSE: decays, an adult corpse releases its eggs
		if alive_array[i] == 0:
			var b := current_biomass[i]
			b -= 2.0 * step
			current_biomass[i] = b
			if b < 0:
				local_pending_remove_id.append(i)
				if lifecycle >= max_life_cycle:
					for e in 5:
						local_pending_spawn_id.append(i)
			continue

		var p := position_array[i]
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)
		var steer := Vector3.ZERO   # sum of forces (acceleration), NOT a velocity
		var v:Vector3= current_velocity[i]
		var global_i := i + base

	#--------HUNTING ON / OFF (hunger, with two thresholds so it doesn't flicker)
		if current_action[i] == Hunt.IDLE and _energy < hunt_start_energy:
			current_action[i] = Hunt.APPROACH            # hungry: start hunting
		elif current_action[i] != Hunt.IDLE and _energy >= hunt_stop_energy:
			if strike_ok:
				reset_hunt(i)
			current_action[i] = Hunt.IDLE                # full: stop, even mid-charge
			v = Vector3.ZERO

		var state: int = current_action[i]
		if not strike_ok and state != Hunt.IDLE:
			state = Hunt.APPROACH                    # no hunt arrays yet: simple seek
		var override_v := false             # CHARGE / DASH / RECOVER set the velocity directly
		var forced_v := Vector3.ZERO

	#--------MOVE & AI
		if state != Hunt.IDLE:
			match state:
				Hunt.APPROACH:
					# Prey in my field cell? Then look for one; otherwise follow the mixed scent
					var found_food := false              # a scent to follow or a prey in sight
					var prey_here := 0.0
					for k in preys.size():
						for fid in prey_fields[k]:
							prey_here += preys[k].field_now(fid)[c]
					if prey_here < 1.0:
						var g := Vector3.ZERO
						for k in preys.size():
							var gk := Vector3.ZERO
							for fid in prey_fields[k]:
								gk += preys[k].field_gradient(fid, c)
							if gk.length_squared() > 1e-6:
								g += gk.normalized() * pr_aff[k]     # favourite smells stronger
						if g.length_squared() > 1e-6:
							steer += (g.normalized() * max_speed - v) * w_seek
							found_food = true
					else:
						var best := _best_prey(p, global_i, preys, pr_aff)
						var prey := int(best.w)
						if prey >= 0:
							found_food = true
							var _delta := Vector3(best.x, best.y, best.z)
							var dist := _delta.length()
							if strike_ok and dist <= strike_range:
								current_action[i] = Hunt.CHARGE      # in range: start the tell
								charge_end[i] = now + charge_time    # real clock
								hunt_target[i] = prey
							elif dist > 0.0:
								steer += (_delta / dist * max_speed - v) * w_seek

					# Nothing to eat anywhere: slow down to a stop instead of drifting on
					if not found_food:
						override_v = true
						forced_v = v * keep_no_food
						if forced_v.length_squared() < 0.0025:
							forced_v = Vector3.ZERO

				Hunt.CHARGE:
					# Stand still and aim; abort if the prey is gone or got too far
					override_v = true
					forced_v = v * keep_charge               # brake hard
					var _delta := _delta_to(hunt_target[i], p, offs, world_size, wrap_x, wrap_y, wrap_z)
					if _delta.x == INF or _delta.length() > lose_range:
						reset_hunt(i)                        # lost it
					elif now >= charge_end[i]:            # real time, not ticks
						# Lock the direction NOW: where the prey is, not where it goes
						_delta.y = 0.0
						hunt_dir[i] = _delta.normalized() if _delta.length_squared() > 1e-6 \
								else Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
						current_action[i] = Hunt.DASH
						hunt_timer[i] = dash_distance / maxf(dash_speed, 0.01)

				Hunt.DASH:
					override_v = true
					forced_v = hunt_dir[i] * dash_speed
					# Anything edible within reach is caught
					var gained := _try_catch(p, global_i, preys, offs, catch_r2)
					hunt_timer[i] -= delta
					if gained > 0.0 or hunt_timer[i] <= 0.0:
						_energy += gained
						current_action[i] = Hunt.RECOVER            # hit or miss: out of breath
						hunt_timer[i] = recover_time
						hunt_target[i] = -1

				Hunt.RECOVER:
					override_v = true
					forced_v = v * keep_recover              # slow down to a stop
					hunt_timer[i] -= delta
					if hunt_timer[i] <= 0.0:
						current_action[i] = Hunt.APPROACH

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
		steer = steer.limit_length(max_force)
		var new_v := v + steer * k_tick             # max_force per 1/60 s, whatever the tick rate
		new_v = new_v.limit_length(max_speed)
		if override_v:
			new_v = forced_v                       # charge / dash / recover: no steering, no speed cap
		if i == player_index:
			new_v = player_velocity     # player-controlled: the AI is ignored

	#--------Growth (simulated time: happens when enough energy, no timer)
		if current_action[i] == Hunt.IDLE:
			if _energy >= growth_cost[lifecycle]*1.2 and lifecycle < max_life_cycle:
				current_size[i] += growth_rate
				current_biomass[i] += growth_cost[lifecycle]/10
				current_life_state[i] +=1
				_energy -= growth_cost[lifecycle]

	#--------maintain cost (simulated time)
		_energy += -1.0 * step

	#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0

	#--------Duplicate: an adult full of energy dies, its corpse releases the eggs
		if _energy >= 5*seed_energy and lifecycle >= max_life_cycle:
			alive_array[i] = 0

		current_energy_array[i] = _energy

	#--------MOVE (tick time)
		var q := p + new_v * delta
		# borders (world is 0..size): wrap, or stop at the wall and bounce
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); new_v.x = -new_v.x
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y: q.y = clampf(q.y, 0.0, world_size.y); new_v.y = 0.0
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); new_v.z = -new_v.z
		position_array[i] = q
		new_velocity[i] = new_v
		current_velocity[i] = new_v

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


# --- Hunt helpers ----------------------------------------------------------------

## Fields of a prey species that show hunt-worthy agents: "juvenile" + "adult" when it
## has them (no eggs), else its whole density field.
func _prey_field_ids(prey_sp: ALIFE) -> PackedInt32Array:
	var ids := PackedInt32Array()
	if not hunt_eggs:
		for fname in ["juvenile", "adult"]:
			var fid := prey_sp.field_id(fname)
			if fid >= 0:
				ids.append(fid)
	if ids.is_empty():
		ids.append(prey_sp.field_id(FIELD_DENSITY))
	return ids


## Best prey around p among all prey species: smallest distance / affinity
## (corpses included when hunt_corpses, weighted by corpse_affinity).
## Returns Vector4(dx, dy, dz, global_id), id = -1 if none.
func _best_prey(p: Vector3, me: int, preys: Array[ALIFE], aff: PackedFloat32Array) -> Vector4:
	var best := Vector4(0.0, 0.0, 0.0, -1.0)
	var best_score := INF
	var rings := ceili(strike_range / maxf(alifemanager.cell_size.x, 0.001)) + 1
	rings = maxi(rings, 4)
	for k in preys.size():
		var found := _nearest_prey(p, me, preys[k], rings)
		if int(found.w) < 0:
			continue
		var score := Vector3(found.x, found.y, found.z).length() / maxf(aff[k], 0.001)
		if score < best_score:
			best_score = score
			best = found
	return best


## Like find_nearest, for agents of `prey_sp`: living ones, plus corpses when hunt_corpses
## (a corpse counts as farther away: distance / corpse_affinity).
## Ring search on the contact grid, wrap-aware, stops early once nothing closer can exist.
## Returns Vector4(dx, dy, dz, global_id), id = -1 if none.
func _nearest_prey(p: Vector3, me: int, prey_sp: ALIFE, max_rings: int) -> Vector4:
	var am := alifemanager
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var offs: PackedInt32Array = am.global_species_offset
	var lo := offs[prey_sp.species_id]
	var hi := offs[prey_sp.species_id + 1]
	var alive := prey_sp.alive_array
	var active := prey_sp.active_alife_array
	var life := prey_sp.current_life_state
	# Life cycle 0 = egg only for species that have eggs (an "egg" field)
	var skip_eggs := not hunt_eggs and prey_sp.field_id("egg") >= 0
	var ws: Vector3 = world.size
	var wx: bool = world.border_type_x == world.Border.WRAP
	var wz: bool = world.border_type_z == world.Border.WRAP

	var cx := clampi(int(p.x / cs.x), 0, W - 1)
	var cz := clampi(int(p.z / cs.z), 0, D - 1)
	var lim_x := mini(max_rings, (W - 1) / 2) if wx else max_rings
	var lim_z := mini(max_rings, (D - 1) / 2) if wz else max_rings
	var cmin := minf(cs.x, cs.z)
	var corpse_w := 1.0 / maxf(clampf(corpse_affinity, 0.0, 1.0), 0.001)
	corpse_w *= corpse_w                           # applied to the squared distance

	var best := -1
	var best_d2 := INF
	var best_d := Vector3.ZERO
	for r in max_rings + 1:
		# Anything in ring r is at least (r - 1) cells away: stop if we already have closer
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
						if active[local] == 0:
							continue                       # free slot
						if skip_eggs and life[local] == 0:
							continue                       # eggs aren't food
						var dead := alive[local] == 0
						if dead and (not hunt_corpses or prey_sp.current_biomass[local] <= 0.0):
							continue                       # not hunted, or already eaten
						var d: Vector3 = sorted_pos[k] - p
						if wx: d.x -= ws.x * roundf(d.x / ws.x)
						if wz: d.z -= ws.z * roundf(d.z / ws.z)
						var d2 := d.length_squared() * (corpse_w if dead else 1.0)
						if d2 < best_d2:
							best_d2 = d2
							best = j
							best_d = d
	return Vector4(best_d.x, best_d.y, best_d.z, float(best))


## Vector from p to a prey given by global id (shortest way on wrapped axes).
## x = INF if the prey no longer exists or is dead.
func _delta_to(target: int, p: Vector3, offs: PackedInt32Array, ws: Vector3,
		wx: bool, wy: bool, wz: bool) -> Vector3:
	if target < 0:
		return Vector3(INF, 0.0, 0.0)
	var s := offs.bsearch(target, false) - 1
	var local := target - offs[s]
	var sp = alifemanager.species_array[s]
	if sp.active_alife_array[local] == 0:
		return Vector3(INF, 0.0, 0.0)                # removed
	if sp.alive_array[local] == 0 and not hunt_corpses:
		return Vector3(INF, 0.0, 0.0)                # died and corpses aren't hunted
	var d: Vector3 = sp.position_array[local] - p
	if wx: d.x -= ws.x * roundf(d.x / ws.x)
	if wy: d.y -= ws.y * roundf(d.y / ws.y)
	if wz: d.z -= ws.z * roundf(d.z / ws.z)
	return d


## During the dash: eat the closest prey (or corpse) within catch radius. Returns the energy gained.
func _try_catch(p: Vector3, me: int, preys: Array[ALIFE], offs: PackedInt32Array,
		catch_r2: float) -> float:
	for k in preys.size():
		var found := _nearest_prey(p, me, preys[k], 1)
		var prey := int(found.w)
		if prey < 0 or Vector3(found.x, found.y, found.z).length_squared() > catch_r2:
			continue
		var s := offs.bsearch(prey, false) - 1
		var local := prey - offs[s]
		var sp_o = alifemanager.species_array[s]
		if sp_o.active_alife_array[local] != 0 and sp_o.current_biomass[local] > 0.0:
			# in the world, carried or thrown: all catchable (a carried one dies in the hands)
			sp_o.alive_array[local] = 0              # living: killed / corpse: stays dead
			var gained: float = sp_o.current_biomass[local]
			sp_o.current_biomass[local] = 0          # eaten: its species removes it
			return gained
	return 0.0


## Same as every species (ALIFE.Build_New_Life fills ALL the per-agent arrays,
## health and carry included), then the hunt arrays.
func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(0.159, 0.555, 0.215, 1.0)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return                               # world full (maxLife): nothing spawned
	ensure_hunt_arrays(entity_count)
	reset_hunt(i)                            # a reused slot must not keep a dead crab's dash
