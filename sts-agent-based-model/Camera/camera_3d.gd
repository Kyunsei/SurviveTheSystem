extends Camera3D


var mouse_captured = false
@export var camera_speed = 5






func _ready() -> void:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_pressed("forward"):
		position.z -= camera_speed
	if Input.is_action_pressed("back"):
		position.z += camera_speed
	if Input.is_action_pressed("right"):
		position.x += camera_speed
	if Input.is_action_pressed("left"):
		position.x -= camera_speed
	if Input.is_action_pressed("up"):
		position.y += camera_speed
	if Input.is_action_pressed("down"):
		position.y -= camera_speed



		
			
func _input(event):
		if event.is_action_pressed("ui_cancel"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				mouse_captured = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				mouse_captured = true
