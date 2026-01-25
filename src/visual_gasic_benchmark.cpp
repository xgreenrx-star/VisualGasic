#include "visual_gasic_benchmark.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/time.hpp>

void VisualGasicBenchmark::_bind_methods() {
    ClassDB::bind_method(D_METHOD("run_cpp_benchmark", "iterations", "inner"), &VisualGasicBenchmark::run_cpp_benchmark);
}

Dictionary VisualGasicBenchmark::run_cpp_benchmark(int64_t iterations, int64_t inner) {
    Dictionary result;
    if (iterations <= 0 || inner <= 0) {
        result["elapsed_us"] = 0;
        result["checksum"] = 0;
        return result;
    }

    uint64_t start = Time::get_singleton()->get_ticks_usec();
    int64_t sum = 0;
    for (int64_t i = 0; i < iterations; i++) {
        for (int64_t j = 0; j < inner; j++) {
            sum += j;
        }
    }
    uint64_t end = Time::get_singleton()->get_ticks_usec();

    result["elapsed_us"] = static_cast<int64_t>(end - start);
    result["checksum"] = sum;
    return result;
}
