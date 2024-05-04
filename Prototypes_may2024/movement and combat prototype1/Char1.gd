extends CharacterBody2D

#signal hit

func _ready(): 
	self.position = Vector2(0, 0) #Positionner l'emplacement de départ
	#SwordDown.instantiate()
	var SwordPosition = $SwordPath/SwordLocation
	SwordPosition.progress_ratio = randf()
	var direction = SwordPosition.rotation + PI / 2
	#$SwordDown.position = SwordPosition.position
	$SwordDown.hide()
	_temperature()
	_hunger()
	
@export var speed = 400

signal health_changed(old_value, new_value)
var maximum_health = 100
var current_health = maximum_health
var temperature = 50
var hunger = 200

func _temperature():
	if current_health>0 and temperature<0 or current_health>0 and temperature>49:
		await get_tree().create_timer(0.5).timeout
		current_health -= 1
		await get_tree().create_timer(0.5).timeout
		print("Your current health is ", current_health)
		_temperature()
	elif current_health == 0 or current_health<0 :
		print("You've died!")
		
func _hunger():
	if current_health>0 and hunger>0:
		await get_tree().create_timer(1).timeout
		hunger -= 1
		print("Your hunger level is ", hunger)
		_hunger()
	elif current_health>0 and hunger < 1:
		await get_tree().create_timer(1).timeout
		current_health -= 1
		print("Your current health is ", current_health)
		_hunger()

func get_input():
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed

func _dash():
	if Input.is_action_just_pressed("dash") and speed == 400:
		speed += 600
		await get_tree().create_timer(0.5).timeout
		speed -= 900
		await get_tree().create_timer(0.5).timeout
		speed += 300
		
func _physics_process(delta):
	get_input()
	move_and_slide()

@onready var _animated_sprite = $AnimatedSprite2D

func _process(_delta):
	_sword(_delta)
	_dash()
	if Input.is_action_pressed("move_right"):
		_animated_sprite.play("walk_right")	
	elif Input.is_action_pressed("move_left"):
		_animated_sprite.play("walk_left")
	elif Input.is_action_pressed("move_down"):
		_animated_sprite.play("walk_down")
	elif Input.is_action_pressed("move_up"):
		_animated_sprite.play("walk_up")
	else:
		_animated_sprite.stop()
		
func _sword(delta):
	if Input.is_action_just_pressed("sword_attack") and not $SwordDown.visible :
		$SwordDown.show()
	elif Input.is_action_just_pressed("sword_attack") and $SwordDown.visible :
		$SwordDown.hide()
	#$SwordDown/Timer.start(0)
	$SwordDown.position = Vector2(get_viewport().get_mouse_position() - self.position).normalized()*65
	$SwordDown.look_at(get_viewport().get_mouse_position())

func _input(event):
	# Mouse in viewport coordinates.
	#if event is InputEventMouseButton:
	#	print("Mouse Click/Unclick at: ", event.position)
	#elif event is InputEventMouseMotion:
	#	print ("Mouse Motion at: ", event.position)
		
	# Print the size of the viewport.
	#print("Viewport Resolution is: ", get_viewport().get_visible_rect().size)
	# Alternatively, it's possible to ask the viewport for the mouse position: 
	# get_viewport().get_mouse_position()

	var swordvector = Vector2(get_viewport().get_mouse_position() - self.position)
	
	swordvector = swordvector.normalized()*60
	#print("Your vector is: ", swordvector)

func _on_sword_down_area_entered(area):
	if $SwordDown.visible:
		print("You've hit something!")
