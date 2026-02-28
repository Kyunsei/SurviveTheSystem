extends State
class_name reproduce_state

var target 


func evaluate():
	var score = 0.0
	if player.lifedata["current_life_state"] == 3:
		if  player.lifedata["current_energy"] >= 100:
			score = 1.0
	return score


func enter():
	#if player.current_energy >= player.max_energy:
	var newpos_ori = player.position # + Vector3(randf_range(-10,10),0,randf_range(-10, 10)) 
	for i in range(3):
		var newpos = newpos_ori + + Vector3(randf_range(-0.8,0.8),0,randf_range(-0.8, 0.8)) 
		newpos.x = clamp(newpos.x, -player.World.World_Size.x / 2 + 1, player.World.World_Size.x / 2 - 1)
		newpos.z = clamp(newpos.z, -player.World.World_Size.z / 2 + 1, player.World.World_Size.z / 2 - 1)
		var newalife = player.lifedata.duplicate()
		newalife["position"] = newpos
		player.get_parent().Ask_to_spawn.rpc_id(1, newalife)
	player.lifedata["current_energy"]  = clamp(player.lifedata["current_energy"] - 90,0 ,player.lifedata["Max_energy"] )

func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	pass
