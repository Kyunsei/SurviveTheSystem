extends LifeEntity


# sheep script
var species = "jellybee"
var haspollen = 0

var berry_nest: LifeEntity

var berry_nest_array = []
var duplicate_timer = 0

var vision_array = {
	"food": [],
	"danger": [],
	"friend": [],
	"enemy": [],
	"nest": []
}


var jelly_color = Color(randf_range(0,1),randf_range(0,1),randf_range(0,1),1) 
var hive = null

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var input_dir = Vector2(0,0)


func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	pass

func Build_Stat():
	self.current_life_cycle = 0
	self.maxPV = 10
	self.PV = 10
	self.energy = 5
	self.maxEnergy = 15
	self.maxSpeed = 300
	self.lifespan = 10*(90/10)
	self.age= 0
	$Sprite_0.modulate = jelly_color
	metabolic_cost = 1

func _physics_process(delta):
	if isPlayer:
		input_dir = Player_Control_movement()	


		
	var collision = move_and_collide(velocity *delta)	
	global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
	global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
	if item_array.size() > 0:
		for i in item_array:
			i.position = position+Vector2(0,-32)	
		
func _on_timer_timeout():
	
	if World.isReady and isActive:
		if $Timer.wait_time != lifecycletime / World.speed:
			$Timer.wait_time = lifecycletime / World.speed
		if isDead == false:
			
		
			
			Metabo_cost(metabolic_cost)
			LifeDuplicate()
			Ageing()
			spwan_pollen()
			#Growth()
			#AdjustDirection()
			duplicate_timer += 1
			if self.energy <= 0 or self.age >= lifespan or self.PV <=0:

				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		$DebugLabel.text = str(age) + " " + str(energy)
	if not berry_nest or berry_nest.current_life_cycle != 3 :
		find_new_nest()
		print("No nest")
	if isNestOvercrowded(berry_nest):
		print("Too much medusa")
		find_new_nest()

func isNestOvercrowded(berry_nest):
	var population = 0
	if berry_nest:
		for f in vision_array["friend"]:
			if f.berry_nest:
				if f.berry_nest == berry_nest:
					population += 1
	if population > 2:
		return true
	else:
		return false
					
				

func find_new_nest():
	var potential_nest_array = vision_array["nest"].filter(func(obj): return obj.current_life_cycle == 3)
	if berry_nest:
		if potential_nest_array.has(berry_nest):
			potential_nest_array.erase(berry_nest)
	var random_id = randi_range(0,potential_nest_array.size()-1)
	if potential_nest_array.size() > 0:
		berry_nest = potential_nest_array[random_id]
		$Brainy/idle_state.nest = berry_nest	
		berry_nest.current_sprite.modulate = Color(0,1,0)

	#for n in range(5):
		#if potential_nest_array.size() > 0:
			#var potential_berry_nest = getClosestLife(potential_nest_array, 1000000.0)
			#if potential_berry_nest:
				#if isNestOvercrowded(potential_berry_nest):
					#potential_nest_array.erase(potential_berry_nest)
				#else:
					#berry_nest = potential_berry_nest
					#$Brainy/idle_state.nest = berry_nest	
					#berry_nest.current_sprite.modulate = Color(0,1,0)
					#return
		#else:
			#return
			
		


func spwan_pollen():
	#generate new grass
	var posindex = int(position.y/World.tile_size) * World.world_size  +  int(position.x/World.tile_size)
	if haspollen > 0 and World.block_element_state[posindex] > 0:
		var life = Life.build_life("spiky_grass", position)
		haspollen -= 1
		pass
		'var life = Life.build_life("spiky_grass")
		if life != null:
			life.energy = 2
			var newpos = position
			life.global_position = newpos# Vector2(randi_range(0,World.tile_size*World.world_size),randi_range(0,World.tile_size*World.world_size))
			energy -= 2'
	pass

#diying
func Die():
	$Brainy.Desactivate()
	for i in item_array:
		i.carried_by = null
		i.z_index = 0
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	item_array = []

	
	
	self.isDead = true
	Update_sprite($Dead_Sprite_0)

	

#GROWTHING
func Growth():
	if current_life_cycle == 0:
		pass
			





#Duplication
func LifeDuplicate():
	

	if self.age > 5 and self.energy > 10 and duplicate_timer >= 6 and berry_nest:

		#Lpool Technique
			var life = Life.build_life(species)
			if life != null:
					self.energy -= 5
					life.energy = 5
					life.jelly_color = jelly_color
					life.global_position = PickRandomPlaceWithRange(position,1 * World.tile_size, true)
					self.maxEnergy -= 5
					duplicate_timer = 0
			else:
					print("jellypool_pool empty")
			

		


func angry_mode_on(target):
	if vision_array['danger'].has(target) == false:
		vision_array['danger'].append(target)
		for f in vision_array['friend']:
			f.vision_array['danger'] = vision_array['danger'].duplicate()

func getDamaged(value,antagonist:LifeEntity=null):
	pass
	#if InvicibilityTime == 0:
		#getPushed(antagonist,push_distance)
		#self.PV -= value
		#if self.PV <= 0:
			#Die()
		#InvicibilityTime = 1 
		#modulate = Color(1, 0.2, 0.2)
		#await get_tree().create_timer(0.5).timeout
		#InvicibilityTime = 0
		#modulate = Color(1, 1, 1)
#
	#if self.has_node("HP_bar"):
#
		#self.AdjustBar()
		#self.get_node("HP_bar").show()

func Activate():
	#set_physics_process(true)
	self.isActive = true
	self.isDead = false
	set_physics_process(true)
	Life.pool_state[species][pool_index] = 1
	Life.life_number[species] += 1
	Build_Stat()
	#Build_Genome()
	show()
	set_collision_layer_value(1,true)
	$Vision.set_collision_mask_value(1,true)
	$Vision_close.set_collision_mask_value(1,true)
	$Timer.wait_time = lifecycletime / World.speed
	#$Timer.start()
	#$Timer.time_left = randf_range(0,$Timer.wait_time)
	$Timer.start(randf_range(0,$Timer.wait_time))
	$Vision/Collision.disabled = false
	$Vision_close/Collision.disabled = false
	Update_sprite($Sprite_0,$Collision_0)
	$Brainy.Activate()

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	set_physics_process(false)
	#Decomposition(0)
	set_collision_layer_value(1,false)
	$Vision.set_collision_mask_value(1,false)
	$Vision_close.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	#Life.jellybee_pool_state[self.pool_index] = 0
	$Vision/Collision.disabled = true
	$Vision_close/Collision.disabled = true
	$Collision_0.disabled = true
	$Brainy.Desactivate()
	#Life.sheep_number -= 1
	#prepare for new instance

	#Build_Stat()	
	#No need to change collision as Die did it
	#$Body_0/Collision_0.show()
	#$Body_1/Collision_1.hide()
	#$Body_1/Collision_1.disabled = true		
	#$Body_0/Collision_0.disabled = false	
	

	hide()

func Eat(life):
	#print("Eaten")
	var value = max(0,min(life.energy-5, 5))
	self.energy += value
	life.energy -=  value
	haspollen += 1
	if life.current_life_cycle <= 2 and  life.energy <= 5:
		life.current_life_cycle = 1
		life.Update_sprite(life.get_node("Sprite_1"),life.get_node("Collision_1"))
		if vision_array["food"].has(life):
			vision_array["food"].erase(life)
	

	#life.Die()
	#$DebugLabel.text = str(age) + " " + str(energy)



func _on_vision_body_entered(body):

		if body.species== "spiky_grass" and body.current_life_cycle == 2:
			if body.energy > 5:
				vision_array['food'].append(body)

	
				
				
		if body.species== "berry" and body.current_life_cycle == 3:
				self.vision_array['nest'].append(body)
				
		if body.species== "catronaute":
			vision_array['enemy'].append(body)
		#getAway(body.position)





func _on_vision_body_exited(body):

	for n in vision_array:
		if vision_array[n].has(body):
			vision_array[n].erase(body)
	
	if berry_nest == body:
		if body.current_life_cycle != 3 or body.isDead== true:
				berry_nest = null
				$Brainy/idle_state.nest = null
				var potential_nest = vision_array["nest"].filter(func(obj): return obj.current_life_cycle == 3)
				if potential_nest.size() > 0:
					berry_nest = getClosestLife(potential_nest, 1000000.0)
					$Brainy/idle_state.nest = berry_nest	
	
			


func _on_action_timer_timeout():
	action_finished = true


'func _on_mouse_entered():
	$DebugLabel.show()
	Life.player.mouse_target = self



func _on_mouse_exited():
	$DebugLabel.hide()
	if Life.player.mouse_target == self:
		Life.player.mouse_target = null'


func _on_vision_close_body_entered(body):
	if body.species== "jellybee" and body!= self:
		vision_array['friend'].append(body) # Replace with function body.


func _on_vision_close_body_exited(body):
		if vision_array["friend"].has(body):
			vision_array["friend"].erase(body)
