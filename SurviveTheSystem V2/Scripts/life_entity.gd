extends RigidBody2D


var INDEX = 0
var current_cycle = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	var rng = RandomNumberGenerator.new()
	position.x += rng.randi_range(0,5)
	#position.y += rng.randi_range(0,5)
	current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	setSprite()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Debug.text = str (Life.parameters_array[INDEX*Life.par_number + 1] ) +" / " + str (Life.parameters_array[INDEX*Life.par_number + 2] ) +" / " + str (Life.state_array[INDEX]) 
	if current_cycle != Life.parameters_array[INDEX*Life.par_number + 3]:
		current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
		if current_cycle >= 0:
			setSprite()
	'if Life.state_array[INDEX] == -1 :
		#Life.RemoveLife(INDEX)
		#Life.state_array[INDEX] == -1
		queue_free()'
	
func _physics_process(delta):
	if current_cycle >= 0:
		move()
	
	
func setSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
	var y = (floor(posIndex/World.world_size))*Life.life_size_unit
	y= 0
	$Sprite.texture = Life.Genome[genome_index]["sprite"][current_cycle]
	$Sprite.offset.x = -1 * (Life.Genome[genome_index]["sprite"][current_cycle].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Life.Genome[genome_index]["sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	#global_position.y += y + Life.life_size_unit # Life.Genome[genome_index]["sprite"][current_cycle].get_height() #(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	AdjustPhysics()
	
func setActionSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	if Life.Genome[genome_index]["action_sprite"][current_cycle] != null:

		var posIndex = Life.world_matrix.find(INDEX)
		var y = (floor(posIndex/World.world_size))*Life.life_size_unit
		y= 0
		$Sprite.texture = Life.Genome[genome_index]["action_sprite"][current_cycle]
		$Sprite.offset.x = -1 * (Life.Genome[genome_index]["action_sprite"][current_cycle].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
		$Sprite.offset.y = -1 * Life.Genome[genome_index]["action_sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
		#global_position.y += y + Life.life_size_unit # Life.Genome[genome_index]["sprite"][current_cycle].get_height() #(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
		AdjustPhysics()
	
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
		
		Life.parameters_array[INDEX*Life.par_number+6] = position.y #int(position.y/Life.life_size_unit)
		Life.parameters_array[INDEX*Life.par_number+7] = position.x #int(position.x/Life.life_size_unit)

func AdjustPhysics():
	var width = $Sprite.texture.get_width()
	var height = $Sprite.texture.get_height()	
	var image_size = $Sprite.texture.get_size()
	$Area2D/CollisionShape2D.shape.size = image_size
	$Area2D/CollisionShape2D.position =  Vector2(width/2,-height/2)


func _on_area_2d_area_entered(area):
	if (area.name != "Player" and area.name != "Attaque" ):
		print(area.name)
		var contact_index = area.get_parent().INDEX
		#Life.Eat(INDEX, contact_index)


		


func _on_area_2d_body_entered(body):
	if (body.name == "Player"):
		setActionSprite()
 # Replace with function body.


func _on_area_2d_body_exited(body):
	if (body.name == "Player"):
		setSprite() # Replace with function body.
