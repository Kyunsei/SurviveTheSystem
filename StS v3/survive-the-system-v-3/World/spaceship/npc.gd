extends Area3D

var player

func display_text(dialogue_box, text):
	dialogue_box.show()
	dialogue_box.show_text(text)

func interact(p):
	player = p
	if not player.dialogue_box.button_pressed.is_connected(_on_next):
		player.dialogue_box.button_pressed.connect(_on_next)
	display_text(p.dialogue_box, "Welcome Catraunaute! \n We need you to collect bioressources for the magnificient catempire! \n Are you READY ?!!?!")


func _on_next():
	player.position = Vector3(0,1,0)
