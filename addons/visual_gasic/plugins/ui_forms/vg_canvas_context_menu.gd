@tool
extends EditorContextMenuPlugin

var host_plugin: EditorPlugin

func _popup_menu(_paths: PackedStringArray) -> void:
	add_context_menu_item("🧩 Add VG Control…", Callable(self, "_on_add_control"))
	add_context_menu_item("🔧 VG Properties", Callable(self, "_on_props"))
	add_context_menu_item("⚡ Wire Event…", Callable(self, "_on_wire_event"))

func _on_add_control(_paths = null) -> void:
	if not is_instance_valid(host_plugin):
		push_warning("[VG Context Menu] host_plugin invalid")
		return
	host_plugin._ui_forms_show_toolbox_window()

func _on_props(_paths = null) -> void:
	if not is_instance_valid(host_plugin):
		push_warning("[VG Context Menu] host_plugin invalid")
		return
	host_plugin._ui_forms_show_props_window()

func _on_wire_event(_paths = null) -> void:
	if not is_instance_valid(host_plugin):
		push_warning("[VG Context Menu] host_plugin invalid")
		return
	var sel = host_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() == 1:
		host_plugin._generate_event_handler(sel[0])
