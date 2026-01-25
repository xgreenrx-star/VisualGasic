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
};

#endif // VISUAL_GASIC_BENCHMARK_H
