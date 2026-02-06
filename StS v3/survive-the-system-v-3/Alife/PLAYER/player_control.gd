extends Node
class_name player_control

var player : Node3D

var direction = Vector3(0,0,0)

func _ready() -> void:
	player = get_parent()
	

func _physics_process(delta: float) -> void:
	direction = Vector3(0,0,0)
	if is_multiplayer_authority():
		if Input.is_action_pressed("down"):
			direction.z = 1
		if Input.is_action_pressed("up"):
			direction.z = -1
		if Input.is_action_pressed("right"):
			direction.x = 1
		if Input.is_action_pressed("left"):
			direction.x = -1	
		if direction != Vector3.ZERO:
			direction = direction.normalized()
		
		player.direction = direction
