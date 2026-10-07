@tool
extends EditorPlugin

var _passed := 0
var _failed := 0

func _enter_tree() -> void:
	call_deferred("_run_checks")

func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FULL-EDITOR-LIFECYCLE FAIL: " + description)

func _wait_for_editor() -> void:
	for frame in range(10):
		await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame

func _run_checks() -> void:
	await _wait_for_editor()
	var combo_script = load("res://addons/visual_gasic/vg_combo_box.gd")
	for style in range(3):
		var combo = combo_script.new()
		combo.Style = style
		add_child(combo)
		var inline_ref := weakref(combo._inline_list)
		_check(combo._inline_list.get_parent() == combo, "ComboBox owns hidden inline list")
		combo.AddItem("Alpha")
		combo.AddItem("Beta")
		combo.select(1)
		var preserves_items: bool = combo.ListCount == 2 and combo.Text == "Beta"
		for next_style in range(3):
			combo.Style = next_style
			preserves_items = preserves_items and combo._item_list.item_count == 2 and combo.Text == "Beta"
		_check(preserves_items, "ComboBox style changes preserve items and selected text")
		combo.queue_free()
		combo = null
		await get_tree().process_frame
		_check(inline_ref.get_ref() == null, "ComboBox releases inline list in every style")
	var baseline := Node.get_orphan_node_ids()
	for cycle in range(2):
		EditorInterface.set_plugin_enabled("visual_gasic", true)
		await _wait_for_editor()
		var plugin = EditorInterface.get_base_control().get_meta("visual_gasic_plugin_instance", null)
		_check(is_instance_valid(plugin), "VG plugin enabled")
		if not is_instance_valid(plugin):
			break
		var menu: PopupMenu = plugin._vgasic_tools_menu
		var menu_ref := weakref(menu)
		_check(is_instance_valid(menu) and menu.get_parent() != null, "VG Tools menu attached")
		if cycle == 1:
			plugin._remove_vgasic_from_project_menu()
			await get_tree().process_frame
			_check(menu_ref.get_ref() == null, "direct Project submenu freed")
			plugin._setup_vgasic_tools_menu()
			plugin._godot_project_hook_retries = 11
			plugin._inject_vgasic_into_project_menu()
			await _wait_for_editor()
			_check(plugin._vgasic_tools_menu_in_tools, "Tools fallback exercised")
			menu_ref = weakref(plugin._vgasic_tools_menu)
		var editor_ref := weakref(plugin._embedded_code_editor)
		var narcea_ref := weakref(plugin._ai_help_panel)
		var debugger_ref := weakref(plugin.debugger_plugin)
		var plugin_ref := weakref(plugin)
		EditorInterface.set_plugin_enabled("visual_gasic", false)
		plugin = null
		menu = null
		await _wait_for_editor()
		_check(menu_ref.get_ref() == null, "VG Tools popup and internal resources released")
		_check(editor_ref.get_ref() == null and narcea_ref.get_ref() == null,
			"embedded editor and Narcea panel released")
		_check(debugger_ref.get_ref() == null and plugin_ref.get_ref() == null,
			"debugger and main plugin released")
		var unexpected: PackedStringArray = []
		for id in Node.get_orphan_node_ids():
			if baseline.has(id):
				continue
			var node = instance_from_id(id)
			if node is Node and node.get_parent() == null:
				unexpected.append("%s:%s" % [node.get_class(), node.name])
		_check(unexpected.is_empty(), "no new orphan roots: %s" % unexpected)
	if ProjectSettings.get_setting("vg/tests/exit_enabled", false):
		EditorInterface.set_plugin_enabled("visual_gasic", true)
		await _wait_for_editor()
		_check(EditorInterface.is_plugin_enabled("visual_gasic"), "quit with full VG plugin enabled")
	print("FULL-EDITOR-LIFECYCLE RESULTS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
