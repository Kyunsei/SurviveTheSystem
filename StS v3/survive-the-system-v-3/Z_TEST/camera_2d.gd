extends Camera2D

@export var pan_speed := 800.0      # pixels/sec at zoom 1
@export var zoom_step := 1.1
@export var min_zoom := 0.05
@export var max_zoom := 10.0
@export var smooth := 12.0          # 0 = instant

var _target_zoom := 1.0

func _ready() -> void:
	_target_zoom = zoom.x

func _process(delta: float) -> void:
	# Keyboard pan (arrows via ui_*, plus WASD)
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.limit_length(1.0) * pan_speed * delta / zoom.x

	# Smooth zoom toward cursor
	if not is_equal_approx(zoom.x, _target_zoom):
		var z := _target_zoom if smooth <= 0.0 else lerpf(zoom.x, _target_zoom, 1.0 - exp(-smooth * delta))
		_zoom_at_mouse(z)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom * zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom / zoom_step, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		position -= event.relative / zoom.x

func _zoom_at_mouse(new_zoom: float) -> void:
	# Keep the world point under the cursor fixed while zooming
	var offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	var world_under_mouse := position + offset / zoom.x
	zoom = Vector2.ONE * new_zoom
	position = world_under_mouse - offset / new_zoom
