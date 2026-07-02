@tool
extends EditorContextMenuPlugin

var host_plugin: EditorPlugin

func _popup_menu(_paths: PackedStringArray) -> void:
	add_context_menu_item("🧩 Add VG Control…", Callable(self, "_on_add_control"))
	add_context_menu_item("🔧 VG Properties", Callable(self, "_on_props"))
	add_context_menu_item("⚡ Wire Event…", Callable(self, "_on_wire_event"))
	add_context_menu_item("📂 Open Prototype Scene", Callable(self, "_on_open_prototype"))

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

func _on_open_prototype(_paths = null) -> void:
	if not is_instance_valid(host_plugin):
		push_warning("[VG Context Menu] host_plugin invalid")
		return
	var sel = host_plugin.get_editor_interface().get_selection().get_selected_nodes()
	if sel.size() != 1:
		return
	var node = sel[0]
	# The placed node is an instance of a prototype .tscn — get its scene file path
	var scene_path: String = node.scene_file_path if node.has_method("scene_file_path") else ""
	if scene_path.is_empty():
		# Node is not a sub-scene root — walk up to find the instance root
		var owner = node.get_scene_instance_load_placeholder() if false else null
		var inst_root = node
		while inst_root and inst_root.owner != null:
			inst_root = inst_root.owner
			if inst_root.scene_file_path != "":
				# inst_root is the sub-scene root; but that's the *parent* scene.
				# What we want is the prototype this node came from.
				break
		# Fallback: derive from the control name (e.g. "Button1" → "Button.tscn")
		var base_name = node.name.rstrip("0123456789")
		var candidate = "res://addons/visual_gasic/prototypes/" + base_name + ".tscn"
		if ResourceLoader.exists(candidate):
			scene_path = candidate
	if scene_path.is_empty():
		push_warning("[VG] Could not determine prototype scene path for: " + node.name)
		return
	host_plugin.get_editor_interface().open_scene_from_path(scene_path)
