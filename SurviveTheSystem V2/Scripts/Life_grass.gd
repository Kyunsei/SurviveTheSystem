extends LifeEntity

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script
#var thread: Thread

var current_time_speed = World.speed

func Build_Genome():
	Genome["maxPV"]=[10,10]
	Genome["soil_absorption"] = [2,2]
	Genome["lifespan"]=[20,20]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]


func Build_Phenotype(): #go to main
	#This function should be call when building the pool.
	
	# SPRITE
	$Sprite_0.texture = Genome["sprite"][0]
	$Sprite_0.offset.y = -$Sprite_0.texture.get_height()

	$Sprite_1.texture = Genome["sprite"][1]
	$Sprite_1.offset.y = -$Sprite_1.texture.get_height()
	$Sprite_1.hide()
	#TIMER
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
		
	#$Timer.start(randf_range(0,.25))
	#ADD vision
	$Vision/Collision.shape.radius = 150
	$Vision/Collision.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)

	#ADD Body
	$Body/Collision_0.shape.size = $Sprite_0.texture.get_size()
	$Body/Collision_0.position = Vector2(Life.life_size_unit/2,-$Sprite_0.texture.get_height()/2) #Vector2(width/2,-height/2)
	
	$Body/Collision_1.shape.size = $Sprite_1.texture.get_size()
	$Body/Collision_1.position = Vector2(Life.life_size_unit/2,-$Sprite_1.texture.get_height()/2) #Vector2(width/2,-height/2)
	$Body/Collision_1.hide()	
	
func Build_Stat():
	self.PV = Genome["maxPV"][0]
	self.current_life_cycle = 0
	self.PV = Genome["maxPV"][self.current_life_cycle]
	
	
func _ready():
	#pass
	#Activate()

	Build_Stat()
	Build_Genome()
	Build_Phenotype()
	hide() #pooling technique
	
	
	#get_parent().get_parent().world_speed_changed.connect(_world_speed_modified)



func _on_timer_timeout():
	if World.isReady and isActive:
		Absorb_soil_energy()
		Metabo_cost()	
		LifeDuplicate()
		Ageing()
		Growth()

		if self.energy <= 0 or self.age >= Genome["lifespan"][current_life_cycle] or self.PV <=0:
			Deactivate()
		
		if current_time_speed != World.speed:
			adapt_time_to_worldspeed()

		#Debug part
		$DebugLabel.text = str(current_life_cycle)



"resource_name"
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


#GROWTHING
func Growth():
	if current_life_cycle == 0:
		if self.age > 2 and self.energy > 2:
			self.current_life_cycle += 1
			
			$Body/Collision_0.hide()
			$Body/Collision_1.show()
			$Sprite_1.show()
			$Sprite_0.hide()
			


#Duplication
func LifeDuplicate():
	if current_life_cycle == 1 :
		if self.energy > 4:
			
			
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
			
			#Life.grass_pool Technique
			var li = Life.grass_pool_state.find(0)	
			if li > -1 and Life.plant_number + 500 < Life.grass_pool_state.size():
				self.energy -= 2
				Life.grass_pool_scene[li].Activate()
				Life.grass_pool_scene[li].energy = 2
				Life.grass_pool_scene[li].age = 0
				Life.grass_pool_scene[li].current_life_cycle = 0
				Life.grass_pool_scene[li].PV = Genome["maxPV"][0]

				Life.plant_number += 1
				Life.grass_pool_scene[li].global_position = PickRandomPlaceWithRange(position,2 * World.tile_size)
			else:
				print("pool empty")


			
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


func adapt_time_to_worldspeed():
	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))
	current_time_speed =  World.speed




func Activate():
	self.isActive = true
	Life.grass_pool_state[self.pool_index] = 1
	Build_Stat()
	#Build_Genome()
	show()

func Deactivate():

	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	
	Decomposition()
	self.isActive = false
	Life.grass_pool_state[self.pool_index] = 0
	#Life.inactive_grass.append(self)
	Life.plant_number -= 1

	#Build_Genome()
	Build_Stat()
	$Body/Collision_0.show()
	$Body/Collision_1.hide()

	$Sprite_1.hide()
	$Sprite_0.show()
	hide()



func _on_vision_area_entered(area):
	if area.get_parent().name == "Player":
		pass
		#$Sprite.modulate = Color(0, 0, 1)


func _on_vision_area_exited(area):
	if area.get_parent().name == "Player":
		pass
		#$Sprite.modulate = Color(1, 1, 1)
