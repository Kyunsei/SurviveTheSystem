extends Node
# GPU compute-shader version of the same A/B benchmark, for comparison
# against GDScript threads and the native GDExtension version.

const ITEM_COUNT := 1_000_000
const WORK_ITERS := 60
const REPEATS := 3
const LOCAL_SIZE := 256
var label_text = ""

const SHADER_ARITH := """
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
	float data[];
} data_buffer;

layout(push_constant, std430) uniform Params {
	uint item_count;
	uint work_iters;
	uint pad0;
	uint pad1;
} params;

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= params.item_count) {
		return;
	}
	float x = data_buffer.data[idx];
	for (uint k = 0u; k < params.work_iters; k++) {
		x = x * 1.0000137 + 0.0000731;
	}
	data_buffer.data[idx] = x;
}
"""

const SHADER_CALLS := """
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
	float data[];
} data_buffer;

layout(push_constant, std430) uniform Params {
	uint item_count;
	uint work_iters;
	uint pad0;
	uint pad1;
} params;

void main() {
	uint idx = gl_GlobalInvocationID.x;
	if (idx >= params.item_count) {
		return;
	}
	float x = data_buffer.data[idx];
	for (uint k = 0u; k < params.work_iters; k++) {
		x = sin(x) * 0.5 + sqrt(abs(x)) * 0.3;
	}
	data_buffer.data[idx] = x;
}
"""

func _initialize() -> void:
	label_text = ""
	print("Attempting to create a local RenderingDevice (GPU compute) headless...")
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAILED: no RenderingDevice available in this headless run.")
		#quit(1)
		return
	print("RenderingDevice created OK.\n")

	_run_variant(rd, "pure arithmetic", SHADER_ARITH)
	_run_variant(rd, "sin()/sqrt() calls", SHADER_CALLS)

	rd.free()
	#quit()

func _run_variant(rd: RenderingDevice, label: String, shader_src: String) -> void:
	var src := RDShaderSource.new()
	src.source_compute = shader_src
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL

	var spirv := rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		print("SHADER COMPILE ERROR (%s): %s" % [label, spirv.compile_error_compute])
		return

	var shader := rd.shader_create_from_spirv(spirv)

	var input := PackedFloat32Array()
	input.resize(ITEM_COUNT)
	for i in ITEM_COUNT:
		input[i] = float(i % 1000) * 0.001
	var input_bytes := input.to_byte_array()

	var best_ms := INF
	for r in REPEATS:
		var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform.binding = 0
		uniform.add_id(buffer)
		var uniform_set := rd.uniform_set_create([uniform], shader, 0)
		var pipeline := rd.compute_pipeline_create(shader)

		var pc := PackedInt32Array([ITEM_COUNT, WORK_ITERS, 0, 0]).to_byte_array()
		var group_count := int(ceil(float(ITEM_COUNT) / float(LOCAL_SIZE)))

		var t0 := Time.get_ticks_usec()
		var cl := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
		rd.compute_list_set_push_constant(cl, pc, pc.size())
		rd.compute_list_dispatch(cl, group_count, 1, 1)
		rd.compute_list_end()
		rd.submit()
		rd.sync()
		var t1 := Time.get_ticks_usec()
		best_ms = min(best_ms, (t1 - t0) / 1000.0)

		if r == 0:
			var out_bytes := rd.buffer_get_data(buffer)
			var out := out_bytes.to_float32_array()
			print("  sample check: in[0]=%.6f out[0]=%.6f  in[1000]=%.6f out[1000]=%.6f" % [input[0], out[0], input[1000], out[1000]])


		rd.free_rid(uniform_set)
		rd.free_rid(pipeline)
		rd.free_rid(buffer)

	print("=== GPU compute, %s ===" % label)
	label_text += "=== GPU compute, %s === \n" % label

	print("  %d items x %d iters: best of %d runs = %.3f ms  (%.0f items/sec)" % [ITEM_COUNT, WORK_ITERS, REPEATS, best_ms, ITEM_COUNT / (best_ms / 1000.0)])
	label_text +="  %d items x %d iters: best of %d runs = %.3f ms  (%.0f items/sec) \n" % [ITEM_COUNT, WORK_ITERS, REPEATS, best_ms, ITEM_COUNT / (best_ms / 1000.0)]
	

	print("")

	rd.free_rid(shader)


func _process(delta: float) -> void:
	$Label2.text = label_text

func _on_button_pressed() -> void:
	_initialize()
	
