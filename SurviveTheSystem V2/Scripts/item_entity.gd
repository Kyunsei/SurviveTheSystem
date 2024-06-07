extends Area2D


var inUse = false
var isThrown = false
var isEquipped = false
var interact_array = []
var INDEX = 0
var user_INDEX = -1

var inter_value = 0

var start_pos = Vector2(0,0)
var direction_throw = Vector2(0,0)

var iteminfo_index =  0

# Called when the node enters the scene tree for the first time.
func _ready():
	iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	setSprite() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

	
func _physics_process(delta):
		if isThrown:
			Throwing()
		
		global_position.x = clamp(global_position.x, 0, World.world_size*World.tile_size)
		global_position.y = clamp(global_position.y, 0, World.world_size*World.tile_size)
		


func setSprite(TYPE=0):
	var item_index = Item.item_array[INDEX*Item.par_number]
	var size = Item.item_information[item_index]["sprite"][0].get_size()
	$Sprite.texture = Item.item_information[item_index]["sprite"][0]
	#$Sprite.offset.x = -1 * (Item.item_information[item_index]["sprite"][0].get_width()-Life.life_size_unit)/2#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	$Sprite.offset.y = -1 * Item.item_information[item_index]["sprite"][0].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	if TYPE == 1:
			size = Item.item_information[item_index]["sprite_empty"][0].get_size()
			$Sprite.texture = Item.item_information[item_index]["sprite_empty"][0]
			$Sprite.offset.y = -1 * Item.item_information[item_index]["sprite_empty"][0].get_height()#*(Life.Genome[genome_index]["sprite"][1].get_height()/Life.life_size_unit )
	#$CollisionShape2D/DebugRect2.position = position
	AdjustPhysics()
 
func AdjustPhysics():
	var width = $Sprite.texture.get_width()
	var height = $Sprite.texture.get_height()	
	var image_size = $Sprite.texture.get_size()
	$CollisionShape2D.shape.size =  Vector2(image_size[0]*3,image_size[1]*4) #image_size *2
	$CollisionShape2D.position =  Vector2(-width/2,-height/2)
	
	
	$CollisionShape2D/DebugRect2.size = $CollisionShape2D.shape.size
	$CollisionShape2D/DebugRect2.position -= $CollisionShape2D/DebugRect2.size/2


func ActivateItem(user_index): # button use
	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	if Item.item_information[iteminfo_index]['use'][0] == 2:
		var x = int(position.y/World.tile_size)
		var y = int(position.x/World.tile_size)
		var posindex = 0
		#if Item.item_array[INDEX*Item.par_number+2]==1:	 #full		
		for i in range(3):
			for j in range(3):
				posindex = (x+i)*World.world_size + y+j
				World.block_element_array[posindex] += 10# inter_value /(3*3)		
		#Item.item_array[INDEX*Item.par_number+2]=0		
			#inter_value = 0
			#setSprite(1)
	else : 
		print("use: nothing happen")
		'elif Item.item_array[INDEX*Item.par_number+2]==0: #empty
			for i in range(3):
				for j in range(3):	
					posindex = (x+i)*World.world_size + y+j
					inter_value += World.block_element_array[posindex]
					World.block_element_array[posindex] = 0 #Item.item_information[iteminfo_index]["value"][0]
			Item.item_array[INDEX*Item.par_number+2]=1
			setSprite(0)'

func AttackItem(user_index):
	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	if Item.item_information[iteminfo_index]['attack'][0] == 1:

		$CollisionShape2D/DebugRect2.show()
		$Timer.start(0)
		ApplyDamage()
					
	else :
		print("attack: nothing happen")

func ApplyDamage():
	for i in interact_array:
		if i != null:
			Life.parameters_array[i.INDEX*Life.par_number+1] -= Item.item_information[iteminfo_index]['damagevalue'][0]
			if Life.Genome[Life.parameters_array[i.INDEX*Life.par_number]]["movespeed"][Life.parameters_array[i.INDEX*Life.par_number+3]] > 0:
				i.global_position += global_position.direction_to(i.global_position) *64

func BeEaten (user_index):
	#var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	var genome_index = Life.parameters_array[user_index*Life.par_number+0]
	var current_cycle = Life.parameters_array[user_index*Life.par_number+3]
	if Item.item_information[iteminfo_index]['eat'][0] == 1:
		if Life.parameters_array[user_index*Life.par_number+2] < Life.Genome[genome_index]["maxenergy"][current_cycle]:
			Life.parameters_array[user_index*Life.par_number+2] += 10
			Life.parameters_array[user_index*Life.par_number+1] -= 9
			queue_free()
	#print("Best print BEaten")
	
func BeThrown (user_index):
	print("This thing was thrown")
	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	var distance = 100*Item.item_information[iteminfo_index]['throw'][0]
	direction_throw = Vector2(Life.parameters_array[user_index*Life.par_number+4],Life.parameters_array[user_index*Life.par_number+5])
	
	if Item.item_information[iteminfo_index]['throw'][0] > 0:
		start_pos = global_position
		isThrown = true
		$CollisionShape2D/DebugRect2.show()


func Throwing():
	var iteminfo_index = Item.item_array[INDEX*Item.par_number + 0]
	var distance = 100*Item.item_information[iteminfo_index]['throw'][0]
	var speed = 10.
	if start_pos.distance_to(global_position) < distance:
		global_position += direction_throw*speed
	else:
		isThrown = false
		$CollisionShape2D/DebugRect2.hide()
	
	#holded item speed = 1000
	#wait 2 sec
	#holded item speed =-1000
	#Set direction towards player cursor
	
func _on_timer_timeout():
	$CollisionShape2D/DebugRect2.hide()
	#queue_free() # Replace with function body.



func _on_area_entered(area):
	if area.is_in_group("Life") and isEquipped == true:

		if area.get_parent().INDEX != user_INDEX:
			interact_array.append(area.get_parent()) # Replace with function body.				
	elif isThrown:
		if area.is_in_group("Life"):
			if area.get_parent().INDEX != user_INDEX:
				Life.parameters_array[area.get_parent().INDEX*Life.par_number+1] -= Item.item_information[iteminfo_index]['damagevalue'][0]
func _on_area_exited(area):
	if area.is_in_group("Life") and isEquipped == true:
		interact_array.erase(area.get_parent()) # Replace with function body. # Replace with function body.
