extends Node
class_name player_control

var player : Node3D

var direction = Vector3(0,0,0)


func _ready() -> void:
	player = get_parent()
	

func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		direction = Vector3(0,0,0)
		#print("yes")
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
