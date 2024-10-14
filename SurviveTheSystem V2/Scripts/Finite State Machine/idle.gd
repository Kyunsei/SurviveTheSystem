extends State
class_name idle_state


var direction: Vector2i
var wander_time : float

var life_entity: LifeEntity


func choose_direction_and_time():
	direction = Vector2(randi_range(-1,1),randi_range(-1,1))
	wander_time = randf_range(0.2,1.)
	

func Enter():
	if get_parent().get_parent():
		life_entity = 	get_parent().get_parent()
	choose_direction_and_time()
	
func Exit():
	pass
	
func Update(delta: float):
	if wander_time > 0:
		wander_time -= delta
	else:
		choose_direction_and_time()
	
func Physics_Update(delta: float):
	if life_entity:
		life_entity.velocity = direction * get_parent().get_parent().maxSpeed * 0.5
		
		if check_Danger():
			Transitioned.emit(self,"avoid_state")
		
		elif check_Hungry():
			if check_Food():
				Transitioned.emit(self,"getcloser_state")
			else:
				pass
				
		
	


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
				
func check_Food():
	if life_entity.food_array.size() > 0:
		var alive_array = life_entity.food_array.filter(func(obj): return obj.isDead == false)
		if alive_array.size() > 0:
			alive_array.sort_custom(compare_by_distance)
			#if life_entity.getCenterPos().distance_to(alive_danger[0].getCenterPos()) < 100:
			get_parent().get_node("getcloser_state").target = alive_array[0]
			return true
		return false
	return false

func check_Hungry():
	if life_entity.energy < life_entity.maxEnergy:
		return true
	else:
		return false


