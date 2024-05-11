extends CharacterBody2D

var input_dir = Vector2.ZERO
var speed = 200


var attaque_scene = load("res://Scenes/attaque.tscn") #load scene of block

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
	if Input.is_action_pressed("attaque"):
		attaque(input_dir)

	velocity = input_dir.normalized() * speed 
	move_and_collide(velocity *delta)
	position.x = clamp(position.x, 0, World.world_size*World.tile_size)
	position.y = clamp(position.y, 0, World.world_size*World.tile_size)

func attaque(dir):
		var new_atk = attaque_scene.instantiate()
		new_atk.name = "Attaque"

		new_atk.position.x += 32 * dir[0]
		new_atk.rotation = 0
		if dir[1] <0 :
			new_atk.position.y += 64 * dir[1]
		add_child(new_atk)
		
	
	
