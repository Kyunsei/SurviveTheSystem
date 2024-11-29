extends CanvasLayer

var life_stat = load("res://Scenes/life_stat_end.tscn")

var end_type : ending = ending.GOOD

enum ending {
	GOOD,
	BAD
}

# Called when the node enters the scene tree for the first time.
func _ready():
	for l in Life.life_number:
		var ls = life_stat.instantiate()
		ls.species = l
		$VBoxContainer.add_child((ls))
		
	match end_type:
		ending.BAD:
			$Label_endType.text = "BAD ENDING =("
			$Label_endType.set("theme_override_colors/font_color", Color(1, 0, 0))
		ending.GOOD:
			$Label_endType.text = "GOOD ENDING =)"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_quit_pressed():
	get_tree().quit()


func _on_button_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")


