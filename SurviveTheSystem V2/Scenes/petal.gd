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
	self.PV = 10
	self.maxPV = 10
	
	
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
			if self.energy <= 0 or self.age >= self.lifespan  or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()
