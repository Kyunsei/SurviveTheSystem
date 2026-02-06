extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Network.get_node("client_menu").client_started.connect($"Alife manager".on_game_started)
