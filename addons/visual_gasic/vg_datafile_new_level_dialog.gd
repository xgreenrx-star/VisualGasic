@tool
extends AcceptDialog
## Wizard: new labeled DataFile + empty CSV/.vgd grid.

signal completed(ref: Dictionary, open_grid_editor: bool)

const NewLevel := preload("res://addons/visual_gasic/vg_datafile_new_level.gd")
const VGTheme := preload("res://addons/visual_gasic/vg_theme_utils.gd")

const PANEL_BG := Color(0.941, 0.929, 0.910)
const PANEL_BORDER := Color(0.72, 0.71, 0.68)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const LABEL_MUTED := Color(0.35, 0.35, 0.5)
const INPUT_BG := Color(1.0, 1.0, 1.0)
const DIALOG_SIZE := Vector2i(440, 400)

var _label_edit: LineEdit
var _path_edit: LineEdit
var _w_spin: SpinBox
var _h_spin: SpinBox
var _format_opt: OptionButton
var _open_grid: CheckBox
var _create_btn: Button
var _code_edit: CodeEdit = null
var _status: Label


func _ready() -> void:
	title = "New Level (DataFile)"
	unresizable = true
	exclusive = true
	popup_window = true
	transient = true
	min_size = DIALOG_SIZE
	max_size = Vector2i(520, 480)
	theme = _build_dialog_theme()

	var outer := PanelContainer.new()
	outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var outer_sb := StyleBoxFlat.new()
	outer_sb.bg_color = PANEL_BG
	outer_sb.border_color = PANEL_BORDER
	outer_sb.set_border_width_all(1)
	outer_sb.set_content_margin_all(10)
	outer_sb.content_margin_bottom = 14
	outer.add_theme_stylebox_override("panel", outer_sb)
	add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(root)

	var intro := Label.new()
	intro.text = "Create a labeled tile map and DataFile line in your .vg source."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 11)
	intro.add_theme_color_override("font_color", TEXT_DARK)
	root.add_child(intro)

	root.add_child(_small_label("Label name"))
	_label_edit = _styled_line_edit()
	root.add_child(_label_edit)
	_label_edit.text_changed.connect(_on_label_changed)

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 6)
	var path_box := VBoxContainer.new()
	path_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_box.add_child(_small_label("File path"))
	_path_edit = _styled_line_edit()
	path_box.add_child(_path_edit)
	path_row.add_child(path_box)
	var browse := Button.new()
	browse.text = "Browse…"
	browse.custom_minimum_size = Vector2(72, 0)
	path_row.add_child(browse)
	browse.pressed.connect(_on_browse)
	root.add_child(path_row)

	var dim_row := HBoxContainer.new()
	dim_row.add_theme_constant_override("separation", 12)
	var w_box := VBoxContainer.new()
	w_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_box.add_child(_small_label("Width (tiles)"))
	_w_spin = _styled_spinbox()
	_w_spin.value = NewLevel.DEFAULT_W
	w_box.add_child(_w_spin)
	dim_row.add_child(w_box)
	var h_box := VBoxContainer.new()
	h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_box.add_child(_small_label("Height (tiles)"))
	_h_spin = _styled_spinbox()
	_h_spin.value = NewLevel.DEFAULT_H
	h_box.add_child(_h_spin)
	dim_row.add_child(h_box)
	root.add_child(dim_row)
	call_deferred("_opaque_spinbox_internals", _w_spin)
	call_deferred("_opaque_spinbox_internals", _h_spin)

	root.add_child(_small_label("On-disk format"))
	_format_opt = OptionButton.new()
	_format_opt.add_item("CSV (editable text — recommended)", 0)
	_format_opt.add_item("Binary .vgd (runtime MemoryBuffer)", 1)
	_format_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_format_opt.item_selected.connect(_on_format_selected)
	root.add_child(_format_opt)
	VGTheme.hook_option_button(_format_opt)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", Color(0.65, 0.15, 0.15))
	_status.custom_minimum_size.y = 24
	root.add_child(_status)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.custom_minimum_size.y = 34
	_open_grid = CheckBox.new()
	_open_grid.text = "Open Grid Editor after create"
	_open_grid.button_pressed = true
	_open_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_checkbox(_open_grid)
	footer.add_child(_open_grid)
	_create_btn = _styled_action_button("Create")
	_create_btn.custom_minimum_size = Vector2(96, 30)
	footer.add_child(_create_btn)
	root.add_child(footer)

	_create_btn.pressed.connect(_on_confirmed)
	canceled.connect(queue_free)
	call_deferred("_hide_builtin_buttons")


func open_for(code_edit: CodeEdit) -> void:
	_code_edit = code_edit
	_status.text = ""
	_apply_suggestions()
	size = DIALOG_SIZE
	popup_centered(DIALOG_SIZE)
	call_deferred("_hide_builtin_buttons")
	call_deferred("_ensure_dialog_size")


func _apply_suggestions() -> void:
	if _code_edit == null:
		return
	var caret := _code_edit.get_caret_line()
	var sugg := NewLevel.suggest_from_source(_code_edit.text, caret)
	_label_edit.text = str(sugg.get("label", NewLevel.default_label()))
	_path_edit.text = str(sugg.get("path", NewLevel.default_path_for_label(_label_edit.text)))
	_w_spin.value = int(sugg.get("width", NewLevel.DEFAULT_W))
	_h_spin.value = int(sugg.get("height", NewLevel.DEFAULT_H))
	_format_opt.selected = 1 if bool(sugg.get("as_vgd", false)) else 0


func _hide_builtin_buttons() -> void:
	var ok_btn := get_ok_button()
	if ok_btn:
		ok_btn.visible = false


func _ensure_dialog_size() -> void:
	size = DIALOG_SIZE
	min_size = DIALOG_SIZE


func _style_checkbox(cb: CheckBox) -> void:
	cb.add_theme_color_override("font_color", TEXT_DARK)
	cb.add_theme_color_override("font_hover_color", TEXT_DARK)
	cb.add_theme_color_override("font_pressed_color", TEXT_DARK)
	cb.add_theme_color_override("font_focus_color", TEXT_DARK)
	cb.add_theme_color_override("font_disabled_color", LABEL_MUTED)


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


func _styled_line_edit() -> LineEdit:
	var le := LineEdit.new()
	le.add_theme_color_override("font_color", TEXT_DARK)
	le.add_theme_color_override("font_placeholder_color", LABEL_MUTED)
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(4)
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", sb.duplicate())
	return le


func _styled_spinbox() -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = NewLevel.MAX_DIM
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
	t.set_color("font_color", "CheckBox", TEXT_DARK)
	t.set_color("font_hover_color", "CheckBox", TEXT_DARK)
	t.set_color("font_pressed_color", "CheckBox", TEXT_DARK)
	t.set_color("font_focus_color", "CheckBox", TEXT_DARK)
	return t


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", LABEL_MUTED)
	return l


func _on_label_changed(_new_text: String) -> void:
	pass


func _on_format_selected(idx: int) -> void:
	var p := _path_edit.text.get_basename()
	if idx == 1:
		_path_edit.text = p + ".vgd"
	else:
		_path_edit.text = p + ".csv"


func _on_browse() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.title = "Save level as"
	fd.filters = PackedStringArray(["*.csv ; CSV grid", "*.vgd ; VG binary grid"])
	var cur := _path_edit.text.strip_edges()
	if cur.begins_with("res://"):
		fd.current_path = ProjectSettings.globalize_path(cur)
	else:
		fd.current_dir = ProjectSettings.globalize_path("res://data")
	fd.file_selected.connect(func(selected: String) -> void:
		var res := selected
		if selected.begins_with("/"):
			var proj := ProjectSettings.globalize_path("res://")
			if selected.begins_with(proj):
				res = "res://" + selected.substr(proj.length())
		_path_edit.text = res
		fd.queue_free()
	)
	fd.canceled.connect(fd.queue_free)
	get_tree().root.add_child(fd)
	fd.popup_centered_ratio(0.55)


func _on_confirmed() -> void:
	_status.text = ""
	if _code_edit == null:
		_status.text = "No code editor active."
		return
	var lbl := _label_edit.text.strip_edges()
	var path := _path_edit.text.strip_edges()
	var w := int(_w_spin.value)
	var h := int(_h_spin.value)
	var as_vgd := _format_opt.selected == 1
	if not NewLevel.is_valid_label(lbl):
		_status.text = "Invalid label name."
		return
	var abs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if FileAccess.file_exists(abs):
		var confirm := ConfirmationDialog.new()
		confirm.title = "Overwrite file?"
		confirm.dialog_text = "Replace existing file?\n" + path
		confirm.theme = _build_dialog_theme()
		confirm.exclusive = true
		confirm.unresizable = true
		confirm.confirmed.connect(func() -> void:
			_finish_create(lbl, path, w, h, as_vgd)
			confirm.queue_free()
		)
		confirm.canceled.connect(confirm.queue_free)
		get_tree().root.add_child(confirm)
		confirm.popup_centered()
		return
	_finish_create(lbl, path, w, h, as_vgd)


func _finish_create(label: String, path: String, w: int, h: int, as_vgd: bool) -> void:
	var result := NewLevel.create_level(_code_edit, label, path, w, h, as_vgd)
	if not bool(result.get("ok", false)):
		_status.text = str(result.get("error", "Create failed"))
		return
	var ref: Dictionary = result.get("ref", {})
	completed.emit(ref, _open_grid.button_pressed)
	queue_free()
