class_name FlyCamera
extends Camera3D
## Map-style camera (Godot 4): the mouse is always visible.
##
## Fly mode:
##   WASD:               move parallel to the ground (relative to where the camera faces)
##   E / Q:              up / down
##   Shift:              faster
##   Wheel:              zoom toward the cursor (or change height, see wheel_changes_height)
##   Right click + drag: rotate the view
## Follow mode (start it with follow(...) from your code):
##   Right click + drag: orbit around the entity | Wheel: distance
##   WASD / E / Q:       stop following
## H: show / hide the overlay
## Keys use physical positions, so WASD works on QWERTY, AZERTY and QWERTZ layouts.

signal follow_stopped

@export var speed := 10.0                    # world units per second at reference_height
@export var sprint_multiplier := 3.0
@export var mouse_sensitivity := 0.004
## Higher camera = faster movement, so the map scrolls at the same speed on screen.
@export var speed_scales_with_height := true
@export var reference_height := 15.0
@export var ground_y := 0.0
@export var min_height := 1.0                # never go below ground_y + min_height

@export_group("Wheel")
## false: the wheel zooms toward the cursor. true: the wheel only changes the height.
@export var wheel_changes_height := false
@export var wheel_step := 0.15               # fraction of the distance to the ground per notch

## When false, WASD / E / Q / Ctrl / Space don't move the camera (and don't stop following).
## Turned off by the picker while you control an agent.
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

@export_group("Overlay")
@export var show_overlay := true
@export var overlay_font_size := 12
@export var overlay_opacity := 0.55
@export var overlay_margin := 12

var _yaw := 0.0
var _pitch := 0.0
var _yaw_locked := false                     # true: dragging only tilts up/down (control mode 1)
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


## Lock the horizontal direction (dragging then only tilts up/down). yaw = 0 looks north (-Z).
func set_yaw_lock(locked: bool, yaw: float = 0.0) -> void:
	_yaw_locked = locked
	if locked:
		_yaw = yaw
		rotation = Vector3(_pitch, _yaw, 0.0)


## Kept for compatibility with older scripts: the mouse is always visible now.
func set_mouse_captured(_captured: bool) -> void:
	pass


func is_dragging() -> bool:
	return _dragging


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Right click + drag: rotate the view (or orbit in follow mode)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # unlimited rotation while dragging
		elif _dragging:
			_dragging = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.warp_mouse(_drag_start)                   # cursor back where the drag started
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		if not _yaw_locked:
			_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation = Vector3(_pitch, _yaw, 0.0)

	# Wheel: zoom (or distance in follow mode)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.0, event.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(-1.0, event.position)
				get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		show_overlay = not show_overlay
		_overlay.visible = show_overlay


func _zoom(direction: float, mouse_pos: Vector2) -> void:
	if is_following():
		if direction > 0.0:
			follow_distance = maxf(follow_distance / follow_distance_step, follow_min_distance)
		else:
			follow_distance = minf(follow_distance * follow_distance_step, follow_max_distance)
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
	var input := _read_move_input() if move_keys_enabled else Vector3.ZERO

	if is_following():
		if input != Vector3.ZERO:
			stop_follow()                          # any movement key leaves follow mode
		else:
			_process_follow(delta)
			return

	if input == Vector3.ZERO:
		return

	# Move on a plane parallel to the ground, relative to where the camera faces
	var b := global_transform.basis
	var fwd := Vector3(-b.z.x, 0.0, -b.z.z)
	if fwd.length_squared() < 1e-4:
		fwd = Vector3(b.y.x, 0.0, b.y.z)           # looking straight down: "up" on screen
	fwd = fwd.normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()

	var dir := right * input.x + fwd * (-input.z)
	if dir != Vector3.ZERO:
		dir = dir.normalized()
	dir.y = input.y

	var current_speed := speed
	if speed_scales_with_height:
		var height := maxf(global_position.y - ground_y, min_height)
		current_speed *= clampf(height / reference_height, 0.2, 20.0)
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed *= sprint_multiplier

	global_position += dir * current_speed * delta
	global_position.y = maxf(global_position.y, ground_y + min_height)


func _process_follow(delta: float) -> void:
	var p = _follow_target.call()
	if not (p is Vector3):
		stop_follow()                              # entity gone: back to fly mode, camera stays here
		return

	if p.distance_to(_follow_pos) > follow_snap_distance:
		_follow_pos = p                            # wrapped / teleported: don't sweep across the world
	else:
		_follow_pos = _follow_pos.lerp(p, 1.0 - exp(-follow_smoothing * delta))

	# Orbit: stay behind the look direction, at follow_distance from the entity
	var center := _follow_pos + Vector3.UP * follow_height_offset
	global_position = center + global_transform.basis.z * follow_distance


func _read_move_input() -> Vector3:
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): input.y -= 1.0
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
	if is_following():
		_overlay.text = "\n".join([
			"Following",
			"Right drag  orbit",
			"Wheel  distance %.1f" % follow_distance,
			"WASD  stop following",
			"H  hide",
		])
		return
	_overlay.text = "\n".join([
		"WASD  move",
		"E / Q  up / down",
		"Shift  faster",
		"Wheel  zoom",
		"Right drag  rotate view",
		"H  hide",
	])
