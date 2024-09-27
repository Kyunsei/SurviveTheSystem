extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


var rotate_x = false
var rotate_y = false

func _input(event):		
	if event.is_action_pressed("shift") :
			if rotate_x == false:
				rotate_x = true
				$CheckButton.button_pressed = true
			else:
				rotate_x = false
				$CheckButton.button_pressed = false
			
	if event.is_action_pressed("alt") :
			if rotate_y == false:
				rotate_y = true
				$CheckButton2.button_pressed = true
			else:
				rotate_y = false	
				$CheckButton2.button_pressed = false
