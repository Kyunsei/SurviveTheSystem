extends State
class_name growthsheep

var egg_factor_time = 2.

var sprite_array = [
preload("res://Alife/animal/Herbivor/sheep1.png"),
preload("res://Alife/animal/Herbivor/sheep2.png"),
preload("res://Alife/animal/Herbivor/sheep3.png"),
preload("res://Alife/animal/Herbivor/SHEEP.png")]




var size_array = [0.5,0.5,1.5,2]

func evaluate():
	if player.lifedata["current_life_state"] == 0:
		return 5.0

	if player.lifedata["current_life_state"] < sprite_array.size()-1:
		if player.lifedata["current_energy"] >= 100:
			return 1.5
		return 0.
	else:
		return 0.

func enter():
	if player.lifedata["current_energy"] < 100:
		pass
	else:
		if player.lifedata["current_life_state"] < sprite_array.size()-1:
			player.lifedata["current_life_state"] += 1
			player.lifedata["Biomass"] += 20
			player.lifedata["Max_speed"] = 5
			player.lifedata["current_energy"] -= 50
			#player.get_node("MeashInstance3D").texture = load(sprite_array[player.lifedata["current_life_state"]])
			send_new_sprite.rpc(player.lifedata["current_life_state"])

@rpc("any_peer","call_remote")
func send_new_sprite(state):
		var mi := player.get_node("MeshInstance3D") as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		var unique_mat := src_mat.duplicate(true) as StandardMaterial3D
		unique_mat.resource_local_to_scene = true
		unique_mat.albedo_texture = sprite_array[state]
		mi.set_surface_override_material(0, unique_mat) 
		var q := QuadMesh.new()
		q.size = Vector2(size_array[state], size_array[state])
		mi.mesh = q                                     
		mi.position.y = (q.size.y-1) / 2.0


func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	if player.lifedata["current_life_state"] == 0:
		player.lifedata["current_energy"] += egg_factor_time *delta * GlobalSimulationParameter.simulation_speed

		
