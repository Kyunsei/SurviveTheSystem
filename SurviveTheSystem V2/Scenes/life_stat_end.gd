extends Control

var species = "cat"



# Called when the node enters the scene tree for the first time.
func _ready():

	var il = Life.life_scene[species].instantiate()
	$Sprite2D.texture = il.get_node("Sprite_0").texture
	$ProgressBar.value = Life.life_number[species]*100 / Life.pool_scene[species].size()
	if Life.life_number[species] <= 0:
		$Label.text =  "EXCTINCT"
		get_parent().get_parent().end_type = get_parent().get_parent().ending.BAD
	else:
		$Label.text =  str(Life.life_number[species]) + " / " + str(Life.pool_scene[species].size())


			
