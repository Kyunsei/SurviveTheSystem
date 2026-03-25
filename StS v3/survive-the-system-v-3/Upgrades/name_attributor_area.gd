extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		print("tesssst")
		$"../LineEdit".hide()
		$"../LineEdit".release_focus()
func _gui_input(event):
	if event.is_action_pressed("ui_cancel"):
		hide()

var p_id
var playerz
func interact(player):
	playerz = player
	$"../LineEdit".grab_focus()
	$"../LineEdit".show()


func _on_line_edit_text_submitted(new_text: String) -> void:
	$"../LineEdit".hide()
	print(playerz)
	change_player_name(new_text)


func change_player_name(text):
	playerz.get_node("MeshInstance3D").get_node("LabelName").text = text
	playerz.get_node("MeshInstance3D").get_node("LabelName").show()


func good_player_id(player_id):
	p_id = player_id
