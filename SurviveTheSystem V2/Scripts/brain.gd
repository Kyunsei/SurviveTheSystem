extends Node
'global script for the behaviour loop'

var all_life = null
var state_array = []

func BrainLoopCPU(folder):
	all_life = folder.get_children()
	var temp = state_array.duplicate()
	var l = 0
	if all_life != null:
		while l != -1:
			l = temp.find(1)
			temp[l] += 1
			if l > 0:
				#setDirection(l)
				goToClosest(l,folder)


func Init_Brain():
	state_array.resize(Life.max_life)
	state_array.fill(-1)
	
func setDirection(INDEX):
	var genome_index = Life.parameters_array[INDEX*Life.par_number+0]
	var current_cycle = Life.parameters_array[INDEX*Life.par_number+3]
	if Life.Genome[genome_index]["movespeed"][current_cycle] > 0:
		var rng = RandomNumberGenerator.new()
		Life.parameters_array[INDEX*Life.par_number+4] =rng.randi_range(-1,1)
		Life.parameters_array[INDEX*Life.par_number+5] =rng.randi_range(-1,1)
	else:
		Life.parameters_array[INDEX*Life.par_number+4] =0
		Life.parameters_array[INDEX*Life.par_number+5] =0

func goToClosest(INDEX,folder):

	var direction = Vector2(0,0)
	if folder.has_node(str(INDEX)):
		var entity_active = folder.get_node(str(INDEX))
		var rangeofview = 40*World.tile_size
		
		for life in entity_active.vision_array:
			if life.is_in_group("Life") and life.name != str(INDEX):	
				var t_index = int(str(life.name))
				if Life.parameters_array[t_index*Life.par_number] == 3:
					var distance = entity_active.position.distance_to(life.position)
					if distance < rangeofview:
						rangeofview = distance
						direction = (life.position - entity_active.position).normalized()
						
					
		Life.parameters_array[INDEX*Life.par_number + 4] = direction.x
		Life.parameters_array[INDEX*Life.par_number + 5] =  direction.y


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
	
