extends State
class_name getcloser_state


var direction: Vector2

var target: Node2D

func Enter():
	pass





	
func Exit():
	pass
	
func Update(delta: float):
	pass
	
func Physics_Update(delta: float):
	if get_parent().get_parent():
		if get_parent().get_parent().food_array.size() > 0:
			var food_temp = get_parent().get_parent().food_array.duplicate()
			var alive_food = food_temp.filter(func(obj): return obj.isDead == false)
			if alive_food.size() > 0:
				alive_food.sort_custom(compare_by_distance)
				target = alive_food[0]
				var center = get_parent().get_parent().getCenterPos() #  position + Vector2(32,-32) #temporaire
				direction = -(center - target.getCenterPos())
				get_parent().get_parent().velocity = direction.normalized() * get_parent().get_parent().maxSpeed
		
				if direction.length()<16:
					get_parent().get_parent().Eat(target)
					get_parent().get_parent().velocity = Vector2.ZERO
					if get_parent().get_parent().energy >= get_parent().get_parent().maxEnergy:
						Transitioned.emit(self,"idle_state")

		else:
			Transitioned.emit(self,"idle_state")
			
			
	
		
