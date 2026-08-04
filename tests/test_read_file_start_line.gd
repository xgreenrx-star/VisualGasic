@tool
extends SceneTree
## Regression test for read_file's start_line support (vg_ai_tools.gd).
##
## Real incident (Aug 2026, live in the C64 Emulator project): Narcea tried
## calling read_file with a "start_line" argument to page through a large
## already-open file looking for specific handler functions. The tool
## silently ignored "start_line" (it wasn't a recognized key at all) and
## always returned the file from line 1, wasting several agent-loop hops
## before Narcea gave up and fell back to find_in_files (which also failed,
## separately, because it forgot to set "regex":true for a "|" pattern).
##
## Fix: _do_read_file() now honors a 1-based "start_line" (default 1) and
## returns a windowed slice, same convention as goto_line/replace_range/etc.
##
## Run: godot --headless --script tests/test_read_file_start_line.gd
## (stage via test_proj -- see build_and_test.md for the current workaround,
## since game_projects/AGCK_Tests no longer exists.)

var _failed := 0
var _passed := 0
var _tools = null
var _tmp_path := "res://_read_file_start_line_fixture.vg"


func _init() -> void:
	print("=== read_file start_line Regression Test ===")
	print("")

	var script = load("res://addons/visual_gasic/vg_ai_tools.gd")
	if script == null:
		print("FATAL: could not load vg_ai_tools.gd")
		quit(1)
		return
	_tools = script.new()

	_write_fixture()

	_test_default_reads_from_top()
	_test_start_line_pages_forward()
	_test_start_line_plus_max_lines_windows()
	_test_start_line_past_eof_returns_empty_gracefully()
	_test_start_line_one_is_same_as_default()

	_cleanup_fixture()

	print("")
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	print("RESULTS: %d/%d passed, %d failed" % [_passed, _passed + _failed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s  %s" % [label, detail])


func _write_fixture() -> void:
	var lines: Array = []
	for i in range(1, 51):
		lines.append("Line%03d" % i)
	var f := FileAccess.open(_tmp_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()


func _cleanup_fixture() -> void:
	if FileAccess.file_exists(_tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp_path))


func _test_default_reads_from_top() -> void:
	print("-- No start_line: reads from line 1 (back-compat) --")
	var out: String = _tools._do_read_file({"path": _tmp_path, "max_lines": 5})
	_check("contains Line001", out.find("Line001") != -1, out)
	_check("does not contain Line006", out.find("Line006") == -1, out)


func _test_start_line_pages_forward() -> void:
	print("-- start_line pages past the top instead of re-reading it --")
	var out: String = _tools._do_read_file({"path": _tmp_path, "start_line": 10, "max_lines": 5})
	_check("does not contain Line001 (skipped)", out.find("Line001") == -1, out)
	_check("contains Line010 (first requested line)", out.find("Line010") != -1, out)
	_check("contains Line014 (5th line of window)", out.find("Line014") != -1, out)
	_check("does not contain Line015 (past window)", out.find("Line015") == -1, out)


func _test_start_line_plus_max_lines_windows() -> void:
	print("-- start_line + max_lines together define an exact window --")
	var out: String = _tools._do_read_file({"path": _tmp_path, "start_line": 45, "max_lines": 3})
	_check("contains Line045", out.find("Line045") != -1, out)
	_check("contains Line047", out.find("Line047") != -1, out)
	_check("does not contain Line048", out.find("Line048") == -1, out)


func _test_start_line_past_eof_returns_empty_gracefully() -> void:
	print("-- start_line past EOF degrades gracefully (no error/crash) --")
	var out: String = _tools._do_read_file({"path": _tmp_path, "start_line": 9000, "max_lines": 5})
	_check("no Line0 content leaks through", out.find("Line0") == -1, out)
	_check("still reports the real total line count (50)", out.find(" 50 lines") != -1, out)


func _test_start_line_one_is_same_as_default() -> void:
	print("-- start_line:1 is equivalent to omitting it --")
	var a: String = _tools._do_read_file({"path": _tmp_path, "start_line": 1, "max_lines": 5})
	var b: String = _tools._do_read_file({"path": _tmp_path, "max_lines": 5})
	_check("start_line:1 output matches no-start_line output", a == b, "a=%s b=%s" % [a, b])
