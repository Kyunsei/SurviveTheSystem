extends LifeEntity

var species = "catronaute"


var barehand_array = []
var isimmobile_1sec = false
var dashing = false
var worn_out = false
var is_sprinting = false
var stamina = 100
var signalconnected = false

#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

# Interaction
var nearby_object: LifeEntity 
var interaction_array =[]

var eat_timer = 0

var zoomIncrement = 0.05
var zoomMin = 0.75
var zoomMax = 1.5
var zoom_level = 0
#other


func Build_Genome():
	Genome["maxPV"]=[10000000000000]
	Genome["stamina"]=[100]
	Genome["maxEnergy"]=[100]
	Genome["speed"] =[200]
	Genome["lifespan"]=[1000]
	Genome["sprite"] = [preload("res://Art/player_cat.png")]
	Genome["dead_sprite"] = [preload("res://Art/poop_star.png")]
	Genome["slime_sprite"] = [preload("res://Art/slime_down_1.png"),preload("res://Art/slime_right_1.png"),preload("res://Art/slime_up_1.png"),preload("res://Art/slime_left_1.png")]
	Genome["planty_sprite"] = [preload("res://Art/player_bulbi.png")] #TEMPORAIRE

func passive_healing():
	if self.PV < self.maxPV :
		self.PV += 0.2
		isimmobile_1sec = false

func stamina_regeneration():
	if is_sprinting == true :
		pass
	elif self.stamina < 100 : 
		self.stamina += 5
		#print("gained 5 stamina") #to know if you've regenerated stamina
		AdjustBar()
		isimmobile_1sec = false


func init_progressbar():
	$HP_bar.modulate = Color(1, 0, 0)
	$Energy_bar.modulate = Color(0, 1, 0)
	$Energy_bar.modulate = Color(0, 1, 1)
	#get("custom_styles/fg").bg_color = Color(1, 0, 0)

func Build_Stat():
	self.lifecycletime = 2. #5 times more quick #in second
	self.current_life_cycle = 0
	self.PV = 30
	self.energy = 50
	self.maxPV = 50
	self.maxEnergy = 100
	self.maxSpeed = 200
	self.stamina = 100
	self.lifespan = 6000 
	metabolic_cost = 1.
	AdjustBar()
	
func Build_Phenotype(): 
	# SPRITE
	$Sprite_0.texture = Genome["sprite"][0]
	if Life.char_selected == "planty":
		$Sprite_0.texture = Genome["planty_sprite"][0] #TEMPORAIRE
	if Life.char_selected == "slime":
		$Sprite_0.texture = Genome["slime_sprite"][0] #TEMPORAIRE
		$Sprite_0.scale = Vector2(1,1)
		
	#$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	#$Sprite_0.offset.x = -$Sprite_0.texture.get_width()/4
	
	$Dead_Sprite_0.texture = Genome["dead_sprite"][0]
	$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	
	$Dead_Sprite_0.hide()

	#ADD Body

	#$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	if World.debug_mode: 
		zoomMin = 0
	init_progressbar()
	
	self.size = $Sprite_0.texture.get_size()
	
	#attack
	#var size_Barehand = Vector2(32,32*3)
	#$BareHand_attack/CollisionShape2D.shape.size = size_Barehand
	#$BareHand_attack/CollisionShape2D/sprite.size = size_Barehand
	#$BareHand_attack/CollisionShape2D/sprite.position = -Vector2(1,0.5)*size_Barehand
	#$BareHand_attack/CollisionShape2D/sprite2.size = size_Barehand
	#$BareHand_attack/CollisionShape2D/sprite2.position = -Vector2(1,0.5)*size_Barehand

func Player_Control_movement():
		var input_dir = Vector2.ZERO
		var rotation_dir = 0
		if Input.is_action_pressed("left") :
			
			input_dir.x -= 1
			rotation_dir = -1	
			LastOrientation = "left"
			if Life.char_selected == "slime":
				$Sprite_0.texture = Genome["slime_sprite"][3] 
		if Input.is_action_pressed("right"):
			input_dir.x += 1
			rotation_dir = 1
			LastOrientation = "right"
			if Life.char_selected == "slime":
				$Sprite_0.texture = Genome["slime_sprite"][1] 
		if Input.is_action_pressed("up"):
			input_dir.y -= 1
			rotation_dir = -1
			LastOrientation = "up"
			if Life.char_selected == "slime":
				$Sprite_0.texture = Genome["slime_sprite"][2] 
		if Input.is_action_pressed("down"):
			input_dir.y += 1
			rotation_dir = 1
			LastOrientation = "down"
			if Life.char_selected == "slime":
				$Sprite_0.texture = Genome["slime_sprite"][0] 
				
		velocity = input_dir.normalized() * self.maxSpeed
		position.x = clamp(position.x, 0, World.world_size*World.tile_size)
		position.y = clamp(position.y, 0, World.world_size*World.tile_size)
		return input_dir
		
func _physics_process(delta):
	if isPlayer and isDead == false:
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
				
		if input_dir.normalized() != Vector2(0,0):
			last_dir = input_dir 
			isimmobile_1sec = false	
			
		Highlight_closest_pickable_element()
		
		if Input.is_action_pressed("eat") :
			if item_array.size() >0 or nearby_object:
				$TextureProgressBar.show()
				eat_timer += delta * 120
				$TextureProgressBar.value = eat_timer
				
				if eat_timer >= 100:	
					if item_array.size() >0:
						Eat_Action()
						if item_array.size() ==0 :
							$TextureProgressBar.hide()
					elif nearby_object:
						Eat(nearby_object)
						$TextureProgressBar.hide()
					eat_timer = 0
					
			#timer += delta
		
		'if timer >= threshold_time and action_started:
		action_started = false
		timer = 0
		print("hold")'
		
	move_and_slide()
	
	
	var temppos = position + last_dir * Vector2(64,96)
	$BareHand_attack.rotation =  (last_dir.angle()) 
	#$BareHand_attack.position =  last_dir * $BareHand_attack/CollisionShape2D.shape.size* Vector2(3,3)  + Vector2(32,-32)#- $Sprite_0.texture.get_size() * Vector2(-0.25,0.5)
	if item_array.size() > 0:
		var c = 0
		for i in item_array:
			if i.species == "spidercrab_leg" or i.species == "spidercrab_claw":
				#i.position =  position + Vector2(16,-16)+ last_dir*Vector2(64,64)
				i.position =  last_dir * $Sprite_0.texture.get_size() * Vector2(1,1)  + (position + $Sprite_0.texture.get_size()/2* Vector2(1,-1))
				i.rotation =  (last_dir.angle())
			else: 
				c += 1
				i.position =  last_dir * $Sprite_0.texture.get_size() * Vector2(1,1)/2  + (position + $Sprite_0.texture.get_size()/4* Vector2(1,-1))
	
func _input(event):
	if isPlayer and isDead == false:
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


		if Input.is_action_just_released("eat"):
			eat_timer = 0
			$TextureProgressBar.value = eat_timer
			$TextureProgressBar.hide()
			#if timer < threshold_time and action_started:
			#action_started = false

			
		'if event.is_action_pressed("eat"):
		
			eat_timer = 0
			$TextureProgressBar.show()
			$TextureProgressBar.value = eat_timer'

			#Eat()
			#isimmobile_1sec = false
		if event.is_action_released("sprint"):
			Sprint_Action_Stop()
			isimmobile_1sec = false
			if is_sprinting == false :
				$RegenTimer.start(0.5)
		if event.is_action_pressed("attack"):
			Attack()
			isimmobile_1sec = false
		if event.is_action_pressed("throw"):
			print( "throw is pressed")
			#Throw()
			isimmobile_1sec = false
		'else:
			current_action = 2'
		zoom_level = get_parent().get_parent().get_node("Camera2D").zoom.x
		if event.is_action_pressed("zoom_in"):
			#if input_dir == Vector2(0,0):
				#get_parent().get_parent().get_node("Camera2D").zoom.x += zoomIncrement
				#get_parent().get_parent().get_node("Camera2D").zoom.y += zoomIncrement
				zoom_level = clamp(zoom_level + zoomIncrement, zoomMin, zoomMax)
				get_parent().get_parent().get_node("Camera2D").zoom = zoom_level * Vector2.ONE

				get_tree().get_root().set_input_as_handled()
				#World.fieldofview = round(get_viewport().get_visible_rect().size * 1/$Camera2D.zoom / World.tile_size) 


		if event.is_action_pressed("zoom_out"):
			#if input_dir == Vector2(0,0):
				#get_parent().get_parent().get_node("Camera2D").zoom.x -= 0.05
				#get_parent().get_parent().get_node("Camera2D").zoom.y -= 0.05
				zoom_level = clamp(zoom_level - zoomIncrement, zoomMin, zoomMax)
				get_parent().get_parent().get_node("Camera2D").zoom = zoom_level * Vector2.ONE
		if World.debug_mode:
			#if event.is_action_pressed("test1"):
				#print("q")
				#var middle = position  #+ Vector2(size.x/2,-size.y/2)'
				#var center_x = int(middle.x/World.tile_size)
				#var	center_y = int(middle.y/World.tile_size)
				#var radius = 2 #in tiles
				#for x in range(center_x - radius, center_x + radius + 1):
					#for y in range(center_y - radius, center_y + radius + 1):
						#if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
							#var posindex = y*World.world_size + x
							#if posindex < World.block_element_array.size():				
								#World.block_element_array[posindex]	-= 5
								#if 	World.block_element_array[posindex]	< 0:
									#World.block_element_array[posindex]	= 0
								#update_tiles_according_soil_value([Vector2i(x,y)])
				#'for b in get_parent().get_parent().get_node("Blocks").get_children():
					#b.BlockUpdate()'

			#if event.is_action_pressed("test2"):
				#print("e")
				#var middle = position  #+ Vector2(size.x/2,-size.y/2)'
				#var center_x = int(middle.x/World.tile_size)
				#var	center_y = int(middle.y/World.tile_size)
				#var radius = 2 #in tiles
				#for x in range(center_x - radius, center_x + radius + 1):
					#for y in range(center_y - radius, center_y + radius + 1):
						#if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
							#var posindex = y*World.world_size + x
							#if posindex < World.block_element_array.size():				
								#World.block_element_array[posindex]	+= 5
								#update_tiles_according_soil_value([Vector2i(x,y)])
				#'for b in get_parent().get_parent().get_node("Blocks").get_children():
					#b.BlockUpdate()'
			if event.is_action_pressed("T"):
				position = get_viewport().get_camera_2d().get_global_mouse_position()
				
			if event.is_action_pressed("test1"):
				var mouse_position =get_viewport().get_camera_2d().get_global_mouse_position()
				draw_block(mouse_position, 0, 1)
			if event.is_action_pressed("test2"):
				var mouse_position =get_viewport().get_camera_2d().get_global_mouse_position()
				draw_block(mouse_position, -1, 1)


func draw_block(mouse_position, value, radius):
				var center_x = int(mouse_position.x/World.tile_size)
				var	center_y = int(mouse_position.y/World.tile_size)
				for x in range(center_x - radius, center_x + radius + 1):
					for y in range(center_y - radius, center_y + radius + 1):
						#if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
							var posindex = y*World.world_size + x
							if posindex < World.block_element_array.size() and posindex >= 0:
								print(World.block_element_array[posindex])				
								World.block_element_array[posindex]	= value
								get_parent().get_parent().get_node("World_TileMap").draw_new_tiles_according_to_soil_value(0, [Vector2i(x,y)])
								#get_parent().get_parent().get_node("World_TileMap").update_ALL_tilemap_tile_to_new_soil_value()
								#get_parent().get_parent().get_node("World_TileMap").update_tilemap_tile_array_to_new_soil_value(0, [Vector2i(x,y)])

func Highlight_closest_pickable_element():
	if interaction_array.size() > 0:
		var closest_item = getClosestLife(interaction_array,$Interaction_Area/CollisionShape2D.shape.radius+100)
		if closest_item:
			if nearby_object:
				if nearby_object != closest_item:
					nearby_object.current_sprite.modulate = Color(1,1,1)
					nearby_object.z_index = 0		
					nearby_object = closest_item
					nearby_object.current_sprite.modulate = Color(0,0,1)
					nearby_object.z_index = 1	
			else:
				nearby_object = closest_item
				nearby_object.current_sprite.modulate = Color(0,0,1)
				nearby_object.z_index = 1
				




func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:


			Metabo_cost(metabolic_cost)
			Ageing()
			passive_healing()
			AdjustBar()


			if self.energy <= 0:
				cause_of_death = deathtype.HUNGER
				Die()
			if self.age >= lifespan:
				cause_of_death = deathtype.AGE
				Die()
					
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			if energy <= 0:
				Deactivate()
			else:
				energy -= 5


func getDamaged(value,antagonist:LifeEntity=null):
	if InvicibilityTime == 0:
		InvicibilityTime = 1 
		$sound/hurt_sound.playing = true
		self.PV -= value
		AdjustBar()

		$Sprite_0.modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.8).timeout
		InvicibilityTime = 0
		$Sprite_0.modulate = Color(1, 1, 1)
		if self.PV <= 0:
			Die()
			cause_of_death = deathtype.DAMMAGE

func AdjustBar():
	$HP_bar.value = self.PV *100 / self.maxPV
	$Energy_bar.value = self.energy *100 / self.maxEnergy


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

		if Input.is_action_pressed("up") or Input.is_action_pressed("down") or Input.is_action_pressed("left") or Input.is_action_pressed("right") :
			await get_tree().create_timer(0.2).timeout
			#self.stamina -= 1

		AdjustBar()
	else :
		action_finished = true
		self.maxSpeed = 200
		
func Dash_Action():
	if dashing == false: # and worn_out == false and self.stamina >= 10:
		dashing = true
		var initial_position = position
		action_finished = false #not use here
		if self.maxSpeed < 400  :
			#self.stamina -= 10
			worn_out = true
			self.maxSpeed = 1500
			#$Collision_0.shape.size *= 0.4
			set_collision_mask_value(2,false)
			velocity = last_dir.normalized()*self.maxSpeed
			await get_tree().create_timer(0.2).timeout
			dashing = false
			
			action_finished = true 
			set_collision_mask_value(2,true)
			#$Collision_0.shape.size *= 2.5
			velocity = Vector2.ZERO
			self.maxSpeed = 200
			if getsoiltype(position)== 0:
				await get_tree().create_timer(0.1).timeout
				self.PV -= 20
				position = initial_position
				if PV <= 0:
					Die()
					cause_of_death = deathtype.VOID
			AdjustBar() #Ca c'est pour que les bar de HP et faim change si jaja
			
			await get_tree().create_timer(1.5).timeout
			worn_out = false

func getsoiltype(pos):
	var x = int(pos.x/World.tile_size)
	var y = int(pos.y/World.tile_size)
	var posindex = y*World.world_size + x
	return World.block_element_state[posindex]
				

func Sprint_Action_Stop():
	if dashing == true : 
		is_sprinting = false
		pass
	else :
		is_sprinting = false
		action_finished = true
		self.maxSpeed = 200

func PickUp():
	if nearby_object:
		action_finished = false
		'$BareHand_attack/CollisionShape2D/sprite2.show()
		$BareHand_attack/ActionTimer.start(0.2)'

		nearby_object.getPickUP(self)
		nearby_object.current_sprite.modulate = Color(1,1,1)
		nearby_object.z_index = 0		
		interaction_array.erase(nearby_object)
		nearby_object = null
		
	
	'var closestItem = getClosestLife(barehand_array,$Vision/Collision.shape.radius+100)
	if closestItem != null:
		var distancetoclosestItem = position.distance_to(closestItem.position)
		if  distancetoclosestItem < 64 :
			if closestItem.current_sprite:
				closestItem.current_sprite.modulate = Color(0,0,1)

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
			#if closestItem.species == "grass" : #used to be used to grab grass
				#closestItem.getPickUP(self)
				#closestItem.z_index = 0
			if closestItem.species == "stingtree" and  closestItem.current_life_cycle == 0:
				if closestItem.mother_tree == null:
					closestItem.getPickUP(self)
					closestItem.z_index = 0'

	
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


func getPushed(from,distance):

	var camera = get_parent().get_parent().get_node("Camera2D")
	camera.position_smoothing_enabled = true
	direction = (getCenterPos() - from.getCenterPos()).normalized()
	position = position +  direction * distance
	await get_tree().create_timer(0.3).timeout

	camera.position_smoothing_enabled = false

func BareHand_attack():
	#$BareHand_attack/CollisionShape2D.disabled = false
	$BareHand_attack/CollisionShape2D/sprite.show()
	$BareHand_attack/ActionTimer.start(0.2)
	for i in barehand_array:
		#print(i)
		if i != null :
	

			if i.species == "spiky_grass" :
				self.getDamaged(2)
				i.getDamaged(1)
			else :
				i.getDamaged(10,self)


			

func Die():
	$sound/death_sound.playing = true
	DropALL()
	self.isDead = true
	velocity = Vector2(0,0)
	$Dead_Sprite_0.show()
	$Sprite_0.hide()
	
	await get_tree().create_timer(1.8).timeout
	Deactivate()
	
	
func Activate():
	if not signalconnected:
		get_parent().get_parent().light_out.connect( _on_light_out)
		get_parent().get_parent().light_on.connect( _on_light_on)
		signalconnected = true
	set_physics_process(true)
	self.isActive = true
	self.isDead = false
	Life.pool_state["cat"][pool_index] = 1
	Life.life_number["cat"] += 1
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
	#Decomposition(1)
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.pool_state["cat"][pool_index] = 0
	Life.life_number["cat"] -= 1
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
	elif life.species == "sheep" and life.current_life_cycle >= 2 and life.isDead:
		var value = min(life.energy,10)
		self.energy += value
		life.energy -= value
		if life.energy <= 0:
			life.Deactivate()

	elif life.species == "petal" and life.isDead == false :
		self.energy += life.energy
		life.energy= 0
		PV += 10
		life.Die()
	#$DebugLabel.text = str(age) + " " + str(energy)
	self.energy = clamp(self.energy,0, self.maxEnergy)

	AdjustBar()
#Sacrebleu il faut changer toutes les entity pour leur donner des "damageable" group
func _on_bare_hand_attack_body_entered(body):
	if body != self and body.is_in_group("not_damageable") == false :
		if body.z_index == 0:
			barehand_array.append(body)	
#Sacrebleu il faut changer toutes les entity pour leur donner des "damageable" group

func _on_bare_hand_attack_body_exited(body):
	if body != self:
		if barehand_array.has(body):
			barehand_array.erase(body)


func _on_action_timer_timeout():
	$BareHand_attack/CollisionShape2D/sprite.hide()
	$BareHand_attack/CollisionShape2D/sprite2.hide()
	
	#$BareHand_attack/CollisionShape2D.disabled = true
	action_finished = true


func _on_regen_timer_timeout():
	stamina_regeneration()
	action_finished = true


func _on_bare_hand_attack_area_entered(area):
	if area.is_in_group("damageable"):
		#print("damageable area touched")
		area.get_parent().getDamaged(10,self)


func _on_interaction_area_body_entered(body):
	if self.isActive:
		if body.isPickable and item_array.has(body)==false and body.isDead==false:
			interaction_array.append(body)
		elif body.species == "sheep" and body.isDead and item_array.has(body)==false:
			interaction_array.append(body)
		


func _on_interaction_area_body_exited(body):
	if nearby_object == body:
		nearby_object.current_sprite.modulate = Color(1,1,1)
		nearby_object.z_index = 0
		nearby_object = null
	if interaction_array.has(body):
		interaction_array.erase(body)
		
				
func _on_light_on() :
		$PointLight2D.show()
	
	
func _on_light_out() :
	$PointLight2D.hide()
