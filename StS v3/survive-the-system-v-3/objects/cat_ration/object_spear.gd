extends Item
var area
@export var attack_size = Vector3(2,2,2)
var timer = 0.5
func _ready():
		area = $attack_area

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
	var center = player.position
	var size = Vector3(2,2,2)
	var targets = player.get_parent().get_alife_in_area(player.position, size)
	#player.get_node("MeshInstance3D").get_node("Area3D").show()
	if targets:
		for t in targets:
			if t is Dictionary:
				if t != player.lifedata:
					player.get_parent().Attack(t,5)
					print("hit player")
			else:
				player.get_parent().Attack(t,5)
				print("hit non player")
	#player.get_node("MeshInstance3D").get_node("Area3D").hide()

	
	
	
static func eat(player):
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
