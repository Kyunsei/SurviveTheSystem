extends MultiMeshInstance2D
class_name world_map #not sure of name..
#this script is to display topview simplified world element/alife system
#TODO to improve update at all frame - #ALL on GPU directly
#Limit the number of update either by frame or in total

@export var activated = false
@export var display : Control
@export var MaxDrawn := 100000
@export var scalebar : Control



#-----par for display
var current_layer : int = 0
var current_species : int = 0
var panel_size : Vector2
var origin : Vector2
var D: int
var W: int
var H: int
var display_cell_size : Vector2
var display_field : String
var display_species :ALIFE

#-----PERF var 
var update_all_usec := 0.0



#Sequentially update NOT in use
var update_on_n_frame := 4
var c := 0


func _ready() -> void:
	panel_size = display.size	
	multimesh =  MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = MaxDrawn	
	#setup()


func setup( cell_size: Vector3, world_size:Vector3, shape:= 0):
	var world_size2:= Vector2( world_size.x, world_size.z)

	#Now using subviewport so no need to rescale everything
	#panel_size = display.size	
	#origin = display.position
	#display_cell_size = panel_size/world_size2
	panel_size =  world_size2
	display.size = panel_size
	display_cell_size = Vector2(cell_size.x,cell_size.z) #panel_size/world_size2
	
	var mesh_size = cell_size.x
	var dims := Vector3i((world_size / cell_size).ceil())
	W = dims.x         # cells along x
	H = dims.y       # cells along y
	D = dims.z         # cells along z

	
	multimesh =  MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = MaxDrawn
	multimesh.visible_instance_count = 0
	
	var mesh
	if shape == 0:
		mesh =  build_quad_mesh(mesh_size)
	if shape == 1:
		mesh = build_triangle_mesh(mesh_size)
	#bin_size = alifemanager.bin_size
	multimesh.mesh = mesh


func build_quad_mesh(size: float):
	var quad = QuadMesh.new()
	quad.size = Vector2(size, size)
	return quad


func build_triangle_mesh(length:float, width: float = 0.35) -> ArrayMesh:
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
	




func draw_grid(value_array,col:Color) -> void:
	if !value_array:
		return
	if display_field != "": 
		#this is a quick fix because diffusion field array are replaced at each frame, 
		#so need to track from source
		value_array = display_species.get(display_field)
	var t0 := Time.get_ticks_usec()
	var max := get_max_value(value_array) 
	scalebar.max_value = max
	scalebar.color = col
	var ii := 0
	var cy :int= clamp(current_layer,0,H-1) # to see by layer in y 	
	var p:= Vector2.ZERO
	var a: float = 0.0
	var v: float = 0.5
	for cz in D:
		for cx in W:
			var cc := cx + W * (cy + H * cz)   # inline, no second division
			#var v = lerp(0.25,0.8,value_array[c])       # the cell's value, if needed
			p = Vector2(cx, cz) * display_cell_size +  display_cell_size/2 + origin
			if value_array[cc] is Vector3:
				var vec =  value_array[cc]
				v = vec.length()
				#var angle := atan2(vec.y, vec.x) 
				a = atan2(vec.z, vec.x)   # if your direction is in x,z (data from a 3D grid)
				v = clampf(v/max, 0.0, 1.0)
			else:
				v = clamp(value_array[cc]/max ,0.,1.)  
			
			col.a =v
			multimesh.set_instance_transform_2d(ii, Transform2D(a, p))
			multimesh.set_instance_color(ii, col)
			ii += 1

	multimesh.visible_instance_count = ii
	update_all_usec = Time.get_ticks_usec() - t0







func get_max_value(values) -> float:
	if values.is_empty():
		return 1.0

	if values is PackedVector3Array:
		var max_sq := 0.0
		for v in values:
			max_sq = maxf(max_sq, v.length_squared())
		return sqrt(max_sq)

	if values is PackedFloat32Array or values is PackedInt32Array:
		var max_value := -INF
		for x in values:
			max_value = maxf(max_value, x)
		return max_value

	# Regular Array (untyped or Array[Vector3] / Array[float]): check the first element
	if values is Array:
		if values[0] is Vector3:
			var max_sq := 0.0
			for v in values:
				max_sq = maxf(max_sq, v.length_squared())
			return sqrt(max_sq)
		return float(values.max())

	push_error("get_max_value: unsupported type")
	return 1.0
