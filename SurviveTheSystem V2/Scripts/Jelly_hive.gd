extends LifeEntity

var species = "jellyhive"

var bee_in_proximity = []
var danger_array = []

func _ready():
	Activate()
	
	
func Activate():
	#set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Build_Stat()
	show()
	set_collision_layer_value(1,true)
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))


func Deactivate():
	queue_free()
	
func Build_Stat():
	PV = 100
	energy = 50

func spawn_jellybee():
	if energy >= 10:
		var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
			#Lpool Technique
		var li = Life.jellybee_pool_state.find(0)	
		#+ Life.grass_pool_state.size()*0.05
		if li > -1: # and Life.sheep_number  < Life.sheep_pool_scene.size():
			self.energy -= 10
			Life.jellybee_pool_scene[li].Activate()
			Life.jellybee_pool_scene[li].energy = 10
			Life.jellybee_pool_scene[li].age = 0
			Life.jellybee_pool_scene[li].current_life_cycle = 0
			Life.jellybee_pool_scene[li].PV = 10
			Life.jellybee_pool_scene[li].global_position = newpos 
			Life.jellybee_pool_scene[li].hive = self
			energy -= 10
		else:
			pass
			print("jellybee_pool empty")




func call_jellybee_to_help(body):
	for b in bee_in_proximity:
		b.angry_mode_on(body)

func calm_down_bee(body):
	for b in bee_in_proximity:
		if b.danger_array.has(body):
			b.danger_array.erase(body)

func _on_timer_timeout():
	if World.isReady and isActive:
		spawn_jellybee()
		if self.energy <= 0  or self.PV <=0:
			Die()			
		if current_time_speed != World.speed:
			adapt_time_to_worldspeed()
	else:
		Deactivate()			


func _on_vision_body_entered(body):
	if body.species == "jellybee":
		bee_in_proximity.append(body)
	if body.species == "catronaute":
		call_jellybee_to_help(body)
		danger_array.append(body)


func _on_vision_body_exited(body):
	if bee_in_proximity.has(body):
		bee_in_proximity.erase(body)
	if danger_array.has(body):
		danger_array.erase(body)
		calm_down_bee(body)


