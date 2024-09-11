extends LifeEntity


# sheep script
var species = "sheep"

var direction = Vector2(0,0)

var food_array = []
var danger_array = []
var friend_array = []




var action_finished = true



func Build_Genome():
	Genome["maxPV"]=[15,10,20]
	Genome["speed"] =[0,200,100]
	Genome["lifespan"]=[100,100,100]
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
	$Vision/Collision.shape.radius = 200
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_2.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	$Collision_1.hide()
	$Collision_1.disabled = true		

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 10

func _physics_process(delta):
	if isPlayer:
		Player_Control_movement()	
	if isDead == false:
		Brainy()
	else:
		velocity = Vector2(0,0)
		
	var collision = move_and_collide(velocity *delta)	
	global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	if item_array.size() > 0:
		for i in item_array:
			i.position = position	
		
func _on_timer_timeout():
	
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
			if self.current_life_cycle !=0:
				pass
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
		#$DebugLabel.text = str(age) + " " + str(energy)




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
		if self.age > 4 and self.energy > 8:
			self.current_life_cycle += 1
			$Sprite_1.show()
			$Sprite_0.hide()
			set_physics_process(true)
	if current_life_cycle == 1:
		if self.age > 8 and self.energy > 10:
			self.current_life_cycle += 1
			$Sprite_2.show()
			$Sprite_1.hide()
			$Collision_0.hide()
			$Collision_1.show()
			$Collision_1.disabled = false		
			$Collision_0.disabled = true	

			


#Duplication
func LifeDuplicate():
	if current_life_cycle == 2 :
		if self.age % 10 == 0 and self.energy > 20:
			var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
			for i in range(0,int(self.energy-10)/10):
			#Lpool Technique
				var li = Life.sheep_pool_state.find(0)	
				#+ Life.grass_pool_state.size()*0.05
				if li > -1 and Life.sheep_number  < Life.sheep_pool_scene.size():
					self.energy -= 10
					Life.sheep_pool_scene[li].Activate()
					Life.sheep_pool_scene[li].energy = 10
					Life.sheep_pool_scene[li].age = 0
					Life.sheep_pool_scene[li].current_life_cycle = 0
					Life.sheep_pool_scene[li].PV = Genome["maxPV"][0]
					Life.sheep_number += 1
					Life.sheep_pool_scene[li].global_position = newpos + Vector2(randf_range(0,32),randf_range(0,32))
				else:
					print("sheep_pool empty")


func AdjustDirection():
	if action_finished == true:
		direction.x = randi_range(-1,1)
		direction.y = randi_range(-1,1)
		velocity = direction * Genome["speed"][self.current_life_cycle]*0.5
		action_finished = false
		$ActionTimer.start(0.5)
		$DebugLabel.text = "Idle"

func getCloser(target):
	direction = -(position - target).normalized()
	velocity = direction * Genome["speed"][self.current_life_cycle]
	#$DebugLabel.text = "feeding"
	

func goToMiddle(life_array):
	if action_finished == true:
		var sum = Vector2(0,0)
		for l in life_array:
			sum += l.position
		var middle_pos = sum/life_array.size()
		getCloser(middle_pos + Vector2(randf_range(-16,16),randf_range(-16,16)))
		action_finished = false
		$ActionTimer.start(0.5)
####################







	
	
	
###############3	 
func getAway(target):
	if action_finished == true:
		direction = (position - target).normalized()
		velocity = direction * 400  # Genome["speed"][self.current_life_cycle] *2
		action_finished = false
		$DebugLabel.text = "avoid"
		$ActionTimer.start(0.5)

func Brainy():
	var danger_array_temp = danger_array.duplicate()
	var food_array_temp = food_array.duplicate()
	var friend_array_temp = friend_array.duplicate()
	

	if danger_array_temp.size() > 0 :
		var cl = getClosestLife(danger_array_temp,1000)
		var random = randi_range(0,100)
		var probability = clamp(1.0 - (position.distance_to(cl.position) / 300), 0.0, 1.0) * 100
		if random <= probability:
			getAway(cl.position)


	if action_finished == true:
		if self.energy < 50 and food_array_temp.size()>0:
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:
				$DebugLabel.text ="feeding"
				if position.distance_to(cl.position) < 32 and cl.isDead == false:
						Eat(cl)
				if cl.isDead == false:
						getCloser(cl.position)
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		elif friend_array_temp.size() > 0:
			$DebugLabel.text ="herd"
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:

				if position.distance_to(cl.position) > 32 :
					#getCloser(cl.position)
					goToMiddle(friend_array_temp)
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		else:
			AdjustDirection()
		'elif friend_array_temp.size() > 0:
		var cl = getClosestLife(friend_array_temp,1000)
		if position.distance_to(cl.position) > 96 :
			getCloser(cl.position)'		


'func getClosestLife(array, 1000):
	var closest_entity = array[0]
	var min_distance = 1000
	var calc_distance = 500
	for p in array:
		calc_distance = position.distance_to(p.position)
		if calc_distance <= min_distance:
			min_distance = calc_distance
			closest_entity = p
	return closest_entity'
	
	
func Activate():
	#set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.sheep_pool_state[self.pool_index] = 1
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
	Decomposition()
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.sheep_pool_state[self.pool_index] = 0
	Life.sheep_number -= 1
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

func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		pass

func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		pass
		#print(area.position) # Replace with function body.


func _on_vision_body_entered(body):
	if body.name != "PlayerBody":
		if body.species== "grass":
			#print(position.distance_to(body.position))
			food_array.append(body)
			#Eat(body)
			#getCloser(body.position)
		if body.species== "sheep" and body!= self:
			#getAway(body.position)
			friend_array.append(body)
		if body.species == "catronaute":
			danger_array.append(body)
	else:
		danger_array.append(body.get_parent())

		#getAway(body.position)





func _on_vision_body_exited(body):
	if body.name != "PlayerBody":
		if body.species== "grass":
			#print(position.distance_to(body.position))
			food_array.erase(body)
			#Eat(body)
			#getCloser(body.position)
		if body.species== "sheep" and body!= self:
			#getAway(body.position)
			friend_array.erase(body)
		if body.species == "catronaute":
			danger_array.erase(body)
	else:
		danger_array.erase(body.get_parent())
		#getAway(body.position)


func _on_action_timer_timeout():
	action_finished = true

