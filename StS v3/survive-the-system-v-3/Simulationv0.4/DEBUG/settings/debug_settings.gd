extends Control
#This Script deal with the debug settings of main parameter for the game
#we idea is to test quickly different world settings
#And also to assess ecosystem equilibrium

var world : WorldManager
var alifemanager : AlifeManager
var render : AlifeRendererManager 
var sim_manager :SimulationManager

#-------------------------

func init():
	$Panel/Alife.alifemanager = alifemanager
	$Panel/Alife.init()

func update_alife_to_world_settings(new_size):
	#return
	#update world size and grid size to new value
	var ratio := Vector3.ONE
	for a in 3:
		if world.size[a] != 0.0:
			ratio[a] = new_size[a] / world.size[a]
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			sp.Stock_Life(i) #THIS can be changed by a reset of stamp layer only i guess 
	#alifemanager.set_contact_cell_size()
	#cell_size = alifemanager.new_cell_size
	alifemanager.init_GRID(world.size)
	world.init()
	alifemanager.current_global_photosynthesis_rate.resize(world.SUN_NUM_CELLS)

	#recalculate new grid map of alife
	
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			sp.position_array[i] = sp.position_array[i] * ratio
			sp.Release_Life(i)		


#--------------------


func _on_show_hide_button_pressed() -> void:
	var ishow :bool = $Panel.visible
	$Panel.visible = !ishow
	if ishow:
		$SHOW_HIDEButton.text = "Open Settings"
	else:
		$SHOW_HIDEButton.text = "Close"


#------------------------------------Button LINK----------------------------------------------------



func _on_button_1_toggled(toggled_on: bool) -> void:
	$Panel/Alife.visible = toggled_on
	#$simulation_UI/World.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$Panel/World.visible = false
		$Panel/Rendering.visible = false
		$Panel/choose_menu/Button_3.button_pressed = false
		$Panel/choose_menu/Button_2.button_pressed = false

func _on_button_2_toggled(toggled_on: bool) -> void:
	$Panel/World.visible = toggled_on
	#$simulation_UI/Alife.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$Panel/Alife.visible = false
		$Panel/Rendering.visible = false
		$Panel/choose_menu/Button_1.button_pressed = false
		$Panel/choose_menu/Button_3.button_pressed = false

func _on_button_3_toggled(toggled_on: bool) -> void:
	$Panel/Rendering.visible = toggled_on
		#$simulation_UI/World.visible = false
		#$simulation_UI/Alife.visible = false
	if toggled_on:
		$Panel/Alife.visible = false
		$Panel/World.visible = false
		$Panel/choose_menu/Button_1.button_pressed = false
		$Panel/choose_menu/Button_2.button_pressed = false


func _on_world_x_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.x = int(new_text)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.Release_all_alife()

func _on_world_y_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.y = int(new_text)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.Release_all_alife()

func _on_world_z_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.z = int(new_text)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.Release_all_alife()
	
func _on_borderx_item_selected(index: int) -> void:
		pass


func _on_bordery_item_selected(index: int) -> void:
	pass # Replace with function body.


func _on_borderz_item_selected(index: int) -> void:
	pass # Replace with function body.


func _on_sunenergy_text_submitted(new_text: String) -> void:
	world.SUN_energy = float(new_text)
	world.SUN_update()

func _on_sun_x_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.x = int(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()



func _on_sun_y_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.y = int(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()
	
func _on_sun_z_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.z = int(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()


	

func _on_field_x_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("x",float(new_text))


func _on_field_z_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("z",float(new_text))


func _on_field_y_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("y",float(new_text))
