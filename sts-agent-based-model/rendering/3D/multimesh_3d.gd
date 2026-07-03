extends MultiMeshInstance3D

const STRIDE := 20  # 12 transform + 4 color + 4 custom_data — must match multimesh format
var _buffer: PackedFloat32Array = PackedFloat32Array()
var _capacity: int = 0

func _ensure_capacity(n: int):
	if n <= _capacity:
		return
	_capacity = n
	_buffer.resize(n * STRIDE)

func draw_all(pos_x, pos_y, pos_z, active, n):
	_ensure_capacity(n)
	multimesh.instance_count = _capacity

	var c := 0
	for i in range(n):
		if active[i]:
			var base := c * STRIDE
			_buffer[base + 0] = 1.0
			_buffer[base + 1] = 0.0
			_buffer[base + 2] = 0.0
			_buffer[base + 3] = pos_x[i]
			_buffer[base + 4] = 0.0
			_buffer[base + 5] = 1.0
			_buffer[base + 6] = 0.0
			_buffer[base + 7] = pos_y[i]
			_buffer[base + 8] = 0.0
			_buffer[base + 9] = 0.0
			_buffer[base + 10] = 1.0
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
