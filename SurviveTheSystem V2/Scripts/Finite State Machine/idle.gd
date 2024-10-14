extends State
class_name idle_state


var direction: Vector2i
var wander_time : float


func choose_direction_and_time():
	direction = Vector2(randi_range(-1,1),randi_range(-1,1))
	wander_time = randf_range(0.2,1.)
	

func Enter():

	choose_direction_and_time()
	
func Exit():
	pass
	
func Update(delta: float):
	if wander_time > 0:
		wander_time -= delta
	
	else:
		choose_direction_and_time()
	
func Physics_Update(delta: float):
	if get_parent().get_parent():
		get_parent().get_parent().velocity = direction * get_parent().get_parent().maxSpeed * 0.5
		
		if get_parent().get_parent().danger_array.size() > 0:
			var danger_temp = get_parent().get_parent().danger_array.duplicate()
			var alive_danger = danger_temp.filter(func(obj): return obj.isDead == false)
			if alive_danger.size() > 0:
				alive_danger.sort_custom(compare_by_distance)
				if get_parent().get_parent().getCenterPos().distance_to(alive_danger[0].getCenterPos()) < 100:
					Transitioned.emit(self,"avoid_state")

		if get_parent().get_parent().energy < get_parent().get_parent().maxEnergy and  get_parent().get_parent().food_array.size() > 0:
				Transitioned.emit(self,"getcloser_state")
