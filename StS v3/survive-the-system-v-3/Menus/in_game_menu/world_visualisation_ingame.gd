extends Control

var alifemanager
var World
var mm
var mm2
var panel_size : Vector2
var color_list = [Color(0.0, 0.345, 0.0, 1.0),
Color(0.507, 0.207, 0.164, 1.0),
Color(0.067, 0.173, 0.096, 1.0),
Color(0.053, 0.407, 0.629, 1.0),
Color(0.948, 0.937, 0.778, 1.0),
Color(0.976, 0.11, 0.0, 1.0),
Color(0.392, 0.392, 0.392, 1.0),
Color(0.492, 0.21, 0.524, 1.0),
Color(0.0, 0.722, 0.867, 1.0),
Color(0.566, 0.554, 0.022, 1.0)
]
var isOn = true
var update_time = 1


#------- different affichage -----------

var alife_selected : int = 0
var isalifeshow : bool = true
var isfieldshow : bool = false
var isflowshow : bool = false
var isbinshow : bool = false
var islightshow : bool = false
var isshadowshow : bool = false

# ...


	
func init():
	if multiplayer.is_server():
		return
	alifemanager = get_parent().get_parent().get_node("Alife manager")
	print(alifemanager)
	World = get_parent().get_parent().get_node("World")
	panel_size = $Panel.size
	mm = $MultiMeshInstance2D.multimesh# MultiMesh.new()
	#mm.transform_format = MultiMesh.TRANSFORM_2D
	#mm.instance_count = 1000000
	#mm2.instance_count = 1000000

	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)


func init_alife_select_choice_button():
	#$Alife_select.item_count = AlifeRegistry.SPECIES_ID.size()
	var  popup =$Alife_select.get_popup()
	popup.add_item("ALL")
	for s in AlifeRegistry.SPECIES_ID.keys():
		popup.add_item(str(s))
 

func build_quad_mesh():
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	return quad


func build_triangle_mesh():
	var mesh = ArrayMesh.new()
	
	var vertices = PackedVector3Array([
		Vector3(0,-.5,0),
		Vector3(5,0,0),
		Vector3(0,.5,0)
	])
	
	var arrays = []
	
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	
	return mesh
	
var isInit = false

func _process(delta: float) -> void:
	if multiplayer.is_server():
		return
	if GlobalSimulationParameter.ClientStarted:
		if isInit:	
			update()
		else:
			init()
			isInit = true


func update():

	var i = 0
	
	i = show_alife(i,alife_selected)
	mm.visible_instance_count = i
	
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
	mm.mesh = build_quad_mesh()
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


func show_flow():
	var i = 0
	if isflowshow:
	
		mm2.mesh = build_triangle_mesh()

		var arr: PackedFloat64Array = alifemanager.get_node("Grass_Manager2").field_world_array[alife_selected-1]
		var manager = alifemanager.get_node("Grass_Manager2")
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
			var stupid_scale =  panel_size/ Vector2(World.World_Size.x, World.World_Size.z)  * stupid_factor
			#stupid_scale.y = stupid_scale.y/4
			
			#print("pos: ", arr)
			#print("bin: ", bin)
			#print("arr.size(): ", arr.size())
			var direction = manager.calculate_flow_at_bin(alife_selected-1,bin)
			var angle = Vector2(direction.x,direction.z).angle() 

			t = Transform2D(angle, stupid_scale, 0.0, Vector2(x, y))
			
			mm2.set_instance_transform_2d(i, t)
			mm2.set_instance_color(i, Color(0.805, 0.805, 0.805, 1.0) )	
			i+= 1
			mm.visible_instance_count = i
	mm2.visible_instance_count = i


func show_bin(i,world_bin, tile_size):
	mm.mesh = build_quad_mesh()

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
	mm.mesh = build_quad_mesh()

	
	var c = 0
	var manager = alifemanager.get_node("Grass_Manager2")
	for posit in alifemanager.get_node("Grass_Manager2").position_array:
		var t : Transform2D
		var pos = position_conversion(posit)
		if alifemanager.get_node("Grass_Manager2").Active[c] == 0:
			pos.y = -10000	
			

			
		if manager.Species_array[c] == 0 or manager.Species_array[c] == AlifeRegistry.SPECIES_ID.MOSS or manager.Species_array[c] == AlifeRegistry.SPECIES_ID.SPIKYFLOWER :
			t = Transform2D(
					Vector2(0.5, 0),
					Vector2(0, 0.5),
					pos
				)
		elif manager.Species_array[c] == AlifeRegistry.SPECIES_ID.SPIDERCRAB:
				t = Transform2D(
					Vector2(1.5, 0),
					Vector2(0, 1.5),
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
	
