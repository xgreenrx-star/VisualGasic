@tool
extends EditorContextMenuPlugin

var host_plugin: EditorPlugin

func _popup_menu(_paths: PackedStringArray) -> void:
	add_context_menu_item("🧩 Add VG Control…", _on_add_control)
	add_context_menu_item("🔧 VG Properties", _on_props)
	add_context_menu_item("⚡ Wire Event…", _on_wire_event)

func _on_add_control() -> void:
	if host_plugin and host_plugin.has_method("_ui_forms_show_toolbox_window"):
		host_plugin._ui_forms_show_toolbox_window()

func _on_props() -> void:
	if host_plugin and host_plugin.has_method("_ui_forms_show_props_window"):
		host_plugin._ui_forms_show_props_window()

func _on_wire_event() -> void:
	if not host_plugin:
		return
	var sel = host_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1 and host_plugin.has_method("_generate_event_handler"):
		host_plugin._generate_event_handler(sel[0])
