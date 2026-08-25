#include "visual_gasic_vector_draw_benchmark.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void VisualGasicVectorDrawBenchmark::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "count"), &VisualGasicVectorDrawBenchmark::configure);
	ClassDB::bind_method(D_METHOD("is_ready"), &VisualGasicVectorDrawBenchmark::is_ready);
	ClassDB::bind_method(D_METHOD("get_result"), &VisualGasicVectorDrawBenchmark::get_result);
}

Vector2 VisualGasicVectorDrawBenchmark::grid_xy(int index) {
	return Vector2(float(index % GRID_COLS) * float(CELL), float(index / GRID_COLS) * float(CELL));
}

int64_t VisualGasicVectorDrawBenchmark::bench_uniform_rects(VGVectorCanvas2D *canvas, int p_count) {
	PackedVector2Array rects;
	rects.resize(p_count * 2);
	int64_t cs = 0;
	Color color(0.2f, 0.4f, 0.9f, 1.0f);
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		rects[i * 2] = p;
		rects[i * 2 + 1] = Vector2(CELL, CELL);
		cs += int64_t(p.x) + int64_t(p.y) + CELL;
	}
	canvas->DrawRectsUniform(rects, color, true);
	return cs;
}

void VisualGasicVectorDrawBenchmark::configure(int p_count) {
	count = p_count;
	ready = false;
	result = Dictionary();
}

bool VisualGasicVectorDrawBenchmark::is_ready() const {
	return ready;
}

Dictionary VisualGasicVectorDrawBenchmark::get_result() const {
	return result;
}

void VisualGasicVectorDrawBenchmark::_draw() {
	if (count <= 0 || ready) {
		return;
	}

	int64_t t0 = Time::get_singleton()->get_ticks_usec();
	int64_t cs = bench_uniform_rects(this, count);
	VGVectorCanvas2D::_draw();
	int64_t elapsed = Time::get_singleton()->get_ticks_usec() - t0;

	result["elapsed_us"] = elapsed;
	result["checksum"] = cs;
	ready = true;
	count = 0;
}
