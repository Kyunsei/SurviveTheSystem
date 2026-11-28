extends RefCounted
class_name ALIFE

#This script deal with core loop of agent in every thread
#it is run by alifemanger
#the current version is species specific
#need to think how i do a unique one for agent to evolve in different species
#currently,  each species herit/extend from this one and need to cutomise the main loop

#TODO simulation time in threads?
#TODO add physics collision/gravity?

# ---- Simulation parameters -------------------------------------------
#var dt :float= 0.0#.32
var total_time := 0 #inUSE?

var world: WorldManager
var alifemanager : AlifeManager

# ---- ARRAY management variables -------------------------------------------
var free_indices : Array =[]
var entity_count : int
var active_entity_count : int #not in use currently

var pending_spawn_id : PackedInt32Array
var pending_remove_id: PackedInt32Array
var pending_update_id: PackedInt32Array #check if in use

#multithread
var spawn_per_chunk : Array[PackedInt32Array] = []
var remove_per_chunk : Array[PackedInt32Array] = []
var update_per_chunk : Array[PackedInt32Array] = [] 

# ---- ALIFE ECS stats -------------------------------------------------------
#Physics and position
var position_array : PackedVector3Array
var current_energy_array : PackedFloat64Array
var current_velocity : PackedVector3Array
var new_velocity : PackedVector3Array

#Status
var active_alife_array : PackedInt32Array  #To reuse some 
var alive_array : PackedInt32Array
var current_action: PackedInt32Array  #not yet in use but already in shader and intialized

#GROWTH. life cycle
var current_life_state : PackedInt32Array
var current_biomass : PackedFloat32Array
var current_age : PackedInt32Array
var current_size : PackedFloat32Array
var current_health : PackedFloat32Array
var current_max_health : PackedFloat32Array
var init_size := 1.0

#WORLD GRID REFERENCES
#Not totally in use, not yet update if moved
var current_sungrid_id : PackedInt32Array
var current_grid_id : PackedInt32Array  


#interaction
var holding := PackedInt32Array()   # global id of the item I carry, -1 = none
var held_by := PackedInt32Array()   # global id of who carries me, -1 = none
var facing := PackedVector3Array()   # last direction faced (the player's arrow), for carried items
#not in use
var current_cpu_cost : PackedInt32Array
var current_color :PackedColorArray


# ---- RENDERING -------------------------------------------------------
#Each species has its own renderer.  the script here just manage to write to the rend_data
#make the link between the two also
var renderer2D : AlifeRenderer2D
var renderer3D : AlifeRenderer3D
var rend_data : AlifeRenderingData


#ARRAY stuff
var pending_multimesh_drawn_id : PackedInt32Array
var pending_multimesh_erase_id : PackedInt32Array
var pending_multimesh_update_id : PackedInt32Array #check if in use

# ---- SPECIES SPECIFIC -------------------------------------------------------
#here might move in full ecs array one time
#general
var species_name := "Test"
var species_id := 0
var interactable := false                    # true: the player's Action key looks for this species
var photosynthesis_on := false
var photo_layer_y := 0
var max_health := 100.0

#rendering
var sprite := preload("res://Alife/Plant/Grass/grass.png")
var colour := Color(0.193, 0.404, 0.283, 1.0)
const CORPSE_COLOR := Color(0.488, 0.077, 0.15, 0.2)
var hframes := 1
var vframes := 1
#rendering: ground sprite (null = none, the round shadow instead)
var ground_sprite: Texture2D = null       # flat sprite on the ground under each agent
var ground_sprite_scale := 1.0            # its width, in world units (x the agent's size)
var ground_sprite_follows_size := true    # grows with the agent
var ground_params := {}                   # extra ground shader settings

#rendering: several standing sprites per agent (e.g. moss)
var render_copies := 1                    # 1 to 3
var copy_params := {}                     # extra settings for them
var sprite_scale := 1.0       # base size of the standing sprite (x the agent's size if it scales)
var shadow_from_photo_range := false
var shadow_params := {}
var native_shadow := false
var caster_params := {}
#LIFECYCLE
var growth_rate := 0.25
var duplication_range := 15
var seed_energy := 5.0
var seed_biomass := 5.0
var max_life_cycle := 3
var growth_cost : PackedFloat32Array


#METABO
var photo_range := 0
var photo_optimal_value = 1.0
var photo_optimal_width = 0.2
var max_energy := 100.0
var has_seed := false

#Movement & AI
var max_speed := 10.0

#Flock par
var view_radius := 15.0	 #need to be < that contact cell grid
var separation_radius := 12.0
var w_separation := 2.0 #alifemanager.separation
var w_alignment :=1.0 #alifemanager.allignment
var w_cohesion := 0.5# alifemanager.cohesion
var w_seek := 0.5# alifemanager.cohesion

var max_force := 10.0
var max_neighbors := 8
var target_density := 20.0     # agents per cell you're happy with


# ---- GRID THINGS - SCENT FIELDS -------------------------------------------------------
# Each species owns any number of fields on the field grid (alifemanager.field_cell_size).
# Every frame build_field() lets each agent in the world deposit into every field, then
# spreads (diffusion) and fades (decay) them. Each field has:
#   now       what was deposited this frame only
#   diffused  the lasting scent: deposits spread and fade over time
#
# Two fields always exist; older code reads them through the FIELD_* arrays below:
#   "density"  COUNT     1 per agent         -> FIELD_count / FIELD_c_diffused
#   "flow"     VELOCITY  the agent velocity  -> FIELD_velocity / FIELD_v_diffused
#
# Add your own in the species' _init, e.g. a slow-fading trail of living agents only:
#   add_field("trail", FieldSource.COUNT, 0.1, 0.99, true)
# or only the agents in a range of life cycle stages (min_stage, max_stage, -1 = no limit):
#   add_field("adult", FieldSource.COUNT, -1.0, -1.0, true, 2, 2)    # stage 2 only
#   add_field("tree", FieldSource.COUNT, -1.0, -1.0, true, 2)        # stage 2 and above
# By default only agents standing in the world (state 1) deposit. The last argument picks
# other states too, e.g. fruits on the ground or carried, not hanging in a tree:
#   add_field("fruit", FieldSource.COUNT, -1.0, -1.0, true, 0, 0, [1, AlifeManager.HELD])
# and read it, from this species or any other:
#   sp.field_diffused(sp.field_id("trail"))[c]    sp.field_gradient(trail_id, c)

enum FieldSource {
	COUNT,       # 1 per agent
	VELOCITY,    # the agent's velocity (vector field)
}
const FIELD_DENSITY := "density"
const FIELD_FLOW := "flow"

class ScentField:
	var name := ""
	var source := 0                              # FieldSource
	var is_vector := false                       # VELOCITY fields store Vector3
	var diffusion := -1.0                        # < 0: the species' field_diffusion
	var decay := -1.0                            # < 0: the species' field_decay
	var only_alive := false                      # true: corpses don't deposit
	var min_stage := -1                          # >= 0: only agents at this life stage or above
	var max_stage := -1                          # >= 0: only agents at this life stage or below
	var state_mask := 1 << 1                     # bit s set: agents in state s deposit (default: 1)
	var now_f := PackedFloat32Array()            # float fields
	var diffused_f := PackedFloat32Array()
	var now_v := PackedVector3Array()            # vector fields
	var diffused_v := PackedVector3Array()

var fields: Array[ScentField] = []
var _field_ids := {}                             # name -> index in fields
var _agent_field_cell := PackedInt32Array()      # scratch: field cell of each agent

####FLOW FIELD (the two default fields, kept for older code)
var FIELD_count: PackedFloat32Array
var FIELD_velocity: PackedVector3Array
var FIELD_c_diffused: PackedFloat32Array
var FIELD_v_diffused: PackedVector3Array
var SCENT: PackedVector3Array

#SHOULD MOVE TO ALIFEMANAGER
#var field_cell_size := Vector3(20,20,20)
var FIELD_W : int
var FIELD_H : int
var FIELD_D : int
var FIELD_NUM_CELLS : int



#for player control---------------
## Which Pilot controls each agent (its slot in PilotSystem.pilots), -1 = the AI.
## Several agents of the same species can be controlled at once (one per player).
var pilot_id := PackedInt32Array()
var pilot_system = null                # set by PilotSystem when a pilot is added
## true: this species reads its pilots itself in its tick (get_pilot / control_velocity).
## false (older species): PilotSystem drives player_index / player_velocity for one pilot.
var uses_pilots := false
## Actions this species can do when controlled (PlayerInput bits). The others do nothing,
## and their key hints aren't shown. e.g. PlayerInput.ALL & ~PlayerInput.THROW
var control_actions := PlayerInput.ALL

## Per species: how it moves when controlled (same keys, different feel).
var control_speed := 3.0               # world units / s
var sprint_multiplier := 2.0
var can_jump := true                   # false: jump does nothing (uses the JUMP group below)
var dash_multiplier := 4.0             # speed during the dash (x control_speed)
var dash_time := 0.15                  # seconds the dash lasts
var dash_cooldown := 0.8               # seconds between dashes (real time)
## Per species: its attack when controlled.
var attack_width := 1.5                # across, centered on the agent
var attack_length := 2.0               # forward, starting at the agent
var attack_height := 2.0               # up from the agent's feet
var attack_damage := 20.0              # if the species has no get_damage()
var attack_cooldown := 0.4             # seconds (real time)

# OLD single-player control: only for species with uses_pilots = false (set by PilotSystem)
var player_index := -1                 # local index of the controlled agent (-1 = none)
var player_velocity := Vector3.ZERO    # velocity chosen by the player




#not in use?
################# AI-between_species_input
var max_neighbors_count := 8
var neighbour_count : PackedInt32Array
var mouse_target : Vector3


var food_sp_id : PackedInt32Array = [0]
var danger_sp_id : PackedInt32Array
var friend_sp_id : PackedInt32Array

var danger_max_dist : float

var minEnergy : float = 5.0
#var maxEnergy : float = 20.0

#Randomness
const JITTER_COUNT := 4096
var _jitter: PackedVector3Array
var _jhead: int = 0



#############################################################################################
##############################################################################################
#############################################################################################
##############################################################################################


var player_vy := 0.0               # vertical speed of the controlled agent
var player_jump_buffer := 0.0      # > 0: jump pressed recently (set by the picker)
var player_jump_held := false      # jump key still held (variable height)
var player_air_time := 0.0         # time since leaving the ground (coyote time)

@export_group("JUMP")
@export var jump_height := 8.0
@export var time_to_jump_apex := .3
@export var fall_multiplier := 2.0        # falls faster than it rises
@export var low_jump_multiplier := 2.5    # key released early: shorter jump
@export var coyote_time := 0.12
@export var max_fall_speed := 30.0
@export var ground_y := 0.0


# ---- PILOTS (player control) ----------------------------------------------------------

## The Pilot controlling agent i, or null (AI). Safe in the chunk tick (read only).
func get_pilot(i: int) -> Pilot:
	var pid := pilot_id[i] if i < pilot_id.size() else -1
	if pid < 0 or pilot_system == null:
		return null
	return pilot_system.pilots[pid]


## Velocity of agent i controlled by pilot pl, for this step (called in the chunk tick).
## Default: walks at control_speed (sprint, dash), jumps with the JUMP settings on the
## floor floor_h. Override it in a species for another way of moving (fly, hop, swim...).
## vertical = false: horizontal only (y = 0).
func control_velocity(pl: Pilot, i: int, p: Vector3, floor_h: float, delta: float,
		vertical := true) -> Vector3:
	var dir := Vector3(pl.input.move.x, 0.0, pl.input.move.y).limit_length(1.0)
	var v: Vector3
	if pl.dash_left > 0.0:
		var d := dir if dir.length_squared() > 1e-6 else pl.facing
		v = Vector3(d.x, 0.0, d.z).normalized() * control_speed * dash_multiplier
	else:
		var sprint := sprint_multiplier if pl.input.is_held(PlayerInput.SPRINT) \
				and control_actions & PlayerInput.SPRINT != 0 else 1.0
		v = dir * control_speed * sprint
	if vertical:
		v.y = pilot_vertical(pl, p.y, delta, floor_h)
	return v


## Jump + gravity of a controlled agent on the floor floor_h (lands on / falls off ledges).
## The state is in the pilot, so several players never share it.
func pilot_vertical(pl: Pilot, y: float, dt: float, floor_h: float) -> float:
	var g := 2.0 * jump_height / (time_to_jump_apex * time_to_jump_apex)
	var grounded := y <= floor_h + 0.001 and pl.vy <= 0.0
	if grounded:
		pl.vy = 0.0
		pl.air_time = 0.0
	else:
		pl.air_time += dt

	# Jump: pressed recently (buffer) + on the floor or just left it (coyote)
	if can_jump and pl.jump_buffer > 0.0 and pl.air_time <= coyote_time:
		pl.vy = 2.0 * jump_height / time_to_jump_apex
		pl.jump_buffer = 0.0
		pl.air_time = coyote_time + 1.0     # no second jump in the air
		grounded = false

	# Gravity: stronger when falling, or when the key was released early
	if not grounded:
		var m := 1.0
		if pl.vy < 0.0:
			m = fall_multiplier
		elif not pl.input.is_held(PlayerInput.JUMP):
			m = low_jump_multiplier
		pl.vy = maxf(pl.vy - g * m * dt, -max_fall_speed)
	return pl.vy


## A controlled agent pressed `action` (a PlayerInput bit). Return true when the species
## did its own thing (e.g. a spider's charge on ATTACK); false = the default action runs.
## Main thread, before the tick: safe to change any array.
func on_control_action(pl: Pilot, action: int) -> bool:
	return false


## OLD: vertical physics of the controlled agent (species with uses_pilots = false).
func _player_vertical(y: float, dt: float) -> float:
	var g := 2.0 * jump_height / (time_to_jump_apex * time_to_jump_apex) #gravity 
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

	# Gravity: stronger when falling, or when the key was released early
	if not grounded:
		var m := 1.0
		if player_vy < 0.0:
			m = fall_multiplier
		elif not player_jump_held:
			m = low_jump_multiplier
		player_vy = maxf(player_vy - g * m * dt, -max_fall_speed)
	return player_vy

## Only seeds / fruits can be picked up, not grown trees.
func can_be_carried(i: int) -> bool:
	return true #current_life_state[i] == 0

#Init part--------------------------------------------------------------------

func init(worldd:WorldManager,alifm:AlifeManager):
	_jitter.resize(JITTER_COUNT)
	for k in JITTER_COUNT:
		_jitter[k] = Vector3(randf_range(-1.0,1.0),0,randf_range(-1.0,1.0))
	#cross ref
	world = worldd
	alifemanager = alifm
	_init_alife_par()
	_init_array_management()
	build_offsets()
	_init_field_grid()
	setup_render_packing() #HERE IF WORLD RESIZE IN Y DOESNT WORK



func _init_array_management():		
	entity_count = 0
	active_entity_count =0
	free_indices = [] 
	
	pending_multimesh_drawn_id = []
	pending_multimesh_update_id = []
	pending_multimesh_erase_id = []
	
	pending_spawn_id = []
	pending_update_id = []
	pending_remove_id = []
	
func _init_alife_par():
	#alife 
	position_array = [] 
	current_energy_array = [] 
	current_velocity = []
	new_velocity = []
	facing = []
	current_health = []
	current_max_health = []
	active_alife_array = []   #To reuse some 
	alive_array = []
	current_sungrid_id = []
	current_grid_id = []
	
	current_color = []	
	current_life_state= []
	current_biomass= []
	current_age= []
	current_size= []
	current_action=[]
	
	holding = []
	held_by = []
	pilot_id = []
	
	current_cpu_cost = []
	
	#for render only
	color_packed=[]


func _init_field_grid():
	var dims := Vector3i((world.size / alifemanager.field_cell_size).ceil())
	FIELD_W = dims.x         # cells along x
	FIELD_H = dims.y       # cells along y
	FIELD_D = dims.z         # cells along z
	FIELD_NUM_CELLS = FIELD_W * FIELD_H * FIELD_D

	add_field(FIELD_DENSITY, FieldSource.COUNT)      # does nothing if it already exists
	add_field(FIELD_FLOW, FieldSource.VELOCITY)
	for f in fields:
		_size_field(f)
	_sync_legacy_fields()

	SCENT.clear()
	SCENT.resize(FIELD_NUM_CELLS)
	SCENT.fill(Vector3.ZERO)	
	
	build_field_neighbors()

func set_chunk(n:int):
	spawn_per_chunk.resize(n)
	remove_per_chunk.resize(n)
	for i in n:
		spawn_per_chunk[i] = []   # clear the previous frame's results
		remove_per_chunk[i] = []

	

#############################################################################################
##############################################################################################
# MAIN LOOOP
#############################################################################################
##############################################################################################


func run_chunk_simulation( start: int, end: int,local_id:int, delta: float,dt:float, sim_speed:float) -> void:
	2#var dt := delta                              # fixed simulated time per tick
	var local_pending_spawn_id : PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	#var mouse_target :Vector3 = alifemanager.mouse_position # Vector3(get_viewport().get_mouse_position().x,0,get_viewport().get_mouse_position().y)

	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	#MINIMAL ALIFE SCRIPT
	for i in range(start, end):
		if active_alife_array[i] == 0:
			continue
		if alive_array[i] == 0:
			continue
		var _energy:= current_energy_array[i]
		
		#EAT
		if _energy < 5:		
			_energy += (1) * dt	
		
		#maintain cost
		_energy += -0.6  * dt # - (side * side - side) *dt #* active_alife_array[i]
		
		#DEATH
		if _energy < 0 :
			alive_array[i] = 0
			
		#Duplicate
		if _energy >= 5:
			local_pending_spawn_id.append(i)
			_energy -= 5
		#update energy
		current_energy_array[i] = _energy	
		
		#CHECK to free entity
		if alive_array[i] == 0 and active_alife_array[i] == 1:
			local_pending_remove_id.append(i)
	
	
		#HERE velocity and position are updated in paralell so can make issue #TODO
		'Move_random(i,wrap_x,wrap_y,wrap_z,world_size)
		var q :Vector3 = position_array[i] + new_velocity[i] * dt
		var v := new_velocity[i]
		# borders (world is 0..size)
		if wrap_x: q.x = fposmod(q.x, world_size.x)
		elif q.x < 0.0 or q.x > world_size.x: q.x = clampf(q.x, 0.0, world_size.x); v.x = -v.x
		if wrap_y: q.y = fposmod(q.y, world_size.y)
		elif q.y < 0.0 or q.y > world_size.y: q.y = clampf(q.y, 0.0, world_size.y); v.y = -v.y
		if wrap_z: q.z = fposmod(q.z, world_size.z)
		elif q.z < 0.0 or q.z > world_size.z: q.z = clampf(q.z, 0.0, world_size.z); v.z = -v.z
		position_array[i] = q
		current_velocity[i] = v'
	


	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id

	
#############################################################################################
# FIELD SCENT GRID MANAGEMENT
#############################################################################################

@export_range(0.0, 1.0) var field_diffusion := 0.3
@export_range(0.8, 1.0, 0.001) var field_decay := 0.95

var _nbr := PackedInt32Array()      # 6 neighbors per field cell, -1 = wall

## Call once at start, and again when the field size or border types change.
func build_field_neighbors() -> void:
	var W := FIELD_W; var H := FIELD_H; var D := FIELD_D
	var wx: bool = world.border_type_x == world.Border.WRAP
	var wy: bool = world.border_type_y == world.Border.WRAP
	var wz: bool = world.border_type_z == world.Border.WRAP
	_nbr.resize(W * H * D * 6)
	for z in D:
		for y in H:
			for x in W:
				var c := x + W * (y + H * z)
				var b := c * 6
				_nbr[b]     = _nb(x + 1, y, z, c, W, H, D, wx, wy, wz)
				_nbr[b + 1] = _nb(x - 1, y, z, c, W, H, D, wx, wy, wz)
				_nbr[b + 2] = _nb(x, y + 1, z, c, W, H, D, wx, wy, wz)
				_nbr[b + 3] = _nb(x, y - 1, z, c, W, H, D, wx, wy, wz)
				_nbr[b + 4] = _nb(x, y, z + 1, c, W, H, D, wx, wy, wz)
				_nbr[b + 5] = _nb(x, y, z - 1, c, W, H, D, wx, wy, wz)


func _nb(x: int, y: int, z: int, self_c: int, W: int, H: int, D: int,
		wx: bool, wy: bool, wz: bool) -> int:
	if x < 0 or x >= W:
		if not wx: return -1
		x = posmod(x, W)
	if y < 0 or y >= H:
		if not wy: return -1
		y = posmod(y, H)
	if z < 0 or z >= D:
		if not wz: return -1
		z = posmod(z, D)
	var o := x + W * (y + H * z)
	return -1 if o == self_c else o      # wrapping onto itself (axis of size 1) = no neighbor


# =====================================================================================
# PASTE INTO THE BASE ALIFE SCRIPT: replaces build_field(), adds 3 settings.
# =====================================================================================

## false: this species has no scent at all (items, tools...): build_field does nothing.
var uses_fields := true
## false: this species never moves (plants): its VELOCITY fields ("flow") stay at zero,
## so they are neither filled nor diffused.
var moves := true
## Build / spread the fields only every Nth tick (scent changes slowly).
## Species are staggered (species_id) so they don't all work on the same tick.
## Deposits and fade are scaled by N, so the scent keeps about the same strength.
var field_every := 1

var _field_tick := 0
var _fields_quiet := false          # no agents and fields already cleared: nothing to do


func build_field() -> void:
	if not uses_fields:
		return

	# Nobody left: clear the fields once, then skip until agents come back
	if active_entity_count == 0:
		if not _fields_quiet:
			for f in fields:
				_size_field(f)                   # back to zero
			_sync_legacy_fields()
			_fields_quiet = true
		return
	_fields_quiet = false

	# Only every Nth tick, staggered between species
	_field_tick += 1
	var every := maxi(field_every, 1)
	if every > 1 and (_field_tick + species_id) % every != 0:
		return
	var weight := float(every)                   # N ticks of deposits in one go

	var field_cell_size := alifemanager.field_cell_size
	var W := FIELD_W; var H := FIELD_H; var D := FIELD_D
	var n := entity_count
	var N := FIELD_NUM_CELLS
	var inv := Vector3.ONE / field_cell_size

	# 1. Field cell of every agent not in the pool, once for all fields (-1 = no deposit)
	_agent_field_cell.resize(n)
	for i in n:
		if active_alife_array[i] == 0:
			_agent_field_cell[i] = -1
			continue
		var p := position_array[i]
		_agent_field_cell[i] = clampi(int(p.x * inv.x), 0, W - 1) \
			+ W * (clampi(int(p.y * inv.y), 0, H - 1) \
			+ H * clampi(int(p.z * inv.z), 0, D - 1))

	# 2. Deposit, then diffuse, field by field
	for f in fields:
		if f.is_vector and not moves:
			continue                             # plants: flow stays zero, nothing to spread
		var rate := f.diffusion if f.diffusion >= 0.0 else field_diffusion
		var fade := f.decay if f.decay >= 0.0 else field_decay
		if every > 1:
			fade = pow(fade, every)              # N ticks of fading in one go
		var check_stage := f.min_stage >= 0 or f.max_stage >= 0
		var mask := f.state_mask

		if f.is_vector:
			var now := f.now_v
			now.fill(Vector3.ZERO)
			var dif := f.diffused_v
			for i in n:
				var c := _agent_field_cell[i]
				if c < 0 or (mask >> active_alife_array[i]) & 1 == 0:
					continue
				if f.only_alive and alive_array[i] == 0:
					continue
				if check_stage and not _in_stages(f, current_life_state[i]):
					continue
				var v := current_velocity[i] * weight
				now[c] += v
				dif[c] += v
			f.now_v = now
			f.diffused_v = _diffuse_v(dif, rate, fade)
		else:
			var now := f.now_f
			now.fill(0.0)
			var dif := f.diffused_f
			for i in n:
				var c := _agent_field_cell[i]
				if c < 0 or (mask >> active_alife_array[i]) & 1 == 0:
					continue
				if f.only_alive and alive_array[i] == 0:
					continue
				if check_stage and not _in_stages(f, current_life_state[i]):
					continue
				now[c] += weight
				dif[c] += weight
			f.now_f = now
			f.diffused_f = _diffuse_f(dif, rate, fade)

	_sync_legacy_fields()

'func build_field() -> void:
	var field_cell_size := alifemanager.field_cell_size
	var W := FIELD_W; var H := FIELD_H; var D := FIELD_D
	var n := entity_count
	var N := FIELD_NUM_CELLS

	# 1. Field cell of every agent not in the pool, once for all fields (-1 = no deposit)
	_agent_field_cell.resize(n)
	for i in n:
		if active_alife_array[i] == 0:
			_agent_field_cell[i] = -1
			continue
		var p := position_array[i]
		_agent_field_cell[i] = clampi(int(p.x / field_cell_size.x), 0, W - 1) \
			+ W * (clampi(int(p.y / field_cell_size.y), 0, H - 1) \
			+ H * clampi(int(p.z / field_cell_size.z), 0, D - 1))

	# 2. Deposit, then diffuse, field by field
	for f in fields:
		var rate := f.diffusion if f.diffusion >= 0.0 else field_diffusion
		var fade := f.decay if f.decay >= 0.0 else field_decay

		if f.is_vector:
			var now := PackedVector3Array()
			now.resize(N)
			now.fill(Vector3.ZERO)
			var dif := f.diffused_v
			for i in n:
				var c := _agent_field_cell[i]
				if c < 0 or (f.only_alive and alive_array[i] == 0):
					continue
				if not _in_stages(f, current_life_state[i]):
					continue
				if (f.state_mask >> active_alife_array[i]) & 1 == 0:
					continue
				var v := current_velocity[i]
				now[c] += v
				dif[c] += v
			f.now_v = now
			f.diffused_v = _diffuse_v(dif, rate, fade)
		else:
			var now := PackedFloat32Array()
			now.resize(N)
			now.fill(0.0)
			var dif := f.diffused_f
			for i in n:
				var c := _agent_field_cell[i]
				if c < 0 or (f.only_alive and alive_array[i] == 0):
					continue
				if not _in_stages(f, current_life_state[i]):
					continue
				if (f.state_mask >> active_alife_array[i]) & 1 == 0:
					continue
				now[c] += 1.0
				dif[c] += 1.0
			f.now_f = now
			f.diffused_f = _diffuse_f(dif, rate, fade)

	_sync_legacy_fields()'


## rate / fade < 0: the species' field_diffusion / field_decay
func _diffuse_f(a: PackedFloat32Array, rate := -1.0, fade := -1.0) -> PackedFloat32Array:
	var df := field_diffusion if rate < 0.0 else rate
	var dc := field_decay if fade < 0.0 else fade
	var out := PackedFloat32Array()
	out.resize(a.size())
	for c in a.size():
		var s := a[c]
		var b := c * 6
		var sum := 0.0
		var k := 0
		for j in 6:
			var o := _nbr[b + j]
			if o >= 0:
				sum += a[o]
				k += 1
		out[c] = ((s + (sum / k - s) * df) if k > 0 else s) * dc
	return out


func _diffuse_v(a: PackedVector3Array, rate := -1.0, fade := -1.0) -> PackedVector3Array:
	var df := field_diffusion if rate < 0.0 else rate
	var dc := field_decay if fade < 0.0 else fade
	var out := PackedVector3Array()
	out.resize(a.size())
	for c in a.size():
		var s := a[c]
		var b := c * 6
		var sum := Vector3.ZERO
		var k := 0
		for j in 6:
			var o := _nbr[b + j]
			if o >= 0:
				sum += a[o]
				k += 1
		out[c] = ((s + (sum / k - s) * df) if k > 0 else s) * dc
	return out


## Scent gradient at one cell. Call it per agent, only when needed.
func scent_gradient(a:PackedFloat32Array, c: int) -> Vector3:
	var s := a[c]
	var b := c * 6
	var o: int
	o = _nbr[b];     var xp := a[o] if o >= 0 else s
	o = _nbr[b + 1]; var xm := a[o] if o >= 0 else s
	o = _nbr[b + 2]; var yp := a[o] if o >= 0 else s
	o = _nbr[b + 3]; var ym := a[o] if o >= 0 else s
	o = _nbr[b + 4]; var zp := a[o] if o >= 0 else s
	o = _nbr[b + 5]; var zm := a[o] if o >= 0 else s
	return Vector3(xp - xm, yp - ym, zp - zm)


#---- Fields API ------------------------------------------------------------------------

## Adds a field (call it in the species' _init). Returns its id; an existing name
## returns the existing id. diffusion / decay < 0: the species' field_diffusion / field_decay.
## only_alive: corpses don't deposit.
## min_stage / max_stage: only agents in this range of life cycle stages (-1 = no limit).
## states: agent states that deposit (active_alife_array values). Default: in the world.
func add_field(fname: String, source: int, diffusion := -1.0, decay := -1.0,
		only_alive := false, min_stage := -1, max_stage := -1, states: Array = [1]) -> int:
	if _field_ids.has(fname):
		return _field_ids[fname]
	var f := ScentField.new()
	f.name = fname
	f.source = source
	f.is_vector = source == FieldSource.VELOCITY
	f.diffusion = diffusion
	f.decay = decay
	f.only_alive = only_alive
	f.min_stage = min_stage
	f.max_stage = max_stage
	f.state_mask = 0
	for st in states:
		f.state_mask |= 1 << int(st)
	fields.append(f)
	_field_ids[fname] = fields.size() - 1
	if FIELD_NUM_CELLS > 0:
		_size_field(f)                           # added after the grid exists
	return fields.size() - 1


## Id of a field by name, -1 if this species doesn't have it.
func field_id(fname: String) -> int:
	return _field_ids.get(fname, -1)


## Lasting scent of a field (spread + faded). Read-only.
func field_diffused(fid: int) -> PackedFloat32Array:
	return fields[fid].diffused_f


## What was deposited this frame only. Read-only.
func field_now(fid: int) -> PackedFloat32Array:
	return fields[fid].now_f


## Vector fields (VELOCITY): lasting / this frame.
func field_diffused_v(fid: int) -> PackedVector3Array:
	return fields[fid].diffused_v

func field_now_v(fid: int) -> PackedVector3Array:
	return fields[fid].now_v


## Direction toward more of this field's scent, at field cell c.
func field_gradient(fid: int, c: int) -> Vector3:
	return scent_gradient(fields[fid].diffused_f, c)


## True when a life cycle stage is inside the field's stage range.
func _in_stages(f: ScentField, stage: int) -> bool:
	if f.min_stage >= 0 and stage < f.min_stage:
		return false
	if f.max_stage >= 0 and stage > f.max_stage:
		return false
	return true


## Field cell of a position.
func field_cell(p: Vector3) -> int:
	var fcs := alifemanager.field_cell_size
	return clampi(int(p.x / fcs.x), 0, FIELD_W - 1) \
		+ FIELD_W * (clampi(int(p.y / fcs.y), 0, FIELD_H - 1) \
		+ FIELD_H * clampi(int(p.z / fcs.z), 0, FIELD_D - 1))


func _size_field(f: ScentField) -> void:
	var N := FIELD_NUM_CELLS
	if f.is_vector:
		f.now_v.resize(N)
		f.now_v.fill(Vector3.ZERO)
		f.diffused_v.resize(N)
		f.diffused_v.fill(Vector3.ZERO)
	else:
		f.now_f.resize(N)
		f.now_f.fill(0.0)
		f.diffused_f.resize(N)
		f.diffused_f.fill(0.0)


## The two default fields, under the names older code uses.
func _sync_legacy_fields() -> void:
	var d: ScentField = fields[_field_ids[FIELD_DENSITY]]
	FIELD_count = d.now_f
	FIELD_c_diffused = d.diffused_f
	var fl: ScentField = fields[_field_ids[FIELD_FLOW]]
	FIELD_velocity = fl.now_v
	FIELD_v_diffused = fl.diffused_v
	
##########################################################################################
#### callable interspecies
##########################################################################################

func Interact(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])

## Agent i was damaged by agent local_id of species sp.
func on_damaged(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])

func getPickUp(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])

func getDropped(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])

func Interact2(i:int, sp:ALIFE, local_id:int):
	print("%s ID: %d interacted with %s ID: %d" %[sp.species_name, local_id, species_name, i])

# --- Carry ---------------------------------------------------------------------

	
##########################################################################################
#### Main loop function
##########################################################################################


func Eat(start:int,end:int):
	pass
	for i in range(start,end):
		pass

func GoTo(start:int,end:int):

	if alifemanager.global_position_array.size()<1:
		return
	var H := FIELD_H
	var W := FIELD_W
	var D := FIELD_D
	var field_cell_size := alifemanager.field_cell_size
	
	var target_dist := 1.0
	var offs: PackedInt32Array = alifemanager.global_species_offset
	var base  := offs[alifemanager.species_array.size()-1]
	var target_id := 0
	var t_sp := alifemanager.species_array[target_id]
	var t_diff := t_sp.FIELD_c_diffused
	var t_count := t_sp.FIELD_count
	for i in range(start,end):
		var steer := Vector3.ZERO
		var p := position_array[i]
		var cx := mini(int(p.x / field_cell_size.x), W - 1)
		var cy := mini(int(p.y / field_cell_size.y), H - 1)
		var cz := mini(int(p.z / field_cell_size.z), D - 1)
		var c := cx + W * (cy + H * cz)	
		var tc := t_count[c]
		if tc < 1 :
			var g:= scent_gradient(t_diff, c)
			if g.length_squared() > 1e-6:
				steer = (g.normalized() * 5 ) 
		else:
			var me := i + base
			# closest agent of any species, in the 3x3x3 block
			#var id := find_nearest(p, me)
			# closest prey (species 0), searching up to 4/1 cells away
			var found := find_nearest(p, me, 0, 4)
			var prey := int(found.w)
			if prey >= 0:
				var delta := Vector3(found.x, found.y, found.z)
				var dist := delta.length()       # direction to it (wrap-aware)
				var dir :Vector3 = delta / dist if dist > 0.0 else Vector3.ZERO
				if dist < target_dist:
					# eat / attack prey
					var sp := offs.bsearch(prey, false) - 1
					var local := prey - offs[sp]
					var sp_o : = alifemanager.species_array[sp]
					#var e:=  sp_o.current_energy_array[local] 
					#sp_o.current_energy_array[local] = 0
					sp_o.alive_array[local] = 0
					current_energy_array[i] +=  sp_o.current_biomass[local]
				else:
					steer += dir * 1 # (dir * cruise_speed - v) * w_hunt
						
			
		new_velocity[i]=steer


func Move_random(i,wrap_x,wrap_y,wrap_z,size):
		var p: Vector3 = position_array[i] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		p.x = fposmod(p.x, size.x) if wrap_x else clampf(p.x, 0.0, size.x)
		p.y = fposmod(p.y, size.y) if wrap_y else clampf(p.y, 0.0, size.y)
		p.z = fposmod(p.z, size.z) if wrap_z else clampf(p.z, 0.0, size.z)
		position_array[i] = p		

func count_neighbour(start:int, end:int):
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
	var global_sorted_pos: PackedVector3Array = alifemanager.sorted_pos
	var cell_start: PackedInt32Array = alifemanager.cell_start
	var cell_items: PackedInt32Array = alifemanager.cell_items
	var species_array:= alifemanager.species_array  # precomputed once per frame
	var base := offs[species_id] #to find own global id
	view_radius = alifemanager.neighbour_view_range	
	max_neighbors_count = alifemanager.neighbour_max_count
	var view_r2 := view_radius * view_radius

	var my_end := offs[species_id + 1]
	


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
			if n >= max_neighbors_count: break
			var z := cz + dz
			var sz := 0.0
			if z < 0:
				if not wrap_z: continue
				z += D; sz = -world_size.z
			elif z >= D:
				if not wrap_z: continue
				z -= D; sz = world_size.z

			for dy in range(-1, -1 + ny):
				if n >= max_neighbors_count: break
				var y := cy + dy
				var sy := 0.0
				if y < 0:
					if not wrap_y: continue
					y += H; sy = -world_size.y
				elif y >= H:
					if not wrap_y: continue
					y -= H; sy = world_size.y

				for dx in range(-1, -1 + nx):
					if n >= max_neighbors_count: break
					var x := cx + dx
					var sx := 0.0
					if x < 0:
						if not wrap_x: continue
						x += W; sx = -world_size.x
					elif x >= W:
						if not wrap_x: continue
						x -= W; sx = world_size.x

					var cell := x + W * (y + H * z)
					var shift_p := Vector3(sx, sy, sz) - p   # one shift per cell
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var other: int = cell_items[k]
						if  other == global_i: #other < base or other >= my_end or
							continue
						var d: Vector3 = global_sorted_pos[k] + shift_p
						var dist2 := d.length_squared()
						if dist2 > view_r2:# or dist2 == 0.0:
							continue
						n += 1
						if n >= max_neighbors_count:
							break
		neighbour_count[i] = n
		
func Flock(start,end,dt):
	#world
	var field_cell_size := alifemanager.field_cell_size

	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP	
	var cell_size := alifemanager.cell_size		
	var W := alifemanager.GRID_W
	var H := alifemanager.GRID_H
	var D := alifemanager.GRID_D
	
	var fieldW := FIELD_W
	var fieldH := FIELD_H
	var fieldD := FIELD_D
	
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
	


	var view_r2 := view_radius * view_radius
	var sep_r2 := separation_radius * separation_radius
	var my_end := offs[species_id + 1]
	var n := 0
	var TYPE = alifemanager.flock_type

	if TYPE == 0: #neighbour

		for i in range(start, end):
			n= 0 #number of compatible neighbour
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
				if n >= max_neighbors: break
				var z := cz + dz
				var sz := 0.0
				if z < 0:
					if not wrap_z: continue
					z += D; sz = -world_size.z
				elif z >= D:
					if not wrap_z: continue
					z -= D; sz = world_size.z

				for dy in range(-1, -1 + ny):
					if n >= max_neighbors: break
					var y := cy + dy
					var sy := 0.0
					if y < 0:
						if not wrap_y: continue
						y += H; sy = -world_size.y
					elif y >= H:
						if not wrap_y: continue
						y -= H; sy = world_size.y

					for dx in range(-1, -1 + nx):
						if n >= max_neighbors: break
						var x := cx + dx
						var sx := 0.0
						if x < 0:
							if not wrap_x: continue
							x += W; sx = -world_size.x
						elif x >= W:
							if not wrap_x: continue
							x -= W; sx = world_size.x

						var cell := x + W * (y + H * z)
						var shift_p := Vector3(sx, sy, sz) - p   # one shift per cell
						for k in range(cell_start[cell], cell_start[cell + 1]):
							var other: int = cell_items[k]
							if other < base or other >= my_end or other == global_i: #WORK ONLY IF SELF SPECIES
								continue
							var d: Vector3 = global_sorted_pos[k] + shift_p
							var dist2 := d.length_squared()
							if dist2 > view_r2 or dist2 == 0.0:
								continue
							n += 1
							sum_d += d
							sum_v += current_velocity[other - base]  #WORK ONLY IF SELF SPECIES
							if dist2 < sep_r2:
								sep -= d / dist2
							if n >= max_neighbors:
								break
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
			
	elif TYPE == 1: #flow cell
		var cruise_speed := 5.0
		var w_speed := 1.0
		for i in range(start, end):
			var p := position_array[i]
			var v := current_velocity[i]
			var c := clampi(int(p.x / field_cell_size.x), 0, fieldW - 1) \
				+ fieldW * (clampi(int(p.y / field_cell_size.y), 0, fieldH - 1) \
				+ fieldH * clampi(int(p.z / field_cell_size.z), 0, fieldD - 1))

			var others := FIELD_count[c] - 1.0          # remove myself

			# --- 1. ALIGNMENT: direction only, never brakes -----------------
			var steer_align := Vector3.ZERO
			var flow := Vector3.ZERO
			if others > 0.0:
				flow = FIELD_velocity[c] - v              # others in my cell
			else:
				flow = FIELD_v_diffused[c]                # alone: recent flow nearby
			if flow.length_squared() > 1e-6:
				steer_align = flow.normalized() * cruise_speed - v

			# --- 2. SEPARATION: current crowding, not the scent -------------
			var crowd := clampf((others - target_density) / target_density, 0.0, 1.0)
			var steer_sep := Vector3.ZERO
			if crowd > 0.0:
				var g := scent_gradient(FIELD_count, c)
				if g.length_squared() > 1e-6:
					steer_sep = (-g.normalized() * cruise_speed - v) * crowd

			# --- 3. COHESION: scent toward the group, fades when crowded ----
			var steer_coh := Vector3.ZERO
			var sg := scent_gradient(FIELD_c_diffused, c)
			if sg.length_squared() > 1e-6:
				steer_coh = (sg.normalized() * cruise_speed - v) * (1.0 - crowd)

			# --- 4. CRUISE: keep moving ---------------------------------------
			var steer_speed := Vector3.ZERO
			if v.length_squared() > 1e-6:
				steer_speed = (v.normalized() * cruise_speed - v) * w_speed

			# --- combine --------------------------------------------------
			var steer := steer_align * w_alignment + steer_sep * w_separation \
				+ steer_coh * w_cohesion + steer_speed
			steer = steer.limit_length(max_force)

			var nv : Vector3 = v + steer * dt
			var s := nv.length()
			if s < 1e-6:
				new_velocity[i] = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * cruise_speed
			else:
				new_velocity[i] = nv / s * clampf(s, 1.0, 10.0)
	elif TYPE == 2: #hybrid: contact grid for separation + alignment, field for cohesion
		# --- hybrid tuning (move to @export later) --------------------------
		var contact_radius := 6.0          # alignment range, must be <= cell_size
		var sep_radius := 3.0              # personal space, < contact_radius
		var cruise_speed := 5.0
		var w_speed := 1.0
		var contact_r2 := contact_radius * contact_radius
		var sep_r2_h := sep_radius * sep_radius

		for i in range(start, end):
			var p: Vector3 = position_array[i]
			var v: Vector3 = current_velocity[i]
			var global_i := i + base

			# ===== SHORT RANGE: contact grid ===============================
			#var n := 0
			n = 0
			var sum_v := Vector3.ZERO
			var sep := Vector3.ZERO
			var min_d2 := sep_r2_h                # closest neighbor inside personal space

			var cx := clampi(int(p.x / cell_size.x), 0, W - 1)
			var cy := clampi(int(p.y / cell_size.y), 0, H - 1)
			var cz := clampi(int(p.z / cell_size.z), 0, D - 1)

			for dz in range(-1, -1 + nz):
				if n >= max_neighbors: break
				var z := cz + dz
				var sz := 0.0
				if z < 0:
					if not wrap_z: continue
					z += D; sz = -world_size.z
				elif z >= D:
					if not wrap_z: continue
					z -= D; sz = world_size.z

				for dy in range(-1, -1 + ny):
					if n >= max_neighbors: break
					var y := cy + dy
					var sy := 0.0
					if y < 0:
						if not wrap_y: continue
						y += H; sy = -world_size.y
					elif y >= H:
						if not wrap_y: continue
						y -= H; sy = world_size.y

					for dx in range(-1, -1 + nx):
						if n >= max_neighbors: break
						var x := cx + dx
						var sx := 0.0
						if x < 0:
							if not wrap_x: continue
							x += W; sx = -world_size.x
						elif x >= W:
							if not wrap_x: continue
							x -= W; sx = world_size.x

						var cell := x + W * (y + H * z)
						var shift_p := Vector3(sx, sy, sz) - p
						for k in range(cell_start[cell], cell_start[cell + 1]):
							var other: int = cell_items[k]
							if other < base or other >= my_end or other == global_i:
								continue                      # same species only
							var d: Vector3 = global_sorted_pos[k] + shift_p
							var dist2 := d.length_squared()
							if dist2 > contact_r2 or dist2 == 0.0:
								continue
							n += 1
							sum_v += current_velocity[other - base]
							if dist2 < sep_r2_h:
								sep -= d / dist2              # stronger when closer
								min_d2 = minf(min_d2, dist2)
							if n >= max_neighbors:
								break

			# ===== LONG RANGE: field cell ===================================
			var fc := clampi(int(p.x / field_cell_size.x), 0, fieldW - 1) \
				+ fieldW * (clampi(int(p.y / field_cell_size.y), 0, fieldH - 1) \
				+ fieldH * clampi(int(p.z / field_cell_size.z), 0, fieldD - 1))

			var crowd := clampf(float(n) / max_neighbors, 0.0, 1.0)   # 0 = alone, 1 = in a group

			# --- 1. SEPARATION: exact neighbors, scaled by how close the nearest is
			var steer_sep := Vector3.ZERO
			if sep.length_squared() > 1e-8:
				var closeness := 1.0 - sqrt(min_d2) / sep_radius        # 0 at edge, 1 touching
				steer_sep = (sep.normalized() * cruise_speed - v) * closeness

			# --- 2. ALIGNMENT: real neighbors, or the field's flow when alone
			var steer_align := Vector3.ZERO
			var flow := sum_v if n > 0 else FIELD_v_diffused[fc]
			if flow.length_squared() > 1e-6:
				var align_scale := 1.0 if n > 0 else 0.5              # weaker when guessing from the field
				steer_align = (flow.normalized() * cruise_speed - v) * align_scale

			# --- 3. COHESION: scent toward the group, fades once in a group
			var steer_coh := Vector3.ZERO
			if crowd < 1.0:
				var sg := scent_gradient(FIELD_c_diffused, fc)
				if sg.length_squared() > 1e-6:
					steer_coh = (sg.normalized() * cruise_speed - v) * (1.0 - crowd)

			# --- 4. CRUISE: keep moving -------------------------------------
			var steer_speed := Vector3.ZERO
			if v.length_squared() > 1e-6:
				steer_speed = (v.normalized() * cruise_speed - v) * w_speed

			# --- combine ----------------------------------------------------
			var steer := steer_sep * w_separation + steer_align * w_alignment \
				+ steer_coh * w_cohesion + steer_speed
			steer = steer.limit_length(max_force)

			var nv :Vector3= v + steer * dt
			var s := nv.length()
			if s < 1e-6:
				new_velocity[i] = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * cruise_speed
			else:
				new_velocity[i] = nv / s * clampf(s, 1.0, 10.0)	


func Photosynthesis(start:int,end:int,dt:float):
		var global_photo_rate := world.SUN_stamp
		var sun_grid := world.SUN_GRID 
		var W := world.SUN_GRID_W
		var H := world.SUN_GRID_H
		var photo_rate = 1.0 #alifemanager.photo_absorption_rate
		var value :=  0.0
		for i in range(start, end):
			#var t := Time.get_ticks_usec()
			if active_alife_array[i] == 0:
				continue
			if alive_array[i] == 0:
				continue		
			var _energy:= current_energy_array[i]
			if _energy < 10:
				var sun_c := current_sungrid_id[i]
				var sun_c_up := sun_c + W #WORK ONLY IF THERE IS A LAYER ABOVE
				#var total := global_photo_rate[sun_c]
				var r:= photo_range
				var total := 0.0
				var ry := 0
				var d:= global_photo_rate[sun_c]
				var d_up := global_photo_rate[sun_c_up] +1
			
					#value = d  #or stamp value
				value =  sun_grid[sun_c_up]  /   maxf(d_up, photo_rate) 
				var value2 =photo_rate* exp(-((value - photo_optimal_value) ** 2) / (2 * photo_optimal_width ** 2))
				#print("%f value and take %f , for %f optimal" %[value,value2, photo_optimal_value] )
				current_energy_array[i] += value2 /maxf(d, photo_rate) * dt

					#( sun_grid[sun_c] * photo_rate *  dt) /   maxf(d, photo_rate) 




			
##########################################################################################
####GRID/SUN MANAGEMENT
##########################################################################################
const R_MAX := 10
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
	'if !alifemanager.agent_photo_stamp_on:
		alifemanager.current_global_photosynthesis_rate[c] += w
		return'

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

		world.SUN_stamp[x + y * W + z * PLANE] += w

	if layer != 0:
		world.SUN_stamp[c] += w


## Returns the global id of the closest agent to `p`, or -1 if none found.
## self_id:   global id to ignore (-1 = none)
## species:   only this species (-1 = any species)
## max_rings: how far to search, in cells (1 = the 3x3x3 block around me)
func find_nearest(p: Vector3, self_id: int = -1, species: int = -1, max_rings: int = 1) -> Vector4:

	
	var am := alifemanager
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var ws: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var offs: PackedInt32Array = am.global_species_offset
	var active: PackedInt32Array = am.global_active          

	# species filter as an id range (no lookup per agent)
	var lo := 0
	var hi := 1 << 30
	if species >= 0:
		lo = offs[species]
		hi = offs[species + 1]

	var cx := clampi(int(p.x / cs.x), 0, W - 1)
	var cy := clampi(int(p.y / cs.y), 0, H - 1)
	var cz := clampi(int(p.z / cs.z), 0, D - 1)

	# on wrap axes, don't search further than half the grid (avoids visiting cells twice)
	var lim_x := mini(max_rings, (W - 1) / 2) if wrap_x else max_rings
	var lim_y := mini(max_rings, (H - 1) / 2) if wrap_y else max_rings
	var lim_z := mini(max_rings, (D - 1) / 2) if wrap_z else max_rings
	var cmin := minf(cs.x, minf(cs.y, cs.z))

	var best := -1
	var best_d2 := INF
	var best_d := Vector3.ZERO

	for r in max_rings + 1:
		# stop: anything in ring r is at least (r - 1) cells away
		if best >= 0 and best_d2 <= pow((r - 1) * cmin, 2):
			break

		for dz in range(-mini(r, lim_z), mini(r, lim_z) + 1):
			var z := cz + dz
			if not wrap_z and (z < 0 or z >= D): continue
			var zw := posmod(z, D)
			var sz := float((z - zw) / D) * ws.z

			for dy in range(-mini(r, lim_y), mini(r, lim_y) + 1):
				var y := cy + dy
				if not wrap_y and (y < 0 or y >= H): continue
				var yw := posmod(y, H)
				var sy := float((y - yw) / H) * ws.y

				for dx in range(-mini(r, lim_x), mini(r, lim_x) + 1):
					# only the shell of this ring (inner cells were done before)
					if maxi(absi(dx), maxi(absi(dy), absi(dz))) != r:
						continue
					var x := cx + dx
					if not wrap_x and (x < 0 or x >= W): continue
					var xw := posmod(x, W)
					var sx := float((x - xw) / W) * ws.x

					var cell := xw + W * (yw + H * zw)
					var shift_p := Vector3(sx, sy, sz) - p
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var other: int = cell_items[k]
						if other == self_id or other < lo or other >= hi:
							continue
						if active[other] == 0 :                  # <- new: skip inactive
							continue
						var d: Vector3 = sorted_pos[k] + shift_p
						var d2 := d.length_squared()
						if d2 < best_d2:
							best_d2 = d2
							best = other
							best_d = d


	return Vector4(best_d.x, best_d.y, best_d.z, float(best))

func get_cell_id(pos: Vector3,cell_size:Vector3, W:int , H:int, D:int)-> int :
		var inv := Vector3.ONE / cell_size # worldd.SUN_cell_size   # (1/x, 1/y, 1/z)
		var p := (pos) * inv  #MAYBE HERE TO CHANGE?
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
		if photosynthesis_on and !has_seed:
			var s_c := get_cell_id(newpos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
			if world.SUN_stamp[s_c] > 0 :
				continue
		Build_New_Life(newpos,seed_energy,0, current_color[i])
	
	for i in pending_remove_id:
		Remove_Life(i)	



	pending_spawn_id.clear()
	pending_remove_id.clear()


func Build_New_Life(pos: Vector3, e: float = seed_energy,lc:= 0, col := Color(0.159, 0.555, 0.215, 1.0)):
	if alifemanager.global_entity_count >= alifemanager.maxLife and alifemanager.maxLife>0:
		return

	var i  =  find_free_index()
	if i >= entity_count:
		current_energy_array.append(e) #HERE MAYBE
		active_alife_array.append(1)
		position_array.append(pos)
		current_color.append(col)
		current_health.append(max_health)
		current_max_health.append(max_health)
		color_packed.append(0)
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array.append(1) 
		current_velocity.append(Vector3.ZERO)
		new_velocity.append(Vector3.ZERO)
		facing.append(Vector3.ZERO)
		current_life_state.append(lc)
		current_biomass.append(seed_biomass)
		current_age.append(0)
		current_size.append(init_size)
		current_action.append(0)
		holding.append(-1)
		held_by.append(-1)	
		pilot_id.append(-1)

		current_sungrid_id.append(get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D))
		current_grid_id.append(get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D))
		
		current_cpu_cost.append(0)
		neighbour_count.append(0)

		#update_bin_array(i)
		entity_count += 1

		
	else:
		current_energy_array[i] = e
		active_alife_array[i] = 1
		position_array[i] = pos
		current_health[i] = max_health
		current_max_health[i] = max_health

		current_color[i]=col
		set_agent_color(i,Color(1.0, 1.0, 1.0, 1.0))
		alive_array[i] = 1
		current_velocity[i] = Vector3.ZERO
		new_velocity[i] = Vector3.ZERO
		facing[i] = Vector3.ZERO
		current_sungrid_id[i] = get_cell_id(pos,world.SUN_cell_size,world.SUN_GRID_W,world.SUN_GRID_H,world.SUN_GRID_D)
		current_grid_id[i] = get_cell_id(pos,alifemanager.cell_size,alifemanager.GRID_W,alifemanager.GRID_H,alifemanager.GRID_D)
		current_life_state[i]=lc
		current_biomass[i]=seed_biomass
		current_age[i]=0
		current_size[i]=init_size
		current_cpu_cost[i] = 0
		neighbour_count[i] = 0
		current_action[i] = 0
		holding[i] = -1
		held_by[i] = -1
		pilot_id[i] = -1                   # a reused slot is never still controlled
		
	active_entity_count += 1
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := photo_range#int(init_size.x)-1
			stamp(c,r,0,photo_layer_y,1.0)

	pending_multimesh_drawn_id.append(i)


func Remove_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 0
	free_indices.append(i)
	active_entity_count -= 1
	
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := photo_range #int(init_size.x)-1
			stamp(c,r,0,photo_layer_y,-1.0)

	pending_multimesh_erase_id.append(i)


func Stock_Life(i):
	if active_alife_array[i] == 0:
		return 
	active_alife_array[i]= 2 # STORED ?

	active_entity_count -= 1
	if photosynthesis_on:
			var c := current_sungrid_id[i]
			var r := photo_range
			stamp(c,r,0,photo_layer_y,-1.0)
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
			#var c_calc := c +  world.SUN_GRID_W
			var r := photo_range
			stamp(c,r,0,photo_layer_y,1.0)

			
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
# ============================================================================
# Render packing — paste into your species script.
# Writes 4 floats per agent into rend_data.data (read by test3d.gdshader):
#   R = x
#   G = z
#   B = y (12 bits) << 12 | color RGB 4:4:4 (12 bits)
#   A = state (2) | action (4) << 2 | size (6) << 6 | life cycle (12) << 12
# Every packed channel is <= 24 bits: the largest integer a float stores exactly.
# ============================================================================

enum AgentState { FREE = 0, ALIVE = 1, DEAD = 2, DECOMPOSING = 3 }

# --- Channel A ---
const STATE_BITS  := 2
const ACTION_BITS := 4
const SIZE_BITS   := 8
const LIFE_BITS   := 10      # 2 + 4 + 6 + 12 = 24

const ACTION_SHIFT := STATE_BITS                  # 2
const SIZE_SHIFT   := ACTION_SHIFT + ACTION_BITS  # 6
const LIFE_SHIFT   := SIZE_SHIFT + SIZE_BITS      # 12

const ACTION_MASK := (1 << ACTION_BITS) - 1       # 15
const SIZE_MASK   := (1 << SIZE_BITS) - 1         # 63
const LIFE_MASK   := (1 << LIFE_BITS) - 1         # 4095

#const SIZE_MIN := 0.5        # must match SIZE_MIN in the shader
#const SIZE_MAX := 100.0      # must match SIZE_MAX in the shader
#const SIZE_SCALE := SIZE_MASK / (SIZE_MAX - SIZE_MIN)

# --- Channel B ---
const COLOR_BITS := 12                            # RGB 4:4:4
const Y_SHIFT    := COLOR_BITS                    # 12
const Y_MASK     := (1 << 12) - 1                 # 4095 levels between 0 and world height

var y_scale := 0.0                                # set by setup_render_packing()

## Per-agent color, packed 4:4:4. Set at birth / mutation with set_agent_color().
## 0 = "no color": the shader uses the species' alive_color instead.
## Resize it together with your other per-agent arrays.
var color_packed := PackedInt32Array()


## Call once after the world size is known (e.g. in the species setup).
func setup_render_packing() -> void:
	y_scale = Y_MASK / maxf(world.size.y, 0.001)  # guard against a flat world


static func pack_color444(c: Color) -> int:
	return (roundi(c.r * 15.0) << 8) | (roundi(c.g * 15.0) << 4) | roundi(c.b * 15.0)


func set_agent_color(i: int, c: Color) -> void:
	color_packed[i] = pack_color444(c)


func write_rendering_buffer_in_chunk(start: int, end: int) -> void:
	var r_data := rend_data.data
	for i in range(start, end):
		var o := i * 4

		# --- State: active + alive merged ---
		var state := AgentState.FREE
		if active_alife_array[i] != 0:
			state = AgentState.ALIVE if alive_array[i] != 0 else AgentState.DEAD
			# if <your decomposing flag>: state = AgentState.DECOMPOSING

		if state == AgentState.FREE:
			r_data[o + 3] = 0.0                   # shader skips free slots
			continue

		var p := position_array[i]
		var size_q := mini(roundi(current_size[i] * 10.0), SIZE_MASK)
		var action := mini(current_action[i], ACTION_MASK)       # <- your action array
		var life := mini(current_life_state[i], LIFE_MASK)
		var y_q := clampi(roundi(p.y * y_scale), 0, Y_MASK)

		r_data[o]     = p.x
		r_data[o + 1] = p.z
		r_data[o + 2] = float(color_packed[i] | (y_q << Y_SHIFT))
		r_data[o + 3] = float(state | (action << ACTION_SHIFT) \
				| (size_q << SIZE_SHIFT) | (life << LIFE_SHIFT))

	rend_data.dirty = true

#####################################OLD BELOW##############################
#############################################################################
