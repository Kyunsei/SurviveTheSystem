extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "bigtree"

var counter = 0






func Build_Genome():
	pass

func Build_Phenotype():
	#This function should be call when building the pool.
	pass
	
func Build_Stat():
	self.PV = 20
	self.current_life_cycle = 0
	self.maxPV = 20
	self.energy = 10
	self.maxEnergy = 15
	self.age= 0
	self.lifecycletime = 10.
	self.lifespan= 30 * (World.one_day_length/lifecycletime)
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
					Absorb_sun_energy(1,5*current_life_cycle)
					LifeDuplicate()
					'if self.energy < self.maxEnergy:
						Absorb_soil_energy(2,3)'
				
				Growth()
				Ageing()

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



#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	
	Update_sprite($Dead_Sprite_0, $Collision_0)
	set_sun_occupation(0,3*current_life_cycle)

	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 1*(World.one_day_length/lifecycletime) and self.energy > 2:

			self.current_life_cycle += 1
			Update_sprite($Sprite_1, $Collision_1)	
			self.maxPV = 30
			self.PV = self.maxPV
			self.isPickable = false
	elif current_life_cycle == 1:
		if self.age > 2*(World.one_day_length/lifecycletime) and self.energy > 5:
			self.current_life_cycle += 1
			Update_sprite($Sprite_2, $Collision_2)	
			self.maxPV =60
			self.PV = self.maxPV
	


#Duplication
func LifeDuplicate():
	if current_life_cycle == 2:
		#print("duplicate")
		#if self.energy >= 15 :
			var life = Life.build_life(species)
			if life != null:
				self.energy -= 10
				life.energy = 10
				life.position = PickRandomPlaceWithRange(position,20 * World.tile_size)
										

			else:
				print("bigtree_pool empty")


			





func Activate():

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
	


func getPickUP(transporter):
	if current_life_cycle == 0:
		if self.carried_by != null:
			carried_by.item_array.erase(self)
		self.carried_by = transporter
		transporter.item_array.append(self)
		#seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)

 


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
	pass
			#LifeDuplicate2(body.get_parent())




func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self

func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null
