extends ALIFE
class_name ALIFE_GRASS

## Energy below this: photosynthesis on. Energy lost per second (simulated).
const FEED_BELOW := 100.0                        # seed_energy * 2
const UPKEEP := 0.7

## Where it may grow: its species' height grid (given by NavWorld), null = flat ground.
var height_grid: HeightGrid = null


func _init() -> void:
	moves = false
	positions_static = true                      # never moves: field cells are cached

	species_name = "GRASS"
	#PHOT
	photosynthesis_on = true
	photo_layer_y = 0
	photo_range = 0
	photo_optimal_value = 1
	photo_optimal_width = 0.2
	
	#LIFECYCLE/DUP
	duplication_range = 50
	init_size = 0.5
	seed_energy = 50
	seed_biomass = 5
	max_life_cycle = 3
	max_health = 5
	growth_cost = [50,50,50,50] #Should be size of max_life
	growth_rate = 0.4
	
	spawn_on_floor = false

## One tick for agents [start, end). Every per-agent number is computed once per chunk;
## locals are typed (untyped = slower Variant math). Arrays that other species write while
## this runs (alive, biomass, energy... when they eat it) are only used through the member,
## never copied into a local: a local copy would make their writes go to another array.
func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	var local_pending_spawn_id := PackedInt32Array()
	var local_pending_remove_id := PackedInt32Array()

	# Read-only this tick (nobody else writes them meanwhile): local copies are safe
	var active := active_alife_array
	var sun_id := current_sungrid_id
	var sun_stamp := world.SUN_stamp
	var sun_grid := world.SUN_GRID
	var sun_W: int = world.SUN_GRID_W
	var costs := growth_cost

	# Constants for this chunk
	var step := dt * sim_speed
	var photo_rate := 1.0
	var opt := float(photo_optimal_value)
	var inv_2w2 :float= 1.0 / (2.0 * photo_optimal_width * photo_optimal_width)
	var feed_below := FEED_BELOW
	var decay := 0.1 * step                      # corpse biomass lost per tick
	var upkeep := UPKEEP * step                  # energy lost per tick
	var dup_at := seed_energy * 1.5
	var top := max_life_cycle
	var grow := growth_rate

	for i in range(start, end):
		var st := active[i]
		if st == 0:
			continue
		if alive_array[i] == 0:
			if st == 1:
				var b: float = current_biomass[i] - decay
				current_biomass[i] = b
				if b < 0.0:
					local_pending_remove_id.append(i)
			continue                             # dead: nothing else (carried ones too)

		var e: float = current_energy_array[i]
		#--------EAT: photosynthesis
		if e < feed_below:
			var sc := sun_id[i]
			var up := sc + sun_W                 # needs a layer above
			var x: float = sun_grid[up] / maxf(sun_stamp[up] + 1.0, photo_rate) - opt
			e += photo_rate * exp(-x * x * inv_2w2) / maxf(sun_stamp[sc], photo_rate) * step

		#--------Growth
		var life := current_life_state[i]
		var cost: float = costs[life]
		if life < top and e >= cost * 1.2:
			current_size[i] += grow
			current_biomass[i] += 5.0
			current_life_state[i] = life + 1
			e -= cost

		#--------maintain cost
		e -= upkeep

		#--------DEATH
		if e < 0.0 or current_health[i] < 0.0:
			alive_array[i] = 0

		#--------Duplicate
		if e >= dup_at:
			local_pending_spawn_id.append(i)
			e -= seed_energy

		current_energy_array[i] = e

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


## Spawns and removes of the tick. A seed lands on the floor under where it falls (height
## grid), and only where the sun grid lets it grow.
func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])

	var d_range := duplication_range
	for i in pending_spawn_id:
		var newpos := on_floor(pick_random_position(Vector3(d_range, 0, d_range), position_array[i]))
		if newpos.x == INF:
			continue                             # no floor there (wall, outside the area)
		if photosynthesis_on and !has_seed:
			var s_c := get_cell_id(newpos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
			var s_c_up := s_c + world.SUN_GRID_W
			if world.SUN_stamp[s_c] > 0 or world.SUN_stamp[s_c_up] > 0:
				continue
		Build_New_Life(newpos,seed_energy,0, current_color[i])

	for i in pending_remove_id:
		Remove_Life(i)

	pending_spawn_id.clear()
	pending_remove_id.clear()
