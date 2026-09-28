extends Node2D

var size : Vector3
var default_size = Vector3(20,20,20)
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	size = default_size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
