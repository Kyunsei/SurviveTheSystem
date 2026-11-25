class_name FlyCamera
extends Camera3D
## Map-style camera (Godot 4): the mouse is visible, except in mouse-look mode.
##
## All keys are Input Map actions (remappable in the Controls menu). Default keys in ():
##
## Fly mode:
##   up / down / left / right (WASD or left stick): move parallel to the ground
##                       (relative to where the camera faces, analog on a stick)
##   camera_rise / camera_lower (E / Q): up / down
##   sprint (Shift):     faster
##   camera_zoom_in / camera_zoom_out (wheel): zoom toward the cursor
##                       (or change height, see wheel_changes_height)
##   look_up / look_down / look_left / look_right (right stick): turn the view
##   Right click + drag: rotate the view
## Follow mode (start it with follow(...) from your code):
##   Right click + drag or look_*: orbit around the entity | zoom: distance
##   Any movement key:   stop following
## Mouse-look mode (set_mouse_look(true), used by control modes 2 and 3):
##   the mouse turns the view directly, no click needed, cursor hidden
##   free_cursor (Esc): give the cursor back | again or left click: back to mouse look
## First person (set_first_person(true), used by control mode 3):
##   while following, the camera sits at the entity's eyes (first_person_eye_height)
## Wrap view (WorldWrap.visual, used by control modes 1 and 2):
##   the camera crosses the world's borders seamlessly. Every frame it publishes
##   the global shader value `wrap_center` (Project Settings > Shader Globals, vec3).
## overlay_toggle (H): show / hide the overlay
##
## camera_rise, camera_lower, free_cursor and overlay_toggle aren't in your action list
## yet: until you add them to the Input Map, the keys in () are used.

signal follow_stopped

@export var speed := 10.0                    # world units per second at reference_height
@export var sprint_multiplier := 3.0
@export var mouse_sensitivity := 0.004
@export var stick_look_speed := 2.5          # radians per second with the look actions fully pushed
## Higher camera = faster movement, so the map scrolls at the same speed on screen.
@export var speed_scales_with_height := true
@export var reference_height := 15.0
@export var ground_y := 0.0
@export var min_height := 1.0                # never go below ground_y + min_height

@export_group("Wheel")
## false: zoom goes toward the cursor. true: zoom only changes the height.
@export var wheel_changes_height := false
@export var wheel_step := 0.15               # fraction of the distance to the ground per notch
@export var trackpad_scroll_speed := 0.15    # two-finger scroll (pan gesture) zoom speed
@export var pinch_zoom_speed := 5.0          # trackpad pinch zoom speed

## When false, the movement actions don't move the camera (and don't stop following).
## Turned off by the controller while you control an agent.
@export var move_keys_enabled := true
## Kept for compatibility with older scripts: the mouse is never captured anymore.
var click_to_capture := false

@export_group("Follow")
@export var follow_distance := 6.0
@export var follow_min_distance := 0.5
@export var follow_max_distance := 200.0
@export var follow_distance_step := 1.15
@export var follow_smoothing := 10.0         # higher = sticks tighter to the entity
@export var follow_height_offset := 0.5      # look slightly above the entity's feet
@export var follow_snap_distance := 10.0     # bigger jump (wrap, teleport): snap instead of sliding
## Lowest height above the ground while following: looking up stops at the angle
## where the camera would touch the soil (the distance never changes).
@export var follow_min_height := 0.3
## First person: eye height above the entity's feet. Updated every frame by the controller
## from the agent's size.
@export var first_person_eye_height := 0.8

@export_group("Overlay")
@export var show_overlay := true
@export var overlay_font_size := 12
@export var overlay_opacity := 0.55
@export var overlay_margin := 12

var _yaw := 0.0
var _pitch := 0.0
var _yaw_locked := false                     # true: turning only tilts up/down (control mode 1)
var _mouse_look := false                     # true: the mouse turns the view without a click
var _look_suspended := false                 # free_cursor: cursor given back, mouse look paused
var _first_person := false                   # follow from the entity's eyes
var _dragging := false
var _drag_start := Vector2.ZERO
var _overlay: Label

var _follow_target := Callable()             # returns Vector3, or null when the entity is gone
var _follow_pos := Vector3.ZERO              # smoothed target position


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_overlay()
	_update_overlay()


# --- Public API ----------------------------------------------------------------

## Start following. `target` must return the entity's world position (Vector3),
## or null when it no longer exists (the camera then goes back to fly mode).
func follow(target: Callable) -> void:
	var p = target.call()
	if not (p is Vector3):
		return
	_follow_target = target
	_follow_pos = p
	follow_distance = clampf(global_position.distance_to(p), follow_min_distance, follow_max_distance)
	_update_overlay()


func stop_follow() -> void:
	if not is_following():
		return
	_follow_target = Callable()
	_update_overlay()
	follow_stopped.emit()


func is_following() -> bool:
	return _follow_target.is_valid()


## Lock the horizontal direction (turning then only tilts up/down). yaw = 0 looks north (-Z).
func set_yaw_lock(locked: bool, yaw: float = 0.0) -> void:
	_yaw_locked = locked
	if locked:
		_yaw = yaw
		rotation = Vector3(_pitch, _yaw, 0.0)


## Mouse look: when on, moving the mouse turns the view directly (no right click),
## and the cursor is hidden. Used by control modes 2 and 3.
func set_mouse_look(on: bool) -> void:
	_mouse_look = on
	_look_suspended = false
	_apply_mouse_mode()


## True while the mouse is actually turning the view (on, and not paused with free_cursor).
func is_mouse_look() -> bool:
	return _mouse_look and not _look_suspended


## First person: while following, the camera is placed at the entity's eyes.
func set_first_person(on: bool) -> void:
	_first_person = on
	_update_overlay()


func is_first_person() -> bool:
	return _first_person


## Point the wrap view is centered on: the followed entity, or the camera itself.
## Every agent is drawn at its copy closest to this point, so zooming in or out
## never changes which copy you see.
func get_wrap_center() -> Vector3:
	return _follow_pos if is_following() else global_position


## Kept for compatibility with older scripts.
func set_mouse_captured(_captured: bool) -> void:
	pass


func is_dragging() -> bool:
	return _dragging


func _apply_mouse_mode() -> void:
	if not _dragging:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_look() else Input.MOUSE_MODE_VISIBLE
	_update_overlay()


# --- Action helpers ----------------------------------------------------------------

## Pressed this event: the Input Map action if it exists, else the fallback key.
func _act_pressed(event: InputEvent, action: String, fallback_key: Key) -> bool:
	if InputMap.has_action(action):
		return event.is_action_pressed(action)
	return event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == fallback_key


## How much an action is held (0..1): the Input Map action if it exists, else the fallback key.
func _strength(action: String, fallback_key: Key) -> float:
	if InputMap.has_action(action):
		return Input.get_action_strength(action)
	return 1.0 if Input.is_physical_key_pressed(fallback_key) else 0.0


## Name of the key bound to an action, for the overlay.
func _key(action: String, fallback := "") -> String:
	if not InputMap.has_action(action):
		return fallback
	var e := ConfigurationSettings.get_event(action, ConfigurationSettings.Slot.KEYBOARD_MOUSE)
	if e == null:
		e = ConfigurationSettings.get_event(action, ConfigurationSettings.Slot.CONTROLLER)
	return ConfigurationSettings.event_to_text(e)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _mouse_look and _act_pressed(event, "free_cursor", KEY_ESCAPE):
		_look_suspended = not _look_suspended          # cursor back / mouse look again
		_apply_mouse_mode()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _mouse_look and _look_suspended:
		_look_suspended = false                         # click in the world: mouse look again
		_apply_mouse_mode()
		get_viewport().set_input_as_handled()

	# Right click + drag: rotate the view (or orbit in follow mode).
	# Not needed in mouse-look mode: the mouse already turns the view.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if is_mouse_look():
			pass
		elif event.pressed:
			_dragging = true
			_drag_start = event.position
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # unlimited rotation while dragging
		elif _dragging:
			_dragging = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.warp_mouse(_drag_start)                   # cursor back where the drag started
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and (_dragging or is_mouse_look()):
		_turn(event.relative * mouse_sensitivity)

	# Trackpad, always on: two-finger scroll (sent as a pan gesture on macOS) and pinch
	elif event is InputEventPanGesture:
		_zoom(-event.delta.y * trackpad_scroll_speed, event.position)
		get_viewport().set_input_as_handled()

	elif event is InputEventMagnifyGesture:
		_zoom((event.factor - 1.0) * pinch_zoom_speed, event.position)
		get_viewport().set_input_as_handled()

	# Zoom (or distance in follow mode). Echo allowed: holding a key keeps zooming.
	elif event.is_action_pressed("Camera_zoom_in", true):
		_zoom(_zoom_amount(event), _zoom_point(event))
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("Camera_zoom_out", true):
		_zoom(-_zoom_amount(event), _zoom_point(event))
		get_viewport().set_input_as_handled()

	elif _act_pressed(event, "overlay_toggle", KEY_H):
		show_overlay = not show_overlay
		_overlay.visible = show_overlay


## Turn the view by an amount in radians (x = yaw, y = pitch). Mouse and look actions.
func _turn(amount: Vector2) -> void:
	if not _yaw_locked:
		_yaw -= amount.x
	_pitch -= amount.y
	_pitch = clamp(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	rotation = Vector3(_pitch, _yaw, 0.0)


## One notch = 1. Smooth-scrolling trackpads send many small wheel events (factor < 1).
func _zoom_amount(event: InputEvent) -> float:
	if event is InputEventMouseButton and event.factor > 0.0:
		return minf(event.factor, 1.0)
	return 1.0


## Where to zoom toward: the cursor for mouse events, else the screen center.
func _zoom_point(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	return get_viewport().get_visible_rect().size * 0.5


## direction: +1 = one notch in, -1 = one notch out (fractions for trackpads).
func _zoom(direction: float, mouse_pos: Vector2) -> void:
	if is_following() and _first_person:
		return                                     # no zoom from the eyes
	if is_following():
		follow_distance = clampf(follow_distance / pow(follow_distance_step, direction),
				follow_min_distance, follow_max_distance)
		_update_overlay()
		return

	var height := maxf(global_position.y - ground_y, min_height)
	var step := height * wheel_step
	if wheel_changes_height:
		global_position.y -= direction * step
	else:
		# Move along the ray under the cursor: zooms toward what you point at
		global_position += project_ray_normal(mouse_pos) * direction * step
	global_position.y = maxf(global_position.y, ground_y + min_height)


# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	# Look actions (right stick, arrow keys...): turn the view, like the mouse does
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_turn(look * stick_look_speed * delta)

	_process_move(delta)
	# Shared with every shader that wraps (Project Settings > Shader Globals: wrap_center, vec3)
	RenderingServer.global_shader_parameter_set("wrap_center", get_wrap_center())
	if show_overlay:
		_update_overlay()                          # keys may have been remapped


func _process_move(delta: float) -> void:
	var input := _read_move_input() if move_keys_enabled else Vector3.ZERO

	if is_following():
		if input != Vector3.ZERO:
			stop_follow()                          # any movement key leaves follow mode
		else:
			_process_follow(delta)
			return

	if input == Vector3.ZERO:
		_wrap_camera()                             # the zoom may have moved it
		return

	# Move on a plane parallel to the ground, relative to where the camera faces
	var b := global_transform.basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z)
	if fwd.length_squared() < 1e-4:
		fwd = Vector3(b.y.x, 0.0, b.y.z)           # looking straight down: "up" on screen
	fwd = fwd.normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()

	var dir := (right * input.x + fwd * (-input.z)).limit_length(1.0)   # analog on a stick
	dir.y = input.y

	var current_speed := speed
	if speed_scales_with_height:
		var height := maxf(global_position.y - ground_y, min_height)
		current_speed *= clampf(height / reference_height, 0.2, 20.0)
	if Input.is_action_pressed("sprint"):
		current_speed *= sprint_multiplier

	global_position += dir * current_speed * delta
	global_position.y = maxf(global_position.y, ground_y + min_height)
	_wrap_camera()


func _process_follow(delta: float) -> void:
	var p = _follow_target.call()
	if not (p is Vector3):
		stop_follow()                              # entity gone: back to fly mode, camera stays here
		return

	# First person: exactly at the eyes, no smoothing (smoothing feels like lag from inside)
	if _first_person:
		_follow_pos = p
		global_position = p + Vector3.UP * first_person_eye_height
		return

	# Through the border if the wrap view is on: the camera never sweeps across the world
	p = WorldWrap.nearest_image(p, _follow_pos)
	if p.distance_to(_follow_pos) > follow_snap_distance:
		_follow_pos = p                            # teleported: snap instead of sliding
	else:
		_follow_pos = _follow_pos.lerp(p, 1.0 - exp(-follow_smoothing * delta))

	# Keep the followed point inside the world. The camera is placed from it below,
	# so it moves along automatically: invisible on screen, and zoom never wraps anything.
	if WorldWrap.view_enabled():
		var y := _follow_pos.y
		_follow_pos = WorldWrap.wrap_into(_follow_pos)
		_follow_pos.y = y

	# Orbit: stay behind the look direction, at follow_distance from the entity
	var center := _follow_pos + Vector3.UP * follow_height_offset
	var floor_y := ground_y + follow_min_height

	# Looking up lowers the camera: stop the angle where it would touch the soil.
	# Camera height = center.y - sin(pitch) * distance, so sin(pitch) <= (center.y - floor) / distance
	var s := clampf((center.y - floor_y) / maxf(follow_distance, 0.001), -1.0, 1.0)
	var max_pitch := minf(asin(s), deg_to_rad(89.0))
	if _pitch > max_pitch:
		_pitch = max_pitch
		rotation = Vector3(_pitch, _yaw, 0.0)

	global_position = center + global_transform.basis.z * follow_distance
	global_position.y = maxf(global_position.y, floor_y)   # safety net


## Keeps the free-flying camera inside the world on wrapped axes (x / z only, never
## its height), only while the wrap view is on. Returns how much the camera was moved.
func _wrap_camera() -> Vector3:
	if not WorldWrap.view_enabled():
		return Vector3.ZERO
	var before := global_position
	var after := WorldWrap.wrap_into(before)
	after.y = before.y
	if after == before:
		return Vector3.ZERO
	global_position = after
	return after - before


## x = right, y = up, z = backward (-z = forward). Analog values on a stick.
func _read_move_input() -> Vector3:
	var input := Vector3.ZERO
	input.x = Input.get_axis("left", "right")
	input.z = Input.get_axis("up", "down")
	input.y = _strength("camera_rise", KEY_E) - _strength("camera_lower", KEY_Q)
	return input


# --- Overlay -----------------------------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_overlay = Label.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Anchor to the bottom-right corner and grow up/left from there
	_overlay.anchor_left = 1.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_top = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.offset_left = -overlay_margin
	_overlay.offset_right = -overlay_margin
	_overlay.offset_top = -overlay_margin
	_overlay.offset_bottom = -overlay_margin
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# Discreet look: small, semi-transparent, light shadow for readability
	_overlay.add_theme_font_size_override("font_size", overlay_font_size)
	_overlay.add_theme_color_override("font_color", Color(1, 1, 1, overlay_opacity))
	_overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, overlay_opacity * 0.8))
	_overlay.add_theme_constant_override("shadow_offset_x", 1)
	_overlay.add_theme_constant_override("shadow_offset_y", 1)
	_overlay.add_theme_constant_override("line_spacing", 1)

	_overlay.visible = show_overlay
	layer.add_child(_overlay)


func _update_overlay() -> void:
	if _overlay == null:
		return
	var free_key := _key("free_cursor", "Esc")
	var hide_line := "%s  hide" % _key("overlay_toggle", "H")
	if is_following() and _first_person:
		_overlay.text = "\n".join([
			"First person",
			("Mouse  look around   %s  free cursor" % free_key if is_mouse_look()
					else "%s / click  mouse look" % free_key),
			hide_line,
		])
		return
	if is_following():
		_overlay.text = "\n".join([
			"Following",
			("Mouse  look around   %s  free cursor" % free_key if is_mouse_look()
					else ("%s / click  mouse look" % free_key if _mouse_look else "Right drag  orbit")),
			"%s / %s  distance %.1f" % [_key("camera_zoom_in"), _key("camera_zoom_out"),
					follow_distance],
			hide_line,
		])
		return

	var move := PackedStringArray([_key("up"), _key("left"), _key("down"), _key("right")])
	var short := true
	for k in move:
		short = short and k.length() == 1
	_overlay.text = "\n".join([
		"%s  move" % ("" if short else " ").join(move),
		"%s / %s  up / down" % [_key("camera_rise", "E"), _key("camera_lower", "Q")],
		"%s  faster" % _key("sprint"),
		"%s / %s  zoom" % [_key("camera_zoom_in"), _key("camera_zoom_out")],
		"Right drag  rotate view",
		hide_line,
	])
