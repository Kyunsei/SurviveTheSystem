extends State
class_name avoid_state

var direction: Vector2

var target: Node2D

@export var detection_distance: int = World.tile_size*10


func Enter():
	if get_parent().get_parent():
		life_entity = get_parent().get_parent()
		
	
func Exit():
	pass
	
func Update(delta: float):
	pass
	
func Physics_Update(delta: float):
	if life_entity and target:
		direction = (life_entity.getCenterPos()  - target.getCenterPos())
		life_entity.velocity = direction.normalized() * life_entity.maxSpeed *2.
		if direction.length() >  detection_distance:
				Transitioned.emit(self,"idle_state")
		
	'if life_entity:
		if life_entity.danger_array.size()>0:
			var danger_temp = life_entity.danger_array.duplicate()
			var alive_danger = danger_temp.filter(func(obj): return obj.isDead == false)
			if alive_danger.size() > 0:
				alive_danger.sort_custom(compare_by_distance)
				var target = alive_danger[0]

		if target:
			var center = get_parent().get_parent().getCenterPos() #  position + Vector2(32,-32) #temporaire
			direction = (center - target.getCenterPos())
			get_parent().get_parent().velocity = direction.normalized() * get_parent().get_parent().maxSpeed *1.5
	
			if direction.length()>100:
				Transitioned.emit(self,"idle_state")
		else:
			Transitioned.emit(self,"idle_state")'
