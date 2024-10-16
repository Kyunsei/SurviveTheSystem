extends LifeEntity

var species = "spidercrab"


var barehand_array = []

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var vision_array = {
	"food": [],
	"danger": []
}


var isBurrow = false
#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

func Build_Genome():
	Genome["maxPV"]=[60,60]
	Genome["speed"] =[190,150]
	Genome["lifespan"]=[5000,5000]
	Genome["scale"]=[0.33,1]
	#Genome["sprite"] = [preload("res://Art/player_cat.png")]
	#Genome["dead_sprite"] = [preload("res://Art/poop_star.png")]
	
	#Genome["planty_sprite"] = [preload("res://Art/player_bulbi.png")] #TEMPORAIRE

func init_progressbar():
	$HP_bar.modulate = Color(1, 0, 0)
	$Energy_bar.modulate = Color(0, 1, 0)
	#get("custom_styles/fg").bg_color = Color(1, 0, 0)

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = 60# Genome["maxPV"][self.current_life_cycle]	
	self.energy = 80
	self.maxPV = 60#Genome["maxPV"][self.current_life_cycle]	
	self.maxSpeed = 190
	self.size = $Sprite_0.texture.get_size()*0.33
	self.age= 0

	AdjustBar()
	
func Build_Phenotype(): 
	# SPRITE
	
	$Sprite_0.scale *= Genome["scale"][self.current_life_cycle]
	#$Collision_0.shape.size = size
	$Dead_Sprite_0.scale *= Genome["scale"][self.current_life_cycle]
	
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	#$Sprite_0.offset.x = 0 # -$Sprite_0.texture.get_width()/4
	
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	#$Dead_Sprite_0.offset.x = 0# -$Dead_Sprite_0.texture.get_width()/2
	
	$Dead_Sprite_0.hide()

	#Body
	$Collision_0.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #Vector2(width/2,-height/2)
	$Collision_1.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*1

	#Vision
	$Vision/Collision.shape.radius = 1500
	$Vision/Collision.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #Vector2(width/2,-height/2)


	init_progressbar()
	


func _physics_process(delta):
	if isPlayer and isDead == false:
		input_dir = Player_Control_movement()

	'else:
		if isDead == false :
			Brainy()'

	move_and_collide(velocity *delta)
	#global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	#global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	if item_array.size() > 0:
		var c = 0
		for i in item_array:
				i.position = position + Vector2(48+c*16,-64)
				c += 1
	
	if direction.normalized() != Vector2(0,0):
		last_dir = direction



'func Brainy():
	var center = position + Vector2(size.x/2,-size.y/2)
	var food_array_temp = food_array.duplicate()
	var danger_array_temp = danger_array.duplicate()

	if danger_array_temp.size() > 0:
		var cl = getClosestLife(danger_array_temp,250)
		if cl != null:
			getAway(cl.getCenterPos())

	if item_array.size() > 0:
		if item_array[0].species == "berry" and item_array[0].current_life_cycle == 3 and action_finished: 
			if isBurrow ==false:
				hide_under_soil()
				action_finished = false
				$ActionTimer.start(1.)

			elif isBurrow and action_finished :
				if food_array_temp.size()>0:
					var cl = getClosestLife(food_array_temp,1000)
					if cl !=null:
						$DebugLabel.text ="waiting_Food" 
						if center.distance_to(cl.getCenterPos()) < (128*3) and cl.isDead == false:
							var rdn = randi_range(0,100)
							if rdn < 25:
								attack_from_soil(cl)
								action_finished = false
								$ActionTimer.start(1.)
							else:
								action_finished = false
								$ActionTimer.start(1.)
							
						elif center.distance_to(cl.getCenterPos()) < 64*Genome["scale"][current_life_cycle] and cl.isDead == false:
								if cl.species=="catronaute":					
									cl.getDamaged(10)
								else :
									Eat(cl)
									velocity = Vector2(0,0)'
				

'if action_finished == true and isBurrow == false:
		if self.energy < 90 and food_array_temp.size()>0:
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:
				$DebugLabel.text ="feeding" 
				#NEED TO ADJUST DISTANCE ACCORDING TO CENTER NOT CORNER
				if center.distance_to(cl.getCenterPos()) < (128*3) and cl.isDead == false:
					$DebugLabel.text ="charging"
					var rdn = randi_range(0,100)
					if rdn < 50:
						ChargeToward(cl.getCenterPos())
					else:
						velocity = Vector2(0,0)
						action_finished = false
						$ActionTimer.start(2.)
					
				elif center.distance_to(cl.getCenterPos()) < 64*Genome["scale"][current_life_cycle] and cl.isDead == false:
						if cl.species=="catronaute":
						
							cl.getDamaged(10)
						else :
							Eat(cl)
							velocity = Vector2(0,0)
							$DebugLabel.text ="Eat"
				elif cl.isDead == false and center.distance_to(cl.getCenterPos()) >= 128*3:
						#ChargeToward(cl.position)
						getCloser(cl.position)
						$DebugLabel.text ="getToFood "
				else:
					AdjustDirection()
			else:
				AdjustDirection()
		else:
			AdjustDirection()
	else:
		var cl = getClosestLife(food_array_temp,1000)
		if cl !=null:
			if center.distance_to(cl.getCenterPos()) < 64*Genome["scale"][current_life_cycle] and cl.isDead == false:
				if cl.species=="catronaute":
					cl.getDamaged(10)
				else :
					Eat(cl)
					velocity = Vector2(0,0)
					$DebugLabel.text ="Eat"'
'#AdjustDirection()
		print("here?")
		velocity = Vector2(0,0)'	

func ChargeToward(target):
	var center = getCenterPos()
	if action_finished == true:
		action_finished = false
		$ActionTimer.start(0.5)
		direction = -(center - target).normalized()
		velocity = direction * maxSpeed*4			

func hide_under_soil():
	get_node("Sprite_0").hide()
	self.maxSpeed = 0
	velocity = Vector2(0,0)
	isBurrow = true
	get_node("Collision_"+ str(current_life_cycle)).disabled = true
	$DebugLabel.text = "under_soil"
	if self.current_life_cycle == 0:
		$ActionTimer.start(5.)

func getDamaged(value):
	if InvicibilityTime == 0:
		self.PV -= value
		if self.PV <= 0:
			Die()
		InvicibilityTime = 1 
		modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.1).timeout
		InvicibilityTime = 0
		modulate = Color(1, 1, 1)
		if current_life_cycle == 0:
			hide_under_soil()
		
	if self.has_node("HP_bar"):
		self.AdjustBar()
		self.get_node("HP_bar").show()

func get_out_of_soil():
	get_node("Sprite_0").show()
	get_node("Collision_"+ str(current_life_cycle)).disabled = false
	isBurrow = false
	self.maxSpeed = Genome["speed"][self.current_life_cycle]
	$DebugLabel.text = ""
	
func attack_from_soil(cl):
	get_out_of_soil()
	ChargeToward(cl.getCenterPos())
	$DebugLabel.text = "CHAAAARGE !!!!"
	pass

func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:

			Metabo_cost()
			Ageing()
			AdjustBar()
			LifeDuplicate()
			Growth()



			if self.energy <= 0 or self.age >= Genome["lifespan"][self.current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()


func Growth():
	if current_life_cycle == 0:
		if self.age > 20 and self.energy > 5:
			self.current_life_cycle += 1
			var leg_pos = [self.getCenterPos()-Vector2(48,0), self.getCenterPos()-Vector2(-48,0), self.getCenterPos()-Vector2(48,-32), self.getCenterPos()-Vector2(-48,-32)]
			var leg_rotation = [-1.5707963268,1.5707963268,-1.5707963268,1.5707963268]
			var leg_flip = [1,0,1,0]
			for n in range(4) :
				var crab_leg = Life.spidercrab_leg_scene.instantiate()
				get_parent().add_child(crab_leg) 
				crab_leg.position = leg_pos[n]
				crab_leg.rotation = leg_rotation[n]
				crab_leg.get_node("Sprite_0").flip_h = leg_flip[n]
			var claw_pos = [self.getCenterPos()-Vector2(32,-64), self.getCenterPos()-Vector2(-32,-64)]
			var claw_rotation = [-6.2831853072,0]
			var claw_flip = [0,1]
			for n in range(2) :
				var crab_claw = Life.spidercrab_claw_scene.instantiate()
				get_parent().add_child(crab_claw) 
				crab_claw.position = claw_pos[n]
				crab_claw.rotation = claw_rotation[n]
				crab_claw.get_node("Sprite_0").flip_h = claw_flip[n]
			$Sprite_0.scale = Vector2(1,1)
			$Dead_Sprite_0.scale = Vector2(1,1)
			$Collision_0.disabled = true
			$Collision_1.disabled = false
			$Collision_0.hide()
			$Collision_1.show()
			position.x = position.x - $Sprite_0.texture.get_width()/2  + size.x/2 #*Vector2(1,0)
			position.y = position.y + $Sprite_0.texture.get_height()/2  - size.y/2 #*Vector2(1,0)
			$Collision_0.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #- ($Sprite_0.texture.get_size()/2 + size/2)*Vector2(1,0)
			$Vision/Collision.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #- ($Sprite_0.texture.get_size()/2 + size/2)*Vector2(1,0)
			size = $Sprite_0.texture.get_size()
			vision_array["danger"] = []
			maxSpeed = 190
		
			self.maxSpeed = Genome["speed"][self.current_life_cycle]
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV

func LifeDuplicate():
	if self.age % 70 == 0 and self.energy > 60 and current_life_cycle >= 1:
			var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
			var life = Life.build_life(species)
			if life != null:
				self.energy -= 30			
				life.energy = 30
				life.global_position = newpos 
			else:
				print("spidercrab_pool empty")

func Attack():
	BareHand_attack()

func PickUp():
	$BareHand_attack/sprite2.show()
	$BareHand_attack/ActionTimer.start(0)
	var closestItem = getClosestLife(barehand_array,$Vision/Collision.shape.radius+100)
	if closestItem != null:
		var distancetoclosestItem = position.distance_to(closestItem.position)
		if  distancetoclosestItem < 64 :

			if closestItem.species == "berry":
				if closestItem.current_life_cycle == 0:
					closestItem.getPickUP(self)
					closestItem.z_index = 1
				if closestItem.current_life_cycle == 3:
					closestItem.LifeDuplicate2(self)

			if closestItem.species == "sheep" and closestItem.current_life_cycle < 2:
				closestItem.getPickUP(self)
				closestItem.z_index = 1
			if closestItem.species == "grass" :
				closestItem.getPickUP(self)
				closestItem.z_index = 1
			if closestItem.species == "stingtree" and  closestItem.current_life_cycle == 0:
				if closestItem.mother_tree == null:
					closestItem.getPickUP(self)
					closestItem.z_index = 1

	
func Drop():
	if item_array.size() >0:
		item_array[0].carried_by = null
		item_array[0].z_index = 0
		item_array.remove_at(0)


func Throw():
	pass

func Eat_Action():
	if item_array.size() >0:	
		Eat(item_array[0])
		AdjustBar()



func BareHand_attack():
	$BareHand_attack/sprite.show()
	$BareHand_attack/ActionTimer.start(0)
	for i in barehand_array:
		if i != null:
			i.getDamaged(10)

			

func Die():
	self.isDead = true
	velocity = Vector2(0,0)
	Drop()
	$Dead_Sprite_0.show()
	$Sprite_0.hide()

	
	
func Activate():

	set_physics_process(true)
	self.isActive = true
	self.isDead = false
	$Brainy.Activate()
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	$Collision_1.disabled = true
	$Collision_1.hide()
	Build_Stat()
	show()
	
	set_collision_layer_value(1,true)
	$Vision.set_collision_mask_value(1,true)

	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))


	$Collision_0.show()
	$Collision_0.disabled = false	
	$Dead_Sprite_0.hide()	
	$Sprite_0.show()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	$Brainy.Desactivate()
	Decomposition()
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	hide()

func Eat(life):
	self.energy += life.energy
	life.energy= 0
	life.Die()


func _on_bare_hand_attack_body_entered(body):
	if body != self:
		if body.z_index == 0:
			barehand_array.append(body)	


func _on_bare_hand_attack_body_exited(body):
	if body != self:
		if barehand_array.has(body):
			barehand_array.erase(body)


func _on_action_timer_timeout():
	action_finished = true
	if isBurrow == true and current_life_cycle == 0:
		get_out_of_soil()


func _on_mouse_entered():
	AdjustBar()
	$HP_bar.show()
	$Energy_bar.show()


func _on_mouse_exited():
	$HP_bar.hide()
	$Energy_bar.hide()
	

func _on_vision_body_entered(body):
	if body.species== "sheep":
		if body.current_life_cycle > 0 and self.current_life_cycle == 1:
			vision_array["food"].append(body)
		elif body.current_life_cycle == 0 and self.current_life_cycle == 0:
			vision_array["food"].append(body)
	if body.species== "jellybee":
		if self.current_life_cycle == 0:
			vision_array["food"].append(body)
	if body.species == "catronaute":
		if self.current_life_cycle == 1:
			vision_array["food"].append(body)
		else:
			vision_array["danger"].append(body)

		#getAway(body.position)


func _on_vision_body_exited(body):
	for n in vision_array:
		if vision_array[n].has(body):
			vision_array[n].erase(body)

