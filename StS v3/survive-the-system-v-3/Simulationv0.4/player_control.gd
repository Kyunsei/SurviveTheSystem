class_name PlayerController
extends Node
## Playing an agent (works with AgentPicker and FlyCamera).
##
## C:            take control of the hovered (or followed) agent | C again: release it
## In control:
##   WASD        move the agent, Shift runs, Space jumps
##   Left click  (or R) pick up the outlined agent (the closest one in range)
##               near a machine (ring on the ground): feed it what you carry,
##               or start / stop it with empty hands
##   Q / E       drop / eat what you carry (one item at a time)
##   G (hold)    charge a throw, release to launch what you carry (arc + gravity)
##   T           attack: every agent in a box in front of you loses biomass
##               (debug: the box is drawn as a red wireframe for a moment)
##   1           north view (default): camera faces north, W = north, right drag only tilts
##   2           camera view: the mouse turns the view, W = where the camera looks
##   3           first person: from the agent's eyes, the mouse turns the view
##   Esc         (modes 2 / 3) give the cursor back
## Shows: an energy bar above the agent (HUD in first person), a facing arrow on the
## ground and a status line at the top of the screen.
##
## Needs in the species script, read by the simulation:
##   var player_index := -1                 # local index of the controlled agent (-1 = none)
##   var player_velocity := Vector3.ZERO    # velocity chosen by the player
##   var player_jump_buffer := 0.0, player_jump_held := false (jump)
## Carrying, for species the simulation moves:
##   var held_index := -1, held_position := Vector3.ZERO
## First person needs `uniform int hidden_id = -1;` in the sprite shader.

signal control_started(species, index: int)
signal control_ended(species, index: int)
signal agent_picked_up(species, index: int, item_species, item_index: int)
signal agent_dropped(species, index: int, item_species, item_index: int)
signal agent_thrown(species, index: int, item_species, item_index: int, speed: float)
signal item_landed(item_species, item_index: int, position: Vector3)
## hits: Array of [species, local_index] that were inside the box
signal agent_attacked(species, index: int, hits: Array)

@export var alifemanager: AlifeManager
@export var camera: FlyCamera
@export var picker: AgentPicker              # hover / follow / ids

@export_group("Control")
@export var control_speed := 3.0             # world units per second
@export var target_range := 3.0              # max distance for the outlined / pick-up target
@export var target_search_rings := 2         # grid rings searched for the closest agent
@export var energy_bar_size := Vector2(36, 5)
@export var arrow_color := Color(1.0, 1.0, 1.0, 0.75)
@export var arrow_scale := 1.0               # relative to the agent's width
@export var eye_ratio := 0.8                 # first person: eye height / sprite height

@export_group("Planet")
## Little-planet look while controlling an agent: the world is drawn bent down with
## distance. Smaller = rounder planet. 0 = flat. Drop at distance d = d² / (2 × radius).
@export var planet_radius := 60.0

@export_group("Throw")
@export var throw_min_speed := 3.0           # tap G
@export var throw_max_speed := 14.0          # G held for throw_charge_time
@export var throw_charge_time := 1.0         # seconds to reach full power
@export var throw_angle_deg := 35.0          # launch angle above the ground
@export var throw_gravity := 20.0            # world units / s²
@export var ground_y := 0.0                  # where thrown items land

@export_group("Key hints")
@export var show_key_hints := true           # row of key buttons under the status line
@export var hint_font_size := 12

@export_group("Attack")
@export var attack_width := 1.5              # across, centered on the agent
@export var attack_length := 2.0             # forward, starting at the agent
@export var attack_height := 2.0             # up from the agent's feet (and a bit below)
@export var attack_damage := 20.0            # biomass removed from each agent hit
@export var attack_cooldown := 0.4           # seconds between attacks (real time)
@export var attack_kills_at_zero := true     # biomass reaching 0 kills the agent
@export var show_hitbox := true              # debug: draw the box when attacking
@export var hitbox_show_time := 0.25         # seconds the debug box stays visible

@export_group("Carry")
@export var carry_forward := 0.5             # how far in front of the carrier (x its height)
@export var carry_height := 0.5              # how high (fraction of the carrier's height)

enum ControlView { NORTH, CAMERA, FIRST_PERSON }
@export var control_view := ControlView.NORTH

var controlled_species = null
var controlled_index := -1
var target_species = null                    # closest agent in range (outlined)
var target_index := -1
var held_species = null                      # the carried agent (one at a time)
var held_index := -1
var target_machine: Machine = null           # closest machine in range (ring shown)
var sprint := 1.0

var _highlighted_machine: Machine = null

var _charging := false                       # G held
var _charge := 0.0                           # 0..1 throw power
var _flights: Array[Dictionary] = []         # thrown items in the air: {sp, j, pos, vel}

var _attack_cd := 0.0                        # cooldown left
var _hitbox := MeshInstance3D.new()
var _hitbox_time := 0.0                      # debug box: time left visible
var _hitbox_origin := Vector3.ZERO           # flat world position of the last attack
var _hitbox_basis := Basis()

var _layer := CanvasLayer.new()
var _bar_bg := ColorRect.new()
var _bar_fill := ColorRect.new()
var _arrow := MeshInstance3D.new()
var _facing := Vector3.FORWARD
var _status := Label.new()
var _hints := HBoxContainer.new()
var _hints_sig := ""                         # current content, to rebuild only on change


func _ready() -> void:
	_layer.layer = 90
	add_child(_layer)
	_build_energy_bar()
	_build_arrow()
	_build_status()
	_build_hitbox()
	_build_hints()


# --- Public ----------------------------------------------------------------------

func is_controlling() -> bool:
	return controlled_species != null


## True when the current view wants the mouse to turn the camera (modes 2 and 3).
func wants_mouse_look() -> bool:
	return is_controlling() and control_view != ControlView.NORTH


# --- Input -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Left click in control mode: use the machine, or pick up the outlined agent
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _use_target():
			get_viewport().set_input_as_handled()
		return

	# G released: launch
	if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_G:
		if _charging:
			_charging = false
			_throw()
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_C:
			if is_controlling():
				release_control()
			elif picker.hovered_species != null:
				take_control(picker.hovered_species, picker.hovered_index)
			elif picker.followed_species != null:
				take_control(picker.followed_species, picker.followed_index)
			else:
				return
			get_viewport().set_input_as_handled()

		KEY_1, KEY_KP_1:
			if is_controlling():
				set_control_view(ControlView.NORTH)
				get_viewport().set_input_as_handled()

		KEY_2, KEY_KP_2:
			if is_controlling():
				set_control_view(ControlView.CAMERA)
				get_viewport().set_input_as_handled()

		KEY_3, KEY_KP_3:
			if is_controlling():
				set_control_view(ControlView.FIRST_PERSON)
				get_viewport().set_input_as_handled()

		KEY_SPACE:
			if is_controlling():
				controlled_species.player_jump_buffer = 0.12    # jump buffering
				get_viewport().set_input_as_handled()

		KEY_R:
			if _use_target():
				get_viewport().set_input_as_handled()

		KEY_T:
			if is_controlling():
				_attack()
				get_viewport().set_input_as_handled()

		KEY_G:
			if is_controlling() and held_species != null:
				_charging = true                     # charge while held, throw on release
				_charge = 0.0
				get_viewport().set_input_as_handled()

		KEY_Q:
			if is_controlling() and held_species != null:
				_drop()
				get_viewport().set_input_as_handled()

		KEY_E:
			if is_controlling() and held_species != null:
				_eat(controlled_species, controlled_index, held_species, held_index)
				get_viewport().set_input_as_handled()


func _can_pick_up() -> bool:
	return is_controlling() and held_species == null and target_species != null \
			and not _species_has_flight(target_species)


## Left click / R: the machine in range first (feed it / start-stop it), else pick up.
## Returns true if something happened.
func _use_target() -> bool:
	if not is_controlling():
		return false
	if target_machine != null:
		var used := target_machine.interact(controlled_species, controlled_index,
				held_species, held_index)
		if used:
			_clear_held()                        # the carried item went into the machine
		return true
	if _can_pick_up():
		_interact(controlled_species, controlled_index, target_species, target_index)
		return true
	return false


# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _charging:
		if held_species == null or not is_controlling():
			_charging = false                        # item eaten / dropped while charging
		else:
			_charge = minf(_charge + delta / maxf(throw_charge_time, 0.01), 1.0)
	_process_flights(delta)
	_update_planet()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_update_hitbox(delta)
	_update_hints()
	_update_wrap_view()
	if is_controlling():
		_process_control()
	_process_carry()
	_update_machine_highlight()
	_update_energy_bar()
	_update_arrow()
	_update_status()


# --- Control ---------------------------------------------------------------------

func take_control(sp, i: int) -> void:
	if not ("player_index" in sp):
		push_error("Species script needs `player_index` and `player_velocity` for control mode")
		return
	release_control()
	controlled_species = sp
	controlled_index = i
	sp.player_index = i
	sp.player_velocity = Vector3.ZERO

	# Start the arrow in the direction the agent was already moving
	var v: Vector3 = sp.current_velocity[i]
	v.y = 0.0
	_facing = v.normalized() if v.length_squared() > 1e-6 else Vector3.FORWARD

	camera.move_keys_enabled = false                 # WASD moves the agent, not the camera
	picker.follow(sp, i)
	set_control_view(control_view)
	control_started.emit(sp, i)


func release_control() -> void:
	if not is_controlling():
		return
	_drop()                                          # let go of anything carried
	var sp = controlled_species
	var i := controlled_index
	sp.player_index = -1
	sp.player_velocity = Vector3.ZERO
	sp.renderer3D.material_override.set_shader_parameter("hidden_id", -1)
	controlled_species = null
	controlled_index = -1
	target_species = null
	target_index = -1
	target_machine = null
	camera.move_keys_enabled = true
	camera.set_yaw_lock(false)
	camera.set_mouse_look(false)
	camera.set_first_person(false)
	control_ended.emit(sp, i)


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
	var r := planet_radius if is_controlling() else 0.0
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


func _process_control() -> void:
	var sp = controlled_species
	var i := controlled_index
	if sp.active_alife_array[i] == 0 or sp.alive_array[i] == 0:
		release_control()                            # the agent died (drops what it carries)
		return

	# Eye height follows the agent's size (it may grow)
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	camera.first_person_eye_height = q.y * sp.current_size[i] * eye_ratio

	# WASD: x = right, y = forward
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	sprint = 2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	sp.player_jump_held = Input.is_physical_key_pressed(KEY_SPACE)

	var dir := Vector3.ZERO
	if control_view == ControlView.NORTH:
		dir = Vector3(input.x, 0.0, -input.y)        # W = north (-Z), D = east (+X)
	else:
		# Modes 2 and 3: relative to where the camera looks, flattened on the ground
		var b := camera.global_transform.basis
		var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
		dir = right * input.x + fwd * input.y
	sp.player_velocity = dir.normalized() * control_speed * sprint

	# Machine whose zone we're in (also while carrying: that's how you feed it).
	# Each machine has its own interact_range. If several zones overlap, the one
	# we're deepest in wins (distance relative to its range), so a big machine
	# doesn't steal the focus from a small one right next to us.
	var pos: Vector3 = sp.position_array[i]
	var best_score := INF
	target_machine = null
	for m in get_tree().get_nodes_in_group("machines"):
		var d := WorldWrap.nearest_image(m.global_position, pos).distance_to(pos)
		if d > m.interact_range:
			continue
		var score := d / maxf(m.interact_range, 0.001)
		if score < best_score:
			best_score = score
			target_machine = m

	# Closest other agent (any species) within range. None while carrying:
	# the hands are full, and the carried agent would always be the closest.
	target_species = null
	target_index = -1
	if held_species != null:
		return
	var me: int = alifemanager.global_species_offset[alifemanager.species_array.find(sp)] + i
	var found: Vector4 = sp.find_nearest(pos, me, -1, target_search_rings)
	var id := int(found.w)
	var agent_dist := Vector3(found.x, found.y, found.z).length()
	# Agent vs machine: compared relative to their ranges, like machines between them
	var agent_score := agent_dist / maxf(target_range, 0.001)
	if id >= 0 and agent_dist <= target_range and agent_score < best_score:
		var t := picker.split_id(id)
		target_species = t[0]
		target_index = t[1]
		target_machine = null                       # the agent is closer than the machine


## Left click / R in control mode, on the outlined agent: pick it up.
func _interact(sp, i: int, target_sp, j: int) -> void:
	print("%s #%d picks up %s #%d" % [sp.species_name, i, target_sp.species_name, j])
	target_sp.Interact(j, sp, i)
	#target_sp.Interact(j, sp, i)      # your previous interaction, if you still need it
	_pick_up(target_sp, j)


# --- Carry -----------------------------------------------------------------------

func _pick_up(item_sp, j: int) -> void:
	if held_species != null:
		return                                       # one item at a time
	held_species = item_sp
	held_index = j
	if "held_index" in item_sp:
		item_sp.held_index = j
		item_sp.held_position = _carry_position()
	target_species = null
	target_index = -1
	agent_picked_up.emit(controlled_species, controlled_index, item_sp, j)


## Q while carrying: put the item down in front of the carrier, on its feet level.
func _drop() -> void:
	if held_species == null:
		return
	var item_sp = held_species
	var j := held_index
	if is_controlling() and item_sp.active_alife_array[j] != 0:
		var p := _carry_position()
		p.y = controlled_species.position_array[controlled_index].y
		item_sp.position_array[j] = p
	_clear_held()
	agent_dropped.emit(controlled_species, controlled_index, item_sp, j)


## E while carrying.
## If the eaten agent is removed, the carry ends on its own.
func _eat(sp, i: int, food_sp, j: int) -> void:
	print("%s #%d eats %s #%d" % [sp.species_name, i, food_sp.species_name, j])
	sp.current_energy_array[i] += food_sp.current_biomass[j]
	food_sp.Remove_Life(j)


## Every frame: keep the carried agent in the carrier's hands.
func _process_carry() -> void:
	if held_species == null:
		return
	var item_sp = held_species
	var j := held_index
	if not is_controlling() or item_sp.active_alife_array[j] == 0:
		_clear_held()                                # item gone (eaten, removed) or no carrier
		return
	var p := _carry_position()
	if "held_index" in item_sp:
		item_sp.held_position = p                    # the simulation places it there
	item_sp.position_array[j] = p                    # and right now, for plants / no simulation


## In front of the carrier (along its facing arrow), at a fraction of its height.
func _carry_position() -> Vector3:
	var sp = controlled_species
	var i := controlled_index
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var h := maxf(q.y * sp.current_size[i], 0.2)
	var p: Vector3 = sp.position_array[i] + _facing * carry_forward * h + Vector3.UP * h * carry_height
	return WorldWrap.wrap_into(p)                    # stays inside the world near a border


func _clear_held() -> void:
	if held_species != null and "held_index" in held_species:
		held_species.held_index = -1
	held_species = null
	held_index = -1


# --- Throw -------------------------------------------------------------------------

## G released: launch the carried item, power from how long G was held.
func _throw() -> void:
	if not is_controlling() or held_species == null:
		return
	var item_sp = held_species
	var j := held_index

	# Direction: where the camera looks (modes 2 / 3), else the facing arrow (mode 1)
	var dir := _facing
	if control_view != ControlView.NORTH:
		var b := camera.global_transform.basis
		dir = Vector3(-b.z.x, 0.0, -b.z.z)
	dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD

	var speed := lerpf(throw_min_speed, throw_max_speed, _charge)
	var a := deg_to_rad(throw_angle_deg)
	var vel := dir * cos(a) * speed + Vector3.UP * sin(a) * speed
	var pos := _carry_position()

	_clear_held()
	# Animals: keep the simulation's hands off it while it flies
	if "held_index" in item_sp:
		item_sp.held_index = j
		item_sp.held_position = pos
	_flights.append({"sp": item_sp, "j": j, "pos": pos, "vel": vel})
	agent_thrown.emit(controlled_species, controlled_index, item_sp, j, speed)


## Every frame (real time, so it works while paused too): move items in the air.
func _process_flights(delta: float) -> void:
	for f in _flights.duplicate():
		var sp = f["sp"]
		var j: int = f["j"]
		if sp.active_alife_array[j] == 0:            # removed mid-air
			_end_flight(f, false)
			continue

		var vel: Vector3 = f["vel"]
		var pos: Vector3 = f["pos"]
		vel.y -= throw_gravity * delta
		pos += vel * delta
		var landed := pos.y <= ground_y
		if landed:
			pos.y = ground_y

		# Stay in the world: wrap on wrapped axes, stop at the edge otherwise
		pos = WorldWrap.wrap_into(pos)
		var ws := WorldWrap.size
		if WorldWrap.mask.x == 0.0: pos.x = clampf(pos.x, 0.0, ws.x)
		if WorldWrap.mask.z == 0.0: pos.z = clampf(pos.z, 0.0, ws.z)

		f["vel"] = vel
		f["pos"] = pos
		sp.position_array[j] = pos
		if "held_index" in sp:
			sp.held_position = pos
		if landed:
			_end_flight(f, true)


func _end_flight(f: Dictionary, landed: bool) -> void:
	_flights.erase(f)
	var sp = f["sp"]
	if "held_index" in sp and sp.held_index == f["j"]:
		sp.held_index = -1                           # the simulation moves it again
	if landed:
		item_landed.emit(sp, f["j"], f["pos"])


## One flying item per species (it uses the species' held_index slot).
func _species_has_flight(sp) -> bool:
	if not ("held_index" in sp):
		return false
	for f in _flights:
		if f["sp"] == sp:
			return true
	return false


# --- Key hints (top of the screen, in control mode) --------------------------------

func _build_hints() -> void:
	_hints.add_theme_constant_override("separation", 6)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.visible = false
	_layer.add_child(_hints)


## All control keys, always the same: [key, action]
const KEY_HINTS := [
	["WASD", "move"],
	["Shift", "run"],
	["Space", "jump"],
	["T", "attack"],
	["Click / R", "pick up / use"],
	["Q", "drop"],
	["E", "eat"],
	["G", "hold to throw"],
	["1 2 3", "view"],
	["Esc", "cursor"],
	["C", "release"],
]


func _current_hints() -> Array:
	return KEY_HINTS


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


# --- Attack -------------------------------------------------------------------------

## Aim: where the camera looks (modes 2 / 3), else the facing arrow (mode 1). Flat.
func _aim_dir() -> Vector3:
	var dir := _facing
	if control_view != ControlView.NORTH:
		var b := camera.global_transform.basis
		dir = Vector3(-b.z.x, 0.0, -b.z.z)
	return dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD


## T: hit every agent inside a box in front of the controlled agent.
func _attack() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown

	var sp = controlled_species
	var i := controlled_index
	var origin: Vector3 = sp.position_array[i]
	var fwd := _aim_dir()
	var right := Vector3.UP.cross(fwd).normalized()     # perpendicular, on the ground
	_facing = fwd

	# Debug box: x = width (centered), y = height, z = length (forward)
	_hitbox_origin = origin
	_hitbox_basis = Basis(right * attack_width, Vector3.UP * attack_height, fwd * attack_length)
	_hitbox_time = hitbox_show_time

	var hits := _agents_in_box(origin, right, fwd, sp, i)
	for h in hits:
		var hsp = h[0]
		var j: int = h[1]
		var b: float = hsp.current_biomass[j] - attack_damage
		hsp.current_biomass[j] = maxf(b, 0.0)
		if attack_kills_at_zero and b <= 0.0:
			hsp.alive_array[j] = 0                       # the simulation handles the corpse
	agent_attacked.emit(sp, i, hits)


## Every living agent whose position is inside the box (wrap-aware), except the attacker.
## Uses the contact grid: only the cells around the box are checked.
func _agents_in_box(origin: Vector3, right: Vector3, fwd: Vector3, me_sp, me_i: int) -> Array:
	var am := alifemanager
	var hits: Array = []
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var offs: PackedInt32Array = am.global_species_offset
	var me: int = offs[am.species_array.find(me_sp)] + me_i
	var wx := WorldWrap.mask.x > 0.0
	var wz := WorldWrap.mask.z > 0.0
	var ws := WorldWrap.size

	# Cells covering a circle around the box center, big enough to contain the whole box
	var center := origin + fwd * attack_length * 0.5
	var reach := Vector2(attack_width * 0.5, attack_length * 0.5).length()
	var cx := clampi(int(fposmod(center.x, ws.x) / cs.x) if wx else int(center.x / cs.x), 0, W - 1)
	var cz := clampi(int(fposmod(center.z, ws.z) / cs.z) if wz else int(center.z / cs.z), 0, D - 1)
	var rx := ceili(reach / cs.x) + 1
	var rz := ceili(reach / cs.z) + 1
	if wx: rx = mini(rx, (W - 1) / 2)
	if wz: rz = mini(rz, (D - 1) / 2)

	var half_w := attack_width * 0.5
	for zz in range(cz - rz, cz + rz + 1):
		var z := posmod(zz, D) if wz else zz
		if z < 0 or z >= D:
			continue
		for y in H:
			for xx in range(cx - rx, cx + rx + 1):
				var x := posmod(xx, W) if wx else xx
				if x < 0 or x >= W:
					continue
				var cell := x + W * (y + H * z)
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = cell_items[k]
					if j == me or active[j] == 0:
						continue
					var d: Vector3 = sorted_pos[k] - origin
					if wx: d.x -= ws.x * roundf(d.x / ws.x)
					if wz: d.z -= ws.z * roundf(d.z / ws.z)
					var along := d.dot(fwd)
					var across := d.dot(right)
					if along < 0.0 or along > attack_length or absf(across) > half_w:
						continue
					if d.y < -0.5 or d.y > attack_height:
						continue
					var t := picker.split_id(j)
					if t[0].alive_array[t[1]] == 0:
						continue                             # corpses aren't hit
					hits.append(t)
	return hits


# --- Debug hitbox (wireframe) ----------------------------------------------------

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
	if _hitbox_time <= 0.0 or not show_hitbox:
		_hitbox.visible = false
		return
	_hitbox_time -= delta
	# Drawn where the attack happened, at its copy near the view, on the planet
	var center := camera.get_wrap_center()
	var p := WorldWrap.curve(WorldWrap.nearest_image(_hitbox_origin, center), center)
	_hitbox.global_transform = Transform3D(_hitbox_basis, p)
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
	var sp = controlled_species
	if sp == null:
		_arrow.visible = false
		return
	var i := controlled_index

	# Facing: the keys being pressed (instant, even when paused), else the real movement
	var v: Vector3 = sp.player_velocity
	if v.length_squared() < 1e-6:
		v = sp.current_velocity[i]
	v.y = 0.0
	if v.length_squared() > 1e-6:
		_facing = v.normalized()                     # standing still: keep the last direction

	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var s := maxf(q.x * sp.current_size[i], 0.3) * arrow_scale
	var angle := atan2(_facing.x, _facing.z)
	var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * s)
	var center := camera.get_wrap_center()
	var p := WorldWrap.curve(WorldWrap.nearest_image(sp.position_array[i], center), center)
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
	var foot := WorldWrap.curve(WorldWrap.nearest_image(sp.position_array[i], center), center)
	var above: Vector3 = foot + Vector3(0.0, q.y * size + 0.2, 0.0)
	if cam.is_position_behind(above):
		_bar_bg.visible = false
		return
	_bar_bg.position = cam.unproject_position(above) - Vector2(_bar_bg.size.x * 0.5, _bar_bg.size.y)
	_bar_bg.visible = true


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
	var view: String = ["[1] North view", "[2] Camera view", "[3] First person"][control_view]
	_status.text = "Controlling %s #%d   ·   %s   ·   C  release" % [
			controlled_species.species_name, controlled_index, view]
	if held_species != null:
		_status.text += "\nCarrying %s #%d   ·   Q  drop   ·   E  eat   ·   G  throw" % [
				held_species.species_name, held_index]
	if target_machine != null:
		var action := "feed it" if held_species != null \
				else ("stop" if target_machine.running else "start")
		_status.text += "\n%s   ·   Click / R  %s" % [target_machine.status_text(), action]
	if _charging:
		var filled := roundi(_charge * 10.0)
		_status.text += "\nThrow  [%s%s]  %d%%" % ["■".repeat(filled), "□".repeat(10 - filled),
				roundi(_charge * 100.0)]
	_status.visible = true
