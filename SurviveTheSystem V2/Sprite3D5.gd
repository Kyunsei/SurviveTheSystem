extends Sprite3D



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
		rotation = get_parent().get_node("CharacterBody3D").rotation # Replace with function body.
