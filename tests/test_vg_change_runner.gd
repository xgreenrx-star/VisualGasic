extends SceneTree

## Phase 5: protected scenarios run one at a time. A hang is killed.
var failures := 0
var checks := 0
var _root := ""


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("FAIL: " + what)


func _run() -> void:
	var Runner = load("res://addons/visual_gasic/vg_change_runner.gd")
	if Runner == null:
		push_error("FAIL: vg_change_runner.gd is not loaded")
		quit(1)
		return
	_root = ProjectSettings.globalize_path("user://vg_change_runner_proj")
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root)
	_put("project.godot", "config_version=5\n\n[application]\n\nconfig/name=\"VGChangeRunner\"\n")
	_put("pass_scenario.gd", "extends SceneTree\nfunc _initialize() -> void:\n\tprint(\"[PASS] pass_scenario.gd\")\n\tquit(0)\n")
	_put("fail_scenario.gd", "extends SceneTree\nfunc _initialize() -> void:\n\tprint(\"[FAIL] fail_scenario.gd\")\n\tquit(1)\n")
	_put("silent_scenario.gd", "extends SceneTree\nfunc _initialize() -> void:\n\tprint(\"hello\")\n\tquit(0)\n")
	_put("hang_scenario.gd", "extends SceneTree\nfunc _initialize() -> void:\n\twhile true:\n\t\tOS.delay_msec(50)\n")
	Runner.timeout_sec = 120.0
	var passed: Dictionary = await _finish(Runner, "pass_scenario.gd")
	check(str(passed.get("status", "")) == "pass", "passing scenario, got %s" % str(passed))
	var failed: Dictionary = await _finish(Runner, "fail_scenario.gd")
	check(str(failed.get("status", "")) == "fail", "failing scenario, got %s" % str(failed))
	var silent: Dictionary = await _finish(Runner, "silent_scenario.gd")
	check(str(silent.get("status", "")) == "incomplete", "missing result line is incomplete, got %s" % str(silent))
	Runner.timeout_sec = 0.4
	var hang_pid := 0
	check(Runner.start(_root, _root.path_join("hang_scenario.gd"), "do-not-pass-this-to-the-process"), "hang scenario starts")
	var hung := {}
	while true:
		hung = Runner.poll()
		if bool(hung.get("done", false)):
			hang_pid = int(hung.get("pid", 0))
			break
		await process_frame
	check(str(hung.get("status", "")) == "incomplete", "timeout is incomplete, got %s" % str(hung))
	for _i in 10:
		if hang_pid == 0 or not OS.is_process_running(hang_pid):
			break
		await process_frame
	check(hang_pid == 0 or not OS.is_process_running(hang_pid), "timed-out process is gone")
	var args: Array = Runner.last_arguments()
	var joined := " ".join(args)
	check(joined.find("do-not-pass-this-to-the-process") < 0, "model text is not a process argument")
	Runner.timeout_sec = 120.0
	if failures == 0:
		print("[PASS] test_vg_change_runner.gd (%d/%d)" % [checks, checks])
		quit(0)
	else:
		print("[FAIL] test_vg_change_runner.gd (%d failures / %d checks)" % [failures, checks])
		quit(1)


func _finish(Runner, file_name: String) -> Dictionary:
	check(Runner.start(_root, _root.path_join(file_name), ""), "start " + file_name)
	while true:
		var result: Dictionary = Runner.poll()
		if bool(result.get("done", false)):
			return result
		await process_frame
	return {}


func _put(rel: String, text: String) -> void:
	var path := _root.path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	for file_name in da.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in da.get_directories():
		_wipe(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
