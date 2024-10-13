extends LifeEntity

var species = "catronaute"


var barehand_array = []
var isimmobile_1sec = false
var dashing = false
var worn_out = false
var is_sprinting = false
var stamina = 100

#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

func Build_Genome():
	Genome["maxPV"]=[10000000000000]
	Genome["stamina"]=[100]
	Genome["maxEnergy"]=[100]
	Genome["speed"] =[200]
	Genome["lifespan"]=[1000]
	Genome["sprite"] = [preload("res://Art/player_cat.png")]
	Genome["dead_sprite"] = [preload("res://Art/poop_star.png")]
	
	Genome["planty_sprite"] = [preload("res://Art/player_bulbi.png")] #TEMPORAIRE

func passive_healing():
	if self.PV < self.maxPV and isimmobile_1sec == true:
		self.PV += 0.5
		AdjustBar()
		isimmobile_1sec = false

func stamina_regeneration():
	if self.stamina < 100 :
		self.stamina += 5
		AdjustBar()
		isimmobile_1sec = false


func init_progressbar():
	$HP_bar.modulate = Color(1, 0, 0)
	$Energy_bar.modulate = Color(0, 1, 0)
	$Energy_bar.modulate = Color(0, 1, 1)
	#get("custom_styles/fg").bg_color = Color(1, 0, 0)

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = 30
	self.energy = 50
	self.maxPV = 50
	self.maxEnergy = 100
	self.maxSpeed = 200
	self.stamina = 100
	AdjustBar()
	
func Build_Phenotype(): 
	# SPRITE
	$Sprite_0.texture = Genome["sprite"][0]
	if Life.char_selected == "planty":
		$Sprite_0.texture = Genome["planty_sprite"][0] #TEMPORAIRE
		
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	$Sprite_0.offset.x = -$Sprite_0.texture.get_width()/4
	
	$Dead_Sprite_0.texture = Genome["dead_sprite"][0]
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	
	$Dead_Sprite_0.hide()

	#ADD Body

	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	init_progressbar()
	
	self.size = $Sprite_0.texture.get_size()
	
	#attack
	var size_Barehand = Vector2(32,32*3)
	$BareHand_attack/CollisionShape2D.shape.size = size_Barehand
	$BareHand_attack/sprite.size = size_Barehand
	$BareHand_attack/sprite.position = -Vector2(0.5,0.5)*size_Barehand
	$BareHand_attack/sprite2.size = size_Barehand
	$BareHand_attack/sprite2.position = -Vector2(0.5,0.5)*size_Barehand


func _physics_process(delta):
	if isPlayer:
		if dashing == false :
			input_dir = Player_Control_movement()
			
		if Input.is_action_just_pressed("sprint"):
				Dash_Action() 
				isimmobile_1sec = false
		if Input.is_action_pressed("sprint"):
			Sprint_Action()
			isimmobile_1sec = false

		'else :
			#if isimmobile_1sec == false and action_finished == true:'

		if  is_sprinting == false and action_finished == true:
			action_finished = false
			$RegenTimer.start(0.5)
			#isimmobile_1sec = true
				
		if input_dir.normalized() != Vector2(0,0):
			last_dir = input_dir 
			isimmobile_1sec = false	
				
	move_and_slide()
	
	var temppos = position + last_dir * Vector2(64,96)
	$BareHand_attack.rotation =  (last_dir.angle()) 
	$BareHand_attack.position =  last_dir * $BareHand_attack/CollisionShape2D.shape.size* Vector2(1.5,0.5)  - $Sprite_0.texture.get_size() * Vector2(-0.25,0.5)
	if item_array.size() > 0:
		var c = 0
		for i in item_array:
			if i.species == "spidercrab_leg" or i.species == "spidercrab_claw":
				i.position =  last_dir * Vector2(32+i.size.x/2, 32 + i.size.x/2) + (position + Vector2(16,-32))
				i.rotation =  (last_dir.angle())
			else: 
				c += 1
				i.position =  last_dir * i.size * Vector2(1,1)  +position
	
func _input(event):
	if isPlayer:
		#var object_attack_vector = Vector2(get_viewport().get_mouse_position() - self.position)
		#object_attack_vector = object_attack_vector.normalized()*60
		if event.is_action_pressed("use"):
			#current_action = 3
			#UseItem()
			#Life.stop=true
			#Life.Instantiate_NewLife_in_Batch(get_parent(),0,20,Life.new_lifes)
			#attaque(input_dir)
			print("use is pressed")
			isimmobile_1sec = false
		if event.is_action_pressed("interact"):
			PickUp()
			isimmobile_1sec = false
		if event.is_action_pressed("drop"):
			Drop()
			isimmobile_1sec = false

		if event.is_action_pressed("eat"):
			Eat_Action()
			#Eat()
			isimmobile_1sec = false
		if event.is_action_released("sprint"):
			Sprint_Action_Stop()
			isimmobile_1sec = false
		if event.is_action_pressed("attack"):
			Attack()
			isimmobile_1sec = false
		if event.is_action_pressed("throw"):
			print( "throw is pressed")
			#Throw()
			isimmobile_1sec = false
		'else:
			current_action = 2'
		if event.is_action_pressed("zoom_in"):
			#if input_dir == Vector2(0,0):
				$Camera2D.zoom.x += 0.05
				$Camera2D.zoom.y += 0.05
				#World.fieldofview = round(get_viewport().get_visible_rect().size * 1/$Camera2D.zoom / World.tile_size) 


		if event.is_action_pressed("zoom_out"):
			#if input_dir == Vector2(0,0):
				$Camera2D.zoom.x -= 0.05
				$Camera2D.zoom.y -= 0.05
				#World.fieldofview = round(get_viewport().get_visible_rect().size * 1/$Camera2D.zoom / World.tile_size)

		if event.is_action_pressed("test1"):
			print("q")
			var middle = position  #+ Vector2(size.x/2,-size.y/2)'
			var center_x = int(middle.x/World.tile_size)
			var	center_y = int(middle.y/World.tile_size)
			var radius = 2 #in tiles
			for x in range(center_x - radius, center_x + radius + 1):
				for y in range(center_y - radius, center_y + radius + 1):
					if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
						var posindex = y*World.world_size + x
						if posindex < World.block_element_array.size():				
							World.block_element_array[posindex]	-= 5
							if 	World.block_element_array[posindex]	< 0:
								World.block_element_array[posindex]	= 0
							update_tiles_according_soil_value([Vector2i(x,y)])
			'for b in get_parent().get_parent().get_node("Blocks").get_children():
				b.BlockUpdate()'

		if event.is_action_pressed("test2"):
			print("e")
			var middle = position  #+ Vector2(size.x/2,-size.y/2)'
			var center_x = int(middle.x/World.tile_size)
			var	center_y = int(middle.y/World.tile_size)
			var radius = 2 #in tiles
			for x in range(center_x - radius, center_x + radius + 1):
				for y in range(center_y - radius, center_y + radius + 1):
					if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
						var posindex = y*World.world_size + x
						if posindex < World.block_element_array.size():				
							World.block_element_array[posindex]	+= 5
							update_tiles_according_soil_value([Vector2i(x,y)])
			'for b in get_parent().get_parent().get_node("Blocks").get_children():
				b.BlockUpdate()'


func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:

			Metabo_cost()
			Ageing()
			AdjustBar()


			if self.energy <= 0 or self.age >= Genome["lifespan"][self.current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()


func getDamaged(value):
	if InvicibilityTime == 0:
		self.PV -= value
		AdjustBar()
		InvicibilityTime = 1 
		$Sprite_0.modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.5).timeout
		InvicibilityTime = 0
		$Sprite_0.modulate = Color(1, 1, 1)
	if self.PV <= 0:
		Die()

func AdjustBar():
	$HP_bar.value = self.PV *100 / self.maxPV
	$Energy_bar.value = self.energy *100 / self.maxEnergy
	$Stamina_bar.value = self.stamina *100 / 100


func Attack():
	#var s = Time.get_ticks_msec()
	action_finished = false
	if item_array.size() != 0:
		item_array[0].Use_Attack()
	else :
		BareHand_attack()
	#var ss = Time.get_ticks_msec()
	#print(ss-s)
		

	
func Sprint_Action():
	if self.stamina > 1 :
		is_sprinting = true
		action_finished = false
		if self.maxSpeed < 300 :
			self.maxSpeed = 300

		await get_tree().create_timer(0.2).timeout
		self.stamina -= 1

		AdjustBar()
	else :
		action_finished = true
		self.maxSpeed = 200
		
func Dash_Action():
	if dashing == false and worn_out == false and self.stamina >= 10:
		dashing = true
		action_finished = false #not use here
		if self.maxSpeed < 400  :
			self.stamina -= 10
			worn_out = true
			self.maxSpeed = 1500
			#$Collision_0.shape.size *= 0.4
			velocity = last_dir.normalized()*self.maxSpeed
			await get_tree().create_timer(0.2).timeout
			dashing = false
			action_finished = true 
			#$Collision_0.shape.size *= 2.5
			velocity = Vector2.ZERO
			self.maxSpeed = 200
			AdjustBar() #Ca c'est pour que les bar de HP et faim change si jaja
			await get_tree().create_timer(1.5).timeout
			worn_out = false


func Sprint_Action_Stop():
	if dashing == true : 
		pass
	else :
		is_sprinting = false
		action_finished = true
		self.maxSpeed = 200

func PickUp():
	action_finished = false
	$BareHand_attack/sprite2.show()
	$BareHand_attack/ActionTimer.start(0.2)
	var closestItem = getClosestLife(barehand_array,$Vision/Collision.shape.radius+100)
	if closestItem != null:
		var distancetoclosestItem = position.distance_to(closestItem.position)
		if  distancetoclosestItem < 64 :

			if closestItem.species == "berry":
				if closestItem.current_life_cycle == 0:
					closestItem.getPickUP(self)
					closestItem.z_index = 0
				if closestItem.current_life_cycle == 3:
					closestItem.LifeDuplicate2(self)

			if closestItem.species == "spidercrab_leg":
				closestItem.getPickUP(self)
				closestItem.z_index = 0

			if closestItem.species == "spidercrab_claw":
				closestItem.getPickUP(self)
				closestItem.z_index = 0

			if closestItem.species == "petal" and closestItem.isDead == false :
				closestItem.getPickUP(self)
				closestItem.z_index = 0

			if closestItem.species == "rock"  :
				closestItem.getPickUP(self)
				closestItem.z_index = 0


			if closestItem.species == "sheep" and closestItem.current_life_cycle < 2:
				closestItem.getPickUP(self)
				closestItem.z_index = 0
			#if closestItem.species == "grass" :
				#closestItem.getPickUP(self)
				#closestItem.z_index = 0
			if closestItem.species == "stingtree" and  closestItem.current_life_cycle == 0:
				if closestItem.mother_tree == null:
					closestItem.getPickUP(self)
					closestItem.z_index = 0

	
func Drop():
	if item_array.size() >0:
		item_array[0].carried_by = null
		item_array[0].z_index = 0
		if item_array[0].species == "rock" :
			item_array[0].getDropped(self)
			item_array.remove_at(0)
		else :
			item_array.remove_at(0)

func Throw():
	pass

func Eat_Action():
	if item_array.size() >0:	
		Eat(item_array[0])
		AdjustBar()



func BareHand_attack():
	$BareHand_attack/sprite.show()
	$BareHand_attack/ActionTimer.start(0.2)
	for i in barehand_array:
		#print(i)
		if i != null :
			if i.species == "jellybee" :
				i.angry_mode_on(self)

			elif i.species == "spiky_grass" :
				self.getDamaged(2)
				i.getDamaged(1)
			else :
				i.getDamaged(1)


			

func Die():
	DropALL()
	self.isDead = true
	$Dead_Sprite_0.show()
	$Sprite_0.hide()
	
	
func Activate():
	set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.cat_pool_state[self.pool_index] = 1
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
	Life.cat_pool_state[self.pool_index] = 0
	Life.cat_number -= 1
	hide()

func Eat(life):
	#print("Eaten")
	if life.species == "berry" and life.current_life_cycle == 0:
		self.energy += life.energy
		life.energy= 0
		life.Die()
	elif life.species == "sheep" and life.current_life_cycle < 2:
		self.energy += life.energy
		life.energy= 0
		life.Die()
	elif life.species == "petal" :
		self.energy += life.energy
		life.energy= 0
		PV += 10
		life.Die()
	#$DebugLabel.text = str(age) + " " + str(energy)

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
	#passive_healing()
	action_finished = true


func _on_regen_timer_timeout():
	if is_sprinting == false:
		stamina_regeneration()
	action_finished = true
