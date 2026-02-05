extends State
class_name getcloser_state


var direction: Vector2
var next_path_position: Vector2 

var target: Node2D
var target_register_pos : Vector2

var timer: float
var previous_pos: Vector2

var action_type = "FOOD" 

@export var action_distance: int = 16

@export var chasing_max_timer: float = 10



@export var minimun_distance: int = 0
@export var maximun_distance: int = 32*5
@export var next_state = ""


func Enter():
	timer = chasing_max_timer
	if get_parent().get_parent():
		life_entity = get_parent().get_parent()
		if target:
			life_entity.navigation_agent.target_position = target.getCenterPos()
			target_register_pos = target.getCenterPos() 
			if not life_entity.navigation_agent.is_target_reachable():
				#print("too far /obstacle")
				remove_target()
				Transitioned.emit(self,"idle_state")
		#life_entity.get_node("DebugLabel").text = "get closer"
func Exit():
	pass
	
func Update(delta: float):
	#check if stuck every 3 second
	if timer <= 0:
		remove_target()
		timer = chasing_max_timer
	timer -= delta
	pass
	
func Physics_Update(delta: float):
	if life_entity:
		if life_entity.isActive and life_entity.isDead == false:
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
						if target.isDead:
							remove_target()
							Transitioned.emit(self,"idle_state")
						#print("going to food")
						if target_register_pos != target.getCenterPos():
							life_entity.navigation_agent.target_position = target.getCenterPos()
							target_register_pos = target.getCenterPos() 
							
						next_path_position = life_entity.navigation_agent.get_next_path_position()
						direction = next_path_position - life_entity.getCenterPos()
						life_entity.velocity = direction.normalized() * life_entity.maxSpeed 
	
						
						

						if life_entity.getCenterPos().distance_to(target.getCenterPos())<minimun_distance and next_state != "":
								get_parent().get_node(next_state).target = target
								Transitioned.emit(self,next_state)
											
						elif life_entity.getCenterPos().distance_to(target.getCenterPos())<action_distance:
							#print("Eating")
							if action_type == "FOOD":
								var action_func = Callable(life_entity, "Eat")
								action_func.call(target)
							elif action_type == "ENEMY":
								var action_func = Callable(target, "getDamaged")
								action_func.call(8) 
							#life_entity.Eat(target)
							life_entity.velocity = Vector2.ZERO
							if target.isDead:
								remove_target()
							Transitioned.emit(self,"idle_state")
							
						
					
					else:

						remove_target()
						Transitioned.emit(self,"idle_state")

					
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
	for n in life_entity.vision_array:
		if 	life_entity.vision_array[n].has(target):
				if n == "food":
					life_entity.vision_array[n].erase(target)
				target = null
