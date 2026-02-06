extends CharacterBody3D


@export var speed = 500
var direction = Vector3(0,0,0)


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	if is_multiplayer_authority():
		$Camera3D.current = true

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		velocity = direction *speed *delta
		move_and_slide()
