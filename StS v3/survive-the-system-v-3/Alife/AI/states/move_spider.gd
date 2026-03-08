extends State
class_name move_state_spider

var wandertimer = 0
var target 
var direction = Vector3()
var isFood = true



func evaluate():
	target = null
	var score = 0.5
	var debug = "CHILL"


	if player.lifedata["current_energy"]  < player.lifedata["Max_energy"] /2:
		debug = "Hungry"
		var food = find_safe_food()

		if food:
			if food is Dictionary:
				var offset = food["position"] - player.position
				var dist = offset.length()
				var food_dir = offset.normalized()
				player.lifedata["current_speed"] = 22
				direction = food_dir 
				target = food
				if GlobalSimulationParameter.life_numbers != {}:
					if target["Species"] == Alifedata.enum_speciesID.SHEEP:
						if player.get_parent().get_parent().current_life_count_by_species[Alifedata.enum_speciesID.SHEEP] < 2:
							return 0
	get_parent().get_parent().get_node("debugLabel").text = debug

	return score
	

func get_wander_direction():
	return Vector3(randf_range(-1,1),0,randf_range(-1,1)) 
	
	


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
