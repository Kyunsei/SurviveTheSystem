extends State
class_name reproduce_state

var target 


func evaluate():


	var score = player.current_energy/player.max_energy
	return score


func enter():
	var newpos = player.position + Vector3(
	randf_range(-10,10),
	0,
	randf_range(-10, 10)
	)
	newpos.x = clamp(newpos.x, -player.World.World_Size.x / 2 + 1, player.World.World_Size.x / 2 - 1)
	newpos.z = clamp(newpos.z, -player.World.World_Size.z / 2 + 1, player.World.World_Size.z / 2 - 1)
	player.get_parent().Spawn_Beast.rpc_id(1, player.global_position, Alifedata.enum_speciesID.SHEEP)
	player.current_energy -= clamp(player.current_energy/2,0,player.max_energy)

func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	pass
