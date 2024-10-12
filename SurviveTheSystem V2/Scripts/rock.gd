extends LifeEntity


func _ready():
	Activate()

#var life_scene = load("res://Scenes/life_grass.tscn")
# Grass script

var species = "rock"

func Build_Genome():
	Genome["maxPV"]=[10,10,10]
	Genome["soil_absorption"] = [2,2,2]
	Genome["lifespan"]=[20,20,20]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/grass_1.png"),preload("res://Art/grass_2.png")]
	Genome["dead_sprite"] = [preload("res://Art/grass_dead.png")]

	
	
func Build_Stat():
	self.PV = 100000000000000000
	self.current_life_cycle = 0
	self.PV = 100000000000000000
	self.energy = 1
	self.lifespan = 2000000000000000000




##diying
#func Die():
	#self.isDead = true
	#if carried_by != null:
		#carried_by.item_array.erase(self)
		#self.carried_by = null
		#z_index = 0
	#$Dead_Sprite_0.show()
	#$Collision_1.disabled = true		
	#$Collision_0.disabled = false		
	#$Collision_0.show()
	#$Collision_1.hide()
	#$Sprite_1.hide()
	#$Sprite_0.hide()
	#


func Activate():
	self.isActive = true
	Build_Stat()
	set_collision_layer_value(1,1)
	#Build_Genome()
	show()
	#$Timer.wait_time = lifecycletime / World.speed
	#$Timer.start(randf_range(0,$Timer.wait_time))
	#self.size = get_node("Collision_0").shape.size

#func Deactivate():	
	##global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	#
	#Decomposition()
	#$Timer.stop()
	#set_collision_layer_value(1,0)
	#self.isActive = false
	#Life.grass_pool_state[self.pool_index] = 0
	##Life.inactive_grass.append(self)
	#Life.plant_number -= 1
#
#
#
	##prepare for new instance
	#self.isDead = false
	##No need to change collision as Die did it
	##$Body_0/Collision_0.show()
	##$Body_1/Collision_1.hide()
	##$Body_1/Collision_1.disabled = true		
	##$Body_0/Collision_0.disabled = false	
	#
	#$Sprite_1.hide()
	#$Dead_Sprite_0.hide()
	#$Sprite_0.show()
	#hide()
#
#
