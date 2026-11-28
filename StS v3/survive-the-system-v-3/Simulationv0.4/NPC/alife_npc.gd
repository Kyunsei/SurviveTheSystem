extends ALIFE_CATTLE
class_name ALIFE_NPC
## NPC species: agents with a name and dialogue (NpcData), placed by NpcSpot nodes.
## Built on the cattle: same walking on the height grid (floors, walls, ledges).
##   - wander around their spot (NpcData.wander_radius), slowly
##   - stop while anyone talks to them (several players can talk to one at once)
##   - Action key near one (PilotSystem -> Interact): opens the DialogueBox on the screen
##     of whoever pressed it; it closes when they're farther than talk_range
##   - can be carried and eaten (carryable / edible), can't be hurt; no metabolism
## Add it to ALIFE_CODEX's species list, and "NPC" to NavWorld's species_names.

# Per agent (sized in Build_New_Life)
var npc_data: Array = []                       # NpcData of each agent (main thread only)
var home := PackedVector3Array()               # where its NpcSpot put it
var talking := PackedInt32Array()              # how many people talk to it now
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
		var pl: Pilot = get_pilot(i) if pilot_id[i] >= 0 else null   # null = the AI
		var is_player := pl != null
		var new_v := Vector3.ZERO
		if is_player:
			new_v = control_velocity(pl, i, p, 0.0, delta, false)   # keys; _move does gravity
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

## A conversation ends when the talker and the NPC are farther apart than this
## (walked away, NPC carried off), or when either is gone (eaten, died).
var talk_range := 5.0

## Open conversations: {"i": npc index, "data": its NpcData, "sp"/"li": the talker,
## "peer": the talker's network peer (0 = here)}. Several at once: anyone can talk to a
## busy NPC. talking[i] = how many people talk to NPC i (it stands still while > 0).
var _talks: Array[Dictionary] = []
## Talked to before: "npc index:peer" -> true (first lines once per player).
var _met := {}


## Action key on this NPC: starts its dialogue, on the screen of whoever plays `sp`.
func Interact(i: int, sp: ALIFE, local_id: int):
	if i >= npc_data.size() or npc_data[i] == null:
		push_warning("ALIFE_NPC #%d has no NpcData (was it placed by an NpcSpot?)" % i)
		return
	var peer := _remote_peer(sp, local_id)
	for t in _talks:
		if t["i"] == i and t["peer"] == peer:
			return                             # this player already talks to it
	var box := _dialogue_box()
	if peer == 0:
		if box == null:
			push_warning("ALIFE_NPC: no DialogueBox autoload (Project Settings > Globals > Autoload)")
			return
		if box.is_open:
			return                             # our screen already shows a dialogue
	if (npc_data[i] as NpcData).first_lines.is_empty():
		push_warning("NPC %s has no first_lines" % (npc_data[i] as NpcData).display_name)

	var key := "%d:%d" % [i, peer]
	var first_meet := not _met.has(key)
	_met[key] = true
	times_talked[i] += 1
	talking[i] += 1
	current_velocity[i] = Vector3.ZERO
	_talks.append({"i": i, "data": npc_data[i], "sp": sp, "li": local_id, "peer": peer})

	if peer > 0:                               # a network player: on THEIR screen
		var net := _autoload("Network")
		if net != null:
			net.open_remote_dialogue(peer, species_name, i, npc_data[i], first_meet)
	else:
		box.start(npc_data[i], first_meet, func(): _end_talk(i, 0))


## Every frame (host / solo, called by PilotSystem): closes the conversations whose
## talker walked away, or whose NPC was carried off, eaten or died.
func update_talks() -> void:
	if _talks.is_empty():
		return
	var r2 := talk_range * talk_range
	for t in _talks.duplicate():
		var i: int = t["i"]
		var tsp = t["sp"]
		var li: int = t["li"]
		var ok: bool = i < entity_count and active_alife_array[i] != 0 and alive_array[i] != 0 \
				and npc_data[i] == t["data"] \
				and li < tsp.entity_count and tsp.active_alife_array[li] != 0 \
				and tsp.alive_array[li] != 0
		if ok:
			var d: Vector3 = tsp.position_array[li] - position_array[i]
			var ws := WorldWrap.size
			if WorldWrap.mask.x > 0.0: d.x -= ws.x * roundf(d.x / ws.x)
			if WorldWrap.mask.z > 0.0: d.z -= ws.z * roundf(d.z / ws.z)
			ok = d.x * d.x + d.z * d.z <= r2
		if not ok:
			_close_talk(t)


## Ends conversation t now: on our screen, or on the remote player's.
func _close_talk(t: Dictionary) -> void:
	var peer: int = t["peer"]
	_end_talk(t["i"], peer)                    # first, so the box's own callback finds nothing
	if peer > 0:
		var net := _autoload("Network")
		if net != null:
			net.close_remote_dialogue(peer)
	else:
		var box := _dialogue_box()
		if box != null and box.is_open:
			box.close()


## A conversation is over (closed by the player, or by _close_talk). Safe to call twice.
func _end_talk(i: int, peer: int) -> void:
	for t in _talks:
		if t["i"] == i and t["peer"] == peer:
			_talks.erase(t)
			if i < talking.size():
				talking[i] = maxi(talking[i] - 1, 0)   # walks again once nobody talks to it
			return


## Host: the remote player `peer` closed its dialogue with NPC i.
func remote_dialogue_closed(i: int, peer: int) -> void:
	_end_talk(i, peer)


func _dialogue_box() -> Node:
	return _autoload("DialogueBox")


func _autoload(n: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(n) if tree != null else null


## The network peer playing agent local_id of sp, or 0 if it's played here (or by the AI).
func _remote_peer(sp, local_id: int) -> int:
	if not ("pilot_id" in sp) or local_id >= sp.pilot_id.size() or sp.pilot_id[local_id] < 0:
		return 0
	var pl = sp.get_pilot(local_id)
	if pl == null:
		return 0
	var tree := Engine.get_main_loop() as SceneTree
	var me := tree.root.multiplayer.get_unique_id() if tree != null else 1
	return pl.peer_id if pl.peer_id != me else 0


# --- Protected ---------------------------------------------------------------------------
## Players can carry and eat NPCs (an NpcSpot with respawn brings an eaten one back).
## Set these to false to make them untouchable again.
var carryable := true
var edible := true


func can_be_carried(_j: int) -> bool:
	return carryable


func can_be_eaten(_j: int) -> bool:
	return edible


func on_damaged(_i: int, _sp: ALIFE, _local_id: int):
	pass
