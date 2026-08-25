#ifndef VISUAL_GASIC_DRAW_BENCHMARK_H
#define VISUAL_GASIC_DRAW_BENCHMARK_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

using namespace godot;

class VisualGasicDrawBenchmark : public Node2D {
	GDCLASS(VisualGasicDrawBenchmark, Node2D);

	static constexpr int GRID_COLS = 50;
	static constexpr int CELL = 8;
	static constexpr int SPRITE_SIZE = 8;
	static constexpr real_t CIRCLE_RADIUS = 3.0;

	String workload;
	int count = 0;
	Dictionary result;
	bool ready = false;

	Ref<Texture2D> sprite_texture;

	bool moving_mode = false;
	int object_count = 0;
	int frame_target = 0;
	int warmup_frames = 0;
	PackedFloat32Array offsets;
	int frame = 0;
	int64_t draw_total_us = 0;
	int draw_samples = 0;
	bool finished = false;
	int64_t last_checksum = 0;

	static Vector2 grid_xy(int index);
	static int64_t draw_filled_rects(CanvasItem *canvas, int p_count);
	static int64_t draw_outline_rects(CanvasItem *canvas, int p_count);
	static int64_t draw_lines(CanvasItem *canvas, int p_count);
	static int64_t draw_circles(CanvasItem *canvas, int p_count);
	static int64_t draw_sprites(CanvasItem *canvas, const Ref<Texture2D> &texture, int p_count);
	static int64_t draw_polylines(CanvasItem *canvas, int p_count);
	static int64_t draw_mixed(CanvasItem *canvas, const Ref<Texture2D> &texture, int p_count);
	static int64_t run_workload(CanvasItem *canvas, const String &p_workload, int p_count, const Ref<Texture2D> &texture);

protected:
	static void _bind_methods();

public:
	void _ready() override;
	void _process(double delta) override;
	void _draw() override;

	void configure(const String &p_workload, int p_count);
	void configure_moving(int p_object_count, int p_frame_count, int p_warmup);
	bool is_ready() const;
	bool bench_finished() const;
	Dictionary get_result() const;
};

#endif // VISUAL_GASIC_DRAW_BENCHMARK_H
