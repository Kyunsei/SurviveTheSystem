extends State
class_name getcloser_state


var direction: Vector2

var target: Node2D
var life_entity: LifeEntity

func Enter():
	if get_parent().get_parent():
		life_entity = get_parent().get_parent()
		

func Exit():
	pass
	
func Update(delta: float):
	pass
	
func Physics_Update(delta: float):
	if life_entity:
		if check_Danger():
			Transitioned.emit(self,"avoid_state")
			
		elif target:
			direction = -(life_entity.getCenterPos() - target.getCenterPos())
			life_entity.velocity = direction.normalized() * life_entity.maxSpeed
		
			if direction.length()<16:
				life_entity.Eat(target)
				life_entity.velocity = Vector2.ZERO
				if target.isDead:
					target = null
					Transitioned.emit(self,"idle_state")


				'get_parent().get_parent().velocity = Vector2.ZERO
					if get_parent().get_parent().energy >= get_parent().get_parent().maxEnergy:
					Transitioned.emit(self,"eat_state")'

		else:
			Transitioned.emit(self,"idle_state")
			
			
	
func check_Danger():
	if life_entity.danger_array.size() > 0:
		var alive_danger = life_entity.danger_array.filter(func(obj): return obj.isDead == false)
		if alive_danger.size() > 0:
			alive_danger.sort_custom(compare_by_distance)
			if life_entity.getCenterPos().distance_to(alive_danger[0].getCenterPos()) < World.tile_size*6:
				get_parent().get_node("avoid_state").target = alive_danger[0]
				return true
			return false
		return false
	return false		
