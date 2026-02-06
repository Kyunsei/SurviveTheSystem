extends Node
class_name player_control

var player : Node3D
var camera_anchor : Node3D

var direction = Vector3(0,0,0)



func _ready() -> void:
	player = get_parent()
	if player.has_node("camera_anchor"):
		camera_anchor = player.get_node("camera_anchor")
	

func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		direction = Vector3(0,0,0)
		#print("yes")
		if Input.is_action_pressed("down"):
			direction.z = 1
		if Input.is_action_pressed("up"):
			direction.z = -1
		if Input.is_action_pressed("right"):
			direction.x = 1
		if Input.is_action_pressed("left"):
			direction.x = -1	
		if direction != Vector3.ZERO:
			direction = direction.normalized()
		if camera_anchor:
			var cam_basis = camera_anchor.transform.basis
			direction = (cam_basis *direction).normalized() #THIS MAKE ONE DIRECTION SLOWERr

		player.direction = direction
		#player.get_node("MeshInstance3D").look_at(-direction)
		
