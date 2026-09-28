extends Node3D
## First/third-person walker for the 3D explorer. There are no physics
## colliders (the terrain lives on the GPU), so the player follows the height map
## directly. It can swim, and it can spectate an agent (orbit camera).

const Meshes := preload("res://scripts/meshes.gd")

const EYE := 1.65
const WALK := 6.0
const SPRINT := 15.0
const JUMP := 7.5
const GRAVITY := 20.0
const SWIM_Y := -1.2 ## body height when floating in a lake
const MOUSE_SENS := 0.0025

var height_at: Callable ## (x, z) -> ground height in metres
var world_size := 2048.0
var first_person := false
var spectating := false
var spectate_target := Vector3.ZERO ## set every frame while spectating
var spectate_size := 1.0
var yaw := 0.0
var pitch := -0.25
var horizontal_speed := 0.0 ## m/s, for the agents' escape odds
var swimming := false

var cam: Camera3D
var _body: Node3D
var _vel_y := 0.0
var _on_ground := true
var _orbit := 5.0


func _ready() -> void:
	_body = Meshes.player_body()
	add_child(_body)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.far = 1200.0
	add_child(cam)
	cam.top_level = true
	cam.make_current()


func spawn(p: Vector3) -> void:
	position = p
	_vel_y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * MOUSE_SENS
		pitch = clampf(pitch - m.relative.y * MOUSE_SENS, -1.5, 1.4)
	elif event is InputEventMouseButton and event.pressed and not first_person:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit = maxf(_orbit * 0.9, 2.0)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit = minf(_orbit * 1.1, 120.0)


func _process(delta: float) -> void:
	if height_at.is_null():
		return
	if spectating:
		# Stay with the followed agent (the target is already unwrapped near us).
		position = position.lerp(spectate_target, 1.0 - exp(-8.0 * delta))
		horizontal_speed = 0.0
	else:
		_walk(delta)
	_wrap()
	_update_camera()


func _walk(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.x = float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT))
		input.y = float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP))
	var ground: float = height_at.call(position.x, position.z)
	swimming = ground < SWIM_Y + 0.3
	var speed := SPRINT if _key(KEY_SHIFT) else WALK
	if swimming:
		speed *= 0.45
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var move := (right * input.x - fwd * input.y).normalized() * speed
	position += move * delta
	horizontal_speed = move.length()
	if move.length() > 0.1:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-move.x, -move.z), 1.0 - exp(-12.0 * delta))

	var floor_y := maxf(height_at.call(position.x, position.z), SWIM_Y)
	if _on_ground and _key(KEY_SPACE) and not swimming:
		_vel_y = JUMP
		_on_ground = false
	_vel_y -= GRAVITY * delta
	position.y += _vel_y * delta
	if position.y <= floor_y:
		position.y = floor_y
		_vel_y = 0.0
		_on_ground = true


## The world is a torus: keep the player inside [0, world_size).
func _wrap() -> void:
	var w := world_size
	var shift := Vector3(-floor(position.x / w) * w, 0, -floor(position.z / w) * w)
	if shift != Vector3.ZERO:
		position += shift
		spectate_target += shift


func _update_camera() -> void:
	var look := Basis.from_euler(Vector3(pitch, yaw, 0))
	_body.visible = not first_person and not spectating
	if first_person and not spectating:
		cam.global_transform = Transform3D(look, position + Vector3(0, EYE, 0))
		return
	var pivot := position + Vector3(0, 1.4 if not spectating else 0.6 + spectate_size * 0.6, 0)
	var dist := _orbit if not spectating else _orbit * 0.5 + spectate_size * 2.0
	var pos := pivot + look * Vector3(0, 0, dist)
	pos.y = maxf(pos.y, height_at.call(pos.x, pos.z) + 0.4)
	pos.y = maxf(pos.y, 0.3) # stay above the water surface
	cam.global_transform = Transform3D(Basis.looking_at(pivot - pos), pos)


func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)
