extends Node2D

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")
const DrawBenchWorkloads = preload("res://benchmarks/draw/draw_bench_workloads.gd")

var _workload := ""
var _count := 0
var _result: Dictionary = {}
var _sprite_texture: Texture2D = null


func _ready() -> void:
	var img := Image.create(
		DrawBenchConfig.SPRITE_SIZE,
		DrawBenchConfig.SPRITE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	img.fill(DrawBenchConfig.FILL_COLOR)
	_sprite_texture = ImageTexture.create_from_image(img)


func configure(workload: String, count: int) -> void:
	_workload = workload
	_count = count
	_result = {}


func is_ready() -> bool:
	return not _result.is_empty()


func get_result() -> Dictionary:
	return _result


func _draw() -> void:
	if _workload.is_empty():
		return

	var start := Time.get_ticks_usec()
	var checksum := DrawBenchWorkloads.run_workload(self, _workload, _count, _sprite_texture)
	_result = {
		"elapsed_us": Time.get_ticks_usec() - start,
		"checksum": checksum,
	}
	_workload = ""
