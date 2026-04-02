extends MultiMeshInstance3D


func draw_all(pos):
	pass
	multimesh.instance_count = pos.size()
	multimesh.visible_instance_count = pos.size()
	var i = 0
	for p in pos:
		multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE), p))
		i += 1

func update(index, pos):
	pass


func draw_new(pos):
	pass


func remove(index):
	pass
