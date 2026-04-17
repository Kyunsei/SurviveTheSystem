extends Node
class_name AgentManager


#AGENTS VARIABLE
var positions : PackedVector3Array
var positions_x : PackedFloat32Array
var positions_y : PackedFloat32Array
var positions_z : PackedFloat32Array

var directions: PackedVector3Array
var active : PackedInt32Array



#SPATIAL THINGS
var bin_ids : PackedInt32Array
var bin_array : Array[PackedInt32Array]
@export var bin_size : Vector3 = Vector3(5,5,5)


#World
var world_manager : WorldManager

#AGENT MANAGER
var free_indices : Array =[]
var agent_count :int = 0 

#SYSTEM CALLED
@export var systems : Array[AgentSystem]
@export var physics_process_systems : Array[AgentSystem]
@export var species_systems : Array[AgentSystem]
@export var physics_process_species_systems : Array[AgentSystem]


func init(world:WorldManager):
	world_manager = world
	Generate_Arrays()


func update(delta):
	for s in systems:
		s.update(self,delta)
	for s in species_systems:
		s.update(self,delta)
		
func physics_update(delta):
	for s in physics_process_systems:
		s.update(self,delta)
	for s in physics_process_species_systems:
		s.update(self,delta)


#------------------------ ARRAY MANAGEMNT --------------------

func get_free_id() -> int :
	var new_id : int
	if free_indices.size()> 0:
		new_id = free_indices.pop_back()
	else:
		new_id = agent_count
		agent_count += 1
	return new_id



func Generate_Arrays():
	bin_array = set_bin_array(bin_size,0)
	pass
	



func Build_New_Agent():
	positions.append(Vector3(0,0,0))
	positions_x.append(0)
	positions_y.append(0)
	positions_z.append(0)

	active.append(1)

func Build_Agent(id):
	positions[id]=Vector3(0,0,0)
	positions_x[id] =0
	positions_y[id] =0
	positions_z[id] =0
	active[id]=1
	
	
func Add_Agent():
	var new_id : int
	if free_indices.size()> 0:
		new_id = free_indices.pop_back()
		agent_count += 1
		Build_Agent(new_id)
	else:
		new_id = agent_count
		agent_count += 1
		Build_New_Agent()
	return new_id

func Remove_Agent(id):
	free_indices.append(id)
	agent_count -= 1
	active[id]=0



#------------------------ BIN MANAGEMNT --------------------

func get_current_bin(pos,binsize,world_id) -> int:
	var x = pos.x/binsize.x
	var y = pos.y/binsize.y
	var z = pos.z/binsize.z
	var Y = world_manager.size_y[world_id]
	var Z = world_manager.size_z[world_id]
	var binid = x * (Y * Z) + y * Z + z
	return binid
	
func add_id_in_bin(index:int,bin_index:int) -> bool:
	if bin_array.size() < bin_index:
		return false
	if bin_array[bin_index].has(index):
		return false
	bin_array[bin_index].append(index)
	bin_ids[index] = bin_index
	return true
	
func remove_id_in_bin(index:int,bin_index:int) -> bool:
	if bin_array.size() < bin_index:
		return false
	if !bin_array[bin_index].has(index):
		return false
	bin_array[bin_index].erase(index)
	bin_ids[index] = -1
	return true

func set_bin_array(binsize,world_id) -> Array[PackedInt32Array]:
	assert(binsize.x > 0 and binsize.y > 0 and binsize.z > 0)
	var new_array : Array[PackedInt32Array]
	var w_x = float(world_manager.size_x[world_id])
	var w_y = float(world_manager.size_y[world_id])
	var w_z = float(world_manager.size_z[world_id])
	
	var bins_x = int(ceil(w_x / binsize.x))
	var bins_y = int(ceil(w_y / binsize.y))
	var bins_z = int(ceil(w_z / binsize.z))

	var total_bins = bins_x * bins_y * bins_z

	for i in range(total_bins):
		new_array.append([])
	return new_array

	
