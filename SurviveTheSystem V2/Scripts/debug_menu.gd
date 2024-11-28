extends Control


var energy_spawn_value: int
var energy_spawn_isActivate: bool = false
var energy_spawn_radius: int
var alife_spawn_isActivate: bool = false
var alife_info_isActivate:bool = false

var alife_taget: LifeEntity


var species_selected : int
var age_selected : int
var energy_selected : int
# Called when the node enters the scene tree for the first time.
func _ready():
	init_value_world()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Life.player != null: #kindof waiting to init
		var text = ""
		for n in Life.life_number:
			text = text + "\n" + n + " " + str(Life.life_number[n]) +"/" + str(Life.pool_scene[n].size())

		$Panel/Alife_Debug/Option/info_all_alife.text = text
		
	if alife_taget != null:
		$Panel/Alife_Debug/Option/info/info_alife.text = "species/pool_ID: " + str(alife_taget.species) + " / "+  str(alife_taget.pool_index) + "\n"+ "PV: " + str(alife_taget.PV) + "/" + str(alife_taget.maxPV)  + "\n" + "E: " + "%0.2f" % alife_taget.energy + "/" + str(alife_taget.maxEnergy)  + "\n" + "age: " + str(alife_taget.age) + "/" + str(alife_taget.lifespan)  + "\n"

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
	if float(new_text) >= 0.1:
		World.speed = float(new_text)
	else:
		World.speed = 0.1
		print("minimum world speed : 0.1")
	get_parent().get_parent().UpdateSimulationSpeed()
	$Panel/World_Debug/option/world/world_speed/LineEdit_wspeed.release_focus() 


func _on_line_edit_speed_text_submitted(new_text):
	World.diffusion_speed = float(new_text)
	get_parent().get_parent().UpdateSimulationSpeed()
	$Panel/World_Debug/option/energy_diffusion/speed/LineEdit_speed.release_focus() 

func _on_line_edit_factor_text_submitted(new_text):
	World.diffusion_factor = float(new_text)
	$Panel/World_Debug/option/energy_diffusion/factor/LineEdit_factor.release_focus() 

func _on_line_edit_min_text_submitted(new_text):
	World.diffusion_min_limit = float(new_text)
	$Panel/World_Debug/option/energy_diffusion/minvalue/LineEdit_min.release_focus() 

func _on_line_edit_spawnenergy_text_submitted(new_text):
	energy_spawn_value = int(new_text)
	$Panel/World_Debug/option/spawn_energy/edit_energy/LineEdit_spawnenergy.release_focus() 

func _on_check_box_toggled(toggled_on):
	energy_spawn_isActivate = toggled_on
	alife_spawn_isActivate = false
	#alife_info_isActivate = false 
	
func _on_check_boxalifespawn_toggled(toggled_on):
	alife_spawn_isActivate = toggled_on
	energy_spawn_isActivate = false
	#alife_info_isActivate = false

func _on_check_box_info_toggled(toggled_on):
	#alife_spawn_isActivate = false
	#energy_spawn_isActivate = false
	alife_info_isActivate = toggled_on

func _on_lineedit_radius_text_submitted(new_text):
	energy_spawn_radius = int(new_text)
	$Panel/World_Debug/option/spawn_energy/radius/LineEdit_radius.release_focus() 

func _input(event):
	
		# Mouse in viewport coordinates.
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				var mouse_position =get_viewport().get_camera_2d().get_global_mouse_position()
				if energy_spawn_isActivate:
					draw_block(mouse_position,energy_spawn_value, energy_spawn_radius)
				if alife_spawn_isActivate:
					var life = Life.build_life(Life.pool_scene.keys()[species_selected])
					if life != null:
						life.global_position = mouse_position
						life.energy = energy_selected
						life.age = age_selected
				if alife_info_isActivate:
					alife_taget = Life.player.mouse_target




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
						







func _on_check_box_hunger_toggled(toggled_on):
	if toggled_on:
		Life.player.metabolic_cost = 0
		
	else:
		Life.player.metabolic_cost = 1


func _on_bs_1_pressed():
	species_selected = clamp(0,species_selected-1, Life.pool_scene.keys().size()-1 )
	$Panel/Alife_Debug/Option/Spawner/species_select/Label2.text = Life.pool_scene.keys()[species_selected]

func _on_bs_2_pressed():
	species_selected = clamp(0,species_selected+1, Life.pool_scene.keys().size()-1 )
	$Panel/Alife_Debug/Option/Spawner/species_select/Label2.text = Life.pool_scene.keys()[species_selected]


func _on_ba_1_pressed():
	age_selected = max(0,age_selected-1)
	$Panel/Alife_Debug/Option/Spawner/age_select/Label2.text = str(age_selected)


func _on_ba_2_pressed():
	age_selected = max(0,age_selected+1)
	$Panel/Alife_Debug/Option/Spawner/age_select/Label2.text = str(age_selected) # Replace with function body.


func _on_be_1_pressed():
	energy_selected = max(0,energy_selected+1)
	$Panel/Alife_Debug/Option/Spawner/energy_select/Label2.text = str(energy_selected) # Replace with function body.


func _on_be_2_pressed():
	energy_selected = max(0,energy_selected+1)
	$Panel/Alife_Debug/Option/Spawner/energy_select/Label2.text = str(energy_selected) # Replace with function body.


func _on_line_edit_energy_text_submitted(new_text):
	energy_selected = int(new_text)
	$Panel/Alife_Debug/Option/Spawner/energy_select/LineEdit_energy.release_focus()  # Replace with function body.


func _on_line_edit_age_text_submitted(new_text):
	age_selected = int(new_text)
	$Panel/Alife_Debug/Option/Spawner/age_select/LineEdit_age.release_focus()  # Replace with function body.


func _on_check_box_hitbox_toggled(toggled_on):
	if toggled_on:
		Life.player.set_collision_mask_value(2,false)
		print("hitbox desactivated")
	else:
		Life.player.set_collision_mask_value(2,true)
		print("hitbox activated")
