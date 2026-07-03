@tool
extends SceneTree

## Test: stale _override_vg_path (from VG IDE session) does not corrupt
## the native script editor's Code Navigator when plugin clears it.

const PASS = "[PASS]"
const FAIL = "[FAIL]"

var _failures: int = 0

class MockScriptEditor extends RefCounted:
	var _current_script = null
	var _current_editor = null
	func get_current_script(): return _current_script
	func get_current_editor(): return _current_editor

class MockEditorInterface extends RefCounted:
	var _scene_root: Node = null
	var _script_editor: MockScriptEditor = null
	func _init(): _script_editor = MockScriptEditor.new()
	func get_edited_scene_root(): return _scene_root
	func get_script_editor(): return _script_editor
	func get_open_scenes() -> Array: return []
	func set_main_screen_editor(_s: String) -> void: pass

class MockPlugin extends RefCounted:
	var _editor_interface: MockEditorInterface
	func _init(): _editor_interface = MockEditorInterface.new()
	func get_editor_interface() -> MockEditorInterface: return _editor_interface

func _init():
	print("=== Code Navigator stale-override test ===")

	var nav_script = load("res://addons/visual_gasic/code_navigator.gd")
	_assert("nav_script loads", nav_script != null)
	if nav_script == null:
		quit(1); return

	var root_ctrl = Control.new()
	get_root().add_child(root_ctrl)
	var nav = nav_script.new()
	root_ctrl.add_child(nav)

	var mock_plugin = MockPlugin.new()
	nav.editor_plugin = mock_plugin

	var main_vg := "/home/Commodore/Documents/VisualGasic/local_projects/infoview_companion/main.vg"
	var ic_vg   := "/home/Commodore/Documents/VisualGasic/local_projects/infoview_companion/infoview_companion.vg"

	_assert("main.vg exists",  FileAccess.file_exists(main_vg))
	_assert("ic.vg exists",    FileAccess.file_exists(ic_vg))

	# ---- Simulate: VG IDE had main.vg open → override is set ----
	print("\n--- Step 1: VG IDE sets override to main.vg ---")
	nav.set_override_vg_path(main_vg)
	_assert("override is main.vg", nav._override_vg_path == main_vg)

	# ---- Simulate: user switches to native Script editor with ic.vg open ----
	# In the real plugin, _check_script_editor_for_vg does:
	#   _code_navigator.set_override_vg_path("")   ← the new fix
	#   _code_navigator.refresh_objects()
	print("\n--- Step 2: native editor opens infoview_companion.vg, plugin clears override ---")
	nav.set_override_vg_path("")  # this is what _check_script_editor_for_vg now does

	var ic_script = GDScript.new()
	ic_script.resource_path = ic_vg
	mock_plugin._editor_interface._script_editor._current_script = ic_script
	mock_plugin._editor_interface._scene_root = null

	nav.refresh_objects()

	print("  override=", nav._override_vg_path)
	print("  cached=",   nav._last_known_vg_path)
	print("  event_list.item_count=", nav.event_list.item_count)

	_assert("override cleared",          nav._override_vg_path == "")
	_assert("cached = ic.vg",            nav._last_known_vg_path == ic_vg)
	_assert("event_list has 24 items",   nav.event_list.item_count == 24)
	_assert("(General) selected",        nav.object_list.get_item_text(0) == "(General)")

	# ---- Confirm main.vg would have been 0 procs (shows why fix matters) ----
	print("\n--- Step 3: show main.vg has 0 procedures (why stale override was a bug) ---")
	var main_text := FileAccess.get_file_as_string(main_vg)
	var procs: Array = nav._parse_procedures(main_text)
	print("  main.vg proc count = ", procs.size())
	_assert("main.vg has far fewer procs than ic.vg (skeleton)",  procs.size() < 3)

	print("")
	if _failures == 0:
		print(PASS + " All tests passed.")
		quit(0)
	else:
		print(FAIL + " " + str(_failures) + " test(s) failed.")
		quit(1)

func _assert(label: String, condition: bool) -> void:
	if condition:
		print(PASS + " " + label)
	else:
		printerr(FAIL + " " + label)
		_failures += 1
