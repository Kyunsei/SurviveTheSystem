extends Node
## Thread scaling A/B test: pure arithmetic vs. builtin function calls (sin/sqrt).
##
## Usage: create an empty scene, add a Node, attach this script, press Play.
## Results print to the Output panel. Finishes in under a minute with the
## defaults below and quits itself automatically when done.

const ITEM_COUNT := 500_000
const WORK_ITERS := 60
const REPEATS := 3

var _base_data: PackedFloat32Array
var label_text = ""

func run_simulation() -> void:
	print("OS.get_processor_count() = %d\n" % OS.get_processor_count())
	label_text = "OS.get_processor_count() = %d\n" % OS.get_processor_count()
	label_text += "item_count %d, Work_iter %d, Repeat %d \n" % [ITEM_COUNT, WORK_ITERS, REPEATS]

	_base_data = PackedFloat32Array()
	_base_data.resize(ITEM_COUNT)
	var init_i := 0
	while init_i < ITEM_COUNT:
		_base_data[init_i] = float(init_i % 1000) * 0.001
		init_i += 1

	print("=== pure arithmetic, no builtin function calls ===")
	label_text += "=== pure arithmetic, no builtin function calls === \n"
	await _sweep(false)
	print("\n=== with sin()/sqrt() builtin calls ===")
	label_text += "\n === with sin()/sqrt() builtin calls === \n"
	await _sweep(true)

	print("\ndone")
	#get_tree().quit()

func _sweep(use_calls: bool) -> void:
	var best_1 := INF
	for r in REPEATS:
		best_1 = min(best_1, _run_once(1, use_calls))
		await get_tree().process_frame

	print("%-8s %-12s %-10s %-10s" % ["threads", "time_ms", "speedup", "efficiency"])
	label_text += "%-8s %-12s %-10s %-10s \n" % ["threads", "time_ms", "speedup", "efficiency"]
	var thread_counts: Array[int] = [1, 2, 4, 8, 16]
	for t in thread_counts:
		var best := INF
		for r in REPEATS:
			best = min(best, _run_once(t, use_calls))
			await get_tree().process_frame  # keep the window responsive between runs
		var speedup := best_1 / best
		var efficiency := speedup / float(t) * 100.0
		print("%-8d %-12.2f %-10.2f %-9.1f%%" % [t, best, speedup, efficiency])
		label_text += "%-8d %-12.2f %-10.2f %-9.1f%% \n" % [t, best, speedup, efficiency]

func _run_once(thread_count: int, use_calls: bool) -> float:
	var threads: Array[Thread] = []
	var chunk := ITEM_COUNT / thread_count
	var t0 := Time.get_ticks_usec()
	for t in thread_count:
		var begin := t * chunk
		var end := ITEM_COUNT if t == thread_count - 1 else begin + chunk
		var thread := Thread.new()
		if use_calls:
			thread.start(_work_chunk_calls.bind(begin, end))
		else:
			thread.start(_work_chunk_arith.bind(begin, end))
		threads.append(thread)
	for thread in threads:
		thread.wait_to_finish()
	var t1 := Time.get_ticks_usec()
	return (t1 - t0) / 1000.0

# Uses sin()/sqrt() builtin calls -- in testing, this is where GDScript's
# thread scaling collapses (and can go NEGATIVE past ~8 threads), because
# builtin function calls go through shared interpreter bookkeeping that
# threads end up serializing on.
func _work_chunk_calls(begin: int, end: int) -> void:
	var local_result := PackedFloat32Array()
	local_result.resize(end - begin)
	var i := begin
	while i < end:
		var x := _base_data[i]
		var k := 0
		while k < WORK_ITERS:
			x = sin(x) * 0.5 + sqrt(abs(x)) * 0.3
			k += 1
		local_result[i - begin] = x
		i += 1

# Same op count, but pure arithmetic (no builtin function calls). This scales
# like real multithreaded native code -- confirms the bottleneck above is the
# function-call path, not GDScript threading or the hardware in general.
func _work_chunk_arith(begin: int, end: int) -> void:
	var local_result := PackedFloat32Array()
	local_result.resize(end - begin)
	var i := begin
	while i < end:
		var x := _base_data[i]
		var k := 0
		while k < WORK_ITERS:
			x = x * 1.0000137 + 0.0000731
			k += 1
		local_result[i - begin] = x
		i += 1

func _process2(delta: float) -> void:
	$Label.text = label_text

func _on_button_pressed() -> void:
	run_simulation()
	
	
	
