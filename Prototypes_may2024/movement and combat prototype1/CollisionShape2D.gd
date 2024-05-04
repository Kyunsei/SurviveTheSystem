extends CollisionShape2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.





signal shoot(plasma_scene, direction, location)

var plasma_scene = preload("res://plasma_scene.tscn")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shoot.emit(plasma_scene, rotation, position)

func _process(delta):
	look_at(get_global_mouse_position())


func _on_shoot(plasma_scene, direction, location):
	var plasma = plasma_scene.instantiate()
	add_child(plasma)
	plasma.rotation = direction
	plasma.position = location
	plasma.velocity = plasma.velocity.rotated(direction)
