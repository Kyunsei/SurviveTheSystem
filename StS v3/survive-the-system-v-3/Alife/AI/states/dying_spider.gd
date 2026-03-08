extends State
class_name dying_state_spider


'func _ready() -> void:
	changecolor.rpc()'
	

var dead_sprite = [
	preload("res://assets/Art from STS2/spider_dead.png")
]	
	
	

func evaluate():
	var score = 0
	if player.lifedata["current_health"] <= 0 or player.lifedata["Alive"] == 0:
		score = 10.
	return score

@rpc("any_peer","call_remote")
func send_new_sprite():
		var mi := player.get_node("MeshInstance3D") as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		var unique_mat := src_mat.duplicate(true) as StandardMaterial3D
		unique_mat.resource_local_to_scene = true
		unique_mat.albedo_texture = dead_sprite[0]
		mi.set_surface_override_material(0, unique_mat) 
		#var q := QuadMesh.new()
		#q.size = Vector2(size_array[state], size_array[state])
		#mi.mesh = q                                     
		#mi.position.y = (q.size.y-1) / 2.0




func enter():
	var debug = "Dead"
	get_parent().get_parent().get_node("debugLabel").text = debug

	send_new_sprite.rpc()


func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	pass
