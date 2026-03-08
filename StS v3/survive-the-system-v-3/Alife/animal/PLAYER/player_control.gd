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
			if Input.is_action_just_pressed("fullscreen"):
				var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		#print(player.lifedata)
		#if player.lifedata["Alive"] == 1:
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
				player.get_parent().get_node("beast_manager").spawn_new_beast.rpc_id(1, player.position, Alifedata.enum_speciesID.SHEEP)
			

			if player.position.y < -200:
				player.position = Vector3(1,1,1)
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
			#print("player health is "+ str(player.current_health))
			#print("player hunger is "+ str(player.current_hunger))
			if Input.is_action_just_pressed("pick_up") :
				var Area3d = %Pick_up_Area3D
				Area3d.show()
				pick_up.rpc_id(1)
				await get_tree().create_timer(0.2).timeout
				Area3d.hide()
			if Input.is_action_just_pressed("show_status") :
				show_stats_menu()
				
			if Input.is_action_just_pressed("Action") :
				action()
				
			if Input.is_action_just_pressed("Drop"):
				Drop.rpc_id(1)
			if Input.is_action_just_pressed("eat"):
				eat_holding_item.rpc_id(1)


@rpc("any_peer","call_local")
func UseITEM():	
	#print(player.item_hold)
	if player.item_hold:
		if player.item_hold["Data"][0] is Dictionary:
			if player.item_hold["Data"][0]["Species"] == Alifedata.enum_speciesID.ITEM:
				player.item_hold["Data"][0]["Use"].call(player)
			else:
				print("alife entitity action")
		else:
			print("alife entitity action")
	else:
		var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
		 												player_action_area.get_node("CollisionShape3D").shape.size)
		if targets:
			for t in targets:
				if t is Dictionary:
					if t != player.lifedata:
						alife_manager.Attack(t,5)
				else:
					alife_manager.Attack(t,5)
				
				

@rpc("any_peer","call_local")
func pick_up() :
			var collision = %pick_up_CollisionShape3D
			collision.disabled = false
			await get_tree().create_timer(0.2).timeout
			collision.disabled = true

@rpc("any_peer","call_local")
func eat_holding_item() :
	if player.item_hold:
		if player.item_hold["Data"][0] is Dictionary:
			if player.item_hold["Data"][0]["Species"] == Alifedata.enum_speciesID.ITEM:
				player.item_hold["Data"][0]["Eat"].call(player)
			else:
				var value = player.item_hold["Data"][0]["Biomass"]/15
				var inventory = player.get_node("Player_HUD").get_node("Inventory")
				var item_eaten = inventory.remove_selected(int(player.name))
				if item_eaten:
					player.lifedata["current_energy"] =clamp(player.lifedata["current_energy"]+value,0,player.lifedata["Max_energy"])
					#print(value)
		else:
			var id = player.item_hold["Data"][0]
			var value = alife_manager.get_node("Grass_Manager2").current_biomass_array[id]/15
			var inventory = player.get_node("Player_HUD").get_node("Inventory")
			var item_eaten = inventory.remove_selected(int(player.name))
			if item_eaten:
					player.lifedata["current_energy"] =clamp(player.lifedata["current_energy"]+value,0,player.lifedata["Max_energy"])
					#print(value)
			
	else:
		pass

			#else:
				#alife_manager.add(item_dropped,player.position)	
				#pass
		#pass

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
	var collision = Action_area.get_node("CollisionShape3D")
	collision.shape = collision.shape.duplicate()
	var box_area = collision.shape
	box_area.size = Vector3.ONE *player.pickup_range_upgrade
	#print(player.pickup_range_upgrade)
	#print(collision.shape.size)
	var interacted_areas = Action_area.get_overlapping_areas()
	for area in interacted_areas:
		if area.get_parent().is_in_group("Collector"):
			area.get_parent().interact(player)
		if area.name == "Upgrade":
			area.interact(player)
		if area.name == "Area3D_go_button":
			area.get_parent().interacting()
		if area.name == "call_collector_ship_Area3D":
			area.get_parent().interacting()
		if area.name == "go_up_area3D":
			area.get_parent().go_up()
		if area.name == "Skin_Area3D":
			area.attribute_skin(player)

	
	
	var targets = alife_manager.get_alife_in_area(player_action_area.get_node("CollisionShape3D").global_position,
	 												player_action_area.get_node("CollisionShape3D").shape.size)

	#print(targets)
	if targets:
		for t in targets:
			if t is Dictionary:
				if t != player.lifedata:
					#print(t)
					#alife_manager.interact(t,player)
					if add_to_inventory(t):
						#print("added")
						alife_manager.remove(t)	
			else:
				if add_to_inventory(t):
					alife_manager.remove(t)	
					
						
						
func add_to_inventory(alife):
		#print(alife["Species"])
		var inventory = player.get_node("Player_HUD").get_node("Inventory")
		if alife is Dictionary:

			if inventory.add_item(inventory.prep_alife(alife),int(player.name)):
				return true
			else:
				return false
				#queue_free()
		else:
			if inventory.add_item(inventory.prep_newgrass(alife),int(player.name)):
				return true
			else:
				return false


@rpc("any_peer","call_remote")
func Drop():
	if player.item_hold:
		var inventory = player.get_node("Player_HUD").get_node("Inventory")
		var item_dropped = inventory.remove_selected(int(player.name))
		if item_dropped != null:
			if item_dropped is Dictionary:
				if item_dropped["Species"] == Alifedata.enum_speciesID.ITEM:
					alife_manager.get_node("Item_Manager").spawn_item.rpc(item_dropped,player.position)
				else:
					alife_manager.add(item_dropped,player.position)	
			else:
				alife_manager.add(item_dropped,player.position)	

		#player.drop(0, 1)

func show_stats_menu():
	player.get_node("Player_HUD").get_node("StatsPanel").update_status()
	if player.get_node("Player_HUD").get_node("StatsPanel").visible :
		player.get_node("Player_HUD").get_node("StatsPanel").hide()
	else :
		player.get_node("Player_HUD").get_node("StatsPanel").show()


'@rpc("any_peer","call_remote")
func put_back_in_world(id, number):
	id = inventory.size() - 1
	if inventory.has(id):
		var obj = inventory[id]
		remove_from_inventory(id, number)
		var pos = position
		pos.y = 0
		if obj["Species"] == Alifedata.enum_speciesID.SHEEP:
			get_parent().get_node("beast_manager").Spawn_Beast.rpc_id(1, pos, Alifedata.enum_speciesID.SHEEP)
		else:
			get_parent().get_node("Grass_Manager").ask_for_spawn_grass(pos,obj["Species"])'
	
