class_name FlyCamera
extends Camera3D
## FPS-style free-fly camera (Godot 4) with a small controls overlay (bottom right).
## Mouse: look around | WASD: move | E / Space: up | Q / Ctrl: down
## Shift: sprint | Mouse wheel: change speed | Esc: release mouse | Left click: capture mouse
## H: show / hide the controls overlay
## Keys use physical positions, so WASD works on QWERTY, AZERTY and QWERTZ layouts.

@export var speed := 10.0
@export var sprint_multiplier := 3.0
@export var mouse_sensitivity := 0.002
@export var speed_step := 1.2
@export var min_speed := 0.5
@export var max_speed := 500.0

@export_group("Overlay")
@export var show_overlay := true
@export var overlay_font_size := 12
@export var overlay_opacity := 0.55
@export var overlay_margin := 12

var _yaw := 0.0
var _pitch := 0.0
var _overlay: Label


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	_build_overlay()
	_set_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	# Look around
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation = Vector3(_pitch, _yaw, 0.0)

	# Mouse buttons: capture + speed control
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_set_captured(true)
			MOUSE_BUTTON_WHEEL_UP:
				speed = min(speed * speed_step, max_speed)
				_update_overlay()
			MOUSE_BUTTON_WHEEL_DOWN:
				speed = max(speed / speed_step, min_speed)
				_update_overlay()

	# Keys: release mouse / toggle overlay
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_set_captured(false)
			KEY_H:
				show_overlay = not show_overlay
				_overlay.visible = show_overlay


func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL): input.y -= 1.0

	if input == Vector3.ZERO:
		return

	# Forward/strafe follow where the camera looks (fly mode), up/down is world vertical
	var dir := global_transform.basis * Vector3(input.x, 0.0, input.z)
	dir.y += input.y
	dir = dir.normalized()

	var current_speed := speed
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed *= sprint_multiplier

	global_position += dir * current_speed * delta


func _set_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	_update_overlay()


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
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_overlay.text = "Click to control camera\nH  hide"
		return
	_overlay.text = "\n".join([
		"WASD  move",
		"E / Q  up / down",
		"Shift  sprint",
		"Wheel  speed %.1f" % speed,
		"Esc  release mouse",
		"H  hide",
	])
