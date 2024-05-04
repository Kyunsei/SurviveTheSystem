extends Area2D


signal hit()

var velocity = Vector2.RIGHT

func _physics_process(delta):
	position += velocity * delta

#var plasma_shot = red_plasma.instantiate()
#get_parent().add_child(red_plasma)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_timer_timeout():
	pass


func _on_body_entered(body):
	emit_signal
