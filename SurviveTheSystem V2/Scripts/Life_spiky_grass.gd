extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "spiky_grass"

func Build_Genome():
	Genome["maxPV"]=[10,10]
	Genome["soil_absorption"] = [2,2]
	Genome["lifespan"]=[20,20]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]
	Genome["dead_sprite"] = [preload("res://Art/grass_dead.png")]

func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	

	$Sprite_1.hide()
	$Sprite_flower.hide()
	$Sprite_2.hide()
	$Dead_Sprite_0.hide()
	
		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 16
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_1.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	$Collision_1.hide()
	$Collision_1.disabled = true		
	
func Build_Stat():

	self.current_life_cycle = 0
	self.PV = 10
	self.energy = 0
	self.lifespan = 3*(World.one_day_length/lifecycletime)
	self.age= 0
	self.maxEnergy = 15.
	metabolic_cost = 1.0

	
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			'if self.energy < self.maxEnergy:
				Absorb_soil_energy(1,1)'
			
			Metabo_cost(3)	
			Absorb_sun_energy(2,1)

			#LifeDuplicate()
			Ageing()
			Growth()

			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:
				Die()
			energy = clamp(energy, 0, maxEnergy)
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		$DebugLabel.text = str(energy)




#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	Update_sprite($Dead_Sprite_0,$Collision_0 )
	$Sprite_flower.hide()
	'var petal = Life.petal_scene.instantiate()
	get_parent().add_child(petal) 
	petal.position = self.position - Vector2(32,32)'

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 3 and self.energy > 2:
			self.current_life_cycle += 1
			
			Update_sprite($Sprite_1,$Collision_1 )

	if current_life_cycle == 1:
		if self.energy >= 15:
			self.current_life_cycle += 1
			Update_sprite($Sprite_2,$Collision_1 )
			#$Body/Collision_0.set_deferred("disabled", true)
			#$Body/Collision_1.set_deferred("disabled", false)
			


#Duplication
func LifeDuplicate():
	if current_life_cycle >= 1 :
		if self.energy < 5:
			
			
			'var genome_ID = 0
			Life.new_lifes.append(genome_ID)
			var newpos = PickRandomPlaceWithRange(position,5 * World.tile_size) 
			Life.new_lifes_position.append(newpos)'

			'var newlife = life_scene.instantiate()
			newlife.global_position = PickRandomPlaceWithRange(position,5 * World.tile_size) 
			get_parent().add_child(newlife)'
			
			'if Life.inactive_grass.size()>0:
				self.energy -= 2
				Life.inactive_grass[0].Activate()
				Life.inactive_grass[0].energy = 2
				Life.inactive_grass[0].global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
				Life.inactive_grass.remove_at(0)	
				Life.plant_number += 1'
			
			#Life.grass_pool Technique
			
			var li = Life.build_life("spiky_grass")# Life.spiky_grass_pool_state.find(0)	
			#+ Life.grass_pool_state.size()*0.05
			if li: # and Life.plant_number  < Life.grass_pool_state.size():
				self.energy -= 0
				li.energy = 0
				li.age = 0
				li.current_life_cycle = 0
				li.PV = Genome["maxPV"][0]
				li.global_position = PickRandomPlaceWithRange(position,2 * World.tile_size)
			#else:
				#pass
				#print("pool empty")


			




		





func Activate():

	$Vision.monitoring = true
	self.isActive = true
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	Update_sprite($Sprite_0,$Collision_0 )
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	#self.size = get_node("Collision_0").shape.size
	$Vision/Collision.disabled = false

func Deactivate():	
	set_physics_process(false)
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	$Vision.monitoring = false
	#Decomposition(1)
	$Timer.stop()
	set_collision_layer_value(1,0)
	$Collision_0.disabled = true
	$Vision/Collision.disabled = true
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	#Life.inactive_grass.append(self)
	#Life.plant_number -= 1



	#prepare for new instance
	self.isDead = false
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	Update_sprite($Sprite_0)
	hide()





func getDamaged(value,antagonist:LifeEntity=null):
	if InvicibilityTime == 0:
		self.PV -= value
		if self.PV <= 0:
			Die()
		InvicibilityTime = 1 
		modulate = Color(1, 0.2, 0.2)

		if current_life_cycle == 2 :
			current_life_cycle -= 1
			energy -= 10
			Update_sprite($Sprite_1,$Collision_1 )
			var petal = Life.petal_scene.instantiate()
			get_parent().add_child(petal) 
			petal.position = self.position - Vector2(10,10)
		
		await get_tree().create_timer(0.5).timeout
		InvicibilityTime = 0
		modulate = Color(1, 1, 1)
				

		

	

func _on_vision_body_entered(body):
	if body.species == "catronaute" and self.isDead == false and self.current_life_cycle > 0:
		body.getDamaged(5)
	if body.species == "spidercrab_leg":
		var petal = Life.petal_scene.instantiate()
		get_parent().add_child(petal) 
		petal.position = self.position - Vector2(10,10)


func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self



func _on_mouse_exited():
	
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null

