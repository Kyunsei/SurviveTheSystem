extends Node
## Calls the native (GDExtension) ThreadBench.run_sweep -- compare these
## numbers directly against test.gd (the pure-GDScript version) on this
## same machine.

const ITEM_COUNT := 1000000
const WORK_ITERS := 60
const REPEATS := 3
var label_text = ""


func run_simulation() -> void:
	print("OS.get_processor_count() = %d\n" % OS.get_processor_count())
	label_text = "OS.get_processor_count() = %d\n" % OS.get_processor_count()


	var bench := ThreadBench.new()
	var thread_counts := PackedInt32Array([1, 2, 4, 8, 16])
	var results: Array = bench.run_sweep(ITEM_COUNT, WORK_ITERS, REPEATS, thread_counts)

	var printed_arith_header := false
	var printed_calls_header := false
	for row in results:
		var use_calls: bool = row["use_calls"]
		if not use_calls and not printed_arith_header:
			print("=== pure arithmetic, no builtin function calls (native) ===")
			label_text += "=== pure arithmetic, no builtin function calls (native) === \n"
			print("%-8s %-12s %-10s %-10s" % ["threads", "time_ms", "speedup", "efficiency"])
			label_text += "%-8s %-12s %-10s %-10s \n" % ["threads", "time_ms", "speedup", "efficiency"]

			printed_arith_header = true
		if use_calls and not printed_calls_header:
			print("\n=== with sin()/sqrt() builtin calls (native) ===")
			label_text += "\n=== with sin()/sqrt() builtin calls (native) === \n"
			print("%-8s %-12s %-10s %-10s" % ["threads", "time_ms", "speedup", "efficiency"])
			label_text += "%-8s %-12s %-10s %-10s \n" % ["threads", "time_ms", "speedup", "efficiency"]
			printed_calls_header = true
		print("%-8d %-12.2f %-10.2f %-9.1f%%" % [row["threads"], row["time_ms"], row["speedup"], row["efficiency"]])
		label_text += "%-8d %-12.2f %-10.2f %-9.1f%% \n" % [row["threads"], row["time_ms"], row["speedup"], row["efficiency"]]
	print("\ndone")
	#get_tree().quit()

func _process(delta: float) -> void:
	$Label2.text = label_text

func _on_button_pressed() -> void:
	run_simulation()
