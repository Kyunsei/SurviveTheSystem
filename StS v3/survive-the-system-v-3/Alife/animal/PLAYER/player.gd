extends CharacterBody3D



@export var max_speed = 9
@export var sprint_speed = 18
@export var gravity = 60
@export var base_jump = 25
@export var fall_gravity := 90
@export var low_jump_gravity := 240
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
var grass_in_inventory = 0
var finished_their_mission = false
var poisoned_by_flower = 0.0
var has_wings = false
var flapping = false
var has_halo = false
var halo_effect = false




@onready var health_bar = $MeshInstance3D/Status_bar/SubViewport/ProgressBarHealth
@onready var energy_bar = $MeshInstance3D/Status_bar/SubViewport2/ProgressBarEnergy
var immune_to_death = false
var is_alive = true
var skin_index:int = 0 : set = set_skin
var input_blocked = false


var manager
var alifemanager_id : int
var max_health = 100
var max_energy = 200
var previous_health := 0.0

#MONEY MONEY MONEY MONEY MONEY
var catnation_credits :int = 1: 
	set(current_money): 
		if catnation_credits != current_money: 
			var previous_money = catnation_credits
			catnation_credits = current_money
			lifedata["Money"] = current_money
			set_current_money(previous_money)
			get_parent().get_parent().get_node("SPACESHIP").get_node("Shop_area").update_credits_in_shop.rpc_id(1, int(name), catnation_credits)

func set_current_money(prev_money: int) -> int:
	var difference := prev_money - catnation_credits
	show_label_above_player.rpc_id(int(name),-difference, Color(1.0, 0.843, 0.0, 1.0), 1.0, ""," money")
	return difference
#MONEY MONEY MONEY MONEY MONEY

var inv_capacity = 0.0
var inventory_capacity_upgrade = 1
var pickup_capacity = 0.0
var pickup_range_upgrade = pickup_capacity*5.0 + 1.0
var health_upgrade_cost = 2
var inventory_upgrade_cost = 2
var energy_upgrade_cost = 2
var range_upgrade_cost = 2

#Escape the surface variables here!
@onready var timer_label = $Player_HUD/TimerLabel
var last_time_displayed := -1
var escape_timer_running = false
var escape_time_left = 0.0
var escape_height := 90.0

#Server sync variables stuff
var input_direction : Vector3
var input_jump := false
var input_sprint := false

#INVENTORY PART
var inventory_HUD 
var inventory = {}
var inventory_count = 0
var item_hold = []
var vacuum_turned_on = false
var vacuum_action_range 
var vacuum_tick := 0.0
var vacuum_interval := 0.15
var spear_animation_in_course = false
var time_before_attack
var secondary_hold = false
var speardefense = false

var dialogue_box 

var lifedata = {}

#INVENTORY ABOVE
#ANIMATION VARIABLES ANIMATION VARIABLES ANIMATION VARIABLES ANIMATION VARIABLES
var spear_animations = [
	"hold_spear_to_strike",
	"hold_spear_to_strike_2",
	"hold_spear_position",
	"base_to_hold_spear",
	"hold_spear_to_block_position",
	"block_position",
]
#ANIMATION VARIABLES ANIMATION VARIABLES ANIMATION VARIABLES ANIMATION VARIABLES

###########INVENTORY HELPER FUNCTION

'@rpc("any_peer","call_local")
func add_to_inventory(object, number):
	inventory[inventory_count] = object
	inventory_count += 1
	#print(inventory)

@rpc("any_peer","call_remote")
func remove_from_inventory(id, number):
	if inventory.has(id):
		inventory.erase(id)
		inventory_count -= 1
		#print("removed")

@rpc("any_peer","call_remote")
func drop(id, number):
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

func set_skin(value:int):
	skin_index = value
	apply_skin()
func apply_skin():

	var skins = [
		preload("res://assets/assets kyun/deep_blue1.png"),
		preload("res://assets/assets kyun/ground_texture128.png"),
		preload("res://assets/assets kyun/grass_texture128.png"),
		preload("res://assets/assets kyun/collector_texture.png"),
		preload("res://assets/assets kyun/rayed2.png"),
		preload("res://assets/assets kyun/rayed1.png")
	]

	var material = StandardMaterial3D.new()
	material.albedo_texture = skins[skin_index]

	for child in $MeshInstance3D.get_children():
		if child is MeshInstance3D:
			child.set_surface_override_material(0, material)
	$MeshInstance3D.set_surface_override_material(0, material)

####################################

@rpc("any_peer","call_local")
func equip_item(item):
	item_hold = item
	if item_hold:
		update_item_hold_texture.rpc(item["inventory_icon"])
		show_selected(item_hold, int(name))
		#$MeshInstance3D/Sprite3D_holdItem.texture = load(item["inventory_icon"])
	else:
		update_item_hold_texture.rpc(null)
		hide_bound_objects()

func show_selected(item, _peer_id):
		var spear_path = "res://objects/cat_ration/Object_spear.tscn"
		var vacuum_path = "res://objects/cat_ration/Object_Vacuum.tscn"
		var gold_vacuum_path = "res://objects/cat_ration/Object_gold_vacuum.tscn"
		var slot = item["Data"][0]	
		#var holding
		if slot is Dictionary: 
			if slot.has("inventory_path"):
				if slot["inventory_path"] == spear_path:
					update_item_hold_texture.rpc(null)
					get_node("MeshInstance3D").get_node("spear").show()
					get_node("MeshInstance3D").get_node("Hoover").hide()
					get_node("MeshInstance3D").get_node("Gold_Hoover").hide()
					if $PlayerAnimater.current_animation not in spear_animations:
						$PlayerAnimater.play("base_to_hold_spear")
						await $PlayerAnimater.animation_finished
						$PlayerAnimater.play("hold_spear_position")
					$AnimationPlayer.play("init_pos_vacuum")
					vacuum_turned_on = false
					set_vacuum_state.rpc_id(1, false) 
				elif slot["inventory_path"] == vacuum_path:
					update_item_hold_texture.rpc(null)
					get_node("MeshInstance3D").get_node("Hoover").show()
					get_node("MeshInstance3D").get_node("spear").hide()
					get_node("MeshInstance3D").get_node("Gold_Hoover").hide()
					reset_arm_position()
					spear_back_to_origin()
					vacuum_turned_on = false
					set_vacuum_state.rpc_id(1, false) 
				elif slot["inventory_path"] == gold_vacuum_path:
					update_item_hold_texture.rpc(null)
					get_node("MeshInstance3D").get_node("Hoover").hide()
					get_node("MeshInstance3D").get_node("spear").hide()
					get_node("MeshInstance3D").get_node("Gold_Hoover").show()
					$AnimationPlayer.play("init_pos_vacuum")
					reset_arm_position()
					spear_back_to_origin()
					vacuum_turned_on = false
					set_vacuum_state.rpc_id(1, false) 
				else :
					reset_arm_position()
					hide_bound_objects()
		else:
			hide_bound_objects()
		
func reset_arm_position():
	if $PlayerAnimater.current_animation in spear_animations:
		$PlayerAnimater.play_backwards("base_to_hold_spear")
		await $PlayerAnimater.animation_finished
		$PlayerAnimater.play("base_arm_position")

		

func hide_bound_objects():
	spear_back_to_origin()
	reset_arm_position()
	get_node("MeshInstance3D").get_node("spear").hide()
	get_node("MeshInstance3D").get_node("Hoover").hide()
	get_node("MeshInstance3D").get_node("Gold_Hoover").hide()
	$AnimationPlayer.play("init_pos_vacuum")
	vacuum_turned_on = false
	set_vacuum_state.rpc_id(1, false) 

@rpc("any_peer","call_local")
func update_item_hold_texture(path):
	if path:
		$MeshInstance3D/Sprite3D_holdItem.texture = load(path)
	else:
		$MeshInstance3D/Sprite3D_holdItem.texture = null

func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


@rpc("any_peer","call_remote")
func go_back_to_ship(pos):
	var ship_pos = get_parent().get_parent().get_node("SPACESHIP").position
	ship_pos.x += pos
	position = ship_pos
	$MeshInstance3D.rotation.y = deg_to_rad(180)
	$camera_anchor.rotation.y = deg_to_rad(180)
	
@rpc("any_peer","call_remote")
func go_to_position(pos):
	position = pos

@rpc("any_peer","call_remote")
func move_player_position(pos):
	position = pos


func _ready() -> void:
	manager = get_parent().get_node("Grass_Manager2")
	vacuum_action_range = $MeshInstance3D/vacuum_Area3D/CollisionShape3D
	if is_multiplayer_authority():
		apply_skin()
		$PlayerAnimater.play("base_arm_position")
		$MeshInstance3D/Status_bar.show()
		%Camera3D.current = true
		World = get_parent().get_parent().get_node("World") #NEED TO BE CHANGED TO ASK SERVER INFO
		go_back_to_ship(0)
		dialogue_box = $Player_HUD/Dialogue
		inventory_HUD = $Player_HUD/Inventory
		manager.init_multimesh(self)

	if multiplayer.is_server():
		previous_health= manager.current_health_array[alifemanager_id]
		health_bar.max_value = max_health
		energy_bar.max_value = max_energy
		#update_status_of_player(inventory_capacity_upgrade, catnation_credits)

@rpc("any_peer","call_remote")
func show_halo(state:bool):
	if state == true: 
		get_node("MeshInstance3D").get_node("Halo").show()
	else:
		get_node("MeshInstance3D").get_node("Halo").hide()
		change_player_health.rpc_id(1,1000000)

@rpc("any_peer","call_local")
func change_player_health(qty):
	manager.current_health_array[alifemanager_id] = qty
	previous_health =qty
@rpc("any_peer","call_remote")
func change_halo_effect(state:bool):
	if state == true: 
		halo_effect = true
	else:
		halo_effect = false

var halo_time 
func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() :
		
		if has_halo:
			if halo_effect == false:
				halo_time += _delta
				if halo_time >= 30:
					change_halo_effect(true)
					show_halo(true)
			else:
				halo_time = 0.0
		if input_blocked == false:
			velocity.x = direction.x *speed 
			velocity.z = direction.z *speed 
			#data_movement_to_server.rpc_id(1, global_position)
			if Input.is_action_just_pressed("jump"):
				if is_on_floor() == false and has_wings:
					if flapping == false:
						flapping= true
						$WingsAnimater.speed_scale = 2.0
						$WingsAnimater.play("flapping_wings")
						velocity.y += 40
						await $WingsAnimater.animation_finished
						await get_tree().create_timer(0.2).timeout
						flapping= false
			if Input.is_action_just_pressed("secondary_use"):
				secondary_hold = true
			if Input.is_action_just_released("secondary_use"):
				secondary_hold = false
			if speed >= 10:
				$PlayerAnimaterLeg.speed_scale = 2
			else:
				$PlayerAnimaterLeg.speed_scale = 1
			if velocity.x != 0 or velocity.z != 0:
				if not $PlayerAnimaterLeg.is_playing() or $PlayerAnimaterLeg.current_animation != "leg_movement":
					$PlayerAnimaterLeg.play("leg_movement")
			else:
				if $PlayerAnimaterLeg.current_animation == "leg_movement":
					$PlayerAnimaterLeg.stop()

			if direction != Vector3(0,0,0):
				$MeshInstance3D.rotation.y = $camera_anchor.rotation.y 
				#$Action_Area3D.rotation.y = $camera_anchor.rotation.y 
				pass
				#var target_yaw := atan2(direction.x, -direction.z)
			move_and_slide()		
			change_bin.rpc_id(1)
		
@rpc("any_peer","call_remote",)
func data_movement_to_server(pos):
	giving_position_to_others.rpc(pos)
@rpc("any_peer","call_local","unreliable")
func giving_position_to_others(pos: Vector3) -> void:
	if not is_multiplayer_authority():
		# Smoothly interpolate to avoid vibration
		global_position = pos
		#global_position = pos


func _process(delta: float) -> void:

	if multiplayer.is_server():# and GlobalSimulationParameter.ClientStarted:
		if input_blocked:
			return  
		if int(name) == null:
			pass
		else:
			var current_health = manager.current_health_array[alifemanager_id]
			if current_health < previous_health:
				active_tint.rpc_id(int(name),1.0,Color(1.0,.0,.0,0.2))
				previous_health = current_health
			if manager.current_energy_array[alifemanager_id] <=0:
				if speed > 9:
					manager.current_health_array[alifemanager_id]-= 1.5*delta
					active_tint.rpc_id(int(name),1.0,Color(1.0,.0,.0,0.2))
				else: 
					manager.current_health_array[alifemanager_id]-= 1*delta
					active_tint.rpc_id(int(name),1.0,Color(1.0,.0,.0,0.2))

			else :
				if speed > 9:
					manager.current_energy_array[alifemanager_id]-= 1.0*delta
				else: 
					manager.current_energy_array[alifemanager_id]-= 0.5*delta
			if manager.current_energy_array[alifemanager_id] >=50 and manager.current_health_array[alifemanager_id] < max_health:
				manager.current_health_array[alifemanager_id] += 1*delta
				manager.current_energy_array[alifemanager_id] -= 1*delta

			'else:
					lifedata["current_energy"] -= 0.5*delta
					#manager.current_energy_array[alifemanager_id]-= 0.5*delta
			Regen_Health(delta)'
			
			
			#if lifedata["current_health"] <= 0 or get_parent().get_node("Grass_Manager2").current_health_array[alifemanager_id]<= 0:
			if get_parent().get_node("Grass_Manager2").current_health_array[alifemanager_id]<= 0:
				Die.rpc_id(1, int(name))

			#update_bar.rpc_id(int(name),1, lifedata["current_health"], lifedata["Max_health"])
			#update_bar.rpc_id(int(name),2, lifedata["current_energy"], lifedata["Max_energy"])
			sync_lifedata.rpc_id(int(name), lifedata)
			update_bar.rpc_id(int(name),1, manager.current_health_array[alifemanager_id], max_health)
			update_bar.rpc_id(int(name),2, manager.current_energy_array[alifemanager_id], max_energy)
			if vacuum_turned_on:
				vacuum_tick -= delta

				if vacuum_tick <= 0:
					vacuum_tick = vacuum_interval
					vacuum_loop()

	if escape_timer_running and is_multiplayer_authority():
		escape_time_left -= delta
		var current_time := int(escape_time_left)
		if current_time != last_time_displayed:
			last_time_displayed = current_time
			if position.y >= escape_height:
				timer_label.text = str(int(escape_time_left)) +"(safe)"
			else:
				timer_label.text = str(int(escape_time_left)) + " Return to ship"
			if escape_time_left <= 0:
				escape_timer_running = false

var tween
@rpc("any_peer", "call_remote")
func active_tint(fade_time: float, color: Color):
	var rect = $TintColor
	rect.color = color
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, fade_time)

@rpc("any_peer","call_local")
func sync_lifedata(data: Dictionary):
	pass
	lifedata = data
	#var manager = get_parent().get_node("Grass_Manager2")
	#health = manager.current_health_array[alifemanager_id]
	#energy = manager.current_energy_array[alifemanager_id]
@rpc("any_peer","call_local")
func change_bin():
	var _manager = 	get_parent().get_node("Grass_Manager2")
	var _i = alifemanager_id
	_manager.position_array[_i] = position

	var old_bin = _manager.binID_array[_i]
	var current_bin = _manager.get_real_current_bin(_i)
	if position.y > 2:
		current_bin = -1
	#print(current_bin)

	if old_bin == current_bin:
		return
	else:		
		_manager.remove_from_world_bin(_i)
		_manager.put_in_world_bin(_i)	

@rpc("any_peer","call_local")
func Die(id):
	'if lifedata["Alive"] == 1:
		lifedata["Alive"] = 0
		death.rpc_id(id,id)
	elif lifedata["current_health"] <= 0:
		lifedata["Alive"] = 0
		death.rpc_id(id,id)'
	#NEW
	if immune_to_death == false:
		if halo_effect == true and has_halo:
			immune_to_death = true
			show_halo.rpc_id(int(name),false)
			change_halo_effect.rpc_id(int(name),false)
			await get_tree().create_timer(5.0).timeout
			change_player_health.rpc_id(1,100)
			immune_to_death = false
		else:
			remove_durability(100)
			if manager.Alive_array[alifemanager_id] == 1:
				manager.Alive_array[alifemanager_id] = 0
				death.rpc_id(id,id)
			elif manager.current_health_array[alifemanager_id] <= 0:
				manager.Alive_array[alifemanager_id] = 0
				death.rpc_id(id,id)	



func _on_pick_up_area_3d_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("object"):
		#print("picked object"+ str(area.get_parent().name))
		GlobalSimulationParameter.object_grass_number -= 1
		grass_in_inventory += area.get_parent().current_energy
		area.get_parent().queue_free()
		
		pass

@rpc("any_peer","call_local")
func death(_id):
	is_alive = false
	if immune_to_death == false:
		immune_to_death = true
		$CollisionShape3D.disabled = true
		velocity = Vector3.ZERO
		gravity = 0
		fall_gravity = 0
		low_jump_gravity = 0
		max_speed = 0
		sprint_speed = 0
		base_jump = 0
		$MeshInstance3D.hide()
		get_parent().drop_bones.rpc_id(1, global_position)
		await get_tree().create_timer(3.0).timeout
		respawn()
		respawn_server.rpc_id(1)
		#$CatBones.show()

#@rpc("any_peer","call_local")
func respawn():
	go_back_to_ship(0)
	change_bin.rpc_id(1)

	#is_alive = true
	gravity = 60
	fall_gravity = 90
	low_jump_gravity = 240
	max_speed = 9
	sprint_speed = 18
	base_jump = 25
	$CollisionShape3D.disabled = false
	$MeshInstance3D.show()
	await get_tree().create_timer(5.0).timeout
	if immune_to_death == true:
		change_player_health.rpc_id(1,55)
		immune_to_death = false
@rpc("any_peer","call_local")
func respawn_server():
	#is_alive = true

	#NEW
	manager.current_health_array[alifemanager_id] =50
	previous_health = 50
	manager.Alive_array[alifemanager_id] =1
	#manager.binID_array[alifemanager_id] = -1
	manager.current_energy_array[alifemanager_id] =100
	await get_tree().create_timer(5.0).timeout
	if immune_to_death == true:
		change_player_health.rpc_id(1,55)
		immune_to_death = false

	#OLD - will be deleted when all migrated
	'lifedata["current_health"] = 50
	lifedata["current_energy"] = 100
	lifedata["Alive"] = 1'

@rpc("any_peer","call_remote")
func update_status_of_player():
		#print("somethinf status")
		#lifedata["Money"] = catnation_credits
		#lifedata["Inventory_capacity"] = inventory_capacity_upgrade
		#print(lifedata["Money"])
		get_node("Player_HUD").get_node("StatsPanel").update_status.rpc_id(1,int(name))


@rpc("any_peer","call_local")
func update_bar(bartype,value, MaxValue):
	if bartype ==1 :
		health_bar.value = value
		health_bar.max_value = MaxValue
		#print(str(MaxValue)+ str("debug"))
	if bartype ==2 :
		energy_bar.value = value
		energy_bar.max_value = MaxValue
		#print(str(MaxValue)+ str("debug"))

@rpc("any_peer","call_local")
func force_escape_time(new_time):
	escape_time_left = new_time
	last_time_displayed = -1

@rpc("any_peer","call_local")
func escape_success():
	timer_label.show()
	timer_label.text = "You survived!"

	await get_tree().create_timer(2.0).timeout
	timer_label.hide()

@rpc("any_peer","call_local")
func stop_escape_ui():
	print("escape stopped")
	escape_timer_running = false
	timer_label.hide()

@rpc("any_peer","call_remote")
func hide_inventory():
	get_node("Player_HUD").get_node("Inventory").hide()
	for child in get_node("Controler_canvas").get_children():
		child.position.y -=5000
	for child in get_node("Mouse_canvas").get_children():
		child.position.y -=5000


@rpc("any_peer","call_local")
func show_escape_timer(time):
	escape_time_left = time
	escape_timer_running = true
	timer_label.text = str(int(time))
	timer_label.show()

@rpc("any_peer","call_local")
func start_escape_ui(time):
	escape_timer_running = true
	escape_time_left = time
	timer_label.show()

#Server sync movement
@rpc("any_peer","call_remote","unreliable")
func receive_input(dir: Vector3, jump: bool, sprint: bool):
	if !multiplayer.is_server():
		return
		
	input_direction = dir
	input_jump = jump
	input_sprint = sprint
	
	
#OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!
@rpc("any_peer","call_remote")
func first_ascension():
		has_wings = true
		get_node("MeshInstance3D").get_node("Wings").show()
@rpc("any_peer","call_remote")
func second_ascension():
		has_halo = true
		halo_effect = true
		get_node("MeshInstance3D").get_node("Halo").show()
@rpc("any_peer","call_local")
func spear_attack():
	if manager.Alive_array[alifemanager_id] == 1:
		#if lifedata["current_energy"]> 0 : 
			#lifedata["current_energy"] -= 1
		if manager.current_energy_array[alifemanager_id] >0:
			manager.current_energy_array[alifemanager_id] -= 1 
		else:
			manager.current_health_array[alifemanager_id] -= 1 
		if spear_animation_in_course == false and speardefense == false:
			time_before_attack = 0.4
			spear_animation_in_course = true
			spear_attack_animation.rpc_id(int(name))
		var area = $MeshInstance3D/spear_Area3D
		var collision = $MeshInstance3D/spear_Area3D/CollisionShape3D
		var extents = collision.shape.size/2
		var basiss = collision.global_transform.basis.orthonormalized()
		var world_extents = Vector3(
		abs(basiss.x.x) * extents.x + abs(basiss.y.x) * extents.y + abs(basiss.z.x) * extents.z,
		abs(basiss.x.y) * extents.x + abs(basiss.y.y) * extents.y + abs(basiss.z.y) * extents.z,
		abs(basiss.x.z) * extents.x + abs(basiss.y.z) * extents.y + abs(basiss.z.z) * extents.z
	)
		var forward = -area.global_transform.basis.z
		var pos_center = area.global_position + forward * extents.z
		var targets = get_parent().get_alife_in_area(pos_center, world_extents)
		if targets: 
			remove_durability(3)
			for t in targets:
				if t is Dictionary:
					#if t != lifedata and t["Species"] != Alifedata.enum_speciesID.CAT:
					if t.alifemanager_id != alifemanager_id:
						get_parent().Attack(t,25)
				else :
					if t == alifemanager_id:
						pass
					else:
						get_parent().Attack(t,25)
						print(manager.Species_array[t])
		check_player_hit.rpc_id(1, 25, area)
		await get_tree().create_timer(time_before_attack).timeout
		spear_animation_in_course = false

@rpc("any_peer","call_remote")
func spear_attack_animation():
	$AnimationPlayer.play("spear_attack_2")
	$PlayerAnimater.play("hold_spear_to_strike_2")
	await $AnimationPlayer.animation_finished
	$AnimationPlayer.play_backwards("spear_attack_1")
	$PlayerAnimater.play_backwards("hold_spear_to_strike")
	await $AnimationPlayer.animation_finished
	$AnimationPlayer.play("RESET")
	if get_node("MeshInstance3D").get_node("spear").is_visible_in_tree():
		$PlayerAnimater.play("hold_spear_position")
@rpc("any_peer","call_local")
func check_player_hit(dmg, areaofaction):
	var interacted_areas = areaofaction.get_overlapping_areas()
	for t in interacted_areas:
		if t.is_in_group("spear_hit") and t.get_parent()!= self :
			if t.get_parent().speardefense == false:
				#get_parent().Attack(t.get_parent().lifedata, dmg)
				#if t.get_parent().lifedata["current_health"] > 0:
				if t.get_parent().manager.current_health_array[t.get_parent().alifemanager_id] >0:
					remove_health_to_target.rpc_id(1,int(t.get_parent().name),25.0)
					t.get_parent().show_label_above_player.rpc_id(int(t.get_parent().name),-dmg, Color(1.0, 0.1, 0.0, 1.0), 1.0, ""," Health")
					remove_durability(3)
			else :
				#if t.get_parent().lifedata["current_health"] > 0:
				if t.get_parent().manager.current_health_array[t.get_parent().alifemanager_id] >0:
					t.get_parent().show_label_above_player.rpc_id(int(t.get_parent().name),dmg, Color(0.5, 0.5, 0.5, 1.0), 1.0, ""," Damage Blocked")
					remove_durability(10)
					if t.get_parent().item_hold :
						t.get_parent().remove_durability(1)
					#if t.get_parent().lifedata["current_energy"]> 0:
						#t.get_parent().lifedata["current_energy"] -=5
					if t.get_parent().manager.current_energy_array[t.get_parent().alifemanager_id] >0:
						t.get_parent().manager.current_energy_array[t.get_parent().alifemanager_id] -=5
					else:
						t.get_parent().manager.current_health_array[t.get_parent().alifemanager_id] -=1

@rpc("any_peer","call_local")
func remove_health_to_target(p_id,value):
	var alife_manager = get_parent()
	var player_list = alife_manager.player_array
	for p in player_list:
		if int(p.name) == p_id:
			manager.current_health_array[p.alifemanager_id] -= value




@rpc("any_peer","call_local")
func spear_defense(number):
	spear_defense_animation.rpc_id(int(name), number)

@rpc("any_peer","call_remote")
func spear_defense_animation(defendingornot):
	if defendingornot == 0:
		$AnimationPlayer.play("spear_going_to_defense")
		$PlayerAnimater.play("hold_spear_to_block_position")
		await $AnimationPlayer.animation_finished
		if $MeshInstance3D/spear.is_visible_in_tree():
			$PlayerAnimater.play("block_position")
		$AnimationPlayer.play("spear_in_defense")
		set_speardefense_state.rpc_id(1, true) # tell server
	else:
		spear_back_to_origin()


func spear_back_to_origin():
	if $PlayerAnimater.current_animation in spear_animations:
		$AnimationPlayer.play_backwards("spear_going_to_defense")
		$PlayerAnimater.play_backwards("hold_spear_to_block_position")
		await $AnimationPlayer.animation_finished
		$AnimationPlayer.play("base_spear_position")
		if $MeshInstance3D/spear.is_visible_in_tree():
			$PlayerAnimater.play("hold_spear_position")
		set_speardefense_state.rpc_id(1, false) # tell server
@rpc("any_peer","call_local")
func set_speardefense_state(state: bool):
	speardefense = state

@rpc("any_peer","call_local")
func speardefending():
	pass

@rpc("any_peer","call_local")
func vacuum_activation():
	vacuum_animation.rpc_id(int(name))

@rpc("any_peer","call_local")
func vacuum_activation2():
	vacuum_animation2.rpc_id(int(name))

@rpc("any_peer","call_remote")
func vacuum_animation():
	if vacuum_turned_on == false:
		$AnimationPlayer.play("vacuum_on_2")
		set_vacuum_state.rpc_id(1, true) # tell server
		vacuum_turned_on = true
	else:
		$AnimationPlayer.play("init_pos_vacuum")
		set_vacuum_state.rpc_id(1, false) # tell server
		vacuum_turned_on = false

@rpc("any_peer","call_remote")
func vacuum_animation2():
	if vacuum_turned_on == false:
		$AnimationPlayer.play("gold_vac_2_on")
		set_vacuum_state.rpc_id(1, true) # tell server
		vacuum_turned_on = true
	else:
		$AnimationPlayer.play("init_pos_gold_vac")
		set_vacuum_state.rpc_id(1, false) # tell server
		vacuum_turned_on = false

@rpc("any_peer","call_local")
func set_vacuum_state(state: bool):
	vacuum_turned_on = state

@rpc("any_peer","call_local")
func vacuum_loop():
	var alife_manager = get_parent()
	var targets = alife_manager.get_alife_in_area(vacuum_action_range.global_position,
	 												vacuum_action_range.shape.size)
	if targets:
		for t in targets:
			if t is Dictionary:
				if t != lifedata:
					#print(t)
					#alife_manager.interact(t,player)
					if add_to_inventory(t):
						remove_durability(0.33)
						#print("added")
						alife_manager.remove(t)	
			else:
				if alife_manager.get_node("Grass_Manager2").Species_array[t] == 5: #CAT
					return
				if add_to_inventory(t):
					remove_durability(0.33)
					alife_manager.remove(t)	


func remove_durability(amount):
	#print(multiplayer.is_server())
	if item_hold:
		if item_hold["Data"][0] is Dictionary:
			item_hold["Data"][0]["durability"] -= amount
			get_node("Player_HUD").get_node("Inventory").update_durability(int(name))
			if item_hold["Data"][0]["durability"] <= 0 :
				get_node("Player_HUD").get_node("Inventory").remove_selected(int(name))


func add_to_inventory(alife):
		var inventoryy = get_node("Player_HUD").get_node("Inventory")
		if alife is Dictionary:

			if inventoryy.add_item(inventoryy.prep_alife(alife),int(name)):
				return true
			else:
				return false
				#queue_free()
		#else:
			#if inventoryy.add_item(inventoryy.prep_newgrass(alife),int(name)):
				#return true
		else:
			if manager.SPECIES[manager.Species_array[alife]].isPickable(manager,alife):
				if inventoryy.add_item(inventoryy.prep_newgrass(alife),int(name)):
					return true
			else:
				return false


@rpc("any_peer","call_remote")
func show_label_above_player(string, color, time, Special, type):
	var label := Label3D.new()
	label.modulate = color
	if string > 0:
		label.text = "Gained " + str(abs(string)) + str(type)
	else :
		label.text = "Lost " + str(abs(string)) + str(type)
		label.modulate += Color(0.0, -0.6, 0.0, 0.0) #reder color normally
	if type == " Damage Blocked":
		label.text = "Blocked " + str(abs(string)) + " Damage"
	if Special == "Special":
		label.text = type
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.9, 0)
	add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.5, time)
	var tween2 = label.create_tween()
	tween2.tween_property(label, "modulate:a", 0.0, time)
	var tween3 = label.create_tween()
	tween3.tween_property(label, "outline_modulate:a", 0.0, time)
	await tween.finished
	label.queue_free()
	#await get_tree().create_timer(time).timeout
	#label.queue_free()

#OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!OBJECT FUNCTION HERE!!!!

@rpc("any_peer", "call_remote")
func set_input_blocked(blocked: bool):
	input_blocked = blocked
	set_process_input(not blocked)  # disables _input() if blocked

var isWorldAccelerated = false
@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	if isWorldAccelerated == false:
		get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time = 1000
		GlobalSimulationParameter.simulation_speed = value
		isWorldAccelerated = true
