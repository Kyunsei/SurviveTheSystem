extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_show_button_pressed():
	$Panel.show()
	$ShowButton.hide()


func _on_hide_button_pressed():
	$Panel.hide() # Replace with function body.
	$ShowButton.show()
