extends ALIFE
class_name ALIFE_TREE


var current_photo_range : PackedInt32Array
var current_photo_layer : PackedInt32Array

#var seed_id : PackedInt32Array
var parent_id : PackedInt32Array

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
	
	#LIFECYCLE/DUP
	duplication_range = 8
	init_size = .5
	
	seed_energy = 250
	seed_biomass = 25
	
	max_energy = 1000
	max_life_cycle = 5 #growt_cost size -1
	growth_cost = [250,350,350,350,350,350] #Should be size of max_life
	growth_rate = 3
	
	
	#
	current_photo_range = []
	current_photo_layer =[]
	parent_id = []

func run_chunk_simulation( start: int, end: int,local_id:int, delta: float, sim_speed:float) -> void:
	var dt := 0.16 * sim_speed #TODO
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

	
	for i in range(start, end):
		if active_alife_array[i] == 3: #in tree
			continue
		if active_alife_array[i] == 0:
			continue
		if alive_array[i] == 0:
			if active_alife_array[i] == 1:
				var b = current_biomass[i]
				b -= 0.1 * dt *sim_speed
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
			_energy -= 2 * dt * sim_speed
			if _energy < 0:
				if  sun_stamp[sun_c] > 1 or sun_stamp[sun_c+sun_W] > 1:
					alive_array[i] = 0
				else:
					current_life_state[i]+=1
					current_size[i] += growth_rate/2
					_energy = seed_energy
					var r: = 1
					stamp(sun_c,current_photo_range[i],0,current_photo_layer[i],-1.0)
					current_photo_range[i]= r
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
			_energy += value2 /maxf(d, photo_rate) *dt

		#--------maintain cost
		_energy += -0.7  * dt # - (side * side - side) *dt #* active_alife_array[i]
		
		#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0
	
	#--------Growth

		if _energy >= g_cost*1.2 and lifecycle < max_life_cycle:
			stamp(sun_c,current_photo_range[i],0,current_photo_layer[i],-1.0)

			current_size[i] += growth_rate
			current_biomass[i] += g_cost/10
			current_life_state[i] +=1
			_energy -= g_cost	
			current_photo_range[i]= current_photo_range[i]+1
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



func Build_New_Life(pos: Vector3, e: float = seed_energy, col := Color(0.159, 0.555, 0.215, 1.0), stored := 1,parentid := -1):
	if alifemanager.global_entity_count >= alifemanager.maxLife and alifemanager.maxLife>0:
		return

	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(stored)
		position_array.append(pos)
		current_color.append(col)
		color_packed.append(0)
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array.append(1) 
		current_velocity.append(Vector3.ZERO)
		new_velocity.append(Vector3.ZERO)
		current_life_state.append(0)
		current_biomass.append(seed_biomass)
		current_age.append(0)
		current_size.append(init_size)
		current_action.append(0)
		current_photo_layer.append(1)
		current_photo_range.append(0)
		parent_id.append(parentid)
		

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
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array[i] = 1
		current_velocity[i] = Vector3.ZERO
		new_velocity[i] = Vector3.ZERO
		current_sungrid_id[i] = get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
		current_grid_id[i] = get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
		current_life_state[i]=0
		current_biomass[i]=seed_biomass
		current_age[i]=0
		current_size[i]=init_size
		current_cpu_cost[i] = 0
		neighbour_count[i] = 0
		current_action[i] = 0
		current_photo_layer[i] = 1
		current_photo_range[i] = 0
		parent_id[i] = parentid


	active_entity_count += 1
	if photosynthesis_on and stored == 1:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]#int(init_size.x)-1
			stamp(c,r,0,current_photo_layer[i],1.0)

	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 0
	free_indices.append(i)
	active_entity_count -= 1
	
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]#int(init_size.x)-1
			stamp(c,r,0,current_photo_layer[i],-1.0)

	pending_multimesh_erase_id.append(i)


func Stock_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 2 # STORED ?

	active_entity_count -= 1
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := current_photo_range[i]
			var l := current_photo_layer[i]
			stamp(c,r,0,l,-1.0)
	pending_multimesh_erase_id.append(i)
	

func Release_Life(i):
	if active_alife_array[i] == 0:
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
	
	var d_range:= duplication_range
	for i in pending_spawn_id:
		var center := position_array[i]
		center.y += current_size[i]/2  +1.5#*128/2
		var newpos := pick_random_position(Vector3(3.5,2.0,3.5),center)
		if photosynthesis_on and !has_seed:
			var s_c := get_cell_id(newpos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
			if world.SUN_stamp[s_c] > 0 :
				continue
		Build_New_Life(newpos,seed_energy, current_color[i],3, i )
	
	for i in pending_remove_id:
		Remove_Life(i)	

	pending_spawn_id.clear()
	pending_remove_id.clear()


func Interact(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])
	if active_alife_array[i] == 3:
		active_alife_array[i] = 2
		parent_id[i] = -1
	else:
		for j in entity_count:
			if parent_id[j] == i:
				position_array[j].y = 0
				active_alife_array[j] =1
				parent_id[j] = -1
