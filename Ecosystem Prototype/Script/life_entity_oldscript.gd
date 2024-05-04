'''
Generic script to determine the behaviour of life forms.

It consists of:
	Inner ressources management
	Reproduction
	Behaviour
	Adpatation/ evolution

'''

extends RigidBody2D

#Graphique variable
var parameters = {
	"artpath" : ["res://art/grass.png"],
	"size" : [1.0],
	"foodtype" : "grass",
	"digestiontype" : "soil",
	"moveSpeed" : 0	,
	"seedtime" : 0. ,
	"energyLifeCycleCost" : [10.],
	"seedenergy" : 5.,
	"spreaddistance" : 5.,
	"metabospeed" : 1.,
	"foodabsorbtion" : 5.,
	#"foodabsorbtiondistance" : 5.,
	"energyHomeostasisCost" : 2.,
	"force" : 0.,
	"agelimit": 10,
	"behaviourspeed": 1,
	"weight": 1.,
	"layer": 4,
	"mask": 1#5	
}

var blockpos_all = null
var isSleeping = false
var isSeed = true
var life_state = 0
var age = 0
var energy = 0
var alive = true
var isInInventory = false

var out = false	

var direction = Vector2(0,0)
var tiles_array = []

var life_size_unit= World.life_size_unit
var life_scene = load("res://Scene/life_entity.tscn")


var width : int
var factor : float# float(width/ life_size_unit / parameters.size[life_state])
var imageSize : Vector2

var foodabsorbed : float
var foodleft: float	

# Called when the node enters the scene tree for the first time.
func _ready():

	$Timer.wait_time = (parameters.metabospeed + randf_range(-0.25, 0.25)*parameters.metabospeed )  / World.World_Speed
	#$Timer.wait_time = parameters.metabospeed   / World.World_Speed
	$BehaviourTimer.wait_time = (parameters.behaviourspeed + randf_range(-0.5, 0.5))  / World.World_Speed
	AdjustPhysics()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	if alive == false:
		Die()
	else:
		if parameters.moveSpeed >0 :
			Move()



func _on_timer_timeout():
	tiles_array = []
	#if parameters.digestiontype=="soil":
	if isInInventory == false:
		checkreproduce()
		growth()
		if isSeed == false:
			energyCosumption()
			getenergy() 
		age = age + 1.0/ (( World.Day_time + World.Night_time)/parameters.metabospeed )
		#$Label.text = "energy: " + str("%.2f" % energy)  +"\nage:" + str(age)	
		checkDeath()


func UpdateSimulationSpeed():
	$Timer.wait_time = (parameters.metabospeed   + randf_range(-0.25, 0.25)*parameters.metabospeed ) / World.World_Speed
	#$Timer.wait_time = parameters.metabospeed   / World.World_Speed
	$BehaviourTimer.wait_time = parameters.behaviourspeed  / World.World_Speed
	$Timer.start(0)
	linear_velocity = Vector2(0,0)
	#$BehaviourTimer.start(0)

func AdjustPhysics():
	if life_state >= parameters.artpath.size():
			$Sprite2D.texture = load(parameters.artpath[-1])
	else:	
		$Sprite2D.texture = load(parameters.artpath[life_state])
	width = $Sprite2D.texture.get_width()
	factor =  float(width/ life_size_unit / parameters.size[life_state])
	$Sprite2D.scale = Vector2(1/factor,1/factor)	
	imageSize = $Sprite2D.texture.get_size()/factor	
	$CollisionShape2D.shape.size = imageSize# Vector2(size1,size1)# $RigidBody2D/Sprite2D.texture.get_size()
	mass = parameters.weight
	collision_layer = parameters.layer
	$Area2D/CollisionShape2D.shape.size = $CollisionShape2D.shape.size + Vector2(1,1)	
	collision_mask = parameters.mask
	if parameters.size[life_state] <=1. :
		add_to_group("Tool")
	if parameters.size[life_state] > 1. and is_in_group("Tool"):
		remove_from_group("Tool")

func Move():

		var moveVector = Vector2(0,0)
		#var speed = parameters.moveSpeed * World.World_Speed
		if global_position.x <= (World.instantiateRange+2)*World.tile_size:
			linear_velocity = Vector2(0,0)
			direction = Vector2(1,0)
		if global_position.x >= (World.Map_size[0]-World.instantiateRange-2)*World.tile_size:
			linear_velocity = Vector2(0,0)
			direction = Vector2(-1,0)
		if global_position.y <= (World.instantiateRange+2)*World.tile_size:
			linear_velocity = Vector2(0,0)
			direction = Vector2(0,1)
		if global_position.y >= (World.Map_size[1]-World.instantiateRange-2)*World.tile_size:
			linear_velocity = Vector2(0,0)
			direction = Vector2(0,-1)
					
		moveVector = direction*parameters.moveSpeed * World.World_Speed	
		apply_impulse(moveVector)


		

	
func InitLife():
	energy = energy - parameters.energyLifeCycleCost[0] - parameters.seedenergy
	var newgrass = life_scene.instantiate()
	var newPos = PickRandomPlace()
	newgrass.position.x = newPos[0]
	newgrass.position.y = newPos[1]
	newgrass.parameters = parameters
	newgrass.life_state = 0
	newgrass.energy = parameters.seedenergy #parameters.energyReproductionCost
	get_parent().add_child(newgrass)


	#life_entities.append(newgrass)



func checkreproduce():
	if energy > (parameters.energyLifeCycleCost[0] + parameters.seedenergy):
		if life_state == parameters.energyLifeCycleCost.size()-1:	
			InitLife()

		

func getenergy():
	foodabsorbed = 0# parameters.foodabsorbtion
	if blockpos_all == null:
		blockpos_all = getBlockPos()
	for blockpos in blockpos_all:
		foodleft = World.Block_Matrix[blockpos[0]][blockpos[1]][3][0] -  float(parameters.foodabsorbtion)/blockpos_all.size()
		if foodleft < 0:
				foodabsorbed = foodabsorbed + float(parameters.foodabsorbtion)/blockpos_all.size() + foodleft
				foodleft= 0
		else:
				foodabsorbed = foodabsorbed + float(parameters.foodabsorbtion)/blockpos_all.size()
		World.Block_Matrix[blockpos[0]][blockpos[1]][3][0] = foodleft
		get_parent().tiles_to_update.append([blockpos[0],blockpos[1]])	
	energy = energy + foodabsorbed
	
'	for tile in tiles_array:
		var energybytile = float(parameters.foodabsorbtion)/tiles_array.size()


		var foodleft = tile.energy - energybytile
		if foodleft < 0:
			foodabsorbed = foodabsorbed + energybytile + foodleft
			foodleft= 0
		else:
			foodabsorbed = foodabsorbed + energybytile
		tile.energy = foodleft
		tile.Update()
	energy = energy + foodabsorbed
'



func PickRandomPlace():

	var random_x = randf_range(parameters.spreaddistance*-1, parameters.spreaddistance)
	var random_y = randf_range(parameters.spreaddistance*-1, parameters.spreaddistance)

	var x = max(global_position.x + random_x*life_size_unit, (World.BufferZoneSize/2+1)*World.tile_size)
	x = min(x, (World.Map_size[0]-1)*World.tile_size - World.BufferZoneSize/2*World.tile_size)
	
	var y = min(global_position.y + random_y*life_size_unit, (World.Map_size[1]-1)*World.tile_size - World.BufferZoneSize/2*World.tile_size)
	y = max(y, (World.BufferZoneSize/2+1)*World.tile_size)
	
	return [x,y]


func getBlockPos():
	var blockpos_all = []
	for i in range(-parameters.size[life_state],parameters.size[life_state]):
		for j in range(-parameters.size[life_state],parameters.size[life_state]):
			
			var blockpos = Vector2(global_position) - Vector2(parameters.size[life_state]*World.life_size_unit/2,parameters.size[life_state]*World.life_size_unit/2)
			blockpos =Vector2i(roundi(blockpos[0]/World.tile_size),roundi(blockpos[1]/World.tile_size))
			#-Vector2(World.life_size_unit*i,World.life_size_unit*j)/2	
			blockpos = blockpos + Vector2i(i/2,j/2)	 #- Vector2i(roundi(parameters.size[life_state]/2),roundi(parameters.size[life_state]/2))
			if blockpos_all.has(blockpos) == false:
				blockpos_all.append(blockpos)
	return blockpos_all

	

func energyCosumption():
	energy = energy - parameters.energyHomeostasisCost
	#World.Soil_food += parameters.energyHomeostasisCost
	transferEnergy(parameters.energyHomeostasisCost)


func transferEnergy(number):
	if blockpos_all == null:
		blockpos_all = getBlockPos()
	for blockpos in blockpos_all:
		World.Block_Matrix[blockpos[0]][blockpos[1]][3][0] += number/blockpos_all.size()
		get_parent().tiles_to_update.append([blockpos[0],blockpos[1]])	

		
func checkDeath():
	if energy <= 0:
		alive = false
	if age > parameters.agelimit:
		alive = false


func killed():
	alive = false


func Die():
		transferEnergy((energy+parameters.energyLifeCycleCost[life_state]))
		queue_free()


func growth():


	parameters.agelimit
	'energyLifeCycleCost of 0 = seed'
	if parameters.energyLifeCycleCost[0]!=0 and isSeed == true:		
		isSeed = false
	if age > parameters.seedtime and life_state < parameters.energyLifeCycleCost.size()-1 :
		if energy >  parameters.energyLifeCycleCost[life_state+1]:
			isSeed = false
			life_state += 1
			energy = energy - parameters.energyLifeCycleCost[life_state]
			position.y = position.y - parameters.size[life_state]*World.life_size_unit/4   #just for aesthtic
			AdjustPhysics()
	
	#Doesn't work
	pass
	
func change_direction():
	var rng = RandomNumberGenerator.new()
	var random_x = rng.randf_range(-1, 1)
	var random_y = rng.randf_range(-1, 1)
	direction = Vector2(random_x ,random_y)
	

func Eat(B):
		if B.parameters.foodtype == parameters.digestiontype:
			energy += B.energy + B.parameters.energyLifeCycleCost[B.life_state]
			B.energy = 0
			B.alive = false
			$Label.text = "energy: " + str("%.2f" % energy)  +"\nage:" + str(age)	



func displayLabel(display):
	if display:
		$Label.show()
	else:
		$Label.hide()



func Action(Actor, interact_array):
	if(parameters.force<1 ):
		World.Player_energy += energy + parameters.energyLifeCycleCost[life_state]
		energy = 0
		alive=false
		Actor.DropTool()

func _on_behaviour_timer_timeout():
	change_direction()
	pass # Replace with function body.


func _on_mouse_entered():
	$Label.show() # Replace with function body.


func _on_mouse_exited():
	$Label.hide() # Replace with function body.


func _on_area_2d_body_entered(body):
	
	if body.name.match("Player"):
		pass
		'''
		if(parameters.force<1 and parameters.foodtype=="berry" ): #and parameters.foodtype=="berry"):
			World.Player_energy += energy + parameters.energyReproductionCost
			energy = 0
			alive = false
		'''
		if(parameters.force>1 ):
			energy += World.Player_energy
			World.Player_energy = 0 		
			 
			#update_number(-1)
			#queue_free()
	else:
			if body.is_in_group("Life"):
				if  parameters.force > body.parameters.force:

					if energy < parameters.seedenergy*1.5 + parameters.energyLifeCycleCost[life_state]:
						Eat(body) 

