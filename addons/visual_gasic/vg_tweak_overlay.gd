@tool
extends Control

# Universal Tweak Overlay v2 — works on any VisualGasic project.
#
# Architecture:
#   - Discovers targets via VGTweakAdapters (Control, Node2D, Sprite2D,
#     Label/TextEdit, VectorCanvasGroup, anything with get_tweak_adapters()).
#   - Renders a draggable left-side control panel + right-side property
#     inspector built from each target's schema.
#   - Pauses/resumes the game on demand without breaking its own input.
#   - Persists overrides to res://.vg_tweaks.json + user://vg_tweaks.json.
#   - Routes "Edit with AI" requests up to VGTweakSystem.
#   - Provides object-swap dialog backed by VGTweakSwapRegistry.

signal overlay_closed()
signal ai_edit_requested(request: Dictionary)

const Adapters = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_adapters.gd")
const Inspector = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_inspector.gd")
const Persistence = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_persistence.gd")
const SourcePatcher = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_source.gd")
const SwapRegistry = preload("res://addons/visual_gasic/vg_tweak/vg_tweak_swap_registry.gd")

var _targets: Array = []
var _selected_id: String = ""
# Multi-selection: ordered ids; primary = last (drives inspector).
var _selection: Array = []
var _overrides: Dictionary = {}
# Pinned per-command adapters keyed by their id. Survive _rescan() so the
# selection doesn't get clobbered ~0.25s after picking an individual shape.
# Value is the adapter instance; we re-append it after each tree rescan as
# long as its underlying canvas is still valid.
var _pinned_cmd_adapters: Dictionary = {}

var _control_panel: PanelContainer
var _inspector_panel: PanelContainer
var _inspector: VBoxContainer
var _target_selector: OptionButton
var _status_label: Label
var _pause_btn: Button
var _swap_dialog: AcceptDialog
var _diff_dialog: AcceptDialog

var _overlay_dragging: bool = false
var _overlay_drag_start: Vector2
var _overlay_panel_start: Vector2
var _drag_panel: PanelContainer = null
var _control_body: VBoxContainer
var _inspector_body: VBoxContainer
var _control_min_btn: Button
var _inspector_min_btn: Button
var _target_dragging: bool = false
var _target_drag_start: Vector2
var _target_drag_base: Vector2
# Per-target start positions for group drag/nudge. id -> Vector2.
var _multi_drag_bases: Dictionary = {}
# Rubber-band selection state.
var _rubber_active: bool = false
var _rubber_additive: bool = false
var _rubber_start: Vector2 = Vector2.ZERO
var _rubber_end: Vector2 = Vector2.ZERO
var _tree_dirty: bool = true
var _refresh_timer: float = 0.0
var _was_paused_on_open: bool = false
# Undo: each stack entry is an Array of {id, prop, before}. A batch is opened
# at the start of a drag/nudge/inspector edit and committed when it ends, so
# Ctrl+Z reverts the whole stroke in one step.
var _undo_stack: Array = []
var _redo_stack: Array = []
var _undo_open: bool = false
var _undo_batch: Array = []
var _undo_seen: Dictionary = {}  # "id|prop" -> true (already captured this batch)
const UNDO_LIMIT := 64
# Clipboard for the right-click context menu. Holds the last copied per-prop
# values keyed by property name (e.g. {"color": Color(...)}).
var _clipboard: Dictionary = {}
var _ctx_menu: PopupMenu = null
# Snap-to-grid: when on, drag deltas and nudges are rounded to a multiple
# of _snap_grid (in canvas pixels). The grid itself is rendered faintly.
var _snap_enabled: bool = false
var _snap_grid: float = 8.0
var _snap_btn: CheckButton = null
var _snap_spin: SpinBox = null
# Multi-canvas filter: when more than one VectorCanvas exists, the user can
# restrict targets to a single canvas. Empty string = no filter.
var _canvas_filter: String = ""
var _canvas_filter_btn: OptionButton = null
var _place_kind: String = ""
var _palette_buttons: Dictionary = {}
var _palette_row: HBoxContainer = null
const REFRESH_INTERVAL := 0.25

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	grab_focus()
	_build_ui()
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	_rescan()
	_load_persisted()
	# Auto-pause the running game when the overlay engages so the user can
	# inspect/adjust without dodging moving targets. We remember the prior
	# pause state and restore it on close.
	_was_paused_on_open = get_tree().paused
	get_tree().paused = true
	if _pause_btn != null:
		_pause_btn.button_pressed = true
		_pause_btn.text = "Resume"
	set_process(true)
	queue_redraw()

func _exit_tree() -> void:
	if get_tree():
		if get_tree().node_added.is_connected(_on_tree_changed):
			get_tree().node_added.disconnect(_on_tree_changed)
		if get_tree().node_removed.is_connected(_on_tree_changed):
			get_tree().node_removed.disconnect(_on_tree_changed)
		# Restore the pre-overlay pause state.
		get_tree().paused = _was_paused_on_open

func _on_tree_changed(_n: Node) -> void:
	_tree_dirty = true

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	if _tree_dirty:
		_tree_dirty = false
		_rescan()
	else:
		_refresh_rects()
	if _inspector:
		_inspector.refresh_values()
	queue_redraw()

# ----------------- UI -----------------

func _build_ui() -> void:
	_control_panel = _make_panel(Vector2(12, 12), Vector2(320, 0))
	add_child(_control_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_control_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_input.bind(_control_panel))
	var title := Label.new()
	title.text = "Tweak Overlay"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_control_min_btn = Button.new()
	_control_min_btn.text = "–"
	_control_min_btn.tooltip_text = "Collapse/expand panel"
	_control_min_btn.custom_minimum_size = Vector2(24, 0)
	_control_min_btn.pressed.connect(_toggle_control_minimized)
	header.add_child(_control_min_btn)
	vbox.add_child(header)

	_control_body = VBoxContainer.new()
	_control_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_control_body)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	_control_body.add_child(actions)
	_pause_btn = _btn("Pause", "_on_pause_toggled")
	_pause_btn.toggle_mode = true
	actions.add_child(_pause_btn)
	actions.add_child(_btn("Refresh", "_on_refresh"))
	actions.add_child(_btn("Save", "_on_save"))
	actions.add_child(_btn("Save Sel", "_on_save_selected"))
	actions.add_child(_btn("→ Source", "_on_save_to_source"))
	actions.add_child(_btn("Reset", "_on_reset_target"))
	actions.add_child(_btn("Close", "_on_close"))

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 6)
	_control_body.add_child(selector_row)
	var sl := Label.new()
	sl.text = "Target:"
	selector_row.add_child(sl)
	_target_selector = OptionButton.new()
	_target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_selector.item_selected.connect(_on_target_selected)
	selector_row.add_child(_target_selector)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 36)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_control_body.add_child(_status_label)

	# Snap + canvas-filter row.
	var snap_row := HBoxContainer.new()
	snap_row.add_theme_constant_override("separation", 6)
	_control_body.add_child(snap_row)
	_snap_btn = CheckButton.new()
	_snap_btn.text = "Snap"
	_snap_btn.tooltip_text = "Round drag/nudge to grid"
	_snap_btn.toggled.connect(func(p):
		_snap_enabled = p
		queue_redraw()
	)
	snap_row.add_child(_snap_btn)
	_snap_spin = SpinBox.new()
	_snap_spin.min_value = 1
	_snap_spin.max_value = 256
	_snap_spin.step = 1
	_snap_spin.value = _snap_grid
	_snap_spin.custom_minimum_size = Vector2(70, 0)
	_snap_spin.value_changed.connect(func(v):
		_snap_grid = max(1.0, float(v))
		queue_redraw()
	)
	snap_row.add_child(_snap_spin)
	var cfl := Label.new()
	cfl.text = "Canvas:"
	snap_row.add_child(cfl)
	_canvas_filter_btn = OptionButton.new()
	_canvas_filter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_filter_btn.item_selected.connect(_on_canvas_filter_selected)
	snap_row.add_child(_canvas_filter_btn)

	# Palette row — click a kind to enter "place mode", then click the canvas.
	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 4)
	_control_body.add_child(_palette_row)
	var pl := Label.new()
	pl.text = "Place:"
	_palette_row.add_child(pl)
	for kind in ["rect", "ellipse", "line", "text"]:
		var b := Button.new()
		b.text = kind.capitalize()
		b.toggle_mode = true
		b.tooltip_text = "Toggle place-%s mode, then click on a canvas" % kind
		var cap: String = kind
		b.toggled.connect(func(p): _on_palette_toggled(cap, p))
		_palette_row.add_child(b)
		_palette_buttons[kind] = b

	var vp_size := get_viewport_rect().size
	_inspector_panel = _make_panel(Vector2(vp_size.x - 352, 12), Vector2(340, 0))
	add_child(_inspector_panel)
	var insp_vbox := VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 6)
	_inspector_panel.add_child(insp_vbox)
	var insp_header := HBoxContainer.new()
	insp_header.mouse_filter = Control.MOUSE_FILTER_STOP
	insp_header.gui_input.connect(_on_header_input.bind(_inspector_panel))
	var insp_title := Label.new()
	insp_title.text = "Inspector"
	insp_title.add_theme_font_size_override("font_size", 14)
	insp_title.add_theme_color_override("font_color", Color(1, 1, 1))
	insp_header.add_child(insp_title)
	var insp_spacer := Control.new()
	insp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_header.add_child(insp_spacer)
	_inspector_min_btn = Button.new()
	_inspector_min_btn.text = "–"
	_inspector_min_btn.tooltip_text = "Collapse/expand inspector"
	_inspector_min_btn.custom_minimum_size = Vector2(24, 0)
	_inspector_min_btn.pressed.connect(_toggle_inspector_minimized)
	insp_header.add_child(_inspector_min_btn)
	insp_vbox.add_child(insp_header)

	_inspector_body = VBoxContainer.new()
	_inspector_body.add_theme_constant_override("separation", 6)
	insp_vbox.add_child(_inspector_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(320, 280)
	_inspector_body.add_child(scroll)
	_inspector = Inspector.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)
	_inspector.property_changed.connect(_on_property_changed)
	_inspector.request_source_edit.connect(_on_request_source_edit)
	_inspector.request_ai_edit.connect(_on_request_ai_edit)
	_inspector.request_swap.connect(_on_request_swap)

func _toggle_control_minimized() -> void:
	if _control_body == null:
		return
	_control_body.visible = not _control_body.visible
	_control_min_btn.text = "–" if _control_body.visible else "+"
	# Let the panel shrink to its header when collapsed.
	_control_panel.reset_size()

func _toggle_inspector_minimized() -> void:
	if _inspector_body == null:
		return
	_inspector_body.visible = not _inspector_body.visible
	_inspector_min_btn.text = "–" if _inspector_body.visible else "+"
	_inspector_panel.reset_size()

func _make_panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.78)
	st.border_color = Color(1, 1, 1, 0.25)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", st)
	return p

func _btn(text: String, handler: String) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(Callable(self, handler))
	return b

# ----------------- Discovery -----------------

func _rescan() -> void:
	_targets = Adapters.collect_from_tree(get_tree().get_root(), self)
	_filter_visible()
	# Re-attach any pinned per-command adapters whose canvas is still alive.
	var stale: Array = []
	for pid in _pinned_cmd_adapters.keys():
		var adp = _pinned_cmd_adapters[pid]
		var canvas = adp.owner_node if adp != null else null
		if canvas == null or not is_instance_valid(canvas):
			stale.append(pid)
			continue
		var already := false
		for t in _targets:
			if t.id == pid:
				already = true
				break
		if not already:
			_targets.append(adp)
	for pid in stale:
		_pinned_cmd_adapters.erase(pid)
		if _selected_id == pid:
			_selected_id = ""
	_targets.sort_custom(func(a, b): return a.label < b.label)
	_apply_canvas_filter()
	_rebuild_canvas_filter_options()
	_update_palette_visibility()
	_populate_selector()
	_reapply_overrides()
	_update_status()

func _rebuild_canvas_filter_options() -> void:
	if _canvas_filter_btn == null:
		return
	# Collect unique VectorCanvas paths from targets owned by a canvas.
	var paths: Array = []
	for t in _targets:
		var owner = t.owner_node
		if owner == null or not is_instance_valid(owner):
			continue
		if owner.get_class() != "Node2D" and not (owner.has_method("get_command_target")):
			continue
		var pth := str(owner.get_path())
		if not paths.has(pth):
			paths.append(pth)
	_canvas_filter_btn.visible = paths.size() > 1
	_canvas_filter_btn.clear()
	_canvas_filter_btn.add_item("(all)")
	_canvas_filter_btn.set_item_metadata(0, "")
	var sel_idx := 0
	for i in range(paths.size()):
		_canvas_filter_btn.add_item(paths[i].get_file() if paths[i] != "" else "?")
		_canvas_filter_btn.set_item_metadata(i + 1, paths[i])
		if paths[i] == _canvas_filter:
			sel_idx = i + 1
	if sel_idx >= _canvas_filter_btn.get_item_count():
		sel_idx = 0
		_canvas_filter = ""
	_canvas_filter_btn.select(sel_idx)

func _apply_canvas_filter() -> void:
	if _canvas_filter == "":
		return
	var kept: Array = []
	for t in _targets:
		var owner = t.owner_node
		if owner != null and is_instance_valid(owner) and owner.has_method("get_command_target"):
			if str(owner.get_path()) != _canvas_filter:
				continue
		kept.append(t)
	_targets = kept

func _on_canvas_filter_selected(idx: int) -> void:
	if _canvas_filter_btn == null:
		return
	_canvas_filter = str(_canvas_filter_btn.get_item_metadata(idx))
	_rescan()

func _refresh_rects() -> void:
	_filter_visible()
	_populate_selector()
	_update_status()

func _filter_visible() -> void:
	var vp := get_viewport_rect()
	var keep: Array = []
	for t in _targets:
		var r: Rect2 = t.get_rect()
		if r.size == Vector2.ZERO and vp.has_point(r.position):
			keep.append(t)
		elif r.intersects(vp):
			keep.append(t)
	_targets = keep

func _populate_selector() -> void:
	if _target_selector == null:
		return
	_target_selector.clear()
	var sel_idx := -1
	for i in range(_targets.size()):
		var t = _targets[i]
		_target_selector.add_item("%s  [%s]" % [t.label, t.kind])
		_target_selector.set_item_metadata(i, t.id)
		if t.id == _selected_id:
			sel_idx = i
	if sel_idx >= 0:
		_target_selector.select(sel_idx)
	elif _targets.size() > 0:
		_target_selector.select(0)
		_selected_id = _targets[0].id
		_selection = [_selected_id]
		if _inspector:
			_inspector.set_target(_targets[0])

func _update_status() -> void:
	if _status_label == null:
		return
	var pause_state = "PAUSED" if get_tree().paused else "running"
	var sel_part := ""
	if _selection.size() > 0:
		sel_part = " · %d selected" % _selection.size()
	var undo_part := ""
	if _undo_stack.size() > 0 or _redo_stack.size() > 0:
		undo_part = " · undo %d/redo %d" % [_undo_stack.size(), _redo_stack.size()]
	var filter_part := ""
	if _canvas_filter != "":
		filter_part = " · canvas: %s" % _canvas_filter.get_file()
	var place_part := ""
	if _place_kind != "":
		place_part = " · place: %s (Esc to cancel)" % _place_kind
	_status_label.text = "%d targets — %s%s%s%s%s. LMB pick, Shift+LMB toggle, drag empty=box, RMB menu, Ctrl+Z/Y undo/redo, Esc clear, Ctrl+Shift+T close." % [
		_targets.size(), pause_state, sel_part, undo_part, filter_part, place_part
	]

# ----------------- Input -----------------

func _on_header_input(event: InputEvent, panel: PanelContainer = null) -> void:
	var target_panel: PanelContainer = panel if panel != null else _control_panel
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_overlay_dragging = event.pressed
		if event.pressed:
			_drag_panel = target_panel
			_overlay_drag_start = get_viewport().get_mouse_position()
			_overlay_panel_start = target_panel.position
		else:
			_drag_panel = null
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _overlay_dragging and _drag_panel != null:
		var mp = get_viewport().get_mouse_position()
		_drag_panel.position = _overlay_panel_start + (mp - _overlay_drag_start)
		_clamp_panel(_drag_panel)
		get_viewport().set_input_as_handled()

func _clamp_panel(panel: PanelContainer) -> void:
	var vp = get_viewport_rect().size
	var sz = panel.get_size()
	panel.position.x = clamp(panel.position.x, 0, max(0, vp.x - sz.x))
	panel.position.y = clamp(panel.position.y, 0, max(0, vp.y - sz.y))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and event.ctrl_pressed and event.shift_pressed:
			_on_close()
			return
		if event.keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
			_undo_pop()
			get_viewport().set_input_as_handled()
			return
		if (event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed) \
				or (event.keycode == KEY_Y and event.ctrl_pressed):
			_redo_pop()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_D and event.ctrl_pressed:
			_duplicate_selected()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE:
			_delete_selected_runtime()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _place_kind != "":
				var b: Button = _palette_buttons.get(_place_kind, null)
				if b != null:
					b.set_pressed_no_signal(false)
				_place_kind = ""
				_update_status()
				get_viewport().set_input_as_handled()
				return
			if _rubber_active:
				_rubber_active = false
				queue_redraw()
			elif _selection.size() > 0:
				_clear_selection()
				_update_status()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			_cycle_selection(1 if not event.shift_pressed else -1)
			get_viewport().set_input_as_handled()
			return
		if _selected_id != "":
			var step = 10 if event.shift_pressed else 1
			var dlt = Vector2.ZERO
			match event.keycode:
				KEY_UP: dlt.y = -step
				KEY_DOWN: dlt.y = step
				KEY_LEFT: dlt.x = -step
				KEY_RIGHT: dlt.x = step
			if dlt != Vector2.ZERO:
				_nudge_selected(dlt)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_over_ui(event.position):
			return
		# Pick under the cursor (non-additive) before showing the menu, unless
		# we already have a multi-selection containing this point. Alt picks
		# the individual draw command instead of its enclosing group.
		var hit_id := _pick_at(event.position, false, event.alt_pressed)
		if hit_id == "" and _selection.is_empty():
			return
		_show_context_menu(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_over_ui(event.position):
				return
			if _place_kind != "":
				_place_at(event.position)
				get_viewport().set_input_as_handled()
				return
			var additive: bool = event.shift_pressed
			# Alt+click bypasses group-promotion to select one draw command.
			var hit_id := _pick_at(event.position, additive, event.alt_pressed)
			if hit_id != "":
				if not additive:
					_start_group_drag(event.position)
			else:
				# Empty space → begin rubber-band selection.
				if not additive:
					_clear_selection()
				_rubber_active = true
				_rubber_additive = additive
				_rubber_start = event.position
				_rubber_end = event.position
				queue_redraw()
			get_viewport().set_input_as_handled()
		else:
			if _rubber_active:
				_rubber_end = event.position
				_finalize_rubber()
				_rubber_active = false
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif _target_dragging:
				_target_dragging = false
				_undo_commit()
				get_viewport().set_input_as_handled()
			else:
				_target_dragging = false
		return
	if event is InputEventMouseMotion:
		if _rubber_active:
			_rubber_end = event.position
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _target_dragging:
			_drag_to(event.position)
			get_viewport().set_input_as_handled()

func _is_over_ui(pos: Vector2) -> bool:
	if _control_panel and _control_panel.get_global_rect().has_point(pos):
		return true
	if _inspector_panel and _inspector_panel.get_global_rect().has_point(pos):
		return true
	if _swap_dialog and _swap_dialog.visible:
		return true
	if _diff_dialog and _diff_dialog.visible:
		return true
	return false

func _pick_at(pos: Vector2, additive: bool = false, pick_individual: bool = false) -> String:
	# Per-command pick first: walk all VectorCanvas nodes in the tree, ask each
	# whether any draw command's geometry contains the click point, and pick
	# the topmost hit (highest z_index → latest command). This lets the user
	# select individual shapes without wrapping every one in BeginGroup.
	# Returns the id that was hit (or "" if nothing). When additive is true,
	# toggles the id in the selection instead of replacing. When the picked
	# command belongs to a non-empty BeginGroup, promote the selection to the
	# group target so dragging moves every sibling command together (no ghost
	# from un-translated siblings). pick_individual=true (Alt+click) bypasses
	# the promotion to address one draw command directly.
	var state: Dictionary = {"canvas": null, "cmd": {}, "z": -2147483648}
	_collect_command_hit_impl(get_tree().get_root(), pos, state)
	var best_canvas: Node = state.get("canvas")
	var best_cmd: Dictionary = state.get("cmd", {})
	if best_canvas != null and not best_cmd.is_empty():
		var sid: String = str(best_cmd.get("__stable_id", ""))
		var grp: String = str(best_cmd.get("group", ""))
		if not pick_individual and grp != "":
			var group_id := "vg:%s:%s" % [str(best_canvas.get_path()), grp]
			for t in _targets:
				if t.id == group_id:
					if additive:
						_toggle_in_selection(group_id)
					elif not _selection.has(group_id):
						_set_selection_single(group_id)
					else:
						_set_primary(group_id)
					return group_id
		if sid != "":
			var entry: Dictionary = best_canvas.get_command_target(sid)
			if not entry.is_empty():
				var adapter = Adapters.LegacyCanvasAdapter.new(best_canvas, entry)
				_pinned_cmd_adapters[adapter.id] = adapter
				var existing_idx := -1
				for i in range(_targets.size()):
					if _targets[i].id == adapter.id:
						existing_idx = i
						break
				if existing_idx < 0:
					_targets.append(adapter)
					_populate_selector()
				if additive:
					_toggle_in_selection(adapter.id)
				else:
					if not _selection.has(adapter.id):
						_set_selection_single(adapter.id)
					else:
						# Keep current multi-selection so user can drag the group.
						_set_primary(adapter.id)
				return adapter.id
	# Fallback: classic bbox pick across existing targets.
	var best = null
	var best_area := INF
	for t in _targets:
		var r: Rect2 = t.get_rect()
		if not r.has_point(pos):
			continue
		var area = max(1.0, r.size.x * r.size.y)
		if area < best_area:
			best = t
			best_area = area
	if best:
		if additive:
			_toggle_in_selection(best.id)
		else:
			if not _selection.has(best.id):
				_set_selection_single(best.id)
			else:
				_set_primary(best.id)
		return best.id
	return ""

func _set_selection_single(id: String) -> void:
	_selection = [id]
	_selected_id = id
	_sync_inspector_to_primary()
	_update_status()
	queue_redraw()

func _set_primary(id: String) -> void:
	if not _selection.has(id):
		_selection.append(id)
	_selected_id = id
	_sync_inspector_to_primary()
	queue_redraw()

func _toggle_in_selection(id: String) -> void:
	if _selection.has(id):
		_selection.erase(id)
		if _selected_id == id:
			_selected_id = _selection[-1] if _selection.size() > 0 else ""
	else:
		_selection.append(id)
		_selected_id = id
	_sync_inspector_to_primary()
	_update_status()
	queue_redraw()

func _clear_selection() -> void:
	_selection.clear()
	_selected_id = ""
	if _inspector:
		_inspector.set_target(null)
	queue_redraw()

func _sync_inspector_to_primary() -> void:
	if _target_selector:
		for i in range(_targets.size()):
			if _targets[i].id == _selected_id:
				_target_selector.select(i)
				break
	if _inspector:
		var t = _selected_target()
		_inspector.set_target(t)

func _finalize_rubber() -> void:
	var rect := Rect2(_rubber_start, Vector2.ZERO).expand(_rubber_end).abs()
	if rect.size.x < 2.0 and rect.size.y < 2.0:
		return
	if not _rubber_additive:
		_selection.clear()
		_selected_id = ""
	# Walk canvases and collect every command whose bbox intersects the rect.
	var hits: Array = []
	_collect_commands_in_rect_impl(get_tree().get_root(), rect, hits)
	for h in hits:
		var canvas: Node = h["canvas"]
		var sid: String = h["sid"]
		var entry: Dictionary = canvas.get_command_target(sid)
		if entry.is_empty():
			continue
		var adapter = Adapters.LegacyCanvasAdapter.new(canvas, entry)
		_pinned_cmd_adapters[adapter.id] = adapter
		var have := false
		for t in _targets:
			if t.id == adapter.id:
				have = true
				break
		if not have:
			_targets.append(adapter)
		if not _selection.has(adapter.id):
			_selection.append(adapter.id)
	# Also include any pre-existing bbox targets fully under the rubber rect.
	for t in _targets:
		if str(t.id).begins_with("vg:") and str(t.id).find(":cmd:") >= 0:
			continue
		var r: Rect2 = t.get_rect()
		if r.size == Vector2.ZERO:
			continue
		if rect.encloses(r) or rect.intersects(r):
			if not _selection.has(t.id):
				_selection.append(t.id)
	if _selection.size() > 0:
		_selected_id = _selection[-1]
	_populate_selector()
	_sync_inspector_to_primary()
	queue_redraw()

func _collect_commands_in_rect_impl(node: Node, screen_rect: Rect2, out: Array) -> void:
	if node == null:
		return
	if node.has_method("find_commands_in_rect") and node is CanvasItem:
		var inv := (node as CanvasItem).get_global_transform().affine_inverse()
		# Transform rect corners into local space; use AABB of the result.
		var p0 := inv * screen_rect.position
		var p1 := inv * (screen_rect.position + Vector2(screen_rect.size.x, 0))
		var p2 := inv * (screen_rect.position + screen_rect.size)
		var p3 := inv * (screen_rect.position + Vector2(0, screen_rect.size.y))
		var lr := Rect2(p0, Vector2.ZERO).expand(p1).expand(p2).expand(p3)
		var sids: Array = node.find_commands_in_rect(lr)
		for sid in sids:
			out.append({"canvas": node, "sid": sid})
	for child in node.get_children():
		_collect_commands_in_rect_impl(child, screen_rect, out)

func _collect_command_hit_impl(node: Node, pos: Vector2, state: Dictionary) -> void:
	if node == null:
		return
	if node.has_method("pick_command_at"):
		var local: Vector2 = pos
		if node is CanvasItem:
			local = (node as CanvasItem).get_global_transform().affine_inverse() * pos
		var hit: Dictionary = node.pick_command_at(local, 4.0)
		if not hit.is_empty():
			var z: int = 0
			if node is CanvasItem:
				z = (node as CanvasItem).z_index
			if z >= int(state.get("z", -2147483648)):
				state["canvas"] = node
				state["cmd"] = hit
				state["z"] = z
	for child in node.get_children():
		_collect_command_hit_impl(child, pos, state)

func _select(id: String) -> void:
	_selection = [id]
	_selected_id = id
	for i in range(_targets.size()):
		if _targets[i].id == id:
			if _target_selector:
				_target_selector.select(i)
			if _inspector:
				_inspector.set_target(_targets[i])
			break
	queue_redraw()

func _cycle_selection(step: int) -> void:
	if _targets.is_empty():
		return
	var idx := 0
	for i in range(_targets.size()):
		if _targets[i].id == _selected_id:
			idx = i
			break
	idx = (idx + step) % _targets.size()
	if idx < 0:
		idx += _targets.size()
	_select(_targets[idx].id)

# ----------------- Mutations -----------------

func _selected_target():
	for t in _targets:
		if t.id == _selected_id:
			return t
	return null

func _selected_targets() -> Array:
	var out: Array = []
	for id in _selection:
		for t in _targets:
			if t.id == id:
				out.append(t)
				break
	return out

func _pos_prop_for(t) -> String:
	var schema: Dictionary = t.get_schema()
	if schema.has("position"):
		return "position"
	if schema.has("translate"):
		return "translate"
	return ""

func _start_group_drag(pos: Vector2) -> void:
	_multi_drag_bases.clear()
	for t in _selected_targets():
		var prop := _pos_prop_for(t)
		if prop == "":
			continue
		var v = t.get_value(prop)
		_multi_drag_bases[t.id] = v if typeof(v) == TYPE_VECTOR2 else Vector2.ZERO
	if _multi_drag_bases.is_empty():
		_target_dragging = false
		return
	_target_dragging = true
	_target_drag_start = pos
	_undo_begin()

func _start_drag(pos: Vector2) -> void:
	_start_group_drag(pos)

func _drag_to(pos: Vector2) -> void:
	var delta := pos - _target_drag_start
	if _snap_enabled:
		delta = Vector2(snappedf(delta.x, _snap_grid), snappedf(delta.y, _snap_grid))
	for t in _selected_targets():
		var prop := _pos_prop_for(t)
		if prop == "":
			continue
		var base: Vector2 = _multi_drag_bases.get(t.id, Vector2.ZERO)
		_apply_value(t, prop, base + delta)
	queue_redraw()

func _nudge_selected(delta: Vector2) -> void:
	if _snap_enabled:
		var step := _snap_grid
		delta = Vector2(sign(delta.x) * step if delta.x != 0 else 0.0, sign(delta.y) * step if delta.y != 0 else 0.0)
	_undo_begin()
	for t in _selected_targets():
		var prop := _pos_prop_for(t)
		if prop == "":
			continue
		var current = t.get_value(prop)
		var base: Vector2 = current if typeof(current) == TYPE_VECTOR2 else Vector2.ZERO
		var new_val := base + delta
		if _snap_enabled:
			new_val = Vector2(snappedf(new_val.x, _snap_grid), snappedf(new_val.y, _snap_grid))
		_apply_value(t, prop, new_val)
	_undo_commit()

func _apply_value(t, prop: String, value: Variant) -> void:
	# Capture the before-value for undo (once per (target, prop) per batch).
	if _undo_open:
		var key := "%s|%s" % [t.id, prop]
		if not _undo_seen.has(key):
			var before = t.get_value(prop)
			_undo_batch.append({"id": t.id, "prop": prop, "before": before})
			_undo_seen[key] = true
	if t.set_value(prop, value):
		var entry: Dictionary = _overrides.get(t.id, {})
		entry[prop] = value
		_overrides[t.id] = entry
		if _inspector and t.id == _selected_id:
			_inspector.refresh_values()
		queue_redraw()

func _undo_begin() -> void:
	if _undo_open:
		return
	_undo_open = true
	_undo_batch = []
	_undo_seen = {}

func _undo_commit() -> void:
	if not _undo_open:
		return
	_undo_open = false
	if _undo_batch.is_empty():
		return
	_undo_stack.append(_undo_batch)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	# Any fresh edit invalidates the redo timeline.
	_redo_stack.clear()
	_undo_batch = []
	_undo_seen = {}

func _undo_pop() -> void:
	if _undo_stack.is_empty():
		return
	var batch: Array = _undo_stack.pop_back()
	# Build a redo batch capturing the current (post-edit) values, then revert.
	var redo_batch: Array = []
	for i in range(batch.size() - 1, -1, -1):
		var op: Dictionary = batch[i]
		var t = null
		for cand in _targets:
			if cand.id == op["id"]:
				t = cand
				break
		if t == null:
			continue
		var after = t.get_value(op["prop"])
		redo_batch.append({"id": op["id"], "prop": op["prop"], "before": after})
		if t.set_value(op["prop"], op["before"]):
			var entry: Dictionary = _overrides.get(t.id, {})
			entry[op["prop"]] = op["before"]
			_overrides[t.id] = entry
	if not redo_batch.is_empty():
		_redo_stack.append(redo_batch)
	if _inspector:
		_inspector.refresh_values()
	queue_redraw()
	_update_status()

func _redo_pop() -> void:
	if _redo_stack.is_empty():
		return
	var batch: Array = _redo_stack.pop_back()
	var undo_batch: Array = []
	for i in range(batch.size() - 1, -1, -1):
		var op: Dictionary = batch[i]
		var t = null
		for cand in _targets:
			if cand.id == op["id"]:
				t = cand
				break
		if t == null:
			continue
		var after = t.get_value(op["prop"])
		undo_batch.append({"id": op["id"], "prop": op["prop"], "before": after})
		if t.set_value(op["prop"], op["before"]):
			var entry: Dictionary = _overrides.get(t.id, {})
			entry[op["prop"]] = op["before"]
			_overrides[t.id] = entry
	if not undo_batch.is_empty():
		_undo_stack.append(undo_batch)
	if _inspector:
		_inspector.refresh_values()
	queue_redraw()
	_update_status()

func _reapply_overrides() -> void:
	for tid in _overrides.keys():
		for t in _targets:
			if t.id == tid:
				t.apply(_overrides[tid])
				break

func _on_property_changed(prop: String, value: Variant) -> void:
	# Inspector edits apply to every selected target whose schema has prop.
	_undo_begin()
	var any := false
	for t in _selected_targets():
		var schema: Dictionary = t.get_schema()
		if not schema.has(prop):
			continue
		_apply_value(t, prop, value)
		any = true
	if not any:
		var t = _selected_target()
		if t != null:
			_apply_value(t, prop, value)
	_undo_commit()

# ----------------- Buttons -----------------

func _on_close() -> void:
	emit_signal("overlay_closed")
	queue_free()

func _on_refresh() -> void:
	_tree_dirty = true
	_refresh_timer = 0.0

func _on_pause_toggled() -> void:
	get_tree().paused = _pause_btn.button_pressed
	_pause_btn.text = "Resume" if get_tree().paused else "Pause"
	_update_status()

func _on_save() -> void:
	var bag := _overrides.duplicate(true)
	_merge_runtime_cmds_into(bag)
	Persistence.save_all(bag)
	_status_label.text = "Saved %d overrides." % bag.size()

func _on_save_selected() -> void:
	if _selection.is_empty():
		_status_label.text = "Nothing selected to save."
		return
	# Merge our selected subset into whatever is already on disk so we don't
	# wipe other targets the user has previously persisted.
	var disk: Dictionary = Persistence.load_all()
	var n := 0
	for id in _selection:
		if _overrides.has(id):
			disk[id] = _overrides[id]
			n += 1
	_merge_runtime_cmds_into(disk)
	Persistence.save_all(disk)
	_status_label.text = "Saved %d selected target(s)." % n

# D3 — write tweaks back into the .vg source. For each currently-overridden
# target that carries a source hint, ask VGTweakSource to patch the matching
# literal in the file. Only properties supported by the patcher (today:
# color/fill_color/modulate/self_modulate) are written; the rest stay in the
# JSON bag. The user keeps the runtime tweak whether or not the source
# patch succeeds, so failure is non-destructive.
func _on_save_to_source() -> void:
	var ids: Array = _selection.duplicate() if _selection.size() > 0 else _overrides.keys()
	if ids.is_empty():
		_status_label.text = "→ Source: nothing to write."
		return
	var patched := 0
	var skipped := 0
	var errors: Array[String] = []
	for id in ids:
		var props: Dictionary = _overrides.get(id, {})
		if props.is_empty():
			continue
		var t = null
		for cand in _targets:
			if cand.id == id:
				t = cand
				break
		if t == null or not (t.has_method("get_source_hint")):
			skipped += props.size()
			continue
		for prop in props.keys():
			var hint: Dictionary = t.get_source_hint(prop)
			if hint.is_empty() or hint.get("file", "") == "" or int(hint.get("line", -1)) < 1:
				skipped += 1
				continue
			var res: Dictionary = SourcePatcher.patch_property(hint, prop, props[prop])
			if res.get("ok", false):
				patched += 1
			else:
				skipped += 1
				var err: String = str(res.get("error", "")).strip_edges()
				if err != "" and err != "no change":
					errors.append("%s.%s: %s" % [str(id).get_file(), prop, err])
	var msg := "→ Source: patched %d, skipped %d." % [patched, skipped]
	if not errors.is_empty():
		msg += "  first error: " + errors[0]
	_status_label.text = msg

func _on_reset_target() -> void:
	# Reset every currently-selected target (or the primary if nothing). Uses
	# the canvas's clear_tweak_override so all per-prop overrides go away,
	# not just translate/position.
	_undo_begin()
	var ids: Array = _selection.duplicate() if _selection.size() > 0 else ([_selected_id] if _selected_id != "" else [])
	for id in ids:
		var t = null
		for cand in _targets:
			if cand.id == id:
				t = cand
				break
		if t == null:
			continue
		# Capture before-state for undo: every prop in current overrides.
		var existing: Dictionary = _overrides.get(id, {})
		for prop in existing.keys():
			var key := "%s|%s" % [id, prop]
			if not _undo_seen.has(key):
				_undo_batch.append({"id": id, "prop": prop, "before": existing[prop]})
				_undo_seen[key] = true
		if t.has_method("clear_override"):
			t.clear_override()
		_overrides.erase(id)
	_undo_commit()
	if _inspector:
		_inspector.refresh_values()
	queue_redraw()
	_update_status()

func _on_target_selected(idx: int) -> void:
	_select(str(_target_selector.get_item_metadata(idx)))

func _load_persisted() -> void:
	var data := Persistence.load_all()
	if data.is_empty():
		return
	_overrides = data
	_reapply_overrides()

# ----------------- Source / AI / Swap -----------------

func _on_request_source_edit(prop: String) -> void:
	var t = _selected_target()
	if t == null:
		return
	var hint: Dictionary = t.get_source(prop)
	if hint.is_empty():
		_show_diff("No source hint", "This target's %s has no recorded source location.\nUse 'Edit with AI' instead." % prop)
		return
	var new_value = t.get_value(prop)
	var res: Dictionary = SourcePatcher.patch_literal(hint, new_value)
	if res.get("ok", false):
		_overrides.erase(t.id)
		_show_diff("Patched %s" % hint.get("file", ""), res.get("diff", ""))
	else:
		_show_diff("Patch failed", str(res.get("error", "unknown error")))

func _on_request_ai_edit(_prop: String, _value: Variant) -> void:
	var t = _selected_target()
	if t == null:
		return
	var pending: Dictionary = _overrides.get(t.id, {})
	if pending.is_empty():
		pending = t.snapshot()
	var requests: Array = []
	for prop in pending.keys():
		var hint: Dictionary = t.get_source(prop)
		requests.append(SourcePatcher.build_ai_request(t.label, prop, null, pending[prop], hint.get("file", "")))
	emit_signal("ai_edit_requested", {"target_id": t.id, "label": t.label, "requests": requests})
	_show_diff("AI edit requested", "%d request(s) sent for target '%s'." % [requests.size(), t.label])

func _on_request_swap() -> void:
	var t = _selected_target()
	if t == null or not t.can_swap():
		_show_diff("Not swappable", "This target has no swap options registered.\nCall VGTweakSwapRegistry.register_scene_swap() or .register_recipe_swap() to add some.")
		return
	if _swap_dialog == null:
		_swap_dialog = AcceptDialog.new()
		_swap_dialog.title = "Swap target"
		add_child(_swap_dialog)
	for c in _swap_dialog.get_children():
		if c is VBoxContainer:
			c.queue_free()
	var box := VBoxContainer.new()
	_swap_dialog.add_child(box)
	var hdr := Label.new()
	hdr.text = "Choose a replacement for: %s" % t.label
	box.add_child(hdr)
	var options: Array = t.swap_options()
	if options.is_empty():
		var none := Label.new()
		none.text = "(no swap options registered for this group)"
		box.add_child(none)
	for opt in options:
		var btn := Button.new()
		btn.text = "%s  [%s]" % [opt.get("label", "?"), opt.get("kind", "")]
		var oid: String = str(opt.get("id", ""))
		btn.pressed.connect(func():
			if t.swap_to(oid):
				_swap_dialog.hide()
				_tree_dirty = true
				_refresh_timer = 0.0
		)
		box.add_child(btn)
	_swap_dialog.popup_centered(Vector2i(360, 300))

func _show_diff(title: String, body: String) -> void:
	if _diff_dialog == null:
		_diff_dialog = AcceptDialog.new()
		add_child(_diff_dialog)
	_diff_dialog.title = title
	_diff_dialog.dialog_text = body
	_diff_dialog.popup_centered(Vector2i(560, 320))

# ----------------- Draw -----------------

func _draw() -> void:
	if _snap_enabled and _snap_grid >= 4.0:
		var vp := get_viewport_rect().size
		var col := Color(1, 1, 1, 0.06)
		var x := 0.0
		while x < vp.x:
			draw_line(Vector2(x, 0), Vector2(x, vp.y), col, 1.0)
			x += _snap_grid
		var y := 0.0
		while y < vp.y:
			draw_line(Vector2(0, y), Vector2(vp.x, y), col, 1.0)
			y += _snap_grid
	for t in _targets:
		var r: Rect2 = t.get_rect()
		if r.size == Vector2.ZERO:
			continue
		var fill = Color(0.8, 0.8, 0.2, 0.10)
		var stroke = Color(1, 1, 1, 0.45)
		var thick = 1.5
		var is_primary: bool = t.id == _selected_id
		var is_sel: bool = _selection.has(t.id)
		if is_primary:
			fill = Color(0.2, 0.9, 1.0, 0.30)
			stroke = Color(1, 1, 1, 0.95)
			thick = 3.0
		elif is_sel:
			fill = Color(0.2, 0.9, 1.0, 0.18)
			stroke = Color(0.7, 0.95, 1.0, 0.85)
			thick = 2.0
		draw_rect(r, fill, true)
		draw_rect(r, stroke, false, thick)
	if _rubber_active:
		var rr := Rect2(_rubber_start, Vector2.ZERO).expand(_rubber_end).abs()
		draw_rect(rr, Color(0.3, 0.7, 1.0, 0.15), true)
		draw_rect(rr, Color(0.6, 0.85, 1.0, 0.9), false, 1.0)
	if _target_dragging:
		_draw_alignment_guides()

func _draw_alignment_guides() -> void:
	# When dragging, render thin lines through edges of other targets that
	# share an X or Y axis with any edge/center of the primary selection.
	var primary = _selected_target()
	if primary == null:
		return
	var pr: Rect2 = primary.get_rect()
	if pr.size == Vector2.ZERO:
		return
	const TOL := 4.0
	var sel_ids: Dictionary = {}
	for id in _selection:
		sel_ids[id] = true
	var p_xs := [pr.position.x, pr.position.x + pr.size.x * 0.5, pr.position.x + pr.size.x]
	var p_ys := [pr.position.y, pr.position.y + pr.size.y * 0.5, pr.position.y + pr.size.y]
	var col := Color(1.0, 0.4, 0.9, 0.9)
	var vp := get_viewport_rect().size
	for t in _targets:
		if sel_ids.has(t.id):
			continue
		var r: Rect2 = t.get_rect()
		if r.size == Vector2.ZERO:
			continue
		var t_xs := [r.position.x, r.position.x + r.size.x * 0.5, r.position.x + r.size.x]
		var t_ys := [r.position.y, r.position.y + r.size.y * 0.5, r.position.y + r.size.y]
		for px in p_xs:
			for tx in t_xs:
				if abs(px - tx) <= TOL:
					draw_line(Vector2(tx, 0), Vector2(tx, vp.y), col, 1.0)
		for py in p_ys:
			for ty in t_ys:
				if abs(py - ty) <= TOL:
					draw_line(Vector2(0, ty), Vector2(vp.x, ty), col, 1.0)

# ----------------- Context menu -----------------

const _CTX_RESET := 1
const _CTX_COPY_COLOR := 2
const _CTX_COPY_FILL := 3
const _CTX_COPY_POS := 4
const _CTX_PASTE := 5
const _CTX_EDIT_SRC := 6
const _CTX_DUPLICATE := 7
const _CTX_DELETE := 8

func _show_context_menu(pos: Vector2) -> void:
	if _ctx_menu == null:
		_ctx_menu = PopupMenu.new()
		add_child(_ctx_menu)
		_ctx_menu.id_pressed.connect(_on_ctx_id)
	_ctx_menu.clear()
	var t = _selected_target()
	var schema: Dictionary = t.get_schema() if t != null else {}
	_ctx_menu.add_item("Reset selection", _CTX_RESET)
	_ctx_menu.add_item("Duplicate\tCtrl+D", _CTX_DUPLICATE)
	_ctx_menu.add_item("Delete placed\tDel", _CTX_DELETE)
	_ctx_menu.add_separator()
	if schema.has("color"):
		_ctx_menu.add_item("Copy color", _CTX_COPY_COLOR)
	if schema.has("fill_color"):
		_ctx_menu.add_item("Copy fill color", _CTX_COPY_FILL)
	if schema.has("position") or schema.has("translate"):
		_ctx_menu.add_item("Copy position", _CTX_COPY_POS)
	if not _clipboard.is_empty():
		_ctx_menu.add_separator()
		var keys: Array = _clipboard.keys()
		_ctx_menu.add_item("Paste %s to selection" % ", ".join(keys), _CTX_PASTE)
	_ctx_menu.add_separator()
	_ctx_menu.add_item("Edit source", _CTX_EDIT_SRC)
	_ctx_menu.reset_size()
	_ctx_menu.position = Vector2i(get_viewport().get_mouse_position())
	_ctx_menu.popup()

func _on_ctx_id(id: int) -> void:
	match id:
		_CTX_RESET:
			_on_reset_target()
		_CTX_DUPLICATE:
			_duplicate_selected()
		_CTX_DELETE:
			_delete_selected_runtime()
		_CTX_COPY_COLOR:
			_ctx_copy_prop("color")
		_CTX_COPY_FILL:
			_ctx_copy_prop("fill_color")
		_CTX_COPY_POS:
			var t = _selected_target()
			if t != null:
				var prop := _pos_prop_for(t)
				if prop != "":
					_ctx_copy_prop(prop)
		_CTX_PASTE:
			_ctx_paste()
		_CTX_EDIT_SRC:
			_on_request_source_edit("")

func _ctx_copy_prop(prop: String) -> void:
	var t = _selected_target()
	if t == null:
		return
	var v = t.get_value(prop)
	if v == null:
		return
	_clipboard = {prop: v}
	if _status_label:
		_status_label.text = "Copied %s = %s" % [prop, str(v)]

func _ctx_paste() -> void:
	if _clipboard.is_empty() or _selection.is_empty():
		return
	_undo_begin()
	for prop in _clipboard.keys():
		var value = _clipboard[prop]
		for t in _selected_targets():
			var schema: Dictionary = t.get_schema()
			# Accept position/translate aliasing.
			var target_prop: String = str(prop)
			if not schema.has(target_prop):
				if target_prop == "position" and schema.has("translate"):
					target_prop = "translate"
				elif target_prop == "translate" and schema.has("position"):
					target_prop = "position"
				else:
					continue
			_apply_value(t, target_prop, value)
	_undo_commit()
	_update_status()

# ----------------- Duplicate / Delete (runtime) -----------------

func _duplicate_selected() -> void:
	# Clone every selected cmd: target into the canvas's runtime list. Other
	# kinds of targets (Control/Node2D/etc.) are skipped — duplication for
	# native nodes would require knowing the scene tree intent.
	var new_ids: Array = []
	for t in _selected_targets():
		var tid := str(t.id)
		# id is "vg:<canvas_path>:cmd:<stable_id>" for command targets.
		var marker := ":cmd:"
		var idx := tid.find(marker)
		if idx < 0:
			continue
		var sid := tid.substr(idx + marker.length())
		var canvas: Node = t.owner_node
		if canvas == null or not canvas.has_method("duplicate_command"):
			continue
		var new_sid: String = canvas.duplicate_command(sid)
		if new_sid == "":
			continue
		var entry: Dictionary = canvas.get_command_target(new_sid)
		if entry.is_empty():
			continue
		var adapter = Adapters.LegacyCanvasAdapter.new(canvas, entry)
		_pinned_cmd_adapters[adapter.id] = adapter
		_targets.append(adapter)
		new_ids.append(adapter.id)
	if new_ids.is_empty():
		if _status_label:
			_status_label.text = "Nothing to duplicate (only canvas commands can be duplicated)."
		return
	_populate_selector()
	_selection = new_ids
	_selected_id = new_ids[-1]
	_sync_inspector_to_primary()
	_update_status()
	queue_redraw()
	if _status_label:
		_status_label.text = "Duplicated %d shape(s)." % new_ids.size()

func _delete_selected_runtime() -> void:
	# Remove runtime-placed shapes (Ctrl+D duplicates or palette drops).
	# Does not touch source-driven commands — those need a source edit.
	var removed := 0
	for t in _selected_targets():
		var tid := str(t.id)
		var marker := ":cmd:runtime:"
		var idx := tid.find(marker)
		if idx < 0:
			continue
		var sid := "runtime:" + tid.substr(idx + marker.length())
		var canvas: Node = t.owner_node
		if canvas == null or not canvas.has_method("remove_runtime_command"):
			continue
		if canvas.remove_runtime_command(sid):
			_pinned_cmd_adapters.erase(tid)
			_overrides.erase(tid)
			removed += 1
	if removed == 0:
		if _status_label:
			_status_label.text = "Nothing deletable (only runtime/duplicated shapes)."
		return
	_clear_selection()
	_rescan()
	_update_status()
	queue_redraw()
	if _status_label:
		_status_label.text = "Deleted %d runtime shape(s)." % removed

# ---------------- Palette / runtime shape placement (D2) ----------------

func _on_palette_toggled(kind: String, pressed: bool) -> void:
	# Single-selection toggle group: turning one on turns the others off.
	if pressed:
		_place_kind = kind
		for k in _palette_buttons.keys():
			if k != kind:
				var b: Button = _palette_buttons[k]
				if b.button_pressed:
					b.set_pressed_no_signal(false)
		if _status_label:
			_status_label.text = "Place mode: %s — click a canvas." % kind
	else:
		if _place_kind == kind:
			_place_kind = ""
			if _status_label:
				_status_label.text = "Place mode off."

func _topmost_canvas_at(global_pos: Vector2) -> Node:
	# Walk the scene for VectorCanvas-like nodes (anything with the runtime
	# placement API) and pick the one whose global bounds contain the click,
	# preferring higher z_index / later z_as_relative ordering.
	var root := get_tree().get_root()
	var best: Node = null
	var best_z := -2147483648
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not n.has_method("add_runtime_command"):
			continue
		if not (n is CanvasItem):
			continue
		var ci: CanvasItem = n
		if not ci.visible:
			continue
		var sz := Vector2.ZERO
		if "size" in ci:
			sz = ci.size
		if sz == Vector2.ZERO:
			# Best-effort: use viewport size so 2D canvases with implicit
			# extent still receive clicks.
			sz = get_viewport_rect().size
		var xform := ci.get_global_transform()
		var local_pos = xform.affine_inverse() * global_pos
		var rect := Rect2(Vector2.ZERO, sz)
		if not rect.has_point(local_pos):
			continue
		var z := 0
		if "z_index" in ci:
			z = ci.z_index
		if z >= best_z:
			best_z = z
			best = ci
	return best

func _place_at(global_pos: Vector2) -> void:
	if _place_kind == "":
		return
	var canvas := _topmost_canvas_at(global_pos)
	if canvas == null:
		if _status_label:
			_status_label.text = "No canvas under cursor."
		return
	var local_pos: Vector2 = canvas.get_global_transform().affine_inverse() * global_pos
	if _snap_enabled and _snap_grid > 0.5:
		local_pos = Vector2(snappedf(local_pos.x, _snap_grid), snappedf(local_pos.y, _snap_grid))
	var sid: String = canvas.add_runtime_command(_place_kind, local_pos)
	if sid == "":
		return
	# Clear toggle after a successful drop and refresh targets.
	var b: Button = _palette_buttons.get(_place_kind, null)
	if b != null:
		b.set_pressed_no_signal(false)
	var placed_kind := _place_kind
	_place_kind = ""
	_rescan()
	# Try to auto-select the new shape.
	var canvas_path := str(canvas.get_path())
	var new_tid := "vg:%s:cmd:%s" % [canvas_path, sid]
	for t in _targets:
		if t.id == new_tid:
			_selection = [new_tid]
			_selected_id = new_tid
			_sync_inspector_to_primary()
			_populate_selector()
			break
	if _status_label:
		_status_label.text = "Placed %s at (%d,%d)." % [placed_kind, int(local_pos.x), int(local_pos.y)]

func _merge_runtime_cmds_into(bag: Dictionary) -> void:
	# For every VectorCanvas in the tree that carries runtime-placed shapes,
	# write its full spec list under the special "__runtime_cmds__" key so
	# Persistence.load_all can restore them on the next run.
	var root := get_tree().get_root()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not n.has_method("get_runtime_commands_for_save"):
			continue
		var specs: Array = n.get_runtime_commands_for_save()
		var key := "vg:%s:__runtime_cmds__" % str(n.get_path())
		if specs.is_empty():
			bag.erase(key)
		else:
			bag[key] = specs

func _update_palette_visibility() -> void:
	if _palette_row == null:
		return
	var has_host := false
	for t in _targets:
		var owner = t.owner_node
		if owner != null and is_instance_valid(owner) and owner.has_method("add_runtime_command"):
			has_host = true
			break
	_palette_row.visible = has_host
