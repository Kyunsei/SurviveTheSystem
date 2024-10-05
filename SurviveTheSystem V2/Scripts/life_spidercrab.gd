extends LifeEntity

var species = "spidercrab"


var barehand_array = []
var food_array = []


#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

func Build_Genome():
	Genome["maxPV"]=[60,60]
	Genome["speed"] =[200,200]
	Genome["lifespan"]=[5000,5000]
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
	self.energy = 100
	self.maxPV = 60#Genome["maxPV"][self.current_life_cycle]	
	self.maxSpeed = 190


	AdjustBar()
	
func Build_Phenotype(): 
	# SPRITE
	
		
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	#$Sprite_0.offset.x = 0 # -$Sprite_0.texture.get_width()/4
	
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	#$Dead_Sprite_0.offset.x = 0# -$Dead_Sprite_0.texture.get_width()/2
	
	$Dead_Sprite_0.hide()

	#Body
	$Collision_0.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#Vision
	$Vision/Collision.shape.radius = 1500
	$Vision/Collision.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)


	init_progressbar()
	
	#attack
	var size_Barehand = Vector2(32,32*3)
	$BareHand_attack/CollisionShape2D.shape.size = size_Barehand
	$BareHand_attack/sprite.size = size_Barehand
	$BareHand_attack/sprite.position = -Vector2(0.5,0.5)*size_Barehand
	$BareHand_attack/sprite2.size = size_Barehand
	$BareHand_attack/sprite2.position = -Vector2(0.5,0.5)*size_Barehand


func _physics_process(delta):
	if isPlayer and isDead == false:
		input_dir = Player_Control_movement()

	else:
		if isDead == false :
			Brainy()

	move_and_collide(velocity *delta)
	global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	if item_array.size() > 0:
		var c = 0
		for i in item_array:
			i.position = position + Vector2(48+c*16,-64)
			c += 1
	
	if direction.normalized() != Vector2(0,0):
		last_dir = direction
	var temppos = position + last_dir * Vector2(64,96)
	$BareHand_attack.rotation =  (last_dir.angle()) 
	$BareHand_attack.position =  last_dir * $BareHand_attack/CollisionShape2D.shape.size* Vector2(1.5,0.5)  - $Sprite_0.texture.get_size() * Vector2(-0.25,0.5)

func _input(event):
	if isPlayer:
		if event.is_action_pressed("use"):
			#current_action = 3
			#UseItem()
			#Life.stop=true
			#Life.Instantiate_NewLife_in_Batch(get_parent(),0,20,Life.new_lifes)
			#attaque(input_dir)
			print("use is pressed")
		if event.is_action_pressed("interact"):
			PickUp()

		if event.is_action_pressed("drop"):
			Drop()

		if event.is_action_pressed("eat"):
			Eat_Action()
			#Eat()
		if event.is_action_pressed("attack"):
			Attack()
		if event.is_action_pressed("throw"):
			print( "throw is pressed")
			#Throw()
		'else:
			current_action = 2'
		if event.is_action_pressed("zoom_in"):
			$Camera2D.zoom.x += 0.25
			$Camera2D.zoom.y += 0.25

		if event.is_action_pressed("zoom_out"):
			$Camera2D.zoom.x -= 0.25
			$Camera2D.zoom.y -= 0.25


func Brainy():
	var center = position + Vector2($Sprite_0.texture.get_width()/2, -$Sprite_0.texture.get_height()/2)
	var food_array_temp = food_array.duplicate()

	if action_finished == true:
		if self.energy < 90 and food_array_temp.size()>0:
			var cl = getClosestLife(food_array_temp,1000)
			if cl !=null:
				$DebugLabel.text ="feeding" 
				#NEED TO ADJUST DISTANCE ACCORDING TO CENTER NOT CORNER
				if center.distance_to(cl.position) < (128*3) and cl.isDead == false:
					$DebugLabel.text ="charging"
					var rdn = randi_range(0,100)
					if rdn < 25:
						ChargeToward(cl.position)
					else:
						velocity = Vector2(0,0)
						action_finished = false
						$ActionTimer.start(2.)
					
				elif center.distance_to(cl.position) < 64 and cl.isDead == false:
						if cl.species=="catronaute":
							cl.getDamaged(10)
						else :
							Eat(cl)
							velocity = Vector2(0,0)
							$DebugLabel.text ="Eat"
				elif cl.isDead == false and center.distance_to(cl.position) >= 128*3:
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
			if center.distance_to(cl.position) < 64 and cl.isDead == false:
				if cl.species=="catronaute":
					cl.getDamaged(10)
				else :
					Eat(cl)
					velocity = Vector2(0,0)
					$DebugLabel.text ="Eat"
		'#AdjustDirection()
		print("here?")
		velocity = Vector2(0,0)'	

func ChargeToward(target):
	var center = position + Vector2($Sprite_0.texture.get_width()/2, -$Sprite_0.texture.get_height()/2)
	if action_finished == true:
		action_finished = false
		$ActionTimer.start(0.5)
		direction = -(center - target).normalized()
		velocity = direction * maxSpeed*4			

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
		if self.age > 2 and self.energy > 5:
			self.current_life_cycle += 1
			var crab_leg_combat_scene = Life.crab_leg_combat_scene.instantiate()
			get_parent().add_child(crab_leg_combat_scene) 
			crab_leg_combat_scene.position = self.position
			$Sprite_0.scale *= 3
			$Dead_Sprite_0.scale *=3
			$Collision_0.scale *=3
			$HurtBox/CollisionShape2D.scale *=3
			set_physics_process(true)
			self.maxSpeed = Genome["speed"][self.current_life_cycle]
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV

func LifeDuplicate():
	if self.age % 1 == 0 and self.energy > 60 and current_life_cycle >= 1:
			var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
			var li = Life.spidercrab_pool_state.find(0)
			#var li2 = Life.crab_leg_pool_state.find(0)		
			#+ Life.grass_pool_state.size()*0.05
			if li > -1 and Life.spidercrab_number  < Life.spidercrab_pool_scene.size():
				self.energy -= 30
				Life.spidercrab_pool_scene[li].Activate()
			#	Life.crab_leg_pool_scene[li2].Activate()
			#	Life.crab_leg_pool_scene[li2].PV = Genome["maxPV"][0]
		#		Life.crab_leg_pool_scene[li2].age = 0
		#		Life.crab_leg_pool_scene[li2].global_position = newpos 
				Life.spidercrab_pool_scene[li].energy = 30
				Life.spidercrab_pool_scene[li].age = 0
				Life.spidercrab_pool_scene[li].current_life_cycle = 0
				Life.spidercrab_pool_scene[li].PV = Genome["maxPV"][0]
				Life.spidercrab_number += 1
				Life.spidercrab_pool_scene[li].global_position = newpos 
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
	$HurtBox/CollisionShape2D.queue_free()
	
	
func Activate():
	set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.spidercrab_pool_state[self.pool_index] = 1
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
	Decomposition()
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.spidercrab_pool_state[self.pool_index] = 0
	Life.spidercrab_number -= 1
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
	$BareHand_attack/sprite.hide()
	$BareHand_attack/sprite2.hide()
	action_finished = true


func _on_mouse_entered():
	AdjustBar()
	$HP_bar.show()
	$Energy_bar.show()


func _on_mouse_exited():
	$HP_bar.hide()
	$Energy_bar.hide()
	

func _on_vision_body_entered(body):
	if body.species== "sheep":
		if body.current_life_cycle > 0:
			food_array.append(body)
	if body.species == "catronaute":
		food_array.append(body)

		#getAway(body.position)


func _on_vision_body_exited(body):

	if body.species== "sheep" :
		if body.current_life_cycle > 0:
			food_array.erase(body)
	if body.species == "catronaute":
		food_array.erase(body)

