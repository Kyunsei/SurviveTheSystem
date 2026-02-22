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
		#if not player.is_on_floor():
			#player.velocity.y -= player.gravity*delta
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
			var cam_basis = camera_anchor.global_transform.basis
			# Get camera forward and right
			var forward = cam_basis.z
			var right = cam_basis.x
			# Remove vertical influence
			forward.y = 0
			right.y = 0
			forward = forward.normalized()
			right = right.normalized()
			# Rebuild movement direction on horizontal plane
			direction = (right * direction.x + forward * direction.z).normalized()
			player.direction = direction
				#player.get_node("MeshInstance3D").look_at(-direction)
		
		
		if Input.is_action_just_pressed("use"):
			player_action_area.show()

			UseITEM.rpc_id(1)
			await get_tree().create_timer(0.2).timeout
			player_action_area.hide()
			
		
		if Input.is_action_just_pressed("action1"):			
			#player.get_parent().Spawn_life_without_pool.rpc_id(1,player.global_position, "sheep")
			player.get_parent().get_node("beast_manager").Spawn_Beast.rpc_id(1, player.global_position, Alifedata.enum_speciesID.SHEEP)
		
		
		if Input.is_action_just_pressed("refresh"):			
			#player.get_parent().Spawn_life_without_pool.rpc_id(1,player.global_position, "sheep")
			player.get_parent().get_node("Grass_Manager").draw_multimesh_on_client.rpc_id(1,multiplayer.get_unique_id())
		
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
		if not player.is_on_floor():
			if player.velocity.y > 0:
				if Input.is_action_pressed("jump") :
					player.velocity.y -= player.gravity*delta
				else:
					player.velocity.y -= player.low_jump_gravity * delta
			else :
				player.velocity.y -= player.fall_gravity*delta
		if Input.is_action_just_pressed("jump") and player.is_on_floor():
			player.velocity.y = player.base_jump
	
		if Input.is_action_just_pressed("pick_up") :
			var Area3d = %Pick_up_Area3D
			Area3d.show()
			pick_up.rpc_id(1)
			await get_tree().create_timer(0.2).timeout
			Area3d.hide()
		if Input.is_action_just_pressed("Action") :
			action()#.rpc_id(1)
		if Input.is_action_just_pressed("Drop"):
			player.drop.rpc_id(1,0, 1)

@rpc("any_peer","call_local")
func UseITEM():

	var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
	 												player_action_area.get_node("CollisionShape3D").shape.size)
	if targets:
		for t in targets:
			if t is Dictionary:
				if t["Species"] == Alifedata.enum_speciesID.GRASS :
					alife_manager.get_node("Grass_Manager").Cut(t)
				else:
					pass

@rpc("any_peer","call_local")
func pick_up() :
			var collision = %pick_up_CollisionShape3D
			collision.disabled = false
			await get_tree().create_timer(0.2).timeout
			collision.disabled = true
			
#@rpc("any_peer","call_local")
func action():
	var interacted_areas = Action_area.get_overlapping_areas()

	for area in interacted_areas:
				#return
		if area.name == "NPC":
			area.interact(player)
		action_on_server.rpc_id(1)	

@rpc("any_peer","call_remote")
func action_on_server():
	var interacted_areas = Action_area.get_overlapping_areas()
	for area in interacted_areas:
		if area.get_parent().is_in_group("Collector"):
			area.get_parent().interact(player)
	
	
	
	var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
	 												player_action_area.get_node("CollisionShape3D").shape.size)
	if targets:
		for t in targets:
			if t is Dictionary:
					alife_manager.get_node("Grass_Manager").interact(t,player)
					
						
						
						
