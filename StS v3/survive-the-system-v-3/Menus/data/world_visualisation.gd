extends Control

var alifemanager
var World
var mm
var panel_size : Vector2
var color_list = [Color(0.0, 0.345, 0.0, 1.0),Color(0.507, 0.207, 0.164, 1.0),Color(0.0, 0.117, 1.0, 1.0),Color(0.635, 0.635, 0.635, 1.0),Color(0.638, 0.398, 0.895, 1.0),Color(0.976, 0.11, 0.0, 1.0),Color(0.826, 0.826, 0.826, 1.0)]
var isOn = true
var update_time = 1


#------- different affichage -----------

var alife_selected : int = 0
var isalifeshow : bool = true
var isfieldshow : bool = false
var isflowshow : bool = false
var isbinshow : bool = false
var islightshow : bool = false


# ...


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	alifemanager = get_parent().get_parent().get_parent().get_node("Alife manager")
	World = get_parent().get_parent().get_parent().get_node("World")
	panel_size = $Panel.size
	mm = $MultiMeshInstance2D.multimesh# MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = 1000000
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	$Alife_select.get_popup().id_pressed.connect(_on_menu_button_pressed)

	#var instance = MultiMeshInstance2D.new()
	#instance.multimesh = mm
	mm.mesh = quad
	update()

func _process(delta: float) -> void:
	update_time -= delta
	if isOn:	
		if update_time < 0:
			update()
			update_time = 1

func update():

	var i = 0
	
	if isbinshow:	
		i = show_bin(i,World.bin_array, World.bin_size)	
	elif islightshow:
		i = show_bin(i,World.light_array, World.light_tile_size)
	elif isfieldshow:
		i = show_field(i)
	elif isflowshow:
		i = show_flow(i)		
	if isalifeshow:
		i = show_alife(i,alife_selected)
		
	mm.visible_instance_count = i
	
	'for g in alifemanager.get_node("beast_manager").beast_dict.values():
		var t = Transform2D(0, position_conversion(g["position"]))

		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, color_list[g["Species"]]) 
		i+= 1

	mm.visible_instance_count = alifemanager.get_node("beast_manager").beast_dict.size() +  alifemanager.get_node("Grass_Manager").grass_dict.size() + alifemanager.get_node("Grass_Manager2").entity_count
'
func position_conversion(pos):
	#var newpos
	#var factor = Vector2(World.World_Size.x*World.bin_size.x,World.World_Size.z*World.bin_size.z) / panel_size
	#newpos = Vector2(pos.x,pos.z) /  factor  + panel_size/2
	#print("pos: ", pos, " -> panel: ", newpos, " (factor: ", factor, ")")
	var world_extent = Vector2(World.World_Size.x, World.World_Size.z)
	# world_extent = (1000, 1000) meters
	var newpos = (Vector2(pos.x, pos.z) / world_extent) * panel_size + panel_size / 2
	#print(pos)
	return newpos
	#return newpos


func show_field(i):
	if alife_selected == 0:
		return i
	var arr = alifemanager.get_node("Grass_Manager2").field_world_array[alife_selected-1]
	for bin in range(World.bin_array.size()):
		var t : Transform2D
		var tile_number = Vector3i(World.World_Size/ World.bin_size)
		
		var conv_tile_size = Vector2()
		conv_tile_size.x = panel_size.x / tile_number.x
		conv_tile_size.y = panel_size.y / tile_number.z	
		var x = (bin % int(tile_number.x) )  * conv_tile_size.x +  conv_tile_size.x/2
		@warning_ignore("integer_division")
		var y = (bin / int(tile_number.x) % int(tile_number.z) )* conv_tile_size.y + +  conv_tile_size.y/2

		
		var stupid_factor = Vector2(World.bin_size.x, World.bin_size.z) / Vector2(5,5)
		var stupid_scale = panel_size/ Vector2(World.World_Size.x, World.World_Size.z)  * stupid_factor

		t = Transform2D(
				Vector2(stupid_scale.x, 0),
				Vector2(0, stupid_scale.y),
				Vector2i(x,y)
			)
		
		mm.set_instance_transform_2d(i, t)
		var value = float(arr[bin])/1.0	
		var col = Color(value, value, value, 1.0)		
		mm.set_instance_color(i, col )	
		i+= 1
	return i


func show_flow(i):
	if alife_selected == 0:
		return i
	var arr: PackedVector3Array = alifemanager.get_node("Grass_Manager2").flow_world_array[alife_selected-1]
	
	for bin in range(arr.size()):
		var t : Transform2D
		var tile_number = Vector3i(World.World_Size/ World.bin_size)
		
		var conv_tile_size = Vector2()
		conv_tile_size.x = panel_size.x / tile_number.x
		conv_tile_size.y = panel_size.y / tile_number.z	
		var x = (bin % int(tile_number.x) )  * conv_tile_size.x +  conv_tile_size.x/2
		@warning_ignore("integer_division")
		var y = (bin / int(tile_number.x) % int(tile_number.z) )* conv_tile_size.y + +  conv_tile_size.y/2

		
		var stupid_factor = Vector2(World.bin_size.x, World.bin_size.z) / Vector2(5,5)
		var stupid_scale = panel_size/ Vector2(World.World_Size.x, World.World_Size.z)  * stupid_factor
		stupid_scale.y = stupid_scale.y/4
		
		print("pos: ", arr)
		#print("bin: ", bin)
		#print("arr.size(): ", arr.size())
		var direction = arr[bin]
		var angle = Vector2(direction.x,direction.z).angle() 

		t = Transform2D(angle, stupid_scale, 0.0, Vector2(x, y))
		
		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, Color(0.805, 0.805, 0.805, 1.0) )	
		i+= 1
	return i

func show_bin(i,world_bin, tile_size):
	for bin in range(world_bin.size()):
		var t : Transform2D
		var tile_number = Vector3i(World.World_Size/ tile_size)
		
		var conv_tile_size = Vector2()
		conv_tile_size.x = panel_size.x / tile_number.x
		conv_tile_size.y = panel_size.y / tile_number.z	
		var x = (bin % int(tile_number.x) )  * conv_tile_size.x +  conv_tile_size.x/2
		@warning_ignore("integer_division")
		var y = (bin / int(tile_number.x) % int(tile_number.z) )* conv_tile_size.y + +  conv_tile_size.y/2

		
		var stupid_factor = Vector2(tile_size.x, tile_size.z) / Vector2(5,5)
		var stupid_scale = panel_size/ Vector2(World.World_Size.x, World.World_Size.z)  * stupid_factor

		t = Transform2D(
				Vector2(stupid_scale.x, 0),
				Vector2(0, stupid_scale.y),
				Vector2i(x,y)
			)
		
		mm.set_instance_transform_2d(i, t)
		var value = 0
		if world_bin[i]:
			if  world_bin[i] is Array:
				value = min(float(world_bin[i].size()),30.)/30.
			else:
				value = world_bin[i]
		
		var col = Color(value, value, value, 1.0)
		
		mm.set_instance_color(i, col )	
		i+= 1
	return i





func show_alife(i, sp):

	
	var c = 0
	var manager = alifemanager.get_node("Grass_Manager2")
	for posit in alifemanager.get_node("Grass_Manager2").position_array:
		var t : Transform2D
		var pos = position_conversion(posit)
		if alifemanager.get_node("Grass_Manager2").Active[c] == 0:
			pos.y = -10000	
			

			
		if manager.Species_array[c] == 0:
			t = Transform2D(
					Vector2(0.5, 0),
					Vector2(0, 0.5),
					pos
				)
		else:
			t = Transform2D(0, pos)	
		
		if sp == 0: #ALL specie sprinted
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, color_list[manager.Species_array[c]]) 	
			i+= 1
		elif manager.Species_array[c] == sp - 1 :
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, color_list[manager.Species_array[c]]) 	
			i+= 1		
		c+= 1	
	

	return i
	
'
func add_energy_in_each_tile(value):
	for i in World_size:
		for j in World_size:
			current_energy_array[i][j] += value
			current_energy_array[i][j] = clamp(current_energy_array[i][j], 0, max_energy_by_tile)
	queue_redraw()




func _draw():
	for i in World_size:
		for j in World_size:
			if show_energy_grid:
				var tile_new_color = tile_color
				if current_energy_array.size() > 0 :
					tile_new_color.r = lerp(0.,1.,current_energy_array[i][j]/max_energy_by_tile)
					tile_new_color.g = lerp(0.,1.,current_energy_array[i][j]/max_energy_by_tile)
					tile_new_color.b = lerp(0.,1.,current_energy_array[i][j]/max_energy_by_tile)

				draw_rect(Rect2(i*tile_size, j*tile_size, tile_size-1, tile_size-1), tile_new_color)
			else:
				draw_rect(Rect2(i*tile_size, j*tile_size, tile_size, tile_size), tile_color)
'


func _on_menu_button_pressed(id : int) -> void:
	alife_selected = id


func _on_line_edit_text_submitted(new_text: String) -> void:
	update_time = float(new_text)


func _on_button_toggled(toggled_on: bool) -> void:
			isOn = 	toggled_on


func _on_button_alife_toggled(toggled_on: bool) -> void:
	isalifeshow = toggled_on


func _on_button_field_toggled(toggled_on: bool) -> void:
	isfieldshow = toggled_on


func _on_button_flow_toggled(toggled_on: bool) -> void:
	isflowshow= toggled_on


func _on_button_bin_toggled(toggled_on: bool) -> void:
	isbinshow= toggled_on


func _on_button_light_toggled(toggled_on: bool) -> void:
	islightshow = toggled_on
