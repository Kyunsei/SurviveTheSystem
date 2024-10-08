extends LifeEntity


# sheep script
var species = "jellybee"



var food_array = []
var danger_array = []
var friend_array = []

var jelly_color = Color(randf_range(0,1),randf_range(0,1),randf_range(0,1),1) 



var input_dir = Vector2(0,0)


func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	$Dead_Sprite_0.hide()		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 2000
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
		

func Build_Stat():
	self.current_life_cycle = 0
	self.maxPV = 10
	self.PV = 10
	self.energy = 10
	self.maxSpeed = 50
	self.lifespan = 2*(90/5)
	$Sprite_0.modulate = jelly_color


func _physics_process(delta):
	if isPlayer:
		input_dir = Player_Control_movement()	
	if isDead == false:
		Brainy()
	else:
		velocity = Vector2(0,0)
		
	var collision = move_and_collide(velocity *delta)	
	
	if item_array.size() > 0:
		for i in item_array:
			i.position = position+Vector2(0,-32)	
		
func _on_timer_timeout():
	
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
			
			Metabo_cost()
			LifeDuplicate()
			Ageing()
			#Growth()
			#AdjustDirection()
			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:

				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		$DebugLabel.text = str(age) + " " + str(energy)




#diying
func Die():
	for i in item_array:
		i.carried_by = null
		i.z_index = 0
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	item_array = []

	
	
	self.isDead = true

	$Dead_Sprite_0.show()
	$Sprite_0.hide()
	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		pass
			


#Duplication
func LifeDuplicate():

	if self.age > 5 and self.energy > 15:
			var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)

		#Lpool Technique
			var li = Life.jellybee_pool_state.find(0)	
			#+ Life.grass_pool_state.size()*0.05
			if li > -1: # and Life.sheep_number  < Life.sheep_pool_scene.size():
				self.energy -= 10
				Life.jellybee_pool_scene[li].jelly_color = jelly_color
				Life.jellybee_pool_scene[li].Activate()
				Life.jellybee_pool_scene[li].energy = 10
				Life.jellybee_pool_scene[li].age = 0
				Life.jellybee_pool_scene[li].current_life_cycle = 0
				Life.jellybee_pool_scene[li].PV = 10
				Life.jellybee_pool_scene[li].global_position = newpos 
			else:
				pass
				print("jellybee_pool empty")



func Brainy():
	var center = position + Vector2(32,-32) #temporaire
	var danger_array_temp = danger_array.duplicate()
	var food_array_temp = food_array.duplicate()
	var friend_array_temp = friend_array.duplicate()


	if action_finished == true:
		if self.energy < 10 and food_array_temp.size()>0:
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:
				#$DebugLabel.text ="feeding"
				if center.distance_to(cl.getCenterPos()) < 32 and cl.isDead == false:
						Absorb_life_energy(cl,10)
				if cl.isDead == false:
						getCloser(cl.getCenterPos())
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		elif friend_array_temp.size() > 0:
			#$DebugLabel.text ="herd"
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:

				if position.distance_to(cl.getCenterPos()) > 32 :
					#getCloser(cl.position)
					goToMiddle(friend_array_temp)
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		else:
			AdjustDirection()
		
	
	
func Activate():
	#set_physics_process(true)
	self.isActive = true
	self.isDead = false
	set_physics_process(true)
	Life.jellybee_pool_state[self.pool_index] = 1
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
	$Collision_0.disabled = false
	$Vision/Collision.disabled = false
	$Dead_Sprite_0.hide()	
	$Sprite_0.show()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	Decomposition()
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.jellybee_pool_state[self.pool_index] = 0
	$Vision/Collision.disabled = true
	$Collision_0.disabled = true
	#Life.sheep_number -= 1
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
	#$DebugLabel.text = str(age) + " " + str(energy)



func _on_vision_body_entered(body):

		if body.species== "spiky_grass" and body.current_life_cycle == 2:
			#print(position.distance_to(body.position))
			food_array.append(body)
			#Eat(body)
			#getCloser(body.position)
		if body.species== "jellybee" and body!= self:
				friend_array.append(body)
	
		#getAway(body.position)





func _on_vision_body_exited(body):
		if body.species== "spiky_grass" and body.current_life_cycle == 2:
			#print(position.distance_to(body.position))
			food_array.erase(body)
			#Eat(body)
			#getCloser(body.position)
		if body.species== "jellybee" and body!= self:
				friend_array.erase(body)
	


func _on_action_timer_timeout():
	action_finished = true

