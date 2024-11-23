extends LifeEntity


# sheep script
var species = "sheep"




var vision_array = {
	"food": [],
	"danger": [],
	"friend": []
}

var repro_counter = 0

var input_dir = Vector2(0,0)

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var vision_distance: int 

func Build_Genome():
	Genome["maxPV"]=[15,10,20]
	Genome["speed"] =[0,150,100]
	Genome["lifespan"]=[5*(World.one_day_length/lifecycletime),5*(World.one_day_length/lifecycletime),5*(World.one_day_length/lifecycletime)]
	Genome["sprite"] = [preload("res://Art/sheep1.png"),preload("res://Art/sheep2.png"),preload("res://Art/sheep3.png")]
	Genome["dead_sprite"] = [preload("res://Art/sheep_dead1.png"),preload("res://Art/sheep_dead2.png"),preload("res://Art/sheep_dead3.png")]

func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	
	# SPRITE
	$Sprite_0.texture = Genome["sprite"][0]
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()

	$Sprite_1.texture = Genome["sprite"][1]
	$Sprite_1.offset.y = -$Sprite_1.texture.get_height()
	$Sprite_1.hide()
	
	$Sprite_2.texture = Genome["sprite"][2]
	$Sprite_2.offset.y = -$Sprite_2.texture.get_height()
	$Sprite_2.offset.x = -$Sprite_2.texture.get_width()/4

	$Sprite_2.hide()
	
	$Dead_Sprite_0.texture = Genome["dead_sprite"][0]
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	$Dead_Sprite_0.hide()

	$Dead_Sprite_1.texture = Genome["dead_sprite"][1]
	$Dead_Sprite_1.offset.y = -$Dead_Sprite_1.texture.get_height()
	$Dead_Sprite_1.hide()

	$Dead_Sprite_2.texture = Genome["dead_sprite"][2]
	$Dead_Sprite_2.offset.y = -$Dead_Sprite_2.texture.get_height()
	$Dead_Sprite_2.offset.x = -$Dead_Sprite_2.texture.get_width()/4
	$Dead_Sprite_2.hide()


		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 600
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_2.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	$Collision_1.hide()
	$Collision_1.disabled = true		

func Build_Stat():
	Build_Genome()
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 5
	self.maxSpeed = Genome["speed"][self.current_life_cycle]
	size = Vector2(32,32)
	self.age= 0
	self.maxEnergy = 30.

	self.lifespan = 4*(World.one_day_length/lifecycletime)

	self.vision_distance = 500

func _physics_process(delta):
	'if isPlayer:
		input_dir = Player_Control_movement()	
	if isDead == false:
		Brainy()
	else:
		velocity = Vector2(0,0)'
	velocity = velocity * World.speed 
	move_and_slide()	
	global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	
	if item_array.size() > 0:
		for i in item_array:
			i.position = position+Vector2(0,-32)
		
func _on_timer_timeout():
	
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
			if self.current_life_cycle !=0:
				pass
				Metabo_cost()
				Metabo_cost()
				Metabo_cost()
				Metabo_cost()
				Metabo_cost()
				#self.energy += 20	
			LifeDuplicate()
			Ageing()
			Growth()
			AdjustDirection()
			if self.energy <= 0 or self.age >= Genome["lifespan"][self.current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		$DebugLabel.text = str(age) + " " + str(energy)




#diying
func Die():
	$Brainy.Desactivate()
	for i in item_array:
		i.carried_by = null
		i.z_index = 0
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	item_array = []

	
	
	self.isDead = true
	if self.current_life_cycle == 0:
		$Dead_Sprite_0.show()
		$Sprite_0.hide()
	elif self.current_life_cycle == 1:
		$Dead_Sprite_1.show()
		$Sprite_1.hide()
	elif self.current_life_cycle == 2: 	
		$Dead_Sprite_2.show()
		$Sprite_2.hide()


#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 0.5*(World.one_day_length/lifecycletime) and self.energy > 4:
			self.current_life_cycle += 1
			$Sprite_1.show()
			$Sprite_0.hide()
			set_physics_process(true)
			self.maxSpeed = Genome["speed"][self.current_life_cycle]
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV
			self.maxEnergy = 10
			self.size = Vector2(32,32)
			$Brainy.Activate()

	if current_life_cycle == 1:

		if self.age > 2.5*(World.one_day_length/lifecycletime) and self.energy > 8:

			self.current_life_cycle += 1
			$Sprite_2.show()
			$Sprite_1.hide()
			$Collision_0.hide()
			$Collision_1.show()
			$Collision_1.disabled = false		
			$Collision_0.disabled = true	
			self.maxSpeed = Genome["speed"][self.current_life_cycle]
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV
			self.maxEnergy = 20
			size = Vector2(64,64)

			


#Duplication
func LifeDuplicate():
	
	if current_life_cycle == 2 :

		if self.age > 3.5*(World.one_day_length/lifecycletime)  and self.energy > 10 and repro_counter <= 0:
			repro_counter = 2*(World.one_day_length/lifecycletime)
			var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
			for i in range(0,min(3,int(self.energy-5)/5)):

			#Lpool Technique
				var life = Life.build_life(species)
				if life != null:
					self.energy -= 5
					life.energy = 5
					life.global_position = PickRandomPlaceWithRange(position,1 * World.tile_size)
				else:
					print("sheep_pool empty")
		else:
			repro_counter -= 1



'func Brainy():
	var center = position + Vector2(32,-32) #temporaire
	var danger_array_temp = danger_array.duplicate()
	var food_array_temp = food_array.duplicate()
	var friend_array_temp = friend_array.duplicate()


	if danger_array_temp.size() > 0 :
		var cl = getClosestLife(danger_array_temp,1000)
		if cl != null:
			var random = randi_range(0,100)
			var probability = clamp(1.0 - (position.distance_to(cl.getCenterPos()) / 300), 0.0, 1.0) * 100
			if random <= probability:
				getAway(cl.getCenterPos())


	if action_finished == true:
		if self.energy < 80 and food_array_temp.size()>0:
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:
				#$DebugLabel.text ="feeding"
				if center.distance_to(cl.getCenterPos()) < 32 and cl.isDead == false:
						Eat(cl)
				if cl.isDead == false:
						getCloser(cl.getCenterPos())
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		#elif friend_array_temp.size() > 0:
			##$DebugLabel.text ="herd"
			#var cl = getClosestLife(food_array_temp,1000)
			#if cl !=null:
#
				#if position.distance_to(cl.getCenterPos()) > 32 :
					##getCloser(cl.position)
					#goToMiddle(friend_array_temp)
				#else:
					#AdjustDirection()
			#else:
				#AdjustDirection()
		else:
			AdjustDirection()'		


	
	
func Activate():
	#set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	#Build_Genome()
	show()
	set_collision_layer_value(1,true)
	$Vision.set_collision_mask_value(1,true)
	$Timer.wait_time = lifecycletime / World.speed
	#$Timer.start()
	#$Timer.time_left = randf_range(0,$Timer.wait_time)
	$Timer.start(randf_range(0,$Timer.wait_time))


	$Collision_0.show()
	$Collision_1.hide()
	$Collision_1.disabled = true		
	$Collision_0.disabled = false	
	$Sprite_1.hide()
	$Sprite_2.hide()
	$Dead_Sprite_0.hide()	
	$Dead_Sprite_1.hide()
	$Dead_Sprite_2.hide()
	$Sprite_0.show()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	Decomposition(1)
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	$Brainy.Desactivate()
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	#prepare for new instance

	#Build_Stat()	
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	

	hide()

func Eat(life):
	#print("Eaten")
	self.energy += life.energy
	life.energy= 0
	life.Die()
	$DebugLabel.text = str(age) + " " + str(energy)

func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		pass

func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		pass
		#print(area.position) # Replace with function body.


func _on_vision_body_entered(body):
		if body.species== "grass":
			#print(position.distance_to(body.position))
			vision_array["food"].append(body)
			#Eat(body)
			#getCloser(body.position)
		if body.species== "sheep" and body!= self:
			if item_array.size() > 0 :
				if item_array[0].species == "berry" :
					vision_array["danger"].append(body)
			elif body.item_array.size() > 0 :
				if body.item_array[0].species == "berry" :
					vision_array["danger"].append(body)
			else :
			#getAway(body.position)
				vision_array["friend"].append(body)
		if body.species == "catronaute" or body.species == "spidercrab" :
			vision_array["danger"].append(body)



func _on_vision_body_exited(body):
	for n in vision_array:
		if vision_array[n].has(body):
			vision_array[n].erase(body)

func _on_action_timer_timeout():
	action_finished = true



func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self



func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null
