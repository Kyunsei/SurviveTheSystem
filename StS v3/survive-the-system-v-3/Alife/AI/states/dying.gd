extends State
class_name dying_state

'func _ready() -> void:
	changecolor.rpc()'
	
var timer = 0.5

func evaluate():
	var score = 0
	if player.current_energy <= 0:
		score = 1
	return score

@rpc("any_peer","call_local")
func changecolor():
	var mesh_instance = player.get_node("MeshInstance3D")
	'var new_mat = StandardMaterial3D.new()
	new_mat.albedo_color = Color(0.249, 0.24, 0.333, 1.0)
	mesh_instance.set_surface_override_material(0, new_mat)'
	
	mesh_instance.get_active_material(0).albedo_color =  Color(0.249, 0.24, 0.333, 1.0)

func enter():
	timer = 0.5
	#changecolor.rpc()
	

	#print(player.get_parent().name)
	#player.get_parent().Kill_Beast.rpc_id(1, player)


func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	timer -= delta
	if timer <= 0:
		player.get_parent().ask_for_Kill(player.lifedata)
