extends CanvasLayer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		$FPS.text ="Peer ID: " + str(multiplayer.get_unique_id()) + "\nfps: " + str(Engine.get_frames_per_second())
