extends SceneTree

## Headless smoke test for the C++ profiler bridge.
## Run with:
##   ./Godot_v4.6.1-stable_linux.x86_64 --headless --path demo --script test_profiler_bridge.gd

func _init() -> void:
	var failures := 0

	# 1. Class must be registered.
	if not ClassDB.class_exists(&"VisualGasicLanguage"):
		push_error("VisualGasicLanguage class not registered")
		quit(1)
		return

	# 2. Static profiler methods must be bound.
	var required := ["vg_profiler_enable", "vg_profiler_is_enabled",
					 "vg_profiler_get_report", "vg_profiler_clear"]
	for m in required:
		if not ClassDB.class_has_method(&"VisualGasicLanguage", m, true):
			push_error("Missing static method: %s" % m)
			failures += 1
	if failures > 0:
		quit(failures)
		return

	# 3. Enable → verify enabled.
	ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_enable", true)
	var enabled: bool = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_is_enabled")
	print("[test] enabled after enable(true) = ", enabled)
	if not enabled:
		push_error("Profiler did not report enabled=true")
		failures += 1

	# 4. Get report shape.
	var report = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_get_report")
	print("[test] report type: ", typeof(report), "  keys: ", (report.keys() if report is Dictionary else []))
	if not (report is Dictionary):
		push_error("Report is not a Dictionary")
		failures += 1
	else:
		for key in ["profiles", "counters", "profiling_enabled"]:
			if not report.has(key):
				push_error("Report missing key: %s" % key)
				failures += 1
		var prof_count: int = (report.get("profiles", {}) as Dictionary).size()
		var ctr_count: int = (report.get("counters", {}) as Dictionary).size()
		print("[test] profiles=%d  counters=%d  enabled_field=%s" %
			[prof_count, ctr_count, str(report.get("profiling_enabled"))])
		# Counters are pre-registered (parser.*, jit.*, etc.), so must be > 0
		if ctr_count == 0:
			push_error("No counters registered — profiler singleton may not be initialized")
			failures += 1

	# 5. Clear → counters should reset to zero but stay registered.
	ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_clear")
	var after = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_get_report")
	var after_ctr: int = (after.get("counters", {}) as Dictionary).size()
	print("[test] counters after clear = ", after_ctr)
	if after_ctr == 0:
		push_error("Clear wiped registered counters (should keep names, zero values)")
		failures += 1

	# 6. Disable → verify.
	ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_enable", false)
	var dis: bool = ClassDB.class_call_static(&"VisualGasicLanguage", &"vg_profiler_is_enabled")
	print("[test] enabled after enable(false) = ", dis)
	if dis:
		push_error("Profiler still reports enabled=true after disable")
		failures += 1

	if failures == 0:
		print("[test] ALL PROFILER BRIDGE CHECKS PASSED")
	else:
		push_error("[test] %d profiler bridge checks FAILED" % failures)
	quit(failures)
