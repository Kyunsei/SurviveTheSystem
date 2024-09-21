extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	Uptade_timesimulation()
	$HBoxContainer/ProgressBar_day.modulate = Color(1, 1, 0)
	$HBoxContainer/ProgressBar_night.modulate = Color(0.2, 0, 1)
	$HBoxContainer/ProgressBar_day.max_value = World.daytime 
	$HBoxContainer/ProgressBar_night.max_value = World.nighttime 
	$Label.text = "Day " + str(World.day)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func Uptade_timesimulation():
	var fullday = (World.daytime + World.nighttime)  
	$Timer.wait_time = (fullday/ World.speed) / (fullday)
	$Timer.start(0)
	$HBoxContainer/ProgressBar_night.value = 0
	$HBoxContainer/ProgressBar_day.value = 0



func _on_timer_timeout():
	if $HBoxContainer/ProgressBar_day.value < $HBoxContainer/ProgressBar_day.max_value:
		$HBoxContainer/ProgressBar_day.value += 1

	elif $HBoxContainer/ProgressBar_day.value == $HBoxContainer/ProgressBar_day.max_value and $HBoxContainer/ProgressBar_night.value < $HBoxContainer/ProgressBar_night.max_value:
		$HBoxContainer/ProgressBar_night.value += 1

	elif $HBoxContainer/ProgressBar_night.value == $HBoxContainer/ProgressBar_night.max_value:
		$HBoxContainer/ProgressBar_night.value = 0
		$HBoxContainer/ProgressBar_day.value = 0
		$Label.text = "Day " + str(World.day)

