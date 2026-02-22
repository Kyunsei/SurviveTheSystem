extends Camera3D

var player : Node3D
var pitch : float = 0.0
var mouse_captured = false
@export var min_pitch : float = deg_to_rad(-40)
@export var max_pitch : float = deg_to_rad(40)
@export var mouse_sensitivity = 0.002

@export var camera_speed = 5
@export var camera_zoom_speed = 50


@export var pitch_anchor : Node3D
@export var yaw_anchor : Node3D

#@export var turn_speed = 8.0
#@export var smooth := 10.0


#How the camera works?
#Yaw is rotate in Y ( left right)
#pitch is rotate in X (up, down)

#we can change view point with zoom : top view - 3rd person - 1st person
#top view: central to player, arrow can create offset or mouse position
#3rd person: mouse move camera, and direction input (like up is always in fornt of camera)
#Arrow can also offset the camera
#First view: same but more angle possible?




func _ready() -> void:
	
	player = get_parent().get_parent()
	if player.is_multiplayer_authority():

		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player.is_multiplayer_authority():
		if Input.is_action_pressed("Camera_zoom_in"):
			position.z -= camera_zoom_speed*delta
		if Input.is_action_pressed("Camera_zoom_out"):
			position.z += camera_zoom_speed*delta
		if Input.is_action_just_pressed("Mousewheel_in"):
			position.z -= camera_zoom_speed*delta
		if Input.is_action_just_pressed("Mousewheel_out"):
			position.z += camera_zoom_speed*delta	
		if Input.is_action_pressed("offset_camera_down"):
			position.y -= camera_speed*delta
		if Input.is_action_pressed("offset_camera_up"):
			position.y += camera_speed*delta
		if Input.is_action_pressed("offset_camera_left"):
			position.x -= camera_speed*delta
		if Input.is_action_pressed("offset_camera_right"):
			position.x += camera_speed*delta






func _physics_process(delta):
	pass
	#rotation.x = lerp(rotation.x, pitch, smooth * delta)
	'if player.is_multiplayer_authority():
		if Input.is_action_pressed("up"):
			face_camera(delta)
		if Input.is_action_pressed("down"):
			face_camera(delta)
		if Input.is_action_pressed("left"):
			face_camera(delta)
		if Input.is_action_pressed("right"):
			face_camera(delta)'
			
func _unhandled_input(event):
	if player.is_multiplayer_authority():
		if mouse_captured:
			if event is InputEventMouseMotion:
				
				# Yaw (left/right)
				yaw_anchor.rotate_y(-event.relative.x * mouse_sensitivity)
				# Pitch (up/down)
				pitch -= event.relative.y * mouse_sensitivity
				# Clamp pitch
				pitch = clamp(pitch, min_pitch, max_pitch)
				pitch_anchor.rotation.x = pitch
			
func _input(event):
	if player.is_multiplayer_authority():

		if event.is_action_pressed("ui_cancel"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				mouse_captured = false
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				mouse_captured = true

		if event.is_action_pressed("left_click"):
			if 	mouse_captured == false:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				mouse_captured = true


func face_camera(delta):
	# Camera forward vector
	var cam_forward = - %Camera3D.global_transform.basis.z

	# Ignore vertical component
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	if cam_forward.length() == 0:
		return

	# Target rotation
	var target_yaw = atan2(cam_forward.x, cam_forward.z)

	# Smooth rotation
	#player.rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	#direct rotation
	player.rotation.y = atan2(cam_forward.x, cam_forward.z)
