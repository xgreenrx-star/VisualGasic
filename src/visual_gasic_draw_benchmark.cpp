#include "visual_gasic_draw_benchmark.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void VisualGasicDrawBenchmark::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "workload", "count"), &VisualGasicDrawBenchmark::configure);
	ClassDB::bind_method(D_METHOD("configure_moving", "object_count", "frame_count", "warmup"), &VisualGasicDrawBenchmark::configure_moving);
	ClassDB::bind_method(D_METHOD("is_ready"), &VisualGasicDrawBenchmark::is_ready);
	ClassDB::bind_method(D_METHOD("bench_finished"), &VisualGasicDrawBenchmark::bench_finished);
	ClassDB::bind_method(D_METHOD("get_result"), &VisualGasicDrawBenchmark::get_result);
}

Vector2 VisualGasicDrawBenchmark::grid_xy(int index) {
	return Vector2(float(index % GRID_COLS) * float(CELL), float(index / GRID_COLS) * float(CELL));
}

int64_t VisualGasicDrawBenchmark::draw_filled_rects(CanvasItem *canvas, int p_count) {
	int64_t cs = 0;
	Color color(0.2f, 0.4f, 0.9f, 1.0f);
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		canvas->draw_rect(Rect2(p.x, p.y, CELL, CELL), color, true);
		cs += int64_t(p.x) + int64_t(p.y) + CELL;
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_outline_rects(CanvasItem *canvas, int p_count) {
	int64_t cs = 0;
	Color color(0.9f, 0.5f, 0.1f, 1.0f);
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		canvas->draw_rect(Rect2(p.x, p.y, CELL, CELL), color, false);
		cs += int64_t(p.x) + int64_t(p.y) + CELL;
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_lines(CanvasItem *canvas, int p_count) {
	int64_t cs = 0;
	Color color(0.1f, 0.8f, 0.3f, 1.0f);
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		canvas->draw_line(p, p + Vector2(CELL, CELL * 0.5f), color, 1.0f);
		cs += int64_t(p.x) + int64_t(p.y) + CELL;
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_circles(CanvasItem *canvas, int p_count) {
	int64_t cs = 0;
	Color color(0.8f, 0.2f, 0.6f, 1.0f);
	real_t half = CELL * 0.5f;
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		canvas->draw_circle(p + Vector2(half, half), CIRCLE_RADIUS, color);
		cs += int64_t(p.x) + int64_t(p.y) + int64_t(CIRCLE_RADIUS);
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_sprites(CanvasItem *canvas, const Ref<Texture2D> &texture, int p_count) {
	int64_t cs = 0;
	if (!texture.is_valid()) {
		return 0;
	}
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		canvas->draw_texture_rect(texture, Rect2(p.x, p.y, SPRITE_SIZE, SPRITE_SIZE), false);
		cs += int64_t(p.x) + int64_t(p.y) + SPRITE_SIZE;
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_polylines(CanvasItem *canvas, int p_count) {
	int64_t cs = 0;
	Color color(0.1f, 0.8f, 0.3f, 1.0f);
	for (int i = 0; i < p_count; i++) {
		Vector2 p = grid_xy(i);
		PackedVector2Array pts;
		pts.push_back(p);
		pts.push_back(p + Vector2(CELL, 0));
		pts.push_back(p + Vector2(CELL, CELL));
		pts.push_back(p + Vector2(0, CELL));
		pts.push_back(p);
		canvas->draw_polyline(pts, color, 1.0f);
		cs += int64_t(p.x) + int64_t(p.y) + CELL;
	}
	return cs;
}

int64_t VisualGasicDrawBenchmark::draw_mixed(CanvasItem *canvas, const Ref<Texture2D> &texture, int p_count) {
	int64_t cs = 0;
	cs += draw_filled_rects(canvas, p_count);
	cs += draw_lines(canvas, p_count);
	cs += draw_circles(canvas, p_count / 2);
	cs += draw_sprites(canvas, texture, p_count / 2);
	return cs;
}

int64_t VisualGasicDrawBenchmark::run_workload(CanvasItem *canvas, const String &p_workload, int p_count, const Ref<Texture2D> &texture) {
	if (p_workload == "FilledRects") {
		return draw_filled_rects(canvas, p_count);
	}
	if (p_workload == "OutlineRects") {
		return draw_outline_rects(canvas, p_count);
	}
	if (p_workload == "Lines") {
		return draw_lines(canvas, p_count);
	}
	if (p_workload == "Circles") {
		return draw_circles(canvas, p_count);
	}
	if (p_workload == "Sprites") {
		return draw_sprites(canvas, texture, p_count);
	}
	if (p_workload == "Polylines") {
		return draw_polylines(canvas, p_count);
	}
	if (p_workload == "Mixed") {
		return draw_mixed(canvas, texture, p_count);
	}
	UtilityFunctions::push_error("Unknown draw workload: " + p_workload);
	return 0;
}

void VisualGasicDrawBenchmark::_ready() {
	Ref<Image> img = Image::create(SPRITE_SIZE, SPRITE_SIZE, false, Image::FORMAT_RGBA8);
	img->fill(Color(0.2f, 0.4f, 0.9f, 1.0f));
	sprite_texture = ImageTexture::create_from_image(img);
}

void VisualGasicDrawBenchmark::configure(const String &p_workload, int p_count) {
	moving_mode = false;
	set_process(false);
	workload = p_workload;
	count = p_count;
	ready = false;
	result = Dictionary();
}

void VisualGasicDrawBenchmark::configure_moving(int p_object_count, int p_frame_count, int p_warmup) {
	moving_mode = true;
	workload = "";
	ready = false;
	finished = false;
	object_count = p_object_count;
	frame_target = p_frame_count;
	warmup_frames = p_warmup;
	frame = 0;
	draw_total_us = 0;
	draw_samples = 0;
	last_checksum = 0;
	result = Dictionary();
	offsets.resize(object_count);
	for (int i = 0; i < object_count; i++) {
		offsets[i] = float(i * 3);
	}
	set_process(true);
}

bool VisualGasicDrawBenchmark::is_ready() const {
	return ready;
}

bool VisualGasicDrawBenchmark::bench_finished() const {
	return finished;
}

Dictionary VisualGasicDrawBenchmark::get_result() const {
	return result;
}

void VisualGasicDrawBenchmark::_process(double delta) {
	if (!moving_mode || finished) {
		return;
	}

	if (frame >= frame_target + warmup_frames) {
		int64_t avg_us = 0;
		if (draw_samples > 0) {
			avg_us = draw_total_us / draw_samples;
		}
		Dictionary d;
		d["elapsed_us"] = avg_us;
		d["checksum"] = last_checksum;
		d["frames"] = draw_samples;
		result = d;
		finished = true;
		ready = true;
		set_process(false);
		return;
	}

	for (int i = 0; i < object_count; i++) {
		offsets[i] += 1.7f + float(i % 5) * 0.3f;
		if (offsets[i] > 800.0f) {
			offsets[i] = 0.0f;
		}
	}

	frame++;
	queue_redraw();
}

void VisualGasicDrawBenchmark::_draw() {
	if (moving_mode) {
		if (frame <= warmup_frames || frame > frame_target + warmup_frames) {
			return;
		}

		uint64_t start = Time::get_singleton()->get_ticks_usec();
		int64_t cs = 0;
		Color color(0.2f, 0.4f, 0.9f, 1.0f);
		for (int i = 0; i < object_count; i++) {
			real_t x = offsets[i];
			real_t y = float((i * 7) % 40) * float(CELL);
			draw_rect(Rect2(x, y, CELL, CELL), color, true);
			cs += int64_t(x) + int64_t(y) + CELL;
		}
		draw_total_us += int64_t(Time::get_singleton()->get_ticks_usec() - start);
		draw_samples++;
		last_checksum = cs;
		return;
	}

	if (workload.is_empty()) {
		return;
	}

	uint64_t start = Time::get_singleton()->get_ticks_usec();
	int64_t checksum = run_workload(this, workload, count, sprite_texture);
	int64_t elapsed = int64_t(Time::get_singleton()->get_ticks_usec() - start);

	Dictionary d;
	d["elapsed_us"] = elapsed;
	d["checksum"] = checksum;
	result = d;
	ready = true;
	workload = "";
}
