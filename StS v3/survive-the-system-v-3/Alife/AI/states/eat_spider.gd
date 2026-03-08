extends State
class_name eat_state_spider

var target 
@export var eating_time = 0.5
var timer = 0.5  * GlobalSimulationParameter.simulation_speed


func evaluate():
	target = null
	var score = 1 - player.lifedata["current_energy"]/player.lifedata["Max_energy"]
	var dist_score = 0
	var distance : float
	for f in  player.vision_food.values():
		if f:
			if f is Dictionary:
				distance = player.position.distance_to(f["position"])
				if GlobalSimulationParameter.life_numbers != {}:
					if f["Species"] == Alifedata.enum_speciesID.SHEEP:
						if GlobalSimulationParameter.life_numbers[Alifedata.enum_speciesID.SHEEP][-1] < 2:
							return 0
				
			else:
				var t = player.get_parent().get_parent().get_node("Grass_Manager2").position_array[f]
				distance = player.position.distance_to(t)
			

			if distance < 2:
				target = f
				dist_score = 1.0 #clamp(distance / maxDist, 0., 1)
	return dist_score * score


func enter():
	isFinish = false
	timer = eating_time / (GlobalSimulationParameter.simulation_speed)

func exit():
	isFinish = true


func physics_update(delta):
	pass

func update(delta):
	
	timer -= delta
	if timer <= 0:
		if target:
			if target is Dictionary:
				player.lifedata["current_energy"] += target["Biomass"] 
				#player.lifedata["current_energy"]  = clamp(player.lifedata["current_energy"]  ,0, player.lifedata["Max_energy"] )
				
				if target["Species"] == Alifedata.enum_speciesID.SHEEP:
					target["current_health"] = -100
		
				
				if target["Species"] == Alifedata.enum_speciesID.CAT:
					target["current_health"] = -100
			
					
				player.vision_food.erase(target)
				timer = eating_time/ (GlobalSimulationParameter.simulation_speed)
			else:
				var g_manager = player.get_parent().get_parent().get_node("Grass_Manager2")
				player.lifedata["current_energy"] += g_manager.current_biomass_array[target] * 5
				
				
				#player.lifedata["current_energy"]  = clamp(player.lifedata["current_energy"]  ,0, player.lifedata["Max_energy"] )
				g_manager.remove_from_world(target)
				#g_manager.Active[target]= 0

				#get_parent().get_parent().get_parent().get_parent().get_node("Grass_Manager")._pending_external_kills.append(target)
				player.vision_food.erase(target)
				timer = eating_time/ (GlobalSimulationParameter.simulation_speed)
