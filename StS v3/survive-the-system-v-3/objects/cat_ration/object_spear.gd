extends Item

var area
@export var attack_size = Vector3(2,2,2)
var timer = 0.5
var physical_spear_on_ground
func _ready():
		area = $attack_area
		physical_spear_on_ground = $spear
		physical_spear_on_ground.rotation_degrees.x = randf_range(-5.0, 5.0)
		physical_spear_on_ground.rotation_degrees.y = randf_range(0.0, 0.0)
		physical_spear_on_ground.rotation_degrees.z = randf_range(175.0, 185.0)

func _process(delta: float) -> void:
	timer -= delta

func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if timer <0:
			if body.is_in_group("player"):
				add_to_player(body,int(body.name))
			else:
				pass


static func on_use(player): #NOT IMPLEMENTED YET.  need to HAVE ITEM SLECTION BEFORE

	if player.spear_animation_in_course == false and player.speardefense == false:
		player.spear_attack.rpc_id(1)

static func on_use_secondary(player, state):
	if state == false:
		player.spear_defense.rpc_id(1, 1)
	elif state == true:
		player.spear_defense.rpc_id(1, 0)
	
static func eat(_player):
	#print ("eaten cat ratio")
	print("This Spear can't be eaten")
	pass


#static func create_area():
	#var area = Area3D.new()
	#area.name = "MyArea"
	#area.position = pos
#
	#var collision = CollisionShape3D.new()
	#var shape = BoxShape3D.new()
	#shape.size = Vector3(1, 1,1)
#
	#collision.shape = shape
	#area.add_child(collision)
#
	#add_child(area)
