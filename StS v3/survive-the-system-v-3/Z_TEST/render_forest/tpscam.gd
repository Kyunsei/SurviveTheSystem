class_name TPSPlayer
extends CharacterBody3D
## Third-person character + orbit camera, built entirely from code.
## Controls: WASD / arrows = move, Shift = sprint, Space = jump,
## mouse = look, wheel = zoom, Esc = free mouse, click = capture mouse.

@export var walk_speed := 5.0
@export var sprint_speed := 11.0
@export var jump_velocity := 5.5
@export var acceleration := 12.0
@export var turn_speed := 10.0
@export var mouse_sensitivity := 0.0025
@export var camera_distance := 5.0
@export var min_zoom := 1.5
@export var max_zoom := 14.0
@export var min_pitch_deg := -75.0
@export var max_pitch_deg := 35.0

## Text shown in the HUD (set by the forest script).
var hud_title := ""
var hud_info := ""

var _model: Node3D
var _pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _hud: Label
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _pitch := deg_to_rad(-20.0)
var _spawn := Vector3.ZERO


func _ready() -> void:
	_spawn = global_position
	_build_body()
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_camera() -> Camera3D:
	return _camera


# ---------------------------------------------------------------- building

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	# Visual model lives in its own node so it can turn without turning the camera.
	_model = Node3D.new()
	add_child(_model)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.35, 0.2)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	body.material_override = body_mat
	body.position.y = 0.9
	_model.add_child(body)

	# A visor so you can see which way the character faces (-Z = forward).
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.1, 0.12, 0.15)
	visor_mat.roughness = 0.2
	var visor := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.18, 0.25)
	visor.mesh = bm
	visor.material_override = visor_mat
	visor.position = Vector3(0, 1.45, -0.3)
	_model.add_child(visor)


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.6, 0)
	add_child(_pivot)

	_spring = SpringArm3D.new()
	_spring.spring_length = camera_distance
	_spring.margin = 0.2
	var s := SphereShape3D.new()
	s.radius = 0.25
	_spring.shape = s
	_spring.add_excluded_object(get_rid())
	_spring.rotation.x = _pitch
	_pivot.add_child(_spring)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 500.0
	_spring.add_child(_camera)
	_camera.current = true


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(_hud)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity,
				deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		_spring.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera_distance = maxf(min_zoom, camera_distance - 0.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera_distance = minf(max_zoom, camera_distance + 0.5)
			_:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


# ---------------------------------------------------------------- movement

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	var right_in := maxf(_key(KEY_D), _key(KEY_RIGHT)) - maxf(_key(KEY_A), _key(KEY_LEFT))
	var fwd_in := maxf(_key(KEY_W), _key(KEY_UP)) - maxf(_key(KEY_S), _key(KEY_DOWN))

	# Move relative to where the camera looks, flattened on the ground.
	var cam_basis := _pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := right * right_in + forward * fwd_in
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	var speed := sprint_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	var target := dir * speed
	var t := clampf(acceleration * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target.x, t)
	velocity.z = lerpf(velocity.z, target.z, t)

	if dir.length_squared() > 0.001:
		var yaw := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))

	move_and_slide()

	if global_position.y < -30.0:
		global_position = _spawn
		velocity = Vector3.ZERO


func _process(delta: float) -> void:
	_spring.spring_length = lerpf(_spring.spring_length, camera_distance, clampf(10.0 * delta, 0.0, 1.0))
	_hud.text = "%s\nFPS: %d   (%.2f ms)\nDraw calls: %d\nPrimitives: %s\n%s\n\n%s" % [
		hud_title,
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		String.num_int64(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
		hud_info,
		"WASD move  Shift sprint  Space jump  Wheel zoom  T shadows  Esc mouse",
	]
