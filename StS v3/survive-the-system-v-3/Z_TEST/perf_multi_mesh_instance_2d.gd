extends MultiMeshInstance2D

#TODO to improve update at all frame 
#ALL on GPU directly
#Limit the number of update either by frame or in total

var alifemanager
var World
var activated = true

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

#buffer WIP
const STRIDE := 12 #for 2D buffer + color
var buff := PackedFloat32Array()
#var angles: PackedFloat32Array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	print(Performance.get_monitor(Performance.MEMORY_STATIC))
	print(Performance.get_monitor(Performance.OBJECT_COUNT))
	alifemanager = get_parent().get_parent().get_node("AlifeManager")
	World = get_parent().get_parent().get_node("World")
	panel_size = $Panel.size
	
	multimesh =  MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = make_triangle(4.0)
	multimesh.use_colors = true
	multimesh.instance_count = 10000000
	#print(multimesh.buffer)
	var quad = QuadMesh.new()
	quad.size = Vector2(4, 4)
	#multimesh.mesh = quad
	

	
	#buff = multimesh.get_buffer()


func init():
	multimesh.visible_instance_count = 0


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

func setup():
	buff.resize(multimesh.instance_count * STRIDE)
	for i in alifemanager.entity_count:
		#angles[i] += delta
		var px = alifemanager.position_array[i].x
		var py = alifemanager.position_array[i].z
		var o = i * STRIDE
		buff[o + 0] = 1.0
		buff[o + 1] = 1.0
		buff[o + 2] = 0.0
		buff[o + 3] = px
		buff[o + 4] = 1.0
		buff[o + 5] = 1.0
		buff[o + 6] = 0.0
		buff[o + 7] = py
		buff[o + 8] = 0.191
		buff[o + 9] = 0.446
		buff[o + 10] = 0.304
		buff[o + 11] = 1.0
	





#For Transform2D the float-order is: (x.x, y.x, padding_float, origin.x, x.y, y.y, padding_float, origin.y).
#For Transform3D the float-order is: (basis.x.x, basis.y.x, basis.z.x, origin.x, basis.x.y, basis.y.y, basis.z.y, origin.y, basis.x.z, basis.y.z, basis.z.z, origin.z).
func update_all_buffer():
	var t0 := Time.get_ticks_usec()
	var o:= 0
	#buff.resize(alifemanager.entity_count * STRIDE)
	for i in 100:# alifemanager.entity_count:
		#angles[i] += delta
		var px = alifemanager.position_array[i].x
		var py = alifemanager.position_array[i].z
		buff[o + 3] = px
		buff[o + 7] = py
		o += STRIDE

	
	multimesh.buffer=buff
	update_all_usec = Time.get_ticks_usec() - t0 #work because calle din second

	#multimesh.visible_instance_count = alifemanager.entity_count
	#RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buff)



func position_conversion(pos):
	var world_extent = Vector2(World.size.x, World.size.z)
	var newpos = (Vector2(pos.x, pos.z) / world_extent) * panel_size + panel_size / 2
	return newpos

func erase_instance(idx_arr: PackedInt32Array):
	for i in idx_arr:
		multimesh.set_instance_color(i, Color(0.488, 0.077, 0.15, 1.0)) 	


func draw_new_instance(idx_arr: PackedInt32Array):
	var t0 := Time.get_ticks_usec()

	var c = multimesh.visible_instance_count
	for i in idx_arr:
		var posit = alifemanager.position_array[i]
		var t : Transform2D
		#var pos = position_conversion(posit)
		var pos = Vector2(posit.x,posit.z)
		t = Transform2D(1.0,pos)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		#print(i)
		
		#multimesh.set_instance_color(i, alifemanager.color_array[i]) 	
		multimesh.set_instance_color(i, Color(0.313, 0.66, 0.403, 1.0)) 	

		if i > c:
			c+=1	

	multimesh.visible_instance_count = c
	idx_arr.clear()
	draw_new_usec = Time.get_ticks_usec() - t0

func update_all():
	var t0 := Time.get_ticks_usec()
	var i :=1
	for posit in alifemanager.position_array:
		var t : Transform2D
		var pos = position_conversion(posit)
		pos = Vector2(posit.x,posit.z)			
		'elif manager.Species_array[c] == AlifeRegistry.SPECIES_ID.SPIDERCRAB:
				t = Transform2D(
					Vector2(1.5, 0),
					Vector2(0, 1.5),
					pos
				)'
		t = Transform2D(1.0,pos)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		#multimesh.set_instance_color(i, Color(0.138, 0.394, 0.347, 1.0)) 
		if alifemanager.species_id[i]==0:
			multimesh.set_instance_color(i, Color(0.313, 0.66, 0.403, 1.0)) 	
		if alifemanager.species_id[i]==1:
			multimesh.set_instance_color(i, Color(0.886, 0.328, 0.604, 1.0)) 
		if alifemanager.species_id[i]==2:
			multimesh.set_instance_color(i, Color(0.75, 0.387, 0.0, 1.0))	
		i+=1	

		#multimesh.visible_instance_count = i

	update_all_usec = Time.get_ticks_usec() - t0 #work because calle din second


func update_all_sequentially() -> void:
	var t0 := Time.get_ticks_usec()
	var n: int = alifemanager.entity_count
	var from := n * c / update_on_n_frame
	var to := n * (c + 1) / update_on_n_frame    # multiply first, then divide
	update_array(from, to)
	c = (c + 1) % update_on_n_frame
	update_all_usec = Time.get_ticks_usec() - t0

	

func update_array(from: int, to: int):
	#var t0 := Time.get_ticks_usec()
	var pos: Vector3
	var pos2d: Vector2

	var t : Transform2D
	for i in range(from,to):
		if alifemanager.active_alife_array[i] == 0:
				continue
		pos = alifemanager.position_array[i]#position_conversion(posit)
		pos2d = Vector2(pos.x,pos.z)			
		'elif manager.Species_array[c] == AlifeRegistry.SPECIES_ID.SPIDERCRAB:
				t = Transform2D(
					Vector2(1.5, 0),
					Vector2(0, 1.5),
					pos
				)'
		t = Transform2D(1.0,pos2d)
		#print(pos,posit)			
		multimesh.set_instance_transform_2d(i,t)
		multimesh.set_instance_color(i, Color(0.313, 0.66, 0.403, 1.0)) 	

		#multimesh.set_instance_color(i, alifemanager.color_array[i]) 	

		
		i+=1	

		#multimesh.visible_instance_count = i

	#update_all_usec = Time.get_ticks_usec() - t0 
