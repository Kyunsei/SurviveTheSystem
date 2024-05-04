extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready():

	_life_expectancy()
	



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
signal hit

var velocity = Vector2.RIGHT

func _physics_process(delta):
	position += velocity * delta

#var plasma_shot = red_plasma.instantiate()
#get_parent().add_child(red_plasma)

func _life_expectancy():
	await get_tree().create_timer(2).timeout
	queue_free()
	


var player = preload("res://char_1.tscn")
var player2 = preload("res://Char1.gd")
func _on_hit():
	#if body.name == "Char1" :
		#get_node("char1")
		player.current_health -= 100
		print("Player have been hit")
