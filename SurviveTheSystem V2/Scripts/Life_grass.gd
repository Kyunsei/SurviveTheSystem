extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "grass"

func Build_Genome():
	Genome["maxPV"]=[10,10,10]
	Genome["soil_absorption"] = [2,2,2]
	Genome["lifespan"]=[20,20,20]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]
	Genome["dead_sprite"] = [preload("res://Art/grass_dead.png")]

func Build_Phenotype(): #go to main
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
	$Collision_1.disabled = true		
	
func Build_Stat():
	self.PV = 10
	self.current_life_cycle = 0
	self.PV = 10
	self.energy = 2.
	self.lifespan = 1*(90/5)
	self.age = 0
	self.maxEnergy = 5.
	
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			
			Absorb_soil_energy(2,0)
			LifeDuplicate()
			Ageing()
			Growth()
			Metabo_cost()	

			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:
				Die()
			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug partw
		#$DebugLabel.text =  "%.2f" % energy




#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	$Dead_Sprite_0.show()
	$Collision_1.disabled = true		
	$Collision_0.disabled = false		
	$Collision_0.show()
	$Collision_1.hide()
	$Sprite_1.hide()
	$Sprite_0.hide()
	

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




#Duplication
func LifeDuplicate():
	if current_life_cycle == 1  :
		if self.energy > 3:	
			var life: LifeEntity = Life.build_life(species)
			#$DebugLabel.text = "duplicate"
			if life != null:
				self.energy -= 2
				life.energy = 2
				life.global_position = PickRandomPlaceWithRange(position,4 * World.tile_size)
			else:
				#$DebugLabel.text = "full"
				pass
				#print("pool empty")


			




		





func Activate():
	#set_physics_process(false)
	self.isActive = true
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	self.size = get_node("Collision_0").shape.size

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	Decomposition()
	$Timer.stop()
	set_collision_layer_value(1,0)
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1




	#prepare for new instance
	self.isDead = false
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	
	$Sprite_1.hide()
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




