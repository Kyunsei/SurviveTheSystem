extends TileMap



var c = 0
var color_list = [Color.DARK_RED,Color.CADET_BLUE,Color.YELLOW_GREEN,Color.BEIGE]

func build_world():
	#iland center: [(47,120),(140,140)
	#island size: 
	var island_center = [Vector2i(68,68),Vector2i(132,68),Vector2i(100,100),Vector2i(68,132),Vector2i(132,132)]
	var island_size = [20,20,20,20,20]
	var island_energy = [1,2,0,0,0]
	var factor = 1

	for i in range(island_center.size()):
		draw_round_island(island_center[i].x*factor,island_center[i].y*factor,island_size[i]*factor,island_energy[i])

		if i > 1:
			var rnd = randi_range(10,20)
			for p in range(rnd):
				draw_energy_patch((island_center[i].x + randi_range(-island_size[i],island_size[i]))*factor,(island_center[i].y + randi_range(-island_size[i],island_size[i]))*factor,randi_range(2,3)*factor,randi_range(5,10))	
			
	'draw_round_island(140*factor,140*factor,20*factor,5)
	draw_round_island(124*factor,124*factor,12*factor,3)
	draw_round_island(76*factor,124*factor,12*factor,0)
	draw_round_island(100*factor,100*factor,25*factor,3)
	draw_round_island(124*factor,76*factor,12*factor,12)	
	draw_round_island(76*factor,76*factor,12*factor,3)
	draw_round_island(40*factor,40*factor,40*factor,7)				
	draw_round_island(110*factor,60*factor,12*factor,3)	
	draw_round_island(115*factor ,40*factor,12*factor,7)'
	
	update_ALL_tilemap_tile_to_new_soil_value()
	draw_navigation()

func draw_round_island(x,y,radius,energy):
	x=  x-radius
	y=  y-radius
	#var randomlist = [0,0,0,1,0,1]
	var center = Vector2(radius,radius)
	for w in range(0,radius*2+1):
		for h in range(0,radius*2+1):
			#if World.block_element_state[(x+w)*World.world_size +y+h ] == -1 :
			if get_cell_atlas_coords(0, Vector2i(x+w, y+h)) != Vector2i(0, 0):
				var distance = center.distance_to(Vector2(w, h))
				if distance < radius :
						World.block_element_state[(y+h)*World.world_size +x+w ]= 1
						World.block_element_array[(y+h)*World.world_size +x+w  ]= energy#randomlist[randi_range(0,5)]*energy
						set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 0))
				if Vector2(w, h).distance_to(center) >= radius and Vector2(w, h).distance_to(center) < radius +2:
						World.block_element_state[(y+h)*World.world_size +x+w ]= 0
						if center.distance_to(Vector2(w, h-1))< radius:
							set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 1))
						else:
							set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 2))

func draw_energy_patch(x,y,radius,energy):
	x=  x-radius
	y=  y-radius
	var center = Vector2(radius,radius)
	for w in range(0,radius*2+1):
		for h in range(0,radius*2+1):
			#if World.block_element_state[(x+w)*World.world_size +y+h ] == -1 :
	
			if World.block_element_state[(y+h)*World.world_size +x+w ]== 1:
					var distance = center.distance_to(Vector2(w, h))
					if distance < radius :							
							World.block_element_array[(y+h)*World.world_size +x+w ]= energy
							#set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 0))
							#set_tile_according_to_soil_value(Vector2i(x+w, y+h))
	

func update_ALL_tilemap_tile_to_new_soil_value():
	var layer = 0
	var cells = split_array_into_four(get_used_cells(layer))
	update_tilemap_tile_array_to_new_soil_value(layer, cells[0])
	await get_tree().create_timer(0.1).timeout
	update_tilemap_tile_array_to_new_soil_value(layer, cells[1])
	await get_tree().create_timer(0.1).timeout
	update_tilemap_tile_array_to_new_soil_value(layer, cells[2])
	await get_tree().create_timer(0.1).timeout
	update_tilemap_tile_array_to_new_soil_value(layer, cells[3])


func update_tilemap_tile_array_to_new_soil_value(layer, cells):
	for cell in cells:
		var tile_id = get_cell_source_id(layer,cell)
		if tile_id != -1:
			var tile = get_cell_tile_data(layer,cell)
			var co = get_cell_atlas_coords(layer,cell)
			if co != Vector2i(0,2): #empty tile
				if co.y < 1: #border
					set_tile_according_to_soil_value(cell)
				#set_cell(0, cell, 0, Vector2i(0,co.y) + Vector2i(randi_range(0,3), 0))



func set_tile_according_to_soil_value(coord: Vector2i):
	var layer = 0
	var posindex = coord.y*World.world_size + coord.x
	if World.block_element_array[posindex] == 0 :
		set_cell(layer, coord, 0, Vector2i(3,0))
	elif World.block_element_array[posindex] <= 2 and World.block_element_array[posindex] != 0:
		set_cell(layer, coord, 0, Vector2i(2,0))
	elif World.block_element_array[posindex] <= 4 and World.block_element_array[posindex] > 2 :
		set_cell(layer, coord, 0, Vector2i(1,0))
	elif World.block_element_array[posindex] > 4 :
		set_cell(layer, coord, 0, Vector2i(0,0))

func draw_new_tiles_according_to_soil_value(layer, cells):
	for cell in cells:
		var tile_id = get_cell_source_id(layer,cell)
		var tile = get_cell_tile_data(layer,cell)
		var co = get_cell_atlas_coords(layer,cell)
		#if tile_id != -1:
		var posindex = cell.y*World.world_size + cell.x
		print(World.block_element_array[posindex])
		
		if World.block_element_array[posindex] >= 0:
			World.block_element_state[posindex] = 1
			set_tile_according_to_soil_value(cell)
			
			if get_cell_source_id(layer,cell+Vector2i(0,1)) != -1: #below cell exist
				if get_cell_atlas_coords(layer,cell+Vector2i(0,1)).y > 0: #below cell free
					set_cell(layer, cell+Vector2i(0,1), 0, Vector2i(0,1))
			else:
				set_cell(layer, cell+Vector2i(0,1), 0, Vector2i(0,1))

			if get_cell_source_id(layer,cell-Vector2i(0,1)) == -1: #above cell do not exist
				set_cell(layer, cell-Vector2i(0,1), 0, Vector2i(0,2))
			if get_cell_source_id(layer,cell-Vector2i(1,0)) == -1: #left cell do not exist
				set_cell(layer, cell-Vector2i(1,0), 0, Vector2i(0,2))
			if get_cell_source_id(layer,cell+Vector2i(1,0)) == -1: #right cell do not exist
				set_cell(layer, cell+Vector2i(1,0), 0, Vector2i(0,2))
		else:
			World.block_element_state[posindex] = 0
			if get_cell_source_id(layer,cell+Vector2i(0,-1)) != -1: 
				if get_cell_atlas_coords(layer,cell+Vector2i(0,-1)).y == 0: #above cell occupied
					set_cell(layer, cell, 0, Vector2i(0,1))
					
				else:
					set_cell(layer, cell, 0, Vector2i(0,2))
			else:
				set_cell(layer, cell, 0, Vector2i(0,2))
			if get_cell_atlas_coords(layer,cell+Vector2i(0,1)) == Vector2i(0,1):
				set_cell(layer, cell+Vector2i(0,1), 0, Vector2i(0,2))

		

				#set_cell(0, cell, 0, Vector2i(0,co.y) + Vector2i(randi_range(0,3), 0))
						


		
func split_array_into_four(arr):
	var length = arr.size()
	var split_size = ceil(length / 4.0)
	# Slice the array into four sub-arrays
	var array_1 = arr.slice(0, split_size)
	var array_2 = arr.slice(split_size, split_size*2)
	var array_3 = arr.slice(split_size * 2 , split_size*3)
	var array_4 = arr.slice(split_size * 3 , split_size*4)
	return [array_1, array_2, array_3, array_4]




func draw_navigation():
	'var size = 200#World.tile_size*World.tile_size

	var bounding_outline = PackedVector2Array([Vector2(0, 0), Vector2(0,size), Vector2(size, size), Vector2(size, 0)])
	new_navigation_mesh.add_outline(bounding_outline)'
	var new_navigation_mesh = $NavigationRegion2D.navigation_polygon # NavigationPolygon.new()
	$NavigationRegion2D.bake_navigation_polygon(true)

	#NavigationServer2D.bake_from_source_geometry_data(new_navigation_mesh, NavigationMeshSourceGeometryData2D.new());
	#$NavigationRegion2D.navigation_polygon = new_navigation_mesh


func _on_block_timer_timeout():
	pass
	World.BlockLoopGPU() 
	update_ALL_tilemap_tile_to_new_soil_value()
	
	
	

	
	
	
#############################3 NOT IN USE
	
	
		
'var _update_fn: Dictionary = {} # of Dictionary of Callable

var _update_fn1: Dictionary = {} # of Dictionary of Callable
var _update_fn2: Dictionary = {} # of Dictionary of Callable
var _update_fn3: Dictionary = {} # of Dictionary of Callable
var _update_fn4: Dictionary = {} # of Dictionary of Callable
var split = []



func split_dictionary_into_four(dict):
	var keys = dict.keys()
	var total_size = keys.size()
	var split_size = ceil(total_size / 4.0)

	# Initialize four empty dictionaries
	var dict_1 = {}
	var dict_2 = {}
	var dict_3 = {}
	var dict_4 = {}
	# Loop through keys and distribute them into the four dictionaries
	for i in range(total_size):
		var key = keys[i]
		var value = dict[key]
		if i < split_size:
			dict_1[key] = value
		elif i < split_size * 2:
			dict_2[key] = value
		elif i < split_size * 3:
			dict_3[key] = value
		else:
			dict_4[key] = value
	return [dict_1, dict_2, dict_3, dict_4]


# Custom function to change color of all tiles
func update_tilemap_tile(layer: int):
	# Get all used cells in the tilemap
	var cells = get_used_cells(layer)	
	# Loop through each cell and update the tiles color
	for cell in cells:
		#var tile_id = 0#get_cellv(cell)
		var tile_id = get_cell_source_id(layer,cell)
		if tile_id != -1:
			var tile = get_cell_tile_data(layer,cell)
			var co = get_cell_atlas_coords(layer,cell)
			if co.x < 3:	
				set_cell(0, cell, 0, co + Vector2i(1, 0))
			else:
				set_cell(0, cell, 0, co - Vector2i(3, 0))
			# Set modulate color for each tile
			#modulate_tile(cell, new_color)
			#tile_data.modulate = Color.RED
			
			
	

# Custom function to change color of all tiles
func update_tilemap_color(layer: int,new_color: Color):
	# Get all used cells in the tilemap
	var cells = get_used_cells(layer)	
	# Loop through each cell and update the tiles color
	for cell in cells:
		#var tile_id = 0#get_cellv(cell)
		var tile_id = get_cell_source_id(layer,cell)
		if tile_id != -1:
			var tile = get_cell_tile_data(layer,cell)
			tile.modulate = new_color
			# Set modulate color for each tile
			#modulate_tile(cell, new_color)
			#tile_data.modulate = Color.RED


func update_tile(layer: int, coords: Vector2i, fn: Callable):
	if not _update_fn.has(layer): _update_fn[layer] = {}
	_update_fn[layer][coords] = fn
	notify_runtime_tile_data_update(layer)

func update_tiles(layer: int, coords, fn: Callable):
	var s = Time.get_ticks_msec()
	if not _update_fn.has(layer): _update_fn[layer] = {}
	for i in coords:
		_update_fn[layer][i] = fn
	notify_runtime_tile_data_update(layer)
	var ss = Time.get_ticks_msec()
	print("time_uptate: " + str(ss-s) + "ms")

func _use_tile_data_runtime_update(layer: int, coords: Vector2i):
	if not _update_fn.has(layer): return false
	if not _update_fn[layer].has(coords): return false
	return true

func _tile_data_runtime_update(layer: int, coords: Vector2i, tile_data: TileData):
	if not _update_fn.has(layer): return false
	if not _update_fn[layer].has(coords): return false
	var fn: Callable = _update_fn[layer][coords]
	fn.call(tile_data)

	_update_fn[layer].erase(coords)'
