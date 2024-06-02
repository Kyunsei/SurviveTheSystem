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

var attaque_scene = load("res://Scenes/attaque.tscn") #load scene of block

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

	
	position.x = clamp(position.x, 0, World.world_size*World.tile_size)
	position.y = clamp(position.y, 0, World.world_size*World.tile_size)
	Life.parameters_array[INDEX*Life.par_number + 4]  = last_dir.normalized().x 
	Life.parameters_array[INDEX*Life.par_number + 5] = last_dir.normalized().y
	Life.parameters_array[INDEX*Life.par_number + 6]  = position.x 
	Life.parameters_array[INDEX*Life.par_number + 7] = position.y
	if input_dir.normalized() != Vector2(0,0):
		last_dir = input_dir
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
		#attaque(input_dir)
		print("use is pressed")
	if event.is_action_pressed("interact"):
		current_action = 1
		Interact(self)
		#World.element += 50
		print("interact is pressed")
	if event.is_action_pressed("drop"):
		current_action = 2
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
		

			


func _on_area_2d_area_entered(area):
	if interact_with != null:
		interact_with.get_node("DebugRect").hide()		
	if area.is_in_group("Life"):
		interact_with = area.get_parent()
		#interact_array.append(area.get_parent())
	else:
		interact_with = area
		#interact_array.append(area) # Replace with function body.
	interact_with.get_node("DebugRect").show()


func _on_area_2d_area_exited(area):
	if area.is_in_group("Life"):
		area.get_parent().get_node("DebugRect").hide()
		if 	interact_with == area.get_parent():		
			interact_with = null
		#interact_array.erase(area.get_parent())
	else:
		area.get_node("DebugRect").hide()
		if 	interact_with == area:
			interact_with = null
		#interact_array.erase(area) # Replace with function body.
