extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "stingtree"

var isOnTree = false
var hasFruit = false
var contact_array = []
var mother_tree = null
var fruits_array = []


func Build_Genome():
	Genome["maxPV"]=[10,10,15,20]
	Genome["soil_absorption"] = [0,2,4,6]
	Genome["lifespan"]=[20000,200,200,200]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/berry_1.png"),preload("res://Art/berry_3.png"),preload("res://Art/berry_4.png"),preload("res://Art/berry_5.png")]
	Genome["dead_sprite"] = [preload("res://Art/berry_dead.png")]

func Build_Phenotype():
	#This function should be call when building the pool.
	
	# SPRITE
	
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()
	$Sprite_0_in_tree.offset.y = -$Sprite_0_in_tree.texture.get_height()
	$Sprite_0_in_tree.hide()

	$Sprite_1.offset.y = -$Sprite_1.texture.get_height()
	#$Sprite_1.offset.x = $Sprite_1.texture.get_width()/2
	$Sprite_1.hide()
	

	$Sprite_2.offset.y = -$Sprite_2.texture.get_height()
	$Sprite_2.offset.x = -Life.life_size_unit/($Sprite_2.texture.get_width()/Life.life_size_unit)
	$Sprite_2.hide()
	

	$Sprite_3.offset.y = -$Sprite_3.texture.get_height()
	$Sprite_3.offset.x = -$Sprite_3.texture.get_width()/2.5
	$Sprite_3.hide()

		
	#ADD vision
	$Vision/Collision.shape.radius = 32/2
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	#$Body_0/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	#$Body_1/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_2.texture.get_height()/2) #Vector2(width/2,-height/2)
	#$Collision_2.position = Vector2(Life.life_size_unit/2,-$Sprite_2.texture.get_height()/2) #Vector2(width/2,-height/2)
	#$Collision_3.position = Vector2(Life.life_size_unit/2,-$Sprite_3.texture.get_height()/2) #Vector2(width/2,-height/2)

	
	$Collision_1.hide()
	$Collision_1.disabled = true	

	
func Build_Stat():
	self.PV = Genome["maxPV"][0]
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	self.energy = 1
	metabolic_cost = 1 
func _on_timer_timeout():
	if $Timer.wait_time != lifecycletime / World.speed:
		$Timer.wait_time = lifecycletime / World.speed
	if World.isReady and isActive:
		if isDead == false:
			if carried_by == null:
				if isOnTree == false:
					Metabo_cost(metabolic_cost)	
					Absorb_soil_energy(2,min(4,self.current_life_cycle))
			
					LifeDuplicate()
					Ageing()
					Growth()

				if self.energy <= 0 or self.age >= Genome["lifespan"][0] or self.PV <=0:
					Die()
				
				if current_time_speed != World.speed:
					adapt_time_to_worldspeed()
		else:
			Deactivate()

		#Debug part
		#$DebugLabel.text = str(self.energy) + " " + str(self.current_life_cycle)


#EAT soil


#diying
func Die():
	self.isDead = true
	if carried_by != null:
		carried_by.item_array.erase(self)
		self.carried_by = null
		z_index = 0
	for f in fruits_array:
		f.fall()
	
	#$Dead_Sprite_0.show()
	$Collision_1.disabled = true			
	$Collision_0.disabled = false		
	$Collision_0.show()
	$Collision_1.hide()
	$Sprite_1.hide()
	$Sprite_0.hide()
	$Sprite_2.hide()
	$Sprite_3.hide()
	

#GROWTHING
func Growth():
	var growth_function = self.current_life_cycle*5 + 2
	if self.age % 5 == 0 and self.energy > growth_function:
		self.current_life_cycle += 1
		if self.current_life_cycle == 2:
			get_node("Collision_1").show()
			get_node("Collision_0").hide()
			get_node("Collision_1").disabled = false
			get_node("Collision_0").disabled = true	
			self.size = get_node("Collision_1").shape.size
			self.maxPV += 5
			self.PV += 5
		if self.current_life_cycle < 4:
			get_node("Sprite_"+str(self.current_life_cycle)).show()
			get_node("Sprite_"+str(self.current_life_cycle-1)).hide()
			self.maxPV += 5
			self.PV += 5
		else:
			$Sprite_3.scale += Vector2(0.2,0.2)
			var tree_middle_leaf_height = ($Sprite_3.texture.get_height() -  $Sprite_3/fruitplace.get_size().y/2 )* $Sprite_3.scale.y
			for f in fruits_array:
				#f.position.x += 
				f.position.y -= 192*0.2

				f.get_node("Vision").position.y += 192*0.2


#Duplication
func LifeDuplicate():
	if hasFruit == false:
		
		if self.energy > 40 and self.age > 10 and self.current_life_cycle > 2 and hasFruit == false:
					
			#Life.grass_pool Technique

			#+ Life.grass_pool_state.size()*0.05
			var number = randi_range(30,40)
			for i in range(0,number):
				var li = Life.build_life("stingtree")	
				if li :
					
					hasFruit = true

					li.Activate()
					li.energy = 1
					li.age = 0
					li.current_life_cycle = 0
					li.PV = Genome["maxPV"][0]
					li.start_as_fruit(self)
					#Life.stingtree_pool_scene[li].global_position = PickRandomPlaceWithRange(position,8 * World.tile_size)
					

					self.energy -= 1

				

				else:
					print("pool empty")


func start_as_fruit(mother_tree):
	self.mother_tree = mother_tree
	mother_tree.fruits_array.append(self)
	$Sprite_0.hide()
	$Sprite_0_in_tree.show()
	var mother_tree_size = $Sprite_3/fruitplace.get_size() * scale
	
	#var tree_height =  $Sprite_3.get_height()* scales
	#var tree_middle_leaf_height = ($Sprite_3.texture.get_height() -  $Sprite_3/fruitplace.get_size().y/2 )* scale.y
	#var tree_width =  int($Sprite_3.texture.get_width()* scale.x /2)
	var minx = int(mother_tree.position.x - $Sprite_3.texture.get_width()* mother_tree.get_node("Sprite_3").scale.x /2)
	var maxx = int(mother_tree.position.x + $Sprite_3.texture.get_width()* mother_tree.get_node("Sprite_3").scale.x /2)
	var miny = int(mother_tree.position.y - ($Sprite_3.texture.get_height() - $Sprite_3/fruitplace.get_size().y)* mother_tree.get_node("Sprite_3").scale.y)
	var maxy =int(mother_tree.position.y - $Sprite_3.texture.get_height()* mother_tree.get_node("Sprite_3").scale.y)
	var random_x = randi_range(max(0,minx),min((World.world_size)* World.tile_size ,maxx))
	var random_y = randi_range(max(0,miny),min((World.world_size)* World.tile_size ,maxy))
	global_position = Vector2(random_x, random_y)
	#global_position = PickRandomPlaceWithRange(mother_tree.position,tree_width) - Vector2(0,tree_middle_leaf_height)
	z_index = 1
	var tree_middle_leaf_height = ($Sprite_3.texture.get_height() -  $Sprite_3/fruitplace.get_size().y/2 )* mother_tree.get_node("Sprite_3").scale.y
	$Vision.position += Vector2(0,tree_middle_leaf_height)
	$Fruit_Timer.start(randf_range(10,11))
	isOnTree = true

func fall():
	if mother_tree != null:
		#var tree_height = 64 * (mother_tree.current_life_cycle-2)
		var tree_middle_leaf_height = ($Sprite_3.texture.get_height() -  $Sprite_3/fruitplace.get_size().y/2 )* mother_tree.get_node("Sprite_3").scale.y
		#$Vision.position -= Vector2(0,tree_middle_leaf_height)
		$Sprite_0.show()
		$Sprite_0_in_tree.hide()
		#$Vision.position -= Vector2(0,tree_height)


		mother_tree.hasFruit = false
		mother_tree.fruits_array.erase(self)
		mother_tree = null
		z_index = 0
		global_position += Vector2(0,tree_middle_leaf_height)
		$Vision.position = Vector2(0,0)
		for l in contact_array:
			l.getDamaged(10)


func Activate():
	self.isActive = true
	Life.pool_state[species][pool_index] = 0
	Life.life_number[species] -= 1
	Build_Stat()
	set_collision_layer_value(1,1)
	$Vision.set_collision_mask_value(1,true)
	#Build_Genome()
	show()
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	
	self.size = get_node("Collision_0").shape.size

func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition(1)
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
	$Sprite_0.show()
	hide()




func _on_vision_body_entered(body):
	if body.species != "stingtree":
		contact_array.append(body)


		#getAway(body.position)





func _on_vision_body_exited(body):	
	if body.species != "stingtree":
		contact_array.erase(body)






func _on_fruit_timer_timeout():
	isOnTree = false 
	fall()

