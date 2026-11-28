extends ALIFE
class_name ALIFE_CATTLE

#WANDER (random walk): a heading that drifts a little, at a steady speed, with pauses
@export var wander_speed := 3.0       # walking speed (units / s)
@export var wander_turn := 1.5        # how fast the heading can drift (radians / s)
@export var pause_chance := 0.2       # chance per second to stop for a moment (grazing)
@export var walk_chance := 0.5        # chance per second, when stopped, to walk again
@export var gravity := 20.0           # falling off a ledge (units / s²)

#WALKABLE AREA (given by NavWorld; null = flat ground at ground_y, no walls)
var height_grid: HeightGrid = null
var floor_y := PackedFloat32Array()   # height of the floor under each animal


func _init() -> void:
	photosynthesis_on = false
	init_size = 4.0
	sprite_scale = 2.0
	species_name = "CATTLE"
	sprite = preload("res://assets/Art from STS2/fill.png")
	#sprite =preload("res://Alife/animal/Herbivor/Sheep/SHEEP-Sheet.png")
	hframes = 1
	vframes=1
	colour = Color(0.772, 0.772, 0.772, 1.0)

	max_energy = 2500
	max_speed = 10.

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 600
	seed_biomass = 200 #
	max_life_cycle = 2
	growth_cost = [1000,1000,1000] #Should be size of max_life+1
	growth_rate = 0.5

	#State machine
	# full_threshold must stay above the duplication energy (1.5 * seed_energy * 3 = 2700),
	# or sheep stop eating before they can reproduce

	#contact par
	view_radius = 5.0	 #must be <= the contact grid cell size (only 3x3 cells are searched)
	separation_radius = 3.0

	w_separation = 2.0 #dont merge
	w_alignment =0.5 #follow other
	w_cohesion = 0.5# stay in group
	w_seek = 1.0# seek food
	max_force = 2.0 #how much power has steer

	#CONTROL (when a player plays it): slow and heavy, no jump, can't carry or throw
	uses_pilots = true
	control_speed = 2.0
	sprint_multiplier = 1.5
	can_jump = false
	control_actions = PlayerInput.SPRINT | PlayerInput.ACTION | PlayerInput.ATTACK
	attack_width = 2.5                    # a wide headbutt
	attack_length = 2.5
	attack_damage = 10.0
	attack_cooldown = 1.0





func _init_alife_par():
	super()
	floor_y = []


## Same as every species, then the floor under the new animal (where it was spawned).
func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(0.159, 0.555, 0.215, 1.0)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return                               # world full (maxLife): nothing spawned
	if i >= floor_y.size():
		floor_y.append(pos.y)
	else:
		floor_y[i] = pos.y


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
	

	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius

	#Walkable area (read only here: safe on the worker threads)
	var hg := height_grid


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
		var pl: Pilot = get_pilot(i) if pilot_id[i] >= 0 else null   # null = the AI
		var is_player := pl != null

		var p := position_array[i]
		var v:Vector3= current_velocity[i]
		#var global_i := i + base

	
		var new_v := _wander(v, delta)
		if is_player:
			new_v = control_velocity(pl, i, p, 0.0, delta, false)   # keys; _move does gravity
	#--------maintain cost
		#_energy += -1 * step * sim_speed

	#--------DEATH
		if _energy < 0 or current_health[i] <0 :
			alive_array[i] = 0


		#update Value
		current_energy_array[i] = _energy

	#--------MOVE (velocity is per second: dt only here)
		_move(i, p, new_v, delta, world_size, wrap_x, wrap_y, wrap_z, is_player, hg)

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


## Random walk: keeps walking roughly where it was going, the heading drifting a little
## (wander_turn), at wander_speed. Sometimes stops for a moment, then walks again.
## Time-based (delta): the same wandering at any frame rate.
func _wander(v: Vector3, delta: float) -> Vector3:
	var flat := Vector2(v.x, v.z)
	var moving := flat.length_squared() > 1e-4
	if moving:
		if randf() < pause_chance * delta:
			return Vector3.ZERO                    # stops (grazing)
		var ang := atan2(flat.y, flat.x) + randf_range(-1.0, 1.0) * wander_turn * delta
		return Vector3(cos(ang), 0.0, sin(ang)) * wander_speed
	if randf() < walk_chance * delta:
		var a := randf() * TAU                     # starts again, in a new direction
		return Vector3(cos(a), 0.0, sin(a)) * wander_speed
	return Vector3.ZERO


## Moves agent i by velocity v for this step. Borders: wrap, or bounce off the world's
## walls. With a height grid: walks on the real floors (ship deck, platforms), walls block
## (slides along them, turns away when stuck), falls off ledges, head stops under things.
## Without one: stays on the flat ground (ground_y).
func _move(i: int, p: Vector3, v: Vector3, delta: float, world_size: Vector3,
		wrap_x: bool, wrap_y: bool, wrap_z: bool, is_player: bool, hg: HeightGrid) -> void:
	var in_area := hg != null and (not hg.player_only or is_player) and i < floor_y.size()
	var fl: float = floor_y[i] if in_area else ground_y

	# Vertical: falls when above its floor
	v.y = current_velocity[i].y
	if p.y > fl + 0.001:
		v.y -= gravity * delta
	else:
		v.y = maxf(v.y, 0.0)

	var q := p + v * delta
	if wrap_x: q.x = fposmod(q.x, world_size.x)
	elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
	if wrap_z: q.z = fposmod(q.z, world_size.z)
	elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z

	if in_area:
		var r := hg.move(p, q, fl)                 # (x, floor, z): walls, edges, slides
		var wanted := Vector2(q.x - p.x, q.z - p.z)
		var got := Vector2(r.x - p.x, r.z - p.z)
		if wanted.length_squared() > 1e-8 and got.length_squared() < wanted.length_squared() * 0.25:
			# Blocked (or mostly): turn away in a new random direction
			var a := randf() * TAU
			var spd := Vector2(v.x, v.z).length()
			v.x = cos(a) * spd
			v.z = sin(a) * spd
		q.x = r.x
		q.z = r.z
		fl = maxf(r.y, hg.solid_top_under(q.x, q.z, p.y))   # lands on solid tops too
		floor_y[i] = fl
		if q.y < fl:
			q.y = fl                               # on the floor (or stepped up onto it)
			v.y = maxf(v.y, 0.0)
		var ceil_y := hg.ceiling_at(q.x, q.z, maxf(fl, p.y))
		if q.y > ceil_y and ceil_y >= fl:
			q.y = maxf(ceil_y, fl)                 # head under something
			v.y = minf(v.y, 0.0)
	else:
		if q.y < fl:
			q.y = fl                               # flat ground
			v.y = 0.0
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y > world_size.y:
			q.y = world_size.y
			v.y = 0.0

	position_array[i] = q
	new_velocity[i] = v
	current_velocity[i] = v                  # the VELOCITY, not the step's displacement
