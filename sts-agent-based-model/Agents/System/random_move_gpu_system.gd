extends AgentSystem
class_name RANDOM_MOVE_SYSTEM_GPU

@export var speed: float = 100

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var buf_pos: RID
var buf_active: RID
var uniform_set: RID
var buffer_capacity: int = 0
var frame_counter: int = 0
var has_pending: bool = false
var pending_n: int = 0

func _setup_gpu():
	rd = RenderingServer.create_local_rendering_device()
	var shader_file: RDShaderFile = load("res://Agents/System/GPU/random_move.glsl")
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)

func _make_buffer(size_bytes: int) -> RID:
	var bytes := PackedByteArray()
	bytes.resize(size_bytes)
	return rd.storage_buffer_create(bytes.size(), bytes)

func _ensure_buffer(n: int):
	if n <= buffer_capacity and buf_pos.is_valid():
		return
	if has_pending:
		rd.sync()
		has_pending = false
	if buf_pos.is_valid(): rd.free_rid(buf_pos)
	if buf_active.is_valid(): rd.free_rid(buf_active)
	buffer_capacity = n
	buf_pos = _make_buffer(n * 3 * 4)
	buf_active = _make_buffer(n * 4)

	var u_pos := RDUniform.new()
	u_pos.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos.binding = 0
	u_pos.add_id(buf_pos)

	var u_active := RDUniform.new()
	u_active.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_active.binding = 1
	u_active.add_id(buf_active)

	uniform_set = rd.uniform_set_create([u_pos, u_active], shader, 0)

func update(manager, delta):
	if rd == null:
		_setup_gpu()

	var positions_x: PackedFloat32Array = manager.positions_x
	var positions_y: PackedFloat32Array = manager.positions_y
	var positions_z: PackedFloat32Array = manager.positions_z
	var active: PackedInt32Array = manager.active
	var n = positions_x.size()
	if n == 0:
		return

	_ensure_buffer(n)

	var t0 = Time.get_ticks_usec()

	# Collect LAST frame's dispatch results (should be ready or nearly so by now)
	if has_pending:
		rd.sync()
		var out := rd.buffer_get_data(buf_pos, 0, pending_n * 3 * 4).to_float32_array()
		manager.positions_x = out.slice(0, pending_n)
		manager.positions_y = out.slice(pending_n, 2 * pending_n)
		manager.positions_z = out.slice(2 * pending_n, 3 * pending_n)
		positions_x = manager.positions_x
		positions_y = manager.positions_y
		positions_z = manager.positions_z

	var t1 = Time.get_ticks_usec()

	var bytes_x := positions_x.to_byte_array()
	var bytes_y := positions_y.to_byte_array()
	var bytes_z := positions_z.to_byte_array()
	rd.buffer_update(buf_pos, 0, bytes_x.size(), bytes_x)
	rd.buffer_update(buf_pos, n * 4, bytes_y.size(), bytes_y)
	rd.buffer_update(buf_pos, 2 * n * 4, bytes_z.size(), bytes_z)

	var bytes_active := active.to_byte_array()
	rd.buffer_update(buf_active, 0, bytes_active.size(), bytes_active)

	var t2 = Time.get_ticks_usec()

	var world_id = 0
	var wm = manager.world_manager
	var boundary: int = wm.boundary_condition[world_id]

	var push_constant := PackedFloat32Array([
		speed * delta,
		float(wm.size_x[world_id]),
		float(wm.size_y[world_id]),
		float(wm.size_z[world_id]),
	]).to_byte_array()
	push_constant.append_array(PackedInt32Array([boundary, n, frame_counter, 0]).to_byte_array())
	frame_counter += 1

	var groups := ceili(float(n) / 64.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	rd.compute_list_dispatch(compute_list, groups, 1, 1)
	rd.compute_list_end()

	rd.submit()
	has_pending = true
	pending_n = n

	var t3 = Time.get_ticks_usec()

	print("readback(prev frame): %d us | pack: %d us | dispatch(no sync): %d us | total: %d us" % [t1 - t0, t2 - t1, t3 - t2, t3 - t0])

func _exit_tree():
	if has_pending:
		rd.sync()
	if rd:
		if uniform_set.is_valid(): rd.free_rid(uniform_set)
		if buf_pos.is_valid(): rd.free_rid(buf_pos)
		if buf_active.is_valid(): rd.free_rid(buf_active)
		if pipeline.is_valid(): rd.free_rid(pipeline)
		if shader.is_valid(): rd.free_rid(shader)
		rd.free()
