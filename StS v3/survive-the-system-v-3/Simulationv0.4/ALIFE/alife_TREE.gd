extends ALIFE
class_name ALIFE_TREE


var current_photo_range : PackedInt32Array
var current_photo_layer : PackedInt32Array

#var seed_id : PackedInt32Array
var parent_id : PackedInt32Array             # fruit: the tree it hangs in (-1 = none)

#FRUITS---------
# Fruits are this species' seeds. They hang in the branches (state HANGING), fall
# when the tree is shaken (player interact), damaged, dies or is full, and can be
# grabbed from the branches by jumping. On the ground they're normal seeds (state 1).
# States in active_alife_array: 0 pool, 1 world, 2 held, 4 thrown (AlifeManager)
const HANGING := 3                           # in its tree
const FALLING := 5                           # dropping to the ground

var max_fruits := 3                          # per tree
var scatter_when_full := true                # tree full: the new fruit lands on the ground nearby,
											 # just outside the tree's photo range (no shade on it)
var scatter_extra := 3.0                     # random extra distance beyond the photo range (world units)
var ripe_fruits_fall := true                 # (scatter_when_full off) tree full: oldest fruit falls
var fruit_height_min := 0.15                 # branches zone, in fractions of the tree height
var fruit_height_max := 0.45
var fruit_spread := 0.3                     # how far out in the branches (1 = sprite edge)
var damage_drop_chance := 1.0 #5                # chance each fruit falls when the tree is hit
var fruit_gravity := 9.8
#var ground_y := 0.0

#LIFE CYCLE FIELDS (created in _init): living agents at each stage, per field cell
# Fruits count on the ground or carried, not hanging in a tree / falling / thrown,
# dead or alive (animals eat dead fruits too).
# Saplings and trees count when standing in the world.
var fruit_field := -1                        # life state 0
var sapling_field := -1                      # life state 1
var tree_field := -1                         # life state 2 and above

var fruit_offset : PackedVector3Array        # position in its tree, in units of tree height
var hanging : PackedInt32Array               # fruits in trees (follow their tree)
var falling : PackedInt32Array               # fruits dropping
var _last_dt := 0.16

func _init() -> void:
	species_id = 1
	species_name = "tree"
	photosynthesis_on = true
	photo_range = 0 #7
	photo_layer_y = 1
	sprite = preload("uid://xe8k30kjeyh6")
	hframes = 3
	vframes=1
	colour = Color(0.678, 0.372, 0.439, 1.0)
	photo_optimal_value  = 0.5
	photo_optimal_width  = 0.01

	has_seed = true
	shadow_from_photo_range = true           # shadow as wide as the shaded area (photo range)
	native_shadow = true                     # real shadow from the sun (DirectionalLight3D)
	caster_params = {"light_gaps": 0.35, "canopy_at": 0.75, "flatten": 0.35}   # leafy holes, canopy height
	caster_params = {"light_gaps": 0.2, "ragged_edge": 0.2, "canopy_at": 0.75, "flatten": 0.35}
	copy_params = {"receive_shadow": false}   # tree sprites aren't darkened by shadows
	#LIFECYCLE/DUP
	duplication_range = 8
	init_size = .5
	
	seed_energy = 100
	seed_biomass = 10
	
	max_health = 25
	max_energy = 1000
	max_life_cycle = 5 #growt_cost size -1
	growth_cost = [0,200,100,100,100,100] #Should be size of max_life
	growth_rate = 3
	
	
	#
	current_photo_range = []
	current_photo_layer =[]
	parent_id = []
	fruit_offset = []
	hanging = []
	falling = []

	#Life cycle fields: living agents only
	fruit_field = add_field("fruit", FieldSource.COUNT, -1.0, -1.0, false, 0, 0,
			[1, AlifeManager.HELD])                  # on the ground or carried, dead too
	sapling_field = add_field("sapling", FieldSource.COUNT, -1.0, -1.0, true, 1, 1)
	tree_field = add_field("tree", FieldSource.COUNT, -1.0, -1.0, true, 2)      # 2 and above

func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	var step :=  dt * sim_speed                              # fixed simulated time per tick (speed = more ticks)
												 # (trees keep their own 0.16: same pace as before)
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)

	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	#var H := alifemanager.GRID_H
	#var D := alifemanager.GRID_D
	var sun_stamp := world.SUN_stamp
	var sun_grid := world.SUN_GRID
	var sun_W := world.SUN_GRID_W
	var photo_rate := 1.0
	var value:= 0.0

	
	_last_dt = dt                                # for falling fruits (main thread)
	for i in range(start, end):
		if active_alife_array[i] != 1:           # pool, held, hanging, thrown, falling
			continue
		if alive_array[i] == 0:
			if active_alife_array[i] == 1:
				var b = current_biomass[i]
				b -= 0.1 * step
				current_biomass[i] = b
				if b < 0:
					local_pending_remove_id.append(i)
				continue
				
		var _energy:= current_energy_array[i]
		var lifecycle := current_life_state[i]
		var g_cost:=  growth_cost[lifecycle]
		var sun_c := current_sungrid_id[i]		
			
		#EGG TIME---------
		if lifecycle == 0:
			_energy -= 1 * step
			if _energy < 0:
				if  sun_stamp[sun_c] > 1 or sun_stamp[sun_c+sun_W] > 0:
					alive_array[i] = 0
				else:
					current_life_state[i]+=1
					current_size[i] += growth_rate/2
					_energy = seed_energy
					var r: = 1
					stamp(sun_c,current_photo_range[i],0,current_photo_layer[i],-1.0)
					current_photo_range[i]= r
					current_action[i] = mini(r, 15)          # sent to the shadow shader
					current_photo_layer[i]= 1
					stamp(sun_c,r,0,current_photo_layer[i],1.0)

			
			current_energy_array[i] = _energy
			continue
			
			
		#--------EAT
		# Photosynthesis (cached per cell for this frame)
		if _energy < max_energy:
			#_energy += photo(i,sun_W,sun_stamp, sun_grid) * dt
			var sun_c_up := sun_c + sun_W #WORK ONLY IF THERE IS A LAYER ABOVE
			var d:= sun_stamp[sun_c]
			var d_up := sun_stamp[sun_c_up] +1
			value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
			var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
			_energy += value2 /maxf(d, photo_rate) *step

		#--------maintain cost
		_energy += -0.7  * step # - (side * side - side) *dt #* active_alife_array[i]
		#--------DEATH
		if _energy < 0 or current_health[i] <0 :
			alive_array[i] = 0
	
	#--------Growth

		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			stamp(sun_c,current_photo_range[i],0,current_photo_layer[i],-1.0)

			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			_energy -= g_cost	
			current_photo_range[i]= current_photo_range[i]+1
			current_action[i] = mini(current_photo_range[i], 15)   # sent to the shadow shader
			#if lifecycle == 1:
			#	current_photo_layer[i] = 1
				#photo_optimal_value =0.5
			
			stamp(sun_c,current_photo_range[i],0,current_photo_layer[i],1.0)

			
		#--------Duplicate
		if _energy >= seed_energy*1.5 and lifecycle == max_life_cycle:
			local_pending_spawn_id.append(i)
			_energy -= seed_energy
		
		
		#update energy
		current_energy_array[i] = _energy	
		
		
		

			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id



func Build_New_Life(pos: Vector3, e: float = seed_energy,lc:=0, col := Color(0.159, 0.555, 0.215, 1.0), stored := 1,parentid := -1):
	if alifemanager.global_entity_count >= alifemanager.maxLife and alifemanager.maxLife>0:
		return -1

	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(stored)
		position_array.append(pos)
		current_health.append( max_health)
		current_max_health.append( max_health)
		current_color.append(col)
		color_packed.append(0)
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array.append(1) 
		current_velocity.append(Vector3.ZERO)
		new_velocity.append(Vector3.ZERO)
		current_life_state.append(lc)
		current_biomass.append(seed_biomass)
		current_age.append(0)
		current_size.append(init_size)
		current_action.append(0)
		current_photo_layer.append(0)
		current_photo_range.append(0)
		parent_id.append(parentid)
		fruit_offset.append(Vector3.ZERO)
		holding.append(-1)
		held_by.append(-1)		

		current_sungrid_id.append(get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D))
		current_grid_id.append(get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D))
		
		current_cpu_cost.append(0)
		neighbour_count.append(0)
		#update_bin_array(i)
		entity_count += 1

		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = stored
		position_array[i] = pos
		current_color[i]=col
		current_health[i] = max_health
		current_max_health[i] = max_health
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array[i] = 1
		current_velocity[i] = Vector3.ZERO
		new_velocity[i] = Vector3.ZERO
		current_sungrid_id[i] = get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
		current_grid_id[i] = get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
		current_life_state[i]=lc
		current_biomass[i]=seed_biomass
		current_age[i]=0
		current_size[i]=init_size
		current_cpu_cost[i] = 0
		neighbour_count[i] = 0
		current_action[i] = 0
		current_photo_layer[i] = 0
		current_photo_range[i] = 0
		parent_id[i] = parentid
		fruit_offset[i] = Vector3.ZERO
		holding[i] =-1
		held_by[i] = -1	

	active_entity_count += 1
	if photosynthesis_on and stored == 1:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]#int(init_size.x)-1
			stamp(c,r,0,current_photo_layer[i],1.0)

	pending_multimesh_drawn_id.append(i)
	return i


## Only agents standing in the world (state 1) are stamped in the sun grid.
## Held / thrown ones (2 / 4) were already taken off the count and the drawing by Stock_Life.
func Remove_Life(i):
	var state: int = active_alife_array[i]
	if state == 0:
		return
	_forget_fruit(i)
	active_alife_array[i]= 0
	free_indices.append(i)

	var stocked := state == AlifeManager.HELD or state == AlifeManager.FLYING
	if not stocked:
		active_entity_count -= 1
		pending_multimesh_erase_id.append(i)

	if photosynthesis_on and state == 1:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]#int(init_size.x)-1
			stamp(c,r,0,current_photo_layer[i],-1.0)


## Leave the world (picked up). Only for agents standing in the world.
func Stock_Life(i):
	if active_alife_array[i] != 1:
		return
	active_alife_array[i]= 2 # STORED ?

	active_entity_count -= 1
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]
			var l := current_photo_layer[i]
			stamp(c,r,0,l,-1.0)
	pending_multimesh_erase_id.append(i)


## Back in the world (dropped / landed). Only for stocked agents (held or thrown).
func Release_Life(i):
	var state: int = active_alife_array[i]
	if state != AlifeManager.HELD and state != AlifeManager.FLYING:
		return
	active_alife_array[i]= 1 # STORED ?
	active_entity_count += 1

	current_sungrid_id[i] = get_cell_id(position_array[i],world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
	current_grid_id[i] = get_cell_id(position_array[i],alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
	current_velocity[i] = Vector3.ZERO
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]
			var l := current_photo_layer[i]
			stamp(c,r,0,l,1.0)

			
	pending_multimesh_drawn_id.append(i)



func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
	
	for i in pending_spawn_id:
		if has_seed:
			_grow_fruit(i)
			continue
		# No seed: a sapling right next to the tree (previous behaviour)
		var center := position_array[i]
		#center.y += current_size[i]/2  +1.5#*128/2
		var newpos := pick_random_position(Vector3(duplication_range,0.0,duplication_range),center)
		if photosynthesis_on:
			var s_c := get_cell_id(newpos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
			if world.SUN_stamp[s_c] > 0 :
				continue
		Build_New_Life(newpos,seed_energy,0, current_color[i],1, i )

	for i in pending_remove_id:
		Remove_Life(i)	

	pending_spawn_id.clear()
	pending_remove_id.clear()

	_update_hanging()
	_update_falling(_last_dt)


## Action on this agent (by the player or another agent): a grown tree drops its fruits.
func Interact(i:int, sp:ALIFE, local_id:int):
	if current_life_state[i] == 0:
		return                                   # a seed / fruit: nothing to shake
	print("%s ID: %d shakes %s ID: %d" %[sp.species_name, local_id, species_name, i])
	drop_fruits(i, 1.0)


## Only seeds / fruits can be picked up, not grown trees.
func can_be_carried(i: int) -> bool:
	return true #current_life_state[i] == 0


## Called when this agent takes damage (player attack, or other species).
func on_damaged(i:int, _sp:ALIFE, _local_id:int):
	drop_fruits(i, damage_drop_chance)


#FRUITS-------------------------------------------------------------------------------------------

## Every fruit of tree i falls, each with this chance.
func drop_fruits(i: int, chance := 1.0) -> void:
	for j in hanging.duplicate():
		if parent_id[j] == i and randf() < chance:
			_start_fall(j)


## Closest fruit hanging within `reach` of `point` (e.g. a jumping agent's head), or -1.
func find_hanging_fruit(point: Vector3, reach: float) -> int:
	var best := -1
	var best_d := reach * reach
	for j in hanging:
		var p: Vector3 = WorldWrap.nearest_image(position_array[j], point)
		var d := p.distance_squared_to(point)
		if d <= best_d:
			best_d = d
			best = j
	return best


## Take a fruit off its branch, in the world where it is (to be picked up right after).
func detach_fruit(j: int) -> void:
	if active_alife_array[j] != HANGING:
		return
	_forget_fruit(j)
	parent_id[j] = -1
	_place_in_world(j)


## A new fruit in the branches of tree i. Tree full: the fruit lands on the ground nearby
## instead (scatter_when_full), or the oldest one falls to make room (ripe_fruits_fall).
func _grow_fruit(i: int) -> void:
	if active_alife_array[i] == 0 or alive_array[i] == 0:
		return
	if _fruit_count(i) >= max_fruits:
		if scatter_when_full:
			_scatter_fruit(i)
			return
		if not ripe_fruits_fall:
			return
		_drop_oldest_fruit(i)
	var off := _random_fruit_offset()
	var j = Build_New_Life(position_array[i] + off * _tree_height(i), seed_energy,0,
			current_color[i], HANGING, i)
	if j == null or j < 0:
		return                                   # population limit reached
	fruit_offset[j] = off
	hanging.append(j)


## A seed on the ground near tree i, just outside its photo range (the sun-grid cells the
## tree shades), in a random direction.
func _scatter_fruit(i: int) -> void:
	var cs: Vector3 = world.SUN_cell_size
	var cell := maxf(cs.x, cs.z)
	var min_d := (current_photo_range[i] + 1) * cell     # first cell outside the shade
	var a := randf() * TAU
	var d := min_d + randf() * scatter_extra
	var p: Vector3 = position_array[i] + Vector3(cos(a) * d, 0.0, sin(a) * d)
	p.y = ground_y
	p = alifemanager.keep_in_world(p)
	Build_New_Life(p, seed_energy,0, current_color[i], 1, -1)   # state 1: on the ground


## Every tick: fruits stay in their tree's branches (it may move, grow or be carried).
## Tree removed or dead: its fruits fall.
func _update_hanging() -> void:
	for j in hanging.duplicate():
		var t: int = parent_id[j]
		if t < 0 or active_alife_array[t] == 0 or alive_array[t] == 0:
			_start_fall(j)
			continue
		position_array[j] = position_array[t] + fruit_offset[j] * _tree_height(t)


func _start_fall(j: int) -> void:
	_forget_fruit(j)
	parent_id[j] = -1
	active_alife_array[j] = FALLING
	current_velocity[j] = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
	falling.append(j)


## Every tick: falling fruits drop with gravity, then become seeds on the ground.
func _update_falling(dt: float) -> void:
	for j in falling.duplicate():
		var v: Vector3 = current_velocity[j]
		v.y -= fruit_gravity * dt
		var p: Vector3 = position_array[j] + v * dt
		if p.y <= ground_y:
			p.y = ground_y
			position_array[j] = p
			_forget_fruit(j)
			_place_in_world(j)
		else:
			position_array[j] = p
			current_velocity[j] = v


## Hanging / falling fruit -> seed standing in the world (state 1), where it is now.
## Fruits of a tree near the border can hang outside the world: brought back in here.
func _place_in_world(j: int) -> void:
	position_array[j] = alifemanager.keep_in_world(position_array[j])
	active_alife_array[j] = 1
	current_velocity[j] = Vector3.ZERO
	current_sungrid_id[j] = get_cell_id(position_array[j],world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
	current_grid_id[j] = get_cell_id(position_array[j],alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
	if photosynthesis_on:
		stamp(current_sungrid_id[j], current_photo_range[j], 0, current_photo_layer[j], 1.0)


func _forget_fruit(j: int) -> void:
	var k := hanging.find(j)
	if k >= 0:
		hanging.remove_at(k)
	k = falling.find(j)
	if k >= 0:
		falling.remove_at(k)


func _fruit_count(i: int) -> int:
	var n := 0
	for j in hanging:
		if parent_id[j] == i:
			n += 1
	return n


func _drop_oldest_fruit(i: int) -> void:
	for j in hanging:                            # in growth order: the first one is the oldest
		if parent_id[j] == i:
			_start_fall(j)
			return


## Height of tree i's sprite in world units.
func _tree_height(i: int) -> float:
	return current_size[i] * _quad_size().y


## Random spot in the branches zone, in units of the tree height.
func _random_fruit_offset() -> Vector3:
	var q := _quad_size()
	var half_width := 0.5 * q.x / maxf(q.y, 0.001)     # sprite half width / height
	var a := randf() * TAU
	var r := sqrt(randf()) * half_width * fruit_spread
	return Vector3(cos(a) * r, randf_range(fruit_height_min, fruit_height_max), sin(a) * r)


func _quad_size() -> Vector2:
	if renderer3D != null and renderer3D.multimesh != null and renderer3D.multimesh.mesh is QuadMesh:
		return (renderer3D.multimesh.mesh as QuadMesh).size
	return Vector2.ONE
