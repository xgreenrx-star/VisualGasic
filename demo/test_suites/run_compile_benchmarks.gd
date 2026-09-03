extends SceneTree

## Headless VG vs GDScript compile/reload timing (parse + bytecode + optimizer).
## Metric: median reload elapsed_us (lower is faster). Does not include runtime execution.

const WARMUP := 3
const ITERS := 15

const WORKLOADS := [
	{
		"name": "HelloWorld",
		"vg_path": "res://benchmarks/compile/hello.vg",
		"gd_path": "res://benchmarks/compile/hello.gd",
	},
	{
		"name": "BenchCompute",
		"vg_path": "res://bench.vg",
		"gd_path": "user://compile_bench_medium.gd",
		"synthetic_gd_lines": 340,
	},
	{
		"name": "SyntheticLarge",
		"vg_path": "user://compile_bench_large.vg",
		"gd_path": "user://compile_bench_large.gd",
		"synthetic_lines": 1800,
	},
]


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await process_frame
	await process_frame

	_write_synthetic_large()

	print("=== Visual Gasic Compile Benchmarks ===")
	print("Metric: median script reload time (microseconds, lower is faster)")
	print("Phases: tokenize + parse + compile + optimizer (VG); GDScript analyzer + compile")
	print("")

	var results: Array = []
	for wl in WORKLOADS:
		var row := _bench_workload(wl)
		if row.is_empty():
			push_error("Compile benchmark failed: %s" % wl["name"])
			quit(1)
			return
		results.append(row)
		print("=== %s ===" % wl["name"])
		print("  lines (approx): vg=%d gd=%d" % [row["vg_lines"], row["gd_lines"]])
		print("  VisualGasic reload: { \"elapsed_us\": %d }" % row["vg_us"])
		print("  GDScript reload:    { \"elapsed_us\": %d }" % row["gd_us"])
		if row["gd_us"] > 0:
			print("  VG vs GDScript: %.3fx" % (float(row["vg_us"]) / float(row["gd_us"])))
		print("")

	print("Compile benchmarks finished.")
	quit(0)


func _write_synthetic_large() -> void:
	for wl in WORKLOADS:
		if wl.has("synthetic_lines"):
			var n: int = int(wl["synthetic_lines"])
			_store_user_file(String(wl["vg_path"]), _generate_vg(n))
			_store_user_file(String(wl["gd_path"]), _generate_gd(n))
		elif wl.has("synthetic_gd_lines"):
			_store_user_file(String(wl["gd_path"]), _generate_gd(int(wl["synthetic_gd_lines"])))


func _store_user_file(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % path)
		return
	f.store_string(text)
	f.close()


func _generate_vg(target_lines: int) -> String:
	var out: PackedStringArray = ["' Generated compile benchmark (VG)\n"]
	var idx := 0
	while out.size() < target_lines:
		out.append("Sub Bench_%d()\n" % idx)
		out.append("    Dim j As Long\n")
		out.append("    Dim acc As Long\n")
		out.append("    For j = 1 To 12\n")
		out.append("        If j Mod 2 = 0 Then\n")
		out.append("            acc = acc + j * 3\n")
		out.append("        Else\n")
		out.append("            acc = acc - j\n")
		out.append("        End If\n")
		out.append("    Next j\n")
		out.append("End Sub\n\n")
		idx += 1
	return "".join(out)


func _generate_gd(target_lines: int) -> String:
	var out: PackedStringArray = ["extends Node\n\n"]
	var idx := 0
	while out.size() < target_lines:
		out.append("func bench_%d() -> void:\n" % idx)
		out.append("    var acc: int = 0\n")
		out.append("    for j in range(1, 13):\n")
		out.append("        if j % 2 == 0:\n")
		out.append("            acc += j * 3\n")
		out.append("        else:\n")
		out.append("            acc -= j\n")
		out.append("\n")
		idx += 1
	return "".join(out)


func _bench_workload(wl: Dictionary) -> Dictionary:
	var vg_path: String = wl["vg_path"]
	var gd_path: String = wl["gd_path"]

	var vg_us := _median_vg_reload_us(vg_path)
	if vg_us < 0:
		return {}

	var gd_us := _median_gd_reload_us(gd_path)
	if gd_us < 0:
		return {}

	return {
		"name": wl["name"],
		"vg_lines": _count_lines(_read_text(vg_path)),
		"gd_lines": _count_lines(_read_text(gd_path)),
		"vg_us": vg_us,
		"gd_us": gd_us,
	}


func _read_text(path: String) -> String:
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return ""
		return FileAccess.get_file_as_string(path)
	if ResourceLoader.exists(path):
		return FileAccess.get_file_as_string(path)
	return ""


func _count_lines(text: String) -> int:
	if text.is_empty():
		return 0
	return text.split("\n", false).size()


func _median_vg_reload_us(path: String) -> int:
	var script: Script = load(path)
	if script == null:
		push_error("VG load failed: %s" % path)
		return -1
	if script.reload() != OK:
		push_error("VG initial reload failed: %s" % path)

	var samples: Array[int] = []
	for i in ITERS + WARMUP:
		var t0 := Time.get_ticks_usec()
		var err := script.reload()
		var elapsed := Time.get_ticks_usec() - t0
		if err != OK:
			push_error("VG reload failed iter %d: %s" % [i, path])
			return -1
		if i >= WARMUP:
			samples.append(elapsed)
	return _median(samples)


func _median_gd_reload_us(path: String) -> int:
	var script := GDScript.new()
	script.source_code = _read_text(path)
	if script.source_code.is_empty():
		push_error("GD source empty: %s" % path)
		return -1
	if script.reload() != OK:
		push_error("GD initial reload failed: %s" % path)

	var samples: Array[int] = []
	for i in ITERS + WARMUP:
		var t0 := Time.get_ticks_usec()
		var err := script.reload()
		var elapsed := Time.get_ticks_usec() - t0
		if err != OK:
			push_error("GD reload failed iter %d: %s" % [i, path])
			return -1
		if i >= WARMUP:
			samples.append(elapsed)
	return _median(samples)


func _median(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
