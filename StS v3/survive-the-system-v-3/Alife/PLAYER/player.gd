extends CharacterBody3D



@export var max_speed = 500
@export var sprint_speed = 1000
@export var gravity = 100
@export var base_jump = 40
@export var long_jump = 120
@export var fly = false
var speed = max_speed
var crouched = false
var gonna_jump = false
var is_jumping = false
var was_on_floor = false
var currently_on_floor = false
var standing_up = false
var direction = Vector3(0,0,0)
var isdebuging = true
var World : Node3D


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	if is_multiplayer_authority():
		%Camera3D.current = true
		World = get_parent().get_parent().get_node("World") #NEED TO BE CHANGED TO ASK SERVER INFO
		#print(World)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() :
		if is_jumping == false:
			velocity.x = direction.x *speed *delta
			velocity.z = direction.z *speed *delta
		if fly:
			velocity.y = direction.y *speed *delta

		'if not is_on_floor():
			velocity.y -= gravity * delta'
		if direction != Vector3(0,0,0):
			$MeshInstance3D.rotation.y = $camera_anchor.rotation.y 
			pass
			#var target_yaw := atan2(direction.x, -direction.z)
		move_and_slide()

#func _on_pick_up_area_3d_area_entered(area: Area3D) -> void:
	#if area.get_parent().is_in_group("object"):
		#print("picked object")
		#pass
