extends CharacterBody3D


@export var speed = 500
@export var gravity = 1000
@export var fly = false
var crouched = false
var gonna_jump = false
var direction = Vector3(0,0,0)


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	if is_multiplayer_authority():
		%Camera3D.current = true

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		velocity.x = direction.x *speed *delta
		velocity.z = direction.z *speed *delta
		if fly:
			velocity.y = direction.y *speed *delta

		'if not is_on_floor():
			velocity.y -= gravity * delta'
		if direction != Vector3(0,0,0):
			$MeshInstance3D.rotation.y = $camera_anchor.rotation.y 
			pass
			#var target_yaw := atan2(direction.x, -direction.z)
		move_and_slide()
