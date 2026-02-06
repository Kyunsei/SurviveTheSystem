extends CharacterBody3D


@export var speed = 100
var direction = Vector3(0,0,0)


func _physics_process(delta: float) -> void:
	velocity = direction *speed*delta
	move_and_slide()
