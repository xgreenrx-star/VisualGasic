@tool
extends SceneTree

## Integration test: exercise refresh_objects() with a mock plugin.
## Tests both the no-root (Script view) path and the disk fallback for text.

const PASS = "[PASS]"
const FAIL = "[FAIL]"

var _failures: int = 0

# ---------------------------------------------------------------------------
# Mock infrastructure
# ---------------------------------------------------------------------------

class MockCodeEdit extends CodeEdit:
	var _mock_text: String = ""
	func get_mock_text() -> String:
		return _mock_text
	func set_mock_text(t: String) -> void:
		_mock_text = t

# Cannot subclass CodeEdit and override text property directly in GDScript
# (it's a native property). Instead we test the fallback path by returning
# null from get_current_editor, forcing disk read.

class MockEditorInterface extends RefCounted:
	var _scene_root = null          # null = Script view
	var _script_editor = null

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

# ---------------------------------------------------------------------------

func _init():
	print("=== Code Navigator integration test ===")

	var nav_script = load("res://addons/visual_gasic/code_navigator.gd")
	if nav_script == null:
		printerr(FAIL + " Could not load code_navigator.gd")
		quit(1)
		return

	# ---- Add navigator to a real Control so _ready() fires ----
	var root_ctrl = Control.new()
	get_root().add_child(root_ctrl)

	var nav = nav_script.new()
	root_ctrl.add_child(nav)  # triggers _ready(), builds LineEdit/_item_list

	var mock_plugin = MockPlugin.new()
	nav.editor_plugin = mock_plugin

	# ---- Set override path directly (simulates VG IDE / Godot Script path) ----
	var vg_path := "/home/Commodore/Documents/VisualGasic/local_projects/infoview_companion/infoview_companion.vg"
	_assert("vg file exists on disk", FileAccess.file_exists(vg_path))
	nav.set_override_vg_path(vg_path)

	# ---- 1. No-root path with disk fallback ----
	print("\n--- Test 1: no-root (Script view) + disk read ---")
	mock_plugin._editor_interface._scene_root = null
	mock_plugin._editor_interface._script_editor = null

	nav.refresh_objects()

	print("  object_list.item_count = ", nav.object_list.item_count)
	print("  event_list.item_count  = ", nav.event_list.item_count)
	print("  object_list.selected   = ", nav.object_list.selected)
	print("  event_list.selected    = ", nav.event_list.selected)

	# Check object_list text via _data (selected should show "(General)")
	_assert("object_list has items",   nav.object_list.item_count > 0)
	_assert("event_list has items",    nav.event_list.item_count > 1)   # at least (Declarations) + subs
	_assert("object_list[0] is (General)",
		nav.object_list.get_item_text(0) == "(General)")
	_assert("event_list[0] is (Declarations)",
		nav.event_list.get_item_text(0) == "(Declarations)")
	_assert("event_list has at least 5 entries (procedures)",
		nav.event_list.item_count >= 6)  # (Declarations) + 5+ procedures
	_assert("event_list.selected == 0", nav.event_list.selected == 0)
	_assert("object_list.selected == 0", nav.object_list.selected == 0)

	# VGComboBox LineEdit text should reflect selected item
	# access via .Text property (VB6 alias) - test indirectly via selected and get_item_text
	var sel_obj_text = nav.object_list.get_item_text(nav.object_list.selected)
	var sel_evt_text = nav.event_list.get_item_text(nav.event_list.selected)
	print("  object_list selected text: '", sel_obj_text, "'")
	print("  event_list  selected text: '", sel_evt_text, "'")
	_assert("object_list selected text is (General)", sel_obj_text == "(General)")
	_assert("event_list selected text is (Declarations)", sel_evt_text == "(Declarations)")

	# ---- 2. Verify specific procedures appear ----
	print("\n--- Test 2: known procedures present ---")
	var found_procs := PackedStringArray()
	for i in nav.event_list.item_count:
		var meta = nav.event_list.get_item_metadata(i)
		if meta is Dictionary and meta.get("type", "") == "procedure":
			found_procs.append(meta.get("name", "").to_lower())

	print("  procedures in event_list: ", found_procs)
	_assert("_ready in event list",         "_ready" in found_procs)
	_assert("cmdback_click in event list",  "cmdback_click" in found_procs)
	_assert("setrecordbutton in event list", "setrecordbutton" in found_procs)

	# ---- 3. Second refresh_objects() call is stable (no duplicates) ----
	print("\n--- Test 3: re-refresh is idempotent ---")
	nav.refresh_objects()
	_assert("object_list still 1 item after re-refresh", nav.object_list.item_count == 1)
	var proc_count_before: int = nav.event_list.item_count
	nav.refresh_objects()
	_assert("event_list same count after second re-refresh",
		nav.event_list.item_count == proc_count_before)

	# ---- Summary ----
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
