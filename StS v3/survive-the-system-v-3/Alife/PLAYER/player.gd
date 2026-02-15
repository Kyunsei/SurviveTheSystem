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
var grass_in_inventory = 0
var dialogue_box 



#INVENTORY HERE
var inventory = {

}
var inventory_count = 0


###########INVENTORY HELPER FUNCTION

@rpc("any_peer","call_local")
func add_to_inventory(object, number):
	inventory[inventory_count] = object
	inventory_count += 1
	print(inventory)

@rpc("any_peer","call_remote")
func remove_from_inventory(id, number):
	id = inventory.size() - 1
	if inventory.has(id):
		var obj = inventory[id]
		var pos = position
		pos.y = 0
		get_parent().get_node("Grass_Manager").ask_for_spawn_grass(pos,obj["Species"])
		inventory.erase(id)
		inventory_count -= 1
		print("removed")



####################################



func _enter_tree() -> void:
	set_multiplayer_authority(int(name))




func _ready() -> void:
	if is_multiplayer_authority():
		%Camera3D.current = true
		World = get_parent().get_parent().get_node("World") #NEED TO BE CHANGED TO ASK SERVER INFO
		#print(World)
		position = get_parent().get_parent().get_node("SPACESHIP").position
		dialogue_box = $Player_HUD/Dialogue
		
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

func _on_pick_up_area_3d_area_entered(area: Area3D) -> void:
	if area.get_parent().is_in_group("object"):
		#print("picked object"+ str(area.get_parent().name))
		GlobalSimulationParameter.object_grass_number -= 1
		grass_in_inventory += area.get_parent().current_energy
		print(grass_in_inventory)
		area.get_parent().queue_free()
		
		pass
