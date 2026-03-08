extends CharacterBody3D



@export var max_speed = 9
@export var sprint_speed = 18
@export var gravity = 60
@export var base_jump = 25
@export var fall_gravity := 90
@export var low_jump_gravity := 240
@export var long_jump = 120
@export var fly = false
@export var max_health = 100
@export var max_hunger = 100
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
var current_health = max_health
var current_hunger = max_hunger
@onready var health_bar = $MeshInstance3D/Status_bar/SubViewport/ProgressBarHealth
@onready var energy_bar = $MeshInstance3D/Status_bar/SubViewport2/ProgressBarEnergy

#upgrades variable here
var catnation_credits = 1
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



var dialogue_box 

var lifedata = {}

#INVENTORY HERE



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


####################################

@rpc("any_peer","call_local")
func equip_item(item):
	item_hold = item
	if item_hold:
		update_item_hold_texture.rpc(item["inventory_icon"])
		#$MeshInstance3D/Sprite3D_holdItem.texture = load(item["inventory_icon"])
	else:
		update_item_hold_texture.rpc(null)

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

@rpc("any_peer","call_remote")
func move_player_position(pos):
	#print(multiplayer.get_unique_id())
	position = pos


func _ready() -> void:

	if is_multiplayer_authority():
		$MeshInstance3D/Status_bar.show()
		%Camera3D.current = true
		World = get_parent().get_parent().get_node("World") #NEED TO BE CHANGED TO ASK SERVER INFO
		#print(World)
		go_back_to_ship(0)
		dialogue_box = $Player_HUD/Dialogue
		inventory_HUD = $Player_HUD/Inventory
	if multiplayer.is_server():
		health_bar.max_value = lifedata["Max_health"]
		energy_bar.max_value = lifedata["Max_energy"]
		#update_status_of_player(inventory_capacity_upgrade, catnation_credits)
		
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() :
		velocity.x = direction.x *speed 
		velocity.z = direction.z *speed 
		#data_movement_to_server.rpc_id(1, global_position)

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
	if multiplayer.is_server():
		if int(name) == null:
			pass
		else:
			if lifedata["current_energy"] > 0:
				lifedata["current_energy"] -= 0.5*delta
			if lifedata["current_energy"] > 49 and lifedata["current_health"]<lifedata["Max_health"]:
				lifedata["current_health"] += 1*delta
			if lifedata["current_energy"] <= 0:
				lifedata["current_health"] -= 1*delta
			if lifedata["current_health"] <= 0:
				#Die()
				Die.rpc_id(1, int(name))

			update_bar.rpc_id(int(name),1, lifedata["current_health"], lifedata["Max_health"])
			update_bar.rpc_id(int(name),2, lifedata["current_energy"], lifedata["Max_energy"])
			sync_lifedata.rpc_id(int(name), lifedata)
		
	if escape_timer_running and is_multiplayer_authority():
		escape_time_left -= delta
		var current_time := int(escape_time_left)
		if current_time != last_time_displayed:
			last_time_displayed = current_time
			if position.y >= escape_height:
				timer_label.text = str(int(escape_time_left)) +"(safe)"
			else:
				timer_label.text = str(int(escape_time_left)) + " (death)"
			if escape_time_left <= 0:
				escape_timer_running = false


@rpc("any_peer","call_local")
func sync_lifedata(data: Dictionary):
	lifedata = data
	
@rpc("any_peer","call_local")
func change_bin():
	if lifedata.size()>0:
		lifedata["position"] = position

		var old_bin = lifedata["bin_ID"]
		var current_bin = get_parent().get_worldbin_index(position)

		if old_bin == current_bin:
			return
		else:		
			get_parent().remove_from_world_bin(lifedata)
			get_parent().put_in_world_bin(lifedata)

@rpc("any_peer","call_local")
func Die(id):
	if lifedata["Alive"] == 1:
		lifedata["Alive"] = 0
		death.rpc_id(id,id)
	



func _on_pick_up_area_3d_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("object"):
		#print("picked object"+ str(area.get_parent().name))
		GlobalSimulationParameter.object_grass_number -= 1
		grass_in_inventory += area.get_parent().current_energy
		area.get_parent().queue_free()
		
		pass

@rpc("any_peer","call_local")
func death(id):
	$CollisionShape3D.disabled = true
	velocity = Vector3.ZERO
	gravity = 0
	fall_gravity = 0
	low_jump_gravity = 0
	max_speed = 0
	sprint_speed = 0
	base_jump = 0
	$MeshInstance3D.hide()
	get_parent().drop_bones.rpc_id(1, position)
	await get_tree().create_timer(1.0).timeout
	respawn()
	respawn_server.rpc_id(1)
	#$CatBones.show()

#@rpc("any_peer","call_local")
func respawn():
	go_back_to_ship(0)
	gravity = 60
	fall_gravity = 90
	low_jump_gravity = 240
	max_speed = 9
	sprint_speed = 18
	base_jump = 25
	inventory_capacity_upgrade = 1
	$CollisionShape3D.disabled = false
	$MeshInstance3D.show()

@rpc("any_peer","call_local")
func respawn_server():
	lifedata["current_health"] = 100
	lifedata["current_energy"] = 100
	lifedata["Max_energy"] = 100
	lifedata["Max_health"] = 100
	inventory_capacity_upgrade = 1
	lifedata["Alive"] = 1
	lifedata["Inventory_capacity"] = 1


func update_status_of_player():
		#print("somethinf status")
		#lifedata["Money"] = catnation_credits
		#lifedata["Inventory_capacity"] = inventory_capacity_upgrade
		#print(lifedata["Money"])
		get_node("Player_HUD").get_node("StatsPanel").update_status()


@rpc("any_peer","call_local")
func update_bar(bartype,value, MaxValue):
	if bartype ==1 :
		health_bar.value = value
		health_bar.max_value = MaxValue
	if bartype ==2 :
		energy_bar.value = value
		energy_bar.max_value = MaxValue

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
