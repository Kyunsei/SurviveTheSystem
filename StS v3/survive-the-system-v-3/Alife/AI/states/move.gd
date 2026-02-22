extends State
class_name move_state

var wandertimer = 0

func evaluate():
	var dist_score = 0
	var score = 0
	if player.target:
		var distance = player.position.distance_to(player.target["position"])
		#print(distance)
		var maxDist = 5
		dist_score = .8 #clamp(distance / maxDist, 0., 1)
	var energy_score = 1 - player.current_energy/player.max_energy


	score = dist_score * energy_score
	return 0.8#score

func enter():
	wandertimer = 0
func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	if player.target:
		player.direction = (player.target.position - player.position).normalized()	
	else:
		wandertimer -= delta
		if wandertimer <= 0:
			wandertimer = 5 / (1000 * GlobalSimulationParameter.simulation_speed)
			player.direction = Vector3(randf_range(-1,1),0,randf_range(-1,1))
			
	player.position += player.direction * player.current_speed * GlobalSimulationParameter.simulation_speed
	player.position.x = clamp(player.position.x ,-player.World.World_Size.x/2,player.World.World_Size.x/2 )
	player.position.z = clamp(player.position.z ,-player.World.World_Size.z/2,player.World.World_Size.z/2 )
