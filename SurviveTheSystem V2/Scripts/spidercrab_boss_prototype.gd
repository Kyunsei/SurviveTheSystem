extends LifeEntity

var species = "sc_boss"


var vision_array = {
	"food": [],
	"danger": []
}



#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0


func Build_Stat():
	self.current_life_cycle = 0
	self.PV = 60# Genome["maxPV"][self.current_life_cycle]	
	self.energy = 80
	self.maxPV = 60#Genome["maxPV"][self.current_life_cycle]	
	self.maxSpeed = 190
	self.age= 0



func _physics_process(delta):
	if isPlayer and isDead == false:
		input_dir = Player_Control_movement()

	move_and_collide(velocity *delta)
	global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	if item_array.size() > 0:
		var c = 0
		for i in item_array:
				i.position = position + Vector2(48+c*16,-64)
				c += 1
	
	if direction.normalized() != Vector2(0,0):
		last_dir = direction

func getDamaged(value):
	if InvicibilityTime == 0:
		self.PV -= value
		if self.PV <= 0:
			Die()
		InvicibilityTime = 1 
		modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.1).timeout
		InvicibilityTime = 0
		modulate = Color(1, 1, 1)

	if self.has_node("HP_bar"):
		self.AdjustBar()
		self.get_node("HP_bar").show()

func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:

			Metabo_cost()
			Ageing()
			AdjustBar()
			LifeDuplicate()
			Growth()

			if self.energy <= 0 or self.age >= Genome["lifespan"][self.current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

func Die():
	self.isDead = true
	velocity = Vector2(0,0)
	$Sprite_mainbody.hide()
	

	
	
func Activate():
	print("Im a mean boss and I activated just now")
	set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	$Collision_front.disabled = false
	$Collision_front.show()
	$Collision_back.disabled = false
	$Collision_back.show()
	Build_Stat()
	show()
	
	set_collision_layer_value(1,true)



func Deactivate():	
	set_physics_process(false)
	Decomposition(1)
	set_collision_layer_value(1,false)
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	hide()

func Eat(life):
	self.energy += life.energy
	life.energy= 0
	life.Die()
	life.cause_of_death = deathtype.EATEN

