extends State
class_name move_state

var wandertimer = 0
var target 
var direction = Vector3()
var isFood = true



func evaluate():
	target = null
	var score = 0.5
	var debug = "WANDER"

	#var wander_dir = get_wander_direction()
	var final_dir = direction
	player.lifedata["current_speed"] = player.lifedata["Max_speed"] / 2

	# --- DANGER ---
	var danger_data = compute_danger_vector()
	var danger_strength = danger_data.strength
	var danger_dir = danger_data.direction

	if danger_strength > 0.0:
		final_dir += danger_dir * 2.5   # weight of avoidance
		debug = "AVOID"

		# panic mode if very close
	if danger_strength > 0.5:
		score = 2.0
		player.lifedata["current_speed"] = player.lifedata["Max_speed"] * 2
		debug = "PANIC"

	# --- FOOD ---
	var food = find_safe_food()

	if food:
		if food is Dictionary:
			var offset = food["position"] - player.position
			var dist = offset.length()
			var food_dir = offset.normalized()

			var weight = clamp(5.0 / max(dist, 0.1), 1.5, 4.0)
			final_dir = food_dir # * weight
			target = food
			
		else:
			var offset = player.get_parent().get_parent().get_node("Grass_Manager2").position_array[food] - player.position
			var dist = offset.length()
			var food_dir = offset.normalized()

			var weight = clamp(5.0 / max(dist, 0.1), 1.5, 4.0)
			final_dir = food_dir # * weight
			target = food
		debug = "FOOD"

	# normalize final direction
	direction = final_dir.normalized()
	direction.y = 0

	get_parent().get_parent().get_node("debugLabel").text = debug
	return score
	

func get_wander_direction():
	return Vector3(randf_range(-1,1),0,randf_range(-1,1)) 
	
	

'func evaluate():
	target = null
	#var dist_score = 0
	var score = 0.8
	var center = Vector3.ZERO
	player.lifedata["current_speed"] =  player.lifedata["Max_speed"]/2
	
	if player.vision_danger.size()>0:
		center = look_for_danger()	
		if player.lifedata["position"].distance_to(center) < 5:
			score = 2.0
			direction = (player.position - center).normalized()
			player.lifedata["current_speed"] =  player.lifedata["Max_speed"]*2
			isFood = false
			get_parent().get_parent().get_node("debugLabel").text = "DANGER"
			return score


				
	for f in  player.vision_food.values():
		if f:
			for d in  player.vision_danger.values():
				if d:
					var distance_food_danger = center.distance_to(f["position"])		
					if distance_food_danger > 5:						
						score = 0.8
						target = f
						direction = (f["position"]- player.position ).normalized()	
						isFood = true		
						get_parent().get_parent().get_node("debugLabel").text = "FOOD"

						#var distance = player.position.distance_to(f["position"])		
						#var maxDist = 5			
					#dist_score = .8 #clamp(distance / maxDist, 0., 1)

	if target == null:
		get_parent().get_parent().get_node("debugLabel").text = "WANDER"
		
	#var energy_score = 1 - player.current_energy/player.max_energy

	#score = dist_score * energy_scorew
	direction.y = 0
	#print(target)
	return score'


func compute_danger_vector():
	var avoidance = Vector3.ZERO
	var max_radius = 10.0
	var strongest = 0.0

	for d in player.vision_danger.values():
		if d:
			if d is Dictionary:
				var offset = player.position - d["position"]
				var dist = offset.length()

				if dist < max_radius:
					var strength = (max_radius - dist) / max_radius
					avoidance += offset.normalized() * strength
					strongest = max(strongest, strength)

	return {
		"direction": avoidance.normalized() if avoidance.length() > 0 else Vector3.ZERO,
		"strength": strongest
	}


func find_safe_food():
	var safe_radius = 6.0

	for f in player.vision_food.values():
		if f:
			var safe = true

			for d in player.vision_danger.values():
				if d:
					if d is Dictionary:
						if f is Dictionary:
							if d["position"].distance_to(f["position"]) < safe_radius:
								safe = false
								break
						else:
							var t_pos = player.get_parent().get_parent().get_node("Grass_Manager2").position_array[f]
							if d["position"].distance_to(t_pos) < safe_radius:
								safe = false
								break
			if safe:
				return f

	return null

func enter():
	pass#wandertimer = 0
	
func exit():
	pass


func update(delta):
	pass
	
func physics_update(delta):

	var step = player.lifedata["current_speed"] * GlobalSimulationParameter.simulation_speed *delta
	if target:
		if target is Dictionary:
			var dist_to_target	= (target["position"] - player.position).length()
			if dist_to_target <= step and isFood:

				player.position = target["position"]
			
			else:
				#player.direction = (target["position"] - player.position).normalized()	
				player.position += direction * step	
		else:
			var t_pos = player.get_parent().get_parent().get_node("Grass_Manager2").position_array[target]
			var dist_to_target	= (t_pos - player.position).length()
			if dist_to_target <= step and isFood:

				player.position = t_pos
			
			else:
				#player.direction = (target["position"] - player.position).normalized()	
				player.position += direction * step	
	else:
		wandertimer -= delta
		if wandertimer <= 0:
			wandertimer = 5.0 / ( GlobalSimulationParameter.simulation_speed)
			direction = get_wander_direction()
			
		player.position += direction * step	

	
	player.position.x = clamp(player.position.x ,-player.World.World_Size.x/2,player.World.World_Size.x/2 )
	player.position.z = clamp(player.position.z ,-player.World.World_Size.z/2,player.World.World_Size.z/2 )
	player.lifedata["position"] = player.position
	change_bin()

func change_bin():
	var old_bin = player.lifedata["bin_ID"]
	var current_bin = player.get_parent().get_parent().get_worldbin_index(player.position)


	if old_bin == current_bin:
		return
	else:		
		player.get_parent().get_parent().remove_from_world_bin(player.lifedata)
		player.get_parent().get_parent().put_in_world_bin(player.lifedata)
