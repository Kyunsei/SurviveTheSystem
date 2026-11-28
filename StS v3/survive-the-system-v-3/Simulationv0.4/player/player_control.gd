class_name PlayerController
extends Node
## The LOCAL player: keys -> PlayerInput, plus camera, views and HUD. It never moves an
## agent itself: it owns one Pilot in the PilotSystem, which does the actions, and the
## species does the movement. So each species reacts its own way to the same keys
## (speed, jump or not, which actions it has), and the same code works online.
##
## All keys are Input Map actions (remappable in the Controls menu). Default keys in ():
##
## agent_control (C): handled by AgentPicker (take the hovered / followed agent | again: release)
## In control:
##   up / down / left / right (WASD or left stick)  move the agent (analog on a stick)
##   sprint (Shift)   run            jump (Space)    jump
##   dash             short burst of speed (in the direction you move, else forward)
##   pick_up          pick up the outlined agent (the closest one in range)
##   Action           interact with the outlined agent (talk to an NPC, shake a tree...)
##   use              near a machine: feed it what you carry, or start / stop it
##   Drop / eat       drop / eat what you carry (hold eat)
##   throw (hold)     charge a throw, release to launch what you carry
##   attack           hit every agent in a box in front of you
##   view_north (1) / view_camera (2) / view_first_person (3)   views
##   free_cursor (Esc) (modes 2 / 3) give the cursor back (handled by FlyCamera)
## A species only reacts to the actions in its `control_actions`; only those are hinted.
##
## Settings that depend on WHAT you control (speed, jump, dash, attack box...) are in each
## species (ALIFE: control_speed, can_jump, attack_width...). Settings of the actions
## (throw, eat, target range) are on the PilotSystem node.
## First person needs `uniform int hidden_id = -1;` in the sprite shader.

signal control_started(species, index: int)
signal control_ended(species, index: int)
signal agent_picked_up(species, index: int, item_species, item_index: int)
signal agent_dropped(species, index: int, item_species, item_index: int)
signal agent_thrown(species, index: int, item_species, item_index: int, speed: float)
signal item_landed(item_species, item_index: int, position: Vector3)
## hits: Array of [species, local_index] that were inside the box
signal agent_attacked(species, index: int, hits: Array)
signal agent_dashed(species, index: int)

@export var alifemanager: AlifeManager
@export var camera: FlyCamera
@export var picker: AgentPicker              # hover / follow / ids (optional: without it,
											 # take control with spawn_and_control)
## Optional: empty = AlifeManager's child "Pilots" (created if missing).
@export var pilots: PilotSystem

@export_group("Control")
@export var energy_bar_size := Vector2(36, 5)
@export var arrow_color := Color(1.0, 1.0, 1.0, 0.75)
@export var arrow_scale := 1.0               # relative to the agent's width
@export var eye_ratio := 0.8                 # first person: eye height / sprite height
## Camera smoothing while controlling (higher = sticks tighter to the agent).
## The camera's own follow_smoothing is used again when control ends.
@export var control_camera_smoothing := 30.0
@export var ground_y := 0.0                  # height of spawn_and_control

@export_group("Planet")
## Little-planet look while controlling an agent: the world is drawn bent down with
## distance. Smaller = rounder planet. 0 = flat. Drop at distance d = d² / (2 × radius).
@export var planet_radius := 60.0
## Off: no little-planet bend at all, the world stays flat while controlling.
@export var planet_view := true

@export_group("Key hints")
@export var show_key_hints := true           # row of key buttons under the status line
@export var hint_font_size := 12

@export_group("Attack box (debug)")
@export var show_hitbox := true              # draw the box when attacking
@export var hitbox_show_time := 0.25         # seconds the debug box stays visible

enum ControlView { NORTH, CAMERA, FIRST_PERSON }
@export var control_view := ControlView.NORTH

## The pilot this player plays (null = not controlling).
var pilot: Pilot = null

# Read-only views of the pilot, for the picker / UI (same names as before)
var controlled_species:
	get:
		return pilot.species if pilot != null else remote_species
var controlled_index: int:
	get:
		return pilot.index if pilot != null else remote_index
var target_species:
	get:
		return pilot.target_species if pilot != null else null
var target_index: int:
	get:
		return pilot.target_index if pilot != null else -1
var target_machine:
	get:
		return pilot.target_machine if pilot != null else null
var held_species:
	get:
		return _held()[0]
var held_index: int:
	get:
		return _held()[1]

var _pressed := 0                            # buttons pressed since the last input sent
## Network client: the slot of our pilot ON THE HOST (-1 = none). Set by NetSession, which
## sends our inputs there every frame. There is no local pilot on a client.
var remote_slot := -1
var remote_actions := PlayerInput.ALL        # control_actions of the agent we play on the host
## Network client: our agent's MIRROR here (drawn from the host's snapshots), followed by
## the camera. null until it appears in a snapshot.
var remote_species = null
var remote_index := -1
var _seq := 0
var _highlighted_machine = null
var _eat_circle := Control.new()
var _hitbox := MeshInstance3D.new()
var _hitbox_time := 0.0
var _hitbox_seen := 0                        # pilot.attack_serial already shown

var _layer := CanvasLayer.new()
var _bar_bg := ColorRect.new()
var _bar_fill := ColorRect.new()
var _arrow := MeshInstance3D.new()
var _status := Label.new()
var _hints := HBoxContainer.new()
var _hints_sig := ""                         # current content, to rebuild only on change
var _controls_button := Button.new()
var _controls_menu: SettingsRemapMenu


func _ready() -> void:
	process_priority = 20                        # after the simulation and the camera: the arrow,
												 # energy bar... use this frame's positions
	_layer.layer = 90
	add_child(_layer)
	_build_energy_bar()
	_build_arrow()
	_build_status()
	_build_hitbox()
	_build_hints()
	_build_eat_circle()
	_build_controls_button()
	if pilots == null and alifemanager != null:
		pilots = PilotSystem.ensure(alifemanager)
	_connect_pilot_signals()


## Re-sends the PilotSystem's events about OUR pilot as this node's signals (as before).
func _connect_pilot_signals() -> void:
	if pilots == null:
		return
	pilots.pilot_removed.connect(_on_pilot_removed)
	pilots.picked_up.connect(_on_picked_up)
	pilots.dropped.connect(_on_dropped)
	pilots.thrown.connect(_on_thrown)
	pilots.item_landed.connect(_on_item_landed)
	pilots.attacked.connect(_on_attacked)
	pilots.dashed.connect(_on_dashed)


func _on_pilot_removed(pl: Pilot) -> void:
	if pl == pilot:
		_end_control()                           # released, or the agent died


func _on_picked_up(pl: Pilot, isp, j: int) -> void:
	if pl == pilot:
		agent_picked_up.emit(pl.species, pl.index, isp, j)


func _on_dropped(pl: Pilot, isp, j: int) -> void:
	if pl == pilot:
		agent_dropped.emit(pl.species, pl.index, isp, j)


func _on_thrown(pl: Pilot, isp, j: int, speed: float) -> void:
	if pl == pilot:
		agent_thrown.emit(pl.species, pl.index, isp, j, speed)


func _on_item_landed(isp, j: int, pos: Vector3) -> void:
	item_landed.emit(isp, j, pos)


func _on_attacked(pl: Pilot, hits: Array) -> void:
	if pl == pilot:
		agent_attacked.emit(pl.species, pl.index, hits)


func _on_dashed(pl: Pilot) -> void:
	if pl == pilot:
		agent_dashed.emit(pl.species, pl.index)


# --- Public ----------------------------------------------------------------------

## We play an agent we can see (here, or our mirrored agent on a network client).
func is_controlling() -> bool:
	return pilot != null or remote_species != null


## We play an agent: here (pilot), or on the host (network client).
func has_control() -> bool:
	return pilot != null or remote_slot >= 0


## Network client: we only send inputs; the host owns every agent.
func is_net_client() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.is_server()


## Buttons the agent we play reacts to.
func _control_actions() -> int:
	return pilot.species.control_actions if pilot != null else remote_actions


## True when the current view wants the mouse to turn the camera (modes 2 and 3).
func wants_mouse_look() -> bool:
	return is_controlling() and control_view != ControlView.NORTH


## [species, local index] of what the controlled agent carries, or [null, -1].
func _held() -> Array:
	if pilot == null or pilots == null:
		return [null, -1]
	return pilots.held_item(pilot)


## This player's network id (1 = solo / host).
func _local_peer() -> int:
	return multiplayer.get_unique_id()


# --- Action helpers ----------------------------------------------------------------

## Pressed this event: the Input Map action if it exists, else one of the fallback keys.
func _act_pressed(event: InputEvent, action: String, fallback_keys: Array = []) -> bool:
	if InputMap.has_action(action):
		return event.is_action_pressed(action)
	return event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in fallback_keys


## Name of the key bound to an action, for the hints / status line.
## Keyboard/mouse binding first, else the controller one.
func _key(action: String, fallback := "") -> String:
	if not InputMap.has_action(action):
		return fallback
	var e := ConfigurationSettings.get_event(action, ConfigurationSettings.Slot.KEYBOARD_MOUSE)
	if e == null:
		e = ConfigurationSettings.get_event(action, ConfigurationSettings.Slot.CONTROLLER)
	return ConfigurationSettings.event_to_text(e)


# --- Input -----------------------------------------------------------------------

## True while the DialogueBox autoload shows a conversation.
func _dialogue_open() -> bool:
	var box := get_node_or_null("/root/DialogueBox")
	return box != null and box.is_open


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("controls_open"):
		toggle_controls()
		get_viewport().set_input_as_handled()
		return
	if _dialogue_open() or not has_control():
		return                                   # talking / nothing controlled: no actions

	# Views: one at a time
	if _act_pressed(event, "view_north", [KEY_1, KEY_KP_1]):
		set_control_view(ControlView.NORTH)
		get_viewport().set_input_as_handled()
		return
	elif _act_pressed(event, "view_camera", [KEY_2, KEY_KP_2]):
		set_control_view(ControlView.CAMERA)
		get_viewport().set_input_as_handled()
		return
	elif _act_pressed(event, "view_first_person", [KEY_3, KEY_KP_3]):
		set_control_view(ControlView.FIRST_PERSON)
		get_viewport().set_input_as_handled()
		return

	# Every action is checked on its own: several actions bound to the same key all go
	# out on one press. Only the buttons the species has are taken (and the key consumed).
	var mask := _control_actions() | PlayerInput.JUMP   # jump always: struggling when carried
	var did := false
	for b in PlayerInput.ACTIONS:
		var action: String = PlayerInput.ACTIONS[b]
		if mask & b != 0 and InputMap.has_action(action) and event.is_action_pressed(action):
			_pressed |= b
			did = true
	if did:
		get_viewport().set_input_as_handled()


## Called by our Pilot every frame (pilot.poll): the keys right now, as a PlayerInput.
## Movement is turned into WORLD space here, from the view, so species never see cameras.
func _build_input() -> PlayerInput:
	var inp := PlayerInput.new()
	_seq += 1
	inp.seq = _seq
	if _dialogue_open() or not has_control():
		_pressed = 0
		return inp                               # talking: stand still, no actions

	# Movement: x = right, y = forward. Analog on a stick, deadzone from the Input Map.
	var stick := Input.get_vector("left", "right", "down", "up")
	var dir := Vector3.ZERO
	if control_view == ControlView.NORTH:
		dir = Vector3(stick.x, 0.0, -stick.y)        # up = north (-Z), right = east (+X)
	else:
		# Modes 2 and 3: relative to where the camera looks, flattened on the ground
		var b := camera.global_transform.basis
		var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
		dir = right * stick.x + fwd * stick.y
		inp.aim = Vector2(fwd.x, fwd.z)              # attacks / throws go where you look
	dir = dir.limit_length(1.0)                      # half-pushed stick = half speed
	inp.move = Vector2(dir.x, dir.z)

	for b in PlayerInput.ACTIONS:
		var action: String = PlayerInput.ACTIONS[b]
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			inp.held |= b
	inp.pressed = _pressed
	_pressed = 0
	return inp


# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_planet()
	_update_hitbox(delta)
	_update_hints()
	_update_wrap_view()
	if is_controlling():
		# Eye height follows the agent's size (it may grow)
		var sp = controlled_species
		var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
		camera.first_person_eye_height = q.y * sp.current_size[controlled_index] * eye_ratio
	_update_machine_highlight()
	_update_energy_bar()
	_update_eat_circle()                         # after the bar: it sits just above it
	_update_arrow()
	_update_status()
	if picker == null:
		_update_outline()                        # no picker: the controller outlines itself


# --- Control ---------------------------------------------------------------------

## Starts playing agent i of species sp. Nothing happens if someone already plays it.
func take_control(sp, i: int) -> void:
	if is_net_client():
		push_warning("Network client: the host gives you your agent (no local control)")
		return
	if pilots == null:
		push_error("PlayerController: no PilotSystem (set alifemanager)")
		return
	release_control()
	var pl := pilots.add_pilot(sp, i, _local_peer())
	if pl == null:
		push_warning("%s #%d can't be controlled (already played, or gone)" % [sp.species_name, i])
		return
	pilot = pl
	pl.poll = _build_input
	_hitbox_seen = pl.attack_serial

	camera.move_keys_enabled = false                 # movement keys move the agent, not the camera
	_follow_agent(sp, i)
	if _saved_smoothing < 0.0:
		_saved_smoothing = camera.follow_smoothing
	camera.follow_smoothing = control_camera_smoothing
	set_control_view(control_view)
	control_started.emit(sp, i)


## Stops playing (drops what it carries). Also called when the agent dies.
func release_control() -> void:
	if pilot != null and pilots != null:
		pilots.remove_pilot(pilot)                   # -> pilot_removed -> _end_control()
	_end_control()


## Network client: the camera follows our agent's mirror, in the control view.
## Called by NetSession when it appears in a snapshot (again if its local index changes).
func start_remote_view(sp, i: int) -> void:
	if remote_species == sp and remote_index == i:
		return
	var first := remote_species == null
	remote_species = sp
	remote_index = i
	camera.move_keys_enabled = false
	_follow_agent(sp, i)
	if first:
		if _saved_smoothing < 0.0:
			_saved_smoothing = camera.follow_smoothing
		camera.follow_smoothing = control_camera_smoothing
	set_control_view(control_view)
	if first:
		control_started.emit(sp, i)


## Network client: our agent is gone (died, or we left).
func end_remote_view() -> void:
	if remote_species == null:
		return
	var sp = remote_species
	var i := remote_index
	remote_species = null
	remote_index = -1
	sp.renderer3D.material_override.set_shader_parameter("hidden_id", -1)
	if _saved_smoothing >= 0.0:
		camera.follow_smoothing = _saved_smoothing
		_saved_smoothing = -1.0
	camera.move_keys_enabled = true
	camera.set_yaw_lock(false)
	camera.set_mouse_look(false)
	camera.set_first_person(false)
	camera.stop_follow()
	control_ended.emit(sp, i)


## Camera / HUD back to normal once our pilot is gone (released, or the agent died).
func _end_control() -> void:
	if pilot == null:
		return
	var sp = pilot.species
	var i := pilot.index
	pilot.poll = Callable()
	pilot = null
	_pressed = 0
	sp.renderer3D.material_override.set_shader_parameter("hidden_id", -1)
	if _saved_smoothing >= 0.0:
		camera.follow_smoothing = _saved_smoothing   # back to the normal follow
		_saved_smoothing = -1.0
	camera.move_keys_enabled = true
	camera.set_yaw_lock(false)
	camera.set_mouse_look(false)
	camera.set_first_person(false)
	control_ended.emit(sp, i)


var _saved_smoothing := -1.0                     # camera smoothing before control (-1 = none saved)

# Outline without a picker (with one, the picker owns the outline)
var _outlined_species = null
var _outlined_index := -1


## Outlines the target (closest agent in range), else the carried agent, else nothing.
func _update_outline() -> void:
	if target_species != null:
		_set_outline(target_species, target_index)
	elif held_species != null:
		_set_outline(held_species, held_index)
	else:
		_set_outline(null, -1)


func _set_outline(sp, i: int) -> void:
	if sp == _outlined_species and i == _outlined_index:
		return
	if _outlined_species != null:
		_outlined_species.renderer3D.material_override.set_shader_parameter("selected_id", -1)
	_outlined_species = sp
	_outlined_index = i
	if sp != null:
		sp.renderer3D.material_override.set_shader_parameter("selected_id", i)


## The camera follows this agent: through the picker (it also tracks what is followed),
## or directly when there is no picker.
func _follow_agent(sp, i: int) -> void:
	if picker != null:
		picker.follow(sp, i)
		return
	camera.follow(func():
		if sp.active_alife_array[i] == 0 or sp.alive_array[i] == 0:
			return null                                # gone: the camera goes back to fly mode
		return alifemanager.visual_position(sp, i))   # where it's drawn (smooth between ticks)


func set_control_view(view: ControlView) -> void:
	control_view = view
	camera.set_yaw_lock(view == ControlView.NORTH, 0.0)      # yaw 0 = facing north (-Z)
	camera.set_mouse_look(view != ControlView.NORTH)        # modes 2 and 3
	camera.set_first_person(view == ControlView.FIRST_PERSON)
	# Hide the agent's own sprite in first person, or you'd see it from inside
	if is_controlling():
		controlled_species.renderer3D.material_override.set_shader_parameter(
				"hidden_id", controlled_index if view == ControlView.FIRST_PERSON else -1)


## Little planet: on while controlling (where the endless ground is shown), flat otherwise.
## Needs the `planet_radius` Shader Global (float) in the Project Settings.
func _update_planet() -> void:
	planet_radius = WorldWrap.size.x/4
	var r_planet := sqrt( WorldWrap.size.x * WorldWrap.size.z / (4* PI))
	planet_radius = r_planet
	var r := planet_radius if (is_controlling() and planet_view) else 0.0
	if r == WorldWrap.planet_radius:
		return
	WorldWrap.planet_radius = r
	RenderingServer.global_shader_parameter_set("planet_radius", r)


## Wrap-around display: only in control modes 1 and 2.
func _update_wrap_view() -> void:
	var on := is_controlling() and control_view != ControlView.FIRST_PERSON
	if on == WorldWrap.visual:
		return
	WorldWrap.visual = on
	for sp in alifemanager.species_array:
		sp.renderer3D.set_wrap_view(on)


# --- Key hints (top of the screen, in control mode) --------------------------------

func _build_hints() -> void:
	_hints.add_theme_constant_override("separation", 6)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.visible = false
	_layer.add_child(_hints)


## The control keys of what you control now, with the keys currently bound: [key, action].
## Only the actions this species has (control_actions).
func _current_hints() -> Array:
	var mask := _control_actions()
	# "WASD" when every movement key is one letter, else "W A S D" / "Up Left Down Right"
	var move := PackedStringArray([_key("up"), _key("left"), _key("down"), _key("right")])
	var short := true
	for k in move:
		short = short and k.length() == 1
	var hints := [[("" if short else " ").join(move), "move"]]
	var add := func(b: int, action: String, label: String):
		if mask & b != 0:
			hints.append([_key(action), label])
	add.call(PlayerInput.SPRINT, "sprint", "run")
	if controlled_species.can_jump:
		add.call(PlayerInput.JUMP, "jump", "jump")
	add.call(PlayerInput.DASH, "dash", "dash")
	add.call(PlayerInput.ATTACK, "attack", "attack")
	var pick := _key("pick_up")
	var use := _key("use")
	if pick == use and mask & PlayerInput.PICK_UP != 0 and mask & PlayerInput.USE != 0:
		hints.append([pick, "pick up / use"])
	else:
		add.call(PlayerInput.PICK_UP, "pick_up", "pick up")
		add.call(PlayerInput.USE, "use", "use")
	add.call(PlayerInput.ACTION, "Action", "interact")
	add.call(PlayerInput.DROP, "Drop", "drop")
	add.call(PlayerInput.EAT, "eat", "hold to eat")
	add.call(PlayerInput.THROW, "throw", "hold to throw")
	hints.append_array([
		["%s %s %s" % [_key("view_north", "1"), _key("view_camera", "2"),
				_key("view_first_person", "3")], "view"],
		[_key("free_cursor", "Esc"), "cursor"],
		[_key("agent_control", "C"), "release"],
	])
	return hints


func _update_hints() -> void:
	if not show_key_hints or not is_controlling():
		_hints.visible = false
		return

	var hints := _current_hints()
	var sig := str(hints)
	if sig != _hints_sig:                        # rebuild only when the keys change
		_hints_sig = sig
		for c in _hints.get_children():
			c.queue_free()
		for h in hints:
			_hints.add_child(_make_chip(h[0], h[1]))
		_hints.reset_size()

	# Centered, just under the status line
	var screen := get_viewport().get_visible_rect().size
	var w := _hints.get_combined_minimum_size().x
	_hints.position = Vector2((screen.x - w) * 0.5, _status.position.y + _status.size.y + 6.0)
	_hints.visible = true


func _make_chip(key: String, action: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", hint_font_size)
	k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(k)

	var a := Label.new()
	a.text = action
	a.add_theme_font_size_override("font_size", hint_font_size)
	a.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(a)
	return chip


# --- Debug attack box (wireframe): shown when our pilot attacks ---------------------

func _build_hitbox() -> void:
	# Unit box edges: x in [-0.5, 0.5], y in [0, 1], z in [0, 1] (z = forward)
	var c := [
		Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1),
		Vector3(-0.5, 1, 0), Vector3(0.5, 1, 0), Vector3(0.5, 1, 1), Vector3(-0.5, 1, 1),
	]
	var edges := [0, 1, 1, 2, 2, 3, 3, 0,  4, 5, 5, 6, 6, 7, 7, 4,  0, 4, 1, 5, 2, 6, 3, 7]
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in edges:
		im.surface_add_vertex(c[e])
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.15)
	mat.no_depth_test = true                    # visible through grass
	_hitbox.mesh = im
	_hitbox.material_override = mat
	_hitbox.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hitbox.visible = false
	add_child(_hitbox)


func _update_hitbox(delta: float) -> void:
	if pilot != null and pilot.attack_serial != _hitbox_seen:
		_hitbox_seen = pilot.attack_serial           # a new attack: show its box
		_hitbox_time = hitbox_show_time
	if _hitbox_time <= 0.0 or not show_hitbox or pilot == null:
		_hitbox.visible = false
		_hitbox_time = 0.0
		return
	_hitbox_time -= delta
	# Drawn where the attack happened, at its copy near the view, on the planet
	var center := camera.get_wrap_center()
	var p := WorldWrap.curve(WorldWrap.nearest_image(pilot.attack_origin, center), center)
	_hitbox.global_transform = Transform3D(pilot.attack_basis, p)
	_hitbox.visible = true


# --- Machine highlight -------------------------------------------------------------

func _update_machine_highlight() -> void:
	if target_machine == _highlighted_machine:
		return
	if is_instance_valid(_highlighted_machine):
		_highlighted_machine.set_highlight(false)
	_highlighted_machine = target_machine
	if target_machine != null:
		target_machine.set_highlight(true)


# --- Facing arrow (on the ground) --------------------------------------------------

func _build_arrow() -> void:
	# Flat chevron in the XZ plane, pointing toward +Z, starting a bit ahead of the agent
	var verts := PackedVector3Array([
		Vector3(0.0, 0.0, 1.0), Vector3(-0.35, 0.0, 0.4), Vector3(0.0, 0.0, 0.55),
		Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.55), Vector3(0.35, 0.0, 0.4),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = arrow_color
	mesh.surface_set_material(0, mat)

	_arrow.mesh = mesh
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	add_child(_arrow)


func _update_arrow() -> void:
	if pilot == null:
		_arrow.visible = false
		return
	var sp = pilot.species
	var i := pilot.index
	var facing := pilot.facing                       # kept up to date by the PilotSystem
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var s := maxf(q.x * sp.current_size[i], 0.3) * arrow_scale
	var angle := atan2(facing.x, facing.z)
	var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * s)
	var center := camera.get_wrap_center()
	var p := WorldWrap.curve(WorldWrap.nearest_image(alifemanager.visual_position(sp, i), center), center)
	_arrow.global_transform = Transform3D(basis, p + Vector3(0.0, 0.03, 0.0))
	_arrow.visible = true


# --- Energy bar --------------------------------------------------------------------

func _build_energy_bar() -> void:
	_bar_bg.color = Color(0, 0, 0, 0.6)
	_bar_bg.size = energy_bar_size + Vector2(2, 2)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.visible = false
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = energy_bar_size
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar_fill)
	_layer.add_child(_bar_bg)


func _update_energy_bar() -> void:
	var sp = controlled_species
	var cam := get_viewport().get_camera_3d()
	if sp == null or cam == null:
		_bar_bg.visible = false
		return

	var i := controlled_index
	var ratio := clampf(sp.current_energy_array[i] / sp.max_energy, 0.0, 1.0)
	_bar_fill.size.x = energy_bar_size.x * ratio
	_bar_fill.color = Color.RED.lerp(Color.GREEN, ratio)

	# First person: the head is the camera, so show the bar as a HUD at the bottom
	if control_view == ControlView.FIRST_PERSON:
		var screen := get_viewport().get_visible_rect().size
		_bar_bg.position = Vector2(screen.x * 0.5 - _bar_bg.size.x * 0.5, screen.y - 40.0)
		_bar_bg.visible = true
		return

	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var size: float = sp.current_size[i]
	var center := camera.get_wrap_center()
	var foot := WorldWrap.curve(WorldWrap.nearest_image(alifemanager.visual_position(sp, i), center), center)
	var above: Vector3 = foot + Vector3(0.0, q.y * size + 0.2, 0.0)
	if cam.is_position_behind(above):
		_bar_bg.visible = false
		return
	_bar_bg.position = cam.unproject_position(above) - Vector2(_bar_bg.size.x * 0.5, _bar_bg.size.y)
	_bar_bg.visible = true


# --- Eat circle (above the energy bar, fills while eat is held) ---------------------

@export_group("Eat circle")
@export var eat_circle_radius := 8.0         # pixels
@export var eat_circle_color := Color(0.45, 1.0, 0.45, 0.95)

func _build_eat_circle() -> void:
	_eat_circle.size = Vector2.ONE * (eat_circle_radius * 2.0 + 4.0)
	_eat_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eat_circle.visible = false
	_eat_circle.draw.connect(_draw_eat_circle)
	_layer.add_child(_eat_circle)


func _update_eat_circle() -> void:
	if pilot == null or not pilot.eating or not _bar_bg.visible:
		_eat_circle.visible = false
		return
	# Centered above the energy bar
	var above_bar := _bar_bg.position + Vector2(_bar_bg.size.x * 0.5, -eat_circle_radius - 6.0)
	_eat_circle.position = above_bar - _eat_circle.size * 0.5
	_eat_circle.visible = true
	_eat_circle.queue_redraw()


func _draw_eat_circle() -> void:
	var c := _eat_circle.size * 0.5
	var r := eat_circle_radius
	_eat_circle.draw_circle(c, r, Color(0, 0, 0, 0.55))           # background

	# Pie filling clockwise from the top
	var p := clampf(pilot.eat_progress if pilot != null else 0.0, 0.0, 1.0)
	if p > 0.0:
		var pts := PackedVector2Array([c])
		var segments := maxi(2, ceili(32.0 * p))
		for s in segments + 1:
			var a := -PI * 0.5 + TAU * p * s / segments
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		_eat_circle.draw_colored_polygon(pts, eat_circle_color)

	_eat_circle.draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.8), -1, true)   # outline


# --- Status line (top center) ------------------------------------------------------

func _build_status() -> void:
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	_status.visible = false
	_layer.add_child(_status)


func _update_status() -> void:
	if not is_controlling():
		_status.visible = false
		return
	var view: String = [
		"[%s] North view" % _key("view_north", "1"),
		"[%s] Camera view" % _key("view_camera", "2"),
		"[%s] First person" % _key("view_first_person", "3"),
	][control_view]
	_status.text = "Controlling %s #%d   ·   %s   ·   %s  release" % [
			controlled_species.species_name, controlled_index, view,
			_key("agent_control", "C")]
	if held_species != null:
		_status.text += "\nCarrying %s #%d   ·   %s  drop   ·   hold %s  eat   ·   %s  throw" % [
				held_species.species_name, held_index,
				_key("Drop"), _key("eat"), _key("throw")]
	if target_machine != null:
		var action := "feed it" if held_species != null \
				else ("stop" if target_machine.running else "start")
		_status.text += "\n%s   ·   %s  %s" % [target_machine.status_text(), _key("use"), action]
	if pilot != null and pilot.charging:
		var filled := roundi(pilot.charge * 10.0)
		_status.text += "\nThrow  [%s%s]  %d%%" % ["■".repeat(filled), "□".repeat(10 - filled),
				roundi(pilot.charge * 100.0)]
	_status.visible = true


func _on_button_pressed() -> void:
	spawn_and_control(spawn_species,WorldWrap.size/2)



@export_group("Spawn")
@export var spawn_species := "CATRONAUTE"      # species_name of what spawn_and_control makes
@export var spawn_as_adult := true             # starts at its max life cycle
@export var spawn_zoom := 6.0                  # camera distance to the spawned agent (0 = keep)

## Spawns an agent of species `sname` (default: spawn_species) and takes control of it.
## at = Vector3.INF: where the camera looks (on the ground). Returns its index, -1 if it failed.
func spawn_and_control(sname := "", at := Vector3.INF) -> int:
	if is_net_client():
		return -1                                # the host spawns the players' agents
	if alifemanager.tick_running():
		# Pipelined tick running: spawn right after it (arrays are busy now)
		alifemanager.when_free(spawn_and_control.bind(sname, at))
		return -1
	if sname == "":
		sname = spawn_species
	var sp = alifemanager.codex.species.get(sname)
	if sp == null:
		push_warning("spawn_and_control: no species named %s" % sname)
		return -1

	if at == Vector3.INF:
		at = camera.get_wrap_center()                # the point the camera looks at
	at.y = ground_y
	at = alifemanager.keep_in_world(at)

	# Build_New_Life doesn't return the index: it's the next free slot
	var i: int = sp.free_indices[sp.free_indices.size() - 1] if sp.free_indices.size() > 0 \
			else sp.entity_count
	var before: int = sp.active_entity_count
	sp.Build_New_Life(at, sp.seed_energy)
	if sp.active_entity_count == before:
		push_warning("spawn_and_control: world is full (maxLife)")
		return -1

	if spawn_as_adult:
		sp.current_life_state[i] = sp.max_life_cycle
		sp.current_energy_array[i] = sp.max_energy * 0.8

	take_control(sp, i)
	if spawn_zoom > 0.0:
		camera.follow_distance = clampf(spawn_zoom,
				camera.follow_min_distance, camera.follow_max_distance)
	return i


# --- Controls (button top right / controls_open (F1) -> key remap menu) -----------------

func _build_controls_button() -> void:
	_controls_button.text = "Controls"
	_controls_button.tooltip_text = "Controls (%s)" % _key("controls_open", "F1")
	_controls_button.focus_mode = Control.FOCUS_NONE   # never steals Space / Enter
	_controls_button.custom_minimum_size = Vector2(28, 28)
	_controls_button.pressed.connect(toggle_controls)
	_layer.add_child(_controls_button)
	_controls_button.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_controls_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN


## Opens the key remap menu (or closes it if open). The game is paused while it's open.
func toggle_controls() -> void:
	if is_instance_valid(_controls_menu):
		_controls_menu._on_back()                      # already open: close it
		return

	if picker != null:
		picker._tooltip.visible = false                # its _process stops while paused
	if camera != null:
		camera.set_mouse_look(false)                   # free the cursor to click the menu

	_controls_menu = SettingsRemapMenu.open(self)
	# Draw above this node's own layer, so the button and hints stay underneath
	(_controls_menu.get_parent() as CanvasLayer).layer = _layer.layer + 10

	# Freeze the game so the keys pressed while rebinding don't move anything
	var was_paused := get_tree().paused
	get_tree().paused = true
	_controls_menu.closed.connect(func():
		get_tree().paused = was_paused
		_restore_mouse_look())


func _restore_mouse_look() -> void:
	if picker != null:
		picker._update_mouse_look()                    # also knows whether its menu is open
	elif camera != null:
		camera.set_mouse_look(wants_mouse_look())
