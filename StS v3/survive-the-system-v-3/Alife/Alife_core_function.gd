extends Node3D
class_name Alife

#WORLD
@export var World: Node3D 
#Can be a ressources as it will be only array at the end?
var bin_ID = null

#INTERACTION
var current_HP: float
@export var max_HP: float

#METABOLISM
var current_energy: float
@export var max_energy:float

#PHENOTYPE
@export var color:Color
@export var size:Vector3

#MOUVEMENT
var current_speed: float
@export var max_speed: float

#REPRODUCTION
@export var seed_size:Vector3
@export var seed_number:int


#POOLSYSTEM
var isActive:bool
signal reproduction_asked
signal desactivated


func Activate():
	show()
	isActive = true
	put_in_world_bin()

func Desactivate():
	hide()
	isActive = false
	remove_from_world_bin()
	desactivated.emit()


func put_in_world_bin():
	var w_pos = World.get_PositionInGrid(position,World.bin_size)
	var new_bin_ID = World.index_3dto1d(w_pos.x, w_pos.y, w_pos.z, World.bin_size)
	if new_bin_ID < 0:
		print("life out of world")
		remove_from_world_bin()
		return
	if bin_ID != new_bin_ID:
		remove_from_world_bin()
		bin_ID = new_bin_ID
		if World.bin_array[bin_ID] == null:
			World.bin_array[bin_ID] = [self]
		else:	
			World.bin_array[bin_ID].append(self) 
		#World.bin_array[2].append(self) 

	#print(World.bin_array[bin_ID])
	#print(bin_ID)

func remove_from_world_bin():
	if bin_ID:
		if World.bin_array[bin_ID].has(self):
			World.bin_array[bin_ID].erase(self)
			bin_ID = null

 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
