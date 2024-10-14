extends State
class_name avoid_state

var direction: Vector2
var target: Node2D


func Enter():
	if get_parent().get_parent():
		if get_parent().get_parent().danger_array[0]:
			var danger_temp = get_parent().get_parent().danger_array.duplicate()
			var alive_danger = danger_temp.filter(func(obj): return obj.isDead == false)
			if alive_danger.size() > 0:
				alive_danger.sort_custom(compare_by_distance)
				var target = alive_danger[0]
	
func Exit():
	pass
	
func Update(delta: float):
	pass
	
func Physics_Update(delta: float):
	if get_parent().get_parent():
		var center = get_parent().get_parent().getCenterPos() #  position + Vector2(32,-32) #temporaire
		direction = (center - target.getCenterPos())
		get_parent().get_parent().velocity = direction.normalized() * get_parent().get_parent().maxSpeed *1.5
	
	if direction.length()>100:
		Transitioned.emit(self,"idle_state")
		
