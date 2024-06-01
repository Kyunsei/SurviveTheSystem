extends Area2D


var inUse = false
var isEquipped = false
var interact_array = []
var INDEX = 0
var user_INDEX = -1

# Called when the node enters the scene tree for the first time.
func _ready():
	setSprite() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func setSprite():
	var item_index = Item.item_array[INDEX*Item.par_number]
	var size = Item.item_information[item_index]["sprite"][0].get_size()
	$Sprite.texture = Item.item_information[item_index]["sprite"][0]
	#$Sprite.offset.x = -1 * (Item.item_information[item_index]["sprite"][0].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Item.item_information[item_index]["sprite"][0].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )

	#$CollisionShape2D/DebugRect2.position = position
	AdjustPhysics()
 
func AdjustPhysics():
	var width = $Sprite.texture.get_width()
	var height = $Sprite.texture.get_height()	
	var image_size = $Sprite.texture.get_size()
	$CollisionShape2D.shape.size =  Vector2(image_size[0]*3,image_size[1]*4) #image_size *2
	$CollisionShape2D.position =  Vector2(-width/2,-height/2)
	
	
	$CollisionShape2D/DebugRect2.size = $CollisionShape2D.shape.size
	$CollisionShape2D/DebugRect2.position -= $CollisionShape2D/DebugRect2.size/2


func ActivateItem(user_index):


	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	if Item.item_information[iteminfo_index]['action'][0] == 1:
		$CollisionShape2D/DebugRect2.show()
		$Timer.start(0)
		for i in interact_array:
			if i != null:
				Life.parameters_array[i.INDEX*Life.par_number+1] -= Item.item_information[iteminfo_index]['value'][0]
				if Life.Genome[Life.parameters_array[i.INDEX*Life.par_number]]["movespeed"][Life.parameters_array[i.INDEX*Life.par_number+3]] > 0:
					i.global_position += global_position.direction_to(i.global_position) *64
	if Item.item_information[iteminfo_index]['action'][0] == 2:
		var x = int(position.y/World.tile_size)
		var y = int(position.x/World.tile_size)
		var posindex = x*World.world_size + y
		World.block_element_array[posindex] += Item.item_information[iteminfo_index]['value'][0]
		pass
		
func _on_timer_timeout():
	$CollisionShape2D/DebugRect2.hide()
	#queue_free() # Replace with function body.



func _on_area_entered(area):
	if area.is_in_group("Life") and isEquipped == true:
		if area.get_parent().INDEX != user_INDEX:
			interact_array.append(area.get_parent()) # Replace with function body.

func _on_area_exited(area):
	if area.is_in_group("Life") and isEquipped == true:
		interact_array.erase(area.get_parent()) # Replace with function body. # Replace with function body.
