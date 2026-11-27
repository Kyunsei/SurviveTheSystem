class_name PlayerController
extends Node
## Playing an agent (works with AgentPicker and FlyCamera).
##
## All keys are Input Map actions (remappable in the Controls menu). Default keys in ():
##
## agent_control (C): take control of the hovered (or followed) agent | again: release it
## In control:
##   up / down / left / right (WASD or left stick)  move the agent (analog on a stick)
##   sprint (Shift)   run            jump (Space)    jump
##   dash             short burst of speed (in the direction you move, else forward)
##   pick_up          pick up the outlined agent (the closest one in range), including a
##                    fruit hanging in a tree (jump to bring the higher ones in range)
##   Action           interact with the outlined agent (a grown tree drops its fruits)
##   use              near a machine (ring on the ground): feed it what you carry,
##                    or start / stop it with empty hands
##                    (bind pick_up and use to the same key to get one "interact" key)
##   Drop / eat       drop / eat what you carry (one item at a time)
##   throw (hold)     charge a throw, release to launch what you carry (arc + gravity)
##   attack           every agent in a box in front of you loses biomass
##                    (debug: the box is drawn as a red wireframe for a moment)
##   view_north (1)   north view (default): camera faces north, up = north, right drag only tilts
##   view_camera (2)  camera view: the mouse turns the view, up = where the camera looks
##   view_first_person (3)  first person: from the agent's eyes, the mouse turns the view
##   free_cursor (Esc) (modes 2 / 3) give the cursor back (handled by FlyCamera)
##
## The view_* actions aren't in your action list yet: until you add
## them to the Input Map, the keys in () are used. Add them to Settings.REMAPPABLE to
## make them remappable too.
##
## Shows: an energy bar above the agent (HUD in first person), a facing arrow on the
## ground and a status line at the top of the screen.
##
## Needs in the species script, read by the simulation:
##   var player_index := -1                 # local index of the controlled agent (-1 = none)
##   var player_velocity := Vector3.ZERO    # velocity chosen by the player
##   var player_jump_buffer := 0.0, player_jump_held := false (jump)
## Carrying goes through AlifeManager (pick_up / drop / release_flying / land / unlink),
## the same functions AI agents use, so the player is just one more carrier:
##   `var holding := PackedInt32Array()` and `var held_by := PackedInt32Array()` in the
##   species script (AlifeManager sizes them). Items in state HELD (2) or FLYING (4) must
##   not be moved by the simulation. AlifeManager.update_carried() places carried items.
##   Optional: a `facing` PackedVector3Array in the species, written here for the player,
##   so the carried item stays in front even when standing still.
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
@export var picker: AgentPicker              # hover / follow / ids

@export_group("Control")
@export var control_speed := 3.0             # world units per second
@export var sprint_multiplier := 2.0
@export var target_range := 3.0              # max distance for the outlined / pick-up target
@export var target_search_rings := 2         # grid rings searched for the closest agent
@export var energy_bar_size := Vector2(36, 5)
@export var arrow_color := Color(1.0, 1.0, 1.0, 0.75)
@export var arrow_scale := 1.0               # relative to the agent's width
@export var eye_ratio := 0.8                 # first person: eye height / sprite height

@export_group("Dash")
@export var dash_multiplier := 4.0           # speed during the dash (x control_speed)
@export var dash_time := 0.15                # seconds the dash lasts
@export var dash_cooldown := 0.8             # seconds between dashes (real time)

@export_group("Planet")
## Little-planet look while controlling an agent: the world is drawn bent down with
## distance. Smaller = rounder planet. 0 = flat. Drop at distance d = d² / (2 × radius).
@export var planet_radius := 60.0

@export_group("Throw")
@export var throw_min_speed := 3.0           # tap throw
@export var throw_max_speed := 14.0          # throw held for throw_charge_time
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
@export var attack_damage := 20.0            # health removed per hit, for species without get_damage (strength)
@export var attack_cooldown := 0.4           # seconds between attacks (real time)
@export var attack_kills_at_zero := true     # biomass reaching 0 kills the agent
@export var show_hitbox := true              # debug: draw the box when attacking
@export var hitbox_show_time := 0.25         # seconds the debug box stays visible

@export_group("Eat")
@export var eat_hold_time := 1.0             # seconds eat must be held before eating
@export var eat_circle_radius := 8.0         # pixels
@export var eat_circle_color := Color(0.45, 1.0, 0.45, 0.95)

enum ControlView { NORTH, CAMERA, FIRST_PERSON }
@export var control_view := ControlView.NORTH

var controlled_species = null
var controlled_index := -1
var target_species = null                    # closest agent in range (outlined)
var target_index := -1
var target_machine: Machine = null           # closest machine in range (ring shown)
var sprint := 1.0

var _highlighted_machine: Machine = null

var _charging := false                       # throw held
var _charge := 0.0                           # 0..1 throw power
var _flights: Array[Dictionary] = []         # thrown items in the air: {sp, j, pos, vel}

## What the controlled agent carries, read from the carry system (never stored here)
var held_species:
	get:
		return _held()[0]
var held_index: int:
	get:
		return _held()[1]

var _eating := false                         # eat held
var _eat_progress := 0.0                     # 0..1, eats at 1
var _eat_circle := Control.new()

var _dash_left := 0.0                        # dash time remaining
var _dash_cd := 0.0                          # dash cooldown left

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
	_build_eat_circle()


# --- Public ----------------------------------------------------------------------

func is_controlling() -> bool:
	return controlled_species != null


## True when the current view wants the mouse to turn the camera (modes 2 and 3).
func wants_mouse_look() -> bool:
	return is_controlling() and control_view != ControlView.NORTH

## True when the carried item can be used (an ALIFE_ITEM).
func _held_usable() -> bool:
	var item := _held()
	return item[0] != null and item[0].has_method("use")
## [species, local index] of what the controlled agent carries, or [null, -1].
func _held() -> Array:
	if not is_controlling():
		return [null, -1]
	var id: int = controlled_species.holding[controlled_index]
	if id == -1:
		return [null, -1]
	return alifemanager.split_cid(id)               # carry ids, not global ids


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

func _unhandled_input(event: InputEvent) -> void:
	# Throw released: launch
	if event.is_action_released("throw"):
		if _charging:
			_charging = false
			_throw()
			get_viewport().set_input_as_handled()
		return

	# Eat released before the circle is full: cancel
	if event.is_action_released("eat"):
		if _eating:
			_cancel_eat()
			get_viewport().set_input_as_handled()
		return

	if _act_pressed(event, "agent_control", [KEY_C]):
		if _toggle_control():
			get_viewport().set_input_as_handled()
		return

	if not is_controlling():
		return

	# Views / movement-type keys: one at a time, as before
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

	# Every other action is checked on its own: several actions bound to the same key
	# all fire on one press. What each may do is decided BEFORE any of them runs,
	# so one press doesn't chain (e.g. pick up then use what was just picked up).
	var holding := held_species != null
	var item := _held()
	var can_use := target_machine != null or _held_usable()
	var can_pick := _can_pick_up()
	var can_eat :bool= holding and not (item[0].has_method("can_be_eaten") \
			and not item[0].can_be_eaten(item[1]))
	var did := false

	if event.is_action_pressed("jump"):
		controlled_species.player_jump_buffer = 0.12    # jump buffering
		did = true
	if event.is_action_pressed("dash"):
		_dash()
		did = true
	if event.is_action_pressed("attack"):
		_attack()
		did = true
	if event.is_action_pressed("Action"):
		var t := _interact_target()
		_interact(controlled_species, controlled_index, t[0], t[1])
		did = true
	if event.is_action_pressed("use") and can_use:
		if target_machine != null:
			_use_machine()                           # near a machine: feed it / start / stop
		else:
			item[0].use(item[1], controlled_species, controlled_index)
		did = true
	if event.is_action_pressed("pick_up") and can_pick:
		_pick_up(controlled_species, controlled_index, target_species, target_index)
		did = true
	if event.is_action_pressed("throw") and holding:
		_charging = true                             # charge while held, throw on release
		_charge = 0.0
		did = true
	if event.is_action_pressed("Drop") and holding:
		_drop()
		did = true
	if event.is_action_pressed("eat") and can_eat:
		_eating = true                               # the circle fills while held
		_eat_progress = 0.0
		did = true

	if did:
		get_viewport().set_input_as_handled()


## agent_control: release, or take the hovered (else followed) agent. True if something happened.
func _toggle_control() -> bool:
	if is_controlling():
		release_control()
	elif picker.hovered_species != null:
		take_control(picker.hovered_species, picker.hovered_index)
	elif picker.followed_species != null:
		take_control(picker.followed_species, picker.followed_index)
	else:
		return false
	return true


func _can_pick_up() -> bool:
	return is_controlling() and held_species == null and target_species != null


## use: feed the machine in range what you carry, or start / stop it with empty hands.
func _use_machine() -> void:
	var item := _held()
	if target_machine:
		if target_machine.has_method("interact"):
			var used := target_machine.interact(controlled_species, controlled_index, item[0], item[1])
			if used and item[0] != null:
				alifemanager.unlink(item[0], item[1])        # the carried item went into the machine


# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _charging:
		if held_species == null or not is_controlling():
			_charging = false                        # item eaten / dropped while charging
		else:
			_charge = minf(_charge + delta / maxf(throw_charge_time, 0.01), 1.0)
	_process_eat(delta)
	_process_flights(delta)
	_update_planet()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if is_controlling():                         # jump buffer counts down in real time
		controlled_species.player_jump_buffer = maxf(controlled_species.player_jump_buffer - delta, 0.0)
	
	_update_hitbox(delta)
	_update_hints()
	_update_wrap_view()
	if is_controlling():
		_process_control()
	# The carried item is placed by AlifeManager.update_carried(), like for every carrier
	_update_machine_highlight()
	_update_energy_bar()
	_update_eat_circle()                         # after the bar: it sits just above it
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

	camera.move_keys_enabled = false                 # movement keys move the agent, not the camera
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
	_dash_left = 0.0
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
	planet_radius = WorldWrap.size.x/4
	var r_planet := sqrt( WorldWrap.size.x * WorldWrap.size.z / (4* PI))
	planet_radius = r_planet
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

	# Movement: x = right, y = forward. Analog on a stick, deadzone from the Input Map.
	var input := Input.get_vector("left", "right", "down", "up")
	sprint = sprint_multiplier if Input.is_action_pressed("sprint") else 1.0
	sp.player_jump_held = Input.is_action_pressed("jump")

	var dir := Vector3.ZERO
	if control_view == ControlView.NORTH:
		dir = Vector3(input.x, 0.0, -input.y)        # up = north (-Z), right = east (+X)
	else:
		# Modes 2 and 3: relative to where the camera looks, flattened on the ground
		var b := camera.global_transform.basis
		var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
		dir = right * input.x + fwd * input.y
	dir = dir.limit_length(1.0)                      # half-pushed stick = half speed

	if _dash_left > 0.0:
		# Dash: full speed burst, in the direction pressed, else straight ahead
		var d := dir if dir.length_squared() > 1e-6 else _facing
		sp.player_velocity = d.normalized() * control_speed * dash_multiplier
	else:
		sp.player_velocity = dir * control_speed * sprint

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
	var me := alifemanager.g_id(sp, i)
	var found: Vector4 = sp.find_nearest(pos, me, -1, target_search_rings)
	var id := int(found.w)
	var agent_dist := Vector3(found.x, found.y, found.z).length()
	# Agent vs machine: compared relative to their ranges, like machines between them
	var agent_score := agent_dist / maxf(target_range, 0.001)
	if id >= 0 and agent_dist <= target_range and agent_score < best_score:
		var t := alifemanager.split_id(id)
		target_species = t[0]
		target_index = t[1]
		target_machine = null                       # the agent is closer than the machine
		best_score = agent_score

	# Fruits hanging in trees aren't in the contact grid: same range and scoring, asked
	# to the species that have them. Jumping brings the higher ones in range.
	for fsp in alifemanager.species_array:
		if not fsp.has_method("find_hanging_fruit"):
			continue
		var f: int = fsp.find_hanging_fruit(pos, target_range)
		if f < 0:
			continue
		var fruit_dist: float = WorldWrap.nearest_image(fsp.position_array[f], pos).distance_to(pos)
		var fruit_score := fruit_dist / maxf(target_range, 0.001)
		if fruit_score < best_score:
			best_score = fruit_score
			target_species = fsp
			target_index = f
			target_machine = null

## dash: a short burst of speed, with a cooldown.
func _dash() -> void:
	if _dash_cd > 0.0:
		return
	_dash_cd = dash_cooldown
	_dash_left = dash_time
	agent_dashed.emit(controlled_species, controlled_index)
	
# --- Carry (through AlifeManager, like any other carrier) ---------------------------

## pick_up on the outlined agent.
func _pick_up(sp, i: int, item_sp, j: int) -> void:
	if item_sp.has_method("harvest") and item_sp.harvest(j, sp, i):
		target_species = null                        # ripe bush: the berry is now in hand
		target_index = -1
		return
	if item_sp.has_method("can_be_carried") and not item_sp.can_be_carried(j):
		return                                       # e.g. a grown tree
	if item_sp.has_method("detach_fruit"):
		item_sp.detach_fruit(j)                      # a fruit grabbed from its branch
	
	if not alifemanager.pick_up(sp, i, item_sp, j):
		if sp.has_method("can_carry") and not sp.can_carry(i, item_sp, j):
			print("%s #%d: too big to carry (size %.1f needs power %d, has %d)" % [
					sp.species_name, i, item_sp.current_size[j],
					alifemanager.item_carry_class(item_sp, j), sp.carrying_power[i]])
		return                                       # hands full, too big, or item not free
	print("%s #%d picks up %s #%d" % [sp.species_name, i, item_sp.species_name, j])
	target_species = null
	target_index = -1
	agent_picked_up.emit(sp, i, item_sp, j)


## Closest agent of an `interactable` species within target_range, or [null, -1].
## Searched on its own: the outlined target is often grass or a fruit right next to the tree.
func _interact_target() -> Array:
	var sp = controlled_species
	var i := controlled_index
	var pos: Vector3 = sp.position_array[i]
	var me := alifemanager.g_id(sp, i)
	var best: Array = [null, -1]
	var best_d := target_range
	for isp in alifemanager.species_array:
		'if not isp.interactable:
			continue'
		var found: Vector4 = sp.find_nearest(pos, me, isp.species_id, target_search_rings)
		var id := int(found.w)
		if id < 0:
			continue
		var d := Vector3(found.x, found.y, found.z).length()
		if d <= best_d:
			best_d = d
			best = alifemanager.split_id(id)
	return best


## Action on an agent: it reacts in its own way (a tree drops its fruits).
func _interact(sp, i: int, target_sp, j: int) -> void:
	if target_sp == null or not target_sp.has_method("Interact"):
		return
	print("%s #%d interacts with %s #%d" % [sp.species_name, i, target_sp.species_name, j])
	target_sp.Interact(j, sp, i)                     # (target index, who, who's index)

## Drop: put the item down in front of the carrier, on its feet level.
func _drop() -> void:
	var item := _held()
	if item[0] == null:
		return
	var cs = controlled_species
	var ci := controlled_index
	var p := alifemanager.carry_position(cs, ci)
	p.y = cs.position_array[ci].y
	alifemanager.drop(cs, ci, p)
	agent_dropped.emit(cs, ci, item[0], item[1])


## eat held: fill the circle, eat when it's full.
func _process_eat(delta: float) -> void:
	if not _eating:
		return
	if held_species == null or not is_controlling():
		_cancel_eat()                                # dropped / thrown / released meanwhile
		return
	_eat_progress += delta / maxf(eat_hold_time, 0.01)
	if _eat_progress >= 1.0:
		_cancel_eat()
		var item := _held()
		_eat(controlled_species, controlled_index, item[0], item[1])


func _cancel_eat() -> void:
	_eating = false
	_eat_progress = 0.0


## Called when the eat circle is full.
func _eat(sp, i: int, food_sp, j: int) -> void:
	print("%s #%d eats %s #%d" % [sp.species_name, i, food_sp.species_name, j])
	if food_sp.has_method("on_eaten"):
		food_sp.on_eaten(j, sp, i)                   # items: their own effect (energy, health...)
	else:
		sp.current_energy_array[i] += food_sp.current_biomass[j]   # creatures / plants: biomass
	alifemanager.unlink(food_sp, j)                  # free the hands before the slot is reused
	food_sp.Remove_Life(j)
# --- Throw -------------------------------------------------------------------------

## throw released: launch the carried item, power from how long it was held.
func _throw() -> void:
	if not is_controlling() or held_species == null:
		return
	var cs = controlled_species
	var ci := controlled_index

	var dir := _aim_dir()
	var speed := lerpf(throw_min_speed, throw_max_speed, _charge)
	var a := deg_to_rad(throw_angle_deg)
	var vel := dir * cos(a) * speed + Vector3.UP * sin(a) * speed
	var pos := alifemanager.carry_position(cs, ci)

	# Out of the hands, but not back in the world yet: the simulation leaves it alone
	var item: Array = alifemanager.release_flying(cs, ci)
	if item.is_empty():
		return
	_flights.append({"sp": item[0], "j": item[1], "pos": pos, "vel": vel})
	agent_thrown.emit(cs, ci, item[0], item[1], speed)


## Every frame (real time, so it works while paused too): move items in the air.
func _process_flights(delta: float) -> void:
	for f in _flights.duplicate():
		var sp = f["sp"]
		var j: int = f["j"]
		if sp.active_alife_array[j] == 0:            # removed mid-air
			_flights.erase(f)
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
		if landed:
			_flights.erase(f)
			alifemanager.land(sp, j, pos)            # back in the world: the simulation moves it again
			item_landed.emit(sp, j, pos)


# --- Key hints (top of the screen, in control mode) --------------------------------

func _build_hints() -> void:
	_hints.add_theme_constant_override("separation", 6)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.visible = false
	_layer.add_child(_hints)


## All control keys, with the keys currently bound: [key, action]
func _current_hints() -> Array:
	# "WASD" when every movement key is one letter, else "W A S D" / "Up Left Down Right"
	var move := PackedStringArray([_key("up"), _key("left"), _key("down"), _key("right")])
	var short := true
	for k in move:
		short = short and k.length() == 1
	var hints := [
		[("" if short else " ").join(move), "move"],
		[_key("sprint"), "run"],
		[_key("jump"), "jump"],
		[_key("dash"), "dash"],
		[_key("attack"), "attack"],
	]
	var pick := _key("pick_up")
	var use := _key("use")
	if pick == use:
		hints.append([pick, "pick up / use"])
	else:
		hints.append([pick, "pick up"])
		hints.append([use, "use"])
	hints.append_array([
		[_key("Action"), "interact"],
		[_key("Drop"), "drop"],
		[_key("eat"), "hold to eat"],
		[_key("throw"), "hold to throw"],
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


# --- Attack -------------------------------------------------------------------------

## Aim: where the camera looks (modes 2 / 3), else the facing arrow (mode 1). Flat.
func _aim_dir() -> Vector3:
	var dir := _facing
	if control_view != ControlView.NORTH:
		var b := camera.global_transform.basis
		dir = Vector3(-b.z.x, 0.0, -b.z.z)
	return dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD


## attack: hit every agent inside a box in front of the controlled agent.
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

	# Damage: the attacker's strength (else attack_damage), + the carried weapon's bonus.
	# Area: the attack box, scaled by the carried weapon.
	var damage: float = sp.get_damage(i) if sp.has_method("get_damage") else attack_damage
	var area := 1.0
	var weapon := _held()
	if weapon[0] != null and weapon[0].has_method("weapon_damage_bonus"):
		damage += weapon[0].weapon_damage_bonus(weapon[1])
		area = weapon[0].weapon_area_scale(weapon[1])
	var width := attack_width * area
	var length := attack_length * area

	# Debug box: x = width (centered), y = height, z = length (forward)
	_hitbox_origin = origin
	_hitbox_basis = Basis(right * width, Vector3.UP * attack_height, fwd * length)
	_hitbox_time = hitbox_show_time

	var hits := _agents_in_box(origin, right, fwd, sp, i, width, length)
	for h in hits:
		var hsp = h[0]
		var j: int = h[1]
		var before: float = hsp.current_health[j]
		# Armour: the target's species removes a flat amount from every hit (never below 0)
		var taken := damage
		if "damage_reduction" in hsp:
			taken = maxf(damage - hsp.damage_reduction, 0.0)
		var b: float = before - taken
		hsp.current_health[j] = maxf(b, 0.0)
		DamageEffects.hit(hsp, j, before - hsp.current_health[j])   # flash + number
		hsp.on_damaged(j, sp, i)                         # e.g. a tree drops some fruits
		if attack_kills_at_zero and b <= 0.0:
			hsp.alive_array[j] = 0                       # the simulation handles the corpse
	agent_attacked.emit(sp, i, hits)


## Every living agent whose position is inside the box (wrap-aware), except the attacker.
## Uses the contact grid: only the cells around the box are checked.
func _agents_in_box(origin: Vector3, right: Vector3, fwd: Vector3, me_sp, me_i: int,
		width := attack_width, length := attack_length) -> Array:
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
	var center := origin + fwd * length * 0.5
	var reach := Vector2(width * 0.5, length * 0.5).length()
	var cx := clampi(int(fposmod(center.x, ws.x) / cs.x) if wx else int(center.x / cs.x), 0, W - 1)
	var cz := clampi(int(fposmod(center.z, ws.z) / cs.z) if wz else int(center.z / cs.z), 0, D - 1)
	var rx := ceili(reach / cs.x) + 1
	var rz := ceili(reach / cs.z) + 1
	if wx: rx = mini(rx, (W - 1) / 2)
	if wz: rz = mini(rz, (D - 1) / 2)

	var half_w := width * 0.5
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
					if j == me or active[j] != AlifeManager.ACTIVE:
						continue
					var d: Vector3 = sorted_pos[k] - origin
					if wx: d.x -= ws.x * roundf(d.x / ws.x)
					if wz: d.z -= ws.z * roundf(d.z / ws.z)
					var along := d.dot(fwd)
					var across := d.dot(right)
					if along < 0.0 or along > length or absf(across) > half_w:
						continue
					if d.y < -0.5 or d.y > attack_height:
						continue
					var t := alifemanager.split_id(j)
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
	if "facing" in sp:
		sp.facing[i] = _facing                       # the carry system places the item with it

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


# --- Eat circle (above the energy bar, fills while eat is held) ---------------------

func _build_eat_circle() -> void:
	_eat_circle.size = Vector2.ONE * (eat_circle_radius * 2.0 + 4.0)
	_eat_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eat_circle.visible = false
	_eat_circle.draw.connect(_draw_eat_circle)
	_layer.add_child(_eat_circle)


func _update_eat_circle() -> void:
	if not _eating or not _bar_bg.visible:
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
	var p := clampf(_eat_progress, 0.0, 1.0)
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
	if _charging:
		var filled := roundi(_charge * 10.0)
		_status.text += "\nThrow  [%s%s]  %d%%" % ["■".repeat(filled), "□".repeat(10 - filled),
				roundi(_charge * 100.0)]
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
