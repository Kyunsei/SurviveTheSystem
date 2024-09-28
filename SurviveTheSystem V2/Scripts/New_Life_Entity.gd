extends CharacterBody2D
class_name LifeEntity


#OPTIMISATION CPU PERFORMANCE
var isActive = false
var pool_index = 0


#PHYSIC LAW
var lifecycletime = 5. #30. #in second
var current_time_speed = World.speed

#LifeRule
var isDead = false

#control
var isPlayer = false
var action_finished = true

#INVENTAIRE
var item_array = []
var carried_by = null
var direction = Vector2(0,0)

#Internal parameters
var maxPV = 10
var maxEnergy = 100
var maxSpeed = 0


#Genome parameters
var Genome = {
	"maxPV": [0],
	"sprite": [0]
}



#Inter parameters
var energy = 0  #current level of energy/hunger
var age = 0 #current age
var size = Vector2(0,0) #size from sprite
var PV = 0 #current level of health
var current_life_cycle = 0 #which state of life it is. egg, young, adult, etc..
var metabolic_cost = 1 #how much energy is consumed by cycle to keep biological function

func _ready():
	set_physics_process(false)
	Build_Stat()
	Build_Genome()
	Build_Phenotype()
	hide() #pooling technique
	

func Build_Stat():
	self.PV = Genome["maxPV"][0]
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	

func Build_Genome():
	#This function should be customised
	pass

func Build_Phenotype(): #go to main
	#This function should be customised
	pass



func _on_timer_timeout():
	if World.isReady and isActive:
		if isDead == false:
			
			Absorb_soil_energy(0)
			Metabo_cost()	
			LifeDuplicate()
			Ageing()
			Growth()
			if self.energy <= 0 or self.age >= Genome["lifespan"][current_life_cycle] or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

func Player_Control_movement():
		var input_dir = Vector2.ZERO
		var rotation_dir = 0
		if Input.is_action_pressed("left") :
			input_dir.x -= 1
			rotation_dir = -1	
		if Input.is_action_pressed("right"):
			input_dir.x += 1
			rotation_dir = 1
		if Input.is_action_pressed("up"):
			input_dir.y -= 1
			rotation_dir = -1
		if Input.is_action_pressed("down"):
			input_dir.y += 1
			rotation_dir = 1
				
		velocity = input_dir.normalized() * self.maxSpeed


		position.x = clamp(position.x, 0, World.world_size*World.tile_size)
		position.y = clamp(position.y, 0, World.world_size*World.tile_size)
		return input_dir
		
func _physics_process(delta):
	if isPlayer:
		Player_Control_movement()	
	move_and_collide(velocity *delta)

	
func getPickUP(transporter):
	if self.carried_by != null:
		carried_by.item_array.erase(self)
	self.carried_by = transporter
	transporter.item_array.append(self)
	#seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)


#####################################################3MOVMENT script


func AdjustDirection():
	if action_finished == true:
		direction.x = randi_range(-1,1)
		direction.y = randi_range(-1,1)
		velocity = direction * self.maxSpeed * 0.5
		action_finished = false
		$ActionTimer.start(0.5)
		$DebugLabel.text = "Idle"



func getCloser(target):
	var center = position + Vector2(32,-32) #temporaire
	direction = -(center - target).normalized()
	velocity = direction * Genome["speed"][self.current_life_cycle]
	#$DebugLabel.text = "feeding"
	

func goToMiddle(life_array):
	if action_finished == true:
		var sum = Vector2(0,0)
		for l in life_array:
			sum += l.position
		var middle_pos = sum/life_array.size()
		getCloser(middle_pos + Vector2(randf_range(-16,16),randf_range(-16,16)))
		action_finished = false
		$ActionTimer.start(0.5)
 
func getAway(target):
	if action_finished == true:
		direction = (position - target).normalized()
		velocity = direction * 400  # Genome["speed"][self.current_life_cycle] *2
		action_finished = false
		$DebugLabel.text = "avoid"
		$ActionTimer.start(0.5)

##################################

func getClosestLife(array,minDist):
	var closest_entity = null
	var min_distance = minDist
	var calc_distance = 0
	for p in array:
		calc_distance = position.distance_to(p.position)
		if calc_distance <= min_distance:
			min_distance = calc_distance
			closest_entity = p
	return closest_entity

#METABO cost
func Metabo_cost():
	#energy lost is returned to soil
	#var middle = position + Vector2(size.x/2,-size.y/2)
	var middle = position + Vector2(size.x/2,0)#-size.y/2)
	var x = int(middle.x/World.tile_size)
	var	y = int(middle.y/World.tile_size)

	var posindex = y*World.world_size + x
	#	posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
	#if posindex >= 0:
	if posindex < World.block_element_array.size():
		World.block_element_array[posindex] += min(energy, metabolic_cost)
		energy -= min(energy,metabolic_cost)
#Getting old
func Ageing():
	self.age +=1
	
#diying
func Die():
	self.isDead = true
	pass
	#NEED to be customized
	
#EAT soil
'func Absorb_soil_energy():
	var middle = position + Vector2(size.x/2,-size.y/2)
	var x = int(middle.x/World.tile_size)
	var	y = int(middle.y/World.tile_size)
	var posindex = y*World.world_size + x
	if posindex < World.block_element_array.size():
		var soil_energy = World.block_element_array[posindex]	
		energy += min(Genome["soil_absorption"][current_life_cycle],soil_energy)
		World.block_element_array[posindex]	-= min(Genome["soil_absorption"][current_life_cycle],soil_energy)
'
func Absorb_soil_energy(radius):
	var middle = position + Vector2(size.x/2,0)#-size.y/2)
	var center_x = int(middle.x/World.tile_size)
	var	center_y = int(middle.y/World.tile_size)
	for x in range(center_x - radius, center_x + radius + 1):
		for y in range(center_y - radius, center_y + radius + 1):
			if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
				var posindex = y*World.world_size + x
				if posindex < World.block_element_array.size():
					var soil_energy = World.block_element_array[posindex]	
					energy += min(Genome["soil_absorption"][1],soil_energy)
					World.block_element_array[posindex]	-= min(Genome["soil_absorption"][1],soil_energy)


#GROWTHING
func Growth():
	pass
	#NEED to be customized

#Duplication
func LifeDuplicate():
	pass
	#NEED to be customized
			
	
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

			
func Decomposition():
	var middle = position + Vector2(size.x/2,0)#-size.y/2)
	var x = int(middle.x/World.tile_size)
	var	y = int(middle.y/World.tile_size)
	var posindex = y*World.world_size + x
	#	posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
	#if posindex >= 0:
	if posindex < World.block_element_array.size():
		World.block_element_array[posindex] += self.energy
		energy = 0

func AdjustBar():
	$HP_bar.value = self.PV *100 / self.maxPV 
	$Energy_bar.value = self.energy *100 / self.maxPV


var InvicibilityTime = 0

func getDamaged(value):
	if InvicibilityTime == 0:
		self.PV -= value
		InvicibilityTime = 1 
		modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.5).timeout
		InvicibilityTime = 0
		modulate = Color(1, 1, 1)

	if self.has_node("HP_bar"):

		self.AdjustBar()
		self.get_node("HP_bar").show()
	if self.PV <= 0:
		Die()
		#position -= Vector2(-10,0)

func Activate():
	self.isActive = true
	Life.grass_pool_state[self.pool_index] = 1 #HERE
	Build_Stat()
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition()
	$Timer.stop()
	self.isActive = false
	Life.grass_pool_state[self.pool_index] = 0 #HERE
	#Life.inactive_grass.append(self)
	Life.plant_number -= 1 #HERE


	#prepare for new instance
	self.isDead = false
	Build_Stat()	
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	
	$Sprite_1.hide()
	$Dead_Sprite_0.hide()
	$Sprite_0.show()
	hide()







func PickRandomPlaceWithRange(position,range):
	var random_x = randi_range(max(0,position.x-range),min((World.world_size)* World.tile_size ,position.x+range))
	var random_y = randi_range(max(0,position.y-range),min((World.world_size)* World.tile_size ,position.y+range))
	return Vector2(random_x, random_y)


func adapt_time_to_worldspeed():
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	current_time_speed =  World.speed
		


func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		print("player_close")


func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		print("player_leaving")

