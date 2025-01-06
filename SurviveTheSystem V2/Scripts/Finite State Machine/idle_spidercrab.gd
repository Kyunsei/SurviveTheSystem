extends State
class_name idle_spidercrab_state

var direction: Vector2
var wander_time : float


var isHungry = false
var nest: LifeEntity
@export var nest_distance: float


func choose_direction_and_time():
	direction = Vector2(randi_range(-1,1),randi_range(-1,1))
	
	if nest:
				if check_nest_distance(nest):
					pass
				else:

					direction = life_entity.position.direction_to(nest.position)
					
	wander_time = randf_range(0.2,1.)				

func Enter():
	print("enter IDLE")
	if get_parent().get_parent():
		life_entity = 	get_parent().get_parent()
		#life_entity.get_node("DebugLabel").text = "idle"
	choose_direction_and_time()
	
func Exit():
	#print("exit IDLE")
	pass
	
func Update(delta: float):
	if wander_time > 0:
		wander_time -= delta
	else:
		choose_direction_and_time()
	
func Physics_Update(delta: float):
	if life_entity:

		if life_entity.isActive and life_entity.isDead == false:
			isHungry = check_Hungry()
			life_entity.velocity = direction * get_parent().get_parent().maxSpeed * 0
			
			if check_Danger():
				Transitioned.emit(self,"avoid_state")
			
			elif isHungry:
					if check_Food():
						Transitioned.emit(self,"getcloser_state")
					else:
						life_entity.velocity = direction * get_parent().get_parent().maxSpeed * 1
			
			elif check_Enemy():
				Transitioned.emit(self,"getcloser_state")
				
					#get_parent().get_node("getcloser_state").target = nest
					#Transitioned.emit(self,"getcloser_state")
				


func check_Danger():
	var danger_entity: LifeEntity
	if life_entity.vision_array["danger"].size() > 0:
		var alive_danger = life_entity.vision_array["danger"].filter(func(obj): return obj.isDead == false)
		if alive_danger.size() > 0:
			danger_entity = getClosestLife(alive_danger)
			if life_entity.getCenterPos().distance_to(danger_entity.getCenterPos()) < World.tile_size*4:
				get_parent().get_node("avoid_state").target = danger_entity
				return true
			return false
		return false
	return false	
				

func check_Hungry():
	if isHungry == false:
		if life_entity.energy < life_entity.maxEnergy/2:
			return true
		else:
			return false
	else:
		if life_entity.energy < life_entity.maxEnergy:
			return true
		else:
			return false

func check_Food():
	if life_entity.vision_array["food"].size() > 0:
		#var s = Time.get_ticks_msec()

		var alive_array = life_entity.vision_array["food"].filter(func(obj): return obj.isDead == false)
		
		#var ss = Time.get_ticks_msec()
		#print("filter: " + str(ss-s) + "ms")
		if alive_array.size() > 0:
			get_parent().get_node("getcloser_state").target = getClosestLife(alive_array)
			get_parent().get_node("getcloser_state").action_type = "FOOD"
			
			'if life_entity.getCenterPos().distance_to(alive_array[0].getCenterPos()) <= life_entity.vision_distance:
				get_parent().get_node("avoid_state").target =  alive_array[0]'
			return true
		
		return false
	return false

func getClosestLife(array):
	var closest_entity: LifeEntity = null
	var min_distance: float = 10000
	var calc_distance: float = 0
	for p in array:
		calc_distance = life_entity.position.distance_to(p.position)
		if calc_distance <= min_distance:
			min_distance = calc_distance
			closest_entity = p
	return closest_entity


func check_nest_distance(nest):
	if life_entity.position.distance_to(nest.position) > nest_distance:
		return false
	else:
		return true


func check_Enemy():
	if life_entity.vision_array["enemy"].size() > 0:
		#var s = Time.get_ticks_msec()

		var alive_array = life_entity.vision_array["enemy"].filter(func(obj): return obj.isDead == false)
		
		#var ss = Time.get_ticks_msec()
		#print("filter: " + str(ss-s) + "ms")
		if alive_array.size() > 0:
			get_parent().get_node("getcloser_state").target = getClosestLife(alive_array)
			get_parent().get_node("getcloser_state").action_type = "ENEMY"			
			'if life_entity.getCenterPos().distance_to(alive_array[0].getCenterPos()) <= life_entity.vision_distance:
				get_parent().get_node("avoid_state").target =  alive_array[0]'
			return true
		
		return false
	return false
