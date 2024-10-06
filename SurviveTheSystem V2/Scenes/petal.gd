extends LifeEntity

var species = "petal"


var counter = 0

func Build_Genome():
	Genome["maxPV"]=[1000]
	Genome["soil_absorption"] = [0]
	Genome["lifespan"]=[300]#randi_range(15,20)]
	#Genome["sprite"] = [preload("res://Art/berry_1.png"),preload("res://Art/berry_3.png"),preload("res://Art/berry_4.png"),preload("res://Art/berry_5.png")]
	#Genome["dead_sprite"] = [preload("res://Art/berry_dead.png")]

func Activate():

	self.isActive = true
	#Life.berry_pool_state[self.pool_index] = 1
	Build_Stat()
	set_collision_layer_value(1,1)
	$Vision.set_collision_mask_value(1,true)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	self.size = get_node("Collision_0").shape.size

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 1
	
	
	#diying
func Die():
	self.isDead = true
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
