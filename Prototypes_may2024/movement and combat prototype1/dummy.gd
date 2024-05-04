extends Node2D
@onready var _animated_sprite = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if maximumhealth == 0 or maximumhealth<0 :
		queue_free()

var maximumhealth = 100





func _on_area_2d_area_entered(area):
		if area.visible:
			maximumhealth -= 5
			print("Dummy current health is: ", maximumhealth)
			_animated_sprite.play("left")
			#_animated_sprite.stop()
