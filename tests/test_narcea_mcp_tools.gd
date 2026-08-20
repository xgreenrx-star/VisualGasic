extends SceneTree
## MCP server tool smoke — read/write/list without full editor UI.
##
## Run:
##   Godot --headless --path projects/vg_narcea_test -s tests/test_narcea_mcp_tools.gd

const VGMcpServer := preload("res://addons/visual_gasic/vg_mcp_server.gd")

var _failed := 0
var _passed := 0
var _server: VGMcpServer
var _test_root := "res://ai_projects/_mcp_smoke/"


func _initialize() -> void:
	print("=== Narcea MCP Tools Smoke ===")
	_server = VGMcpServer.new()
	root.add_child(_server)
	_test_tools_list()
	_test_read_write_roundtrip()
	_test_list_dir()
	_cleanup()
	_finish()


func _test_tools_list() -> void:
	print("")
	print("--- tools/list ---")
	var tools: Array = _server._tool_definitions()
	_expect("tool definitions non-empty", not tools.is_empty())
	var names: Array = []
	for t in tools:
		if typeof(t) == TYPE_DICTIONARY:
			names.append(str(t.get("name", "")))
	for want in ["read_file", "write_file", "list_dir"]:
		_expect("has tool %s" % want, want in names)


func _test_read_write_roundtrip() -> void:
	print("")
	print("--- write_file + read_file ---")
	_ensure_test_dir()
	var path := _test_root + "hello.txt"
	var write_res: Dictionary = _server._invoke_tool("write_file", {
		"path": path,
		"contents": "mcp smoke ok\nline2",
	})
	_expect("write_file ok", not write_res.has("error"), str(write_res.get("error", "")))
	var read_res: Dictionary = _server._invoke_tool("read_file", {"path": path, "max_lines": 10})
	_expect("read_file ok", not read_res.has("error"), str(read_res.get("error", "")))
	var out := str(read_res.get("output", ""))
	_expect("read content matches", out.find("mcp smoke ok") >= 0)


func _test_list_dir() -> void:
	print("")
	print("--- list_dir ---")
	_ensure_test_dir()
	var res: Dictionary = _server._invoke_tool("list_dir", {"path": _test_root})
	_expect("list_dir ok", not res.has("error"), str(res.get("error", "")))
	_expect("lists hello.txt", str(res.get("output", "")).find("hello.txt") >= 0)
	_cleanup()


func _ensure_test_dir() -> void:
	var abs := ProjectSettings.globalize_path(_test_root)
	DirAccess.make_dir_recursive_absolute(abs)


func _cleanup() -> void:
	_ensure_test_dir()
	var abs := ProjectSettings.globalize_path(_test_root)
	if DirAccess.dir_exists_absolute(abs):
		var da := DirAccess.open(abs)
		if da:
			for f in ["hello.txt"]:
				if FileAccess.file_exists(_test_root + f):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_root + f))
			DirAccess.remove_absolute(abs)


func _ok(label: String) -> void:
	_passed += 1
	print("  [PASS] %s" % label)


func _fail(label: String, reason: String) -> void:
	_failed += 1
	print("  [FAIL] %s: %s" % [label, reason])


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, reason if not reason.is_empty() else "assertion failed")


func _finish() -> void:
	if is_instance_valid(_server):
		_server.free()
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
