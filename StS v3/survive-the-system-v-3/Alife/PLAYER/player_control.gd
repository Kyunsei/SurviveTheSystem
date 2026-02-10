extends Node
class_name player_control

var player : Node3D
var player_action_area : Node3D
var camera_anchor : Node3D
var alife_manager: Node3D

var direction = Vector3(0,0,0)


func _ready() -> void:
	player = get_parent()
	alife_manager = player.get_parent()
	player_action_area = %Area3D
	if player.has_node("camera_anchor"):
		camera_anchor = player.get_node("camera_anchor")
	

func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		direction = Vector3(0,0,0)
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
		
		
		if Input.is_action_just_pressed("action0"):
			player_action_area.show()

			DoAction.rpc_id(1)
			await get_tree().create_timer(0.2).timeout
			player_action_area.hide()
			
		
		if Input.is_action_just_pressed("action1"):
			#var LIFE_SCENE = preload("res://Alife/Plant/Grass/grass.tscn")
			player.get_parent().Spawn_life.rpc_id(1,player.global_position, "grass")


@rpc("any_peer","call_local")
func DoAction():

	var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
	 												player_action_area.get_node("CollisionShape3D").shape.size)
	if targets:
		for t in targets:
			if t!= self:
				t.Die()
