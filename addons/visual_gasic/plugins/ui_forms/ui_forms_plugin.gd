@tool
## UI Forms plugin (experimental) — controller.
##
## A self-contained VB6-style visual form designer implemented purely in
## GDScript.  It ties together:
##   * ui_forms_control_picker    — pick a control type to place
##   * ui_forms_viewport_adapter  — the design canvas (ghost placement, select,
##                                  move, resize, double-click-to-wire)
##   * ui_forms_selection_overlay — selection rect + resize handles
##   * ui_forms_scene_bridge      — .tscn / .vg serialization + event stubs
##
## Interaction model (acceptance):
##   Add Control → picker popup → ghost follows mouse → single click places →
##   double-click wires "Sub <Name>_<Event>()" into <Form>.vg and jumps to code.
##   Save writes <Form>.tscn + <Form>.vg; Open restores everything.
##
## Gated behind the project setting vg/enable_experimental_plugins (enforced by
## the plugin manager), so it never loads unless the user opts in.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const ControlPicker = preload("res://addons/visual_gasic/plugins/ui_forms/ui_forms_control_picker.gd")
const ViewportAdapter = preload("res://addons/visual_gasic/plugins/ui_forms/ui_forms_viewport_adapter.gd")
const SelectionOverlay = preload("res://addons/visual_gasic/plugins/ui_forms/ui_forms_selection_overlay.gd")
const SceneBridge = preload("res://addons/visual_gasic/plugins/ui_forms/ui_forms_scene_bridge.gd")

var _bridge = null
var _picker: Window = null
var _adapter: Control = null
var _overlay: Control = null

var _form_name_field: LineEdit = null
var _status: Label = null

## Control model: Array of { name, type, node, rect, text }.
var _controls: Array = []

var _form_name: String = "Form1"
var _form_size: Vector2 = Vector2(480, 360)
var _tscn_path: String = ""
var _vg_path: String = ""


# ─── Plugin identity ────────────────────────────────────────

func get_plugin_name() -> String:
	return "UI Forms"

func get_toolbar_icon() -> String:
	return "🧩"

func get_toolbar_color() -> Color:
	return Color(0.22, 0.42, 0.40)

func get_toolbar_tooltip() -> String:
	return "UI Forms (experimental) — visual VB6-style form designer"


# ─── UI construction ────────────────────────────────────────

func _build_ui() -> void:
	_bridge = SceneBridge.new()

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.add_child(root)

	# Toolbar.
	var bar := HBoxContainer.new()
	root.add_child(bar)

	var name_lbl := Label.new()
	name_lbl.text = "Form:"
	bar.add_child(name_lbl)

	_form_name_field = LineEdit.new()
	_form_name_field.text = _form_name
	_form_name_field.custom_minimum_size = Vector2(120, 0)
	_form_name_field.text_changed.connect(_on_form_name_changed)
	bar.add_child(_form_name_field)

	var add_btn := Button.new()
	add_btn.text = "➕ Add Control"
	add_btn.tooltip_text = "Pick a control and place it on the form"
	add_btn.pressed.connect(_on_add_control_pressed)
	bar.add_child(add_btn)

	var open_btn := Button.new()
	open_btn.text = "📂 Open"
	open_btn.tooltip_text = "Load <Form>.tscn from the project root"
	open_btn.pressed.connect(_on_open_pressed)
	bar.add_child(open_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Write <Form>.tscn and <Form>.vg"
	save_btn.pressed.connect(_on_save_pressed)
	bar.add_child(save_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_status = Label.new()
	_status.text = "Ready — experimental"
	bar.add_child(_status)

	# Design surface (scrollable, fixed-size form canvas).
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var canvas_wrap := Control.new()
	canvas_wrap.custom_minimum_size = _form_size
	scroll.add_child(canvas_wrap)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_wrap.add_child(bg)

	_adapter = ViewportAdapter.new()
	_adapter.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_wrap.add_child(_adapter)

	_overlay = SelectionOverlay.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_wrap.add_child(_overlay)

	_adapter.set_overlay(_overlay)
	_adapter.place_requested.connect(_on_place_requested)
	_adapter.control_selected.connect(_on_control_selected)
	_adapter.selection_cleared.connect(_on_selection_cleared)
	_adapter.control_geometry_changed.connect(_on_control_geometry_changed)
	_adapter.wire_requested.connect(_on_wire_requested)


# ─── Toolbar actions ────────────────────────────────────────

func _on_form_name_changed(new_text: String) -> void:
	_form_name = _sanitize_name(new_text)

func _on_add_control_pressed() -> void:
	if _picker == null:
		_picker = ControlPicker.new()
		_view.add_child(_picker)
		_picker.control_chosen.connect(_on_control_chosen)
	_picker.popup_picker()

func _on_control_chosen(godot_type: String) -> void:
	_adapter.arm_placement(godot_type)
	_set_status("Click on the form to place a " + SceneBridge.name_base_for(godot_type))

func _on_open_pressed() -> void:
	_ensure_paths()
	if not FileAccess.file_exists(_tscn_path):
		_set_status("No form file at " + _tscn_path)
		return
	open_form(_tscn_path)

func _on_save_pressed() -> void:
	_ensure_paths()
	var err = _bridge.write_form(_tscn_path, _vg_path, _form_name, _form_size, _serializable_controls())
	if err == OK:
		_set_status("Saved " + _tscn_path)
		_rescan_filesystem()
	else:
		_set_status("Save failed (err %d)" % err)


# ─── Canvas callbacks ───────────────────────────────────────

func _on_place_requested(godot_type: String, position: Vector2) -> void:
	var ctrl_name = _bridge.next_control_name(godot_type, _existing_names())
	var node := _make_node(godot_type, ctrl_name)
	var rect := Rect2(position, ViewportAdapter.default_size_for(godot_type))
	_adapter.add_placed_control(node, rect)
	var entry := {
		"name": ctrl_name,
		"type": godot_type,
		"node": node,
		"rect": rect,
		"text": _default_text_for(godot_type, ctrl_name),
	}
	_controls.append(entry)
	_adapter.select_node(node)
	_set_status("Placed " + ctrl_name + " — double-click it to add code")

func _on_control_selected(node: Control) -> void:
	var entry := _find_entry_by_node(node)
	if not entry.is_empty():
		_set_status("Selected " + str(entry["name"]))

func _on_selection_cleared() -> void:
	_set_status("Ready — experimental")

func _on_control_geometry_changed(node: Control, rect: Rect2) -> void:
	var entry := _find_entry_by_node(node)
	if not entry.is_empty():
		entry["rect"] = rect

func _on_wire_requested(node: Control) -> void:
	var entry := _find_entry_by_node(node)
	if entry.is_empty():
		return
	_ensure_paths()
	var suffix := SceneBridge.event_suffix_for(str(entry["type"]))
	var sub_name := str(entry["name"]) + "_" + suffix
	# Authoritative, idempotent stub insertion (creates the .vg if missing).
	_bridge.insert_event_stub(_vg_path, sub_name, "")
	_rescan_filesystem()
	# Jump to the handler in the embedded code editor (reuses host flow, which
	# also ensures/navigates to the handler and switches to code view).
	if _host_plugin and _host_plugin.has_method("_open_in_embedded_editor"):
		_host_plugin._open_in_embedded_editor(_vg_path, sub_name, "")
	elif _host_plugin and _host_plugin.has_method("open_module_in_embedded_editor"):
		_host_plugin.open_module_in_embedded_editor(_vg_path)
	_set_status("Wired " + sub_name + "()")


# ─── Form load ──────────────────────────────────────────────

## Load a form .tscn into the designer, replacing the current model.
func open_form(tscn_path: String) -> void:
	var data: Dictionary = _bridge.load_form(tscn_path)
	_form_name = str(data.get("form_name", "Form1"))
	_form_size = data.get("size", Vector2(480, 360))
	_tscn_path = tscn_path
	_vg_path = _derive_vg_path(tscn_path, _form_name)

	_adapter.clear_controls()
	_controls.clear()
	for cd in data.get("controls", []):
		var godot_type := str(cd.get("type", "Control"))
		var cname := str(cd.get("name", "Control"))
		var node := _make_node(godot_type, cname)
		var txt := str(cd.get("text", ""))
		_apply_text(node, txt)
		var rect: Rect2 = cd.get("rect", Rect2())
		_adapter.add_placed_control(node, rect)
		_controls.append({
			"name": cname, "type": godot_type, "node": node,
			"rect": rect, "text": txt,
		})

	if _form_name_field:
		_form_name_field.text = _form_name
	if _adapter:
		_adapter.get_parent().custom_minimum_size = _form_size
	_set_status("Opened " + tscn_path + " (%d controls)" % _controls.size())


# ─── Helpers ────────────────────────────────────────────────

func _make_node(godot_type: String, node_name: String) -> Control:
	var node: Control
	match godot_type:
		"Button": node = Button.new()
		"Label": node = Label.new()
		"LineEdit": node = LineEdit.new()
		"CheckBox": node = CheckBox.new()
		"OptionButton": node = OptionButton.new()
		"ItemList": node = ItemList.new()
		_: node = Button.new()
	node.name = node_name
	_apply_text(node, _default_text_for(godot_type, node_name))
	return node

func _default_text_for(godot_type: String, node_name: String) -> String:
	match godot_type:
		"Button", "Label", "CheckBox":
			return node_name
		_:
			return ""

func _apply_text(node: Control, txt: String) -> void:
	if txt == "":
		return
	if node is Button or node is Label or node is LineEdit:
		node.text = txt

func _serializable_controls() -> Array:
	var out: Array = []
	for e in _controls:
		out.append({
			"name": e["name"], "type": e["type"],
			"rect": e["rect"], "text": e["text"],
		})
	return out

func _existing_names() -> Array:
	var names: Array = []
	for e in _controls:
		names.append(e["name"])
	return names

func _find_entry_by_node(node: Control) -> Dictionary:
	for e in _controls:
		if e["node"] == node:
			return e
	return {}

func _ensure_paths() -> void:
	if _form_name == "":
		_form_name = "Form1"
	if _tscn_path == "":
		_tscn_path = "res://" + _form_name + ".tscn"
	if _vg_path == "":
		_vg_path = "res://" + _form_name + ".vg"

func _derive_vg_path(tscn_path: String, form_name: String) -> String:
	return tscn_path.get_base_dir().path_join(form_name + ".vg")

func _sanitize_name(raw: String) -> String:
	var s := ""
	for ch in raw.strip_edges():
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") \
				or (ch >= "0" and ch <= "9") or ch == "_":
			s += ch
	return s

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg

func _rescan_filesystem() -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var ei = Engine.get_singleton("EditorInterface")
		if ei and ei.has_method("get_resource_filesystem"):
			var fs = ei.get_resource_filesystem()
			if fs:
				fs.scan()
