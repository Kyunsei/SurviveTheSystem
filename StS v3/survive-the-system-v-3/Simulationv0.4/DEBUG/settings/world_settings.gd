extends ScrollContainer
var world : WorldManager
var alifemanager :AlifeManager
var map : Control


func setup(al : AlifeManager, wd : WorldManager, mp:Control):
	world = wd
	alifemanager = al
	map = mp
	
	

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
	#world.init()
	#alifemanager.current_global_photosynthesis_rate.resize(world.SUN_NUM_CELLS)

	#recalculate new grid map of alife
	
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			sp.position_array[i] = sp.position_array[i] * ratio
			sp.Release_Life(i)		


func calc_ratio(new_size:Vector3)-> Vector3:
	var ratio := Vector3.ONE
	for a in 3:
		if world.size[a] != 0.0:
			ratio[a] = new_size[a] / world.size[a]
	return ratio

func _on_world_x_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.x = int(new_text)
	var ratio := calc_ratio(new_size)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.update_alife_position_to_world_settings(ratio)
	alifemanager.Release_all_alife()
	map.display_map.setup(world.SUN_cell_size,world.size)


func _on_world_y_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.y = int(new_text)
	var ratio := calc_ratio(new_size)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.update_alife_position_to_world_settings(ratio)
	alifemanager.Release_all_alife()
	map.display_map.setup(world.SUN_cell_size,world.size)
	map.select_layer_option.clear()
	for y in world.SUN_GRID_H: 
		map.select_layer_option.add_item(str(y))

func _on_world_z_text_submitted(new_text: String) -> void:
	var new_size := world.size
	new_size.z = int(new_text)
	var ratio := calc_ratio(new_size)
	alifemanager.Store_all_alife()
	world.set_world_size(new_size)
	alifemanager.update_alife_position_to_world_settings(ratio)
	alifemanager.Release_all_alife()
	map.display_map.setup(world.SUN_cell_size,world.size)

	
func _on_borderx_item_selected(index: int) -> void:
	alifemanager.Store_all_alife()
	world.border_type_x = index
	alifemanager.Release_all_alife()



func _on_bordery_item_selected(index: int) -> void:
	alifemanager.Store_all_alife()
	world.border_type_y= index
	alifemanager.Release_all_alife()

func _on_borderz_item_selected(index: int) -> void:
	alifemanager.Store_all_alife()
	world.border_type_z = index
	alifemanager.Release_all_alife()

func _on_sunenergy_text_submitted(new_text: String) -> void:
	world.SUN_energy = float(new_text)
	world.SUN_update()

func _on_sun_x_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.x = float(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()
	if map.current_selected == "sungrid" or map.current_selected == "sunstamp":
		map.display_map.setup(world.SUN_cell_size,world.size)


func _on_sun_y_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.y = float(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()
	map.select_layer_option.clear()
	for y in world.SUN_GRID_H: 
		map.select_layer_option.add_item(str(y))
	if map.current_selected == "sungrid" or map.current_selected == "sunstamp":
		map.display_map.setup(world.SUN_cell_size,world.size)

		
func _on_sun_z_text_submitted(new_text: String) -> void:
	var new_size := world.SUN_cell_size
	new_size.z = float(new_text)
	alifemanager.Store_all_alife()
	world.set_sun_cell(new_size)
	alifemanager.Release_all_alife()
	if map.current_selected == "sungrid" or map.current_selected == "sunstamp":
		map.display_map.setup(world.SUN_cell_size,world.size)

	

func _on_field_x_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("x",float(new_text))
	if map.current_selected == "field" or map.current_selected == "fielddif"  or map.current_selected == "velocity"  or map.current_selected == "velocitydiff":
		map.display_map.setup(alifemanager.field_cell_size,world.size)


func _on_field_z_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("z",float(new_text))
	if map.current_selected == "field" or map.current_selected == "fielddif"  or map.current_selected == "velocity"  or map.current_selected == "velocitydiff":
		map.display_map.setup(alifemanager.field_cell_size,world.size)


func _on_field_y_text_submitted(new_text: String) -> void:
	alifemanager.set_field_cell("y",float(new_text))
	if map.current_selected == "field" or map.current_selected == "fielddif"  or map.current_selected == "velocity"  or map.current_selected == "velocitydiff":
		map.display_map.setup(alifemanager.field_cell_size,world.size)



func _on_grid_x_text_submitted(new_text: String) -> void:
	var new_size := alifemanager.cell_size
	new_size.x = float(new_text)
	alifemanager.set_contact_cell_size(new_size)
	#map.display_map.setup(alifemanager.cell_size,world.size)


func _on_grid_y_text_submitted(new_text: String) -> void:
	var new_size := alifemanager.cell_size
	new_size.y = float(new_text)
	alifemanager.set_contact_cell_size(new_size)
	#map.display_map.setup(alifemanager.cell_size,world.size)

func _on_grid_z_text_submitted(new_text: String) -> void:
	var new_size := alifemanager.cell_size
	new_size.z = float(new_text)
	alifemanager.set_contact_cell_size(new_size)
	#map.display_map.setup(alifemanager.cell_size,world.size)
