extends Item
var area
@export var action_size = Vector3(2,2,2)
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


static func on_use(player):
	player.vacuum_activation.rpc_id(1)
	
	
	
	
static func eat(_player):
	#print ("eaten cat ratio")
	print("This Vacuum can't be eaten")
	pass
