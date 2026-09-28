#include "thread_bench.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <thread>
#include <vector>

using namespace godot;

namespace {

void work_chunk_calls(std::vector<float> &data, size_t begin, size_t end, int work_iters) {
	for (size_t i = begin; i < end; ++i) {
		float x = data[i];
		for (int k = 0; k < work_iters; ++k) {
			x = std::sin(x) * 0.5f + std::sqrt(std::fabs(x)) * 0.3f;
		}
		data[i] = x;
	}
}

void work_chunk_arith(std::vector<float> &data, size_t begin, size_t end, int work_iters) {
	for (size_t i = begin; i < end; ++i) {
		float x = data[i];
		for (int k = 0; k < work_iters; ++k) {
			x = x * 1.0000137f + 0.0000731f;
		}
		data[i] = x;
	}
}

} // namespace

ThreadBench::ThreadBench() {}
ThreadBench::~ThreadBench() {}

void ThreadBench::_bind_methods() {
	ClassDB::bind_method(D_METHOD("run_sweep", "item_count", "work_iters", "repeats", "thread_counts"), &ThreadBench::run_sweep);
}

double ThreadBench::run_once(int item_count, int thread_count, int work_iters, bool use_calls) const {
	std::vector<float> data(static_cast<size_t>(item_count));
	for (int i = 0; i < item_count; ++i) {
		data[i] = static_cast<float>(i % 1000) * 0.001f;
	}

	std::vector<std::thread> threads;
	threads.reserve(thread_count);

	auto t0 = std::chrono::high_resolution_clock::now();

	size_t chunk = static_cast<size_t>(item_count) / static_cast<size_t>(thread_count);
	for (int t = 0; t < thread_count; ++t) {
		size_t begin = static_cast<size_t>(t) * chunk;
		size_t end = (t == thread_count - 1) ? static_cast<size_t>(item_count) : begin + chunk;
		if (use_calls) {
			threads.emplace_back(work_chunk_calls, std::ref(data), begin, end, work_iters);
		} else {
			threads.emplace_back(work_chunk_arith, std::ref(data), begin, end, work_iters);
		}
	}
	for (auto &th : threads) {
		th.join();
	}

	auto t1 = std::chrono::high_resolution_clock::now();
	return std::chrono::duration<double, std::milli>(t1 - t0).count();
}

Array ThreadBench::run_sweep(int item_count, int work_iters, int repeats, PackedInt32Array thread_counts) const {
	Array results;

	for (int pass = 0; pass < 2; ++pass) {
		bool use_calls = (pass == 1);

		double best_1 = 1e18;
		for (int r = 0; r < repeats; ++r) {
			best_1 = std::min(best_1, run_once(item_count, 1, work_iters, use_calls));
		}

		for (int idx = 0; idx < thread_counts.size(); ++idx) {
			int t = thread_counts[idx];
			double best = 1e18;
			for (int r = 0; r < repeats; ++r) {
				best = std::min(best, run_once(item_count, t, work_iters, use_calls));
			}
			double speedup = best_1 / best;
			double efficiency = speedup / static_cast<double>(t) * 100.0;

			Dictionary row;
			row["use_calls"] = use_calls;
			row["threads"] = t;
			row["time_ms"] = best;
			row["speedup"] = speedup;
			row["efficiency"] = efficiency;
			results.push_back(row);
		}
	}

	return results;
}
