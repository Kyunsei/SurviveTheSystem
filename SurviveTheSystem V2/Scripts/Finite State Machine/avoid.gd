extends State
class_name avoid_state

var direction: Vector2

var target: Node2D
var previous_position: Vector2 
var timer: float = 0
var escaping_void: bool = false

@export var idle_type_state = "idle_state"
@export var dodge_speed: float = 4
@export var detection_distance: int = World.tile_size*10


func Enter():
	if get_parent().get_parent():
		life_entity = get_parent().get_parent()
		life_entity.get_node("DebugLabel").text = "avoid"
		if life_entity.species == "sheep" :
			var sound = ["avoid","avoid2"]
			var rd_id = randi_range(0,1)
			life_entity.get_node("Sound").get_node(sound[rd_id]).pitch_scale = 3 - life_entity.current_life_cycle
			life_entity.get_node("Sound").get_node(sound[rd_id]).playing = true
		elif life_entity.species == "fox" :
			life_entity.get_node("Sound").get_node("hish").playing = true
		if life_entity.species == "spidercrab" :
			print("entered avoid state SPIDERCRAB")
	
func Exit():
	pass
	
func Update(delta: float):
	if escaping_void:
		if timer > 0:
			timer -= delta
		else:
			escaping_void = false
	
func Physics_Update(delta: float):
	if life_entity and target:
		if life_entity.isActive and life_entity.isDead == false:
			if escaping_void == false:
				direction = (life_entity.getCenterPos()  - target.getCenterPos())
				#check if void 
				#print(life_entity.position)
				#print(life_entity.position + direction.normalized() *detection_distance)
				'if life_entity.position + direction *detection_distance:
						print("void")'
				life_entity.velocity = direction.normalized() * life_entity.maxSpeed *dodge_speed
				if life_entity.species == "spidercrab" :
					life_entity.rotation = direction.angle()
				if previous_position == life_entity.position:
					timer = 0.3
					escaping_void = true
					life_entity.velocity = (Vector2(randf_range(-1,1),randf_range(-1,1)) ) * life_entity.maxSpeed *dodge_speed
					if life_entity.species == "spidercrab" :
						life_entity.rotation = direction.angle()
				previous_position = life_entity.position
				if direction.length() >  detection_distance:
						Transitioned.emit(self,idle_type_state)
			else:
				if previous_position == life_entity.position:
					timer = 0.3
					escaping_void = true
					life_entity.velocity =  (Vector2(randf_range(-1,1),randf_range(-1,1)) ) * life_entity.maxSpeed *dodge_speed
					if life_entity.species == "spidercrab" :
						life_entity.rotation = direction.angle()
		
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
