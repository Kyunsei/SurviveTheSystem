extends Node
class_name player_control

@onready var Action_area: Area3D = %Action_Area3D
var player : Node3D
var player_action_area : Node3D
var camera_anchor : Node3D
var alife_manager: Node3D

var direction = Vector3(0,0,0)
var total = 0
var total2 = 0

func _ready() -> void:
	var collision = %pick_up_CollisionShape3D
	collision.disabled = true
	player = get_parent()
	alife_manager = player.get_parent()
	player_action_area = %Area3D
	if player.has_node("camera_anchor"):
		camera_anchor = player.get_node("camera_anchor")
	

func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		if not player.is_on_floor():
			player.velocity.y -= player.gravity*delta
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
			player.get_parent().Spawn_life_without_pool.rpc_id(1,player.global_position, "sheep")
			
			#player.get_parent().Spawn_life.rpc_id(1,player.global_position, "grass")
			#player.get_parent().Spawn_life.rpc_id(1,player.global_position, "grass")
			#player.get_parent().Spawn_life.rpc_id(1,player.global_position, "grass")
		if Input.is_action_pressed("jump") :
			total += delta
		if Input.is_action_pressed("sprint") :
			total2 += delta
		if total2 > 0 :
			player.speed = player.sprint_speed
		if total2 == 0 :
			player.speed = player.max_speed
		if Input.is_action_pressed("sprint") == false:
			total2 = 0
		player.currently_on_floor = player.is_on_floor()
		if Input.is_action_just_pressed("jump") and player.is_on_floor():
			total = 0
			#if player.gonna_jump == true :
				#print ("long jumped")
				#player.is_jumping = true
				#player.velocity.y += player.base_jump/1.5
				#player.standing_up = true
				#player.velocity.x = -player.get_node("MeshInstance3D").transform.basis.z.x * player.long_jump
				#player.velocity.z = -player.get_node("MeshInstance3D").transform.basis.z.z * player.long_jump
				#print (player.velocity)
				#player.gonna_jump = false
				#await get_tree().create_timer(0.2).timeout 
				#player.is_jumping = false
			#else :
				#print ("jumped")
				
			player.velocity.y += player.base_jump
			player.standing_up = true
			player.crouched = false
			player.was_on_floor = player.currently_on_floor
		#if not player.was_on_floor and player.currently_on_floor and player.standing_up == true:
				#player.get_node("AnimationPlayer").speed_scale = 5.0
				#player.get_node("AnimationPlayer").play_backwards("Crouch_2")
				#player.standing_up = false
		#if total > 0.2:
			#player.speed = 0
		#if total > 1 :
			#if player.crouched == false :
				#player.get_node("AnimationPlayer").speed_scale = 1.0
				#player.get_node("AnimationPlayer").play("Crouch")
				#player.crouched = true
		#if total > 1.2 :
				#player.gonna_jump = true
			#if Input.is_action_just_released("jump") and player.crouched == true:
				#print("long jump")
				#player.get_node("AnimationPlayer").play("RESET")
				#player.crouched = false
				#player.speed = 500
		if Input.is_action_just_pressed("pick_up") :
			var Area3d = %Pick_up_Area3D
			Area3d.show()
			pick_up.rpc_id(1)
			await get_tree().create_timer(0.2).timeout
			Area3d.hide()
		if Input.is_action_just_pressed("Action") :
			action.rpc_id(1)


@rpc("any_peer","call_local")
func DoAction():

	var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
	 												player_action_area.get_node("CollisionShape3D").shape.size)
	if targets:
		for t in targets:
			if t!= self:
				if t.species == "grass" :
					t.Cut()
				else:
					pass

@rpc("any_peer","call_local")
func pick_up() :
			var collision = %pick_up_CollisionShape3D
			collision.disabled = false
			await get_tree().create_timer(0.2).timeout
			collision.disabled = true
@rpc("any_peer","call_local")
func action():
	var interacted_areas = Action_area.get_overlapping_areas()
	for area in interacted_areas:
		if area.is_in_group("Collector"):
			area.get_parent().Biomass_collected += player.grass_in_inventory
			area.get_parent().update_label()
			player.grass_in_inventory = 0
			print ("item collected")
			print (area.get_parent().Biomass_collected)
			#return
						
						
						
						
