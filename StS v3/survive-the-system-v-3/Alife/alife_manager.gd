extends Node3D

@export var World : Node3D
@export var player_scene: PackedScene
@export var plant_scene: PackedScene
@export var sheep_scene: PackedScene
@export var tree_scene: PackedScene


#
var IsInit = false

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


var tempbool = true

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
#NOW doing something else, Do matrix things on CPU and use multimesh to render very numerous entities (grass) 
#and probably but the loop on a thread
#USE DICTIONARY structure currently, but for more optimisation should be replaced by array -ECS system


func init():
			$Grass_Manager.World = World
			$beast_manager.World = World
			$Grass_Manager.ask_for_spawn_grass(Vector3(25,0,-15),Alifedata.enum_speciesID.GRASS)

			$Grass_Manager.ask_for_spawn_grass(Vector3(-15,0,-15),Alifedata.enum_speciesID.GRASS)
			$Grass_Manager.ask_for_spawn_grass(Vector3(15,0,15),Alifedata.enum_speciesID.TREE)
			$Grass_Manager.ask_for_spawn_grass(Vector3(0,0,15),Alifedata.enum_speciesID.BUSH)
			$beast_manager.Spawn_Beast(Vector3(-10,0,-15),Alifedata.enum_speciesID.SHEEP)


func _process(delta: float) -> void:

	if GlobalSimulationParameter.SimulationStarted: 
		if multiplayer.is_server():
			if ! IsInit:
				init()
				IsInit = true
			timer -= delta
			if timer < 0:
				GlobalSimulationParameter.sheep_number_data.append(current_life_count_by_species[1])
				GlobalSimulationParameter.grass_number_data.append($Grass_Manager.grass_dict.size())
				GlobalSimulationParameter.tree_number_data.append(current_life_count_by_species[2])


				timer = 3
			pass
			$Grass_Manager.update()
			$beast_manager.update()
			
	elif GlobalSimulationParameter.ClientStarted:
		if tempbool:
			$Grass_Manager.draw_multimesh_on_client.rpc_id(1,multiplayer.get_unique_id())
			tempbool = false
		






################################ BIN GESTION

func put_in_world_bin(g):
	var bin_ID = 0
	var w_pos = World.get_PositionInGrid(g["position"],World.bin_size)
	#var w_pos = World.get_PositionInGrid(g.position,World.bin_size)

	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	if new_bin_ID < 0 or new_bin_ID >= World.bin_array.size():
		print("life out of world")
		remove_from_world_bin(g)
		return
	if bin_ID != new_bin_ID:
		remove_from_world_bin(g)
		#g["bin_ID"] = new_bin_ID
	if World.bin_array[new_bin_ID] == null:
		World.bin_array[new_bin_ID] = [g]
		World.bin_sum_array[g["Species"]][new_bin_ID] += 1
	else:	
		World.bin_array[new_bin_ID].append(g) 
		World.bin_sum_array[g["Species"]][new_bin_ID] += 1

	g["bin_ID"] = new_bin_ID
	#g.bin_ID = new_bin_ID

func remove_from_world_bin(g):
	if g["bin_ID"]:
		if World.bin_array[g["bin_ID"]].has(g):
			World.bin_array[g["bin_ID"]].erase(g)
			World.bin_sum_array[g["Species"]][g["bin_ID"]] -= 1

			g["bin_ID"] = null








##################################################################
#OLD
###################################################################

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
func spawn_player(id,pos):
	pass
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	new_player.World = World
	var alifedata = Alifedata.new()
	var new_life_data = alifedata.build_lifedata(id,pos,Alifedata.enum_speciesID.CAT)
	new_player.lifedata = new_life_data
	put_in_world_bin(new_life_data)	
	self.call_deferred("add_child",new_player)

	
	
	
	
	
	

func get_alife_in_area(pos_center, area):
	var results: Array = []
	var min_pos = pos_center - area
	var max_pos = pos_center + area
	var min_grid: Vector3i = World.get_PositionInGrid(min_pos, World.bin_size)
	var max_grid: Vector3i = World.get_PositionInGrid(max_pos, World.bin_size)
		
	for x in range(min_grid.x, max_grid.x + 1):
			for y in range(min_grid.y, max_grid.y + 1):
				for z in range(min_grid.z, max_grid.z + 1):

					if not World.is_valid_bin(x, y, z,World.bin_size):
						continue

					var index: int = World.index_3dto1d(x, y, z, World.bin_size)
			

					var bin = World.bin_array[index]
					if bin:
						for element in bin:
							print(element["Species"])
							if element is Dictionary:
								var p: Vector3 = element["position"]#.global_position

								# Precise AABB check (important!)
								if p.x >= min_pos.x and p.x <= max_pos.x \
								and p.y >= min_pos.y and p.y <= max_pos.y \
								and p.z >= min_pos.z and p.z <= max_pos.z:
									results.append(element)

	return results

	

	

	
 
