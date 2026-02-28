extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_status():
	print("statsPanel Updated")
	#$VBoxContainer/HealthLabel.text = str(get_parent().get_parent().lifedata["current_health"]) + "/" + str(get_parent().get_parent().lifedata["Max_health"])
