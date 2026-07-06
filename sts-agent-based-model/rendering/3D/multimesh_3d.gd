extends MultiMeshInstance3D

const STRIDE := 20  # 12 transform + 4 color + 4 custom_data
var _buffer: PackedFloat32Array = PackedFloat32Array()
var _capacity: int = 0

func _ensure_capacity(n: int):
	if n <= _capacity:
		return
	_capacity = n
	_buffer.resize(n * STRIDE)

func draw_all(pos_x, pos_y, pos_z, dir_x, dir_y, dir_z, active, n):
	_ensure_capacity(n)
	multimesh.instance_count = _capacity

	var c := 0
	for i in range(n):
		if active[i]:
			var base := c * STRIDE

			var dx = dir_x[i]
			var dy = dir_y[i]
			var dz = dir_z[i]
			var len_sq = dx * dx + dy * dy + dz * dz

			var x_axis := Vector3(1, 0, 0)
			var y_axis := Vector3(0, 1, 0)
			var z_axis := Vector3(0, 0, 1)

			if len_sq > 0.0001:
				var inv_len = 1.0 / sqrt(len_sq)
				y_axis = Vector3(dx * inv_len, dy * inv_len, dz * inv_len)
				var reference = Vector3(0, 0, -1)
				if abs(y_axis.dot(reference)) > 0.99:
					reference = Vector3(1, 0, 0)
				x_axis = reference.cross(y_axis).normalized()
				z_axis = x_axis.cross(y_axis).normalized()

			_buffer[base + 0] = x_axis.x
			_buffer[base + 1] = y_axis.x
			_buffer[base + 2] = z_axis.x
			_buffer[base + 3] = pos_x[i]
			_buffer[base + 4] = x_axis.y
			_buffer[base + 5] = y_axis.y
			_buffer[base + 6] = z_axis.y
			_buffer[base + 7] = pos_y[i]
			_buffer[base + 8] = x_axis.z
			_buffer[base + 9] = y_axis.z
			_buffer[base + 10] = z_axis.z
			_buffer[base + 11] = pos_z[i]
			_buffer[base + 12] = 1.0
			_buffer[base + 13] = 1.0
			_buffer[base + 14] = 1.0
			_buffer[base + 15] = 1.0
			_buffer[base + 16] = 0.0
			_buffer[base + 17] = 0.0
			_buffer[base + 18] = 0.0
			_buffer[base + 19] = 0.0
			c += 1

	multimesh.visible_instance_count = c
	multimesh.buffer = _buffer
