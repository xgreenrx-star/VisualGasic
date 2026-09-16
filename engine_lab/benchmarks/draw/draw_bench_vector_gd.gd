extends VGVectorCanvas2D
## GDScript vector-canvas draw benchmark — build rects then DrawRectsUniform once per _draw.

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")
const DrawBenchWorkloads = preload("res://benchmarks/draw/draw_bench_workloads.gd")

var _count := 0
var _elapsed_us := 0
var _checksum := 0
var _ready := false


func configure(count: int) -> void:
	_count = count
	_ready = false
	_elapsed_us = 0
	_checksum = 0


func is_ready() -> bool:
	return _ready


func get_result() -> Dictionary:
	return {
		"elapsed_us": _elapsed_us,
		"checksum": _checksum,
	}


func _draw() -> void:
	if _count <= 0 or _ready:
		return

	var t0 := Time.get_ticks_usec()
	_checksum = DrawBenchWorkloads.vector_canvas_uniform_rects(self, _count)
	ExecuteQueuedCommands()
	_elapsed_us = Time.get_ticks_usec() - t0
	_ready = true
	_count = 0
