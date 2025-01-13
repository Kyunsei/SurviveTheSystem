

extends LifeEntity

var species = "fox"


var barehand_array = []

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var vision_array = {
	"food": [],
	"danger": [],
	"enemy": []
}


var isBurrow = false
#movmnt
var input_dir = Vector2.ZERO

var rotation_dir = 0

var clone_timer = 0

func Build_Genome():
	pass




func Build_Stat():

	self.current_life_cycle = 0
	self.PV = 30
	self.energy = 5
	self.maxEnergy = 20
	self.maxPV = 30
	self.maxSpeed = 190
	self.size = $Sprite_0.texture.get_size()
	self.age= 0
	self.lifespan = 10*(World.one_day_length/lifecycletime)
	self.isPickable = true

	metabolic_cost = 1
	
func Build_Phenotype(): 
	pass
	


func _physics_process(delta):
	if carried_by == null and isDead == false :
		if isPlayer:
			input_dir = Player_Control_movement()
		move_and_slide()
		global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
		global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
		
		if item_array.size() > 0:
			var c = 0
			for i in item_array:
					i.position = position #+ Vector2(48+c*16,-64)
					c += 1
		



func getDamaged(value,antagonist:LifeEntity=null):
	if InvicibilityTime == 0:
		getPushed(antagonist,64)
		$Sound/hurt.playing = true
		vision_array["danger"].append(antagonist)
		self.PV -= value
		if self.PV <= 0:
			Die()
		InvicibilityTime = 1 
		modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.1).timeout
		InvicibilityTime = 0
		modulate = Color(1, 1, 1)

		


func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
		
			Metabo_cost(3)
			Ageing()
			LifeDuplicate()
			Growth()



			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			if energy <= 0:
				Deactivate()
			else:
				energy -= 5

func Growth():
	if current_life_cycle == 0:
		#10*(World.one_day_length/lifecycletime)
		if self.age > 3*(World.one_day_length/lifecycletime) and self.energy >= 15:
			self.current_life_cycle += 1
			
			
			self.isPickable = false
			
			Update_sprite($Sprite_1,$Collision_1)

			size = current_sprite.texture.get_size()
			
			#reset vision
			vision_array["food"] = []
			vision_array["danger"] = []
			$Vision/Collision.disabled = true
			$Vision/Collision.disabled = false
			
			maxSpeed = 190
			self.maxEnergy = 30
			self.maxPV = 30
			self.PV = self.maxPV

func LifeDuplicate():
	#10*(World.one_day_length/lifecycletime)
	if self.age > 5.*(World.one_day_length/lifecycletime) and self.energy >= 25 and current_life_cycle >= 1:
			if clone_timer == 0 :
				
				var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
				var life = Life.build_life(species)
				if life != null:
					self.energy -= 15			
					life.energy = 15
					life.global_position = newpos 
					clone_timer = 3.*(World.one_day_length/lifecycletime)
				else:
					print("fox_pool empty")
			else:
				clone_timer -= 1





func Drop():
	if item_array.size() >0:
		item_array[0].carried_by = null
		item_array[0].z_index = 0
		item_array.remove_at(0)


func Throw():
	pass


			

func Die():
	self.isDead = true
	velocity = Vector2(0,0)
	Drop()
	Update_sprite(get_node("Dead_Sprite_"+str(current_life_cycle)))

	
	
func Activate():

	set_physics_process(true)
	Update_sprite($Sprite_0, $Collision_0)
	self.isActive = true
	self.isDead = false
	$Brainy.Activate()
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	#$Collision_1.disabled = true
	#$Collision_1.hide()
	Build_Stat()
	show()
	
	set_collision_layer_value(1,true)
	$Vision.set_collision_mask_value(1,true)

	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))


	#$Collision_0.show()
	#$Collision_0.disabled = false	
	#$Dead_Sprite_0.hide()	
	#$Sprite_0.show()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	$Brainy.Desactivate()
	#Decomposition(1)
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	hide()

func Eat(life):
	if life.species == "berry" and life.current_life_cycle == 3:
		life.LifeDuplicate2(null)
	else:
		self.energy += life.energy
		energy = clamp(energy,0,maxEnergy)
		life.energy= 0
		life.Die()
		life.cause_of_death = deathtype.EATEN







	
func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self

func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null


func _on_vision_body_entered(body):
	if body.species== "sheep":
		if body.current_life_cycle < 2:
			vision_array["food"].append(body)

	if body.species== "berry":
		if body.current_life_cycle == 0 or body.current_life_cycle == 3 :
			vision_array["food"].append(body)
			
	if body.species == "spidercrab":
		if body.current_life_cycle == 1:
			vision_array["danger"].append(body)


		#getAway(body.position)


func _on_vision_body_exited(body):
	for n in vision_array:
		if vision_array[n].has(body):
			vision_array[n].erase(body)

