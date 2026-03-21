extends Item
var area
@export var action_size = Vector3(2,2,2)
var timer = 0.5
var vacuum_physical_obj
var durability_diff


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
	player.vacuum_activation2.rpc_id(1)
	
	
	
	
static func eat(_player):
	#print ("eaten cat ratio")
	print("This Vacuum can't be eaten")
	pass
	
