extends CharacterBody2D

var input_dir = Vector2.ZERO
var speed = 400

func _physics_process(delta):
	input_dir = Vector2.ZERO
	if Input.is_action_pressed("left") :
		input_dir.x -= 1
	if Input.is_action_pressed("right"):
		input_dir.x += 1
	if Input.is_action_pressed("up"):
		input_dir.y -= 1
	if Input.is_action_pressed("down"):
		input_dir.y += 1

	velocity = input_dir.normalized() * speed 
	move_and_collide(velocity *delta)
	position.x = clamp(position.x, 0, World.world_size*World.tile_size)
	position.y = clamp(position.y, 0, World.world_size*World.tile_size)
