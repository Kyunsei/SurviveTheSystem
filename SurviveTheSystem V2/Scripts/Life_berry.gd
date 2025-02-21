extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "berry"

var counter = 0

var signalconnected = false

var sunoccupationisSet = false

var jelly_bee_array = []

		
signal light_on
signal light_out

func Build_Genome():
	Genome["maxPV"]=[10,10,15,20]
	Genome["soil_absorption"] = [0,2,4,6]
	Genome["lifespan"]=[300,300,300,300]#randi_range(15,20)]
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
	self.energy = 10
	self.maxEnergy = 15
	self.age= 0
	self.lifecycletime = 10.
	self.lifespan= 5 * (World.one_day_length/lifecycletime)
	self.isPickable = true
	metabolic_cost = 1.
	photosynthesis_level = 2
	
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			if carried_by == null :
				if current_life_cycle !=0:
					Metabo_cost(10)	
					Absorb_sun_energy(1,4)
				
					'if self.energy < self.maxEnergy:
						Absorb_soil_energy(2,3)'
				
				Growth()
				Ageing()
			#elif carried_by.species == "spidercrab": 
			else :
				if carried_by.species == "spidercrab":
					if current_life_cycle !=0:
						#Metabo_cost()	
						if self.energy < self.maxEnergy:
							Absorb_life_energy(carried_by,5)
					Growth()
					Ageing()
			if self.energy <= 0 or self.PV <=0:
					Die()
					
			'if self.age >= self.lifespan:
				Revert()'
			energy = clamp(energy, 0, maxEnergy)
			
			if current_time_speed != World.speed:
					adapt_time_to_worldspeed()
		else:
			if energy <= 0:
				Deactivate()
			else:
				energy -= 5

		#Debug part
		$DebugLabel.text = str(self.energy)


func Revert():
	self.current_life_cycle = 0
	Update_sprite($Sprite_0, $Collision_0)	
	self.maxPV = Genome["maxPV"][self.current_life_cycle]
	self.PV = self.maxPV
	self.isPickable = true
	self.age = 0
	if World.isNight == true:
			$PointLight2D.show()

#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	
	Update_sprite($Dead_Sprite_0, $Collision_0)
	if current_life_cycle > 0:
		set_sun_occupation(-1,4)
		sunoccupationisSet = false
	#print(getSunOccupation(1,4,1))
	$PointLight2D.hide()
	for b in jelly_bee_array:
		b.berry_nest = null
	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if World.isNight == true:
			$PointLight2D.show()
		if self.age > 1*(World.one_day_length/lifecycletime) and self.energy > 2:

			self.current_life_cycle += 1
			Update_sprite($Sprite_1, $Collision_1)	
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV
			self.isPickable = false
	elif current_life_cycle == 1:
		$PointLight2D.hide()
		if self.age > 2*(World.one_day_length/lifecycletime) and self.energy > 5:
			#set_sun_occupation(1,4) 
			self.current_life_cycle += 1
			Update_sprite($Sprite_2, $Collision_2)	
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV
	elif current_life_cycle == 2:
		$PointLight2D.hide()
		if self.age > 3*(World.one_day_length/lifecycletime) and self.energy > 10 and self.counter == 0:
			#set_sun_occupation(1,4) 
			self.current_life_cycle += 1
			Update_sprite($Sprite_3, $Collision_3)	
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV
			self.isPickable = true
				
		self.counter +=1
		if self.counter >= 0.5*(World.one_day_length/lifecycletime):
			self.counter = 0
			
	elif current_life_cycle == 3:
		#set_sun_occupation(1,4) 
		if World.isNight == true:
			$PointLight2D.show()
	
	if current_life_cycle >0 and sunoccupationisSet == false:
		set_sun_occupation(1,4) 
		sunoccupationisSet = true


#Duplication
func LifeDuplicate2(transporter):
		
		#print("duplicate")
		#if self.energy >= 15 :
			var life = Life.build_life(species)
			if life != null:
				self.energy -= 10
				life.energy = 10
				#life.global_position = PickRandomPlaceWithRange(position,2 * World.tile_size)
				
				if transporter:		
					getTransported(life,transporter)
				else:
					life.position = PickRandomPlaceWithRange(position,3 * World.tile_size)
							
				self.current_life_cycle = 2
				self.isPickable = false
				$PointLight2D.hide()
				Update_sprite($Sprite_2, $Collision_2)
				for b in jelly_bee_array:
					b.berry_nest = null
				
				

			else:
				print("berry_pool empty")


			


func getTransported(seed,transporter):
	seed.carried_by = transporter
	seed.z_index = 1
	transporter.item_array.append(seed)
	if transporter.isPlayer == false and transporter.species != "spidercrab" :
		seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)




func Activate():

	if not signalconnected:
		get_parent().get_parent().light_out.connect( _on_light_out)
		get_parent().get_parent().light_on.connect( _on_light_on)
		signalconnected = true
	self.isActive = true
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	set_collision_layer_value(1,1)
	$Vision.set_collision_mask_value(1,true)
	#Build_Genome()
	Update_sprite($Sprite_0, $Collision_0)
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	self.size = get_node("Collision_0").shape.size
	
	if self.current_life_cycle == 0 or self.current_life_cycle == 3 :
		if World.isNight == true:
			$PointLight2D.show()
	if self.current_life_cycle == 1 or self.current_life_cycle == 2 :
		if World.isNight == false:
			$PointLight2D.hide()


func getPickUP(transporter):
	if current_life_cycle == 0:
		if self.carried_by != null:
			carried_by.item_array.erase(self)
		self.carried_by = transporter
		transporter.item_array.append(self)
		#seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)
	elif current_life_cycle == 3 and isDead==false:
		#print("here")
		LifeDuplicate2(transporter)
 


func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	#Decomposition(1)
	$Timer.stop()
	set_collision_layer_value(1,0)
	$Vision.set_collision_mask_value(1,false)
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
	
	#$Sprite_1.hide()
	Update_sprite($Sprite_0, $Collision_0)
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
			if body.species== "spidercrab" and body.item_array.size() == 0  and body.current_life_cycle == 1:
				LifeDuplicate2(body)	
		else:
			pass
			#LifeDuplicate2(body.get_parent())




func _on_hitch_hike_timer_timeout():
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		self.z_index = 0
		Update_sprite($Sprite_0, $Collision_0)

func _on_light_on() :
	if self.current_life_cycle == 0 or self.current_life_cycle == 3 :
		$PointLight2D.show()
	
	
func _on_light_out() :
	$PointLight2D.hide()

func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self

func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null
