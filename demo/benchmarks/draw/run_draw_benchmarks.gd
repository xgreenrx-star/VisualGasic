extends SceneTree

const DrawBenchConfig = preload("res://benchmarks/draw/draw_bench_config.gd")
const VG_DRAW_SCRIPT := preload("res://benchmarks/draw/bench_draw.vg")
const VG_MOVING_SCRIPT := preload("res://benchmarks/draw/bench_draw_moving.vg")
const GD_CANVAS := preload("res://benchmarks/draw/draw_bench_canvas_gd.gd")
const GD_MOVING := preload("res://benchmarks/draw/draw_bench_moving_gd.gd")

const WAIT_FRAMES := 60
const MOVING_WAIT_FRAMES := 360


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await self.process_frame
	await self.process_frame

	print("Draw benchmark warmup...")
	await _run_vg_draw("FilledRects", 100)

	print("\n=== Visual Gasic Draw Benchmarks ===")
	print("Metric: microseconds inside _draw (lower is faster)")
	print("MovingObjects: average _draw us over %d frames (%d objects)\n" % [
		DrawBenchConfig.MOVING_FRAME_COUNT,
		DrawBenchConfig.MOVING_OBJECT_COUNT,
	])

	var results: Array = []
	for workload in DrawBenchConfig.workload_counts().keys():
		var count: int = DrawBenchConfig.workload_counts()[workload]
		results.append(await run_draw_workload(workload, count))

	results.append(await run_moving_workload(
		"MovingFilledRects",
		DrawBenchConfig.MOVING_OBJECT_COUNT,
		DrawBenchConfig.MOVING_FRAME_COUNT,
		DrawBenchConfig.MOVING_WARMUP_FRAMES
	))

	for entry in results:
		_print_entry(entry)

	quit(0)


func run_draw_workload(workload: String, count: int) -> Dictionary:
	var gd_result := await _run_gd_draw(workload, count)
	var vg_result := await _run_vg_draw(workload, count)
	var cpp_result := await _run_cpp_draw(workload, count)
	return {
		"name": workload,
		"count": count,
		"gd": gd_result,
		"vg": vg_result,
		"cpp": cpp_result,
	}


func run_moving_workload(name: String, object_count: int, frame_count: int, warmup: int) -> Dictionary:
	var gd_result := await _run_gd_moving(object_count, frame_count, warmup)
	var vg_result := await _run_vg_moving(object_count, frame_count, warmup)
	var cpp_result := await _run_cpp_moving(object_count, frame_count, warmup)
	return {
		"name": name,
		"count": object_count,
		"gd": gd_result,
		"vg": vg_result,
		"cpp": cpp_result,
	}


func _run_gd_draw(workload: String, count: int) -> Dictionary:
	var node: Node2D = GD_CANVAS.new()
	root.add_child(node)
	node.configure(workload, count)
	node.queue_redraw()
	if not await _wait_until(Callable(node, "is_ready")):
		node.queue_free()
		return {}
	var result: Dictionary = node.get_result()
	node.queue_free()
	return result


func _run_vg_draw(workload: String, count: int) -> Dictionary:
	var node := Node2D.new()
	node.set_script(VG_DRAW_SCRIPT)
	root.add_child(node)
	node.call("ConfigureBench", workload, count)
	node.queue_redraw()
	if not await _wait_vg_draw(node):
		node.queue_free()
		return {}
	var result: Dictionary = node.call("GetBenchResult")
	node.queue_free()
	return result


func _run_cpp_draw(workload: String, count: int) -> Dictionary:
	var node = ClassDB.instantiate("VisualGasicDrawBenchmark")
	if node == null:
		push_error("Failed to instantiate VisualGasicDrawBenchmark")
		return {}
	root.add_child(node)
	node.configure(workload, count)
	node.queue_redraw()
	if not await _wait_until(Callable(node, "is_ready")):
		node.queue_free()
		return {}
	var result: Dictionary = node.get_result()
	node.queue_free()
	return result


func _run_gd_moving(object_count: int, frame_count: int, warmup: int) -> Dictionary:
	var node: Node2D = GD_MOVING.new()
	root.add_child(node)
	node.configure(object_count, frame_count, warmup)
	for _i in MOVING_WAIT_FRAMES:
		node.step_frame()
		await self.process_frame
		if node.bench_finished():
			break
	if not node.bench_finished():
		node.queue_free()
		return {}
	var result: Dictionary = node.get_result()
	node.queue_free()
	return result


func _run_vg_moving(object_count: int, frame_count: int, warmup: int) -> Dictionary:
	var node := Node2D.new()
	node.set_script(VG_MOVING_SCRIPT)
	root.add_child(node)
	node.call("ConfigureMoving", object_count, frame_count, warmup)
	if not await _wait_vg_moving(node):
		node.queue_free()
		return {}
	var result: Dictionary = node.call("GetMovingResult")
	node.queue_free()
	return result


func _run_cpp_moving(object_count: int, frame_count: int, warmup: int) -> Dictionary:
	var node = ClassDB.instantiate("VisualGasicDrawBenchmark")
	if node == null:
		return {}
	root.add_child(node)
	await self.process_frame
	node.configure_moving(object_count, frame_count, warmup)
	if not await _wait_until(Callable(node, "bench_finished"), MOVING_WAIT_FRAMES):
		node.queue_free()
		return {}
	var result: Dictionary = node.get_result()
	node.queue_free()
	return result


func _wait_until(predicate: Callable, max_frames: int = WAIT_FRAMES) -> bool:
	for _i in max_frames:
		await self.process_frame
		if predicate.call():
			return true
	return false


func _wait_vg_draw(node: Node) -> bool:
	for _i in WAIT_FRAMES:
		await self.process_frame
		if node.has_method("IsBenchReady") and node.call("IsBenchReady"):
			return true
	return false


func _wait_vg_moving(node: Node) -> bool:
	for _i in MOVING_WAIT_FRAMES:
		await self.process_frame
		if node.has_method("IsMovingFinished") and node.call("IsMovingFinished"):
			return true
	return false


func _print_entry(entry: Dictionary) -> void:
	print("\n=== ", entry["name"], " (n=", entry["count"], ") ===")
	var gd_result: Dictionary = entry.get("gd", {})
	var vg_result: Dictionary = entry.get("vg", {})
	var cpp_result: Dictionary = entry.get("cpp", {})

	print("GDScript: ", gd_result)
	print("VisualGasic: ", vg_result)
	print("C++: ", cpp_result)

	if gd_result.is_empty() or vg_result.is_empty() or cpp_result.is_empty():
		push_warning("Skipping " + str(entry["name"]) + " due to missing benchmark data.")
		return
	var gd_cs = gd_result.get("checksum")
	var vg_cs = vg_result.get("checksum")
	var cpp_cs = cpp_result.get("checksum")
	var is_moving := str(entry["name"]).begins_with("Moving")
	if not is_moving and (gd_cs != vg_cs or gd_cs != cpp_cs):
		push_warning("Checksum mismatch in " + str(entry["name"]) + " — results may not be comparable.")
		print("  checksums gd=", gd_cs, " vg=", vg_cs, " cpp=", cpp_cs)

	var gd_us := float(gd_result.get("elapsed_us", 0))
	var vg_us := float(vg_result.get("elapsed_us", 0))
	var cpp_us := float(cpp_result.get("elapsed_us", 0))

	var fastest := "GDScript"
	var fastest_us := gd_us
	if vg_us < fastest_us:
		fastest = "VisualGasic"
		fastest_us = vg_us
	if cpp_us < fastest_us:
		fastest = "C++"
		fastest_us = cpp_us

	print("VisualGasic vs GDScript: ", vg_us / max(1.0, gd_us), "x")
	print("C++ vs GDScript: ", cpp_us / max(1.0, gd_us), "x")
	print("Fastest: ", fastest, " (", int(fastest_us), " us)")
