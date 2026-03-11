extends State
class_name dying_state

'func _ready() -> void:
	changecolor.rpc()'
	

var dead_sprite = [
	preload("res://Alife/animal/Herbivor/sheep_dead1.png"),
	preload("res://Alife/animal/Herbivor/sheep_dead2.png"),
	preload("res://Alife/animal/Herbivor/sheep_dead3.png"),
	preload("res://Alife/animal/Herbivor/sheep_dead3.png")
]	
	
var timer = 0.5

func evaluate():
	var score = 0
	if player.lifedata["current_health"] <= 0 or player.lifedata["Alive"] == 0:
		score = 10.
	return score

@rpc("any_peer","call_remote")
func send_new_sprite(state):
		var mi := player.get_node("MeshInstance3D") as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		var unique_mat := src_mat.duplicate(true) as StandardMaterial3D
		unique_mat.resource_local_to_scene = true
		unique_mat.albedo_texture = dead_sprite[state]
		mi.set_surface_override_material(0, unique_mat) 
		#var q := QuadMesh.new()
		#q.size = Vector2(size_array[state], size_array[state])
		#mi.mesh = q                                     
		#mi.position.y = (q.size.y-1) / 2.0




func enter():
	send_new_sprite.rpc(player.lifedata["current_life_state"])

	#changecolor.rpc()
	

	#player.get_parent().Kill_Beast.rpc_id(1, player)


func exit():
	pass

func physics_update(_delta):
	pass

func update(_delta):
	pass
