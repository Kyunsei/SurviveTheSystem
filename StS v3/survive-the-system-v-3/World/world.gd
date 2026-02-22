extends Node3D

#WORLD SETUP
var World_Size = Vector3(250,1,250)
var Radius = World_Size/2
var Center_x = World_Size.x/2
var Center_z = World_Size.z/2
var Center_y = World_Size.y

##### LIGHT MATRIX
var light_tile_size = Vector3(1,World_Size.y,1) #in m?
var light_array = []
var light_flux_in = 1.0
var light_max_value = 1.0
var array_path = []

var light_grid_visible = false

#INTERACTION SYSTEM matrix
var bin_array = []
var bin_size = Vector3(5,World_Size.y,5)

var bin_sum_array = [] #array of sum of each alifeelement by bin



func _process(delta: float) -> void:
	
	if GlobalSimulationParameter.SimulationStarted:
		if multiplayer.is_server():
			#add_value_in_each_tile(light_array,light_flux_in,0,light_max_value)
			pass




@rpc("any_peer","call_local")
func generate_world():
	#$Ground/ground.mesh.size = Vector2(World_Size.x,World_Size.z) #THIS IS NOT SYNCH with client
	var calc_size = World_Size/light_tile_size
	light_array.resize(calc_size.x * calc_size.y * calc_size.z)
	fill_value_in_each_tile(light_array,light_flux_in )
	################
	var calc_size2 = World_Size/bin_size
	bin_array.resize(calc_size2.x * calc_size2.y * calc_size2.z)
	#fill_value_in_each_tile(bin_array,[])
	for a in Alifedata.enum_speciesID:
		var arr = []
		arr.resize(calc_size2.x * calc_size2.y * calc_size2.z)
		arr.fill(0)
		bin_sum_array.append(arr)


func get_PositionInGrid(pos,tile_size):
	pos = pos + World_Size/2
	return Vector3i(
		floor(pos.x / tile_size.x),
		floor(pos.y / tile_size.y),
		floor(pos.z / tile_size.z)
	)

func index_3dto1d(x, y, z, tile_size):

	var array_size = World_Size/tile_size
	return x + array_size.x * (y + array_size.y * z)

func index_1dto3d(i, size_in3D) -> Vector3i:
	print("2dto3d not fixed yet")
	var x = i % size_in3D.x
	var y = (i / size_in3D.x) % size_in3D.y
	var z = i / (size_in3D.x * size_in3D.y)
	return Vector3i(x, y, z)


func add_value_in_each_tile(array,value,v_min,v_max):
	for i in array.size():
		array[i] = clamp(array[i]+value, v_min, v_max)
	
func fill_value_in_each_tile(array,value):
	for i in array.size():


		array[i] = value
	
func is_valid_bin(x: int, y: int, z: int,voxel_size:Vector3) -> bool:
	var grid_size := Vector3i(
		floor(World_Size.x / voxel_size.x),
		floor(World_Size.y / voxel_size.y),
		floor(World_Size.z / voxel_size.z)
	)
	return x >= 0 and x < grid_size.x \
	and y >= 0 and y < grid_size.y \
	and z >= 0 and z < grid_size.z
	

func array_path_creation():
	for x in World_Size.x:
		array_path.append([])
		for y in World_Size.y:
			array_path[x].append([])
			for z in World_Size.z:
				array_path[x][y].append(null)
