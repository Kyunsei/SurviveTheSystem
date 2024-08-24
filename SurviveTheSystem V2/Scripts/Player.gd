extends CharacterBody2D

var input_dir = Vector2.ZERO
var last_dir = Vector2.ZERO
var rotation_dir = 0
var basespeed = 300
var speed = 300

#var interact_array = []
var interact_with = null
var equipped_tool = null
var INDEX = 0
var maxEnergy = 100
var current_action = 0

#var attaque_scene = load("res://Scenes/attaque.tscn") #load scene of block

var active_sprite = load("res://Art/player_bulbi.png")
var sleep_sprite = load("res://Art/player_sleep.png")
var isSleeping = false

func _process(delta):
	
	
	speed = basespeed*World.speed
	$Debug.text = "PV: " + str (Life.parameters_array[INDEX*Life.par_number + 1] ) +" /Hunger " + str (floor(Life.parameters_array[INDEX*Life.par_number + 2]) )  
	#$Debug.text = str (Life.parameters_array[INDEX*Life.par_number + 1] ) +" / " + str (floor(Life.parameters_array[INDEX*Life.par_number + 2]) ) +" / " + str (Life.state_array[INDEX]) 
	if Life.state_array[INDEX] <= 0:
		#queue_free()
		$Sprite2D.hide()

func _physics_process(delta):
	input_dir = Vector2.ZERO
	if Input.is_action_pressed("left") :
		input_dir.x -= 1
		rotation_dir = -1	
	if Input.is_action_pressed("right"):
		input_dir.x += 1
		rotation_dir = 1
	if Input.is_action_pressed("up"):
		input_dir.y -= 1
		rotation_dir = -1
	if Input.is_action_pressed("down"):
		input_dir.y += 1
		rotation_dir = 1

	
	
	velocity = input_dir.normalized() * speed 
	move_and_collide(velocity *delta)

	if input_dir.normalized() != Vector2(0,0):
		last_dir = input_dir
	position.x = clamp(position.x, 0, World.world_size*World.tile_size)
	position.y = clamp(position.y, 0, World.world_size*World.tile_size)
	Life.parameters_array[INDEX*Life.par_number + 4]  = last_dir.normalized().x 
	Life.parameters_array[INDEX*Life.par_number + 5] = last_dir.normalized().y
	Life.parameters_array[INDEX*Life.par_number + 6]  = position.x 
	Life.parameters_array[INDEX*Life.par_number + 7] = position.y

	
	if equipped_tool != null:
		var temppos = position + last_dir * Vector2(64,96) 
		equipped_tool.position = position - Vector2(0,32) + last_dir * Vector2(64,64) 
		equipped_tool.rotation = (equipped_tool.position +  Vector2(0,32) ).angle_to_point(position)
		#print(equipped_tool.rotation)
		#equipped_tool.position = position  + last_dir * Vector2(64,64)/2
		#equipped_tool.position = position - Vector2(16,16) + last_dir * Vector2(64,64)/2

func _input(event):
	if event.is_action_pressed("use"):
		current_action = 3
		UseItem()
		Life.stop=true
		Life.Instantiate_NewLife_in_Batch(get_parent(),0,20,Life.new_lifes)
		#attaque(input_dir)
		print("use is pressed")
	if event.is_action_pressed("interact"):
		current_action = 1
		Interact(self)
		#World.element += 50
		print("interact is pressed")
	if event.is_action_pressed("drop"):
		current_action = 2
		Life.stop=false
		#World.element -= 10
		Drop()
		print("drop is pressed")
	if event.is_action_pressed("eat"):
		print("eat is pressed")
		Eat()
	if event.is_action_pressed("attack"):
		print("attack is pressed")
		Attack()
	if event.is_action_pressed("throw"):
		print( "throw is pressed")
		Throw()
	'else:
		current_action = 2'


func Eat():
	if equipped_tool != null:
		#if equipped_tool.is_in_group("Life") == false:
			equipped_tool.BeEaten(INDEX)	

func Attack():
	if equipped_tool != null:
		#if equipped_tool.is_in_group("Life") == false:
			equipped_tool.AttackItem(INDEX)	
			
func Throw():
	if equipped_tool != null:
		if equipped_tool.is_in_group("Life") == false:
			var iteminfo_index = Item.item_array[equipped_tool.INDEX*Item.par_number + 0]
			if Item.item_information[iteminfo_index]['throw'][0] > 0:
			#if equipped_tool.is_in_group("Life") == false:
				equipped_tool.BeThrown(INDEX)	
				Drop()
		elif equipped_tool.is_in_group("Life") == true:
			var genome_index = Life.parameters_array[equipped_tool.INDEX*Life.par_number + 0]
			var current_cycle = Life.parameters_array[equipped_tool.INDEX*Life.par_number + 3]
			if Life.Genome[genome_index]['throw'][current_cycle] > 0:
				#if equipped_tool.is_in_group("Life") == false:
				equipped_tool.BeThrown(INDEX)	
				Drop()


func UseItem():
	if equipped_tool != null:
		#if equipped_tool.is_in_group("Life") == false:
			equipped_tool.ActivateItem(INDEX)	
	
func Interact(entity):
	if interact_with != null:
		if interact_with.is_in_group("Life") == false:
			if interact_with.isEquipped == false:
				Drop()
				equipped_tool = interact_with
				interact_with.isEquipped = true
				interact_with.user_INDEX = INDEX
				interact_with.get_node("DebugRect").hide()	
		if interact_with.is_in_group("Life") == true:
				print("here")
				if interact_with.isEquipped == false:
					var interact_idx = interact_with.Interact(entity)
					if interact_idx == 1:
						Drop()
						equipped_tool = interact_with
						interact_with.isEquipped = true
						interact_with.get_node("DebugRect").hide()

	'for i in interact_array:				
	#	if i.is_in_group("Tool"):
		if i.isEquipped == false:
			equipped_tool = i
			i.isEquipped = true'


func Drop():
	if equipped_tool != null:
		equipped_tool.isEquipped = false
		equipped_tool.user_INDEX = -1
		equipped_tool = null
		

func sleed_mode_on():
	$Sprite2D.texture = sleep_sprite
	basespeed = 0

	#$Sprite2D.offset.x = -1 * (sleep_sprite.get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite2D.offset.y = -32*2.5# * sleep_sprite.get_height()/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Area2D/CollisionShape2D.shape.size = $Sprite2D.texture.get_size()
	$Area2D/CollisionShape2D.position = Vector2(0,-$Sprite2D.texture.get_height()/2) #Vector2(width/2,-height/2)
	Life.Genome[3]["metabospeed"][0] = 0
	pass
	

func sleed_mode_off():
	$Sprite2D.texture = active_sprite
	#$Sprite2D.offset.x = -1 * (active_sprite.get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite2D.offset.y = -32 # * active_sprite.get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Area2D/CollisionShape2D.shape.size = $Sprite2D.texture.get_size()
	$Area2D/CollisionShape2D.position = Vector2(0,-$Sprite2D.texture.get_height()/2) #Vector2(width/2,-height/2)
	basespeed = 300
	Life.Genome[3]["metabospeed"][0] = 1
	pass			


func _on_area_2d_area_entered(area):
	if interact_with != null:
		pass
		#interact_with.get_node("DebugRect").hide()		
	if area.is_in_group("Life"):
		interact_with = area.get_parent()
		#interact_array.append(area.get_parent())
	else:
		interact_with = area
		#interact_array.append(area) # Replace with function body.
	#interact_with.get_node("DebugRect").show()


func _on_area_2d_area_exited(area):
	if area.is_in_group("Life"):
		area.get_parent().get_node("DebugRect").hide()
		if 	interact_with == area.get_parent():		
			interact_with = null
		#interact_array.erase(area.get_parent())
	else:
	#	area.get_node("DebugRect").hide()
		if 	interact_with == area:
			interact_with = null
		#interact_array.erase(area) # Replace with function body.


func _on_sleep_button_pressed():
	if isSleeping == false:
		sleed_mode_on()
		isSleeping = true
	else:
		sleed_mode_off()
		isSleeping = false
		
		

