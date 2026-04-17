extends Node
class_name WorldManager


#WORLD VARIABLE
var positions_x : PackedFloat32Array
var positions_y : PackedFloat32Array
var positions_z : PackedFloat32Array

var size_x : PackedFloat32Array
var size_y : PackedFloat32Array
var size_z : PackedFloat32Array
var boundary_condition : PackedInt32Array
enum boundary_condition_mode  { WRAP, BORDER}


#ECS system variable
var active : PackedInt32Array
var world_count : int = 0
var free_indices : Array

func init():
	Generate_World(Vector3(0,0,0),Vector3(80,30,10))


func Build_New_World(pos: Vector3,size: Vector3):
	positions_x.append(pos.x)
	positions_y.append(pos.y)
	positions_z.append(pos.z)
	size_x.append(size.x)
	size_y.append(size.y)
	size_z.append(size.z)
	boundary_condition.append(1) #TOSET HERE
	active.append(1)

func Build_Agent(id, pos, size):
	positions_x[id] =0
	positions_y[id] =0
	positions_z[id] =0
	active[id]=1
	positions_x[id] =pos.x
	positions_y[id] =pos.y
	positions_z[id] =pos.z
	size_x[id] =size.x
	size_y[id] =size.y
	size_z[id] =size.z
	active[id] =1	
	boundary_condition[1] =1
	
func Add_World(pos:Vector3,size:Vector3):
	var new_id : int
	if free_indices.size()> 0:
		new_id = free_indices.pop_back()
		world_count += 1
		Build_Agent(new_id,pos,size)
	else:
		new_id = world_count
		world_count += 1
		Build_New_World(pos,size)
	return new_id

func Remove_World(id):
	free_indices.append(id)
	world_count -= 1
	active[id]=0
	
	
	
#-------------------------- World generarion HERE---------------------
#Will probably move in another script later
func Generate_World(world_pos: Vector3, world_size:Vector3):
	Add_World(world_pos,world_size)
