extends Sprite2D


var INDEX = 0
var current_cycle = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var rng = RandomNumberGenerator.new()
	current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	setSprite()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Debug.text = str (Life.parameters_array[INDEX*Life.par_number + 2] )
	if current_cycle != Life.parameters_array[INDEX*Life.par_number + 3]:
		current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
		setSprite()
		
func setSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
	var y = (floor(posIndex/World.world_size))*Life.life_size_unit
	texture = Life.Genome[genome_index]["sprite"][current_cycle]
	offset.y = -1 * Life.Genome[genome_index]["sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	position.y = y + Life.life_size_unit # Life.Genome[genome_index]["sprite"][current_cycle].get_height() #(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
