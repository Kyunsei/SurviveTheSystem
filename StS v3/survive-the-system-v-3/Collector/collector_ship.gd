extends AnimatableBody3D

@export var move_distance: float = 90.0
@export var move_speed: float = 10.0

var start_position: Vector3
var target_position: Vector3
var moving := false

func _ready():
	start_position = global_position
	target_position = start_position 


func _physics_process(delta):
	if not moving:
		return
	
	global_position = global_position.move_toward(target_position, move_speed * delta)
	
	# Stop when reached
	if global_position.distance_to(target_position) < 0.01:
		global_position = target_position
		moving = false


# 🔽 Call this to move platform down
func go_down():
	if moving:
		return
	
	if global_position == start_position:
		target_position = start_position - Vector3(0, move_distance, 0)
		moving = true


# 🔼 Call this to move platform up (only if fully down)
func go_up():
	if moving:
		return
	
	var down_position = start_position - Vector3(0, move_distance, 0)
	
	if global_position == down_position:
		target_position = start_position
		moving = true
