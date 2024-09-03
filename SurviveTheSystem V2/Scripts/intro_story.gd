extends Node2D
var counter = 2
var img_file = ""
var text_file = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	if Life.player_skin_ID == 0:
		print("player is a tree")
		$plant_story.show()
	elif Life.player_skin_ID == 1:
		print("player is a cat");
		$cat_story.show()
	$Timer.start(2)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	img_file = "img"+str(counter)
	text_file = "text"+str(counter)
	if Life.player_skin_ID == 0:
		if $plant_story.get_node(img_file) != null : 
			$plant_story.get_node(img_file).show()
		if $plant_story.get_node(text_file) != null :
			$plant_story.get_node(text_file).show()
		if $plant_story.get_node(img_file) == null and $plant_story.get_node(text_file) == null :
			get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	elif Life.player_skin_ID == 1:
		if $cat_story.get_node(img_file) != null : 
			$cat_story.get_node(img_file).show()
		if $cat_story.get_node(text_file) != null :
			$cat_story.get_node(text_file).show()
		if $cat_story.get_node(img_file) == null and $cat_story.get_node(text_file) == null :
			get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	counter += 1

func _on_button_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
	print("text button start is pressed")
	pass # Replace with function body.
