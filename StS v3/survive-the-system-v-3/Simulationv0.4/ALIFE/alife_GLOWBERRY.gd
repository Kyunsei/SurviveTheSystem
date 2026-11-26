extends ALIFE
class_name ALIFE_GLOWBERRY
## Glowberry bush. At max life cycle it carries a ripe berry:
##   Interact or pick_up on it -> the berry (a new glowberry, life cycle 0) goes straight
##   into the hand of whoever did it, and the bush goes back one life cycle (ripens again).
##   If their hands are full, the berry falls on the ground next to the bush instead.
## Only berries (life cycle 0) can be carried, not grown bushes.


func _init() -> void:
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


func run_chunk_simulation( start: int, end: int,local_id:int, dt: float, sim_speed:float) -> void:
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array

	var sun_stamp := world.SUN_stamp
	var sun_grid := world.SUN_GRID
	var sun_W := world.SUN_GRID_W
	var photo_rate := 1.0
	var value:= 0.0

	for i in range(start, end):
		if active_alife_array[i] != 1:
			continue                               # free slot, or a berry in someone's hand
		if alive_array[i] == 0:
			var b = current_biomass[i]
			b -= 0.1 * dt *sim_speed
			current_biomass[i] = b
			if b < 0:
				local_pending_remove_id.append(i)
			continue

		var _energy:= current_energy_array[i]

		#--------EAT
		# Photosynthesis (cached per cell for this frame)
		if _energy < max_energy:
			var sun_c := current_sungrid_id[i]
			var sun_c_up := sun_c + sun_W #WORK ONLY IF THERE IS A LAYER ABOVE
			var d:= sun_stamp[sun_c]
			var d_up := sun_stamp[sun_c_up] +1
			value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate)
			var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
			_energy += value2 /maxf(d, photo_rate)  *  dt * sim_speed

	#--------Growth
		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]

		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			if (lifecycle+1) < max_life_cycle:
				_energy -= g_cost


	#--------maintain cost
		_energy += -0.4  *  dt * sim_speed

		#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0

		#update energy
		current_energy_array[i] = _energy
		#print(current_energy_array[i])
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
	var at := pick_random_position(Vector3(duplication_range, 0, duplication_range), position_array[i])
	Build_New_Life(at, seed_energy,0, current_color[i])
	if active_entity_count == count_before:
		return false                             # world full (maxLife): no berry

	current_life_state[i] -= 1                  # the bush ripens again later
	current_energy_array[i] -= seed_energy
	print(current_life_state[i])
	# Straight into the hand; if it fails (hands full), it just stays on the ground
	if carrier_sp != null and carrier >= 0:
		alifemanager.pick_up(carrier_sp, carrier, self, j)
	return true
