extends MultiMeshInstance3D


func draw_all(pos_x,pos_y,pos_z,active,n):
	pass
	multimesh.instance_count = 1000000#n
	multimesh.visible_instance_count = n
	var c = 0
	for i in range(pos_x.size()):
		if active[i]:
			multimesh.set_instance_color(c, Color(1.0, 1.0, 1.0, 1.0))
			var pos = Vector3(pos_x[i],pos_y[i],pos_z[i])
			multimesh.set_instance_transform(c, Transform3D(Basis().scaled(Vector3.ONE), pos))
			c += 1

func update(index, pos):
	pass


func draw_new(pos):
	pass


func remove(index):
	pass
