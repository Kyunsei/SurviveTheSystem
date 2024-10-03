extends LifeEntity
var species = "crab_leg"

func Activate():
	set_collision_layer_value(1,1)

	

func Build_Genome():
	#set_collision_layer_value(1,1)
	Genome["maxPV"]=[200]
	Genome["soil_absorption"] = [0]
	Genome["lifespan"]=[100]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/crab_leg.png")]
	Genome["dead_sprite"] = [preload("res://Art/crab_leg_broken.png")]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



