extends Node2D

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")
const GD_CANVAS := preload("res://benchmarks/draw/draw_bench_canvas_gd.gd")
const GD_MOVING := preload("res://benchmarks/draw/draw_bench_moving_gd.gd")
const VG_DRAW := preload("res://benchmarks/draw/bench_draw.vg")
const VG_MOVING := preload("res://benchmarks/draw/bench_draw_moving.vg")

@onready var _label: Label = $CanvasLayer/Panel/Margin/VBox/Status
@onready var _results: RichTextLabel = $CanvasLayer/Panel/Margin/VBox/Results

var _workloads: Array = []
var _workload_index := 0
var _lang_index := 0
var _langs := ["GDScript", "VisualGasic", "C++"]
var _pending_node: Node = null
var _state := "idle"
var _wait_frames := 0
var _rows: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_workloads.clear()
	for name in DrawBenchConfig.workload_counts().keys():
		_workloads.append({"name": name, "count": DrawBenchConfig.workload_counts()[name], "moving": false})
	_workloads.append({
		"name": "MovingFilledRects",
		"count": DrawBenchConfig.MOVING_OBJECT_COUNT,
		"moving": true,
	})
	_label.text = "Starting draw benchmarks..."
	call_deferred("_start_next")


func _start_next() -> void:
	if _workload_index >= _workloads.size():
		_label.text = "Done — see results below"
		_results.text = "\n".join(_rows)
		return

	var spec: Dictionary = _workloads[_workload_index]
	var lang := _langs[_lang_index]
	_label.text = "%s / %s" % [spec["name"], lang]
	_state = "setup"
	_wait_frames = 0
	_begin_lang(spec, lang)


func _begin_lang(spec: Dictionary, lang: String) -> void:
	_cleanup_pending()
	match lang:
		"GDScript":
			if spec["moving"]:
				var node: Node2D = GD_MOVING.new()
				add_child(node)
				node.configure(spec["count"], DrawBenchConfig.MOVING_FRAME_COUNT, DrawBenchConfig.MOVING_WARMUP_FRAMES)
				_pending_node = node
			else:
				var node: Node2D = GD_CANVAS.new()
				add_child(node)
				node.configure(spec["name"], spec["count"])
				node.queue_redraw()
				_pending_node = node
		"VisualGasic":
			var node := Node2D.new()
			if spec["moving"]:
				node.set_script(VG_MOVING)
				add_child(node)
				node.call("ConfigureMoving", spec["count"], DrawBenchConfig.MOVING_FRAME_COUNT, DrawBenchConfig.MOVING_WARMUP_FRAMES)
			else:
				node.set_script(VG_DRAW)
				add_child(node)
				node.call("ConfigureBench", spec["name"], spec["count"])
				node.queue_redraw()
			_pending_node = node
		"C++":
			var node = ClassDB.instantiate("VisualGasicDrawBenchmark")
			add_child(node)
			if spec["moving"]:
				node.configure_moving(spec["count"], DrawBenchConfig.MOVING_FRAME_COUNT, DrawBenchConfig.MOVING_WARMUP_FRAMES)
			else:
				node.configure(spec["name"], spec["count"])
				node.queue_redraw()
			_pending_node = node
	_state = "wait"


func _process(_delta: float) -> void:
	if _state != "wait" or _pending_node == null:
		return

	_wait_frames += 1
	var spec: Dictionary = _workloads[_workload_index]
	var lang := _langs[_lang_index]
	var done := false

	if spec["moving"] and lang == "GDScript" and _pending_node.has_method("step_frame"):
		_pending_node.step_frame()

	if spec["moving"]:
		if _pending_node.has_method("bench_finished") and _pending_node.call("bench_finished"):
			done = true
		elif _pending_node.has_method("is_finished") and _pending_node.call("is_finished"):
			done = true
		elif _pending_node.has_method("IsMovingFinished") and _pending_node.call("IsMovingFinished"):
			done = true
	elif _pending_node.has_method("is_ready") and _pending_node.call("is_ready"):
		done = true
	elif _pending_node.has_method("IsBenchReady") and _pending_node.call("IsBenchReady"):
		done = true

	if done or _wait_frames > 240:
		var result: Dictionary = {}
		if _pending_node.has_method("get_result"):
			result = _pending_node.get_result()
		elif _pending_node.has_method("GetBenchResult"):
			result = _pending_node.call("GetBenchResult")
		elif _pending_node.has_method("GetMovingResult"):
			result = _pending_node.call("GetMovingResult")

		var us := int(result.get("elapsed_us", -1))
		_rows.append("%s | %s | %d us | cs=%s" % [spec["name"], lang, us, str(result.get("checksum", "?"))])
		_results.text = "\n".join(_rows)

		_cleanup_pending()
		_lang_index += 1
		if _lang_index >= _langs.size():
			_lang_index = 0
			_workload_index += 1
		_state = "idle"
		call_deferred("_start_next")


func _cleanup_pending() -> void:
	if _pending_node != null and is_instance_valid(_pending_node):
		_pending_node.queue_free()
	_pending_node = null
