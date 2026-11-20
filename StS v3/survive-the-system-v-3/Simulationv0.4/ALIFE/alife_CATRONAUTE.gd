extends ALIFE
class_name ALIFE_CATRONAUTE


var player_vy := 0.0               # vertical speed of the controlled agent
var player_jump_buffer := 0.0      # > 0: jump pressed recently (set by the picker)
var player_jump_held := false      # jump key still held (variable height)
var player_air_time := 0.0         # time since leaving the ground (coyote time)

@export_group("JUMP")
@export var jump_height := 8.0
@export var time_to_jump_apex := 3.5
@export var fall_multiplier := 2.0        # falls faster than it rises
@export var low_jump_multiplier := 2.5    # key released early: shorter jump
@export var coyote_time := 0.12
@export var max_fall_speed := 30.0
@export var ground_y := 0.0


## Vertical physics of the controlled agent. Returns its vertical speed for this step.
func _player_vertical(y: float, dt: float) -> float:
	var g := 2.0 * jump_height / (time_to_jump_apex * time_to_jump_apex)
	var grounded := y <= ground_y + 0.001 and player_vy <= 0.0
	if grounded:
		player_vy = 0.0
		player_air_time = 0.0
	else:
		player_air_time += dt

	# Jump: pressed recently (buffer) + on the ground or just left it (coyote)
	if player_jump_buffer > 0.0 and player_air_time <= coyote_time:
		player_vy = 2.0 * jump_height / time_to_jump_apex
		player_jump_buffer = 0.0
		player_air_time = coyote_time + 1.0     # no second jump in the air
		grounded = false
	player_jump_buffer = maxf(player_jump_buffer - dt, 0.0)

	# Gravity: stronger when falling, or when the key was released early
	if not grounded:
		var m := 1.0
		if player_vy < 0.0:
			m = fall_multiplier
		elif not player_jump_held:
			m = low_jump_multiplier
		player_vy = maxf(player_vy - g * m * dt, -max_fall_speed)
	return player_vy

func _init() -> void:
	photosynthesis_on = false
	init_size = 2.0
	species_name = "CATRONAUTE"
	sprite =preload("res://Alife/animal/PLAYER/player_cat.png")
	hframes = 1
	vframes=1
	colour = Color(0.655, 0.154, 0.226, 1.0)
	
	max_energy = 2500
	max_speed = 6. #WIP might not work as intended

	#LIFECYCLE/DUP
	duplication_range = 2
	seed_energy = 600
	seed_biomass = 2000
	max_life_cycle = 2
	growth_cost = [1000,1000,1000] #Should be size of max_life+1
	growth_rate = 0.5	
	
	
	#food part
	
	#Flock par
	#contact par
	view_radius = 19.0	 #need to be < that contact cell grid
	separation_radius = 18.0
	

	w_separation = 2.0 #dont merge
	w_alignment =0.5 #follow other
	w_cohesion = 0.5# stay in group
	w_seek = 1.0# seek food
	max_force = 2.0 #how much power has steer

	
func run_chunk_simulation( start: int, end: int,local_id:int, dt: float, sim_speed:float) -> void:
	if alifemanager.global_position_array.size()<1:
		return #NEED At least one update before somme function
	
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)
	
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
	var base := offs[alifemanager.species_array.size()-1]		
	
	#FOOD
	var target_dist := 1.0
	var t_sp :ALIFE= alifemanager.codex.species.get("BUGSHEEP")
	var target_id := t_sp.species_id
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count
	
	#Flock
	var view_r2 := view_radius*view_radius
	var sep_r2 := separation_radius*separation_radius
	


	for i in range(start, end):
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
		var v:Vector3= current_velocity[i]
		var _global_i := i + base
		
	#--------APPLY STEERING, once
		steer = steer.limit_length(max_force)      # "=" not "+="
		var new_v := v + steer * dt *sim_speed
		new_v = new_v.limit_length(max_speed)
		if new_v.length_squared() < 1e-8:
			new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) #* 0.1   # small nudge
		
		if i == player_index:
			new_v = player_velocity # player-controlled: the AI is ignored
			new_v.y = _player_vertical(position_array[i].y, dt*sim_speed)  # jump + gravity

			#new_v = new_v.limit_length(max_speed)
		if p.y > 0 : new_v.y -=0.8
		new_velocity[i] = new_v
	#--------maintain cost
		# _energy += -1 *  dt * sim_speed  # - (side * side - side) *dt #* active_alife_array[i]
		
	#--------DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
	#--------Duplicate
		if _energy >= 1.5*seed_energy:
			#local_pending_spawn_id.append(i)
			_energy -= seed_energy
			
			
			
			
		#update Value
		
		current_energy_array[i] = _energy	
		##
		var nv := new_velocity[i] * dt * sim_speed
		var q := p + nv
		# borders (world is 0..size)
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y: q.y = clampf(q.y, 0.0, world_size.y); v.y = -v.y
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z
		position_array[i] = q
		current_velocity[i] = nv
		print(position_array[i])		

			
	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id
