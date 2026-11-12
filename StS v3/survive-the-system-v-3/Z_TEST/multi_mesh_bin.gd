extends MultiMeshInstance2D

#TODO to improve update at all frame 
#ALL on GPU directly
#Limit the number of update either by frame or in total

var alifemanager
var world : World
var activated = false

#Sequentially update
var update_on_n_frame := 4
var c := 0

#PERF DATA
var update_usec := 0.0
var update_all_usec := 0.0
var draw_new_usec := 0.0

################
var panel_size : Vector2
var update_time = 1
var update_time_value = 1

var current_layer : int = 0

###
var bin_size : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	alifemanager = get_parent().get_parent().get_node("AlifeManager")
	world = get_parent().get_parent().get_node("World")
	panel_size = $Panel.size
	
	multimesh =  MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = 10000000
	#print(multimesh.buffer)
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	multimesh.mesh = quad
	

	
	#buff = multimesh.get_buffer()


func init(cell_size, shape:= 0):
	multimesh.visible_instance_count = 0
	var mesh
	if shape == 0:
		var quad = QuadMesh.new()
		quad.size = Vector2(cell_size.x-1, cell_size.z-1)
		mesh = quad
	if shape == 1:
		mesh = make_triangle(cell_size.x)
	#bin_size = alifemanager.bin_size
	multimesh.mesh = mesh


func build_quad_mesh():
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	return quad


func make_triangle(length:float, width: float = 0.35) -> ArrayMesh:
	var half_w := length * width * 0.5
	var verts := PackedVector2Array([
		Vector2(length * 0.6, 0.0),        # tip
		Vector2(-length * 0.4, half_w),    # back corner
		Vector2(-length * 0.4, -half_w),   # back corner
	])
	var uvs := PackedVector2Array([
		Vector2(0.5,0.0),
		Vector2(1,1),
		Vector2(0.0,1)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
	

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









func position_conversion(pos):
	var world_extent = Vector2(world.size.x, world.size.z)
	var newpos = (Vector2(pos.x, pos.z) / world_extent) * panel_size + panel_size / 2
	return newpos




func update_all2(value_array, W:int,H:int,D:int,cell_size:float):
	var t0 := Time.get_ticks_usec()
	init(cell_size)
	var cc:= 0
	var ii:= 0

	for i in value_array:
		var cx := cc % W
		@warning_ignore("integer_division")
		var cy := (cc / W) % H
		@warning_ignore("integer_division")
		var cz := cc / (W*H)
		cc+=1
		
		if cy >0 : #only 2D now
			continue
			
		var t : Transform2D
		var pos = Vector2(cx,cz)*	cell_size	
		
		#print(pos)
		t = Transform2D(0.0,pos)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		#var a = clamp(alifemanager.bin_ids_array[posit].size()/5,0.2,.5)
		multimesh.set_instance_color(ii, Color(0.043, 0.586, 0.699, 1)) 	
		ii+=1
		
	multimesh.visible_instance_count = ii
	update_all_usec = Time.get_ticks_usec() - t0 #work because calle din second


func update_all(value_array, W: int, H: int, D: int, cell_size: Vector3,col:Color,max:=4.0, shape:= 0) -> void:
	var t0 := Time.get_ticks_usec()

	init(cell_size,shape)
	var ii := 0
	var cy :int= clamp(current_layer,0,H-1) # to see by layer in y 
	for cz in D:
		for cx in W:
			#var cc := cx + W * current_layer * cz          # replace H by y = 0 layer
			#var cc := cx + W * cy + D * cz   # inline, no second division
			var cc := cx + W * (cy + H * cz)   # inline, no second division
		
			var v = 0.5 

			#var v = lerp(0.25,0.8,value_array[c])       # the cell's value, if needed
			var pos := Vector2(cx, cz) * Vector2(cell_size.x, cell_size.z) + Vector2(cell_size.x/2,cell_size.z/2)
			var angle := 0.0
			if shape == 1:
				var vec: Vector3 = value_array[cc]
				#var angle := atan2(vec.y, vec.x) 
				angle = atan2(vec.z, vec.x)   # if your direction is in x,z (data from a 3D grid)
				var strength := vec.length()
				var dir := vec / strength
	
				v = clampf(strength/max, 0.0, 1.0)
			else:
				v = clamp(value_array[cc]/max ,0.,1.)  
			
			col.a =v
			multimesh.set_instance_transform_2d(ii, Transform2D(angle, pos))
			multimesh.set_instance_color(ii, col)
			ii += 1

	multimesh.visible_instance_count = ii
	update_all_usec = Time.get_ticks_usec() - t0


func _on_line_edit_layer_text_submitted(new_text: String) -> void:
	current_layer = clamp(int(new_text),0,world.SUN_GRID_H-1)
	print(current_layer)
