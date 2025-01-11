extends State
class_name dash_state


var direction: Vector2
var next_path_position: Vector2 

var target: Node2D

var timer: float
var previous_pos: Vector2

@export var eating_distance: int = 16
@export var speed_multiplicator: int = 8

@export var charge_duration: float = .3
@export var charging_time: float = 1.

var timer_dash_count : float = 0
var timer_dash_prep_count : float = 0
var charge_direction : Vector2 
var isDashing: bool = false

func Enter():
	#print("enter DASH")
	if get_parent().get_parent(): 
		life_entity = get_parent().get_parent()
		timer_dash_prep_count = charging_time
		life_entity.velocity = Vector2.ZERO
		life_entity.get_node("Sound").get_node("coucou").playing = true
		#life_entity.get_node("DebugLabel").text = "dash"
func Exit():
	#print("exit DASH")
	life_entity.set_collision_mask_value(2,true)
	life_entity.get_node("Sprite_0").modulate =  Color(1,1,1,1) 
	isDashing = false
	
func Update(_delta: float):
	if not isDashing:
		Charge_preparation(_delta)
	else:
		if timer_dash_count > 0:
			timer_dash_count -= _delta
			if timer_dash_count <= 0:
				isDashing = false
				life_entity.velocity = Vector2.ZERO
				life_entity.set_collision_mask_value(2,true)

				Transitioned.emit(self,"idle_state")

		
func Physics_Update(_delta: float):
	#if "food" in range :
		#Get speed, get rotation.body.target
		#change color delta -= 1 second
		#go in straight line after delta == 0
	
	
	if life_entity:
		if life_entity.isActive and life_entity.isDead == false:
			if check_Danger() and not isDashing:

				Transitioned.emit(self,"avoid_state")
			elif target:
				if target.isDead:
					remove_target()

					Transitioned.emit(self,"idle_state")
				else :
						direction = target.getCenterPos() - life_entity.position
						life_entity.rotation = direction.angle()
						'if not isDashing:
						ChargeToward(target)'
						if life_entity.position.distance_to(target.getCenterPos())<eating_distance + (eating_distance*life_entity.current_life_cycle):
							life_entity.Eat(target)
							life_entity.velocity = Vector2.ZERO
							remove_target()

					
							Transitioned.emit(self,"idle_state")
						elif target.isDead:
							remove_target()

							Transitioned.emit(self,"idle_state")
						'else:
						remove_target()'




func check_Danger():
	var danger_entity: LifeEntity
	if life_entity.vision_array["danger"].size() > 0:
		var alive_danger = life_entity.vision_array["danger"].filter(func(obj): return obj.isDead == false)
		if alive_danger.size() > 0:
			danger_entity = getClosestLife(alive_danger)
			if life_entity.getCenterPos().distance_to(danger_entity.getCenterPos()) < World.tile_size*2:
				get_parent().get_node("avoid_state").target = danger_entity
				return true
			return false
		return false
	return false

func remove_target():
	for n in life_entity.vision_array:
		if life_entity.vision_array[n].has(target):
			life_entity.vision_array[n].erase(target)
			target = null
	'if 	life_entity.vision_array["food"].has(target):
			life_entity.vision_array["food"].erase(target)
			target = null'

func ChargeToward(food_source):
	isDashing = true
	var center = life_entity.getCenterPos()
	charge_direction = -(center - food_source.getCenterPos()).normalized()
	life_entity.rotation = charge_direction.angle()
	life_entity.velocity = charge_direction * life_entity.maxSpeed*speed_multiplicator	
	timer_dash_count = charge_duration	
	life_entity.set_collision_mask_value(2,false)

func Charge_preparation(_delta):
	if timer_dash_prep_count > 0:
		timer_dash_prep_count -= _delta
		life_entity.get_node("Sprite_0").modulate = Color(1,0,0,1) 
	else:
		life_entity.get_node("Sprite_0").modulate =  Color(1,1,1,1) 

		if target:
			ChargeToward(target)
		else:

			Transitioned.emit(self,"idle_state")
