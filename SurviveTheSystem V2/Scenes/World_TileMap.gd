extends TileMap





func build_world():



	draw_round_island(47,120,12)	
	
	draw_round_island(140,140,20)
	
	draw_round_island(124,124,12)
	draw_round_island(76,124,12)
	draw_round_island(100,100,25)
	draw_round_island(124,76,12)	
	draw_round_island(76,76,12)
	
	
	draw_round_island(40,40,40)				
	draw_round_island(110,60,12)	
	draw_round_island(115,40,12)


func draw_round_island(x,y,radius):
	x=  x-radius
	y=  y-radius
	var center = Vector2(radius,radius)
	for w in range(0,radius*2+1):
		for h in range(0,radius*2+1):
			#if World.block_element_state[(x+w)*World.world_size +y+h ] == -1 :
			if get_cell_atlas_coords(0, Vector2i(x+w, y+h)) != Vector2i(0, 0):
				var distance = center.distance_to(Vector2(w, h))
				if distance < radius :
						World.block_element_state[(x+w)*World.world_size +y+h ]= 1
						set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 0))
				if Vector2(w, h).distance_to(center) >= radius and Vector2(w, h).distance_to(center) < radius +2:
						World.block_element_state[(x+w)*World.world_size +y+h ]= 0
						if center.distance_to(Vector2(w, h-1))< radius:
							set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(0, 1))
						else:
							set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(1, 0))
			'else:
				#merge temporary only
				#set_cell(0, Vector2i(x+w, y+h), 0, Vector2i(1, 0))
				World.block_element_state[(x+w)*World.world_size +y+h ]= 1
				#set_cell(x+w, y+h, 2)'
