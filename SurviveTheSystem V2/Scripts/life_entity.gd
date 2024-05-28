extends CharacterBody2D


var INDEX = 0
var current_cycle = 0
var isEquipped = false
var user_INDEX = -1
var vision_array = []

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

	'if Life.state_array[INDEX] < 0:
		queue_free()'
	if Life.state_array[INDEX] > 0:
		$Debug.text =   str (Life.parameters_array[INDEX*Life.par_number + 1] ) +" / " + str (floor(Life.parameters_array[INDEX*Life.par_number + 2]) )  
		if current_cycle != Life.parameters_array[INDEX*Life.par_number + 3] and current_cycle >= 0 :
			current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
			if current_cycle >= 0:
				setSprite()
		if Life.parameters_array[INDEX*Life.par_number+1] <= 0 :
				setDeadSprite()
			#Life.RemoveLife(INDEX)'
	if Life.state_array[INDEX] <= 0:
		queue_free()
	
func _physics_process(delta):
	if Brain.state_array[INDEX] > 0:
		move(delta)
	Life.parameters_array[INDEX*Life.par_number + 6]  = position.x 
	Life.parameters_array[INDEX*Life.par_number + 7] = position.y
	
	
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
	if Life.Genome[genome_index]["movespeed"][current_cycle]> 0:
		Brain.state_array[INDEX] = 1

func setDeadSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
	var y = (floor(posIndex/World.world_size))*Life.life_size_unit
	y= 0
	$Sprite.texture = Life.Genome[genome_index]["dead_sprite"][current_cycle]
	$Sprite.offset.x = -1 * (Life.Genome[genome_index]["dead_sprite"][current_cycle].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Life.Genome[genome_index]["dead_sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	#global_position.y += y + Life.life_size_unit # Life.Genome[genome_index]["sprite"][current_cycle].get_height() #(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	AdjustPhysics()
	Brain.state_array[INDEX] = 0
	


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
	
func move(delta):
		var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
		var current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
		var directionx = Life.parameters_array[INDEX*Life.par_number+4]
		var directiony = Life.parameters_array[INDEX*Life.par_number+5]
		var direction = Vector2(directionx,directiony)
		velocity = Vector2(0,0)
		#var speed = parameters.moveSpeed * World.World_Speed
		if global_position.x <= 0:
			direction = Vector2(1,0)
		if global_position.x >= World.world_size *World.tile_size:
			direction = Vector2(-1,0)
		if global_position.y <= 0:
			direction = Vector2(0,1)
		if global_position.y >= World.world_size *World.tile_size :
			direction = Vector2(0,-1)
					
		velocity = direction*Life.Genome[genome_index]["movespeed"][current_cycle] *World.speed	
		#apply_impulse(moveVector)
		move_and_collide(velocity *delta)
		global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
		global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
		
		Life.parameters_array[INDEX*Life.par_number+6] = position.y #int(position.y/Life.life_size_unit)
		Life.parameters_array[INDEX*Life.par_number+7] = position.x #int(position.x/Life.life_size_unit)

func AdjustPhysics():
	var width = $Sprite.texture.get_width()
	var height = $Sprite.texture.get_height()	
	var image_size = $Sprite.texture.get_size()
	$Area2D/CollisionShape2D.shape.size = image_size
	$Area2D/CollisionShape2D.position = Vector2(Life.life_size_unit/2,-height/2) #Vector2(width/2,-height/2)



func _on_area_2d_area_entered(area):
	if area.is_in_group("Life"):
		var contact_index = area.get_parent().INDEX
		if Life.state_array[contact_index] > 0:
			Life.Eat(INDEX, contact_index)


func ActivateItem(user_index):
	print("useLIFE")
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	if Life.Genome[genome_index]["use"][current_cycle] == 1: #EAT
		'Life.parameters_array[INDEX*Life.par_number+1] = 0
		Life.parameters_array[INDEX*Life.par_number+2] = 0'
		Life.Eat(user_index,INDEX)
		



func Interact(entity):
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	if Life.Genome[genome_index]["interaction"][current_cycle] == 1:  #equip
		print("equip")
		
	if Life.Genome[genome_index]["interaction"][current_cycle] == 2: #take part
		print("take fruit")
		Life.parameters_array[INDEX*Life.par_number + 3] -=1
		var x = int(Life.parameters_array[INDEX*Life.par_number + 6] / World.tile_size)
		var y =int(Life.parameters_array[INDEX*Life.par_number + 7]  / World.tile_size)
		var newindex = Life.BuildLife(x,y,genome_index,get_parent())
		entity.interact_with = get_parent().get_node(str(newindex))
		entity.Interact(entity)
		
	return Life.Genome[genome_index]["interaction"][current_cycle]



func _on_vision_area_entered(area):
	if area.is_in_group("Life"):
		vision_array.append(area.get_parent()) 
		
func _on_vision_area_exited(area):
	if area.is_in_group("Life"):
		vision_array.erase(area.get_parent()) 
