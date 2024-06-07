extends CharacterBody2D


var INDEX = 0
var current_cycle = -1
var genome_index = -1
var isEquipped = false
var user_INDEX = -1
var vision_array = []
var interact_with = []

var onScreen = true
var activated = false
var thread  = Thread.new()

var start_pos = Vector2(0,0)
var direction_throw = Vector2(0,0)
var isThrown = false


# Called when the node enters the scene tree for the first time.
func _ready():
	
	#var rng = RandomNumberGenerator.new()
	#position.x += rng.randi_range(0,5)
	#position.y += rng.randi_range(0,5)
	#current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	#Life.parameters_array[INDEX*Life.par_number + 6]  = position.x 
	#Life.parameters_array[INDEX*Life.par_number + 7] = position.y
	#setSprite()
	desactivate()
	pass # Replace with function body.

func activate():
	$CollisionShape2D.show()
	$Sprite.show()
	$Area2D.show()
	$Vision.show()
	activated = true
	'thread = Thread.new()
	thread.start(Init)'
	genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	global_position.x  = Life.parameters_array[INDEX*Life.par_number + 6]  
	global_position.y = Life.parameters_array[INDEX*Life.par_number + 7]


		
func desactivate():
	$CollisionShape2D.hide()
	$Sprite.hide()
	$Area2D.hide()
	$Vision.hide()
	global_position.x  = 0 
	global_position.y = 0
	activated = false

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	if Life.state_array[INDEX] > 0:
		if activated != true:
			activate()
		
	#if activated: 
		#eating_food()
		#$Debug.text = str(INDEX) +" "  + " " + str (Life.parameters_array[INDEX*Life.par_number + 1] ) +" / " + str (floor(Life.parameters_array[INDEX*Life.par_number + 2]) )  
		if current_cycle != Life.parameters_array[INDEX*Life.par_number + 3] :
			current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
			setSprite()
		if Life.parameters_array[INDEX*Life.par_number+1] <= 0 :
			setDeadSprite()
	if Life.state_array[INDEX] <= 0  and activated :

				desactivate()
				if isEquipped:
					isEquipped = false
					get_parent().get_node("Player").equipped_tool = null
				

	
func _physics_process(delta):
	if isThrown:
		Throwing()
	if Brain.state_array[INDEX] > 0:
		move(delta)

	
func setSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
	$Sprite.texture = Life.Genome[genome_index]["sprite"][current_cycle]
	$Sprite.offset.x = -1 * (Life.Genome[genome_index]["sprite"][current_cycle].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Life.Genome[genome_index]["sprite"][current_cycle].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	AdjustPhysics()
	if Life.Genome[genome_index]["movespeed"][current_cycle] <0 :
		Brain.state_array[INDEX] = 1
	


func setDeadSprite():
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var posIndex = Life.world_matrix.find(INDEX)
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
		#if global_position.x <= 0:
			#direction = Vector2(1,0)
		#if global_position.x >= World.world_size *World.tile_size:
			#direction = Vector2(-1,0)
		#if global_position.y <= 0:
			#direction = Vector2(0,1)
		#if global_position.y >= World.world_size *World.tile_size :
			#direction = Vector2(0,-1)
					
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



func eating_food():
	if interact_with.size() > 0:
		for i in interact_with:
			var contact_index = i.INDEX
			if Life.state_array[contact_index] > 0:
				Life.Eat(INDEX, contact_index)
#	await get_tree().create_timer(0.5).timeout

func BeEaten (user_index):
	var genome_index = Life.parameters_array[INDEX*Life.par_number + 0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number + 3]
	if Life.Genome[genome_index]["use"][current_cycle] == 1: #EAT
		Life.Eat(user_index,INDEX)

func ActivateItem(user_index):
	print("useLIFE")

func AttackItem(user_index):
	print("this item is attacking right now")
	#var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	#$CollisionShape2D/DebugRect2.show()
	#$Timer.start(0)
	#for i in interact_array:
		#if i != null:
			#Life.parameters_array[i.INDEX*Life.par_number+1] -= Item.item_information[iteminfo_index]['value'][0]
			#if Life.Genome[Life.parameters_array[i.INDEX*Life.par_number]]["movespeed"][Life.parameters_array[i.INDEX*Life.par_number+3]] > 0:
				#i.global_position += global_position.direction_to(i.global_position) *64
				#
func BeThrown (user_index):

	direction_throw = Vector2(Life.parameters_array[user_index*Life.par_number+4],Life.parameters_array[user_index*Life.par_number+5])
	if Life.Genome[genome_index]['throw'][current_cycle] > 0:
		start_pos = global_position
		isThrown = true


func Throwing():
	var distance = 100*Life.Genome[genome_index]['throw'][current_cycle]
	var speed = 10.
	if start_pos.distance_to(global_position) < distance:
		global_position += direction_throw*speed
	else:
		isThrown = false

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


'func entity_eating_target():
	if self.hitbox overlap with is_in_group("Life").hitbox
		if interact_with !=null:
			var contact_index = interact_with.INDEX
			if Life.state_array[contact_index] > 0:
				Life.Eat(INDEX, contact_index)'


func _on_vision_area_entered(area):
	if area.is_in_group("Life"):
		vision_array.append(area.get_parent()) 
		
func _on_vision_area_exited(area):
	if area.is_in_group("Life"):
		vision_array.erase(area.get_parent()) 


func _on_area_2d_area_exited(area):

	if area.is_in_group("Life"):
		interact_with.erase(area.get_parent()) 

func _on_area_2d_area_entered(area):
	if area.is_in_group("Life"):
		interact_with.append(area.get_parent()) 


