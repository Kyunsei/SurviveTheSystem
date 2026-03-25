extends Resource
class_name DNA

@export var species_id : int
@export var display_name : String

# --- Core metabolism ---
@export var Max_energy : PackedFloat32Array =[10]
@export var Max_health : PackedFloat32Array =[4]
@export var Max_age : PackedInt32Array = [0]
@export var Homeostasis_cost : PackedFloat32Array =[0.5]
@export var Decomposition_speed : PackedFloat32Array =[1.]

# --- Plant Related ----
@export var Photosynthesis_absorption : PackedFloat32Array =[1.]
@export var Photosynthesis_range : PackedInt32Array=[0]
@export var Shadow_generation : float = 0
@export var Shadow_tolerance : float = 0.0
@export var Light_tolerance : float = 1.0

	# --- Movement Related ----
@export var Max_speed : PackedFloat32Array =[0.]
@export var size : PackedVector3Array = [Vector3(1,1,1)]

# --- Life Cycle ---
@export var Reproduction_cost : PackedFloat32Array =[5]
@export var Reproduction_spread : PackedFloat32Array =[3]
@export var Reproduction_number : PackedInt32Array =[1]
@export var Biomass : PackedFloat32Array =[5]




'# --- Growth ---
@export var growth_threshold : float
@export var biomass_gain : float
@export var max_life_state : int = 6'

# --- Rendering ---
@export var multimesh : MultiMesh


# --- Inventory---

@export var Sprite_path : String
#@export var material : Material
@export var Stack_amount : int

'# --- Flags ---
@export var is_plant : bool = false
@export var is_animal : bool = false'


# --- BEHAVIOUR FUNCTIONS ---
@export var food_species_id : PackedInt32Array
@export var danger_species_id : PackedInt32Array
@export var friend_species_id : PackedInt32Array


func Init():
	pass

func growth(_manager, _i, _delta):
	pass

func reproduction(_manager, _i, _delta):
	pass

func special_update(_manager, _i, _delta):
	pass


func Update(_manager, _i, _delta):
	pass

func isPickable(_manager, _i):
	return true

func isPickablebutstaying(_manager, _i):
	#TRUE MEAN NOT SATYING < CLASSIC WAY
	return true

func Damage(_action,manager,i,_ii,value):
		manager.current_health_array[i] -= value
