class_name NetSession
extends Node
## Put ONE in your game scene. It connects the game to the Network autoload:
##
##   HOST    runs the simulation as usual. When a player joins, it spawns an agent for it
##           (spawn_species, near spawn_point), gives it a Pilot, and feeds that pilot with
##           the inputs the player sends. When the player leaves, its agent goes back to the
##           AI (or is removed: remove_agent_on_leave).
##   CLIENT  sends its inputs to the host every frame. Its own simulation is stopped: the
##           host sends SNAPSHOTS of the agents around the player's agent (snapshot_rate per
##           second, within interest_radius). The client mirrors them into its own species
##           arrays (so rendering, picking and outlines work as usual), moves them smoothly
##           between two snapshots, and the camera follows its agent.
##
## Both machines must run the same scene. A small lobby panel (top left) hosts / joins.

@export var alifemanager: AlifeManager
@export var sim_manager: SimulationManager
@export var controller: PlayerController
## Optional: empty = AlifeManager's child "Pilots".
@export var pilots: PilotSystem
## Optional: players' agents are spawned on its walkable floor.
@export var nav_world: NavWorld

@export_group("Players")
@export var spawn_species := "CATRONAUTE"     # what a joining player plays
@export var spawn_point: Node3D               # where (empty = the world's center)
@export var spawn_radius := 3.0
@export var spawn_as_adult := true
## true: a leaving player's agent is removed. false: it stays, played by the AI.
@export var remove_agent_on_leave := true
## Network client leaving (or the host quitting): reload the scene, for a fresh solo world.
## false: only the copies of the host's agents are removed, and our simulation resumes.
@export var reload_scene_on_leave := true

@export_group("Snapshots (host)")
@export var snapshot_rate := 15.0             # per second, per client
@export var interest_radius := 40.0           # world units around the player's agent
@export var max_agents_per_snapshot := 3000   # the closest cells first
## No input from a player for this long (lag, frozen window): its agent stops.
@export var input_timeout := 0.5

@export_group("Prediction (client)")
## Your own agent moves at once on your screen (same movement as the host: species
## control_velocity + height grid), then is corrected toward the host's position.
## Off: it is shown like every other agent (smooth, but late by the network delay).
@export var predict_own_agent := true
## How fast a correction is blended in (per second). Higher = snappier, lower = smoother.
@export var correction_rate := 10.0
## A prediction error bigger than this (world units) is not blended: the agent jumps.
@export var snap_distance := 4.0

@export_group("Client authority (host)")
## On: each player's client moves its own agent (instant, no correction) and sends where
## it is; the host only CHECKS it (not faster than its species can go, no going through
## walls on the height grid) and corrects it only when it isn't plausible.
## Off: the host moves everyone from the inputs (prediction + correction on the client).
## The host's value decides. Also a checkbox in the lobby panel.
@export var client_authority := true
## Extra distance allowed on top of the species' top speed (lag spikes, wrap...).
@export var move_tolerance := 1.0
## A claimed position whose path the height grid ends farther than this from it: refused.
@export var wall_tolerance := 0.5
## No position from a driving client for this long (it doesn't send any: prediction off,
## old build...): the host moves its agent from the inputs again.
@export var position_timeout := 0.3
## Print on the host why a client's position was refused (at most once per second).
@export var debug_refusals := true

@export_group("Lobby panel")
@export var show_lobby := true
@export var default_address := "127.0.0.1"
@export var lobby_toggle_key := KEY_F2

# Client: press counters per button, sent every packet (see pack_input)
var _press_counts := PackedByteArray()
# Host: last counters received per pilot slot
var _last_counts := {}

# Host
var _snap_timer := 0.0
var _snap_seq := 0
var _centers := {}                            # peer -> last center of its snapshots
var _last_input_time := {}                    # pilot slot -> real time of its last packet
# Client
var _maps: Array[Dictionary] = []             # per species: host index -> mirror entry
var _last_seq := -1
var _arrival := 0.0                           # real time the last snapshot arrived
var _interval := 1.0 / 15.0                   # measured time between snapshots
var _own_species := -1                        # our agent on the host: species id, index
var _own_index := -1
var _was_client := false                      # we joined someone (cleared on leave)
# Client prediction of our own agent
var _pred: Pilot = null                       # local copy of our pilot (never in PilotSystem)
var _pred_on := false
var _pred_pos := Vector3.ZERO                 # predicted position (corrected at once)
var _pred_floor := 0.0
var _pred_vel := Vector3.ZERO
var _visual_offset := Vector3.ZERO            # drawn = predicted + this; fades to zero
var _authority_on := false                    # client: the host uses client authority
var _host_lets_drive := false                 # client: we move our agent now (send our position)
var _last_corr := -1                          # client: last correction counter seen
var _refusal_print := 0.0                     # host: next time a refusal may be printed
var _snap_flags := 0                          # host: flags / corrections of the snapshot being built
var _snap_corr := 0
var _hist_seq := PackedInt32Array()           # input seq -> predicted position after it
var _hist_pos := PackedVector3Array()
const HISTORY := 256

var _ui := CanvasLayer.new()
var _panel := PanelContainer.new()
var _name_edit := LineEdit.new()
var _addr_edit := LineEdit.new()
var _port_edit := LineEdit.new()
var _host_btn := Button.new()
var _join_btn := Button.new()
var _leave_btn := Button.new()
var _status := Label.new()
var _list := Label.new()


func _ready() -> void:
	# Before the camera (10): on a client, the camera follows where we just put our agent.
	# Host work runs in between_ticks (called by SimulationManager when arrays are free).
	process_priority = 5
	add_to_group("between_ticks")
	_press_counts.resize(10)
	if pilots == null and alifemanager != null:
		pilots = PilotSystem.ensure(alifemanager)
	Network.session = self
	Network.hosted.connect(_refresh_ui)
	Network.joined.connect(_refresh_ui)
	Network.left.connect(_on_left)
	Network.join_failed.connect(func(reason): _set_status("Join failed: " + reason))
	Network.player_joined.connect(func(_id, _n): _refresh_ui())
	Network.player_left.connect(func(_id): _refresh_ui())
	_build_ui()
	_refresh_ui()
	if Network.is_client():
		client_joined("")                     # new scene while connected (host changed scene)
		Network.say_hello()                   # -> the host spawns our agent here


func _exit_tree() -> void:
	if Network.session == self:
		Network.session = null


func scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s != null else ""


func _process(delta: float) -> void:
	if Network.is_client():
		# Send our input to the host every frame, then draw the mirrored world
		if controller != null and controller.remote_slot >= 0:
			var inp := controller._build_input()
			_predict(inp, delta)              # before pack_input (it clears the presses)
			Network.send_input(pack_input(inp))
		_client_interpolate(delta)


## Host: called by SimulationManager right before each tick, when the species arrays are
## free (also with the pipelined tick): spawn joining players, apply their moves, snapshots.
func between_ticks(delta: float) -> void:
	if not Network.is_host():
		return
	if pilots._world_ready():
		Network.accept_pending()              # players who said hello: spawn their agents
	_host_stop_silent_players()
	_host_apply_client_moves()
	_snap_timer += delta
	var every := 1.0 / maxf(snapshot_rate, 1.0)
	if _snap_timer >= every:
		_snap_timer = fmod(_snap_timer, every)
		_host_send_snapshots()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == lobby_toggle_key:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


# --- Input packets ---------------------------------------------------------------------------

## PlayerInput (12 bytes) + one press counter per button (10 bytes).
## A press only counts once even if its packet is lost or arrives twice: the host compares
## the counters with the last ones it saw.
func pack_input(inp: PlayerInput) -> PackedByteArray:
	for k in 10:
		if inp.pressed & (1 << k) != 0:
			_press_counts[k] = (_press_counts[k] + 1) & 255
	inp.pressed = 0
	var b := inp.to_bytes()
	b.append_array(_press_counts)
	if _host_lets_drive and _pred_on:
		var o := b.size()                     # client authority: where our agent is
		b.resize(o + 16)
		b.encode_float(o, _pred_pos.x)
		b.encode_float(o + 4, _pred_pos.y)
		b.encode_float(o + 8, _pred_pos.z)
		b.encode_float(o + 12, _pred_floor)
	return b


## Host: an input packet from peer_id for its pilot slot.
func host_receive_input(_peer_id: int, slot: int, bytes: PackedByteArray) -> void:
	if bytes.size() < 22:
		return
	var counts := bytes.slice(12, 22)
	var last: PackedByteArray = _last_counts.get(slot, counts)
	var pressed := 0
	for k in 10:
		if counts[k] != last[k]:
			pressed |= 1 << k                 # pressed (at least once) since the last packet
	_last_counts[slot] = counts
	var inp := bytes.slice(0, 12)
	inp.encode_u16(6, pressed)
	pilots.receive_input(slot, inp)
	_last_input_time[slot] = _now()
	# Client authority: where the client says its agent is (+ its floor)
	if bytes.size() >= 38 and slot < pilots.pilots.size() and pilots.pilots[slot] != null:
		var pl: Pilot = pilots.pilots[slot]
		pl.net_pos = Vector3(bytes.decode_float(22), bytes.decode_float(26), bytes.decode_float(30))
		pl.net_has_pos = true


# --- Host side ---------------------------------------------------------------------------------

## A player joined: spawn its agent and give it a pilot.
func host_player_joined(peer_id: int) -> void:
	var sp = alifemanager.codex.species.get(spawn_species)
	if sp == null:
		push_warning("NetSession: no species named %s" % spawn_species)
		return
	var at := _spawn_spot()
	var i: int = sp.free_indices[sp.free_indices.size() - 1] if sp.free_indices.size() > 0 \
			else sp.entity_count
	var before: int = sp.active_entity_count
	sp.Build_New_Life(at, sp.seed_energy)
	if sp.active_entity_count == before:
		push_warning("NetSession: world full, no agent for peer %d" % peer_id)
		return
	if spawn_as_adult:
		sp.current_life_state[i] = sp.max_life_cycle
		sp.current_energy_array[i] = sp.max_energy * 0.8
	var pl := pilots.add_pilot(sp, i, peer_id)
	if pl == null:
		return
	_last_counts.erase(pl.id)
	Network.assign(peer_id, pl.id, sp.species_name, i, sp.control_actions)
	print("NetSession: peer %d plays %s #%d (pilot %d)" % [peer_id, sp.species_name, i, pl.id])
	_refresh_ui()


func host_player_left(peer_id: int) -> void:
	alifemanager.when_free(_host_player_left.bind(peer_id))   # a tick may be running


func _host_player_left(peer_id: int) -> void:
	for pl in pilots.pilots_of(peer_id):
		var sp = pl.species
		var i: int = pl.index
		_last_counts.erase(pl.id)
		pilots.remove_pilot(pl)
		if remove_agent_on_leave and sp.active_alife_array[i] != 0:
			alifemanager.unlink(sp, i)
			sp.Remove_Life(i)


## Its agent died or was released on the host: tell the client.
func _on_pilot_removed(pl: Pilot) -> void:
	if Network.is_host() and pl.peer_id != Network.my_id() and Network.players.has(pl.peer_id):
		Network.assign(pl.peer_id, -1)


func _spawn_spot() -> Vector3:
	var c: Vector3 = spawn_point.global_position if spawn_point != null else WorldWrap.size * 0.5
	var a := randf() * TAU
	var r := sqrt(randf()) * spawn_radius
	var p := alifemanager.keep_in_world(Vector3(c.x + cos(a) * r, c.y, c.z + sin(a) * r))
	if spawn_point == null:
		p.y = 0.0
	if nav_world != null and nav_world.grid != null:
		var h := nav_world.floor_at(p.x, p.z, p.y + 1.0)
		if not is_nan(h):
			p.y = h
	return p


# --- Client side -------------------------------------------------------------------------------

func client_joined(host_scene: String) -> void:
	if host_scene != "" and host_scene != scene_path():
		push_warning("NetSession: the host runs %s, you run %s" % [host_scene, scene_path()])
	if controller != null:
		controller.release_control()          # no local control on a client
	if sim_manager != null:
		sim_manager.running = false           # the host's world is the only one
	_clear_local_world()
	_was_client = true
	_set_status("Joined, waiting for an agent...")


func client_assigned(slot: int, species_name: String, index: int, actions: int) -> void:
	if controller == null:
		return
	controller.remote_slot = slot
	controller.remote_actions = actions
	_press_counts.fill(0)
	var sp = alifemanager.codex.species.get(species_name) if species_name != "" else null
	_own_species = sp.species_id if sp != null else -1
	_own_index = index if slot >= 0 else -1
	if slot < 0:
		controller.end_remote_view()
		_set_status("Your agent is gone")
	else:
		_set_status("You play %s #%d on the host" % [species_name, index])
	_refresh_ui()


func _on_left() -> void:
	if controller != null:
		controller.remote_slot = -1
		controller.end_remote_view()
	if _was_client:
		_was_client = false
		if reload_scene_on_leave:
			get_tree().reload_current_scene.call_deferred()
			return
		_clear_local_world()                  # the host's agents aren't ours: remove them
	_maps.clear()
	_last_seq = -1
	_own_species = -1
	_authority_on = false
	_host_lets_drive = false
	_last_corr = -1
	if sim_manager != null and not sim_manager.running:
		sim_manager.running = true            # back to our own world (solo)
	_refresh_ui()


# --- Lobby panel ---------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui.layer = 95
	add_child(_ui)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(12, 12)
	_panel.visible = show_lobby
	_ui.add_child(_panel)

	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Multiplayer   (F2 hide)"
	box.add_child(title)

	_name_edit.text = Network.player_name
	_name_edit.placeholder_text = "Name"
	_addr_edit.text = default_address
	_addr_edit.placeholder_text = "Host address"
	_port_edit.text = str(Network.DEFAULT_PORT)
	_port_edit.placeholder_text = "Port"
	for e in [_name_edit, _addr_edit, _port_edit]:
		e.custom_minimum_size = Vector2(180, 0)
		box.add_child(e)

	var row := HBoxContainer.new()
	box.add_child(row)
	_host_btn.text = "Host"
	_join_btn.text = "Join"
	_leave_btn.text = "Leave"
	for b in [_host_btn, _join_btn, _leave_btn]:
		b.focus_mode = Control.FOCUS_NONE     # never steals Space / Enter from the game
		row.add_child(b)
	_host_btn.pressed.connect(_on_host_pressed)
	_join_btn.pressed.connect(_on_join_pressed)
	_leave_btn.pressed.connect(Network.leave)

	var auth := CheckBox.new()
	auth.text = "Players move their own agent"
	auth.tooltip_text = "Client authority (host decides): instant movement, the host only checks it"
	auth.button_pressed = client_authority
	auth.focus_mode = Control.FOCUS_NONE
	auth.toggled.connect(func(on): client_authority = on)
	box.add_child(auth)

	_status.text = "Offline"
	box.add_child(_status)
	_list.add_theme_font_size_override("font_size", 11)
	box.add_child(_list)
	if pilots != null:
		pilots.pilot_removed.connect(_on_pilot_removed)


func _on_host_pressed() -> void:
	Network.player_name = _name_edit.text.strip_edges()
	if Network.host(int(_port_edit.text)) == OK:
		_set_status("Hosting on port %s" % _port_edit.text)
	_release_focus()


func _on_join_pressed() -> void:
	Network.player_name = _name_edit.text.strip_edges()
	if Network.join(_addr_edit.text.strip_edges(), int(_port_edit.text)) == OK:
		_set_status("Connecting...")
	_release_focus()


func _release_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		f.release_focus()                     # typing in a field must not keep the keys


func _set_status(t: String) -> void:
	_status.text = t


func _refresh_ui() -> void:
	var online := Network.is_online()
	_host_btn.disabled = online
	_join_btn.disabled = online
	_leave_btn.disabled = not online
	if not online and not _status.text.begins_with("Join failed"):
		_status.text = "Offline"
	var lines := PackedStringArray()
	for id in Network.players:
		var p: Dictionary = Network.players[id]
		lines.append("%s%s  (peer %d%s)" % [p["name"], "  [host]" if id == 1 else "",
				id, "" if p["slot"] < 0 else ", pilot %d" % p["slot"]])
	_list.text = "\n".join(lines)


# --- Snapshots: host ---------------------------------------------------------------------------
#
# Packet (zstd compressed, preceded by its raw size as u32):
#   u32 seq, f32 host time, u16 number of species blocks, u16 0,
#   u32 ack: the last input seq of this client the host has applied (prediction)
#   u8 flags (1: you drive your agent now, 2: client authority is on), u8 0,
#   u16 corrections: goes up each time the host refused this client's position
#   per species block: u8 species id, u16 n, then n agents of 15 bytes:
#     u32 host index, u16 x, u16 z, u16 y (quantized over the world size),
#     u8 size x10, u8 life stage, u8 state (active state | alive << 3), u16 color 4:4:4
const AGENT_BYTES := 15
const HEADER_BYTES := 20


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


## Players whose packets stopped: their agent stops walking (no runaway cat).
func _host_stop_silent_players() -> void:
	var now := _now()
	for id in Network.players:
		var slot: int = Network.players[id]["slot"]
		if id == 1 or slot < 0 or slot >= pilots.pilots.size() or pilots.pilots[slot] == null:
			continue
		if now - _last_input_time.get(slot, now) > input_timeout:
			var pl: Pilot = pilots.pilots[slot]
			pl.input.move = Vector2.ZERO
			pl.input.held = 0


func _host_send_snapshots() -> void:
	if not pilots._world_ready():
		return
	_snap_seq += 1
	for id in Network.players:
		if id == 1:
			continue
		var slot: int = Network.players[id]["slot"]
		var center: Vector3 = _centers.get(id, _spawn_spot())
		var ack := 0
		var flags := 2 if client_authority else 0
		var corr := 0
		if slot >= 0 and slot < pilots.pilots.size() and pilots.pilots[slot] != null:
			var pl: Pilot = pilots.pilots[slot]
			center = pl.position()
			ack = pl.input.seq
			if pl.net_allow:
				flags |= 1
			corr = pl.net_corrections
		_centers[id] = center
		_snap_flags = flags
		_snap_corr = corr
		Network.send_snapshot(id, build_snapshot(center, ack))


## The agents around `center` (contact grid cells within interest_radius), packed.
func build_snapshot(center: Vector3, ack := 0) -> PackedByteArray:
	var am := alifemanager
	var n_species := am.species_array.size()
	var lists: Array = []                      # per species: Array of local indices
	for k in n_species:
		lists.append([])
	var total := 0

	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var offs: PackedInt32Array = am.global_species_offset
	var ws := WorldWrap.size
	var wx := WorldWrap.mask.x > 0.0
	var wz := WorldWrap.mask.z > 0.0
	var r2 := interest_radius * interest_radius
	var cx := clampi(int(center.x / cs.x), 0, W - 1)
	var cz := clampi(int(center.z / cs.z), 0, D - 1)
	var rx := ceili(interest_radius / cs.x)
	var rz := ceili(interest_radius / cs.z)
	if wx: rx = mini(rx, (W - 1) / 2)
	if wz: rz = mini(rz, (D - 1) / 2)

	# Rings from the center out, so the cap keeps the closest agents
	for ring in maxi(rx, rz) + 1:
		for dz in range(-mini(ring, rz), mini(ring, rz) + 1):
			for dx in range(-mini(ring, rx), mini(ring, rx) + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var x := cx + dx
				var z := cz + dz
				if wx: x = posmod(x, W)
				elif x < 0 or x >= W: continue
				if wz: z = posmod(z, D)
				elif z < 0 or z >= D: continue
				for y in H:
					var cell := x + W * (y + H * z)
					for k in range(cell_start[cell], cell_start[cell + 1]):
						var j: int = cell_items[k]
						if active[j] == 0:
							continue
						var d: Vector3 = sorted_pos[k] - center
						if wx: d.x -= ws.x * roundf(d.x / ws.x)
						if wz: d.z -= ws.z * roundf(d.z / ws.z)
						if d.x * d.x + d.z * d.z > r2:
							continue
						var s := offs.bsearch(j, false) - 1
						lists[s].append(j - offs[s])
						total += 1
						if total >= max_agents_per_snapshot:
							return _pack(lists, total, ack)
	return _pack(lists, total, ack)


func _pack(lists: Array, total: int, ack := 0) -> PackedByteArray:
	var am := alifemanager
	var blocks := 0
	for l in lists:
		if l.size() > 0:
			blocks += 1
	var raw := PackedByteArray()
	raw.resize(HEADER_BYTES + blocks * 3 + total * AGENT_BYTES)
	raw.encode_u32(0, _snap_seq)
	raw.encode_float(4, _now())
	raw.encode_u16(8, blocks)
	raw.encode_u16(10, 0)
	raw.encode_u32(12, ack)
	raw.encode_u8(16, _snap_flags)
	raw.encode_u8(17, 0)
	raw.encode_u16(18, _snap_corr & 0xFFFF)
	var ws := WorldWrap.size
	var q := Vector3(65535.0 / maxf(ws.x, 0.001), 65535.0 / maxf(ws.y, 0.001),
			65535.0 / maxf(ws.z, 0.001))
	var o := HEADER_BYTES
	for s in lists.size():
		var l: Array = lists[s]
		if l.is_empty():
			continue
		var sp = am.species_array[s]
		raw.encode_u8(o, s)
		raw.encode_u16(o + 1, l.size())
		o += 3
		for i in l:
			var p: Vector3 = sp.position_array[i]
			raw.encode_u32(o, i)
			raw.encode_u16(o + 4, clampi(roundi(p.x * q.x), 0, 65535))
			raw.encode_u16(o + 6, clampi(roundi(p.z * q.z), 0, 65535))
			raw.encode_u16(o + 8, clampi(roundi(p.y * q.y), 0, 65535))
			raw.encode_u8(o + 10, clampi(roundi(sp.current_size[i] * 10.0), 0, 255))
			raw.encode_u8(o + 11, clampi(sp.current_life_state[i], 0, 255))
			raw.encode_u8(o + 12, (sp.active_alife_array[i] & 7) | (int(sp.alive_array[i] != 0) << 3))
			raw.encode_u16(o + 13, sp.color_packed[i] & 0xFFFF)
			o += AGENT_BYTES
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return out


# --- Snapshots: client -------------------------------------------------------------------------

## The host's world replaces ours: remove every local agent.
func _clear_local_world() -> void:
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			if sp.active_alife_array[i] != 0:
				sp.holding[i] = -1
				sp.held_by[i] = -1
				sp.Remove_Life(i)
	_maps.clear()
	_last_seq = -1
	_flush()


func client_snapshot(bytes: PackedByteArray) -> void:
	if bytes.size() < 4:
		return
	var raw := bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	if raw.size() < HEADER_BYTES:
		return
	var seq := raw.decode_u32(0)
	if seq <= _last_seq:
		return                                # older than what we have
	_last_seq = seq
	var now := _now()
	if _arrival > 0.0:
		_interval = lerpf(_interval, clampf(now - _arrival, 0.02, 0.5), 0.2)
	var t := _blend()
	_arrival = now

	var am := alifemanager
	var n_species := am.species_array.size()
	while _maps.size() < n_species:
		_maps.append({})
	# Every mirrored agent starts its next move from where it is drawn now (no jump)
	for s in n_species:
		for e in _maps[s].values():
			e["prev"] = _lerp_wrap(e["prev"], e["next"], t)

	var ws := WorldWrap.size
	var q := Vector3(ws.x / 65535.0, ws.y / 65535.0, ws.z / 65535.0)
	var blocks := raw.decode_u16(8)
	var o := HEADER_BYTES
	for b in blocks:
		var s := raw.decode_u8(o)
		var n := raw.decode_u16(o + 1)
		o += 3
		if s >= n_species:
			o += n * AGENT_BYTES
			continue
		var sp = am.species_array[s]
		var map: Dictionary = _maps[s]
		for k in n:
			var hi := raw.decode_u32(o)
			var p := Vector3(raw.decode_u16(o + 4) * q.x, raw.decode_u16(o + 8) * q.y,
					raw.decode_u16(o + 6) * q.z)
			var size := raw.decode_u8(o + 10) / 10.0
			var life := raw.decode_u8(o + 11)
			var st := raw.decode_u8(o + 12)
			var col := raw.decode_u16(o + 13)
			o += AGENT_BYTES

			var e = map.get(hi)
			if e != null and sp.active_alife_array[e["l"]] == 0:
				e = null                      # its mirror was removed meanwhile
			if e == null:
				var nl := _spawn_mirror(sp, p, life)
				if nl < 0:
					continue                  # our world is full
				e = {"l": nl, "prev": p, "next": p, "seen": seq}
				map[hi] = e
			else:
				e["next"] = _near(p, e["prev"])   # through the border if shorter
			e["seen"] = seq
			var l: int = e["l"]
			sp.current_size[l] = size
			sp.current_life_state[l] = life
			sp.alive_array[l] = 1 if st & 8 != 0 else 0
			sp.active_alife_array[l] = maxi(st & 7, 1)
			sp.color_packed[l] = col

		# Not in this snapshot: died, or out of our area
		for hi in map.keys():
			var e: Dictionary = map[hi]
			if e["seen"] != seq:
				if sp.active_alife_array[e["l"]] != 0:
					sp.Remove_Life(e["l"])
				map.erase(hi)

	# Species with no block at all this time: everything of theirs is gone
	for s in n_species:
		var sp = am.species_array[s]
		var map: Dictionary = _maps[s]
		for hi in map.keys():
			var e: Dictionary = map[hi]
			if e["seen"] != seq:
				if sp.active_alife_array[e["l"]] != 0:
					sp.Remove_Life(e["l"])
				map.erase(hi)

	_follow_own()
	_client_authority_state(raw.decode_u8(16), raw.decode_u16(18))
	if not _authority_on:
		_reconcile(raw.decode_u32(12))        # host moves us: prediction + correction


## A local agent to mirror a host agent. Returns its local index, -1 if the world is full.
func _spawn_mirror(sp, p: Vector3, life: int) -> int:
	var i: int = sp.free_indices[sp.free_indices.size() - 1] if sp.free_indices.size() > 0 \
			else sp.entity_count
	var before: int = sp.active_entity_count
	sp.Build_New_Life(p, sp.seed_energy, life)
	return i if sp.active_entity_count > before else -1


## The camera follows our agent's mirror (once it is in a snapshot).
func _follow_own() -> void:
	if controller == null or _own_species < 0 or _own_species >= _maps.size():
		return
	var e = _maps[_own_species].get(_own_index)
	if e == null:
		return
	controller.start_remote_view(alifemanager.species_array[_own_species], e["l"])


## 0..1: how far we are between the previous snapshot and the last one.
func _blend() -> float:
	return clampf((_now() - _arrival) / maxf(_interval, 0.001), 0.0, 1.0)


## The copy of p closest to ref on the world's wrapped axes (logic wrap, not the view).
func _near(p: Vector3, ref: Vector3) -> Vector3:
	var d := p - ref
	var ws := WorldWrap.size
	if WorldWrap.mask.x > 0.0: d.x -= ws.x * roundf(d.x / ws.x)
	if WorldWrap.mask.y > 0.0: d.y -= ws.y * roundf(d.y / ws.y)
	if WorldWrap.mask.z > 0.0: d.z -= ws.z * roundf(d.z / ws.z)
	return ref + d


func _lerp_wrap(a: Vector3, b: Vector3, t: float) -> Vector3:
	return WorldWrap.wrap_into(a.lerp(b, t))


## Every frame: mirrored agents move smoothly from their previous to their last position,
## then the usual end-of-tick work (offsets, contact grid) and rendering.
func _client_interpolate(delta: float) -> void:
	if _maps.is_empty():
		return
	var t := _blend()
	var inv := 1.0 / maxf(_interval, 0.001)
	var own = _own_entry() if _pred_on else null
	for s in _maps.size():
		var sp = alifemanager.species_array[s]
		for e in _maps[s].values():
			var l: int = e["l"]
			if own != null and is_same(e, own):
				# Our agent: where we predicted it, plus what's left of the last correction
				_visual_offset *= exp(-correction_rate * delta)
				sp.position_array[l] = WorldWrap.wrap_into(_pred_pos + _visual_offset)
				sp.current_velocity[l] = _pred_vel
				continue
			var a: Vector3 = e["prev"]
			var b: Vector3 = e["next"]
			sp.position_array[l] = _lerp_wrap(a, b, t)
			sp.current_velocity[l] = (b - a) * inv   # facing / animation
	_flush()


## Offsets, contact grid and the renderer, as the simulation does after a tick.
func _flush() -> void:
	for sp in alifemanager.species_array:
		sp.set_chunk(0)                       # no spawn / remove left from an old tick
	alifemanager.update_alife()
	if sim_manager != null and sim_manager.render_manager != null:
		sim_manager.render_manager.run_visualisation()


# --- Prediction of our own agent (client) ------------------------------------------------------

## Our agent's mirror entry ({"l": local index, ...}), or null.
func _own_entry():
	if _own_species < 0 or _own_species >= _maps.size():
		return null
	return _maps[_own_species].get(_own_index)


## Moves our agent NOW with this frame's input, the way the host will: the species'
## control_velocity (speed, sprint, dash, jump) and its height grid (walls, floors, ceilings).
func _predict(inp: PlayerInput, delta: float) -> void:
	var e = _own_entry() if predict_own_agent else null
	if e == null:
		_pred_on = false
		return
	var sp = alifemanager.species_array[_own_species]
	var l: int = e["l"]
	if sp.active_alife_array[l] != AlifeManager.ACTIVE \
			or (_authority_on and not _host_lets_drive):
		_pred_on = false                      # carried / thrown / a host-driven move: follow
		return
	if not _pred_on or _pred == null or _pred.species != sp or _pred.index != l:
		_pred = Pilot.new()                   # start predicting from the host's position
		_pred.species = sp
		_pred.index = l
		_pred_pos = e["next"]
		_pred_floor = _pred_pos.y
		_pred_vel = Vector3.ZERO
		_visual_offset = Vector3.ZERO
		_hist_seq.clear()
		_hist_pos.clear()
		_pred_on = true

	var pl := _pred
	pl.input = inp
	var mask: int = sp.control_actions
	# Same timers and presses as PilotSystem._apply (only what changes the movement)
	pl.dash_cd = maxf(pl.dash_cd - delta, 0.0)
	pl.dash_left = maxf(pl.dash_left - delta, 0.0)
	pl.jump_buffer = maxf(pl.jump_buffer - delta, 0.0)
	if inp.pressed & PlayerInput.JUMP & mask != 0:
		pl.jump_buffer = pilots.jump_buffer_time
	if inp.pressed & PlayerInput.DASH & mask != 0 and pl.dash_cd <= 0.0:
		pl.dash_cd = sp.dash_cooldown
		pl.dash_left = sp.dash_time
	var f := Vector3(inp.move.x, 0.0, inp.move.y)
	if f.length_squared() > 1e-6:
		pl.facing = f.normalized()

	# Same steps as the species tick for a controlled agent
	var hg: HeightGrid = sp.height_grid if "height_grid" in sp else null
	var p := _pred_pos
	var fl = _pred_floor if hg != null else sp.ground_y
	var v: Vector3 = sp.control_velocity(pl, l, p, fl, delta)
	var q := p + v * delta
	q = WorldWrap.wrap_into(q)
	var ws := WorldWrap.size
	if WorldWrap.mask.x == 0.0: q.x = clampf(q.x, 0.0, ws.x)
	if WorldWrap.mask.z == 0.0: q.z = clampf(q.z, 0.0, ws.z)
	if hg != null:
		var r := hg.move(p, q, fl)
		q.x = r.x
		q.z = r.z
		fl = maxf(r.y, hg.solid_top_under(q.x, q.z, p.y))
	if q.y < fl:
		q.y = fl
		pl.vy = maxf(pl.vy, 0.0)
	if hg != null:
		var ceil_y := hg.ceiling_at(q.x, q.z, maxf(fl, p.y))
		if q.y > ceil_y and ceil_y >= fl:
			q.y = maxf(ceil_y, fl)
			pl.vy = minf(pl.vy, 0.0)
	_pred_vel = v
	_pred_pos = q
	_pred_floor = fl

	# Remember where this input put us, to compare with the host later
	_hist_seq.append(inp.seq)
	_hist_pos.append(q)
	if _hist_seq.size() > HISTORY:
		_hist_seq = _hist_seq.slice(_hist_seq.size() - HISTORY)
		_hist_pos = _hist_pos.slice(_hist_pos.size() - HISTORY)


## A snapshot arrived: the host had applied our inputs up to `ack`. Where it put our agent
## vs where WE had it after that same input = our prediction error. The prediction is
## fixed at once (and the later history with it); the screen catches up smoothly.
func _reconcile(ack: int) -> void:
	if not _pred_on or ack <= 0:
		return
	var e = _own_entry()
	if e == null:
		return
	var k := _hist_seq.find(ack)
	if k < 0:
		return                                # too old (or not sent yet): skip
	var host_p: Vector3 = e["next"]
	var err := _near(host_p, _hist_pos[k]) - _hist_pos[k]
	# Forget what the host has confirmed
	_hist_seq = _hist_seq.slice(k + 1)
	_hist_pos = _hist_pos.slice(k + 1)
	if err.length_squared() < 1e-6:
		return
	for j in _hist_pos.size():
		_hist_pos[j] += err                   # the later predictions move with the fix
	_pred_pos = WorldWrap.wrap_into(_pred_pos + err)
	_pred_floor += err.y
	if err.length() > snap_distance:
		_visual_offset = Vector3.ZERO         # too far: jump there
	else:
		_visual_offset -= err                 # drawn where it was, then slides to the fix


# --- Client authority ---------------------------------------------------------------------------

## Host: for each player allowed to drive (client_authority, its agent in the world, and its
## species agrees), take the position its client sent if it is plausible:
##   - not farther than its species' top speed (sprint / dash) allows since the last one
##   - the height grid lets it go there (no walking through walls, onto nothing...)
## Refused: the agent stays where it is, and the client is told to snap back (corrections).
## While a player drives, the species doesn't move its agent (Pilot.client_driven).
func _host_apply_client_moves() -> void:
	var now := _now()
	for id in Network.players:
		if id == 1:
			continue
		var slot: int = Network.players[id]["slot"]
		if slot < 0 or slot >= pilots.pilots.size() or pilots.pilots[slot] == null:
			continue
		var pl: Pilot = pilots.pilots[slot]
		var sp = pl.species
		var i := pl.index
		var drive: bool = client_authority and sp.active_alife_array[i] == AlifeManager.ACTIVE \
				and (not sp.has_method("client_can_drive") or sp.client_can_drive(i))
		if not drive:
			pl.net_allow = false              # carried, thrown, a special move: host drives
			pl.client_driven = false
			pl.net_has_pos = false
			pl.net_time = now
			continue
		pl.net_allow = true                   # the client may drive (told in each snapshot)
		if not pl.net_has_pos:
			# No position lately (prediction off, old build, lag): the host moves it from
			# the inputs meanwhile, so it never freezes
			if pl.client_driven and now - pl.net_time > position_timeout:
				pl.client_driven = false
			continue
		pl.net_has_pos = false
		var elapsed := clampf(now - pl.net_time, 0.0, 0.5) if pl.net_time > 0.0 else 0.1
		pl.net_time = now

		var cur: Vector3 = sp.position_array[i]
		var d := _near(pl.net_pos, cur) - cur
		var top: float = sp.control_speed * maxf(sp.sprint_multiplier, sp.dash_multiplier)
		var allowed := top * elapsed * 1.5 + move_tolerance
		var ok := Vector2(d.x, d.z).length() <= allowed
		var why := "" if ok else "too fast: moved %.2f, allowed %.2f in %.3f s" % [
				Vector2(d.x, d.z).length(), allowed, elapsed]
		var target := cur + d
		var hg: HeightGrid = sp.height_grid if "height_grid" in sp else null
		var fl: float = target.y
		if ok and hg != null:
			var cur_fl: float = sp.floor_y[i] if "floor_y" in sp and i < sp.floor_y.size() else cur.y
			var r := hg.move(cur, target, cur_fl)
			var off := Vector2(r.x - target.x, r.z - target.z).length()
			if off > wall_tolerance:
				ok = false                    # the path goes through a wall
				why = "blocked by the height grid: ends %.2f away from the claimed spot" % off
			fl = r.y
		if not ok:
			pl.net_corrections += 1           # not plausible: the client snaps back
			if debug_refusals and now >= _refusal_print:
				_refusal_print = now + 1.0
				print("NetSession: refused peer %d position (%s) %s -> %s" % [
						id, why, cur, pl.net_pos])
			continue
		pl.client_driven = true               # positions arrive: the species leaves it to them
		target.y = maxf(target.y, fl)         # never under its floor
		sp.position_array[i] = WorldWrap.wrap_into(target)
		if "floor_y" in sp and i < sp.floor_y.size():
			sp.floor_y[i] = fl
		sp.current_velocity[i] = d / maxf(elapsed, 0.016)   # facing / animation for everyone


## Client: what the host says about our agent, read from each snapshot.
func _client_authority_state(flags: int, corrections: int) -> void:
	var was_driving := _host_lets_drive
	_authority_on = flags & 2 != 0
	_host_lets_drive = _authority_on and flags & 1 != 0
	if _host_lets_drive and not was_driving:
		_pred_on = false                      # we drive again: restart from the host's position
	if _last_corr >= 0 and corrections != _last_corr and _pred_on:
		var e = _own_entry()                  # the host refused our position: snap back to it
		if e != null:
			_pred_pos = e["next"]
			_pred_floor = _pred_pos.y
			_visual_offset = Vector3.ZERO
			_hist_seq.clear()
			_hist_pos.clear()
	_last_corr = corrections
	if Network.is_client() and controller != null and controller.remote_slot >= 0:
		var mode := "host moves you (prediction)"
		if _authority_on:
			mode = "you move your agent" if _host_lets_drive else "host moves you (carried / special move)"
		_set_status("Playing   ·   %s   ·   corrections %d" % [mode, corrections])
