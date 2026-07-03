extends AgentSystem
class_name BOIDS_SYSTEM_GPU

@export var max_speed: float = 600.0
@export var max_force: float = 30.0
@export var perception_radius: float = 5.0
@export var separation_weight: float = 2.5
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var buf_pos: RID
var buf_vel: RID
var buf_active: RID
var uniform_set: RID
var buffer_capacity: int = 0

func _setup_gpu():
	rd = RenderingServer.create_local_rendering_device()
	var shader_file: RDShaderFile = load("res://Agents/System/GPU/boids.glsl")
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
	if buf_pos.is_valid(): rd.free_rid(buf_pos)
	if buf_vel.is_valid(): rd.free_rid(buf_vel)
	if buf_active.is_valid(): rd.free_rid(buf_active)
	buffer_capacity = n
	buf_pos = _make_buffer(n * 3 * 4)
	buf_vel = _make_buffer(n * 3 * 4)
	buf_active = _make_buffer(n * 4)

	var u_pos := RDUniform.new()
	u_pos.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_pos.binding = 0
	u_pos.add_id(buf_pos)

	var u_vel := RDUniform.new()
	u_vel.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_vel.binding = 1
	u_vel.add_id(buf_vel)

	var u_active := RDUniform.new()
	u_active.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_active.binding = 2
	u_active.add_id(buf_active)

	uniform_set = rd.uniform_set_create([u_pos, u_vel, u_active], shader, 0)

func update(manager, delta):
	if rd == null:
		_setup_gpu()

	var positions_x: PackedFloat32Array = manager.positions_x
	var positions_y: PackedFloat32Array = manager.positions_y
	var positions_z: PackedFloat32Array = manager.positions_z
	var velocity_x: PackedFloat32Array = manager.velocity_x
	var velocity_y: PackedFloat32Array = manager.velocity_y
	var velocity_z: PackedFloat32Array = manager.velocity_z
	var active: PackedInt32Array = manager.active
	var n = positions_x.size()
	if n == 0:
		return

	_ensure_buffer(n)

	var bytes_px := positions_x.to_byte_array()
	var bytes_py := positions_y.to_byte_array()
	var bytes_pz := positions_z.to_byte_array()
	rd.buffer_update(buf_pos, 0, bytes_px.size(), bytes_px)
	rd.buffer_update(buf_pos, n * 4, bytes_py.size(), bytes_py)
	rd.buffer_update(buf_pos, 2 * n * 4, bytes_pz.size(), bytes_pz)

	var bytes_vx := velocity_x.to_byte_array()
	var bytes_vy := velocity_y.to_byte_array()
	var bytes_vz := velocity_z.to_byte_array()
	rd.buffer_update(buf_vel, 0, bytes_vx.size(), bytes_vx)
	rd.buffer_update(buf_vel, n * 4, bytes_vy.size(), bytes_vy)
	rd.buffer_update(buf_vel, 2 * n * 4, bytes_vz.size(), bytes_vz)

	var bytes_active := active.to_byte_array()
	rd.buffer_update(buf_active, 0, bytes_active.size(), bytes_active)

	var world_id = 0
	var wm = manager.world_manager
	var boundary: int = wm.boundary_condition[world_id]

	var push_constant := PackedFloat32Array([
		delta, max_speed, max_force, perception_radius,
		separation_weight, alignment_weight, cohesion_weight,
		float(wm.size_x[world_id]), float(wm.size_y[world_id]), float(wm.size_z[world_id]),
	]).to_byte_array()
	push_constant.append_array(PackedInt32Array([boundary, n, 0, 0, 0, 0]).to_byte_array())

	var groups := ceili(float(n) / 64.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	rd.compute_list_dispatch(compute_list, groups, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var out_pos := rd.buffer_get_data(buf_pos).to_float32_array()
	manager.positions_x = out_pos.slice(0, n)
	manager.positions_y = out_pos.slice(n, 2 * n)
	manager.positions_z = out_pos.slice(2 * n, 3 * n)

	var out_vel := rd.buffer_get_data(buf_vel).to_float32_array()
	manager.velocity_x = out_vel.slice(0, n)
	manager.velocity_y = out_vel.slice(n, 2 * n)
	manager.velocity_z = out_vel.slice(2 * n, 3 * n)

func _exit_tree():
	if rd:
		if uniform_set.is_valid(): rd.free_rid(uniform_set)
		if buf_pos.is_valid(): rd.free_rid(buf_pos)
		if buf_vel.is_valid(): rd.free_rid(buf_vel)
		if buf_active.is_valid(): rd.free_rid(buf_active)
		if pipeline.is_valid(): rd.free_rid(pipeline)
		if shader.is_valid(): rd.free_rid(shader)
		rd.free()
