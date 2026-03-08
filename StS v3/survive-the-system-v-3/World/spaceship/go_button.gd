extends Node3D
var currently_active = false
var moving_wall_initial_position 
var moving_ground_initial_position 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	moving_wall_initial_position = $"../ship/moving_wall1".position
	moving_ground_initial_position = $"../ship/moving_ground1".position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	pass
		
		
func interacting():
	if currently_active == false:
		currently_active = true
		print("you pushed the button")
		$"../ship/moving_wall1".position.y -= 3
		$"../ship/moving_ground1".position.z += 10
		await get_tree().create_timer(2.0).timeout
		$"../ship/moving_wall1".position = moving_wall_initial_position
		$"../ship/moving_ground1".position = moving_ground_initial_position
		await get_tree().create_timer(0.2).timeout
		currently_active = false
		
		
