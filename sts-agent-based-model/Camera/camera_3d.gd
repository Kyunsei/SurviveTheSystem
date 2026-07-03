extends Camera3D

@export var camera_speed: float = 5.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0
@export var speed_scroll_step: float = 0.5
@export var min_speed: float = 0.5
@export var max_speed: float = 50.0

var mouse_captured = false
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	pitch = rotation.x

func _process(delta: float) -> void:
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("back"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("right"):
		input_dir += transform.basis.x
	if Input.is_action_pressed("left"):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_E):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		input_dir -= Vector3.UP

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	var speed = camera_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier

	position += input_dir * speed * delta

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true

	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		rotation.x = pitch

	if event is InputEventMouseButton and mouse_captured:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_speed = clamp(camera_speed + speed_scroll_step, min_speed, max_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_speed = clamp(camera_speed - speed_scroll_step, min_speed, max_speed)
