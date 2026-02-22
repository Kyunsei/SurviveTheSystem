extends State
class_name move_state

var wandertimer = 0
var target 
var direction = 1

func evaluate():
	target = null
	#var dist_score = 0
	var score = 0.8
	player.current_speed =  player.lifedata["Max_speed"]/2
	
	for d in  player.vision_danger.values():
		if d:
			var distance = player.position.distance_to(d["position"])		
			if distance < 5:
				score = 2.0
				direction = -1
				player.current_speed =  player.lifedata["Max_speed"]*2
				
	for f in  player.vision_food.values():
		if f:
			for d in  player.vision_danger.values():
				if d:
					var distance_food_danger = d["position"].distance_to(f["position"])		
					if distance_food_danger > 5:						
						score = 0.8
						target = f
						direction = 1			
						#var distance = player.position.distance_to(f["position"])		
						#var maxDist = 5			
					#dist_score = .8 #clamp(distance / maxDist, 0., 1)

				
	#var energy_score = 1 - player.current_energy/player.max_energy


	#score = dist_score * energy_score
	return score

func enter():
	wandertimer = 0
	
func exit():
	pass

func physics_update(delta):
	pass

func update(delta):
	if target:
		player.direction = (target.position - player.position).normalized()	
	else:
		wandertimer -= delta
		if wandertimer <= 0:
			wandertimer = 5 / (1000 * GlobalSimulationParameter.simulation_speed)
			player.direction = Vector3(randf_range(-1,1),0,randf_range(-1,1)) *direction
			
	player.position += player.direction * player.current_speed * GlobalSimulationParameter.simulation_speed
	player.position.x = clamp(player.position.x ,-player.World.World_Size.x/2,player.World.World_Size.x/2 )
	player.position.z = clamp(player.position.z ,-player.World.World_Size.z/2,player.World.World_Size.z/2 )
	player.lifedata["position"] = player.position
	change_bin()

func change_bin():
	var old_bin = player.lifedata["bin_ID"]
	var current_bin = player.get_parent().get_worldbin_index(player.position)


	if old_bin == current_bin:
		return
	else:		
		player.get_parent().get_parent().remove_from_world_bin(player.lifedata)
		player.get_parent().get_parent().put_in_world_bin(player.lifedata)
