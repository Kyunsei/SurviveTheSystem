extends Sprite2D

var active = false

# Called when the node enters the scene tree for the first time.
func _ready():
	position = Vector2(-2500,-2500)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if World.day == 5 and active == false:
		whale_appear()
	if active :
		Whale_event(delta)


func whale_appear():
	active = true
	position = Life.player.position - Vector2(2500,2500)
	show()
	$AudioStreamPlayer.playing = true
	
func Whale_event(delta):
	position += Vector2(250,250) * delta

'func _input(event):
	if event.is_action_pressed("interact"):
			whale_appear()'
