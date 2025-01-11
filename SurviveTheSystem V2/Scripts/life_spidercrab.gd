extends LifeEntity

var species = "spidercrab"


var barehand_array = []

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var vision_array = {
	"food": [],
	"danger": [],
	"enemy": []
}


var isBurrow = false
#movmnt
var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0

var clone_timer = 0

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
	print(rotation)
	self.current_life_cycle = 0
	self.PV = 60# Genome["maxPV"][self.current_life_cycle]	
	self.energy = 0
	self.maxEnergy = 50
	self.maxPV = 60#Genome["maxPV"][self.current_life_cycle]	
	self.maxSpeed = 190
	self.size = $Sprite_0.texture.get_size()*0.33
	self.age= 0
	self.lifespan = 30*(World.one_day_length/lifecycletime)
	self.isPickable = true
	AdjustBar()
	metabolic_cost = 3
	
func Build_Phenotype(): 
	# SPRITE
	
	$Sprite_0.scale *= Genome["scale"][self.current_life_cycle]
	#$Collision_0.shape.size = size
	$Dead_Sprite_0.scale *= Genome["scale"][self.current_life_cycle]
	$light.scale *= Genome["scale"][self.current_life_cycle]
	
	#$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	##$Sprite_0.offset.x = 0 # -$Sprite_0.texture.get_width()/4
	#
	#$Dead_Sprite_0.offset.y = -$Dead_Sprite_0.texture.get_height()
	#$Dead_Sprite_0.offset.x = 0# -$Dead_Sprite_0.texture.get_width()/2
	
	$Dead_Sprite_0.hide()

	#Body
	#$Collision_0.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #Vector2(width/2,-height/2)
	#$Collision_1.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*1

	#Vision
	$Vision/Collision.shape.radius = 5500
	$Vision/Collision.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #Vector2(width/2,-height/2)


	init_progressbar()
	


func _physics_process(delta):
	if carried_by == null :
		if isPlayer and isDead == false:
			input_dir = Player_Control_movement()

		'else:
			if isDead == false :
				Brainy()'

		move_and_slide()
		global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
		global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
		if item_array.size() > 0:
			var c = 0
			for i in item_array:
					i.position = position #+ Vector2(48+c*16,-64)
					c += 1
		
		if direction.normalized() != Vector2(0,0):
			last_dir = direction

func hide_under_soil():
	get_node("Sprite_0").hide()
	
	#current_sprite.hide()
	
	self.maxSpeed = 0
	velocity = Vector2(0,0)
	isBurrow = true
	get_node("Collision_" + str(current_life_cycle)).disabled = true
	#$DebugLabel.text = "under_soil"
	if self.current_life_cycle == 0:
		$ActionTimer.start(10.)
		$HP_bar.hide()
		
func getDamaged(value,antagonist:LifeEntity=null):
	if current_life_cycle == 1:
		var CrabToAntagonist =  position.direction_to(antagonist.getCenterPos())
		var crab_facing_direction = Vector2(cos(rotation),sin(rotation)) 

		if CrabToAntagonist.dot(crab_facing_direction) < -0.8 :
			if InvicibilityTime == 0:
				getPushed(antagonist,64)
				$Sound/hurt.playing = true
				vision_array["enemy"].append(antagonist)
				self.PV -= value
				if self.PV <= 0:
					Die()
				InvicibilityTime = 1 
				modulate = Color(1, 0.2, 0.2)
				await get_tree().create_timer(0.1).timeout
				InvicibilityTime = 0
				modulate = Color(1, 1, 1)
				if self.has_node("HP_bar"):
					self.AdjustBar()
					self.get_node("HP_bar").show()
		else:
			antagonist.getPushed(self,64)
			$Sound/Cling.playing = true
		
		
	elif current_life_cycle == 0:
		if InvicibilityTime == 0:
			self.PV -= value
			if self.PV <= 0:
				Die()
			InvicibilityTime = 1 
			modulate = Color(1, 0.2, 0.2)
			await get_tree().create_timer(0.1).timeout
			InvicibilityTime = 0
			modulate = Color(1, 1, 1)
			if self.has_node("HP_bar"):
				self.AdjustBar()
				self.get_node("HP_bar").show()
			if current_life_cycle == 0:
				hide_under_soil()
		


func get_out_of_soil():
	get_node("Sprite_0").show()
	get_node("Collision_"+ str(current_life_cycle)).disabled = false
	isBurrow = false
	self.maxSpeed = Genome["speed"][self.current_life_cycle]
	$DebugLabel.text = ""
	
func attack_from_soil(cl):
	get_out_of_soil()
	$DebugLabel.text = "CHAAAARGE !!!!"
	pass

func _on_timer_timeout():
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
			if current_life_cycle == 1:
					Metabo_cost(metabolic_cost)
			elif current_life_cycle == 0:
					Metabo_cost(metabolic_cost+1)

			Ageing()
			#AdjustBar()
			LifeDuplicate()
			Growth()



			if self.energy <= 0 or self.age >= Genome["lifespan"][self.current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			if energy <= 0:
				Deactivate()
			else:
				energy -= 5

func Crab_drop() :
	#var leg_pos = [position-Vector2(48,0), position-Vector2(-48,0), position-Vector2(48,-32), position-Vector2(-48,-32)]
	#var leg_rotation = [-1.5707963268,1.5707963268,-1.5707963268,1.5707963268]
	#var leg_flip = [1,0,1,0]
	#for n in range(4) :
		#var crab_leg = Life.spidercrab_leg_scene.instantiate()
		#get_parent().add_child(crab_leg) 
		#crab_leg.position = leg_pos[n]
		#crab_leg.rotation = leg_rotation[n]
		#crab_leg.get_node("Sprite_0").flip_h = leg_flip[n]
	var claw_pos = [position-Vector2(32,-64), position-Vector2(-32,-64)]
	var claw_rotation = [-6.2831853072,0]
	var claw_flip = [0,1]
	for n in range(2) :
		var crab_claw = Life.spidercrab_claw_scene.instantiate()
		get_parent().add_child(crab_claw) 
		crab_claw.position = claw_pos[n]
		crab_claw.rotation = claw_rotation[n]
		crab_claw.get_node("Sprite_0").flip_h = claw_flip[n]

func Growth():
	if current_life_cycle == 0:
		#10*(World.one_day_length/lifecycletime)
		if self.age > 5*(World.one_day_length/lifecycletime) and self.energy >= 30:
			self.current_life_cycle += 1
			
				
			
			$Sprite_0.scale = Vector2(1,1)
			$Dead_Sprite_0.scale = Vector2(1,1)
			$light.scale = Vector2(1,1)
			self.isPickable = false
			
			Update_sprite($Sprite_0,$Collision_1)
			'$Collision_0.disabled = true
			$Collision_1.disabled = false
			$Collision_0.hide()
			$Collision_1.show()'
			position.x = position.x - $Sprite_0.texture.get_width()/2  + size.x/2 #*Vector2(1,0)
			position.y = position.y + $Sprite_0.texture.get_height()/2  - size.y/2 #*Vector2(1,0)
			$Collision_0.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #- ($Sprite_0.texture.get_size()/2 + size/2)*Vector2(1,0)
			$Vision/Collision.position = Vector2($Sprite_0.texture.get_width()/2,-$Sprite_0.texture.get_height()/2)*Genome["scale"][self.current_life_cycle] #- ($Sprite_0.texture.get_size()/2 + size/2)*Vector2(1,0)
			size = $Sprite_0.texture.get_size()
			
			vision_array["food"] = []
			vision_array["danger"] = []
			$Vision/Collision.disabled = true
			$Vision/Collision.disabled = false
			
			
			maxSpeed = 190
			self.maxEnergy = 80
			self.maxSpeed = Genome["speed"][self.current_life_cycle]
			self.maxPV = Genome["maxPV"][self.current_life_cycle]
			self.PV = self.maxPV

func LifeDuplicate():
	#10*(World.one_day_length/lifecycletime)
	if self.age > 20.*(World.one_day_length/lifecycletime) and self.energy >= 70 and current_life_cycle >= 1:
			if clone_timer == 0 :
				
				var newpos = PickRandomPlaceWithRange(position,1 * World.tile_size)
				var life = Life.build_life(species)
				if life != null:
					self.energy -= 15			
					life.energy = 15
					life.global_position = newpos 
					clone_timer = 5.*(World.one_day_length/lifecycletime)
				else:
					print("spidercrab_pool empty")
			else:
				clone_timer -= 1

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
		#AdjustBar()



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
	Update_sprite($Dead_Sprite_0, $Collision_0)
	Crab_drop()
	'$Dead_Sprite_0.show()
	$Sprite_0.hide()'

	
	
func Activate():

	set_physics_process(true)
	Update_sprite($Sprite_0, $Collision_0)
	self.isActive = true
	self.isDead = false
	$Brainy.Activate()
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	#$Collision_1.disabled = true
	#$Collision_1.hide()
	Build_Stat()
	show()
	
	set_collision_layer_value(1,true)
	$Vision.set_collision_mask_value(1,true)

	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))


	#$Collision_0.show()
	#$Collision_0.disabled = false	
	#$Dead_Sprite_0.hide()	
	#$Sprite_0.show()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	$Brainy.Desactivate()
	#Decomposition(1)
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
	life.cause_of_death = deathtype.EATEN


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
	$DebugLabel.show()
	Life.player.mouse_target = self

func _on_mouse_exited():
	$HP_bar.hide()
	$Energy_bar.hide()
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null


func _on_vision_body_entered(body):
	if body.species== "sheep":
		if body.current_life_cycle > 1 and self.current_life_cycle == 1:
			vision_array["food"].append(body)
		elif body.current_life_cycle == 1 and self.current_life_cycle == 0:
			vision_array["food"].append(body)
	if body.species== "jellybee" and self.current_life_cycle == 0:
			vision_array["food"].append(body)
	if body.species == "catronaute":
		if self.current_life_cycle == 1:
			vision_array["food"].append(body)
		else:
			#pass
			vision_array["danger"].append(body)

		#getAway(body.position)


func _on_vision_body_exited(body):
	for n in vision_array:
		if vision_array[n].has(body):
			vision_array[n].erase(body)


