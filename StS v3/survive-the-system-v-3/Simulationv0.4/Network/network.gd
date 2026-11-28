extends Node
## AUTOLOAD "Network" (Project Settings > Globals > Autoload: net/network.gd, name Network).
## No class_name: the autoload name is the global (like DialogueBox).
##
## Connection only, with Godot's own ENet peer: host / join / leave, the player list,
## and the messages (RPCs). What the game does with them is in NetSession, the node in your
## game scene (it registers itself here). RPCs live on this autoload because it has the
## same path (/root/Network) on every machine, which Godot's RPCs need.
##
## Host = peer 1 = the authority: it runs the simulation. Clients send their inputs.

signal hosted                                 # we are now the host
signal joined                                 # connected to a host (handshake done)
signal join_failed(reason: String)
signal left                                   # disconnected (or stopped hosting)
signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8
const CHANNELS := 2                           # 0: reliable messages + inputs, 1: snapshots
const PROTOCOL := 6                           # bump when messages change: old clients are refused

## peer_id -> {"name": String, "slot": int (pilot slot on the host, -1 = none)}
var players := {}
var player_name := "Player"
var session = null                            # NetSession of the current scene (or null)
var _pending: Array[int] = []                 # host: players waiting for our scene to be ready


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	# _pending is cleared in leave()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Status --------------------------------------------------------------------------------

func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() \
			and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


# --- Host / join / leave ---------------------------------------------------------------------

func host(port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS, CHANNELS)
	if err != OK:
		push_warning("Network: can't host on port %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: {"name": player_name, "slot": -1}}
	print("Network: hosting on port %d" % port)
	hosted.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, CHANNELS)
	if err != OK:
		join_failed.emit("can't connect (%s)" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	print("Network: connecting to %s:%d..." % [address, port])
	return OK


func leave() -> void:
	if not is_online():
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_pending.clear()
	left.emit()


# --- Connection events ---------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if is_host():
		print("Network: peer %d connected, waiting for its hello" % id)


func _on_peer_disconnected(id: int) -> void:
	_pending.erase(id)
	if not players.has(id):
		return
	players.erase(id)
	print("Network: peer %d left" % id)
	if is_host() and session != null:
		session.host_player_left(id)
	player_left.emit(id)


func _on_connected() -> void:
	# Connected at the ENet level: introduce ourselves, the host answers with _welcome
	_hello.rpc_id(1, PROTOCOL, player_name)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	join_failed.emit("no answer from the host")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	print("Network: the host left")
	left.emit()


# --- Messages (RPCs) ---------------------------------------------------------------------------
# Client -> host

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, pname: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_refused.rpc_id(id, "different game version (host %d, you %d)" % [PROTOCOL, protocol])
		return
	var is_new := not players.has(id)
	players[id] = {"name": pname.left(24), "slot": -1}
	if is_new:
		player_joined.emit(id, players[id]["name"])
	if not _pending.has(id):
		_pending.append(id)                   # welcomed once our scene is ready (accept_pending)


## Host, called by NetSession every frame once its world is ready: welcome the players
## who said hello (new ones, or everyone again after a scene change) and spawn their agents.
func accept_pending() -> void:
	if not is_host() or session == null:
		return
	for id in _pending:
		if not players.has(id):
			continue                          # left meanwhile
		_welcome.rpc_id(id, session.scene_path())
		session.host_player_joined(id)        # spawns its agent, then calls assign()
	_pending.clear()


## Client: introduce ourselves (again) to the host, e.g. after a scene change.
func say_hello() -> void:
	if is_client():
		_hello.rpc_id(1, PROTOCOL, player_name)


# --- Scene change ---------------------------------------------------------------------------

## Changes the scene for EVERYONE (host only; offline: just here). Clients load it too, then
## say hello again, and the host spawns their agents in the new scene.
func change_scene(path: String) -> void:
	if is_client():
		return                                # only the host decides
	if is_host():
		_change_scene.rpc(path)
		for id in players:
			players[id]["slot"] = -1          # pilots don't survive the change
	get_tree().change_scene_to_file.call_deferred(path)


@rpc("authority", "call_remote", "reliable")
func _change_scene(path: String) -> void:
	print("Network: the host changes scene to %s" % path)
	get_tree().change_scene_to_file.call_deferred(path)


## Every frame from each client: its input packet (see NetSession.pack_input).
## Unreliable: a lost one is replaced by the next; presses are counted, so none is lost.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(bytes: PackedByteArray) -> void:
	if not is_host() or session == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and players[id]["slot"] >= 0:
		session.host_receive_input(id, players[id]["slot"], bytes)   # only into ITS pilot


# Host -> client

@rpc("authority", "call_remote", "reliable")
func _welcome(host_scene: String) -> void:
	print("Network: joined (host scene %s)" % host_scene)
	if session != null:
		session.client_joined(host_scene)
	joined.emit()


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	print("Network: refused: %s" % reason)
	join_failed.emit(reason)
	leave()


## The host gave us an agent: its pilot slot, species, index and the actions it has.
@rpc("authority", "call_remote", "reliable")
func _assigned(slot: int, species_name: String, index: int, actions: int) -> void:
	if session != null:
		session.client_assigned(slot, species_name, index, actions)


## The world around our agent (see NetSession.build_snapshot). Unreliable on its own channel
## (1): a lost snapshot is simply replaced by the next one, and it never delays inputs.
@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot(bytes: PackedByteArray) -> void:
	if session != null:
		session.client_snapshot(bytes)


## Host -> one client: open a dialogue with NPC `index` of `species_name`.
## The NpcData is found by its file path, else by its display name among the NpcSpots of
## the client's scene (both machines run the same scene).
@rpc("authority", "call_remote", "reliable")
func _open_dialogue(species_name: String, index: int, data_path: String, display_name: String,
		first: bool) -> void:
	var data: NpcData = null
	if data_path != "" and not data_path.contains("::") and ResourceLoader.exists(data_path):
		data = load(data_path) as NpcData
	if data == null:
		data = _find_npc_data(get_tree().root, display_name)
	var box := get_node_or_null("/root/DialogueBox")
	if data == null or box == null:
		push_warning("Network: can't show the dialogue of %s (no NpcData / DialogueBox)" % display_name)
		_dialogue_closed.rpc_id(1, species_name, index)
		return
	box.start(data, first, func(): _dialogue_closed.rpc_id(1, species_name, index))


## Client -> host: the dialogue is closed, the NPC can walk again.
@rpc("any_peer", "call_remote", "reliable")
func _dialogue_closed(species_name: String, index: int) -> void:
	if not is_host() or session == null:
		return
	var sp = session.alifemanager.codex.species.get(species_name)
	if sp != null and sp.has_method("remote_dialogue_closed"):
		sp.remote_dialogue_closed(index, multiplayer.get_remote_sender_id())


## Host -> client: close the dialogue on screen (walked away, the NPC was carried off...).
@rpc("authority", "call_remote", "reliable")
func _close_dialogue() -> void:
	var box := get_node_or_null("/root/DialogueBox")
	if box != null and box.is_open:
		box.close()                           # its callback tells the host, which ignores it


func _find_npc_data(n: Node, display_name: String) -> NpcData:
	if "npc_data" in n and n.npc_data is NpcData and n.npc_data.display_name == display_name:
		return n.npc_data
	for c in n.get_children():
		var d := _find_npc_data(c, display_name)
		if d != null:
			return d
	return null


# --- Called by NetSession ---------------------------------------------------------------------

## Host: tells a client which pilot is its own (slot -1 = none, e.g. it died).
func assign(peer_id: int, slot: int, species_name := "", index := -1, actions := 0) -> void:
	if players.has(peer_id):
		players[peer_id]["slot"] = slot
	if peer_id == my_id():
		return                                # the host's own player plays locally
	_assigned.rpc_id(peer_id, slot, species_name, index, actions)


## Host: an NPC talks to a remote player (called by ALIFE_NPC.Interact).
func open_remote_dialogue(peer_id: int, species_name: String, index: int, data: NpcData,
		first: bool) -> void:
	if is_host():
		_open_dialogue.rpc_id(peer_id, species_name, index, data.resource_path,
				data.display_name, first)


## Host: ends the dialogue on a remote player's screen.
func close_remote_dialogue(peer_id: int) -> void:
	if is_host():
		_close_dialogue.rpc_id(peer_id)


## Host: sends a snapshot to one client.
func send_snapshot(peer_id: int, bytes: PackedByteArray) -> void:
	if is_host() and peer_id != 1:
		_snapshot.rpc_id(peer_id, bytes)


## Client: sends one input packet to the host.
func send_input(bytes: PackedByteArray) -> void:
	if is_client():
		_net_input.rpc_id(1, bytes)
