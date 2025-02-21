extends Node
'global script for the behaviour loop'

var all_life = null
var state_array = []
var action_array = [] # 0:idle, 1:food 2: Danger

func BrainLoopCPU(folder):
	all_life = folder.get_children()
	var temp = state_array.duplicate()
	var l = 0
	if all_life != null:
		while l != -1:
			l = temp.find(1)
			temp[l] += 1
			if l > 0:


				if GoAwayToDanger(l, folder) == false:
					if isHungry(l):
						setAction(l,1)			
					if isFull(l):
						setAction(l,0)	
					DoAction(l,folder)



func Init_Brain():
	state_array.resize(Life.max_life)
	state_array.fill(-1)
	action_array.resize(Life.max_life)
	action_array.fill(-1)	
	
func setRandomDirection(INDEX):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	if Life.Genome[genome_index]["movespeed"][current_cycle] > 0:
		var rng = RandomNumberGenerator.new()
		Life.parameters_array[INDEX*Life.par_number+4] =rng.randi_range(-1,1)
		Life.parameters_array[INDEX*Life.par_number+5] =rng.randi_range(-1,1)
	else:
		Life.parameters_array[INDEX*Life.par_number+4] =0
		Life.parameters_array[INDEX*Life.par_number+5] =0

func goToClosestFood(INDEX,folder):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	var rng = RandomNumberGenerator.new()
	var direction = Vector2(rng.randi_range(-1,1),rng.randi_range(-1,1))
	if folder.has_node(str(INDEX)):
		var entity_active = folder.get_node(str(INDEX))
		var rangeofview = 40*World.tile_size		
		for life in entity_active.vision_array:
			if life.is_in_group("Life") and life.name != str(INDEX):	
				var t_index = int(str(life.name))
				if Life.state_array[t_index]>0:
					var t_genome_index = Life.parameters_array[t_index*Life.par_number]
					var t_current_cycle = Life.parameters_array[t_index*Life.par_number+3]
					if Life.Genome[t_genome_index]["composition"][t_current_cycle] == Life.Genome[genome_index]["digestion"][current_cycle] :
						var distance = entity_active.position.distance_to(life.position)
						if distance < rangeofview:
							rangeofview = distance
							direction = (life.position - entity_active.position).normalized()
												
		Life.parameters_array[INDEX*Life.par_number + 4] = direction.x
		Life.parameters_array[INDEX*Life.par_number + 5] =  direction.y



func GoAwayToDanger(INDEX, folder) :
	var dangerclose = false
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	var direction = Vector2(0,0)
	if folder.has_node(str(INDEX)):
		var entity_active = folder.get_node(str(INDEX))
		var rangeofview = 10*World.tile_size		
		for life in entity_active.vision_array:
			if life.is_in_group("Life") and life.name != str(INDEX):	
				var t_index = int(str(life.name))
				if Life.state_array[t_index]>0:
					var t_genome_index = Life.parameters_array[t_index*Life.par_number]
					var t_current_cycle = Life.parameters_array[t_index*Life.par_number+3]
					if t_genome_index == 4 :
						var distance = entity_active.position.distance_to(life.position)
						if distance < rangeofview:
							dangerclose = true
							rangeofview = distance
							direction = -(life.position - entity_active.position).normalized()
	Life.parameters_array[INDEX*Life.par_number + 4] = direction.x
	Life.parameters_array[INDEX*Life.par_number + 5] =  direction.y
	return dangerclose

func isHungry(INDEX):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	if Life.parameters_array[INDEX*Life.par_number+2] < Life.Genome[genome_index]["maxenergy"][current_cycle]/2:
		return true
	else:
		return false
		
func isFull(INDEX):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	if Life.parameters_array[INDEX*Life.par_number+2] >= Life.Genome[genome_index]["maxenergy"][current_cycle]:
		return true
	else:
		return false

func setAction(INDEX,action):
	action_array[INDEX]=action


func DoAction(INDEX,folder):
	if action_array[INDEX]== 1:
		goToClosestFood(INDEX,folder)
	if action_array[INDEX]== 0:
		setRandomDirection(INDEX)
	'if action_array[INDEX]== 2:
		isCloseToDanger(INDEX,folder)'


'func Move(INDEX):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	if Life.Genome[genome_index]["movespeed"][current_cycle] > 0:
		setDirection(INDEX)
		var posIndex = Life.world_matrix.find(INDEX)
		var directionx = Life.parameters_array[INDEX*Life.par_number+4]
		var directiony = Life.parameters_array[INDEX*Life.par_number+5]
		var x = posIndex % (World.world_size*Life.life_size_unit) 
		var y = floor(posIndex/(World.world_size*Life.life_size_unit))				
		var newPosX =  x + Life.Genome[genome_index]["movespeed"][current_cycle]*directionx
		var newPosY =  y + Life.Genome[genome_index]["movespeed"][current_cycle]*directiony
		newPosX = max(0,newPosX)
		newPosX = min(newPosX, World.world_size*Life.life_size_unit)
		newPosY = max(0,newPosY)
		newPosY = min(newPosY, World.world_size*Life.life_size_unit)
		#world_matrix[posIndex] = -1
		if y != newPosY or x != newPosX:
			Life.world_matrix[newPosX + newPosY*World.world_size] = INDEX
			Life.world_matrix[posIndex] = -1'
	
