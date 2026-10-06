extends SceneTree

## Regression: clearing breakpoints must not re-read a stale JSON file.

const SCRIPT_PATH := "res://scripts/Play.vg"
const LINE := 252
const JSON_PATH := "res://.vg_breakpoints.json"

func _init() -> void:
	var ok := true
	if not ClassDB.class_exists("VisualGasicLanguage"):
		print("FAIL: VisualGasicLanguage not registered")
		print("RESULTS: 0/1 passed, 1 failed")
		quit(1)
		return

	var previous := ""
	if FileAccess.file_exists(JSON_PATH):
		var rf := FileAccess.open(JSON_PATH, FileAccess.READ)
		if rf:
			previous = rf.get_as_text()
			rf.close()

	var wf := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if wf == null:
		print("FAIL: cannot write %s" % JSON_PATH)
		print("RESULTS: 0/1 passed, 1 failed")
		quit(1)
		return
	wf.store_string(JSON.stringify({SCRIPT_PATH: [LINE]}, "\t"))
	wf.close()

	ClassDB.class_call_static("VisualGasicLanguage", "vg_clear_breakpoints")
	var still_hit: bool = ClassDB.class_call_static("VisualGasicLanguage", "vg_has_breakpoint", SCRIPT_PATH, LINE)
	if still_hit:
		print("FAIL: vg_clear_breakpoints reloaded stale JSON for %s:%d" % [SCRIPT_PATH, LINE])
		ok = false
	else:
		print("PASS: vg_clear_breakpoints does not reload stale JSON")

	var armed := {SCRIPT_PATH: [LINE]}
	ClassDB.class_call_static("VisualGasicLanguage", "vg_apply_breakpoints", armed)
	if not ClassDB.class_call_static("VisualGasicLanguage", "vg_has_breakpoint", SCRIPT_PATH, LINE):
		print("FAIL: vg_apply_breakpoints did not arm %s:%d" % [SCRIPT_PATH, LINE])
		ok = false
	else:
		print("PASS: vg_apply_breakpoints arms the requested line")

	ClassDB.class_call_static("VisualGasicLanguage", "vg_apply_breakpoints", {})
	if ClassDB.class_call_static("VisualGasicLanguage", "vg_has_breakpoint", SCRIPT_PATH, LINE):
		print("FAIL: empty vg_apply_breakpoints left %s:%d armed" % [SCRIPT_PATH, LINE])
		ok = false
	else:
		print("PASS: empty vg_apply_breakpoints clears the breakpoint map")

	if previous.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JSON_PATH))
	else:
		var restore := FileAccess.open(JSON_PATH, FileAccess.WRITE)
		if restore:
			restore.store_string(previous)
			restore.close()

	if ok:
		print("RESULTS: 3/3 passed, 0 failed")
		quit(0)
	else:
		print("RESULTS: 0/3 passed, 3 failed")
		quit(1)
