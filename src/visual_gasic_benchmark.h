#ifndef VISUAL_GASIC_BENCHMARK_H
#define VISUAL_GASIC_BENCHMARK_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VisualGasicBenchmark : public Node {
    GDCLASS(VisualGasicBenchmark, Node);

protected:
    static void _bind_methods();

public:
    Dictionary run_cpp_benchmark(int64_t iterations, int64_t inner);
    Dictionary run_cpp_arithmetic(int64_t iterations, int64_t inner);
    Dictionary run_cpp_array_sum(int64_t iterations, int64_t size);
    Dictionary run_cpp_string_concat(int64_t iterations, int64_t inner);
    Dictionary run_cpp_branch(int64_t iterations, int64_t inner);
    Dictionary run_cpp_array_dict(int64_t iterations, int64_t size);
    Dictionary run_cpp_interop(int64_t iterations, int64_t inner);
    Dictionary run_cpp_allocations(int64_t iterations, int64_t size);
    Dictionary run_cpp_allocations_fast(int64_t iterations, int64_t size);
    Dictionary run_cpp_file_io(int64_t iterations, int64_t size);
};

#endif // VISUAL_GASIC_BENCHMARK_H
