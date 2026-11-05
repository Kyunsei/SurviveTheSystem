extends Item
var area
@export var action_size = Vector3(2,2,2)
var timer = 0.5
var vacuum_physical_obj
var durability_diff
var sound_on := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_01Vacuum1_on.wav")
var sound_loop := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_02Vacuum1_loop.wav")
var sound_off := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_03Vacuum1_off.wav")
var sound2_on := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_04Vacuum2_on.wav")
var sound2_loop := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_05Vacuum2_loop.wav")
var sound2_off := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_06Vacuum2_off.wav")
const VACUUM_LOOP := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_02Vacuum1_loop.wav")

var durability :int = 0: 
	set(amouuunt): 
		if durability != amouuunt: 
			var previous_number = durability
			durability = amouuunt
			set_current_durability(previous_number)

func set_current_durability(prev_num: int) -> int:
	var difference := prev_num - durability
	return difference
#MONEY MONEY MONEY MONEY MONEY

func _ready():
	vacuum_physical_obj = $Pivot
	vacuum_physical_obj.rotation_degrees.y = randf_range(0.0, 360.0)

func _process(delta: float) -> void:
	timer -= delta

func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server():
		if timer <0:
			if body.is_in_group("player"):
				add_to_player(body,int(body.name))
			else:
				pass


static func on_use(player):
	#var sound_loop := preload("res://assets/Sounds/SurviveTheSystem_SDH_Sounds_ItemSounds_02Vacuum1_loop.wav")
	player.vacuum_activation.rpc_id(1)

	




	
static func eat(_player):
	#print ("eaten cat ratio")
	print("This Vacuum can't be eaten")
	pass
	
