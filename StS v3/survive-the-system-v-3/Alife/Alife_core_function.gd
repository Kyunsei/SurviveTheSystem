extends Node3D
class_name Alife

#WORLD
@export var World: Node3D 
#Can be a ressources as it will be only array at the end?

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


func Activate():
	show()
	isActive = true

func Desactivate():
	hide()
	isActive = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
