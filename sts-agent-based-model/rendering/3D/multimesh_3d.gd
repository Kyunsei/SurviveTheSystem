extends MultiMeshInstance3D

func _ready() -> void:
	pass#multimesh.instance_count = 1000000#n

func draw_all(pos_x,pos_y,pos_z,active,n):
	pass
	multimesh.instance_count = n

	multimesh.visible_instance_count = n
	var c = 0
	for i in range(pos_x.size()):
		if active[i]:
			multimesh.set_instance_color(c, Color(1.0, 1.0, 1.0, 1.0))
			var pos = Vector3(pos_x[i],pos_y[i],pos_z[i])
			multimesh.set_instance_transform(c, Transform3D(Basis().scaled(Vector3.ONE), pos))
			c += 1


	'var buffer := PackedFloat32Array()
	#n = 1000000
	buffer.resize(n * 20)  # 12 floats per Transform3D (3x4 matrix)
# fill buffer in loop...
	for i in range(n):
		var base = i * 20
		# Basis (identity = no rotation/scale)
		buffer[base + 0]  = 1.0  # basis.x.x
		buffer[base + 1]  = 0.0  # basis.x.y
		buffer[base + 2]  = 0.0  # basis.x.z
		buffer[base + 3]  = pos_x[i]  # origin.x  ← was wrong

		buffer[base + 4]  = 0.0  # basis.y.x
		buffer[base + 5]  = 1.0  # basis.y.y
		buffer[base + 6]  = 0.0  # basis.y.z
		buffer[base + 7]  = pos_y[i]  # origin.y  ← was wrong

		buffer[base + 8]  = 0.0  # basis.z.x
		buffer[base + 9]  = 0.0  # basis.z.y
		buffer[base + 10] = 1.0  # basis.z.z
		buffer[base + 11] = pos_z[i]  # origin.z  ← was wrong
		# Color
		buffer[base + 12] = 1.0  # r
		buffer[base + 13] = 1.0  # g
		buffer[base + 14] = 1.0  # b
		buffer[base + 15] = 1.0  # a
		 # Custom data — pack what you need into 4 floats
		buffer[base + 16] = 0.0
		buffer[base + 17] = 0.0
		buffer[base + 18] = 0.0  # age, state, etc.
		buffer[base + 19] = 0.0	
	multimesh.buffer = buffer  # single upload'


func update(index, pos):
	pass


func draw_new(pos):
	pass


func remove(index):
	pass
