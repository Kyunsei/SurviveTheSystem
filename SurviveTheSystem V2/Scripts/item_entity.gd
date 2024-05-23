extends Area2D


var inUse = false
var isEquipped = false
var interact_array = []
var INDEX = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	setSprite() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func setSprite():
	var item_index = Item.item_array[INDEX*Item.par_number]
	$Sprite.texture = Item.item_information[item_index]["sprite"][0]
	#$Sprite.offset.x = -1 * (Item.item_information[item_index]["sprite"][0].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Item.item_information[item_index]["sprite"][0].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	
	AdjustPhysics()
	
func AdjustPhysics():
	var width = $Sprite.texture.get_width()
	var height = $Sprite.texture.get_height()	
	var image_size = $Sprite.texture.get_size()
	$CollisionShape2D.shape.size = image_size
	$CollisionShape2D.position =  Vector2(width/2,-height/2)

func ActivateItem(user_index):
	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	for i in interact_array:
		Life.parameters_array[i.INDEX*Life.par_number+1] -= Item.item_information[iteminfo_index]['value'][0]
	

func _on_timer_timeout():
	pass
	#queue_free() # Replace with function body.



func _on_area_entered(area):
	if area.is_in_group("Life") and isEquipped == true:
		interact_array.append(area.get_parent()) # Replace with function body.

func _on_area_exited(area):
	if area.is_in_group("Life") and isEquipped == true:
		interact_array.erase(area.get_parent()) # Replace with function body. # Replace with function body.
