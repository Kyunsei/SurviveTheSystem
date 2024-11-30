extends Control

var achiev_panel = load("res://Scenes/achievment_panel.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	GameSystem.Load_achievement()
	for a in GameSystem.achievement_dic:
		var pnl = achiev_panel.instantiate()
		$VBoxContainer.add_child(pnl)
		pnl.get_node("Label").text = a
		pnl.get_node("CheckBox").button_pressed = GameSystem.achievement_dic[a]
		pnl.get_node("CheckBox").connect("pressed", set_achievment.bind(a))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_return_pressed():
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")

func set_achievment(name):
	if GameSystem.achievement_dic[name] == 1:
		GameSystem.achievement_dic[name]  = 0
	else:
		GameSystem.achievement_dic[name]  = 1
	
	GameSystem.Save_achievement()
