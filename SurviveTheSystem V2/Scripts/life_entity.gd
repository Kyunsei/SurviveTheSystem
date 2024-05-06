extends RigidBody2D


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
	
func _physics_process(delta):
	move()
	
	
func setSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
	var y = (floor(posIndex/World.world_size))*Life.life_size_unit
	$Sprite.texture = Life.Genome[genome_index]["sprite"][current_cycle]
	$Sprite.offset.y = -1 * Life.Genome[genome_index]["sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	global_position.y = y + Life.life_size_unit # Life.Genome[genome_index]["sprite"][current_cycle].get_height() #(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )

func move():
		var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
		var current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
		var directionx = Life.parameters_array[INDEX*Life.par_number+4]
		var directiony = Life.parameters_array[INDEX*Life.par_number+5]
		var direction = Vector2(directionx,directiony)
		var moveVector = Vector2(0,0)
		#var speed = parameters.moveSpeed * World.World_Speed
		if global_position.x <= 0:
			linear_velocity = Vector2(0,0)
			direction = Vector2(1,0)
		if global_position.x >= World.world_size *World.tile_size:
			linear_velocity = Vector2(0,0)
			direction = Vector2(-1,0)
		if global_position.y <= 0:
			linear_velocity = Vector2(0,0)
			direction = Vector2(0,1)
		if global_position.y >= World.world_size *World.tile_size :
			linear_velocity = Vector2(0,0)
			direction = Vector2(0,-1)
					
		moveVector = direction*Life.Genome[genome_index]["movespeed"][current_cycle]	
		apply_impulse(moveVector)
		global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
		global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
