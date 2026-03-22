extends AnimatableBody3D
#VERSION WITH MOVE TOWARD
@export var move_distance: float = 90.0
@export var move_speed: float = 10.0
var collector 

var start_position: Vector3
var target_position: Vector3
var collector_grabbed := false
var collector_init_position
var collector_moving = false
var collector_target_position
var moving := false

'func _ready():
	return
	if multiplayer.is_server():
		collector = get_parent().get_parent().get_node("Collector")
		collector_init_position = collector.global_position
		start_position = global_position
		target_position = start_position 
		collector_target_position = start_position -Vector3(1,2,0)'


'func _physics_process(_delta):
	return
	if multiplayer.is_server():
		if collector_moving:
			collector.global_position = collector.global_position.move_toward(collector_init_position, move_speed*2 * delta)
			if collector.global_position.distance_to(collector_init_position) <0.01:
				collector_moving = false
		if not moving:
			return
		
		global_position = global_position.move_toward(target_position, move_speed * delta)
		if collector_grabbed == true:
			collector.global_position = collector.global_position.move_toward(collector_target_position, move_speed * delta)
		# Stop when reached
		if global_position.distance_to(target_position) < 0.01:
			global_position = target_position
			moving = false
			if collector_grabbed:	
				collector_grabbed =false		
				await get_tree().create_timer(8.0).timeout
				collector_moving = true'





# 🔽 Call this to move platform down
func go_down():
	return
	if multiplayer.is_server():
		if moving:
			return
		
		if global_position == start_position:
			target_position = collector.global_position + Vector3(1,2,0)
			moving = true


	# 🔼 Call this to move platform up (only if fully down)
func go_up():
	return
	print("pressed")
	if multiplayer.is_server():
		if moving:
			return
		
		var down_position = collector.global_position + Vector3(1,2,0)
		collector_grabbed = true
		if global_position == down_position:
			target_position = start_position
			moving = true

			
