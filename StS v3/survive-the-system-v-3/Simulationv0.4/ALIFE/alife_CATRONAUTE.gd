extends ALIFE
class_name ALIFE_CATRONAUTE

## Downward acceleration for AI cats in the air, world units / s² of simulated time.
## 8 = the old "-0.8 per tick" at dt 0.1, so the feel at speed 1 is unchanged.
@export var gravity := 8.0

# ---- STATS (per agent, ECS arrays like position_array) ----------------------------
## Biggest size each cat can pick up: an item of size s needs carrying power >= ceil(s).
## (power 1: size up to 1.0 / power 2: up to 2.0 ...). See AlifeManager.pick_up.
var carrying_power := PackedInt32Array()
## Damage of one attack: each agent hit loses this much health.
var strength := PackedFloat32Array()
## Height of the surface under each cat, looked up in height_grid every tick.
## Without a walk area: ground_y, the flat ground as before.
var floor_y := PackedFloat32Array()
## Where cats can walk, given by NavWorld (null = flat ground, no walls).
var height_grid: HeightGrid = null

## Values given to every new cat (change them per cat afterwards, e.g. with growth or mutation)
@export var base_carrying_power := 5           # = a cat's own size (init_size 2.0)
@export var base_strength := 20.0              # = the old attack_damage


func _init() -> void:
	photosynthesis_on = false
	init_size = 2.0
	species_name = "CATRONAUTE"
	sprite =preload("res://Alife/animal/PLAYER/player_cat.png")
	hframes = 1
	vframes=1
	colour = Color(0.655, 0.154, 0.226, 1.0)

	max_energy = 2000
	max_speed = 6. #WIP might not work as intended

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 1000
	seed_biomass = 100
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


# ---- Stats --------------------------------------------------------------------------

func _init_alife_par():
	super()
	carrying_power = []
	strength = []
	floor_y = []


## Same as every species, then the stats of the new cat.
func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(0.159, 0.555, 0.215, 1.0)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return                               # world full (maxLife): nothing spawned
	if i >= carrying_power.size():           # new slot: grow the arrays
		carrying_power.append(base_carrying_power)
		strength.append(base_strength)
		floor_y.append(ground_y)
	else:                                    # reused slot: reset it
		carrying_power[i] = base_carrying_power
		strength[i] = base_strength
		floor_y[i] = ground_y


## Asked by AlifeManager.pick_up: can cat i lift this item?
func can_carry(i: int, item_sp, j: int) -> bool:
	return alifemanager.item_carry_class(item_sp, j) <= carrying_power[i]


## Asked by attacks: damage done by cat i.
func get_damage(i: int) -> float:
	return strength[i]


func run_chunk_simulation( start: int, end: int,local_id:int,delta:float, dt: float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function

	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array

	# Simulated time of this tick. Every rate below (per second) is multiplied by it,
	# and nothing is applied "per tick", so changing dt, sim_speed or the tick rate
	# never changes how fast things happen in simulated time.
	var step := dt * sim_speed

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
	var base := offs[species_id]                  # this species' first global id

	#FOOD
	var target_dist := 1.0
	var t_sp :ALIFE= alifemanager.codex.species.get("BUGSHEEP")
	var target_id := t_sp.species_id
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count

	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius

	#Walk area (read only here: safe on the worker threads)
	var hg := height_grid

	for i in range(start, end):
		# Only agents standing in the world move (held = 2, flying = 4 are moved elsewhere)
		if active_alife_array[i] != AlifeManager.ACTIVE:
			continue
		if alive_array[i] == 0:
			var b := current_biomass[i]
			b -= 0.1 * step                         # corpse decays 0.1 biomass / s
			current_biomass[i] = b
			if b < 0:
				local_pending_remove_id.append(i)
			continue

		var lifecycle := current_life_state[i]
		var _g_cost:=  growth_cost[lifecycle]
		var _energy:= current_energy_array[i]

		var p := position_array[i]
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)
		var _tc := t_count[c]
		var steer := Vector3.ZERO   # sum of forces (acceleration), NOT a velocity
		var v:Vector3= current_velocity[i]           # a real velocity (units / s)
		var _global_i := i + base
		# Surface under the cat (from the last tick), or the flat ground without a walk area
		var in_area := hg != null and (not hg.player_only or i == player_index)
		var fl: float = floor_y[i] if in_area else ground_y

	#--------VELOCITY
		var new_v: Vector3
		if i == player_index:
			# Player-controlled: the AI is ignored. Horizontal speed from the keys,
			# vertical from jump + gravity (_player_vertical has its own gravity).
			new_v = player_velocity
			new_v.y = _player_vertical_on(p.y, delta, fl)
		else:
			steer = steer.limit_length(max_force)
			new_v = v + steer * delta                # acceleration x time
			if p.y > fl + 0.001:
				new_v.y -= gravity * delta           # in the air: falls to the floor under it
			elif new_v.y < 0.0:
				new_v.y = 0.0                       # on the floor
			new_v = new_v.limit_length(max_speed)
			if new_v.length_squared() < 1e-8:
				new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) # small nudge

	#--------maintain cost
		_energy += -1.0 * step                      # 2 energy / s

	#--------DEATH
		if _energy < 0 or current_health[i] < 0:
			alive_array[i] = 0

		current_energy_array[i] = _energy

	#--------MOVE
		var q := p + new_v * delta                   # velocity x time
		# borders (world is 0..size): wrap, or stop at the wall and bounce
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); new_v.x = -new_v.x
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y:
			q.y = clampf(q.y, 0.0, world_size.y); new_v.y = 0.0   # floor / ceiling: stop, no bounce
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); new_v.z = -new_v.z
		# Walk area: the floor at the new spot. Not walkable, or a wall (higher than a step):
		# keep the move along one axis only (slides along walls), else stay in place.
		if in_area:
			var r := hg.move(p, q, fl)                 # (x, floor, z)
			q.x = r.x
			q.z = r.z
			fl = r.y
			# Solid geometry right under the feet (a steep hull edge, a wall top): land on it
			fl = maxf(fl, hg.solid_top_under(q.x, q.z, p.y))
			floor_y[i] = fl

		# Never below the floor under the cat: lands on it, or steps up onto it
		if q.y < fl:
			q.y = fl
			if new_v.y < 0.0:
				new_v.y = 0.0
		# Head room: under a bridge / in a cave, the head stops below the floor above
		if in_area:
			# From where the cat is (its floor, or higher in the air): only what's above it
			var ceil_y := hg.ceiling_at(q.x, q.z, maxf(fl, p.y))
			# (ceiling below the floor: the cat doesn't fit here at all. The move above
			# already pushes it out, so don't pin it to the floor meanwhile)
			if q.y > ceil_y and ceil_y >= fl:
				q.y = maxf(ceil_y, fl)
				if new_v.y > 0.0:
					new_v.y = 0.0
				if i == player_index:
					player_vy = minf(player_vy, 0.0)  # bumped the head: the jump ends
		position_array[i] = q
		new_velocity[i] = new_v
		current_velocity[i] = new_v                 # store the velocity, not the displacement

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


## Jump + gravity of the controlled cat, like ALIFE._player_vertical but with the floor
## under it (floor_h) instead of the flat ground_y: it can land on, and fall off, ledges.
func _player_vertical_on(y: float, dt: float, floor_h: float) -> float:
	var g := 2.0 * jump_height / (time_to_jump_apex * time_to_jump_apex)
	var grounded := y <= floor_h + 0.001 and player_vy <= 0.0
	if grounded:
		player_vy = 0.0
		player_air_time = 0.0
	else:
		player_air_time += dt

	# Jump: pressed recently (buffer) + on the floor or just left it (coyote)
	if player_jump_buffer > 0.0 and player_air_time <= coyote_time:
		player_vy = 2.0 * jump_height / time_to_jump_apex
		player_jump_buffer = 0.0
		player_air_time = coyote_time + 1.0     # no second jump in the air
		grounded = false

	# Gravity: stronger when falling, or when the key was released early
	if not grounded:
		var m := 1.0
		if player_vy < 0.0:
			m = fall_multiplier
		elif not player_jump_held:
			m = low_jump_multiplier
		player_vy = maxf(player_vy - g * m * dt, -max_fall_speed)
	return player_vy
