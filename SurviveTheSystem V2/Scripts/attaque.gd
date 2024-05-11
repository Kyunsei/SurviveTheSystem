extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	queue_free() # Replace with function body.



func _on_area_entered(area):
	if area.is_in_group("Life"):
		Life.parameters_array[area.get_parent().INDEX*Life.par_number+1] -= 2
		
		
		#var contact_index = area.get_parent().INDEX
		#Life.Eat(INDEX, contact_index) # Replace with function body.
