extends Control

#THIS is the script for the map panel

#--cross ref
var alifemanager: AlifeManager
var world: WorldManager

@export var display_map: world_map
@export var map_view: SubViewportContainer
@export var activated:= false

@export var select_layer_option : OptionButton
@export var select_species_option : OptionButton

var display_col : Color
var display_array 
var current_species := 0



func _ready() -> void:
	for box in [$Panel/VBoxContainer/HBoxContainer2, $Panel/VBoxContainer/HBoxContainer3]:
		for b in box.get_children():
			if b is Button:
				b.toggled.connect(_on_mode_toggled.bind(b))
	


func init()-> void:
	display_map.setup(world.SUN_cell_size,world.size)
	activated = false
	init_species_renderer()
	map_view.world_rect =Rect2(0,0,world.size.x, world.size.z)
	map_view._init_view(world.size)
	
	for y in world.SUN_GRID_H: #TODO adapt according to slection of display..
		select_layer_option.add_item(str(y))

	select_species_option.add_item("All")
	for sp in alifemanager.species_array:
		select_species_option.add_item(sp.species_name)
	
func init_species_renderer():
	for c in map_view.get_children():
		if c is AlifeRenderer2D:
			c.queue_free()
	var c:= 0
	for s in alifemanager.species_array:
		s.renderer2D = AlifeRenderer2D.new()
		s.renderer2D.setup(s.rend_data, world.size, s.colour)
		s.renderer2D.name = str(c)
		map_view.get_node("SubViewport").add_child.call_deferred(s.renderer2D)
		c += 1

func update():
	var t0 := Time.get_ticks_usec()
	if activated == true:
		display_map.show()
		display_map.draw_grid(display_array,display_col)
		for s in alifemanager.species_array:
			s.renderer2D.ensure_instances2D(s.entity_count)
			s.renderer2D.set_count(s.entity_count)
	else:
		display_map.hide()
	var t1 := Time.get_ticks_usec()

	$Panel/Label.text = "Map Display - %.2f ms" % ((t1-t0) / 1000.0)
	
func _on_show_hide_button_pressed() -> void:
	var ishow :bool = $Panel.visible
	$Panel.visible = !ishow
	if ishow:
		$SHOW_HIDEButton.text = "Open Map"
	else:
		$SHOW_HIDEButton.text = "Close"

#Button connection part---------------------------------------


func deselect_all(me):
	#var me := $Panel/VBoxContainer/HBoxContainer2/Button2
	for box in [$Panel/VBoxContainer/HBoxContainer2, $Panel/VBoxContainer/HBoxContainer3]:
		for c in box.get_children():
			if c is Button and c != me and c.name != "alife":
				c.set_pressed_no_signal(false)


var current_selected_button : String

func update_map_display(button_name):
	display_map.display_field = ""
	match button_name:
		"alife":
			for s in alifemanager.species_array.size():
				if map_view.get_node("SubViewport").has_node(str(s)):
						map_view.get_node("SubViewport").get_node(str(s)).show()
		"sungrid":
			display_col =  Color(0.992, 0.883, 0.594, 1.0)
			display_array = world.SUN_GRID
			display_map.setup(world.SUN_cell_size, world.size)
		"sunstamp":
			display_col =  Color(0.644, 0.605, 0.089, 1.0)
			display_array = world.SUN_stamp
			display_map.setup(world.SUN_cell_size, world.size)  
		"contactgrid":
			activated = false
			display_col =  Color(0.919, 0.357, 0.613, 1.0)
			display_map.setup(alifemanager.cell_size, world.size) 
			return
		"field":

			display_col =  alifemanager.species_array[display_map.current_species].colour  
			display_array = alifemanager.species_array[display_map.current_species].FIELD_count
			display_map.setup(alifemanager.field_cell_size, world.size)
		"fielddif":
			display_map.display_species = alifemanager.species_array[display_map.current_species]
			display_map.display_field = "FIELD_c_diffused"
			display_col =  alifemanager.species_array[display_map.current_species].colour  
			display_array = alifemanager.species_array[display_map.current_species].FIELD_c_diffused
			display_map.setup(alifemanager.field_cell_size, world.size) 
		"velocity":
			display_col =  alifemanager.species_array[display_map.current_species].colour  
			display_array = alifemanager.species_array[display_map.current_species].FIELD_velocity
			display_map.setup(alifemanager.field_cell_size, world.size,1) 
		"velocitydiff":
			display_map.display_species = alifemanager.species_array[display_map.current_species]
			display_map.display_field = "FIELD_v_diffused"
			display_col =  alifemanager.species_array[display_map.current_species].colour  
			display_array = alifemanager.species_array[display_map.current_species].FIELD_v_diffused
			display_map.setup(alifemanager.field_cell_size, world.size,1) 
		"scent":
			display_col =  alifemanager.species_array[display_map.current_species].colour  
			display_array = alifemanager.species_array[display_map.current_species].SCENT #TODO
			display_map.setup(alifemanager.field_cell_size, world.size,1)

func _on_mode_toggled(on: bool, button: Button) -> void:
	if not on:
		activated = false

		return
	deselect_all(button)
	update_map_display(button.name)
	current_selected_button = button.name
	map_view._init_view()
	activated = true


func _on_species_select_item_selected(index: int) -> void:
	display_map.current_species = index -1
	if index <0:
		display_map.current_species = 0
	current_species = index
	update_map_display(current_selected_button)
	show_alife(current_species)


func show_alife(index):
	if index>0:
		for s in alifemanager.species_array.size():
			if s == index-1:
				if map_view.get_node("SubViewport").has_node(str(s)):
					map_view.get_node("SubViewport").get_node(str(s)).show()
			else:
				if map_view.get_node("SubViewport").has_node(str(s)):
					map_view.get_node("SubViewport").get_node(str(s)).hide()
	else:
		for s in alifemanager.species_array.size():
			if map_view.get_node("SubViewport").has_node(str(s)):
					map_view.get_node("SubViewport").get_node(str(s)).show()

func _on_layer_select_item_selected(index: int) -> void:
	display_map.current_layer = index


func _on_alife_toggled(toggled_on: bool) -> void:
	if toggled_on:
		show_alife(current_species)
	else:
		for s in alifemanager.species_array.size():
				if map_view.get_node("SubViewport").has_node(str(s)):
					map_view.get_node("SubViewport").get_node(str(s)).hide()
