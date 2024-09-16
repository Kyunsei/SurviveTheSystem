extends LifeEntity

var species = "catronaute"


var barehand_array = []
var action_finished = true

#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

func Build_Genome():
	Genome["maxPV"]=[10]
	Genome["speed"] =[200]
	Genome["lifespan"]=[1000]
	Genome["sprite"] = [preload("res://Art/player_cat.png")]
	Genome["dead_sprite"] = [preload("res://Art/poop_star.png")]
	
	Genome["planty_sprite"] = [preload("res://Art/player_bulbi.png")] #TEMPORAIRE

func init_progressbar():
	$HP_bar.modulate = Color(1, 0, 0)
	$Energy_bar.modulate = Color(0, 1, 0)
	#get("custom_styles/fg").bg_color = Color(1, 0, 0)

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]	
	self.PV = 5	
	self.energy = 10


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
	
	#attack
	var size_Barehand = Vector2(32,32*3)
	$BareHand_attack/CollisionShape2D.shape.size = size_Barehand
	$BareHand_attack/sprite.size = size_Barehand
	$BareHand_attack/sprite.position = -Vector2(0.5,0.5)*size_Barehand
	$BareHand_attack/sprite2.size = size_Barehand
	$BareHand_attack/sprite2.position = -Vector2(0.5,0.5)*size_Barehand


func _physics_process(delta):
	if isPlayer:
		input_dir = Player_Control_movement()
		move_and_collide(velocity *delta)


		if item_array.size() > 0:
			var c = 0
			for i in item_array:
				i.position = position + Vector2(c*16,0)
				c += 1
		
		if input_dir.normalized() != Vector2(0,0):
			last_dir = input_dir
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
	self.PV -= value
	AdjustBar()
	if self.PV <= 0:
		Die()

func AdjustBar():
	$HP_bar.value = self.PV *100 / 10 
	$Energy_bar.value = self.energy *100 / 10 


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
