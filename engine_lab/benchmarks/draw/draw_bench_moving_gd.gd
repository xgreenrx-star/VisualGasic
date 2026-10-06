extends Node2D

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")

var _object_count := DrawBenchConfig.MOVING_OBJECT_COUNT
var _frame_target := DrawBenchConfig.MOVING_FRAME_COUNT
var _warmup := DrawBenchConfig.MOVING_WARMUP_FRAMES
var _offsets := PackedInt64Array()
var _frame := 0
var _last_drawn_frame := -1
var _draw_total_us := 0
var _draw_samples := 0
var _finished := false
var _last_checksum := 0
var _result: Dictionary = {}


func configure(object_count: int, frame_count: int, warmup_frames: int) -> void:
	_object_count = object_count
	_frame_target = frame_count
	_warmup = warmup_frames
	_offsets.resize(object_count)
	for i in object_count:
		_offsets[i] = i * 30
	_frame = 0
	_last_drawn_frame = -1
	_draw_total_us = 0
	_draw_samples = 0
	_finished = false
	_last_checksum = 0
	_result = {}


func bench_finished() -> bool:
	return _finished


func get_result() -> Dictionary:
	return _result


func step_frame() -> void:
	if _finished:
		return
	if _frame > _warmup and _last_drawn_frame != _frame:
		return
	if _frame >= _frame_target + _warmup:
		var avg_us := 0
		if _draw_samples > 0:
			avg_us = int(_draw_total_us / _draw_samples)
		_result = {
			"elapsed_us": avg_us,
			"checksum": _last_checksum,
			"frames": _draw_samples,
		}
		_finished = true
		return

	for i in _object_count:
		_offsets[i] += 17 + (i % 5) * 3
		if _offsets[i] > 8000:
			_offsets[i] = 0

	_frame += 1
	queue_redraw()


func _draw() -> void:
	if _finished or _last_drawn_frame == _frame or _frame <= _warmup or _frame > _frame_target + _warmup:
		return
	_last_drawn_frame = _frame

	var start := Time.get_ticks_usec()
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.FILL_COLOR
	for i in _object_count:
		var x := float(_offsets[i]) / 10.0
		var y := float((i * 7) % 40) * cell
		draw_rect(Rect2(x, y, cell, cell), color, true)
		cs += _offsets[i] / 10 + int(y) + DrawBenchConfig.CELL

	_draw_total_us += Time.get_ticks_usec() - start
	_draw_samples += 1
	_last_checksum = cs
