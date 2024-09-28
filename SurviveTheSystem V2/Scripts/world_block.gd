extends Node2D

var x = 0
var y = 0
var posindex
var current_value = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	x = int(position.y/World.tile_size)
	y = int(position.x/World.tile_size)
	posindex = x*World.world_size + y
	current_value =  World.block_element_array[posindex]
	$ColorRect.color = getAdjustedSoilColor()
	#$outsideline.color = getAdjustedSoilColor()
	pass # Replace with function body.


#Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	###$debug.text = str("%.1f" % World.block_element_array[posindex])
	##'if Life.world_matrix[posindex] == -1:
		##$ColorRect.hide()
	##else:
		##$ColorRect.show()
	##pass'
	#if abs(current_value - World.block_element_array[posindex]) > 1 :
		#$ColorRect.color = getAdjustedSoilColor()
		#current_value = World.block_element_array[posindex]
		##$outsideline.color = getAdjustedSoilColor()

func BlockUpdate():
		$ColorRect.color = getAdjustedSoilColor()
		#$debug.text = str(posindex)
		pass
		#$outsideline.color = getAdjustedSoilColor()

func getAdjustedSoilColor():
	var colormax = Color(0.3, 0.2, 0.1, 1)
	var colormin = Color(0.8, 0.6, 0.4, 1)
	var x = min(1, World.block_element_array[posindex]/10. )
	var col = lerp(colormin, colormax, x)
	#$debug.text = "%0.1f" % World.block_element_array[posindex]
	return col


func isOutofFieldOfView():
	var player_pos_x =Life.parameters_array[Life.player_index*Life.par_number + 6]  
	var player_pos_y =Life.parameters_array[Life.player_index*Life.par_number + 7]
	if position.x > player_pos_x + World.fieldofview*World.tile_size:
		return true
	if position.y > player_pos_y + World.fieldofview*World.tile_size:
		return true
	if position.x < player_pos_x - World.fieldofview*World.tile_size:
		return true
	if position.y < player_pos_y - World.fieldofview*World.tile_size:
		return true
	else:
		return false

func ActivateAndDesactivateBlockAroundPlayer():
	var player_dir_x = Life.parameters_array[Life.player_index*Life.par_number + 4]  
	var player_dir_y =Life.parameters_array[Life.player_index*Life.par_number + 5]  
	var player_pos_x =Life.parameters_array[Life.player_index*Life.par_number + 6]  
	var player_pos_y =Life.parameters_array[Life.player_index*Life.par_number + 7] 
	var player_pos = World.getWorldPos(Vector2(player_pos_x,player_pos_y))
	var blockpos = World.getWorldPos(position)
	#right border
	if player_dir_x < 0 :
		if blockpos.x >  World.fieldofview*2 - 1:
			if blockpos.x > (player_pos.x + World.fieldofview):
				var b_pos = position.x - World.fieldofview*2*World.tile_size
				position.x = max(0, b_pos)
				var newpos =World.getWorldPos(position)
				posindex = newpos.y*World.world_size + newpos.x	
	#left	
	if player_dir_x > 0 :
		if blockpos.x < World.world_size - World.fieldofview*2:
			if blockpos.x < (player_pos.x - World.fieldofview):
				var b_pos = position.x + World.fieldofview*2*World.tile_size
				position.x = min(World.world_size*World.tile_size-1, b_pos)
				var newpos = World.getWorldPos(position)
				posindex = newpos.y*World.world_size + newpos.x
	#bottom border
	if player_dir_y < 0 :
		if blockpos.y >  World.fieldofview*2 - 1:
			if blockpos.y > (player_pos.y + World.fieldofview):
				var b_pos = position.y - World.fieldofview*2*World.tile_size
				position.y = max(0, b_pos)
				var newpos =World.getWorldPos(position)
				posindex = newpos.y*World.world_size + newpos.x	
	#top border	
	if player_dir_y > 0 :
		if blockpos.y < World.world_size - World.fieldofview*2:
			if blockpos.y < (player_pos.y - World.fieldofview):
				var b_pos = position.y + World.fieldofview*2*World.tile_size
				position.y = min(World.world_size*World.tile_size-1, b_pos)
				var newpos = World.getWorldPos(position)
				posindex = newpos.y*World.world_size + newpos.x
								
		
		
		
		#var s = Time.get_ticks_msec() 

		#var s2 = Time.get_ticks_msec() 

		#print("filtre is " + str(s2-s))


		#var s3 = Time.get_ticks_msec() 
		#print("loop is " + str(s3-s2))










func _on_visible_on_screen_notifier_2d_screen_exited():
	get_parent().get_parent().allblocks.erase(self)
	pass
	'if Life.player.input_dir != Vector2(0,0):
		print(World.fieldofview)
		$ColorRect.color = Color(0,0,1,1)
		var newpos = position #Life.player.position - (position - Life.player.position)


		#var direction = (position -  Life.player.position).normalized()
				
		if Life.player.input_dir.x != 0  and Life.player.input_dir.y != 0:
			if Life.player.input_dir == Vector2(1,1):	
				if position.y < Life.player.position.y - (World.fieldofview.y* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size ) * Vector2(0,1) 
				if position.x < Life.player.position.x - (World.fieldofview.x* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size )* Vector2(1,0)			
			elif Life.player.input_dir == Vector2(-1,-1):	
				if position.y > Life.player.position.y + (World.fieldofview.y* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size ) * Vector2(0,-1) 
				if position.x > Life.player.position.x + (World.fieldofview.x* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size )* Vector2(-1,0)			
			elif Life.player.input_dir == Vector2(1,-1):	
				if position.y > Life.player.position.y + (World.fieldofview.y* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size ) * Vector2(0,-1) 
				if position.x < Life.player.position.x - (World.fieldofview.x* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size )* Vector2(1,0)			
			elif Life.player.input_dir == Vector2(-1,1):	
				if position.y < Life.player.position.y - (World.fieldofview.y* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size ) * Vector2(0,1) 
				if position.x > Life.player.position.x + (World.fieldofview.x* World.tile_size)/2:
					newpos += (World.fieldofview * World.tile_size + Vector2(1,1)*World.tile_size )* Vector2(-1,0)			
												
			
		else:

			newpos += World.fieldofview * World.tile_size * Life.player.input_dir 
				

		if newpos.x > 0 and newpos.y > 0 and newpos.x < World.world_size*World.tile_size and newpos.y < World.world_size*World.tile_size:
			position = newpos

			var newworldpos = World.getWorldPos(position)
			var newposindex = newworldpos.y*World.world_size + newworldpos.x
			posindex = newposindex
			BlockUpdate()	'


func _on_visible_on_screen_notifier_2d_screen_entered():
	get_parent().get_parent().allblocks.append(self) # Replace with function body.
	BlockUpdate()
	#$ColorRect.color = Color(0,0,1,1)
