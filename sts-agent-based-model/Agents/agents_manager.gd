extends Node
class_name AgentManager


#AGENTS VARIABLE
var positions : PackedVector3Array
var positions_x : PackedFloat32Array
var positions_y : PackedFloat32Array
var positions_z : PackedFloat32Array

var directions: PackedVector3Array
var bin_ids : PackedInt32Array
var active : PackedInt32Array



#SPATIAL THINGS
var bin_array : Array[PackedInt32Array]

#AGENT MANAGER
@export var bin_size : Vector3 = Vector3(5,5,5)
var free_indices : Array =[]
var agent_count :int = 0 

#SYSTEM CALLED
@export var systems : Array[AgentSystem]
@export var physics_process_systems : Array[AgentSystem]
@export var species_systems : Array[AgentSystem]
@export var physics_process_species_systems : Array[AgentSystem]


func init():
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


func get_current_bin(pos,binsize) -> int:
	var binid = 0
	return binid

func Generate_Arrays():
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
