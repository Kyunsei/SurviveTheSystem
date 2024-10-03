extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "grass"

var lifespan = 90/5*2

func Build_Genome():
	Genome["maxPV"]=[10,10]
	Genome["soil_absorption"] = [2,2]
	Genome["lifespan"]=[90/5*2,90/5*2]#randi_range(15,20)]


func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	
	# SPRITE
	


	#$Dead_Sprite_0.hide()
		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 150
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprites_manager_0/Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body

	$Collision_0_0.position = Vector2(Life.life_size_unit/2,-$Sprites_manager_0/Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	$Collision_1_0.position = Vector2(Life.life_size_unit/2,-$Sprites_manager_0/Sprite_0.texture.get_height()/2) + Vector2(32,32) #Vector2(width/2,-height/2)

	$Collision_0_1.position = Vector2(Life.life_size_unit/2,-$Sprites_manager_0/Sprite_1.texture.get_height()/2) #Vector2(width/2,-height/2)
	$Collision_1_1.position = Vector2(Life.life_size_unit/2,-$Sprites_manager_0/Sprite_1.texture.get_height()/2) + Vector2(32,32)#Vector2(width/2,-height/2)
	
	$Collision_0_0.show()
	$Collision_0_0.disabled = false
	$Collision_0_1.disabled = true
	for i in range(1,4):
		'for j in range(0,1):
			var boxname = "Collision_" + str(i) + "_" + str(j)
			get_node(boxname).hide()
			get_node(boxname).disabled = true'
		var spritename = "Sprites_manager_" + str(i)
		get_node(spritename).hide()	
		get_node(spritename).position += Vector2(randf_range(-64*2,64*2),randf_range(-64*2,64*2))


			
func Build_Stat():
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.maxPV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 1
	lifespan = 90/5*2
	
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			
			Absorb_soil_energy(2,3)
			Metabo_cost()	
			LifeDuplicate()
			Ageing()
			Growth()

			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:
				#Die()
				pass
			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		#$DebugLabel.text = str(pool_index)




#diying
func Die():
	
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	$Sprites_manager_0/Dead_Sprite_0.show()
	$Collision_0_1.disabled = true		
	$Collision_0_0.disabled = false		
	$Collision_0_0.show()
	$Collision_0_1.hide()
	$Sprites_manager_0/Sprite_1.hide()
	$Sprites_manager_0/Sprite_0.hide()
	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 2 and self.energy > 2:
			self.current_life_cycle += 1		
			$Collision_0_0.hide()
			$Collision_0_1.show()
			$Collision_0_1.disabled = false		
			$Collision_0_0.disabled = true	
			$Sprites_manager_0/Sprite_1.show()
			$Sprites_manager_0/Sprite_0.hide()
			
			
	elif current_life_cycle == 1:		
		if self.age > 4 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_1.show()
			$Sprites_manager_1/Sprite_0.show()
			$Sprites_manager_1/Sprite_1.hide()
			'$Collision_1_0.show()
			$Collision_1_1.hide()
			$Collision_1_1.disabled = true		
			$Collision_1_0.disabled = false	'
	elif current_life_cycle == 2:
		if self.age > 6 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_1/Sprite_0.hide()
			$Sprites_manager_1/Sprite_1.show()
			'$Collision_1_0.hide()
			$Collision_1_1.show()
			$Collision_1_1.disabled = false		
			$Collision_1_0.disabled = true'
			
			
	elif current_life_cycle == 3:		
		if self.age > 8 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_2.show()
	elif current_life_cycle == 4:
		if self.age > 10 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_2/Sprite_0.hide()
			$Sprites_manager_2/Sprite_1.show()



	elif current_life_cycle == 5:
		if self.age > 12 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_3.show()
	elif current_life_cycle == 6:		
		if self.age > 14 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_3/Sprite_0.hide()
			$Sprites_manager_3/Sprite_1.show()

	elif current_life_cycle == 7:
		if self.age > 16 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_4.show()
	elif current_life_cycle == 8:		
		if self.age > 18 and self.energy > 2:		
			self.current_life_cycle += 1
			$Sprites_manager_4/Sprite_0.hide()
			$Sprites_manager_4/Sprite_1.show()

	
#Duplication
func LifeDuplicate():
	if current_life_cycle == 9 :
		if self.energy > 4:
					
			#Life.grass_pool Technique
			var li = Life.grass_pool_state.find(0)	
			#+ Life.grass_pool_state.size()*0.05
			if li > -1 and Life.plant_number  < Life.grass_pool_state.size():
				self.energy -= 1
				Life.grass_pool_scene[li].Activate()
				Life.grass_pool_scene[li].energy = 1
				Life.grass_pool_scene[li].age = 0
				Life.grass_pool_scene[li].current_life_cycle = 0
				Life.grass_pool_scene[li].PV = Genome["maxPV"][0]

				Life.plant_number += 1
				Life.grass_pool_scene[li].global_position = PickRandomPlaceWithRange(position,4 * World.tile_size)
			else:
				pass
				#print("pool empty")


			




func Activate():
	self.isActive = true
	Life.grass_pool_state[self.pool_index] = 1
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	self.size = get_node("Collision_0_0").shape.size

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition()
	$Timer.stop()
	set_collision_layer_value(1,0)
	self.isActive = false
	Life.grass_pool_state[self.pool_index] = 0
	#Life.inactive_grass.append(self)
	Life.plant_number -= 1

	#prepare for new instance
	self.isDead = false

	$Sprites_manager_0/Sprite_1.hide()
	$Sprites_manager_0/Dead_Sprite_0.hide()
	$Sprites_manager_0/Sprite_0.show()
	$Sprites_manager_1/Sprite_1.hide()
	$Sprites_manager_1/Dead_Sprite_0.hide()
	$Sprites_manager_1/Sprite_0.show()
	$Sprites_manager_1.hide()
	hide()



func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		pass
		'$Sprite_0.modulate = Color(0, 0, 1)
		$Sprite_1.modulate = Color(0, 0, 1)'


func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		pass
		'$Sprite_0.modulate = Color(1, 1, 1)
		$Sprite_1.modulate = Color(1, 1, 1)'




