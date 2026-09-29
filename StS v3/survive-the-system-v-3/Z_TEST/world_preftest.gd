extends Node2D
class_name World

var size : Vector3
var default_size = Vector3(1100,20,640)
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	size = default_size
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
