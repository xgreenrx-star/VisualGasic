extends SceneTree

const Config = preload("../engine_lab/benchmarks/draw/draw_bench_config.gd")


func _init() -> void:
	var good := {
		"name": "MovingFilledRects",
		"gd": {"elapsed_us": 10, "checksum": 257901, "frames": 120},
		"vg": {"elapsed_us": 20, "checksum": 257901, "frames": 120},
		"cpp": {"elapsed_us": 5, "checksum": 257901, "frames": 120},
	}
	var cases: Array[Dictionary] = [
		{"name": "equal results", "entry": good, "error": ""},
	]
	var wrong_checksum: Dictionary = good.duplicate(true)
	wrong_checksum["vg"]["checksum"] = 257112
	cases.append({"name": "moving checksum mismatch", "entry": wrong_checksum, "error": "Checksum mismatch"})
	var extra_frame: Dictionary = good.duplicate(true)
	extra_frame["vg"]["frames"] = 121
	cases.append({"name": "extra draw frame", "entry": extra_frame, "error": "Incorrect measured frame count"})
	var missing_frame: Dictionary = good.duplicate(true)
	missing_frame["cpp"].erase("frames")
	cases.append({"name": "missing frame count", "entry": missing_frame, "error": "Incorrect measured frame count"})
	var missing_data: Dictionary = good.duplicate(true)
	missing_data["gd"].erase("checksum")
	cases.append({"name": "missing checksum", "entry": missing_data, "error": "Missing benchmark data"})
	var negative_time: Dictionary = good.duplicate(true)
	negative_time["vg"]["elapsed_us"] = -1
	cases.append({"name": "negative timing", "entry": negative_time, "error": "Negative benchmark timing"})
	var failed := 0
	for case in cases:
		var actual := Config.result_error(case["entry"])
		if actual != case["error"]:
			printerr("FAIL: ", case["name"], ": ", actual)
			failed += 1
		else:
			print("PASS: ", case["name"])
	quit(1 if failed else 0)
