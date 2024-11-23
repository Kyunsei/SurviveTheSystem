extends State
class_name dash_state


var direction: Vector2
var next_path_position: Vector2 

var target: Node2D

var timer: float
var previous_pos: Vector2

@export var eating_distance: int = 16
@export var speed_multiplicator: int = 1

func Enter():
	print("DECHE STATE")
	if get_parent().get_parent(): 
		life_entity = get_parent().get_parent()

func Exit():
	pass
	
func Update(_delta: float):
	pass
	
func Physics_Update(_delta: float):
	#if "food" in range :
		#Get speed, get rotation.body.target
		#change color delta -= 1 second
		#go in straight line after delta == 0
	
	if life_entity:
		if life_entity.isActive and life_entity.isDead == false:
			if check_Danger():
				Transitioned.emit(self,"avoid_state")
			elif target:
				if target.isDead:
					remove_target()
					Transitioned.emit(self,"idle_spidercrab_state")
				else :
					ChargeToward(target)
					if self :
						if life_entity.getCenterPos().distance_to(target.getCenterPos())<eating_distance:
							life_entity.Eat(target)
							life_entity.velocity = Vector2.ZERO
							remove_target()
							Transitioned.emit(self,"idle_spidercrab_state")
						elif target.isDead:
							remove_target()
							Transitioned.emit(self,"idle_spidercrab_state")
					else:
						remove_target()




func check_Danger():
	var danger_entity: LifeEntity
	if life_entity.vision_array["danger"].size() > 0:
		var alive_danger = life_entity.vision_array["danger"].filter(func(obj): return obj.isDead == false)
		if alive_danger.size() > 0:
			danger_entity = getClosestLife(alive_danger)
			if life_entity.getCenterPos().distance_to(danger_entity.getCenterPos()) < World.tile_size*6:
				get_parent().get_node("avoid_state").target = danger_entity
				return true
			return false
		return false
	return false

func remove_target():
	if 	life_entity.vision_array["food"].has(target):
			life_entity.vision_array["food"].erase(target)
			target = null

func ChargeToward(food_source):
	var center = life_entity.getCenterPos()
	var direction = -(center - food_source.getCenterPos()).normalized()
	life_entity.velocity = direction * life_entity.maxSpeed*speed_multiplicator			
