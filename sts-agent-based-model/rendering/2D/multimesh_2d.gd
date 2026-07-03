extends MultiMeshInstance2D


func _ready() -> void:
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = build_triangle_mesh()


func draw_all(pos_x,pos_y,pos_z,active,n):
	pass
	multimesh.instance_count = 1000000#n
	multimesh.visible_instance_count = n
	var c = 0
	for i in range(pos_x.size()):
		if active[i]:
			var pos2 = Vector2(pos_x[i],pos_z[i]) + Vector2(100,100)
			var t = Transform2D()	
			t.origin = pos2
			#t = Transform2D(angle, stupid_scale, 0.0, Vector2(x, y))

			multimesh.set_instance_color(c, Color(1.0, 1.0, 1.0, 1.0))
			multimesh.set_instance_transform_2d(c, t)
			c += 1


func build_triangle_mesh():
	var mesh = ArrayMesh.new()
	
	var vertices = PackedVector3Array([
		Vector3(0,-2.5,0),
		Vector3(5,0,0),
		Vector3(0,2.5,0)
	])
	
	var arrays = []
	
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	
	return mesh
