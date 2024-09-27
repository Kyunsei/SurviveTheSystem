extends Node2D
var counter = 2
var img_file = ""
var text_file = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	if Life.char_selected == "planty":
		print("player is a tree")
		$plant_story.show()
		$Timer.start(2)
	elif Life.char_selected == "cat":
		print("player is a cat");
		$cat_story.show()
		$Timer.start(2)
	elif Life.char_selected == "sheep":
		$StartButton.show()
		#get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")


		
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	img_file = "img"+str(counter)
	text_file = "text"+str(counter)
	if Life.char_selected=="planty":
		if $plant_story.get_node(img_file) != null : 
			$plant_story.get_node(img_file).show()
		if $plant_story.get_node(text_file) != null :
			$plant_story.get_node(text_file).show()
		if $plant_story.get_node(img_file) == null and $plant_story.get_node(text_file) == null :
			$StartButton.show()
			#get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	elif Life.char_selected == "cat":
		if $cat_story.get_node(img_file) != null : 
			$cat_story.get_node(img_file).show()
		if $cat_story.get_node(text_file) != null :
			$cat_story.get_node(text_file).show()
		if $cat_story.get_node(img_file) == null and $cat_story.get_node(text_file) == null :
			$StartButton.show()
			#get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	counter += 1



func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
