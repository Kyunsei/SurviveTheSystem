extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "berry"


var carried_by = null

func Build_Genome():
	Genome["maxPV"]=[10,10,15,20]
	Genome["soil_absorption"] = [0,2,4,6]
	Genome["lifespan"]=[200,200,200,200]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/berry_1.png"),preload("res://Art/berry_3.png"),preload("res://Art/berry_4.png"),preload("res://Art/berry_5.png")]
	Genome["dead_sprite"] = [preload("res://Art/berry_dead.png")]

func Build_Phenotype():
	#This function should be call when building the pool.
	
	# SPRITE
	$Sprite_0.texture = Genome["sprite"][0]
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()


	$Sprite_1.texture = Genome["sprite"][1]
	$Sprite_1.offset.y = -$Sprite_1.texture.get_height()
	$Sprite_1.offset.x = -$Sprite_1.texture.get_width()/4
	$Sprite_1.hide()
	
	$Sprite_2.texture = Genome["sprite"][2]
	$Sprite_2.offset.y = -$Sprite_2.texture.get_height()
	$Sprite_2.offset.x = -$Sprite_2.texture.get_width()/($Sprite_2.texture.get_width()/Life.life_size_unit)
	$Sprite_2.hide()
	
	$Sprite_3.texture = Genome["sprite"][3]
	$Sprite_3.offset.y = -$Sprite_3.texture.get_height()
	$Sprite_3.offset.x = -$Sprite_3.texture.get_width()/($Sprite_3.texture.get_width()/Life.life_size_unit)
	$Sprite_3.hide()
	
	$Dead_Sprite_0.texture = Genome["dead_sprite"][0]
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	$Dead_Sprite_0.hide()
	
		
	#ADD vision
	$Vision/Collision.shape.radius = 32
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_1.texture.get_height()/2) #Vector2(width/2,-height/2)
	$Collision_2.position = Vector2(Life.life_size_unit/2,-$Sprite_2.texture.get_height()/2) #Vector2(width/2,-height/2)
	$Collision_3.position = Vector2(Life.life_size_unit/2,-$Sprite_3.texture.get_height()/2) #Vector2(width/2,-height/2)

	
	$Collision_1.hide()
	$Collision_1.disabled = true	
	$Collision_2.hide()
	$Collision_2.disabled = true
	$Collision_3.hide()
	$Collision_3.disabled = true	
	
func Build_Stat():
	self.PV = Genome["maxPV"][0]
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 5
	
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			if carried_by == null:
				if current_life_cycle !=0:
					Metabo_cost()	
					Absorb_soil_energy()
			
				#LifeDuplicate()r
				Ageing()
				Growth()

				if self.energy <= 0 or self.age >= Genome["lifespan"][current_life_cycle] or self.PV <=0:
					Die()
				
				if current_time_speed != World.speed:
					adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		$DebugLabel.text = str(self.energy)


#EAT soil
func Absorb_soil_energy():
	var x = int(position.x/World.tile_size)
	var	y = int(position.y/World.tile_size)
	var posindex = y*World.world_size + x
	if posindex < World.block_element_array.size():
		var soil_energy = World.block_element_array[posindex]	
		energy += min(Genome["soil_absorption"][current_life_cycle],soil_energy)
		World.block_element_array[posindex]	-= min(Genome["soil_absorption"][current_life_cycle],soil_energy)


			
'	if parameters_array[INDEX*par_number+2] <= Genome[genome_index]["maxenergy"][current_cycle]:'


#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
	
	$Dead_Sprite_0.show()
	$Collision_1.disabled = true	
	$Collision_2.disabled = true		
	$Collision_3.disabled = true		
	$Collision_0.disabled = false		
	$Collision_0.show()
	$Collision_1.hide()
	$Collision_2.hide()
	$Collision_3.hide()
	$Sprite_1.hide()
	$Sprite_0.hide()
	$Sprite_2.hide()
	$Sprite_3.hide()
	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 2 and self.energy > 2:
			self.current_life_cycle += 1	
			$Collision_0.hide()
			$Collision_1.show()
			$Collision_1.disabled = false		
			$Collision_0.disabled = true	
			$Sprite_1.show()
			$Sprite_0.hide()
	if current_life_cycle == 1:
		if self.age > 4 and self.energy > 5:
			self.current_life_cycle += 1	
			$Collision_1.hide()
			$Collision_2.show()
			$Collision_2.disabled = false		
			$Collision_1.disabled = true	
			$Sprite_2.show()
			$Sprite_1.hide()
	if current_life_cycle == 2:
		if self.age > 8 and self.energy > 10:
			self.current_life_cycle += 1	
			$Collision_2.hide()
			$Collision_3.show()
			$Collision_3.disabled = false		
			$Collision_2.disabled = true	
			$Sprite_3.show()
			$Sprite_2.hide()


#Duplication
func LifeDuplicate2(transporter):
		if self.energy > 10:
					
			#Life.grass_pool Technique
			var li = Life.berry_pool_state.find(0)	
			#+ Life.grass_pool_state.size()*0.05
			if li > -1 and Life.berry_number  < Life.berry_pool_state.size():

				Life.berry_pool_scene[li].Activate()
				Life.berry_pool_scene[li].energy = 5
				Life.berry_pool_scene[li].age = 0
				Life.berry_pool_scene[li].current_life_cycle = 0
				Life.berry_pool_scene[li].PV = Genome["maxPV"][0]

				Life.berry_number += 1
				Life.berry_pool_scene[li].global_position = PickRandomPlaceWithRange(position,2 * World.tile_size)
				
				getTransported(Life.berry_pool_scene[li],transporter)
				
				
				self.current_life_cycle = 2
				self.energy -= 5
				$Collision_3.hide()
				$Collision_2.show()
				$Collision_2.disabled = false		
				$Collision_3.disabled = true	
				$Sprite_2.show()
				$Sprite_3.hide()
				

			else:
				print("pool empty")


			


func getTransported(seed,transporter):
	seed.carried_by = transporter
	transporter.item_array.append(seed)
	seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)


		

func Activate():
	self.isActive = true
	Life.berry_pool_state[self.pool_index] = 1
	Build_Stat()
	set_collision_layer_value(1,1)
	$Vision.set_collision_mask_value(1,true)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition()
	$Timer.stop()
	set_collision_layer_value(1,0)
	$Vision.set_collision_mask_value(1,false)
	self.isActive = false
	Life.berry_pool_state[self.pool_index] = 0
	#Life.inactive_grass.append(self)
	Life.berry_number -= 1


	#prepare for new instance
	self.isDead = false
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	
	#$Sprite_1.hide()
	$Dead_Sprite_0.hide()
	$Sprite_0.show()
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






func _on_vision_body_entered(body):
	if current_life_cycle == 3:
		if body.name != "PlayerBody":
			if body.species== "sheep" and body.current_life_cycle == 2:
				LifeDuplicate2(body)	
		else:
			LifeDuplicate2(body.get_parent())




func _on_hitch_hike_timer_timeout():
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null

