extends AnimatableBody3D

@export var move_distance: float = 20.0
@export var move_speed: float = 2

var start_position: Vector3
var direction := 1.0

func _ready():
	start_position = global_position

func _physics_process(delta):
	global_position.y += direction * move_speed * delta
	
	# Moving up
	if direction > 0 and global_position.y >= start_position.y + move_distance:
		global_position.y = start_position.y + move_distance
		direction = -1.0
	
	# Moving down
	elif direction < 0 and global_position.y <= start_position.y:
		global_position.y = start_position.y
		direction = 1.0
