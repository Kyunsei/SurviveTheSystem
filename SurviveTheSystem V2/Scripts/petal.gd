extends LifeEntity

var species = "petal"


var counter = 0

func _ready():
	Activate()



func Activate():

	self.isActive = true
	#Life.berry_pool_state[self.pool_index] = 1
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	self.size = get_node("Collision_0").shape.size

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = 100
	self.maxPV = 100
	self.lifespan = 10
	
	
	#diying
func Die():
	self.isDead = true
	$Sprite_0.modulate = Color(0.5, 0.5, 0.5,0.5)
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0

func getTransported(seed,transporter):
	seed.carried_by = transporter
	seed.z_index = 1
	transporter.item_array.append(seed)
	#if transporter.isPlayer == false and transporter.species != "spidercrab" :
		#seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)


func _on_timer_timeout():
	if World.isReady and isActive:
		if isDead == false:			
			Ageing()
			if self.age >= self.lifespan  or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	#set_physics_process(false)
	Decomposition(0)
	set_collision_layer_value(1,false)
	#$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false

	#hide()
	queue_free()
