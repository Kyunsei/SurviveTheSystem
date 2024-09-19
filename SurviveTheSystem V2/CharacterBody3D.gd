extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	'if not is_on_floor():
		velocity.y -= gravity * delta'

	# Handle jump.
	'if Input.is_action_just_pressed("interact") and is_on_floor():
		velocity.y = JUMP_VELOCITY'

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	print(input_dir)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _input(event):
		if event.is_action_pressed("zoom_in"):
			if rotate_x == false and rotate_y == false:
				$Node3D/Camera3D.position.z += 0.1 *3
				$Node3D/Camera3D.position.y += 0.1 *2
			elif rotate_x:
				$Node3D.rotation.x += 0.1
				#rotation.x += 0.2
			elif rotate_y:
				#$Node3D.rotation.y += 0.2
				rotation.y += 0.1

		if event.is_action_pressed("zoom_out"):
			if rotate_x == false and rotate_y == false:
				$Node3D/Camera3D.position.z -= 0.1 *3
				$Node3D/Camera3D.position.y -= 0.1 *2
			elif rotate_x:
				$Node3D.rotation.x -= 0.1
				#rotation.x -= 0.2
			elif rotate_y:
				#$Node3D.rotation.y -= 0.2
				rotation.y -= 0.1
		if event.is_action_pressed("shift") :
			if rotate_x == false:
				rotate_x = true
			else:
				rotate_x = false
			
		if event.is_action_pressed("alt") :
			if rotate_y == false:
				rotate_y = true
			else:
				rotate_y = false	

var rotate_x = false
var rotate_y = false
