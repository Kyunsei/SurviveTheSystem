extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "grass"
var sub_species: int = 0

var test_col = Color(1,1,1)
var timer_count : int = 0

func Build_Genome():
	Genome["maxPV"]=[10,10,10]
	Genome["soil_absorption"] = [2,2,2]
	Genome["lifespan"]=[20,20,20]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]
	Genome["dead_sprite"] = [preload("res://Art/grass_dead.png")]

'func Build_Phenotype(): #go to main
	#This function should be call when building the pool.	
	# SPRITE
	$Sprite_1.hide()
	$Dead_Sprite_0.hide()		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 150
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_1.texture.get_height()/2) #Vector2(width/2,-height/2)	
	$Collision_1.hide()
	$Collision_1.disabled = true'	



	

func Build_Stat():
	#self.sub_species = randi_range(0,1)
	#test_col =  Color(randi_range(0,1),randi_range(0,1),randi_range(0,1))
	#modulate = test_col
	self.PV = 10
	self.current_life_cycle = 0
	self.PV = 10
	self.energy = 0.
	self.lifecycletime = 10. #30. #in second
	self.lifespan = 3*(World.one_day_length/lifecycletime)
	self.age = 0
	self.maxEnergy = 10.
	self.isPickable = false
	metabolic_cost = 1.
	photosynthesis_level = 1.
	

	
	if self.sub_species == 1:
		test_col = Color(0,0,1)
		modulate = test_col

	elif self.sub_species == 2:
		test_col = Color(0,1,0)
		modulate = test_col

	else:
		test_col = Color(1,1,1)
		modulate = test_col

		
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:

			'if self.energy < self.maxEnergy:
				Absorb_soil_energy(1,1)'


			
			if self.sub_species == 0:
				Metabo_cost(7)
				Absorb_sun_energy(2,1)
				#modulate =  Color(1,1,1)
				
			elif self.sub_species == 2:
				Absorb_sun_energy(2,0)
				Metabo_cost(1)


				#modulate =  Color(1,1,1)
			elif self.sub_species == 1:
				var energybefore = energy
				Metabo_cost(3)
				Absorb_sun_energy(2,1)
				if energy - energybefore > 4:
					Die()
					#enrgy = 0
			

				
			energy = clamp(energy, 0, maxEnergy)

			
			Growth()
			LifeDuplicate()
			Ageing()
			
			'if self.sub_species == 1:
				if self.energy > 6:
					self.energy = 0
					Die()
'
			
			
			

			if self.energy <= 0 or self.PV <=0: # or or self.PV <=0:
				Die()
				
			if  self.age >= lifespan:
				pass
				#Die()
			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			if energy <= 0:
				Deactivate()
			else:
				energy -= 5

		#Debug partw
		$DebugLabel.text =  "%.4f" % energy + " sub: " + str(self.sub_species)




#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	set_sun_occupation(-2,1)
	Update_sprite($Dead_Sprite_0, $Collision_0)
	'$Dead_Sprite_0.show()
	$Collision_1.disabled = true		
	$Collision_0.disabled = false		
	$Collision_0.show()
	$Collision_1.hide()
	$Sprite_1.hide()
	$Sprite_0.hide()'
	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age >= 2 and self.energy > 2: #5
			self.current_life_cycle += 1
			Update_sprite($Sprite_1, $Collision_1)
			'$Collision_0.hide()
			$Collision_1.show()
			$Collision_1.disabled = false		
			$Collision_0.disabled = true	
			$Sprite_1.show()
			$Sprite_0.hide()'




#Duplication
func LifeDuplicate():
	var energy_required = 10
	var occupation_required = 0.0
	if sub_species == 1:
		energy_required = 3
		occupation_required = 0.4
	if current_life_cycle == 1  :
		if timer_count <= 0:
			if self.energy > 4:	
				for i in range (3 + sub_species*2):
					var newpos = PickRandomPlaceWithRange(position, 3 * World.tile_size)
					var posindex = int(newpos.y/World.tile_size)*World.world_size + int(newpos.x/World.tile_size)		
					#if World.block_element_array[posindex]>= 0:
					if World.block_element_state[posindex]>= 1:
						'if sub_species==1:
							print(getSunEnergy(1,1,2, newpos))
							print(getSunOccupation(1,1,2, newpos))
							print("..........")'
						if getSunEnergy(1,1,2, newpos) >= energy_required and getSunOccupation(1,1,2, newpos) <= occupation_required:
						#if getSunOccupation(1,1,2, newpos) == 0.0 and getSunOccupation(2,1,2, newpos) == 0.0 and getSunOccupation(3,1,2, newpos) == 0.0:
							#if World.sun_energy_occupation_array[posindex]==0:
								timer_count = 1
								var life: LifeEntity = Life.build_life(species)
								if life != null:
									self.energy -= 0#20
									life.energy = 5#20
									life.global_position = newpos #PickRandomPlaceWithRange(position,4 * World.tile_size)
									life.test_col = test_col
									life.modulate = test_col
									life.sub_species = self.sub_species
									life.set_sun_occupation(2,1) 
									#life.maxEnergy = maxEnergy
									if sub_species == 0:
										pass
									else:	
										Life.red -= 1
										Life.blue += 1
								else:
									pass
		else:
				timer_count -= 1		#$DebugLabel.text = "full"
				pass
						#print("pool empty")


			




		





func Activate():
	
	self.isActive = true
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	Update_sprite($Sprite_0,$Collision_0)
	self.size = get_node("Collision_0").shape.size

	Life.red += 1

func Deactivate():	
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	#Decomposition(0)
	$Timer.stop()
	set_collision_layer_value(1,0)
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	
	if sub_species == 0:
		Life.red -= 1
	else:
		Life.blue -= 1




	#prepare for new instance
	self.isDead = false
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	Update_sprite($Sprite_0)
	'$Sprite_1.hide()
	$Dead_Sprite_0.hide()
	$Sprite_0.show()'
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






func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self



func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null
