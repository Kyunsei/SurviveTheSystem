extends Control

var species = ""

# Called when the node enters the scene tree for the first time.
func _ready():

	#$Sprite2D.texture = Life.life_scene[species].
	#get_node("Sprite_0").texture
	print(species)
	$ProgressBar.value = Life.life_number[species]*100 / 200#Life.pool_scene[species].size()
	$Label.text =  str(Life.life_number[species]) + " / " + "200"#Life.pool_scene[species].size()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
