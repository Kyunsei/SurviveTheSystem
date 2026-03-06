extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	linear_velocity = Vector3.ZERO
		#$CollisionShape3D.disabled = true
		#gravity_scale = 0
		#mass = 0
		#await get_tree().create_timer(0.5).timeout
		#$CollisionShape3D.disabled = false
		#gravity_scale = 1.0
		#mass = 100.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
