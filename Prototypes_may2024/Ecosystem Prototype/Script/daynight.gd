extends Node2D

var time_normalised  = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	Init() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#$nightcolor.color[3] = time_normalised

	if $DayTimer.time_left > World.Night_time / World.World_Speed:
		$nightcolor.color[3] = 0.
	if $DayTimer.time_left < World.Night_time / World.World_Speed:
		$nightcolor.color[3] =  0.7		

	

func UpdateSimulationSpeed():
	$DayTimer.wait_time = (World.Day_time + World.Night_time) / World.World_Speed
	$DayTimer.start(0)
	



func Init():
	$nightcolor.color[3] = 0
	$nightcolor.size = (Vector2(World.worldsize,World.worldsize)+ Vector2(1,1))*World.tile_size
	$DayTimer.wait_time =  (World.Day_time + World.Night_time) / World.World_Speed
	$DayTimer.start(0)



func _on_day_timer_timeout():
	World.day = World.day + 1	  # Replace with function body.
