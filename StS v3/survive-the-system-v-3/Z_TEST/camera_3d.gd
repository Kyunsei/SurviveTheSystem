class_name RTSCamera3D
extends Camera3D

@export var target := Vector3.ZERO      # point on the ground the camera looks at
@export var distance := 800.0
@export var min_distance := 5.0
@export var max_distance := 5000.0
@export var yaw := 0.0                  # degrees, rotation around the vertical axis
@export var pitch := -55.0              # degrees, negative = looking down
@export var min_pitch := -89.0
@export var max_pitch := -5.0
@export var move_speed := 1.0           # relative to zoom: zoomed out = faster
@export var rotate_speed := 0.3         # degrees per pixel of mouse movement
@export var key_rotate_speed := 90.0    # degrees per second for Q/E
@export var zoom_step := 1.15

var _orbiting := false
var _panning := false


func _ready() -> void:
	far = max_distance * 4.0
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					distance = maxf(min_distance, distance / zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					distance = minf(max_distance, distance * zoom_step)
			MOUSE_BUTTON_RIGHT:
				_orbiting = event.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed

	elif event is InputEventMouseMotion:
		if _orbiting:
			yaw -= event.relative.x * rotate_speed
			pitch = clampf(pitch - event.relative.y * rotate_speed, min_pitch, max_pitch)
		elif _panning:
			var s := distance * 0.0015
			_pan(Vector2(-event.relative.x, -event.relative.y) * s)

	_apply()


func _process(delta: float) -> void:
	if not current:
		return

	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0

	if dir != Vector2.ZERO:
		var speed := distance * move_speed * delta
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 3.0
		_pan(dir.normalized() * speed)

	if Input.is_key_pressed(KEY_Q): yaw += key_rotate_speed * delta
	if Input.is_key_pressed(KEY_E): yaw -= key_rotate_speed * delta

	_apply()


# Move the target along the ground, relative to where the camera is facing
func _pan(v: Vector2) -> void:
	var flat := Basis(Vector3.UP, deg_to_rad(yaw))
	var right := flat * Vector3.RIGHT
	var forward := flat * Vector3.FORWARD
	target += right * v.x - forward * v.y


# Place the camera on a sphere around the target, looking at it
func _apply() -> void:
	var rot := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	global_transform = Transform3D(rot, target + rot * Vector3(0.0, 0.0, distance))


# Frame the whole world (call it when switching to 3D)
func frame_world(world_min: Vector2, world_max: Vector2) -> void:
	target = Vector3((world_min.x + world_max.x) * 0.5, 0.0, (world_min.y + world_max.y) * 0.5)
	distance = clampf(maxf(world_max.x - world_min.x, world_max.y - world_min.y), min_distance, max_distance)
	_apply()
