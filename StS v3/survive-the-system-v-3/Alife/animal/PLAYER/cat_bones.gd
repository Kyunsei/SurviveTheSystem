extends RigidBody3D
var target_position = Vector3(0,0,0)
var moving_bones = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rotation_degrees.y = randf_range(0.0, 360.0)
	linear_velocity = Vector3.ZERO
	$CollisionShape3D.disabled = true
	gravity_scale = 0
	target_position = Vector3(global_position.x,-0.05, global_position.z)
	await get_tree().create_timer(5.0).timeout
	moving_bones = false
	$CollisionShape3D.disabled = false
	gravity_scale = 1.0
	mass = 100.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta) :
	if global_position.y >= -0.05 and moving_bones == true:
		position = position.move_toward(target_position,8*delta)
