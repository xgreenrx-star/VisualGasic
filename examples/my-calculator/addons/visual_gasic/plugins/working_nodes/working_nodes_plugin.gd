@tool
extends "res://addons/visual_gasic/vg_plugin_base.gd"

var _editor: Control = null
var _right_panel: PanelContainer = null
var _fallback_graph: GraphEdit = null
var _fallback_status: Label = null
var _fallback_next_id: int = 1
# Extended fallback state
var _fallback_node_meta: Dictionary = {}       # node_name -> node_kind
var _fallback_undo_redo: UndoRedo = null
var _fallback_save_path: String = "user://working_nodes_fallback.json"
var _fallback_autosave_timer: Timer = null
var _fallback_node_count_label: Label = null
var _fallback_canvas_menu: PopupMenu = null
var _fallback_node_menu: PopupMenu = null
var _fallback_last_rclick_pos: Vector2 = Vector2.ZERO
var _fallback_last_selected_node: GraphNode = null
var _fallback_search_text: String = ""

func get_plugin_name() -> String:
	return "Working Nodes"

func get_toolbar_icon() -> String:
	return "🧠"

func get_toolbar_color() -> Color:
	return Color(0.35, 0.55, 0.9)

func get_toolbar_tooltip() -> String:
	return "Working Nodes — trigger graph editor"

func _build_ui() -> void:
	if _view is HSplitContainer:
		(_view as HSplitContainer).dragger_visibility = SplitContainer.DRAGGER_HIDDEN
		(_view as HSplitContainer).add_theme_constant_override("separation", 0)
		(_view as HSplitContainer).split_offset = 220

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(220, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.10, 0.11, 0.15)
	left_panel.add_theme_stylebox_override("panel", left_style)
	_view.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_v)

	var title := Label.new()
	title.text = "Working Nodes"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	left_v.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "GD-style triggers + Blender-style math"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	left_v.add_child(subtitle)

	left_v.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "Use +Event / +Action / +Math\nin the main panel to build logic."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	left_v.add_child(hint)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.14, 0.14, 0.18)
	right_panel.add_theme_stylebox_override("panel", right_style)
	_view.add_child(right_panel)
	_right_panel = right_panel

	var loading_label := Label.new()
	loading_label.name = "WNLoadingLabel"
	loading_label.text = "Loading Working Nodes editor..."
	loading_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	right_panel.add_child(loading_label)

	var scr := load("res://addons/visual_gasic/plugins/working_nodes/working_nodes_editor.gd")
	if scr == null:
		_build_inline_fallback(right_panel, "Editor script missing; using fallback UI")
		return
	_editor = scr.new()
	if not (_editor is Control):
		_build_inline_fallback(right_panel, "Editor script did not return a Control; using fallback UI")
		return
	_editor.custom_minimum_size = Vector2(1200, 760)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loading_label.visible = false
	right_panel.add_child(_editor)
	if _editor.has_method("_ensure_initialized"):
		_editor.call_deferred("_ensure_initialized")
	call_deferred("_verify_editor_surface")


func _try_mount_full_editor(host: Control) -> bool:
	var scr := load("res://addons/visual_gasic/plugins/working_nodes/working_nodes_editor.gd")
	if scr == null:
		_fallback_set_status("Full editor script missing.")
		return false

	var candidate = scr.new()
	if not (candidate is Control):
		_fallback_set_status("Full editor script did not return a Control.")
		return false

	for c in host.get_children():
		c.queue_free()

	_editor = candidate
	_editor.custom_minimum_size = Vector2(1200, 760)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(_editor)

	if _editor.has_method("_ensure_initialized"):
		_editor.call_deferred("_ensure_initialized")
	call_deferred("_verify_editor_surface")
	return true


func _on_activated() -> void:
	if is_instance_valid(_view):
		_view.visible = true
	if is_instance_valid(_editor):
		_editor.visible = true
		if _editor.has_method("_ensure_initialized"):
			_editor.call_deferred("_ensure_initialized")
	call_deferred("_verify_editor_surface")


func _on_deactivated() -> void:
	pass


func _verify_editor_surface() -> void:
	if _right_panel == null or not is_instance_valid(_right_panel):
		return
	if _editor == null or not is_instance_valid(_editor):
		if _right_panel.get_child_count() <= 1:
			_build_inline_fallback(_right_panel, "Editor unavailable; fallback UI active")
		return
	# If editor stayed empty due init failure, show guaranteed fallback.
	if _editor.get_child_count() == 0:
		_editor.queue_free()
		_editor = null
		_build_inline_fallback(_right_panel, "Editor failed to initialize; fallback UI active")


func _build_inline_fallback(host: Control, reason: String) -> void:
	for c in host.get_children():
		c.queue_free()
	_editor = null
	_fallback_graph = null
	_fallback_status = null
	_fallback_next_id = 1
	_fallback_node_meta = {}
	_fallback_last_selected_node = null
	if _fallback_undo_redo == null:
		_fallback_undo_redo = UndoRedo.new()
	else:
		_fallback_undo_redo.clear_history()

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(root)

	var banner := Label.new()
	banner.text = "Working Nodes (Fallback Mode)"
	banner.add_theme_font_size_override("font_size", 14)
	banner.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	root.add_child(banner)

	var why := Label.new()
	why.text = reason
	why.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	root.add_child(why)
	_fallback_status = why

	# ── Toolbar row 1: file / edit ops ───────────────────────────────────
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	root.add_child(row1)
	_wn_btn(row1, "Full Editor", _on_fallback_try_full_editor.bindv([host]))
	_wn_btn(row1, "New", _fallback_new_graph)
	_wn_btn(row1, "💾 Save", _fallback_save)
	_wn_btn(row1, "📂 Load", _fallback_load)
	row1.add_child(VSeparator.new())
	_wn_btn(row1, "↩ Undo", _fallback_undo)
	_wn_btn(row1, "↪ Redo", _fallback_redo)
	row1.add_child(VSeparator.new())
	_wn_btn(row1, "Sel All", _fallback_select_all)
	_wn_btn(row1, "🗑 Del", _fallback_delete_selected)
	_wn_btn(row1, "⧉ Dup", _fallback_duplicate_selected)
	row1.add_child(VSeparator.new())
	var search_icon := Label.new(); search_icon.text = "🔍"
	row1.add_child(search_icon)
	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "Filter nodes..."
	search_edit.custom_minimum_size = Vector2(130, 0)
	search_edit.text_changed.connect(_fallback_filter_nodes)
	row1.add_child(search_edit)

	# ── Toolbar row 2: node types / view ops ─────────────────────────────
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	root.add_child(row2)
	_wn_btn(row2, "+Evt",  _on_fallback_add_event)
	_wn_btn(row2, "+Act",  _on_fallback_add_action)
	_wn_btn(row2, "+Math", _on_fallback_add_math)
	_wn_btn(row2, "+Cond", _on_fallback_add_condition)
	_wn_btn(row2, "+Var",  _on_fallback_add_variable)
	_wn_btn(row2, "+Note", _on_fallback_add_note)
	_wn_btn(row2, "+Grp",  _on_fallback_add_group)
	_wn_btn(row2, "+Loop", _on_fallback_add_loop)
	_wn_btn(row2, "+Seq",  _on_fallback_add_sequence)
	_wn_btn(row2, "+Fn",   _on_fallback_add_function)
	row2.add_child(VSeparator.new())
	_wn_btn(row2, "Conn", _fallback_connect_selected)
	_wn_btn(row2, "⊙", func():
		if _fallback_graph:
			_fallback_graph.zoom = 1.0
			_fallback_graph.scroll_offset = Vector2.ZERO
	)
	row2.add_child(VSeparator.new())
	# Zoom buttons (feature 11)
	_wn_btn(row2, "−", func(): if _fallback_graph: _fallback_graph.zoom = max(0.3, _fallback_graph.zoom - 0.15))
	_wn_btn(row2, "+", func(): if _fallback_graph: _fallback_graph.zoom = min(3.0, _fallback_graph.zoom + 0.15))
	row2.add_child(VSeparator.new())
	# Grid snap toggle (feature 10)
	var snap_btn := CheckButton.new()
	snap_btn.text = "Snap"
	snap_btn.button_pressed = true
	snap_btn.toggled.connect(func(on: bool): if _fallback_graph: _fallback_graph.snapping_enabled = on)
	row2.add_child(snap_btn)
	# Minimap toggle (feature 9)
	var map_btn := CheckButton.new()
	map_btn.text = "Map"
	map_btn.button_pressed = true
	map_btn.toggled.connect(func(on: bool): if _fallback_graph: _fallback_graph.minimap_enabled = on)
	row2.add_child(map_btn)
	row2.add_child(VSeparator.new())
	# Execution order badge (feature 13)
	_wn_btn(row2, "⓪ Order", _fallback_show_exec_order)
	row2.add_child(VSeparator.new())
	# Node count badge (feature 12)
	var count_lbl := Label.new()
	count_lbl.text = "Nodes: 0  Conns: 0"
	count_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_fallback_node_count_label = count_lbl
	row2.add_child(count_lbl)

	# ── Toolbar row 3: Blender utility + GD trigger nodes ────────────────
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	root.add_child(row3)
	var r3_lbl := Label.new(); r3_lbl.text = "Blender:"; r3_lbl.add_theme_color_override("font_color", Color(0.7,0.85,0.55))
	row3.add_child(r3_lbl)
	_wn_btn(row3, "+VecM",  _on_fallback_add_vectormath)
	_wn_btn(row3, "+MapR",  _on_fallback_add_maprange)
	_wn_btn(row3, "+Bool",  _on_fallback_add_boolmath)
	_wn_btn(row3, "+Sw",    _on_fallback_add_switch)
	_wn_btn(row3, "+Cmp",   _on_fallback_add_compare)
	_wn_btn(row3, "+Rnd",   _on_fallback_add_randomvalue)
	row3.add_child(VSeparator.new())
	var r3_gd := Label.new(); r3_gd.text = "GD Triggers:"; r3_gd.add_theme_color_override("font_color", Color(1.0,0.65,0.25))
	row3.add_child(r3_gd)
	_wn_btn(row3, "+Trig",   _on_fallback_add_trigger)
	_wn_btn(row3, "+Color",  _on_fallback_add_colorchannel)
	_wn_btn(row3, "+Move",   _on_fallback_add_movegroup)
	_wn_btn(row3, "+Rot",    _on_fallback_add_rotategroup)
	_wn_btn(row3, "+Spawn",  _on_fallback_add_spawntrigger)
	_wn_btn(row3, "+Alpha",  _on_fallback_add_alphafade)
	_wn_btn(row3, "+Tog",    _on_fallback_add_togglegroup)
	_wn_btn(row3, "+Coll",   _on_fallback_add_collisiontrigger)
	_wn_btn(row3, "+Cnt",    _on_fallback_add_counteritem)
	_wn_btn(row3, "+Pulse",  _on_fallback_add_pulseeffect)
	_wn_btn(row3, "+Fol",    _on_fallback_add_followtarget)
	_wn_btn(row3, "+Cam",    _on_fallback_add_cameracontrol)
	_wn_btn(row3, "+Time",   _on_fallback_add_timedevent)

	# ── GraphEdit ─────────────────────────────────────────────────────────
	var graph := GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.show_zoom_label = true
	graph.right_disconnects = true
	graph.minimap_enabled = true          # feature 9
	graph.minimap_size = Vector2(200, 120)
	graph.snapping_enabled = true         # feature 10
	graph.snapping_distance = 20
	graph.connection_request.connect(func(fn: StringName, fp: int, tn: StringName, tp: int):
		if _fallback_graph and not _fallback_graph.is_node_connected(fn, fp, tn, tp):
			_fallback_graph.connect_node(fn, fp, tn, tp)
			_fallback_update_node_count()
	)
	graph.disconnection_request.connect(func(fn: StringName, fp: int, tn: StringName, tp: int):
		if _fallback_graph and _fallback_graph.is_node_connected(fn, fp, tn, tp):
			_fallback_graph.disconnect_node(fn, fp, tn, tp)
			_fallback_update_node_count()
	)
	# Feature 1: Delete key via GraphEdit signal
	graph.delete_nodes_request.connect(_fallback_delete_nodes_by_name)
	# Feature 17: canvas RMB context menu
	graph.gui_input.connect(_on_graph_gui_input_fallback)
	# Feature 18: node selection tracking for node context menu
	graph.node_selected.connect(_on_graph_node_selected_fallback)
	# Feature 19: drag-from-port-to-empty opens add menu
	graph.connection_to_empty.connect(func(from_n: StringName, from_p: int, rpos: Vector2):
		_fallback_last_rclick_pos = rpos + _fallback_graph.scroll_offset
		if _fallback_canvas_menu and is_instance_valid(_fallback_canvas_menu):
			_fallback_canvas_menu.popup(Rect2(_fallback_graph.get_global_rect().position + rpos, Vector2.ZERO))
	)
	root.add_child(graph)
	_fallback_graph = graph

	# ── Context menus ──────────────────────────────────────────────────────
	# Feature 17: canvas right-click menu
	var canvas_menu := PopupMenu.new()
	canvas_menu.add_item("+ Event",     0); canvas_menu.add_item("+ Action",   1)
	canvas_menu.add_item("+ Math",      2); canvas_menu.add_item("+ Condition",3)
	canvas_menu.add_item("+ Variable",  4); canvas_menu.add_item("+ Note",     5)
	canvas_menu.add_item("+ Group",     6); canvas_menu.add_item("+ Loop",     7)
	canvas_menu.add_item("+ Sequence",  8); canvas_menu.add_item("+ Function", 9)
	canvas_menu.add_separator()
	canvas_menu.add_item("Select All",  10); canvas_menu.add_item("Clear Graph", 11)
	canvas_menu.id_pressed.connect(_on_canvas_menu_id_pressed)
	graph.add_child(canvas_menu)
	_fallback_canvas_menu = canvas_menu

	# Feature 18: node right-click menu
	var node_menu := PopupMenu.new()
	node_menu.add_item("Duplicate",     0)
	node_menu.add_item("Delete",        1)
	node_menu.add_separator()
	node_menu.add_item("Bring to Front",2)
	node_menu.id_pressed.connect(_on_node_menu_id_pressed)
	graph.add_child(node_menu)
	_fallback_node_menu = node_menu

	# Feature 8: auto-save every 30 s
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(func():
		if _fallback_graph and is_instance_valid(_fallback_graph):
			_fallback_save_to_path("user://working_nodes_autosave.json")
	)
	root.add_child(timer)
	_fallback_autosave_timer = timer

	_fallback_new_graph()


# ── Helper ────────────────────────────────────────────────────────────────────
func _wn_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _mk_row(parent: Control, label: String, min_v: float, max_v: float, step_v: float) -> SpinBox:
	var row := HBoxContainer.new()
	var lbl := Label.new(); lbl.text = label; lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(lbl)
	var sp := SpinBox.new(); sp.min_value = min_v; sp.max_value = max_v; sp.step = step_v
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	parent.add_child(row)
	return sp

# ── Status ────────────────────────────────────────────────────────────────────
func _fallback_set_status(message: String) -> void:
	if _fallback_status != null and is_instance_valid(_fallback_status):
		_fallback_status.text = message

# ── Node count (feature 12) ───────────────────────────────────────────────────
func _fallback_update_node_count() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	var n := 0
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			n += 1
	var conns := _fallback_graph.get_connection_list().size()
	if _fallback_node_count_label != null and is_instance_valid(_fallback_node_count_label):
		_fallback_node_count_label.text = "Nodes: %d  Conns: %d" % [n, conns]

# ── New Graph ─────────────────────────────────────────────────────────────────
func _fallback_new_graph() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	for child in _fallback_graph.get_children():
		if child is GraphNode:
			child.queue_free()
	_fallback_next_id = 1
	_fallback_node_meta = {}
	if _fallback_undo_redo != null:
		_fallback_undo_redo.clear_history()
	var event_node := _fallback_add_node("Event", Vector2(120, 120))
	var action_node := _fallback_add_node("Action", Vector2(420, 160))
	if event_node != null and action_node != null:
		_fallback_graph.connect_node(StringName(event_node.name), 0, StringName(action_node.name), 0)
	_fallback_update_node_count()
	_fallback_set_status("Graph reset.")

# ── Undo / Redo (feature 3) ───────────────────────────────────────────────────
func _fallback_undo() -> void:
	if _fallback_undo_redo != null:
		_fallback_undo_redo.undo()
		_fallback_update_node_count()

func _fallback_redo() -> void:
	if _fallback_undo_redo != null:
		_fallback_undo_redo.redo()
		_fallback_update_node_count()

# ── Select All (feature 4) ────────────────────────────────────────────────────
func _fallback_select_all() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			c.selected = true
	_fallback_set_status("All nodes selected.")

# ── Delete (feature 1) ────────────────────────────────────────────────────────
func _fallback_delete_selected() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	var to_del: Array = []
	for c in _fallback_graph.get_children():
		if c is GraphNode and c.selected:
			to_del.append(c)
	if to_del.is_empty():
		_fallback_set_status("No nodes selected.")
		return
	if _fallback_undo_redo != null:
		_fallback_undo_redo.create_action("Delete Nodes")
		for nd in to_del:
			var nname := nd.name
			var nkind: String = _fallback_node_meta.get(nname, "Event")
			var npos := nd.position_offset
			_fallback_undo_redo.add_do_method(func():
				var existing: Node = _fallback_graph.get_node_or_null(NodePath(nname))
				if existing: existing.queue_free()
				_fallback_node_meta.erase(nname)
				_fallback_update_node_count()
			)
			_fallback_undo_redo.add_undo_method(func():
				_fallback_add_node(nkind, npos)
				_fallback_update_node_count()
			)
		_fallback_undo_redo.commit_action()
	else:
		for nd in to_del:
			_fallback_node_meta.erase(nd.name)
			nd.queue_free()
	_fallback_update_node_count()
	_fallback_set_status("Deleted %d node(s)." % to_del.size())

func _fallback_delete_nodes_by_name(nodes: Array[StringName]) -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	for nname in nodes:
		var nd: Node = _fallback_graph.get_node_or_null(NodePath(nname))
		if nd and nd is GraphNode:
			_fallback_node_meta.erase(nname)
			nd.queue_free()
	_fallback_update_node_count()
	_fallback_set_status("Deleted %d node(s)." % nodes.size())

# ── Duplicate (feature 2) ─────────────────────────────────────────────────────
func _fallback_duplicate_selected() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	var sel: Array = []
	for c in _fallback_graph.get_children():
		if c is GraphNode and c.selected:
			sel.append(c)
	if sel.is_empty():
		_fallback_set_status("No nodes selected to duplicate.")
		return
	for nd in sel:
		nd.selected = false
		var kind: String = _fallback_node_meta.get(nd.name, "Event")
		var new_nd := _fallback_add_node(kind, nd.position_offset + Vector2(40, 40))
		if new_nd:
			new_nd.selected = true
	_fallback_update_node_count()
	_fallback_set_status("Duplicated %d node(s)." % sel.size())

# ── Search / Filter (feature 5) ───────────────────────────────────────────────
func _fallback_filter_nodes(text: String) -> void:
	_fallback_search_text = text.to_lower()
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			if text.is_empty():
				c.modulate.a = 1.0
			else:
				c.modulate.a = 1.0 if _fallback_search_text in c.title.to_lower() else 0.3

# ── Save (feature 6) ──────────────────────────────────────────────────────────
func _fallback_save() -> void:
	_fallback_save_to_path(_fallback_save_path)

func _fallback_save_to_path(path: String) -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	var data := {"version": 1, "nodes": [], "connections": []}
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			data["nodes"].append({
				"name": c.name, "kind": _fallback_node_meta.get(c.name, "Event"),
				"x": c.position_offset.x, "y": c.position_offset.y, "title": c.title
			})
	for conn in _fallback_graph.get_connection_list():
		data["connections"].append({
			"from": conn["from_node"], "from_port": conn["from_port"],
			"to": conn["to_node"],   "to_port":   conn["to_port"]
		})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		_fallback_set_status("Saved → %s" % path)
	else:
		_fallback_set_status("Save failed: cannot open %s" % path)

# ── Load (feature 7) ──────────────────────────────────────────────────────────
func _fallback_load() -> void:
	_fallback_load_from_path(_fallback_save_path)

func _fallback_load_from_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		_fallback_set_status("No save found at %s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		_fallback_set_status("Load failed: cannot open %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		_fallback_set_status("Load failed: invalid JSON")
		return
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			c.queue_free()
	_fallback_next_id = 1
	_fallback_node_meta = {}
	var remap: Dictionary = {}
	for nd in parsed.get("nodes", []):
		var kind: String = nd.get("kind", "Event")
		var pos := Vector2(float(nd.get("x", 0)), float(nd.get("y", 0)))
		var new_nd := _fallback_add_node(kind, pos)
		if new_nd:
			remap[nd.get("name", "")] = new_nd.name
	for conn in parsed.get("connections", []):
		var fn: String = remap.get(conn.get("from",""), conn.get("from",""))
		var tn: String = remap.get(conn.get("to",""),   conn.get("to",""))
		var fp: int = conn.get("from_port", 0)
		var tp: int = conn.get("to_port", 0)
		if _fallback_graph.has_node(NodePath(fn)) and _fallback_graph.has_node(NodePath(tn)):
			if not _fallback_graph.is_node_connected(StringName(fn), fp, StringName(tn), tp):
				_fallback_graph.connect_node(StringName(fn), fp, StringName(tn), tp)
	_fallback_update_node_count()
	_fallback_set_status("Loaded %d nodes from %s" % [remap.size(), path])

# ── Execution order preview (feature 13) ─────────────────────────────────────
func _fallback_show_exec_order() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	for c in _fallback_graph.get_children():
		if c is GraphNode:
			var b: Node = c.get_node_or_null("_exec_badge")
			if b: b.queue_free()
	var queue: Array = []
	for c in _fallback_graph.get_children():
		if c is GraphNode and _fallback_node_meta.get(c.name, "") == "Event":
			queue.append(c.name)
	var visited: Dictionary = {}
	var order: Dictionary = {}
	var counter := 1
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		if visited.has(cur): continue
		visited[cur] = true
		order[cur] = counter
		counter += 1
		for conn in _fallback_graph.get_connection_list():
			if conn["from_node"] == cur:
				queue.append(conn["to_node"])
	for nname in order:
		var nd: Node = _fallback_graph.get_node_or_null(NodePath(nname))
		if nd and nd is GraphNode:
			var badge := Label.new()
			badge.name = "_exec_badge"
			badge.text = "⓪%d" % order[nname]
			badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			badge.position = Vector2(-32, -22)
			nd.add_child(badge)
	_fallback_set_status("Execution order: %d nodes reachable." % order.size())

# ── Context menus (features 17, 18) ──────────────────────────────────────────
func _on_graph_gui_input_fallback(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_fallback_last_rclick_pos = mb.position + _fallback_graph.scroll_offset
			if _fallback_canvas_menu and is_instance_valid(_fallback_canvas_menu):
				_fallback_canvas_menu.popup(Rect2(mb.global_position, Vector2.ZERO))

func _on_graph_node_selected_fallback(node: Node) -> void:
	if node is GraphNode:
		_fallback_last_selected_node = node
		# Feature 18: show node context menu
		if _fallback_node_menu and is_instance_valid(_fallback_node_menu):
			var mp := _fallback_graph.get_global_rect().position + node.position_offset - _fallback_graph.scroll_offset
			_fallback_node_menu.popup(Rect2(mp + Vector2(node.size.x, 0), Vector2.ZERO))

func _on_canvas_menu_id_pressed(id: int) -> void:
	var at := _fallback_last_rclick_pos
	var _kind_map: Dictionary = {
		0:"Event", 1:"Action", 2:"Math", 3:"Condition", 4:"Variable",
		5:"Note", 6:"Group", 7:"Loop", 8:"Sequence", 9:"Function",
		12:"VectorMath", 13:"MapRange", 14:"BoolMath", 15:"Switch", 16:"Compare", 17:"RandomValue",
		18:"Trigger", 19:"ColorChannel", 20:"MoveGroup", 21:"RotateGroup", 22:"SpawnTrigger",
		23:"AlphaFade", 24:"ToggleGroup", 25:"CollisionTrigger", 26:"CounterItem",
		27:"PulseEffect", 28:"FollowTarget", 29:"CameraControl", 30:"TimedEvent"
	}
	if _kind_map.has(id):
		_fallback_add_node(_kind_map[id], at)
	elif id == 31:
		_fallback_select_all()
	elif id == 32:
		_fallback_new_graph()
	_fallback_update_node_count()

func _on_node_menu_id_pressed(id: int) -> void:
	if _fallback_last_selected_node == null or not is_instance_valid(_fallback_last_selected_node):
		return
	match id:
		0:  # Duplicate
			var kind: String = _fallback_node_meta.get(_fallback_last_selected_node.name, "Event")
			_fallback_add_node(kind, _fallback_last_selected_node.position_offset + Vector2(40, 40))
			_fallback_update_node_count()
		1:  # Delete
			_fallback_node_meta.erase(_fallback_last_selected_node.name)
			_fallback_last_selected_node.queue_free()
			_fallback_last_selected_node = null
			_fallback_update_node_count()
			_fallback_set_status("Node deleted.")
		2:  # Bring to Front
			var par := _fallback_last_selected_node.get_parent()
			if par:
				par.move_child(_fallback_last_selected_node, par.get_child_count() - 1)

# ── Connect selected ──────────────────────────────────────────────────────────
func _fallback_connect_selected() -> void:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		return
	var sel: Array[GraphNode] = []
	for c in _fallback_graph.get_children():
		if c is GraphNode and c.selected:
			sel.append(c)
	if sel.size() < 2:
		_fallback_set_status("Select at least 2 nodes to connect.")
		return
	sel.sort_custom(func(a: GraphNode, b: GraphNode): return a.position_offset.x < b.position_offset.x)
	var made := 0
	for i in range(sel.size() - 1):
		var fn := StringName(sel[i].name)
		var tn := StringName(sel[i + 1].name)
		if not _fallback_graph.is_node_connected(fn, 0, tn, 0):
			_fallback_graph.connect_node(fn, 0, tn, 0)
			made += 1
	_fallback_update_node_count()
	_fallback_set_status("Connected %d link(s)." % made if made > 0 else "Already connected.")

# ── Add node ──────────────────────────────────────────────────────────────────
func _fallback_add_node(node_kind: String, at_pos: Vector2 = Vector2(-1, -1)) -> GraphNode:
	if _fallback_graph == null or not is_instance_valid(_fallback_graph):
		_fallback_set_status("ERROR: graph not ready")
		return null

	var COLOR_EXEC   := Color(1.00, 1.00, 1.00)
	var COLOR_BOOL   := Color(0.90, 0.30, 0.30)
	var COLOR_INT    := Color(0.30, 0.90, 0.40)
	var COLOR_FLOAT  := Color(0.30, 0.55, 1.00)
	var PORT_EXEC    := 0; var PORT_BOOL := 1; var PORT_INT := 2; var PORT_FLOAT := 3

	var node := GraphNode.new()
	node.name = "WN_FB_%d" % _fallback_next_id
	node.title = "%s %d" % [node_kind, _fallback_next_id]
	node.resizable = true

	# Feature 20: tooltips
	var _tooltips := {
		"Event":"Fires execution on a lifecycle or input event.",
		"Action":"Performs an operation on a node in the scene.",
		"Math":"44-op Blender-style math: Arithmetic/Comparison/Rounding/Trig/Conversion/Interpolation.",
		"Condition":"Branches execution based on a boolean test.",
		"Variable":"Stores and outputs a named value.",
		"Note":"Freeform text annotation (no ports).",
		"Group":"Visual frame for grouping related nodes.",
		"Loop":"Repeats execution for each iteration.",
		"Sequence":"Fires outputs in numbered order.",
		"Function":"Reusable subgraph with named inputs/outputs.",
		"VectorMath":"Blender-style vector math: 24 operations on Vector2/3.",
		"MapRange":"Remaps a value from one numeric range to another (Blender Map Range).",
		"BoolMath":"Boolean logic: AND OR NOT NAND NOR XOR XNOR.",
		"Switch":"Outputs True-value or False-value based on a boolean switch.",
		"Compare":"Compares two values and outputs a boolean result.",
		"RandomValue":"Outputs a random float/int/bool/vector within a range with optional seed.",
		"Trigger":"GD-style: activates a group with optional delay and spawn-trigger mode.",
		"ColorChannel":"GD-style: changes a color channel (1-1000) with duration and blend mode.",
		"MoveGroup":"GD-style: moves a group by X/Y over a duration with easing.",
		"RotateGroup":"GD-style: rotates a group by degrees over a duration with easing.",
		"SpawnTrigger":"GD-style: chains/spawns another trigger group with optional delay and remap.",
		"AlphaFade":"GD-style: fades a group's opacity to target value over duration.",
		"ToggleGroup":"GD-style: toggles a group on, off, or flips its visibility.",
		"CollisionTrigger":"GD-style: fires when two block groups overlap.",
		"CounterItem":"GD-style: fires when an item counter meets a target condition.",
		"PulseEffect":"GD-style: pulses a group's color with fade-in, hold, and fade-out.",
		"FollowTarget":"GD-style: makes a group follow another group at a set speed.",
		"CameraControl":"GD-style: controls camera zoom, pan, offset, or static position.",
		"TimedEvent":"GD-style: fires after a delay, with optional repeat interval and loop."
	}
	node.tooltip_text = _tooltips.get(node_kind, node_kind)

	# ── Note node (no ports) ──────────────────────────────────────────────
	if node_kind == "Note":
		node.custom_minimum_size = Vector2(240, 140)
		var sty := StyleBoxFlat.new()
		sty.bg_color = Color(0.28, 0.26, 0.12)
		sty.border_width_left = 3; sty.border_color = Color(1.0, 0.85, 0.25)
		node.add_theme_stylebox_override("panel", sty)
		var ta := TextEdit.new()
		ta.placeholder_text = "Write notes here..."
		ta.custom_minimum_size = Vector2(220, 100)
		ta.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node.add_child(ta)
		_fallback_graph.add_child(node)
		node.position_offset = at_pos if at_pos.x >= 0 else Vector2(140 + float(_fallback_next_id)*60, 140 + float(_fallback_next_id)*40)
		_fallback_node_meta[node.name] = node_kind
		_fallback_next_id += 1
		_fallback_set_status("Added Note.")
		return node

	# ── Group / Frame node ────────────────────────────────────────────────
	if node_kind == "Group":
		node.custom_minimum_size = Vector2(400, 280)
		var sty := StyleBoxFlat.new()
		sty.bg_color = Color(0.15, 0.22, 0.30, 0.45)
		sty.border_width_left = 3; sty.border_width_right = 3
		sty.border_width_top = 3; sty.border_width_bottom = 3
		sty.border_color = Color(0.4, 0.7, 1.0, 0.8)
		node.add_theme_stylebox_override("panel", sty)
		var lbl := Label.new(); lbl.text = "Group Label"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
		node.add_child(lbl)
		_fallback_graph.add_child(node)
		node.position_offset = at_pos if at_pos.x >= 0 else Vector2(140 + float(_fallback_next_id)*60, 140 + float(_fallback_next_id)*40)
		_fallback_node_meta[node.name] = node_kind
		_fallback_next_id += 1
		_fallback_set_status("Added Group frame.")
		return node

	# ── Standard node body ────────────────────────────────────────────────
	node.custom_minimum_size = Vector2(240, 0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	node.add_child(body)

	# Feature 10: collapse button
	var header_row := HBoxContainer.new(); body.add_child(header_row)
	var lbl_kind := Label.new(); lbl_kind.text = node_kind
	lbl_kind.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	lbl_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl_kind)
	var btn_collapse := Button.new(); btn_collapse.text = "▲"; btn_collapse.custom_minimum_size = Vector2(24, 24)
	header_row.add_child(btn_collapse)

	# Feature 2: color tag
	var color_row := HBoxContainer.new(); body.add_child(color_row)
	var clr_lbl := Label.new(); clr_lbl.text = "Color:"; clr_lbl.custom_minimum_size = Vector2(44, 0)
	color_row.add_child(clr_lbl)
	var cpb := ColorPickerButton.new(); cpb.custom_minimum_size = Vector2(60, 22)
	var def_colors := {
		"Event":Color(0.3,0.5,0.9),     "Action":Color(0.3,0.75,0.45),  "Math":Color(0.7,0.45,0.9),
		"Condition":Color(0.9,0.6,0.2), "Variable":Color(0.25,0.8,0.85),"Loop":Color(0.8,0.4,0.55),
		"Sequence":Color(0.5,0.8,0.6),  "Function":Color(0.75,0.65,0.95),
		# Blender utility
		"VectorMath":Color(0.3,0.8,0.7), "MapRange":Color(0.5,0.75,0.3), "BoolMath":Color(0.85,0.3,0.35),
		"Switch":Color(0.65,0.65,0.85),  "Compare":Color(0.9,0.7,0.3),   "RandomValue":Color(0.4,0.85,0.55),
		# Geometry Dash triggers
		"Trigger":Color(1.0,0.5,0.15),       "ColorChannel":Color(0.9,0.3,0.7),  "MoveGroup":Color(0.3,0.7,1.0),
		"RotateGroup":Color(0.5,0.9,0.5),    "SpawnTrigger":Color(1.0,0.8,0.2),  "AlphaFade":Color(0.6,0.6,0.95),
		"ToggleGroup":Color(0.85,0.55,0.25), "CollisionTrigger":Color(1.0,0.3,0.3),"CounterItem":Color(0.4,0.9,0.8),
		"PulseEffect":Color(0.9,0.4,0.85),   "FollowTarget":Color(0.3,0.85,0.65), "CameraControl":Color(0.7,0.85,1.0),
		"TimedEvent":Color(0.95,0.75,0.35)
	}
	cpb.color = def_colors.get(node_kind, Color(0.6, 0.6, 0.6))
	node.modulate = cpb.color.lerp(Color.WHITE, 0.55)
	cpb.color_changed.connect(func(c: Color): node.modulate = c.lerp(Color.WHITE, 0.55))
	color_row.add_child(cpb)

	# Feature 3: enabled toggle
	var tog_row := HBoxContainer.new(); body.add_child(tog_row)
	var tog_lbl := Label.new(); tog_lbl.text = "Enabled:"; tog_lbl.custom_minimum_size = Vector2(60, 0)
	tog_row.add_child(tog_lbl)
	var tog := CheckButton.new(); tog.button_pressed = true
	tog.toggled.connect(func(on: bool): body.modulate = Color(1,1,1) if on else Color(0.55,0.55,0.55,0.7))
	tog_row.add_child(tog)

	# Feature 1: annotation
	var ann := LineEdit.new(); ann.placeholder_text = "Annotation..."; body.add_child(ann)

	body.add_child(HSeparator.new())
	var dc := VBoxContainer.new(); body.add_child(dc)

	# ── Per-type content + ports ──────────────────────────────────────────
	if node_kind == "Event":
		var ol := Label.new(); ol.text = "▶ trigger out"
		ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var ch := OptionButton.new()
		for s in ["On Ready","On Process","On Signal","On Input","On Timer"]: ch.add_item(s)
		dc.add_child(ch)
		node.set_slot(0, false, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	elif node_kind == "Action":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var ch := OptionButton.new()
		for s in ["Move","Rotate","Scale","Play Anim","Emit Signal","Set Property","Call Method","Tween","Wait","Print"]: ch.add_item(s)
		dc.add_child(ch)
		var tgt := LineEdit.new(); tgt.placeholder_text = "Target node path..."; dc.add_child(tgt)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	elif node_kind == "Math":
		var la := Label.new(); la.text = "A (float)"; la.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(la)
		var lb := Label.new(); lb.text = "B (float)"; lb.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lb)
		var lc := Label.new(); lc.text = "C (MultiplyAdd)"; lc.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lc)
		var lo := Label.new(); lo.text = "→ Result"; lo.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lo)
		var cat_ops: Dictionary = {
			"Arithmetic": ["Add","Subtract","Multiply","Divide","Multiply Add","Power","Log","Sqrt","Inv Sqrt","Absolute","Exponent"],
			"Comparison": ["Min","Max","Less Than","Greater Than","Sign","Compare","Smooth Min","Smooth Max"],
			"Rounding":   ["Floor","Ceil","Truncate","Round","Fraction","Modulo","Wrap","Snap","Ping Pong"],
			"Trig":       ["Sin","Cos","Tan","ArcSin","ArcCos","ArcTan","ArcTan2","Sinh","Cosh","Tanh"],
			"Conversion": ["To Radians","To Degrees"],
			"Interpolation":["Lerp","Smooth Step","Inverse Lerp","Clamp"]
		}
		var cat_btn := OptionButton.new()
		for cat in cat_ops.keys(): cat_btn.add_item(cat)
		dc.add_child(cat_btn)
		var op_btn := OptionButton.new()
		for op2 in cat_ops["Arithmetic"]: op_btn.add_item(op2)
		dc.add_child(op_btn)
		cat_btn.item_selected.connect(func(idx: int):
			op_btn.clear()
			var cats2 := cat_ops.keys()
			if idx < cats2.size():
				for op3 in cat_ops[cats2[idx]]: op_btn.add_item(op3)
		)
		node.set_slot(0, true, PORT_FLOAT, COLOR_FLOAT, true, PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(1, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(2, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)

	elif node_kind == "Condition":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var tl := Label.new(); tl.text = "✔ True";     tl.add_theme_color_override("font_color", COLOR_INT);  dc.add_child(tl)
		var fl := Label.new(); fl.text = "✘ False";    fl.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(fl)
		var ch := OptionButton.new()
		for s in ["== Equal","!= Not Equal","> Greater","< Less",">= Gte","<= Lte","Is Null","Has Signal"]: ch.add_item(s)
		dc.add_child(ch)
		var vr := HBoxContainer.new(); var vl := Label.new(); vl.text = "Value:"; vr.add_child(vl)
		var ve := LineEdit.new(); ve.placeholder_text = "compare to..."; ve.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vr.add_child(ve)
		dc.add_child(vr)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_INT, COLOR_INT)
		node.set_slot(1, false, PORT_EXEC, COLOR_EXEC, true, PORT_BOOL, COLOR_BOOL)

	elif node_kind == "Variable":
		var nr := HBoxContainer.new(); var nl := Label.new(); nl.text = "Name:"; nr.add_child(nl)
		var ne := LineEdit.new(); ne.placeholder_text = "my_var"; ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nr.add_child(ne)
		dc.add_child(nr)
		var tr := HBoxContainer.new(); var tl := Label.new(); tl.text = "Type:"; tr.add_child(tl)
		var to := OptionButton.new()
		for s in ["float","int","bool","String","Vector2","Vector3","Color","NodePath"]: to.add_item(s)
		tr.add_child(to); dc.add_child(tr)
		var vr := HBoxContainer.new(); var vl := Label.new(); vl.text = "Value:"; vr.add_child(vl)
		var sp := SpinBox.new(); sp.min_value = -999999; sp.max_value = 999999; sp.step = 0.01
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vr.add_child(sp); dc.add_child(vr)
		node.set_slot(0, true, PORT_FLOAT, COLOR_FLOAT, true, PORT_FLOAT, COLOR_FLOAT)

	# ── Feature 14: Loop node ─────────────────────────────────────────────
	elif node_kind == "Loop":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var bl := Label.new(); bl.text = "↺ body";     bl.add_theme_color_override("font_color", COLOR_INT);  dc.add_child(bl)
		var dl := Label.new(); dl.text = "▶ done";     dl.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(dl)
		var ch := OptionButton.new()
		for s in ["For (count)","While (condition)","For Each (array)","Repeat Timed"]: ch.add_item(s)
		dc.add_child(ch)
		var cr := HBoxContainer.new(); var cl := Label.new(); cl.text = "Count:"; cr.add_child(cl)
		var sp := SpinBox.new(); sp.min_value = 0; sp.max_value = 9999; sp.value = 3
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cr.add_child(sp); dc.add_child(cr)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_INT,  COLOR_INT)
		node.set_slot(1, false, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── Feature 15: Sequence node ─────────────────────────────────────────
	elif node_kind == "Sequence":
		var il := Label.new(); il.text = "▶ exec in"; il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var lbl_info := Label.new(); lbl_info.text = "Fires outputs in order:"
		lbl_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)); dc.add_child(lbl_info)
		for i in range(1, 4):
			var ol := Label.new(); ol.text = "Then %d ▶" % i
			ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)
		node.set_slot(1, false, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)
		node.set_slot(2, false, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── Feature 16: Function node ─────────────────────────────────────────
	elif node_kind == "Function":
		var nr := HBoxContainer.new(); var nl := Label.new(); nl.text = "Name:"; nr.add_child(nl)
		var ne := LineEdit.new(); ne.placeholder_text = "my_function"; ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nr.add_child(ne)
		dc.add_child(nr)
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var p1l := Label.new(); p1l.text = "param_a (float)"; p1l.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(p1l)
		var p2l := Label.new(); p2l.text = "param_b (float)"; p2l.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(p2l)
		var rl  := Label.new(); rl.text  = "→ return";        rl.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(rl)
		var rr := HBoxContainer.new(); var rtl := Label.new(); rtl.text = "Returns:"; rr.add_child(rtl)
		var rto := OptionButton.new()
		for s in ["void","float","int","bool","String","Variant"]: rto.add_item(s)
		rr.add_child(rto); dc.add_child(rr)
		node.set_slot(0, true, PORT_EXEC,  COLOR_EXEC,  true, PORT_EXEC,  COLOR_EXEC)
		node.set_slot(1, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(2, true, PORT_FLOAT, COLOR_FLOAT, true,  PORT_FLOAT, COLOR_FLOAT)

	# ══ Blender utility nodes ════════════════════════════════════════════

	# ── VectorMath ────────────────────────────────────────────────────────
	elif node_kind == "VectorMath":
		var l1 := Label.new(); l1.text = "A (Vector)"; l1.add_theme_color_override("font_color", COLOR_INT);   dc.add_child(l1)
		var l2 := Label.new(); l2.text = "B (Vector)"; l2.add_theme_color_override("font_color", COLOR_INT);   dc.add_child(l2)
		var l3 := Label.new(); l3.text = "Scale";      l3.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(l3)
		var l4 := Label.new(); l4.text = "→ Vector";   l4.add_theme_color_override("font_color", COLOR_INT);   dc.add_child(l4)
		var l5 := Label.new(); l5.text = "→ Float";    l5.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(l5)
		var op := OptionButton.new()
		for s in ["Add","Subtract","Multiply","Divide","Scale","Length","Distance","Normalize",
				"Dot Product","Cross Product","Project","Reflect","Refract","Face Forward",
				"Wrap","Snap","Floor","Ceil","Round","Modulo","Fraction","Absolute","Min","Max"]: op.add_item(s)
		dc.add_child(op)
		node.set_slot(0, true, PORT_INT,   COLOR_INT,   true,  PORT_INT,   COLOR_INT)
		node.set_slot(1, true, PORT_INT,   COLOR_INT,   true,  PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(2, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)

	# ── MapRange ──────────────────────────────────────────────────────────
	elif node_kind == "MapRange":
		for pair in [["Value",COLOR_FLOAT],["From Min",COLOR_FLOAT],["From Max",COLOR_FLOAT],
				["To Min",COLOR_FLOAT],["To Max",COLOR_FLOAT],["→ Result",COLOR_FLOAT]]:
			var ll := Label.new(); ll.text = pair[0]; ll.add_theme_color_override("font_color", pair[1]); dc.add_child(ll)
		var mode_btn := OptionButton.new()
		for s in ["Linear","Stepped","Smooth Step","Smoother Step"]: mode_btn.add_item(s)
		dc.add_child(mode_btn)
		var clamp_r := HBoxContainer.new(); var cl := Label.new(); cl.text = "Clamp:"; clamp_r.add_child(cl)
		var cc := CheckButton.new(); cc.button_pressed = true; clamp_r.add_child(cc); dc.add_child(clamp_r)
		for i in range(5): node.set_slot(i, true, PORT_FLOAT, COLOR_FLOAT, i == 0, PORT_FLOAT, COLOR_FLOAT)

	# ── BoolMath ──────────────────────────────────────────────────────────
	elif node_kind == "BoolMath":
		var la2 := Label.new(); la2.text = "A (bool)"; la2.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(la2)
		var lb2 := Label.new(); lb2.text = "B (bool)"; lb2.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(lb2)
		var lo2 := Label.new(); lo2.text = "→ Result"; lo2.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(lo2)
		var op2 := OptionButton.new()
		for s in ["AND","OR","NOT","NAND","NOR","XOR","XNOR"]: op2.add_item(s)
		dc.add_child(op2)
		node.set_slot(0, true, PORT_BOOL, COLOR_BOOL, true, PORT_BOOL, COLOR_BOOL)
		node.set_slot(1, true, PORT_BOOL, COLOR_BOOL, false, PORT_BOOL, COLOR_BOOL)

	# ── Switch ────────────────────────────────────────────────────────────
	elif node_kind == "Switch":
		var ls := Label.new(); ls.text = "Switch (bool)"; ls.add_theme_color_override("font_color", COLOR_BOOL);  dc.add_child(ls)
		var lt := Label.new(); lt.text = "True value";    lt.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lt)
		var lf := Label.new(); lf.text = "False value";   lf.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lf)
		var lo3 := Label.new(); lo3.text = "→ Output";    lo3.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lo3)
		var tr := HBoxContainer.new(); var tll := Label.new(); tll.text = "Type:"; tr.add_child(tll)
		var tob := OptionButton.new()
		for s in ["Float","Int","Bool","String","Vector2","Vector3","Color"]: tob.add_item(s)
		tr.add_child(tob); dc.add_child(tr)
		node.set_slot(0, true, PORT_BOOL,  COLOR_BOOL,  true,  PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(1, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(2, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)

	# ── Compare ───────────────────────────────────────────────────────────
	elif node_kind == "Compare":
		var la3 := Label.new(); la3.text = "A";            la3.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(la3)
		var lb3 := Label.new(); lb3.text = "B";            lb3.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lb3)
		var le  := Label.new(); le.text  = "Epsilon";     le.add_theme_color_override("font_color", COLOR_FLOAT);  dc.add_child(le)
		var lo4 := Label.new(); lo4.text = "→ Result (bool)"; lo4.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(lo4)
		var dt_r := HBoxContainer.new(); var dtl := Label.new(); dtl.text = "Type:"; dt_r.add_child(dtl)
		var dto := OptionButton.new()
		for s in ["Float","Int","Vector","String","Color"]: dto.add_item(s)
		dt_r.add_child(dto); dc.add_child(dt_r)
		var op3 := OptionButton.new()
		for s in ["< Less Than","> Greater Than","<= Lte",">= Gte","== Equal","!= Not Equal"]: op3.add_item(s)
		dc.add_child(op3)
		node.set_slot(0, true, PORT_FLOAT, COLOR_FLOAT, true,  PORT_BOOL, COLOR_BOOL)
		node.set_slot(1, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_BOOL, COLOR_BOOL)
		node.set_slot(2, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_BOOL, COLOR_BOOL)

	# ── RandomValue ───────────────────────────────────────────────────────
	elif node_kind == "RandomValue":
		var lmin := Label.new(); lmin.text = "Min";     lmin.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lmin)
		var lmax := Label.new(); lmax.text = "Max";     lmax.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lmax)
		var lsed := Label.new(); lsed.text = "Seed";   lsed.add_theme_color_override("font_color", COLOR_INT);   dc.add_child(lsed)
		var lout := Label.new(); lout.text = "→ Value"; lout.add_theme_color_override("font_color", COLOR_FLOAT); dc.add_child(lout)
		var rv_tr := HBoxContainer.new(); var rv_tl := Label.new(); rv_tl.text = "Type:"; rv_tr.add_child(rv_tl)
		var rv_to := OptionButton.new()
		for s in ["Float","Int","Bool","Vector2","Vector3"]: rv_to.add_item(s)
		rv_tr.add_child(rv_to); dc.add_child(rv_tr)
		node.set_slot(0, true, PORT_FLOAT, COLOR_FLOAT, true,  PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(1, true, PORT_FLOAT, COLOR_FLOAT, false, PORT_FLOAT, COLOR_FLOAT)
		node.set_slot(2, true, PORT_INT,   COLOR_INT,   false, PORT_FLOAT, COLOR_FLOAT)

	# ══ Geometry Dash trigger nodes ═══════════════════════════════════════

	# ── Trigger ───────────────────────────────────────────────────────────
	elif node_kind == "Trigger":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		_mk_row(dc, "Delay (s):", 0.0, 99.0, 0.01)
		var sp_r := HBoxContainer.new(); var sp_l := Label.new(); sp_l.text = "Spawn Triggered:"; sp_r.add_child(sp_l)
		var sp_c := CheckButton.new(); sp_r.add_child(sp_c); dc.add_child(sp_r)
		var mt_r := HBoxContainer.new(); var mt_l := Label.new(); mt_l.text = "Multi Trigger:"; mt_r.add_child(mt_l)
		var mt_c := CheckButton.new(); mt_r.add_child(mt_c); dc.add_child(mt_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── ColorChannel ──────────────────────────────────────────────────────
	elif node_kind == "ColorChannel":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Channel (1-1000):", 1, 1000, 1)
		var cc_cpb := ColorPickerButton.new(); cc_cpb.color = Color(1,1,1); cc_cpb.custom_minimum_size = Vector2(140,24); dc.add_child(cc_cpb)
		_mk_row(dc, "Duration (s):", 0.0, 99.0, 0.1)
		var blend := OptionButton.new()
		for s in ["None","Pulse","Blending"]: blend.add_item(s)
		dc.add_child(blend)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── MoveGroup ─────────────────────────────────────────────────────────
	elif node_kind == "MoveGroup":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		_mk_row(dc, "Move X:", -9999, 9999, 1)
		_mk_row(dc, "Move Y:", -9999, 9999, 1)
		_mk_row(dc, "Duration (s):", 0.0, 99.0, 0.1)
		var ease_btn := OptionButton.new()
		for s in ["None","Ease In","Ease Out","Ease In/Out","Elastic In","Elastic Out","Bounce In","Bounce Out","Back In","Back Out"]: ease_btn.add_item(s)
		dc.add_child(ease_btn)
		var lk_r := HBoxContainer.new(); var lk_l := Label.new(); lk_l.text = "Lock to Camera:"; lk_r.add_child(lk_l)
		var lk_c := CheckButton.new(); lk_r.add_child(lk_c); dc.add_child(lk_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── RotateGroup ───────────────────────────────────────────────────────
	elif node_kind == "RotateGroup":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		_mk_row(dc, "Degrees:", -3600, 3600, 1)
		_mk_row(dc, "Duration (s):", 0.0, 99.0, 0.1)
		var ease_btn2 := OptionButton.new()
		for s in ["None","Ease In","Ease Out","Ease In/Out"]: ease_btn2.add_item(s)
		dc.add_child(ease_btn2)
		var lkr_r := HBoxContainer.new(); var lkr_l := Label.new(); lkr_l.text = "Lock Obj Rot:"; lkr_r.add_child(lkr_l)
		var lkr_c := CheckButton.new(); lkr_r.add_child(lkr_c); dc.add_child(lkr_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── SpawnTrigger ──────────────────────────────────────────────────────
	elif node_kind == "SpawnTrigger":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Target Group:", 0, 9999, 1)
		_mk_row(dc, "Delay (s):", 0.0, 99.0, 0.01)
		var rm_r := HBoxContainer.new(); var rm_l := Label.new(); rm_l.text = "Remap:"; rm_r.add_child(rm_l)
		var rm_c := CheckButton.new(); rm_r.add_child(rm_c); dc.add_child(rm_r)
		_mk_row(dc, "Remap From:", 0.0, 1.0, 0.01)
		_mk_row(dc, "Remap To:", 0.0, 1.0, 0.01)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── AlphaFade ─────────────────────────────────────────────────────────
	elif node_kind == "AlphaFade":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		_mk_row(dc, "Opacity (0-1):", 0.0, 1.0, 0.01)
		_mk_row(dc, "Duration (s):", 0.0, 99.0, 0.1)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── ToggleGroup ───────────────────────────────────────────────────────
	elif node_kind == "ToggleGroup":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		var mode_btn2 := OptionButton.new()
		for s in ["Toggle On","Toggle Off","Flip"]: mode_btn2.add_item(s)
		dc.add_child(mode_btn2)
		_mk_row(dc, "Activate Group:", 0, 9999, 1)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── CollisionTrigger ──────────────────────────────────────────────────
	elif node_kind == "CollisionTrigger":
		var il := Label.new(); il.text = "▶ exec in";      il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ on collide"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Block A ID:", 0, 9999, 1)
		_mk_row(dc, "Block B ID:", 0, 9999, 1)
		_mk_row(dc, "Trigger Group:", 0, 9999, 1)
		var act_r := HBoxContainer.new(); var act_l := Label.new(); act_l.text = "Activate On:"; act_r.add_child(act_l)
		var act_o := OptionButton.new()
		for s in ["Overlap Begin","Overlap End","While Overlapping"]: act_o.add_item(s)
		act_r.add_child(act_o); dc.add_child(act_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── CounterItem ───────────────────────────────────────────────────────
	elif node_kind == "CounterItem":
		var il := Label.new(); il.text = "▶ exec in";   il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ on match"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var fl := Label.new(); fl.text = "✘ no match"; fl.add_theme_color_override("font_color", COLOR_BOOL); dc.add_child(fl)
		_mk_row(dc, "Item ID:", 0, 9999, 1)
		_mk_row(dc, "Target Count:", 0, 9999, 1)
		var cmp_btn := OptionButton.new()
		for s in ["== Equal","!= Not Equal","> Greater","< Less",">= Gte","<= Lte"]: cmp_btn.add_item(s)
		dc.add_child(cmp_btn)
		var sub_r := HBoxContainer.new(); var sub_l := Label.new(); sub_l.text = "Subtract?"; sub_r.add_child(sub_l)
		var sub_c := CheckButton.new(); sub_r.add_child(sub_c); dc.add_child(sub_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)
		node.set_slot(1, false, PORT_EXEC, COLOR_EXEC, true, PORT_BOOL, COLOR_BOOL)

	# ── PulseEffect ───────────────────────────────────────────────────────
	elif node_kind == "PulseEffect":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group/Channel:", 0, 9999, 1)
		var pul_t := OptionButton.new()
		for s in ["Color","HSV","Channel"]: pul_t.add_item(s)
		dc.add_child(pul_t)
		var pul_cpb := ColorPickerButton.new(); pul_cpb.color = Color(1,1,1); pul_cpb.custom_minimum_size = Vector2(140,24); dc.add_child(pul_cpb)
		_mk_row(dc, "Fade In:", 0.0, 10.0, 0.1)
		_mk_row(dc, "Hold:", 0.0, 10.0, 0.1)
		_mk_row(dc, "Fade Out:", 0.0, 10.0, 0.1)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── FollowTarget ──────────────────────────────────────────────────────
	elif node_kind == "FollowTarget":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		_mk_row(dc, "Group ID:", 0, 9999, 1)
		_mk_row(dc, "Target Group:", 0, 9999, 1)
		_mk_row(dc, "X Speed:", 0.0, 999.0, 0.1)
		_mk_row(dc, "Y Speed:", 0.0, 999.0, 0.1)
		_mk_row(dc, "Max Speed:", 0.0, 999.0, 0.1)
		var fy_r := HBoxContainer.new(); var fy_l := Label.new(); fy_l.text = "Y Only:"; fy_r.add_child(fy_l)
		var fy_c := CheckButton.new(); fy_r.add_child(fy_c); dc.add_child(fy_r)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── CameraControl ─────────────────────────────────────────────────────
	elif node_kind == "CameraControl":
		var il := Label.new(); il.text = "▶ exec in";  il.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(il)
		var ol := Label.new(); ol.text = "▶ exec out"; ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var cam_t := OptionButton.new()
		for s in ["Zoom","Pan X","Pan Y","Offset X","Offset Y","Static","Free Mode","Reset"]: cam_t.add_item(s)
		dc.add_child(cam_t)
		_mk_row(dc, "Value:", -9999, 9999, 0.1)
		_mk_row(dc, "Duration (s):", 0.0, 99.0, 0.1)
		var cam_e := OptionButton.new()
		for s in ["None","Ease In","Ease Out","Ease In/Out"]: cam_e.add_item(s)
		dc.add_child(cam_e)
		node.set_slot(0, true, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)

	# ── TimedEvent ────────────────────────────────────────────────────────
	elif node_kind == "TimedEvent":
		var ol := Label.new(); ol.text = "▶ exec out";  ol.add_theme_color_override("font_color", COLOR_EXEC); dc.add_child(ol)
		var rl := Label.new(); rl.text = "↺ on repeat"; rl.add_theme_color_override("font_color", COLOR_INT);  dc.add_child(rl)
		_mk_row(dc, "Delay (s):", 0.0, 999.0, 0.1)
		_mk_row(dc, "Duration (s):", 0.0, 999.0, 0.1)
		_mk_row(dc, "Interval (s):", 0.0, 999.0, 0.1)
		var te_lp_r := HBoxContainer.new(); var te_lp_l := Label.new(); te_lp_l.text = "Loop:"; te_lp_r.add_child(te_lp_l)
		var te_lp_c := CheckButton.new(); te_lp_r.add_child(te_lp_c); dc.add_child(te_lp_r)
		var te_tu_r := HBoxContainer.new(); var te_tu_l := Label.new(); te_tu_l.text = "Time Unit:"; te_tu_r.add_child(te_tu_l)
		var te_tu_o := OptionButton.new()
		for s in ["Seconds","BPM Beats","Frames"]: te_tu_o.add_item(s)
		te_tu_r.add_child(te_tu_o); dc.add_child(te_tu_r)
		node.set_slot(0, false, PORT_EXEC, COLOR_EXEC, true, PORT_EXEC, COLOR_EXEC)
		node.set_slot(1, false, PORT_EXEC, COLOR_EXEC, true, PORT_INT, COLOR_INT)

	# ── Feature 10: collapsible body ──────────────────────────────────────
	var collapsible := VBoxContainer.new()
	for ch in body.get_children():
		if ch != header_row:
			body.remove_child(ch)
			collapsible.add_child(ch)
	body.add_child(collapsible)
	btn_collapse.pressed.connect(func():
		collapsible.visible = not collapsible.visible
		btn_collapse.text = "▼" if not collapsible.visible else "▲"
	)

	_fallback_graph.add_child(node)
	node.position_offset = at_pos if (at_pos.x >= 0 and at_pos.y >= 0) else \
		Vector2(140 + float(_fallback_next_id) * 60, 140 + float(_fallback_next_id) * 40)
	_fallback_node_meta[node.name] = node_kind

	# Undo support
	if _fallback_undo_redo != null:
		var nname := node.name
		_fallback_undo_redo.create_action("Add " + node_kind)
		_fallback_undo_redo.add_do_method(func(): pass)
		_fallback_undo_redo.add_undo_method(func():
			var nd: Node = _fallback_graph.get_node_or_null(NodePath(nname))
			if nd: nd.queue_free()
			_fallback_node_meta.erase(nname)
			_fallback_update_node_count()
		)
		_fallback_undo_redo.commit_action(false)

	_fallback_next_id += 1
	_fallback_set_status("Added %s node." % node_kind)
	return node

# ── Add node handlers ─────────────────────────────────────────────────────────
func _on_fallback_add_event()            -> void: _fallback_add_node("Event");            _fallback_update_node_count()
func _on_fallback_add_action()           -> void: _fallback_add_node("Action");           _fallback_update_node_count()
func _on_fallback_add_math()             -> void: _fallback_add_node("Math");             _fallback_update_node_count()
func _on_fallback_add_condition()        -> void: _fallback_add_node("Condition");        _fallback_update_node_count()
func _on_fallback_add_variable()         -> void: _fallback_add_node("Variable");         _fallback_update_node_count()
func _on_fallback_add_note()             -> void: _fallback_add_node("Note");             _fallback_update_node_count()
func _on_fallback_add_group()            -> void: _fallback_add_node("Group");            _fallback_update_node_count()
func _on_fallback_add_loop()             -> void: _fallback_add_node("Loop");             _fallback_update_node_count()
func _on_fallback_add_sequence()         -> void: _fallback_add_node("Sequence");         _fallback_update_node_count()
func _on_fallback_add_function()         -> void: _fallback_add_node("Function");         _fallback_update_node_count()
# Blender utility nodes
func _on_fallback_add_vectormath()       -> void: _fallback_add_node("VectorMath");       _fallback_update_node_count()
func _on_fallback_add_maprange()         -> void: _fallback_add_node("MapRange");         _fallback_update_node_count()
func _on_fallback_add_boolmath()         -> void: _fallback_add_node("BoolMath");         _fallback_update_node_count()
func _on_fallback_add_switch()           -> void: _fallback_add_node("Switch");           _fallback_update_node_count()
func _on_fallback_add_compare()          -> void: _fallback_add_node("Compare");          _fallback_update_node_count()
func _on_fallback_add_randomvalue()      -> void: _fallback_add_node("RandomValue");      _fallback_update_node_count()
# Geometry Dash trigger nodes
func _on_fallback_add_trigger()          -> void: _fallback_add_node("Trigger");          _fallback_update_node_count()
func _on_fallback_add_colorchannel()     -> void: _fallback_add_node("ColorChannel");     _fallback_update_node_count()
func _on_fallback_add_movegroup()        -> void: _fallback_add_node("MoveGroup");        _fallback_update_node_count()
func _on_fallback_add_rotategroup()      -> void: _fallback_add_node("RotateGroup");      _fallback_update_node_count()
func _on_fallback_add_spawntrigger()     -> void: _fallback_add_node("SpawnTrigger");     _fallback_update_node_count()
func _on_fallback_add_alphafade()        -> void: _fallback_add_node("AlphaFade");        _fallback_update_node_count()
func _on_fallback_add_togglegroup()      -> void: _fallback_add_node("ToggleGroup");      _fallback_update_node_count()
func _on_fallback_add_collisiontrigger() -> void: _fallback_add_node("CollisionTrigger"); _fallback_update_node_count()
func _on_fallback_add_counteritem()      -> void: _fallback_add_node("CounterItem");      _fallback_update_node_count()
func _on_fallback_add_pulseeffect()      -> void: _fallback_add_node("PulseEffect");      _fallback_update_node_count()
func _on_fallback_add_followtarget()     -> void: _fallback_add_node("FollowTarget");     _fallback_update_node_count()
func _on_fallback_add_cameracontrol()    -> void: _fallback_add_node("CameraControl");    _fallback_update_node_count()
func _on_fallback_add_timedevent()       -> void: _fallback_add_node("TimedEvent");       _fallback_update_node_count()

func _on_fallback_try_full_editor(host: Control) -> void:
	_fallback_set_status("Trying full editor...")
	if _try_mount_full_editor(host):
		_fallback_set_status("Full editor loaded.")

