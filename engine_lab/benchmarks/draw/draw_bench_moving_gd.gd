extends Node2D

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")

var _object_count := DrawBenchConfig.MOVING_OBJECT_COUNT
var _frame_target := DrawBenchConfig.MOVING_FRAME_COUNT
var _warmup := DrawBenchConfig.MOVING_WARMUP_FRAMES
var _offsets: PackedFloat32Array = PackedFloat32Array()
var _frame := 0
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
		_offsets[i] = float(i * 3)
	_frame = 0
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
		_offsets[i] += 1.7 + float(i % 5) * 0.3
		if _offsets[i] > 800.0:
			_offsets[i] = 0.0

	_frame += 1
	queue_redraw()


func _draw() -> void:
	if _frame <= _warmup or _frame > _frame_target + _warmup:
		return

	var start := Time.get_ticks_usec()
	var cs := 0
	var cell := float(DrawBenchConfig.CELL)
	var color := DrawBenchConfig.FILL_COLOR
	for i in _object_count:
		var x := _offsets[i]
		var y := float((i * 7) % 40) * cell
		draw_rect(Rect2(x, y, cell, cell), color, true)
		cs += int(x) + int(y) + DrawBenchConfig.CELL

	_draw_total_us += Time.get_ticks_usec() - start
	_draw_samples += 1
	_last_checksum = cs
