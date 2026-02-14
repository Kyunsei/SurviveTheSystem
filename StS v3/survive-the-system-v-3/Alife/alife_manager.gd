extends Node3D

@export var World : Node3D
@export var player_scene: PackedScene
@export var plant_scene: PackedScene
@export var sheep_scene: PackedScene
@export var tree_scene: PackedScene


#POOL SYSTEM
var current_life_number = 0
var max_life = 40000
var life_pool = []
var life_pool_index = 0
var life_inactive_index =[]
var life_no_pool_index = 0

var current_life_count_by_species = [0,0,0]


#DATA
var timer = 1

#OLD
var plant_array = []
var plant_energy = []
var plant_age = []
var index_plant = 0
var max_plant  = 10000

#three choice
#1. all alife is instatiate individually
#Pro: easy to do,cons: hard to optimise
#2. alife are in a common matrix and use GPU or renderig server for visual (disconnected
#pro: optimisation possible,  cons: difficult to have heterogeinity bc everything in same matrixx
#3. hybrid... need to identifiy where to parallelise and where to not!

#START WITH 1) because not a lot of time until demo in March

func _ready() -> void:
	$Metabolism.World = World
	#set_multiplayer_authority(1)


func _process(delta: float) -> void:
	if multiplayer.is_server():
		timer -= delta
		if timer < 0:
			GlobalSimulationParameter.sheep_number_data.append(current_life_count_by_species[1])
			GlobalSimulationParameter.grass_number_data.append(current_life_count_by_species[0])
			timer = 5
		pass
		#$Metabolism.Update()


func duplicate_life(alife):
	var newpos = alife.global_position + Vector3(randf_range(-5,5),0,randf_range(-5,5))
	Spawn_life.rpc_id(1,newpos,plant_scene)

	
'@rpc("any_peer","call_local")
func spawn_life(pos,scene):
	var new_life = plant_scene.instantiate()
	new_life.position = pos
	new_life.World = World
	plant_array.append(new_life)
	plant_age.append(0)
	plant_energy.append(0)
	new_life.name = str(index_plant)
	index_plant +=1
	self.call_deferred("add_child",new_life)'

@rpc("any_peer","call_local")
func Spawn_life(new_position: Vector3,alife_type:String):
	var newlife : Alife
	var alife_scene : PackedScene
	if alife_type == "grass":
		alife_scene = plant_scene
	elif alife_type == "sheep":
		alife_scene = sheep_scene
	elif alife_type == "tree":
		alife_scene = tree_scene
	if current_life_number >= max_life:
		return
	#print(current_alife_number)
	if life_pool.size() < max_life:
		newlife = alife_scene.instantiate()
		newlife.ID = life_pool_index
		newlife.LifeManager = self
		newlife.World = World
		newlife.name = str(life_pool_index)
		newlife.reproduction_asked.connect(Spawn_life)
		newlife.desactivated.connect(on_desactivation)
		add_child.call_deferred(newlife)	
		life_pool.append(newlife)
		life_pool_index +=1
		#newlife.Activate()
	else:
		newlife = get_desactivated_life()
		if newlife == null:
			return
		#nal.ID = life_ID_count
		#life_ID_count += 1
		
	#position.x = clamp(position.x,0 ,%World.World_size*%World.tile_size)
	#position.y = clamp(position.y,0 ,%World.World_size*%World.tile_size)
	'if position.x <0 or position.x > %World.World_size*%World.tile_size:		
		position = %World.wrap_around(position)
	if position.y <0 or position.y > %World.World_size*%World.tile_size:		
		position = %World.wrap_around(position)'
	current_life_number += 1
	newlife.position = new_position #- Vector2(nal.size/2,nal.size/2)
	if newlife.species =="grass":
		current_life_count_by_species[0] += 1
	if newlife.species =="sheep":
		current_life_count_by_species[1] += 1
	newlife.Activate()

@rpc("any_peer","call_local")
func Spawn_life_without_pool(new_position: Vector3,alife_type:String):
	var newlife : Alife
	var alife_scene : PackedScene
	if alife_type == "grass":
		alife_scene = plant_scene
	elif alife_type == "sheep":
		alife_scene = sheep_scene
	elif alife_type == "tree":
		alife_scene = tree_scene

	newlife = alife_scene.instantiate()
	newlife.ID = life_no_pool_index
	newlife.LifeManager = self
	newlife.World = World
	newlife.name = "noPool_" + str(life_no_pool_index)
	newlife.reproduction_asked.connect(Spawn_life)
	#newlife.desactivated.connect(on_desactivation)
	add_child.call_deferred(newlife)	
	#life_pool.append(newlife)
	life_no_pool_index +=1

	#current_life_number += 1
	newlife.position = new_position #- Vector2(nal.size/2,nal.size/2)
	newlife.Activate()
	if newlife.species =="grass":
		current_life_count_by_species[0] += 1
	if newlife.species =="sheep":
		current_life_count_by_species[1] += 1
	if newlife.species =="tree":
		current_life_count_by_species[2] += 1
func on_desactivation(life):
	current_life_number -= 1
	if life.species =="grass":
		current_life_count_by_species[0] -= 1
	if life.species =="sheep":
		current_life_count_by_species[1] -= 1
	if life.species =="tree":
		current_life_count_by_species[2] -= 1	
func get_desactivated_life():
	var idx = life_inactive_index.pop_back()  
	return life_pool[idx]
	'for a in life_inactive_index:
		if a.isActive == false:
			return a'
	



	


@rpc("any_peer","call_local")
func spawn_player(id):
	pass
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	new_player.World = World

	self.call_deferred("add_child",new_player)
	#if id == multiplayer.get_unique_id():
	#new_player.set_multiplayer_authority(id)

func get_alife_in_area(pos, area):
	var w_pos = World.get_PositionInGrid(pos,World.bin_size)
	var w_index = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	return World.bin_array[w_index]
	

	
 
