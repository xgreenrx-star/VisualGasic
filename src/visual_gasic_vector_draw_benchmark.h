#ifndef VISUAL_GASIC_VECTOR_DRAW_BENCHMARK_H
#define VISUAL_GASIC_VECTOR_DRAW_BENCHMARK_H

#include "visual_gasic_vector_canvas.h"
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VisualGasicVectorDrawBenchmark : public VGVectorCanvas2D {
	GDCLASS(VisualGasicVectorDrawBenchmark, VGVectorCanvas2D);

	static constexpr int GRID_COLS = 50;
	static constexpr int CELL = 8;

	int count = 0;
	Dictionary result;
	bool ready = false;

	static Vector2 grid_xy(int index);
	static int64_t bench_uniform_rects(VGVectorCanvas2D *canvas, int p_count);

protected:
	static void _bind_methods();

public:
	void _draw() override;

	void configure(int p_count);
	bool is_ready() const;
	Dictionary get_result() const;
};

#endif // VISUAL_GASIC_VECTOR_DRAW_BENCHMARK_H
