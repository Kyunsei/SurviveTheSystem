extends MultiMeshInstance2D

#TODO to improve update at all frame 
#ALL on GPU directly
#Limit the number of update either by frame or in total

var alifemanager
var World
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


###
var bin_size : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	alifemanager = get_parent().get_parent().get_node("AlifeManager")
	World = get_parent().get_parent().get_node("World")
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


func init():
	multimesh.visible_instance_count = 0
	var quad = QuadMesh.new()
	quad.size = Vector2(alifemanager.bin_size-1, alifemanager.bin_size-1)
	bin_size = alifemanager.bin_size
	multimesh.mesh = quad


func build_quad_mesh():
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	return quad


func make_triangle(size:float) -> ArrayMesh:
	var verts := PackedVector2Array([
		Vector2(0.0,-size),
		Vector2(size * 0.866,size*0.5),
		Vector2(-size * 0.866,size*0.5),
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
	var world_extent = Vector2(World.size.x, World.size.z)
	var newpos = (Vector2(pos.x, pos.z) / world_extent) * panel_size + panel_size / 2
	return newpos


func update_all3():
	
	var t0 := Time.get_ticks_usec()
	init()
	var i :=0
	for posit in alifemanager.cell_start:
		var t : Transform2D
		var pos = Vector2(posit.x,posit.z)	*	bin_size	

		t = Transform2D(0.0,pos)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		var a = clamp(alifemanager.bin_ids_array[posit].size()/5,0.2,.5)
		multimesh.set_instance_color(i, Color(0.043, 0.586, 0.699, a)) 	
		i += 1

		
	multimesh.visible_instance_count = i

func update_all():
	
	var t0 := Time.get_ticks_usec()
	init()
	var i :=0
	for posit in alifemanager.bin_ids_array:
		var t : Transform2D
		var pos = Vector2(posit.x,posit.z)	*	bin_size	

		t = Transform2D(0.0,pos)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		var a = clamp(alifemanager.bin_ids_array[posit].size()/5,0.2,.5)
		multimesh.set_instance_color(i, Color(0.043, 0.586, 0.699, a)) 	
		i += 1

		
	multimesh.visible_instance_count = i
		
	update_all_usec = Time.get_ticks_usec() - t0 #work because calle din second
