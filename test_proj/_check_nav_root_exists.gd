@tool
extends SceneTree

## Integration test: root-EXISTS scenario (simulates main.tscn open in Scene panel
## while infoview_companion.vg is open in Script editor).
## This is the actual path used by the live Godot editor.

const PASS = "[PASS]"
const FAIL = "[FAIL]"

var _failures: int = 0
var _print_lines: PackedStringArray = []

class MockScriptEditor extends RefCounted:
	var _current_script = null
	var _current_editor = null

	func get_current_script():
		return _current_script

	func get_current_editor():
		return _current_editor

class MockCurrentEditor extends RefCounted:
	var _code_edit: CodeEdit = null

	func get_base_editor():
		return _code_edit

class MockEditorInterface extends RefCounted:
	var _scene_root: Node = null
	var _script_editor: MockScriptEditor = null

	func _init():
		_script_editor = MockScriptEditor.new()

	func get_edited_scene_root():
		return _scene_root

	func get_script_editor():
		return _script_editor

	func get_open_scenes() -> Array:
		return []

	func set_main_screen_editor(_s: String) -> void:
		pass

class MockPlugin extends RefCounted:
	var _editor_interface: MockEditorInterface

	func _init():
		_editor_interface = MockEditorInterface.new()

	func get_editor_interface() -> MockEditorInterface:
		return _editor_interface


func _init():
	print("=== Code Navigator root-exists integration test ===")

	var nav_script = load("res://addons/visual_gasic/code_navigator.gd")
	_assert("code_navigator.gd loads", nav_script != null)
	if nav_script == null:
		quit(1); return

	var root_ctrl = Control.new()
	get_root().add_child(root_ctrl)
	var nav = nav_script.new()
	root_ctrl.add_child(nav)

	var mock_plugin = MockPlugin.new()
	nav.editor_plugin = mock_plugin

	# -------------------------------------------------------------------
	# Build a minimal mock scene root (like main.tscn)
	# -------------------------------------------------------------------
	var scene_root = Node.new()
	scene_root.name = "InfoViewCompanion"
	scene_root.set_meta("scene_file_path", "res://main.tscn")
	# Override scene_file_path property (GDScript Node.scene_file_path is read-only in-engine
	# but we can test via the VGIntelliSense path. We'll use a custom workaround:
	# create a real temp tscn so _get_current_vg_path() scene fallback returns main.vg)
	var btn = Button.new()
	btn.name = "cmdBack"
	scene_root.add_child(btn)

	mock_plugin._editor_interface._scene_root = scene_root

	# -------------------------------------------------------------------
	# Scenario A: script editor has current_script pointing to the .vg file
	# (the normal case: infoview_companion.vg is open)
	# -------------------------------------------------------------------
	print("\n--- Test A: root exists + current_script = infoview_companion.vg ---")

	var vg_path := "/home/Commodore/Documents/VisualGasic/local_projects/infoview_companion/infoview_companion.vg"
	_assert("vg file exists", FileAccess.file_exists(vg_path))

	# Create a mock Script resource for get_current_script()
	var mock_script = GDScript.new()  # just needs .resource_path
	mock_script.resource_path = vg_path

	mock_plugin._editor_interface._script_editor._current_script = mock_script
	mock_plugin._editor_interface._script_editor._current_editor = null  # no code edit yet (timing)

	nav.refresh_objects()

	print("  object_list.item_count = ", nav.object_list.item_count)
	print("  event_list.item_count  = ", nav.event_list.item_count)

	_assert("Test A: object_list has items", nav.object_list.item_count > 0)
	_assert("Test A: event_list has items (procedures populated)", nav.event_list.item_count > 2)
	_assert("Test A: (General) in object_list", nav.object_list.get_item_text(0) == "(General)")

	# -------------------------------------------------------------------
	# Scenario B: script editor has current_editor with loaded CodeEdit text
	# -------------------------------------------------------------------
	print("\n--- Test B: root exists + code_edit.text populated ---")

	var code_edit = CodeEdit.new()
	root_ctrl.add_child(code_edit)
	code_edit.text = FileAccess.get_file_as_string(vg_path)
	_assert("code_edit.text non-empty", not code_edit.text.is_empty())

	var mock_editor = MockCurrentEditor.new()
	mock_editor._code_edit = code_edit
	mock_plugin._editor_interface._script_editor._current_editor = mock_editor
	mock_plugin._editor_interface._script_editor._current_script = mock_script

	nav.refresh_objects()

	print("  event_list.item_count  = ", nav.event_list.item_count)
	_assert("Test B: event_list has 24 items", nav.event_list.item_count == 24)  # (Declarations) + 23 procs

	# -------------------------------------------------------------------
	# Scenario C: current_script null but code_edit.text populated (transient)
	# -------------------------------------------------------------------
	print("\n--- Test C: current_script = null but code_edit.text populated ---")

	mock_plugin._editor_interface._script_editor._current_script = null
	# current_editor still has code_edit with text

	nav.refresh_objects()

	print("  event_list.item_count  = ", nav.event_list.item_count)
	_assert("Test C: event_list still populated via code_edit.text", nav.event_list.item_count == 24)

	# -------------------------------------------------------------------
	# Scenario D: both null (worst case: mid scene-reload / screen transition)
	# _last_known_vg_path cache should kick in and still serve correct content
	# -------------------------------------------------------------------
	print("\n--- Test D: both null — cache should keep 23 procs ---")

	mock_plugin._editor_interface._script_editor._current_script = null
	mock_plugin._editor_interface._script_editor._current_editor = null

	nav.refresh_objects()
	print("  event_list.item_count  = ", nav.event_list.item_count)
	_assert("Test D: cache preserves 24 items when both null", nav.event_list.item_count == 24)

	# -------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------
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
