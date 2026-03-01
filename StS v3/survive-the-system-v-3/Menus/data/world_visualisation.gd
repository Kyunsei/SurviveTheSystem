extends Control

var alifemanager
var World
var mm
var panel_size : Vector2
var color_list = [Color(0.0, 0.345, 0.0, 1.0),Color(0.611, 0.0, 0.0, 1.0),Color(0.0, 0.117, 1.0, 1.0),Color(0.635, 0.635, 0.635, 1.0),Color(0.583, 0.583, 0.583, 1.0),Color(0.574, 0.574, 0.574, 1.0),Color(0.826, 0.826, 0.826, 1.0)]
var isOn
var update_time = 1
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
	'for i in range(mm.instance_count):
		var pos = Vector2(randf()*1024, randf()*768)
		var t = Transform2D(0, pos)
		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, Color(1, 0, 0)) # red'
	#mm.instance_count = 50000

	var i = 0
	for g in alifemanager.get_node("Grass_Manager").grass_dict.values():
		var t : Transform2D
	
		var pos = position_conversion(g["position"])
		if g["Species"] == Alifedata.enum_speciesID.GRASS:

			t = Transform2D(
				Vector2(0.5, 0),
				Vector2(0, 0.5),
				pos
			)
		else:
			t = Transform2D(0, position_conversion(g["position"]))
		

		mm.set_instance_transform_2d(i, t)

#var transforms = mm.get_instance_transform_array()
#transforms[i] = t
#mm.set_instance_transform_array(transforms)
		
		mm.set_instance_color(i, color_list[g["Species"]]) 
		i+= 1
	
	for g in alifemanager.get_node("beast_manager").beast_dict.values():
		var t = Transform2D(0, position_conversion(g["position"]))

		mm.set_instance_transform_2d(i, t)
		mm.set_instance_color(i, color_list[g["Species"]]) 
		i+= 1

	mm.visible_instance_count = alifemanager.get_node("beast_manager").beast_dict.size() +  alifemanager.get_node("Grass_Manager").grass_dict.size()

func position_conversion(pos):
	var newpos
	var factor = Vector2(World.World_Size.x*World.bin_size.x,World.World_Size.z*World.bin_size.z) / panel_size/2
	newpos = Vector2(pos.x,pos.z) *  factor  + panel_size/2

	return newpos
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


func _on_button_pressed() -> void:
	if isOn:
		isOn =false
	else:
		isOn = true


func _on_line_edit_text_submitted(new_text: String) -> void:
	update_time = float(new_text)
