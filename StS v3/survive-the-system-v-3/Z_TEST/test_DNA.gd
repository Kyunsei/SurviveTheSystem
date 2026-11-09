class_name TESTDNA
extends RefCounted



#TODO make it close more easily? kindof fixed by stopping when FPS too low?
#TODO wait thread?
#TODO fix chunk number/order or make it random?
#TODO simulation time in threads?
#TODO optimise array extension and pending array? maybe more efficient code way -> check claude idea
#TODO sensing alife x alife : wolrd partioning + flow?
#TODO add physics collision/gravity?
#TODO optimise AI

##Simulation par
#var time := 0.0
var dt :float= 0.0#.32
var total_time := 0
#var time_counter := 1

#cross reference
var world: World
var alife_GRID : PackedInt32Array
var alifemanager : AlifeManager

#entity managemnt
var free_indices : Array =[]
var entity_count : int
var active_entity_count : int

#ECS STATS
var position_array : PackedVector3Array
var current_energy_array : PackedFloat64Array
var current_velocity : PackedVector3Array
var new_velocity : PackedVector3Array


var active_alife_array : PackedInt32Array  #To reuse some 
var alive_array : PackedInt32Array

var color_array : PackedColorArray
var current_life_state : PackedInt32Array
var current_biomass : PackedFloat32Array
var current_age : PackedInt32Array
var current_size : PackedVector3Array
var init_size := Vector3(1,1,1)

var current_sungrid_id : PackedInt32Array
var current_grid_id : PackedInt32Array

var current_cpu_cost : PackedInt32Array

#### Duplicate
var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array
var pending_update_id: PackedInt32Array #check if in use


##RENDERING
var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array
var pending_multimesh_update_id : PackedInt32Array #check if in use

var renderer2D : AlifeRenderer2D
var renderer3D : AlifeRenderer3D
var rend_data : AlifeRenderingData

var sprite := preload("res://Alife/Plant/Grass/grass.png")
var name := "Test Species"

'var gid_r : int
var rendering_data : PackedFloat32Array
var r_data_per_chunk : Array[PackedFloat32Array] = []
var writting_rendering_buffer_usec:= 0.0'

#var rendering_buffer : PackedFloat32Array
#const STRIDE := 12  #buffer + colors

#####AI THINGS¬¬¬¬¬
#var AI_on := false
var current_action :PackedByteArray
var action_scores := PackedFloat32Array()  # allocated once, reused

enum Action { MOVE, EAT, DUPLICATE }
var sp_Action_weight : PackedFloat32Array = [1.,-1.,-0.2]
const ACTION_COUNT := 3
const WEIGHTS := [1.0, 1.0, 1.0] 
var MOMENTUM := 1.2
var mouse_target : Vector3

### ALIFE GRID - agent - agent close detection

#old? CHECK THSI ONE?

'var bin_on = false
var cell_size := 10.0

var GRID_W := 32          # cells along x
var GRID_H := 16          # cells along y
var GRID_D := 32          # cells along z
var GRID_WD := GRID_W * GRID_D
var GRID_WH := GRID_W * GRID_H
var NUM_CELLS := GRID_W * GRID_H * GRID_D

var bin_origin := Vector3.ZERO   # min corner of the grid in world space

var cell_start := PackedInt32Array()     # size NUM_CELLS + 1
var write_pos := PackedInt32Array()      # size NUM_CELLS (scratch)
var cell_items := PackedInt32Array()     # size = alife count
var current_cell_id := PackedInt32Array()  # size = alife count
var sorted_pos := PackedVector3Array()'

###SpeciesParameters
var growth_rate := 0.25
var colour := Color(0.193, 0.404, 0.283, 1.0)
const CORPSE_COLOR := Color(0.488, 0.077, 0.15, 0.2)
var species_id := 0

var photo_range := 0
var photo_optimal_value = 1.0
var photo_optimal_width = 0.2

		
		
var duplication_range := 15

#Randomness
const JITTER_COUNT := 4096
var _jitter: PackedVector3Array
var _jhead: int = 0

###multithread things
var gid := -1
#var nThread_max := 8#1  #store on alifemnager
var chunk_count: int
var chunk_size: int
var mutex := Mutex.new()
var spawn_per_chunk : Array[PackedInt32Array] = []
var remove_per_chunk : Array[PackedInt32Array] = []
var update_per_chunk : Array[PackedInt32Array] = [] #NEED TO check if needed
var photo_rate_per_chunk : Array[PackedFloat32Array] = []

#Perf Measurmnt #TODO
var chunk_usec: PackedInt64Array
var chunk_tid: PackedInt64Array
var	total_thread_usec := 0.
var thread_usec := 0.
var	multithread_efficiency := 0.
var	nThreadused := 0

var main_usec = 0
var uai_usec = 0
var bin_screen_usec = 0
var bin_action_usec = 0
var bin_update_usec = 0

###
var metabo_usec := 0.0
var growth_usec := 0.0



##TEST
const usec_budget := 20_000

#############################################################################################
##############################################################################################


func init(worldd,alifm):
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))

	
	entity_count = 0
	active_entity_count =0
	free_indices = [] 
	
	#alife 
	position_array = [] 
	current_energy_array = [] 
	current_velocity = []
	new_velocity = []

	active_alife_array = []   #To reuse some 
	alive_array = []
	current_sungrid_id = []
	current_grid_id = []
	
	pending_multimesh_drawn_id = []
	pending_multimesh_update_id = []
	pending_multimesh_erase_id = []
	
	pending_spawn_id = []
	pending_update_id = []
	pending_remove_id = []
	
	color_array = []	
	current_life_state= []
	current_biomass= []
	current_age= []
	current_size= []
	
	current_cpu_cost = []
		
	
	#AI
	action_scores.resize(ACTION_COUNT)
	current_action = []
	
	#Bin??
	#TODO
	
	##WORLD
	world = worldd
	alifemanager = alifm
	#init_GRID(world.size)
	build_offsets()

	##Rendering
	#rend_data = AlifeRenderingData.new()
	#rendering_buffer.resize(rendering.multimesh.instance_count * STRIDE)




	
	#rendering = RenderingALife2D.new()
	#rendering.init(self,world)
	#multimesh.species = self
	#species_array[s].rendering = mm


####MULTITHREAD
func set_chunk(n:int):
	#for perf tracking 
	chunk_usec.resize(n)
	chunk_tid.resize(n)	
	#reshape temp chunk array
	spawn_per_chunk.resize(n)
	remove_per_chunk.resize(n)
	update_per_chunk.resize(n)	
	photo_rate_per_chunk.resize(n)
	#REndering
	#r_data_per_chunk.resize(n)
	for i in n:
		spawn_per_chunk[i] = []   # clear the previous frame's results
		remove_per_chunk[i] = []
		photo_rate_per_chunk[i] = []
		#r_data_per_chunk[i] = []
	



func run_chunk_simulation( start: int, end: int,local_id:int, dt: float) -> void:
	dt = 0.16 * 1 #TODO
	var dup_on := alifemanager.duplicate_on
	var homeo_on := alifemanager.homeostasis_on
	var interaction_on := alifemanager.interaction_on
	var bin_on := alifemanager.bin_on
	var AI_on := alifemanager.AI_on
	#var visu_on := alifemanager.visualisation_on
	var photo_on := alifemanager.photosynthesis_on
	var agent_photo_calculate := alifemanager.agent_calculated_photo_value
	var remove_on := alifemanager.remove_on
	var grow_on := alifemanager.grow_on
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)

	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP

	if AI_on:

		'for i in range(start, end):
			Move_random(i,wrap_x,wrap_y,wrap_z,world_size)'
		
	
		if bin_on and alifemanager.global_position_array.size() >0:
			Flock(start,end,dt)

		#COMBINE MOVMNT AND CHECK BORDER
		for i in range(start, end):
			var q := position_array[i] + new_velocity[i] * dt
			var v := new_velocity[i]
			# borders (world is 0..size)
			if wrap_x: q.x = fposmod(q.x, world_size.x)
			elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
			if wrap_y: q.y = fposmod(q.y, world_size.y)
			elif q.y < 0.0 or q.y > world_size.y: q.y = clampf(q.y, 0.0, world_size.y); v.y = -v.y
			if wrap_z: q.z = fposmod(q.z, world_size.z)
			elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z
			position_array[i] = q
			current_velocity[i] = v

		
						
	if !photo_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()

			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue	
			var _energy:= current_energy_array[i]
			if _energy < 5:		
				current_energy_array[i] += (1) * dt	
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									
	if photo_on:
		'var ad := [0.0,1.0/4,1.0/3,1.0/2,1.0]
		var arr := []
		for v in ad:
			var value2 =1* exp(-((v - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
			arr.append(value2)
		print(arr)'

		'f(x) = a · e^(−(x − b)² / (2c²))

		a = the height of the peak
		b = the position of the centre of the peak
		c = the width (how spread out the curve is)
		e ≈ 2.718 (Euler’s number'
		var global_photo_rate := alifemanager.current_global_photosynthesis_rate
		var sun_grid := world.SUN_GRID 
		var W := world.SUN_GRID_W
		var H := world.SUN_GRID_H

		var photo_rate = alifemanager.photo_absorption_rate


		var value :=  0.0
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue		
			var _energy:= current_energy_array[i]
			if _energy < 5:
				var sun_c := current_sungrid_id[i]
				var sun_c_up := sun_c + W #WORK ONLY IF THERE IS A LAYER ABOVE
				#var total := global_photo_rate[sun_c]
				var r:= photo_range
				var total := 0.0
				var ry := 0
				var d:= global_photo_rate[sun_c]
				var d_up := global_photo_rate[sun_c_up] +1
				if !agent_photo_calculate or r==0:
					#value = d  #or stamp value
					value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
					var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
					#print("%f value and take %f , for %f optimal" %[value,value2, photo_optimal_value] )
					current_energy_array[i] += value2 /maxf(d, photo_rate) * dt
					
					#( sun_grid[sun_c] * photo_rate *  dt) /   maxf(d, photo_rate) 

				else:
					#TODO WITH SHADOW
						for off in offsets[r * (RY_MAX + 1) + ry]:
								var cc := sun_c + off
								if cc >= global_photo_rate.size():
									continue
								var d2 := global_photo_rate[cc]
								if d2 > 1e-6:
									total += world.SUN_GRID[cc] * photo_rate/ maxf(d2, photo_rate)  	
						current_energy_array[i] += total * dt
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									
	if homeo_on:
		var side := 2 * photo_range + 1 #not account of y dimension
		for i in range(start, end):
			var _energy:= current_energy_array[i]

			#var t := Time.get_ticks_usec()
			_energy += -0.6  * dt # - (side * side - side) *dt #* active_alife_array[i]
			if _energy < 0 :
				alive_array[i] = 0
			current_energy_array[i] = _energy
		#photo_rate_per_chunk[local_id] = local_photo_rate
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

	if interaction_on and bin_on:
		if  alifemanager.global_position_array.size() >0 :
			var radius := 8.0									
			var W := alifemanager.GRID_W
			var H := alifemanager.GRID_H
			var D := alifemanager.GRID_D
			var WH := W * H
			var offs: PackedInt32Array = alifemanager.global_species_offset
			var global_pos: PackedVector3Array = alifemanager.global_position_array
			var cell_start: PackedInt32Array = alifemanager.cell_start
			var cell_items: PackedInt32Array = alifemanager.cell_items
			var species_array := alifemanager.species_array  # precomputed once per frame
			var size: Vector3 = world.size
			#var wrap_x: bool = world.border_type_x == world.Border.WRAP
			#var wrap_y: bool = world.border_type_y == world.Border.WRAP
			#var wrap_z: bool = world.border_type_z == world.Border.WRAP
			var r2 := radius * radius
			var base := offs[species_id]
			var nx := mini(3, W)
			var ny := mini(3, H)
			var nz := mini(3, D)

			for i in range(start, end):
				var p: Vector3 = position_array[i]
				var global_i := i + base
				var c: int = current_grid_id[i]
				var cx := c % W
				var cy := (c / W) % H
				var cz := c / WH

				for dz in range(-1, -1 + nz):
					var z := cz + dz
					if z < 0 or z >= D:
						if not wrap_z: continue
						z = posmod(z, D)
					var zoff := z * WH

					for dy in range(-1, -1 + ny):
						var y := cy + dy
						if y < 0 or y >= H:
							if not wrap_y: continue
							y = posmod(y, H)
						var yoff := zoff + y * W

						for dx in range(-1, -1 + nx):
							var x := cx + dx
							if x < 0 or x >= W:
								if not wrap_x: continue
								x = posmod(x, W)
							var cell := yoff + x

							for k in range(cell_start[cell], cell_start[cell + 1]):
								var other: int = cell_items[k]
								if other == global_i:
									continue
								var d: Vector3 = global_pos[other] - p
								if wrap_x: d.x -= size.x * roundf(d.x / size.x)
								if wrap_y: d.y -= size.y * roundf(d.y / size.y)
								if wrap_z: d.z -= size.z * roundf(d.z / size.z)
								if d.length_squared() <= r2:
									var sp_other := species_array[other]
									var local_idx := other - offs[sp_other.species_id]
									# ... use neighbour
																		
	if grow_on:	
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			var ei:= current_energy_array[i]
			var cls := current_life_state[i]
			current_age[i] += 1
			if cls <2:
				if ei > 3:
					current_life_state[i] += 1
					current_energy_array[i] -= 3
					current_size[i]*= 0.5 #growth_rate
					current_biomass[i] += 2
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

			#current_age[i]+=1
	if dup_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			var _energy:= current_energy_array[i]
			if _energy >= 5:
				local_pending_spawn_id.append(i)
				_energy -= 5
			current_energy_array[i] = _energy
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									


		spawn_per_chunk[local_id] = local_pending_spawn_id
	if remove_on:
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			if alive_array[i] == 0 and active_alife_array[i] == 1:
				local_pending_remove_id.append(i)
			#current_cpu_cost[i]	+= Time.get_ticks_usec() -t 									

		remove_per_chunk[local_id] = local_pending_remove_id
	

##########################################################################################
#### Main loop function
##########################################################################################
	
func Move_random(i,wrap_x,wrap_y,wrap_z,size):
		var p: Vector3 = position_array[i] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		p.x = fposmod(p.x, size.x) if wrap_x else clampf(p.x, 0.0, size.x)
		p.y = fposmod(p.y, size.y) if wrap_y else clampf(p.y, 0.0, size.y)
		p.z = fposmod(p.z, size.z) if wrap_z else clampf(p.z, 0.0, size.z)
		position_array[i] = p		


func Flock(start,end,dt):
	#world
	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP	
	var cell_size := alifemanager.cell_size		
	var W := alifemanager.GRID_W
	var H := alifemanager.GRID_H
	var D := alifemanager.GRID_D
	var WH := W * H
	var nx := W if (wrap_x and W < 3) else 3
	var ny := H if (wrap_y and H < 3) else 3
	var nz := D if (wrap_z and D < 3) else 3
	
	#alifeglobal
	var offs: PackedInt32Array = alifemanager.global_species_offset
	var global_pos: PackedVector3Array = alifemanager.global_position_array
	var global_sorted_pos: PackedVector3Array = alifemanager.sorted_pos
	var cell_start: PackedInt32Array = alifemanager.cell_start
	var cell_items: PackedInt32Array = alifemanager.cell_items
	var species_array:= alifemanager.species_array  # precomputed once per frame
	var base := offs[species_id] #to find own global id
	
	#flock par

	var view_radius := 15.0	
	var separation_radius := 12.0
	var view_r2 := view_radius * view_radius
	var sep_r2 := separation_radius * separation_radius
	var w_separation := 2.0
	var w_alignment := 1.0
	var w_cohesion := 0.5
	var max_force := 10.0


	var total_n := 0
	for i in range(start, end):
		var n:= 0 #number of compatible neighbour
		var sum_d := Vector3.ZERO      # for cohesion sum dist
		var sum_v := Vector3.ZERO      # for alignment sum velocity
		var sep := Vector3.ZERO
		var p: Vector3 = position_array[i]
		var v:Vector3= current_velocity[i]
		var global_i := i + base
		'var c: int = current_grid_id[i]  #current_grid_id not updated yet!
		var cx := c % W
		var cy := (c / W) % H
		var cz := c / WH'
		var cx := mini(int(p.x / cell_size.x), W - 1)
		var cy := mini(int(p.y / cell_size.y), H - 1)
		var cz := mini(int(p.z / cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)
		for dz in range(-1, -1 + nz):
			var z := cz + dz
			if z < 0 or z >= D:
				if not wrap_z: continue
				z = posmod(z, D)
			var zoff := z * WH
			for dy in range(-1, -1 + ny):
				var y := cy + dy
				if y < 0 or y >= H:
					if not wrap_y: continue
					y = posmod(y, H)
				var yoff := zoff + y * W
				for dx in range(-1, -1 + nx):
					var x := cx + dx
					if x < 0 or x >= W:
						if not wrap_x: continue
						x = posmod(x, W)
					var cell := yoff + x
					
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var other: int = cell_items[k]
					
						if other == global_i:
							continue
				
						var d: Vector3 = (global_sorted_pos[k] - p)
						if wrap_x: d.x -= world_size.x * roundf(d.x / world_size.x)
						if wrap_y: d.y -= world_size.y * roundf(d.y / world_size.y)
						if wrap_z: d.z -= world_size.z * roundf(d.z / world_size.z)
						var dist2: = d.length_squared()
						
						if dist2 > view_r2 or dist2 ==0:
							continue
						#print(dist2)
						var sp_i := offs.bsearch(other, false) - 1
						var sp_other := species_array[sp_i] #TODO HERE
						var local_idx := other - offs[sp_i]
						
						if species_id == sp_i:
											# same species -> flock with it
							n += 1
							sum_d += d
							sum_v += sp_other.current_velocity[local_idx]
							if dist2 < sep_r2:
								sep -= d / dist2           # stronger the closer it is
							#elif sp.is_predator:               # <- adapt to your predator check
							#	flee -= d / dist2
							#	threatened = tru

		var steer := Vector3.ZERO
		if n>0 :
			var align_w := w_alignment #* (0.3 if calm else 1.0)
			var coh_w := w_cohesion #* (0.3 if calm else (3.0 if herd else 1.0))  # selfish herd
			steer += sep * w_separation
			steer += (sum_v / n - v) * align_w
			steer += (sum_d / n) * coh_w
		#steer += flee * w_flee
		steer = steer.limit_length(max_force)	
		var new_v :Vector3= v + steer * dt
		var s := new_v.length()
		if s < 0.0001:
			new_v = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) #.normalized() * min_speed
		else:
			new_v = new_v / s * clampf(s, 1, 10)		
		new_velocity[i] = new_v

##########################################################################################
####GRID/SUN MANAGEMENT
##########################################################################################
const R_MAX := 3
const RY_MAX := 3
var offsets: Array[PackedInt32Array] = []   # index = r * (RY_MAX + 1) + ry

func build_offsets() -> void:
	offsets.resize((R_MAX + 1) * (RY_MAX + 1))
	for r in R_MAX + 1:
		for ry in RY_MAX + 1:
			var list := PackedInt32Array()
			for dz in range(-r, r + 1):
				for dy in range(-ry, ry + 1):
					for dx in range(-r, r + 1):
						var nx := float(dx) / maxf(r, 0.5)
						var ny := float(dy) / maxf(ry, 0.5)
						var nz := float(dz) / maxf(r, 0.5)
						if nx * nx + ny * ny + nz * nz > 1.0:
							continue
						list.append(dx)
						list.append(dy)
						list.append(dz)
			offsets[r * (RY_MAX + 1) + ry] = list	

func stamp(c: int, r: int, ry: int, layer: int, w: float) -> void:
	if !alifemanager.agent_photo_stamp_on:
		alifemanager.current_global_photosynthesis_rate[c] += w
		return

	var W: int = world.SUN_GRID_W
	var H: int = world.SUN_GRID_H
	var D: int = world.SUN_GRID_D
	var PLANE := W * H

	# split flat index c into x, y, z (layer shifts y upward)
	var cx := c % W
	var cy := (c / W) % H + layer
	var cz := c / PLANE

	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP

	var list: PackedInt32Array = offsets[r * (RY_MAX + 1) + ry]
	for k in range(0, list.size(), 3):
		var x := cx + list[k]
		if wrap_x: x = posmod(x, W)
		elif x < 0 or x >= W: continue

		var y := cy + list[k + 1]
		if wrap_y: y = posmod(y, H)
		elif y < 0 or y >= H: continue

		var z := cz + list[k + 2]
		if wrap_z: z = posmod(z, D)
		elif z < 0 or z >= D: continue

		alifemanager.current_global_photosynthesis_rate[x + y * W + z * PLANE] += w

	if layer != 0:
		alifemanager.current_global_photosynthesis_rate[c] += w


func get_cell_id(pos: Vector3,cell_size:Vector3, W:int , H:int, D:int)-> int :
		var inv := Vector3.ONE / cell_size # worldd.SUN_cell_size   # (1/x, 1/y, 1/z)
		var p := (pos - world.bin_origin) * inv  #MAYBE HERE TO CHANGE?
		var cx := clampi(roundi(p.x), 0, W - 1)
		var cy := clampi(roundi(p.y), 0, H - 1)
		var cz := clampi(roundi(p.z), 0, D - 1)
		var c := cx + W * (cy + H * cz)   # inline, no second division
		return c

##########################################################################################
####ARRAY MANAGEMENT + SPAWN/REMOVE
##########################################################################################
	
func Build_and_remove_pendings():
	for c in spawn_per_chunk.size():
		pending_remove_id.append_array(remove_per_chunk[c])
		pending_spawn_id.append_array(spawn_per_chunk[c])
	
	var d_range:= duplication_range
	for i in pending_spawn_id:
		var newpos := pick_random_position(Vector3(d_range,0,d_range),position_array[i])
		Build_New_Life(newpos,0.0, color_array[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	



	pending_spawn_id.clear()
	pending_remove_id.clear()


func Build_New_Life(pos: Vector3, e: float, col := Color(0.159, 0.555, 0.215, 1.0)):
	if alifemanager.entity_count >= alifemanager.maxLife and alifemanager.maxLife>0:
		return
	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(1)
		position_array.append(pos)
		current_action.append(0)
		#species_id.append(sp)
		color_array.append(col)
		alive_array.append(1) 
		current_velocity.append(Vector3.ZERO)
		new_velocity.append(Vector3.ZERO)
		#current_bin_id.append(get_binID(pos,bin_size,world.size))
		current_life_state.append(1)
		current_biomass.append(0)
		current_age.append(0)
		current_size.append(init_size)

		current_sungrid_id.append(get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D))
		current_grid_id.append(get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D))
		
		current_cpu_cost.append(0)
		#update_bin_array(i)
		entity_count += 1

		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = 1
		position_array[i] = pos
		current_action[i] = 0
		#species_id[i] = sp
		color_array[i]=col
		alive_array[i] = 1
		current_velocity[i] = Vector3.ZERO
		new_velocity[i] = Vector3.ZERO
		current_sungrid_id[i] = get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
		current_grid_id[i] = get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
		#current_bin_id[i] = get_binID(pos,bin_size,world.size)
		#update_bin_array(i)
		current_life_state[i]=1
		current_biomass[i]=0
		current_age[i]=0
		current_size[i]=init_size
		current_cpu_cost[i] = 0

	active_entity_count += 1
	if alifemanager.photosynthesis_on:
			#var r := photo_range
			#var pos2 := pos
			
			#pos2.y += world.SUN_cell_size.y*1.5
			#var c_up :=  get_world_cell_id(pos2,world)
			var c := current_sungrid_id[i]
			#var c_calc := c +  world.SUN_GRID_W
			var height := int(init_size.y)-1
			var r := int(init_size.x)-1
			stamp(c,r,0,height,1.0)
			#alifemanager.current_global_photosynthesis_rate[current_worldpos_cell_id[i]] += 1.0 #TEMP

			
	
	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 0
	free_indices.append(i)
	active_entity_count -= 1
	
	if alifemanager.photosynthesis_on:
			#var r := photo_range
			var c := current_sungrid_id[i]
			var height := int(init_size.y)-1
			var r := int(init_size.x)-1
			stamp(c,r,0,height,-1.0)
			#stamp(c,r,0,0,-1.0)
	
	
	pending_multimesh_erase_id.append(i)


func Stock_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 2 # STORED ?
	#free_indices.append(i)
	#active_entity_count -= 1
	if alifemanager.photosynthesis_on:
			var c := current_sungrid_id[i]
			var height := int(init_size.y)-1
			var r := int(init_size.x)-1
			stamp(c,r,0,height,-1.0)
	pending_multimesh_erase_id.append(i)
	

func Release_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 1 # STORED ?
	current_sungrid_id[i] = get_cell_id(position_array[i],world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
	current_grid_id[i] = get_cell_id(position_array[i],alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
	current_velocity[i] = Vector3.ZERO
	if alifemanager.photosynthesis_on:
			var c := current_sungrid_id[i]
			#var c_calc := c +  world.SUN_GRID_W
			var height := int(init_size.y)-1
			var r := int(init_size.x)-1
			stamp(c,r,0,height,1.0)

			
	pending_multimesh_drawn_id.append(i)	

func find_free_index():
	var i : int
	if free_indices.size()> 0:
		i = free_indices.pop_back()
	else:
		i = entity_count
	return i 	

##########################################################################################
####HELP FUNCTION
##########################################################################################

func pick_random_on_axis(range_array: float, mid_point: float, border_type: int, limit: float) -> float:
	var lo := mid_point - range_array
	var hi := mid_point + range_array
	if border_type == world.Border.WALL:
		# clamp the range inside the world [0, limit]
		return randf_range(maxf(lo, 0.0), minf(hi, limit))
	# WRAP: pick freely, then wrap back into [0, limit)
	return fposmod(randf_range(lo, hi), limit)

func pick_random_position(rangee: Vector3, centerr: Vector3) -> Vector3:
	return Vector3(
		pick_random_on_axis(rangee.x,centerr.x, world.border_type_x, world.size.x),
		pick_random_on_axis(rangee.y,centerr.y ,world.border_type_y, world.size.y),
		pick_random_on_axis(rangee.z,centerr.z ,world.border_type_z, world.size.z)
	)


################################################################################
####RENDERING: write data to renderer #TODO OPTIMISATION
## LOOK also at script for renderer 2D/3D and visu manager
################################################################################
const STATE_BITS  := 2
const ACTION_BITS := 4
const SIZE_BITS   := 6
const AGE_BITS    := 12        # total must be <= 24

const ACTION_SHIFT := STATE_BITS                  # 2
const SIZE_SHIFT   := ACTION_SHIFT + ACTION_BITS  # 6
const AGE_SHIFT    := SIZE_SHIFT + SIZE_BITS      # 12

const STATE_MASK  := (1 << STATE_BITS) - 1        # 3
const ACTION_MASK := (1 << ACTION_BITS) - 1       # 15
const SIZE_MASK   := (1 << SIZE_BITS) - 1         # 63
const AGE_MASK    := (1 << AGE_BITS) - 1          # 4095

const SIZE_MIN := 0.5
const SIZE_MAX := 100.0

func pack_agent(size: float, action: int, state: int, age: int) -> float:
	var q := roundi(clampf(inverse_lerp(SIZE_MIN, SIZE_MAX, size), 0.0, 1.0) * SIZE_MASK)
	var v := (clampi(state, 0, STATE_MASK)) \
		| (clampi(action, 0, ACTION_MASK) << ACTION_SHIFT) \
		| (q << SIZE_SHIFT) \
		| (clampi(age, 0, AGE_MASK) << AGE_SHIFT)
	return float(v)

func write_rendering_buffer_in_chunk(start: int, end: int) -> void:
	var visu_on := alifemanager.visualisation_on #Can be set before probably
	var r_data:= rend_data.data
	#r_data.resize((end-start)*4)
	if visu_on:
		#var r_data:= renderer.data
		for i in range(start, end):
			var p:= position_array[i]
			var o := i * 4 #need to match STRIDE of renderer
			'if renderer.data[o + 3] != active_alife_array[i]:
				continue'
			r_data[o]     = p.x #* dt     # x
			r_data[o + 1] = p.z # * dt     # y
			r_data[o + 2] = active_alife_array[i]
			r_data[o + 3] = pack_agent(current_size[i].x,0,active_alife_array[i],current_life_state[i])# current_life_state[i]
		#r_data_per_chunk[local_id] = r_data



#####################################OLD BELOW##############################
#############################################################################

func _ready() -> void:
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))



'func init_GRID(world_size):
	var dims := Vector3i((world_size / cell_size).ceil())
	GRID_W = dims.x         # cells along x
	GRID_H = dims.y       # cells along y
	GRID_D = dims.z         # cells along z
	GRID_WD = GRID_W * GRID_D
	GRID_WH = GRID_W * GRID_H
	NUM_CELLS = GRID_W * GRID_H * GRID_D
	cell_start.resize(NUM_CELLS + 1)
	write_pos.resize(NUM_CELLS)'


func getChunk_perf():
	var threads := {}
	var total := 0
	var max_time := 0.0
	for i in chunk_count:
			threads[chunk_tid[i]] = true
			total += chunk_usec[i]
			max_time = max(max_time,chunk_usec[i])
	total_thread_usec = total
	thread_usec = max_time
	multithread_efficiency = float(total) / maxf(1.0, float(main_usec))
	nThreadused = threads.size() # OS.get_processor_count()
	
