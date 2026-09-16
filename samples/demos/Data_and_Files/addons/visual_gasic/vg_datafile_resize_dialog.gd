@tool
extends AcceptDialog
## Confirm grid resize and review PeekData / dimension constant impact on project .vg code.

signal resize_confirmed(new_w: int, new_h: int, apply_fix_indices: Array, findings: Array)
signal goto_line_requested(file: String, line: int)

const UsageAnalyzer := preload("res://addons/visual_gasic/vg_datafile_usage_analyzer.gd")

const PANEL_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const LABEL_MUTED := Color(0.35, 0.35, 0.5)
const INPUT_BG := Color(1.0, 1.0, 1.0)
const DIALOG_SIZE := Vector2i(520, 380)

var _label := ""
var _old_w := 0
var _old_h := 0
var _new_w_spin: SpinBox
var _new_h_spin: SpinBox
var _summary: Label
var _findings_scroll: ScrollContainer
var _findings_box: VBoxContainer
var _findings: Array = []
var _resize_btn: Button
var _rescan_pending := false


func _ready() -> void:
	title = "Resize Grid"
	unresizable = true
	exclusive = true
	popup_window = true
	transient = true
	min_size = DIALOG_SIZE
	max_size = Vector2i(560, 420)
	theme = _build_dialog_theme()

	var outer := PanelContainer.new()
	outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	sb.content_margin_bottom = 12
	outer.add_theme_stylebox_override("panel", sb)
	add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(root)

	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", TEXT_DARK)
	intro.text = (
		"Changing grid dimensions rewrites the file on disk. "
		+ "Matching Const lines (MAP_W, MAP_H, …) are updated automatically. "
		+ "Click a row below to open that line in the code editor."
	)
	root.add_child(intro)

	var dim_row := HBoxContainer.new()
	dim_row.add_theme_constant_override("separation", 12)
	var w_box := VBoxContainer.new()
	w_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_box.add_child(_small_label("New width (tiles)"))
	_new_w_spin = _styled_spinbox()
	w_box.add_child(_new_w_spin)
	dim_row.add_child(w_box)
	var h_box := VBoxContainer.new()
	h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_box.add_child(_small_label("New height (tiles)"))
	_new_h_spin = _styled_spinbox()
	h_box.add_child(_new_h_spin)
	dim_row.add_child(h_box)
	root.add_child(dim_row)
	call_deferred("_opaque_spinbox_internals", _new_w_spin)
	call_deferred("_opaque_spinbox_internals", _new_h_spin)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 10)
	_summary.add_theme_color_override("font_color", TEXT_DARK)
	root.add_child(_summary)

	root.add_child(_small_label("Affected code in project .vg files"))

	_findings_scroll = ScrollContainer.new()
	_findings_scroll.custom_minimum_size = Vector2(0, 132)
	_findings_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_findings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_findings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var list_frame := PanelContainer.new()
	list_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list_sb := StyleBoxFlat.new()
	list_sb.bg_color = INPUT_BG
	list_sb.border_color = PANEL_BORDER
	list_sb.set_border_width_all(1)
	list_sb.set_content_margin_all(4)
	list_frame.add_theme_stylebox_override("panel", list_sb)
	_findings_scroll.add_child(list_frame)
	_findings_box = VBoxContainer.new()
	_findings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_findings_box.add_theme_constant_override("separation", 2)
	list_frame.add_child(_findings_box)
	root.add_child(_findings_scroll)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.custom_minimum_size.y = 34
	var refresh := _styled_action_button("Rescan")
	refresh.pressed.connect(_rescan)
	footer.add_child(refresh)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_resize_btn = _styled_action_button("Resize & Save")
	_resize_btn.custom_minimum_size = Vector2(120, 30)
	_resize_btn.pressed.connect(_on_resize_pressed)
	footer.add_child(_resize_btn)
	root.add_child(footer)

	_new_w_spin.value_changed.connect(_on_dim_spin_changed)
	_new_h_spin.value_changed.connect(_on_dim_spin_changed)
	canceled.connect(queue_free)
	call_deferred("_hide_builtin_ok")


func open_for(label_name: String, old_w: int, old_h: int, proposed_w: int, proposed_h: int) -> void:
	_label = label_name
	_old_w = old_w
	_old_h = old_h
	_new_w_spin.set_value_no_signal(maxi(1, proposed_w))
	_new_h_spin.set_value_no_signal(maxi(1, proposed_h))
	_rescan()
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)
	call_deferred("_hide_builtin_ok")
	call_deferred("_ensure_dialog_size")


func _rescan() -> void:
	var nw := int(_new_w_spin.value)
	var nh := int(_new_h_spin.value)
	var report := UsageAnalyzer.analyze_resize_impact(_label, _old_w, _old_h, nw, nh)
	_findings = report.get("findings", [])
	_summary.text = (
		"Label: %s  ·  %d×%d → %d×%d  ·  cells %d → %d  ·  scanned %d .vg files"
		% [
			_label if not _label.is_empty() else "(unknown)",
			_old_w, _old_h, nw, nh,
			int(report.get("old_count", 0)), int(report.get("new_count", 0)),
			int(report.get("files_scanned", 0)),
		]
	)
	_rebuild_findings_rows()
	var auto_n := 0
	for f in _findings:
		if bool(f.get("auto_fixable", false)):
			auto_n += 1
	if auto_n > 0:
		_summary.text += "  ·  %d auto-update(s) on save" % auto_n
	_resize_btn.disabled = (nw == _old_w and nh == _old_h)
	_resize_btn.text = "Resize & Save" if not _resize_btn.disabled else "No change"


func _rebuild_findings_rows() -> void:
	if _findings_box == null:
		return
	for c in _findings_box.get_children():
		c.queue_free()
	if _findings.is_empty():
		_findings_box.add_child(_finding_info_label(
			"No related PeekData or dimension constants found — still verify index math manually."
		))
		return
	for i in _findings.size():
		var f: Dictionary = _findings[i]
		var sev: String = str(f.get("severity", "info"))
		var prefix := "[!] " if sev == "error" else ("[~] " if sev == "warning" else "[i] ")
		var fix_tag := "  ✎ auto" if bool(f.get("auto_fixable", false)) else ""
		var path: String = str(f.get("file", "")).get_file()
		var txt := prefix + path + ":" + str(int(f.get("line", 0)) + 1) + "  " + str(f.get("message", "")) + fix_tag
		_findings_box.add_child(_make_finding_row(i, txt))


func _finding_info_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", LABEL_MUTED)
	return l


func _make_finding_row(index: int, text: String) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", TEXT_DARK)
	btn.add_theme_color_override("font_focus_color", TEXT_DARK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = INPUT_BG
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.92, 0.94, 0.98)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.86, 0.90, 0.96)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover.duplicate())
	btn.pressed.connect(func() -> void: _on_finding_activated(index))
	return btn


func _on_dim_spin_changed(_v: float) -> void:
	if _rescan_pending:
		return
	_rescan_pending = true
	call_deferred("_rescan_deferred")


func _rescan_deferred() -> void:
	_rescan_pending = false
	if not is_instance_valid(self):
		return
	_rescan()


func _on_resize_pressed() -> void:
	var nw := int(_new_w_spin.value)
	var nh := int(_new_h_spin.value)
	if nw == _old_w and nh == _old_h:
		return
	var auto_fix: Array = []
	for i in _findings.size():
		if bool(_findings[i].get("auto_fixable", false)):
			auto_fix.append(i)
	resize_confirmed.emit(nw, nh, auto_fix, _findings.duplicate(true))
	hide()
	queue_free()


func _on_finding_activated(index: int) -> void:
	if index < 0 or index >= _findings.size():
		return
	var f: Dictionary = _findings[index]
	goto_line_requested.emit(str(f.get("file", "")), int(f.get("line", 0)))


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", LABEL_MUTED)
	return l


func _styled_spinbox() -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 512
	sp.add_theme_color_override("font_color", TEXT_DARK)
	return sp


func _opaque_spinbox_internals(sp: SpinBox) -> void:
	if sp == null or not is_instance_valid(sp):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	sp.add_theme_stylebox_override("normal", sb)
	sp.add_theme_stylebox_override("focus", sb.duplicate())
	sp.add_theme_stylebox_override("read_only", sb.duplicate())
	var le := sp.get_line_edit()
	if le:
		le.add_theme_color_override("font_color", TEXT_DARK)
		le.add_theme_stylebox_override("normal", sb.duplicate())
		le.add_theme_stylebox_override("focus", sb.duplicate())
		le.add_theme_stylebox_override("read_only", sb.duplicate())
	for child in sp.get_children():
		if child is Button:
			child.add_theme_color_override("font_color", TEXT_DARK)
			var btn_sb := sb.duplicate()
			child.add_theme_stylebox_override("normal", btn_sb)
			child.add_theme_stylebox_override("hover", btn_sb)
			child.add_theme_stylebox_override("pressed", btn_sb)


func _styled_action_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_color_override("font_color", TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", TEXT_DARK)
	btn.add_theme_color_override("font_focus_color", TEXT_DARK)
	btn.add_theme_color_override("font_disabled_color", LABEL_MUTED)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL_BG
	normal.border_color = PANEL_BORDER
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.95, 0.94, 0.92)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.88, 0.87, 0.85)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover.duplicate())
	return btn


func _hide_builtin_ok() -> void:
	var ok := get_ok_button()
	if ok:
		ok.visible = false


func _ensure_dialog_size() -> void:
	size = DIALOG_SIZE
	min_size = DIALOG_SIZE


func _build_dialog_theme() -> Theme:
	var t := Theme.new()
	var dlg_sb := StyleBoxFlat.new()
	dlg_sb.bg_color = PANEL_BG
	dlg_sb.border_color = PANEL_BORDER
	dlg_sb.set_border_width_all(1)
	dlg_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "AcceptDialog", dlg_sb)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = PANEL_BG
	btn_sb.border_color = PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 10
	btn_sb.content_margin_right = 10
	btn_sb.content_margin_top = 4
	btn_sb.content_margin_bottom = 4
	t.set_stylebox("normal", "Button", btn_sb)
	t.set_stylebox("hover", "Button", btn_sb.duplicate())
	t.set_stylebox("pressed", "Button", btn_sb.duplicate())
	t.set_color("font_color", "Button", TEXT_DARK)
	t.set_color("font_hover_color", "Button", TEXT_DARK)
	t.set_color("font_pressed_color", "Button", TEXT_DARK)
	t.set_color("font_focus_color", "Button", TEXT_DARK)
	t.set_color("font_color", "Label", TEXT_DARK)

	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(1.0, 1.0, 0.94)
	tip_sb.border_color = Color(0.0, 0.0, 0.0)
	tip_sb.set_border_width_all(1)
	tip_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "TooltipPanel", tip_sb)
	t.set_color("font_color", "TooltipLabel", TEXT_DARK)
	return t
