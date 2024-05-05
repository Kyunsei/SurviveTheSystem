extends Sprite2D


var INDEX = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var rng = RandomNumberGenerator.new()
	print(rng.randi_range(0, 1))
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	texture = Life.Genome[genome_index]["sprite"][rng.randi_range(0, 1)]
	offset.y = Life.Genome[genome_index]["sprite"][1].get_height() *-1
	position.y +=Life.Genome[genome_index]["sprite"][1].get_height() /2
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
