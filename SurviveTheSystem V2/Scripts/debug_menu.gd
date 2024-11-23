extends Control


var energy_spawn_value: int
var energy_spawn_isActivate: bool = false
var energy_spawn_radius: int

# Called when the node enters the scene tree for the first time.
func _ready():
	init_value_world()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_show_button_pressed():
	$Panel.show()
	$ShowButton.hide()


func _on_hide_button_pressed():
	$Panel.hide() # Replace with function body.
	$ShowButton.show()


func _on_world_button_pressed():
	$Panel/World_Debug.show()
	init_value_world()
	$Panel/Alife_Debug.hide()


func _on_alife_button_pressed():
	$Panel/World_Debug.hide()
	$Panel/Alife_Debug.show()



func init_value_world():
	$Panel/World_Debug/option/world/world_speed/LineEdit_wspeed.text = str(World.speed)
	
	$Panel/World_Debug/option/energy_diffusion/speed/LineEdit_speed.text = str(World.diffusion_speed)
	$Panel/World_Debug/option/energy_diffusion/factor/LineEdit_factor.text = str(World.diffusion_factor)
	$Panel/World_Debug/option/energy_diffusion/minvalue/LineEdit_min.text = str(World.diffusion_min_limit)

	$Panel/World_Debug/option/spawn_energy/edit_energy/LineEdit_spawnenergy.text = str(energy_spawn_value)
	$Panel/World_Debug/option/spawn_energy/radius/LineEdit_radius.text = str(energy_spawn_radius)


func _on_line_edit_wspeed_text_submitted(new_text):
	World.speed = float(new_text)
	get_parent().get_parent().UpdateSimulationSpeed()


func _on_line_edit_speed_text_submitted(new_text):
	World.diffusion_speed = float(new_text)
	get_parent().get_parent().UpdateSimulationSpeed()


func _on_line_edit_factor_text_submitted(new_text):
	World.diffusion_factor = float(new_text)


func _on_line_edit_min_text_submitted(new_text):
	World.diffusion_min_limit = float(new_text)


func _on_line_edit_spawnenergy_text_submitted(new_text):
	energy_spawn_value = int(new_text)

func _on_check_box_toggled(toggled_on):
	energy_spawn_isActivate = toggled_on


func _on_lineedit_radius_text_submitted(new_text):
	energy_spawn_radius = int(new_text)


func _input(event):
	if energy_spawn_isActivate:
		# Mouse in viewport coordinates.
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				#if Life.player != null:
				#var mouse_position = event.position / get_viewport().get_camera_2d().zoom + Life.player.position - get_viewport().get_visible_rect().size / 2			
				#adjust_soil(mouse_position, energy_spawn_value , energy_spawn_radius)
				var mouse_position =get_viewport().get_camera_2d().get_global_mouse_position()
				#print(mouse_position)
				draw_block(mouse_position,energy_spawn_value, energy_spawn_radius)

func draw_block(mouse_position, value, radius):
			var center_x = int(mouse_position.x/World.tile_size)
			var	center_y = int(mouse_position.y/World.tile_size)
			for x in range(center_x - radius, center_x + radius + 1):
				for y in range(center_y - radius, center_y + radius + 1):
					if (x - center_x) * (x - center_x) + (y - center_y) * (y - center_y) <= radius * radius:
						var posindex = y*World.world_size + x
						if posindex < World.block_element_array.size() and posindex >= 0:
							print(World.block_element_array[posindex])				
							World.block_element_array[posindex]	= value
							get_parent().get_parent().get_node("World_TileMap").draw_new_tiles_according_to_soil_value(0, [Vector2i(x,y)])
							#get_parent().get_parent().get_node("World_TileMap").update_ALL_tilemap_tile_to_new_soil_value()
							#get_parent().get_parent().get_node("World_TileMap").update_tilemap_tile_array_to_new_soil_value(0, [Vector2i(x,y)])
						
