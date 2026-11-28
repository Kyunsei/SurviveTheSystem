extends ALIFE
class_name ALIFE_GLOWBERRY
## Glowberry bush. At max life cycle it carries a ripe berry:
##   Interact or pick_up on it -> the berry (a new glowberry, life cycle 0) goes straight
##   into the hand of whoever did it, and the bush goes back one life cycle (ripens again).
##   If their hands are full, the berry falls on the ground next to the bush instead.
## Only berries (life cycle 0) can be carried, not grown bushes.


## Where it may grow: its species' height grid (given by NavWorld), null = flat ground.
var height_grid: HeightGrid = null


func _init() -> void:
	moves = false
	positions_static = true                      # never moves: field cells are cached
	species_name = "GLOWBERRY"

	#Rendering
	sprite = preload("res://Alife/Plant/Bush/berry-Sheet.png")
	hframes = 5
	vframes =2
	colour =Color(0.525, 0.114, 0.635, 1.0)

	#PHOT0
	photosynthesis_on = true
	photo_range = 2
	photo_layer_y = 0
	photo_optimal_value = 0.75
	photo_optimal_width = 0.35

	#LIFECYCLE/DUP
	duplication_range = 1
	init_size = 4
	seed_energy = 10
	seed_biomass = 100
	max_energy = 2000
	max_life_cycle = 4
	growth_cost = [100,100,100,1000,0] #Should be size of max_life+1
	growth_rate = 0.0
	has_seed = true  #just allow to spam even if not light available


func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	var local_pending_spawn_id := PackedInt32Array()
	var local_pending_remove_id := PackedInt32Array()

	# Read-only this tick: local copies are safe (arrays others write: through the member)
	var active := active_alife_array
	var sun_id := current_sungrid_id
	var sun_stamp := world.SUN_stamp
	var sun_grid := world.SUN_GRID
	var sun_W: int = world.SUN_GRID_W
	var costs := growth_cost

	var step := dt * sim_speed
	var photo_rate := 1.0
	var opt := float(photo_optimal_value)
	var inv_2w2 :float= 1.0 / (2.0 * photo_optimal_width * photo_optimal_width)
	var decay := 0.1 * step
	var upkeep := 0.4 * step
	var top := max_life_cycle
	var e_max := float(max_energy)

	for i in range(start, end):
		if active[i] != 1:
			continue                               # free slot, or a berry in someone's hand
		if alive_array[i] == 0:
			var b: float = current_biomass[i] - decay
			current_biomass[i] = b
			if b < 0.0:
				local_pending_remove_id.append(i)
			continue

		var e: float = current_energy_array[i]

		#--------EAT: photosynthesis
		if e < e_max:
			var sc := sun_id[i]
			var up := sc + sun_W                   # needs a layer above
			var x: float = sun_grid[up] / maxf(sun_stamp[up] + 1.0, photo_rate) - opt
			e += photo_rate * exp(-x * x * inv_2w2) / maxf(sun_stamp[sc], photo_rate) * step

		#--------Growth
		var life := current_life_state[i]
		var cost: float = costs[life]
		if life < top and e >= cost * 1.2:
			current_size[i] += growth_rate
			current_biomass[i] += cost / 10.0
			current_life_state[i] = life + 1
			if life + 1 < top:
				e -= cost

		#--------maintain cost
		e -= upkeep

		#--------DEATH
		if e < 0.0:
			alive_array[i] = 0

		current_energy_array[i] = e

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


## Interact (shake / use): harvest the ripe berry into the hand of whoever did it.
func Interact(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])
	harvest(i, sp, local_id)


## Only berries can be picked up; grown bushes stay planted.
func can_be_carried(i: int) -> bool:
	return current_life_state[i] == 0


## Ripe bush (max life cycle, alive, in the world)?
func is_ripe(i: int) -> bool:
	return active_alife_array[i] == 1 and alive_array[i] == 1 \
			and current_life_state[i] == max_life_cycle


## Takes the ripe berry of bush i: a new glowberry (life cycle 0) in carrier's hand,
## or on the ground next to the bush if its hands are full (or carrier_sp is null).
## The bush goes back one life cycle and pays the berry's energy.
## Returns true if a berry was made (false: not ripe, or the world is full).
func harvest(i: int, carrier_sp: ALIFE = null, carrier: int = -1) -> bool:
	if not is_ripe(i):
		return false

	# Build_New_Life doesn't return the index: it's the next free one
	var j: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var count_before := entity_count
	var at := on_floor(pick_random_position(Vector3(duplication_range, 0, duplication_range), position_array[i]))
	if at.x == INF:
		at = position_array[i]                   # no floor around: at the bush's foot
	Build_New_Life(at, seed_energy,0, current_color[i])
	if active_entity_count == count_before:
		return false                             # world full (maxLife): no berry
	current_life_state[i] -= 1                  # the bush ripens again later
	current_energy_array[i] -= 1000
	# Straight into the hand; if it fails (hands full), it just stays on the ground
	if carrier_sp != null and carrier >= 0:
		alifemanager.pick_up(carrier_sp, carrier, self, j)
	return true
