#ifndef THREAD_BENCH_H
#define THREAD_BENCH_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

// Native (std::thread) version of the pure-arithmetic vs sin()/sqrt() A/B
// thread-scaling test. Call from GDScript to compare against the GDScript
// thread_bench_ab.gd results on the same machine.
class ThreadBench : public RefCounted {
	GDCLASS(ThreadBench, RefCounted)

protected:
	static void _bind_methods();

public:
	ThreadBench();
	~ThreadBench();

	// Returns an Array of Dictionaries, one per (pass, thread_count):
	// { "use_calls": bool, "threads": int, "time_ms": float, "speedup": float, "efficiency": float }
	// Runs the pure-arithmetic pass first, then the sin()/sqrt() pass.
	Array run_sweep(int item_count, int work_iters, int repeats, PackedInt32Array thread_counts) const;

private:
	double run_once(int item_count, int thread_count, int work_iters, bool use_calls) const;
};

} // namespace godot

#endif // THREAD_BENCH_H
