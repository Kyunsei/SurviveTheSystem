extends State
class_name eat_state

var target 
@export var eating_time = 0.5
var timer = 0.5  * GlobalSimulationParameter.simulation_speed


func evaluate():

	target = null
	var score = 1 - player.lifedata["current_energy"]/player.lifedata["Max_energy"]
	var dist_score = 0
	for f in  player.vision_food.values():
		if f:
			var distance = player.position.distance_to(f["position"])
			#print(distance)
			#print(distance)
			if distance < 2:
				target = f
				dist_score = 1.0 #clamp(distance / maxDist, 0., 1)
	return dist_score


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
			player.lifedata["current_energy"] += target["current_energy"]
			player.lifedata["current_energy"]  = clamp(player.lifedata["current_energy"]  ,0, player.lifedata["Max_energy"] )
			target["current_energy"]= 0
			get_parent().get_parent().get_parent().get_parent().get_node("Grass_Manager")._pending_external_kills.append(target)
			player.vision_food.erase(target)
			timer = eating_time/ (GlobalSimulationParameter.simulation_speed)
