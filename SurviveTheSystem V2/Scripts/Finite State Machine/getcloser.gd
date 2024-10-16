extends State
class_name getcloser_state


var direction: Vector2
var next_path_position: Vector2 

var target: Node2D

var timer: float
var previous_pos: Vector2

@export var eating_distance: int = 16


func Enter():
	timer = 3.
	if get_parent().get_parent():
		life_entity = get_parent().get_parent()
		if target:
			life_entity.navigation_agent.target_position = target.getCenterPos()
			if not life_entity.navigation_agent.is_target_reachable():
				#print("too far /obstacle")
				remove_target()
				Transitioned.emit(self,"idle_state")
		

func Exit():
	pass
	
func Update(delta: float):
	#check if stuck every 3 second
	'if timer <= 0:
		if 	life_entity.food_array.has(target):
			life_entity.food_array.erase(target)
		target = null
		#life_entity.navigation_agent.target_position = target.getCenterPos()
		timer = 3.
	timer -= delta'
	pass
	
func Physics_Update(delta: float):
	if life_entity:
		if check_Danger():
			#print("danger")
			Transitioned.emit(self,"avoid_state")
			
		elif target:
			if target.isDead:
				#print("target dead")
				remove_target()
				Transitioned.emit(self,"idle_state")
			else:
				if life_entity.navigation_agent.is_target_reachable():
					#print("going to food")
					next_path_position = life_entity.navigation_agent.get_next_path_position()
					direction = next_path_position - life_entity.getCenterPos()
					life_entity.velocity = direction.normalized() * life_entity.maxSpeed
								
					if life_entity.getCenterPos().distance_to(target.getCenterPos())<16:
						#print("Eating")
						life_entity.Eat(target)
						life_entity.velocity = Vector2.ZERO
						remove_target()
						Transitioned.emit(self,"idle_state")
					elif target.isDead:
						#print("food was dead")
						remove_target()
						Transitioned.emit(self,"idle_state")
				else:
					remove_target()

				
		else:
			#print("food become too far /obstacle")
			Transitioned.emit(self,"idle_state")
			
			
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
