extends ALIFE_CATTLE
class_name ALIFE_NPC
## NPC species: agents with a name and dialogue (NpcData), placed by NpcSpot nodes.
## Built on the cattle: same walking on the height grid (floors, walls, ledges).
##   - wander around their spot (NpcData.wander_radius), slowly
##   - stop while you talk to them
##   - Action key near one (PlayerController._interact -> Interact): opens the DialogueBox
##   - can't be eaten, carried, or hurt; no metabolism (they don't starve or reproduce)
## Add it to ALIFE_CODEX's species list, and "NPC" to NavWorld's species_names.

# Per agent (sized in Build_New_Life)
var npc_data: Array = []                       # NpcData of each agent (main thread only)
var home := PackedVector3Array()               # where its NpcSpot put it
var talking := PackedInt32Array()              # 1 while in a conversation
var times_talked := PackedInt32Array()
var wander_r := PackedFloat32Array()           # copied from NpcData: read by the worker threads
var wander_s := PackedFloat32Array()

var damage_reduction := 1000000.0              # attacks do nothing


func _init() -> void:
	species_name = "NPC"
	init_size = 2.0
	sprite = preload("res://Alife/animal/PLAYER/player_cat.png")   # <- your NPC sprite
	colour = Color(0.45, 0.75, 1.0, 1.0)
	max_energy = 1000
	seed_energy = 1000
	seed_biomass = 50
	pause_chance = 0.4                         # stops often (looks idle)
	walk_chance = 0.3


func _init_alife_par():
	super()
	npc_data = []
	home = []
	talking = []
	times_talked = []
	wander_r = []
	wander_s = []


func Build_New_Life(pos: Vector3, e: float = seed_energy, lc := 0, col := Color(0.159, 0.555, 0.215, 1.0)):
	var i: int = free_indices[free_indices.size() - 1] if free_indices.size() > 0 else entity_count
	var before := active_entity_count
	super(pos, e, lc, col)
	if active_entity_count == before:
		return
	if i >= home.size():
		npc_data.append(null)
		home.append(pos)
		talking.append(0)
		times_talked.append(0)
		wander_r.append(0.0)
		wander_s.append(0.0)
	else:
		npc_data[i] = null
		home[i] = pos
		talking[i] = 0
		times_talked[i] = 0
		wander_r[i] = 0.0
		wander_s[i] = 0.0


## Called by NpcSpot right after spawning agent i (main thread).
func setup_npc(i: int, data: NpcData, home_pos: Vector3) -> void:
	npc_data[i] = data
	home[i] = home_pos
	wander_r[i] = data.wander_radius if data != null else 0.0
	wander_s[i] = data.wander_speed if data != null else 0.0


func run_chunk_simulation(start: int, end: int, local_id: int, delta: float, dt: float, sim_speed: float) -> void:
	var local_pending_spawn_id: PackedInt32Array
	var local_pending_remove_id: PackedInt32Array
	if alifemanager.global_position_array.size() < 1:
		spawn_per_chunk[local_id] = local_pending_spawn_id
		remove_per_chunk[local_id] = local_pending_remove_id
		return

	var world_size: Vector3 = world.size
	var wrap_x: bool = world.border_type_x == world.Border.WRAP
	var wrap_y: bool = world.border_type_y == world.Border.WRAP
	var wrap_z: bool = world.border_type_z == world.Border.WRAP
	var hg := height_grid

	for i in range(start, end):
		if active_alife_array[i] != 1:
			continue
		if alive_array[i] == 0:
			local_pending_remove_id.append(i)    # NpcSpot respawns it if wanted
			continue
		var p := position_array[i]
		var v := current_velocity[i]
		var is_player := i == player_index
		var new_v := Vector3.ZERO
		if is_player:
			new_v = player_velocity
		elif i < talking.size() and talking[i] == 0 and wander_s[i] > 0.0 and wander_r[i] > 0.0:
			new_v = _wander(v, delta)
			if new_v.length_squared() > 1e-6:
				new_v = new_v.normalized() * wander_s[i]
			var to_home := home[i] - p
			to_home.y = 0.0
			if to_home.length() > wander_r[i]:
				new_v = to_home.normalized() * wander_s[i]   # too far: back home
		_move(i, p, new_v, delta, world_size, wrap_x, wrap_y, wrap_z, is_player, hg)

	spawn_per_chunk[local_id] = local_pending_spawn_id
	remove_per_chunk[local_id] = local_pending_remove_id


# --- Talking (main thread) ---------------------------------------------------------------

## Action key on this NPC (PlayerController._interact): starts its dialogue.
func Interact(i: int, sp: ALIFE, local_id: int):
	var box := _dialogue_box()
	if box == null:
		push_warning("ALIFE_NPC: no DialogueBox autoload (Project Settings > Globals > Autoload)")
		return
	if box.is_open or i >= npc_data.size() or npc_data[i] == null:
		return
	talking[i] = 1
	current_velocity[i] = Vector3.ZERO
	var first := times_talked[i] == 0
	times_talked[i] += 1
	var done := func():
		if i < talking.size():
			talking[i] = 0                     # free to walk again
	box.start(npc_data[i], first, done)


func _dialogue_box() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("DialogueBox") if tree != null else null


# --- Protected ---------------------------------------------------------------------------

func can_be_carried(_j: int) -> bool:
	return true


func can_be_eaten(_j: int) -> bool:
	return true


func on_damaged(_i: int, _sp: ALIFE, _local_id: int):
	pass
