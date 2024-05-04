extends CharacterBody2D

@export var speed = 400
@export var rotation_speed = 1.5

#lost 80% in one day (600s)

var metabospeed = 1.
var energyHomeostasisCost = 100. /600
var rotation_direction = 0
var tiles_array = []
var interact_array = []
var input_dir = Vector2.ZERO

var element = [0,0,0,0,0,0,0,0,0,0]

var alive = true
var tool_equiped = null

# Called when the node enters the scene tree for the first time.
func _ready():
	$Timer.wait_time = metabospeed  / World.World_Speed
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if alive:
		#$Player_energy.text ="Energy: " + str("%.2f" % World.Player_energy)
		$Player_energy.text ="Element: " + str("%.2f" % element[0])
		checkDeath()
	pass

func _physics_process(delta):
	input_dir = Vector2.ZERO
	if Input.is_action_pressed("left") :
		input_dir.x -= 1
	if Input.is_action_pressed("right"):
		input_dir.x += 1
	if Input.is_action_pressed("up"):
		input_dir.y -= 1
	if Input.is_action_pressed("down"):
		input_dir.y += 1
	if Input.is_action_pressed("dash"):
		pass
	if Input.is_action_pressed("Interacting"):
		interact()
		TakeBlockElement()
	if Input.is_action_pressed("using"):
		UseTool()
		GiveBlockElement()
	if Input.is_action_pressed("drop"):
		DropTool()
		GiveBlockElement2()

	velocity = input_dir.normalized() * speed  * max(1,2*World.World_Speed/100)
	move_and_collide(velocity *delta)
	if tool_equiped != null:
		#tool_equiped.apply_central_impulse(velocity * delta)
		tool_equiped.global_position = position
		tool_equiped.linear_velocity= velocity*delta
		
	#position.x = clamp(position.x, (World.instantiateRange+2)*World.tile_size, (World.Map_size[0]-World.instantiateRange-2)*World.tile_size)
	#position.y = clamp(position.y, (World.instantiateRange+2)*World.tile_size, (World.Map_size[1]-World.instantiateRange-2)*World.tile_size)

	#get_input()
	#rotation += rotation_direction * rotation_speed * delta
	#move_and_slide()


'''
func get_input():
	rotation_direction = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	velocity = transform.x * (Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")) * speed
'''

func TakeBlockElement():
	#ROOT function
	var sizeFact = roundi(2)
	var x = roundi(position.x/World.tile_size)
	var y = roundi(position.y/World.tile_size-sizeFact/2) #-1 for sprite offset
	var blockElement = 0
	var qte_transfer = 0
	for i in range(1):
		for j in range(1):
			if x+i >= 0 and y-j >= 0 and x+i < World.worldsize and y-j < World.worldsize :
				for e in range(element.size()):
					blockElement = World.Block_Matrix[(x+i)*World.worldsize*element.size()+(y-j)*element.size() + e]
					element[e] += blockElement
					World.Block_Matrix[(x+i)*World.worldsize*element.size()+(y-j)*element.size() + e] -=  blockElement
					World.Block_to_update.append([x+i,y-j])

	
func GiveBlockElement():
	var sizeFact = roundi(2)
	var x = roundi(position.x/World.tile_size)
	var y = roundi(position.y/World.tile_size-sizeFact/2) #-1 for sprite offset
	for i in range(1):
		for j in range(1):
			for e in range(element.size()):
			
				World.Block_Matrix[(x+i)*World.worldsize*element.size()+(y-j)*element.size() + e] +=  element[e]
				element[e] = 0
				World.Block_to_update.append([x+i,y-j])


func GiveBlockElement2():
	var sizeFact = roundi(2)
	var x = roundi(position.x/World.tile_size)
	var y = roundi(position.y/World.tile_size-sizeFact/2) #-1 for sprite offset
	for i in range(1):
		for j in range(1):
			for e in range(element.size()):
				if World.createElementToggle[e]:
					World.Block_Matrix[(x+i)*World.worldsize*element.size()+(y-j)*element.size() + e] +=  1
					#element[e] = 0
					World.Block_to_update.append([x+i,y-j])






func interact():
	for i in interact_array:				
		if i.is_in_group("Tool"):

			EquipTool(i)


func UseTool():
	if tool_equiped != null:
		tool_equiped.Action(self, interact_array)



func EquipTool(i):
	if tool_equiped == null:
		tool_equiped = i
		i.collision_layer = 0
		i.isInInventory = true

	else:
		DropTool()
		tool_equiped = i
	
	
func DropTool():
	if tool_equiped != null:
		tool_equiped.collision_layer = 4
		tool_equiped.linear_velocity= Vector2(0,0)
		tool_equiped.isInInventory = false
		tool_equiped = null


func getBlockPos():
	var blockpos = Vector2(position)-Vector2(32,32)
	blockpos =Vector2i(blockpos/World.tile_size)
	return blockpos



func energyCosumption():
	World.Player_energy -= energyHomeostasisCost
	#World.Soil_food += energyHomeostasisCost
	#tiles_array.all(addenergy)
	var blockpos= getBlockPos()
	
	World.Block_Matrix[blockpos[0]][blockpos[1]][3][0] += energyHomeostasisCost
	get_parent().tiles_to_update.append([blockpos[0],blockpos[1]])	


func UpdateSimulationSpeed():
	$Timer.wait_time = metabospeed  / World.World_Speed
	$Timer.start(0)
	
	

func _on_timer_timeout():
	tiles_array = []
	if alive:
		pass
		#energyCosumption() # Replace with function body.

	
func checkDeath():
	if World.Player_energy <= 0:
		alive = false
		$Sprite2D.hide()
		$Area2D.hide()
		$Player_energy.text ="DEAD"
		collision_layer = 0
		collision_mask = 1
		$RespawnButton.show()
		pass
		
func Respwan():
		World.Player_energy = 100
		alive = true
		$Sprite2D.show()
		$Area2D.show()
		#$Player_energy.text ="DEAD"
		collision_layer = 4
		collision_mask = 1#5
		$RespawnButton.hide()
	

func _on_area_2d_body_entered(body):
	interact_array.append(body)
	if body.has_method("Eat"):
		body.displayLabel(true) 


func _on_area_2d_body_exited(body):
	interact_array.erase(body)
	if body.has_method("Eat"):
		body.displayLabel(false) 


func _on_respawn_button_pressed():
	Respwan() # Replace with function body.
	
	


