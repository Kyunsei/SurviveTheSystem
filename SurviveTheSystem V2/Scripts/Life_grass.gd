extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script
#var thread: Thread

func Build_Genome():
	Genome["soil_absorption"] = [2]
	Genome["lifespan"]=[randi_range(20,40)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]
	Genome["sprite"] = [preload("res://Art/grass_2.png"),preload("res://Art/grass_2.png")]
func Build_Phenotype(): #go to main
	#global_position = Vector2(int(World.world_size*World.tile_size/2),int(World.world_size*World.tile_size/2))

	# SPRITE
	$Sprite.texture = Genome["sprite"][current_life_cycle]
	$Sprite.offset.y -= $Sprite.texture.get_height()
	
	#TIMER
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time/2))
		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/CollisionShape2D.shape.radius = 150
	$Vision/CollisionShape2D.position = Vector2(Life.life_size_unit/2,-$Sprite.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	$Body/CollisionShape2D.shape.size = $Sprite.texture.get_size()
	$Body/CollisionShape2D.position = Vector2(Life.life_size_unit/2,-$Sprite.texture.get_height()/2) #Vector2(width/2,-height/2)

	
func _ready():
	#pass
	#Activate()
	#hide()
	Build_Genome()
	Build_Phenotype()
	hide() #pooling technique
	#get_parent().get_parent().world_speed_changed.connect(_world_speed_modified)


#EAT soil
func Absorb_soil_energy():
	var x = int(position.x/World.tile_size)
	var	y = int(position.y/World.tile_size)
	var posindex = y*World.world_size + x
	if posindex < World.block_element_array.size():
		var soil_energy = World.block_element_array[posindex]	
		energy += min(Genome["soil_absorption"][current_life_cycle],soil_energy)
		World.block_element_array[posindex]	-= min(Genome["soil_absorption"][current_life_cycle],soil_energy)

#METABO cost
func Metabo_cost():

	#energy lost is returned to soil
	var x = int(position.x/World.tile_size)
	var	y = int(position.y/World.tile_size)
	var posindex = y*World.world_size + x
	#	posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
	#if posindex >= 0:
	if posindex < World.block_element_array.size():
		energy -= min(energy,metabolic_cost)
		World.block_element_array[posindex] += min(energy, metabolic_cost)
			
				
'	if parameters_array[INDEX*par_number+2] <= Genome[genome_index]["maxenergy"][current_cycle]:'

#Getting old
func Ageing():
	self.age +=1
	if self.age >= Genome["lifespan"][current_life_cycle]:
		Deactivate()


#Duplication
func LifeDuplicate():
	if current_life_cycle == 0 :
		if self.energy > 2:
			

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
			
			#Life.grass_pool
			var li = Life.grass_pool_state.find(0)	
			if li > -1 :
				self.energy -= 2
				Life.grass_pool_scene[li].Activate()
				Life.grass_pool_scene[li].energy = 2
				Life.plant_number += 1
				Life.grass_pool_scene[li].global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)

				#marche po car isactive est pas trouvé

			
func Decomposition():
	var x = int(position.x/World.tile_size)
	var	y = int(position.y/World.tile_size)
	var posindex = y*World.world_size + x
	#	posindex = min(World.block_element_array.size()-1,posindex)	#temp to fix edge bug
	#if posindex >= 0:
	if posindex < World.block_element_array.size():
		World.block_element_array[posindex] += self.energy
		energy = 0
		

func PickRandomPlaceWithRange(position,range):
	var random_x = randi_range(max(0,position.x-range),min((World.world_size)* World.tile_size ,position.x+range))
	var random_y = randi_range(max(0,position.y-range),min((World.world_size)* World.tile_size ,position.y+range))
	return Vector2(random_x, random_y)



func _world_speed_modified():
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time/2))


func _on_timer_timeout():
	if World.isReady and isActive:
		Absorb_soil_energy()
		Metabo_cost()	
		LifeDuplicate()
		Ageing()
		$Timer.wait_time = lifecycletime / World.speed
		
		#Debug part
		#$DebugLabel.text = str(energy)


func Activate():
	self.isActive = true
	Life.grass_pool_state[self.pool_index] = 1
	
	#Build_Genome()
	#Build_Phenotype()
	show()

func Deactivate():
	self.age = 0
	global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition()
	self.isActive = false
	Life.grass_pool_state[self.pool_index] = 0
	#Life.inactive_grass.append(self)
	Life.plant_number -= 1

	#Build_Genome()
	#Build_Phenotype()
	#hide()



func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		pass
		#$Sprite.modulate = Color(0, 0, 1)


func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		pass
		#$Sprite.modulate = Color(1, 1, 1)
