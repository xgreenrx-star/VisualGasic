@tool
extends PanelContainer
## VG Context Rail — docked audit sidecar beside the code editor (AI write / user audit).

signal goto_line_requested(line: int)
signal file_action_requested(action: int, ref: Dictionary)
signal summary_insert_requested(line: int, text: String)

const Analyzer := preload("res://addons/visual_gasic/vg_context_analyzer.gd")
const CaretContext := preload("res://addons/visual_gasic/vg_context_caret_context.gd")
const EditorAssist := preload("res://addons/visual_gasic/vg_editor_assist.gd")
const VGCommandHelp := preload("res://addons/visual_gasic/vg_command_help.gd")
const VGCausalChain := preload("res://addons/visual_gasic/vg_causal_chain.gd")
const SpritePanelScript := preload("res://addons/visual_gasic/vg_sprite_data_panel.gd")
const FilePreviewScript := preload("res://addons/visual_gasic/vg_file_preview_panel.gd")
const LiteralPanelScript := preload("res://addons/visual_gasic/vg_literal_convert_panel.gd")
const LiteralResolver := preload("res://addons/visual_gasic/vg_literal_resolver.gd")
const OpenPathResolver := preload("res://addons/visual_gasic/vg_open_path_resolver.gd")

const CREAM_BG := Color(0.96, 0.95, 0.92)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const RAIL_MIN_W := 160
const CARET_DEBOUNCE_SEC := 0.08

var _code_edit: CodeEdit
var _scroll: ScrollContainer
var _body: VBoxContainer
var _sections: Dictionary = {}
var _where_label: Label
var _outline_box: VBoxContainer
var _procedure_box: VBoxContainer
var _procedure_label: Label
var _summary_btn: Button
var _wire_label: Label
var _symbol_label: Label
var _sprite_panel: VBoxContainer
var _file_panel: VBoxContainer
var _literal_panel: VBoxContainer
var _keyword_label: RichTextLabel
var _chain_box: VBoxContainer
var _chain_label: Label
var _chain_open_btn: LinkButton
var _last_ctx_key: String = ""
var _last_outline_key: String = ""
var _last_source: String = ""
var _last_chain_roots: Array = []
var _chain: VGCausalChain
var _caret_timer: Timer
var _pending_caret: int = -1


func _ready() -> void:
	custom_minimum_size.x = RAIL_MIN_W
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM_BG
	sb.border_color = Color(0.72, 0.71, 0.68)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(outer)

	var title := Label.new()
	title.text = "  Context"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 0.0, 0.45))
	outer.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.name = "ContextScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.name = "ContextBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	_where_label = _body_label()
	_outline_box = VBoxContainer.new()
	_outline_box.name = "OutlineBox"
	_outline_box.add_theme_constant_override("separation", 0)

	_procedure_box = VBoxContainer.new()
	_procedure_label = _body_label()
	_summary_btn = Button.new()
	_summary_btn.text = "Add @VG-Summary"
	_summary_btn.add_theme_font_size_override("font_size", 9)
	_summary_btn.visible = false
	_summary_btn.pressed.connect(_on_summary_btn_pressed)
	_procedure_box.add_child(_procedure_label)
	_procedure_box.add_child(_summary_btn)

	_wire_label = _body_label()
	_symbol_label = _body_label()
	_sprite_panel = SpritePanelScript.new()
	_sprite_panel.name = "SpriteEditor"
	_file_panel = FilePreviewScript.new()
	_file_panel.name = "FilePreview"
	if _file_panel.has_signal("file_action_requested"):
		_file_panel.file_action_requested.connect(func(action: int, ref: Dictionary) -> void:
			file_action_requested.emit(action, ref)
		)
	_literal_panel = LiteralPanelScript.new()
	_literal_panel.name = "LiteralConvert"
	if _literal_panel.has_signal("replace_requested"):
		_literal_panel.replace_requested.connect(_on_literal_replace_requested)
	_keyword_label = _reference_label()

	_chain_box = VBoxContainer.new()
	_chain_label = _body_label()
	_chain_open_btn = LinkButton.new()
	_chain_open_btn.text = "Open full chain…"
	_chain_open_btn.add_theme_font_size_override("font_size", 10)
	_style_link_button(_chain_open_btn)
	_chain_open_btn.visible = false
	_chain_open_btn.pressed.connect(_on_open_full_chain)
	_chain_box.add_child(_chain_label)
	_chain_box.add_child(_chain_open_btn)

	_add_section("where", "Where", _where_label)
	_add_section("outline", "Outline", _outline_box)
	_add_section("procedure", "Procedure", _procedure_box)
	_add_section("wire", "Wire", _wire_label)
	_add_section("symbol", "Symbol", _symbol_label)
	_add_section("sprite", "Sprite data", _sprite_panel)
	_add_section("file", "File", _file_panel)
	_add_section("convert", "Convert", _literal_panel)
	_add_section("reference", "Reference", _keyword_label)
	_add_section("chain", "Causal chain", _chain_box)

	_chain = VGCausalChain.new()
	_caret_timer = Timer.new()
	_caret_timer.one_shot = true
	_caret_timer.wait_time = CARET_DEBOUNCE_SEC
	_caret_timer.timeout.connect(_flush_caret_update)
	add_child(_caret_timer)
	_render_idle()


func _body_label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", TEXT_DARK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _reference_label() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.selection_enabled = true
	rtl.meta_underlined = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.add_theme_font_size_override("normal_font_size", 11)
	rtl.add_theme_color_override("default_color", TEXT_DARK)
	rtl.add_theme_color_override("font_selected_color", TEXT_DARK)
	rtl.add_theme_color_override("selection_color", Color(0.35, 0.55, 0.85, 0.35))
	var rtl_sb := StyleBoxFlat.new()
	rtl_sb.bg_color = CREAM_BG
	rtl_sb.content_margin_left = 4
	rtl_sb.content_margin_right = 4
	rtl_sb.content_margin_top = 2
	rtl_sb.content_margin_bottom = 2
	rtl.add_theme_stylebox_override("normal", rtl_sb)
	rtl.add_theme_stylebox_override("focus", rtl_sb)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.meta_clicked.connect(_on_keyword_meta_clicked)
	return rtl


func bind_code_edit(code_edit: CodeEdit) -> void:
	_code_edit = code_edit
	call_deferred("_apply_code_edit_bind")


func _apply_code_edit_bind() -> void:
	if _code_edit == null:
		return
	if is_instance_valid(_sprite_panel) and _sprite_panel.has_method("bind_code_edit"):
		_sprite_panel.bind_code_edit(_code_edit)
	if is_instance_valid(_literal_panel) and _literal_panel.has_method("bind_code_edit"):
		_literal_panel.bind_code_edit(_code_edit)


func notify_source_changed() -> void:
	_last_ctx_key = ""
	_last_outline_key = ""


func update_from_caret() -> void:
	if _code_edit == null:
		_render_idle()
		return
	_pending_caret = _code_edit.get_caret_line()
	if _caret_timer.is_stopped():
		_caret_timer.start()
	else:
		_caret_timer.start()


func _flush_caret_update() -> void:
	if _code_edit == null:
		_render_idle()
		return
	var caret := _pending_caret if _pending_caret >= 0 else _code_edit.get_caret_line()
	_update_from_caret_impl(caret)


func _update_from_caret_impl(caret: int) -> void:
	var source := _code_edit.text
	_last_source = source
	var ctx := Analyzer.analyze(source, caret)
	var key := "%s|%s|%dx%d|%s|%s" % [
		caret,
		ctx.get("region_title", ""),
		int(ctx.get("sprite", {}).get("w", 0)),
		int(ctx.get("sprite", {}).get("h", 0)),
		_file_key_at_caret(source, caret),
		_literal_key_at_caret(source, caret),
	]
	if key != _last_ctx_key:
		_last_ctx_key = key
		_render(ctx, source, caret)
	else:
		_update_heavy_panels(source, caret)
	_update_outline(ctx, caret)
	_set_section_active("where", true)


func _render_idle() -> void:
	if _where_label == null:
		return
	_set_section_active("where", true)
	_where_label.text = "Open a .vg file and place the caret in code."
	_set_section_active("outline", false)
	_set_section_active("procedure", false)
	_set_section_active("wire", false)
	_set_section_active("symbol", false)
	_procedure_label.text = ""
	_summary_btn.visible = false
	_wire_label.text = ""
	_symbol_label.text = ""
	_keyword_label.text = "[i]Keyword help appears when the caret is on a VG keyword or builtin.[/i]"
	_set_section_active("reference", true)
	_chain_label.text = ""
	_chain_open_btn.visible = false
	_last_chain_roots = []
	_set_section_active("chain", false)
	_sprite_panel.visible = false
	_set_section_active("sprite", false)
	if is_instance_valid(_file_panel) and _file_panel.has_method("clear_preview"):
		_file_panel.clear_preview()
	_set_section_active("file", false)
	if is_instance_valid(_literal_panel) and _literal_panel.has_method("clear_section"):
		_literal_panel.clear_section()
	_set_section_active("convert", false)


func _render(ctx: Dictionary, source: String, caret: int) -> void:
	if _where_label == null:
		return
	var line_h := caret + 1
	_where_label.text = "Line %d · %s\n%s" % [
		line_h,
		ctx.get("region_title", ""),
		ctx.get("region_detail", ""),
	]
	_set_section_active("where", true)

	var proc: Dictionary = ctx.get("procedure", {})
	if proc.is_empty():
		_set_section_active("procedure", false)
		_procedure_label.text = ""
		_summary_btn.visible = false
	else:
		_set_section_active("procedure", true)
		var txt := "%s\n%s" % [proc.get("signature", ""), proc.get("summary", "")]
		if str(proc.get("summary", "")).is_empty():
			txt += "\nAdd a comment above the Sub or @VG-Summary for audit notes."
		if ctx.get("is_event_handler", false):
			txt += "\nEvent: %s" % ctx.get("event_label", "")
		_procedure_label.text = txt.strip_edges()
		_summary_btn.visible = str(proc.get("summary", "")).is_empty()
		_summary_btn.set_meta("proc_line", int(proc.get("start_line", caret)))

	_render_wire(source, caret, ctx, proc)
	_render_symbol(source, caret)

	var sprite: Dictionary = ctx.get("sprite", {})
	if sprite.is_empty():
		_sprite_panel.visible = false
		_set_section_active("sprite", false)
	else:
		_sprite_panel.visible = true
		_set_section_active("sprite", true)
		if _sprite_panel.has_method("update_for_caret"):
			_sprite_panel.update_for_caret(source, caret)

	var kw := EditorAssist.get_keyword_at_cursor(_code_edit) if _code_edit else ""
	_render_keyword(kw)
	_set_section_active("reference", true)

	var roots: Array = ctx.get("chain_roots", [])
	_last_chain_roots = roots.duplicate()
	if roots.is_empty():
		_chain_label.text = "Move into an event handler (e.g. btnOK_Click) for a causal chain preview."
		_chain_open_btn.visible = false
		_set_section_active("chain", false)
	else:
		_set_section_active("chain", true)
		var report := _chain.generate(source, roots)
		var lines := report.split("\n")
		if lines.size() > 14:
			lines = lines.slice(0, 14)
			lines.append("…")
		_chain_label.text = "\n".join(lines)
		_chain_open_btn.visible = true

	_update_heavy_panels(source, caret)


func _render_wire(source: String, caret: int, ctx: Dictionary, proc: Dictionary) -> void:
	var connect := CaretContext.connect_at_line(source, caret)
	var parts: PackedStringArray = PackedStringArray()
	if not connect.is_empty():
		parts.append(
			"Connect %s → \"%s\" → %s"
			% [connect.get("node", ""), connect.get("signal", ""), connect.get("handler", "")]
		)
		var node := str(connect.get("node", ""))
		var props := CaretContext.control_properties_for_name(node)
		if not props.is_empty():
			parts.append("Properties: " + ", ".join(props))
	if proc.get("is_event", false):
		var eh := CaretContext.event_handler_parts(str(proc.get("name", "")))
		if not eh.is_empty():
			parts.append(
				"Handler for [%s].%s → Sub %s"
				% [eh.get("control", ""), eh.get("event", ""), eh.get("handler", "")]
			)
	if parts.is_empty():
		_wire_label.text = ""
		_set_section_active("wire", false)
	else:
		_wire_label.text = "\n".join(parts)
		_set_section_active("wire", true)


func _render_symbol(source: String, caret: int) -> void:
	if _code_edit == null:
		_set_section_active("symbol", false)
		return
	var sym := CaretContext.member_at_caret(source, caret, _code_edit.get_caret_column())
	if sym.is_empty() or (sym.get("kind", "") == "identifier" and str(sym.get("type_hint", "")).is_empty() and not CaretContext.is_control_name(str(sym.get("name", "")))):
		_set_section_active("symbol", false)
		_symbol_label.text = ""
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s (%s)" % [sym.get("name", ""), sym.get("type_hint", sym.get("kind", ""))])
	var props: PackedStringArray = sym.get("properties", PackedStringArray())
	if not props.is_empty():
		lines.append("Common: " + ", ".join(props))
	var notes := str(sym.get("notes", ""))
	if not notes.is_empty():
		lines.append(notes)
	_symbol_label.text = "\n".join(lines)
	_set_section_active("symbol", true)


func _update_outline(ctx: Dictionary, caret: int) -> void:
	var outline: Array = ctx.get("outline", [])
	var key := str(outline.size()) + "|" + str(caret)
	for e in outline:
		key += "|" + str(e.get("line", ""))
	if key == _last_outline_key:
		return
	_last_outline_key = key
	for c in _outline_box.get_children():
		c.queue_free()
	if outline.is_empty():
		_set_section_active("outline", false)
		return
	_set_section_active("outline", true)
	var active_label_line := -1
	var sprite_ctx: Dictionary = ctx.get("sprite", {})
	if not sprite_ctx.is_empty():
		active_label_line = int(sprite_ctx.get("label_line", -1))
	for e in outline:
		var btn := LinkButton.new()
		var label := str(e.get("label", ""))
		var line_no: int = int(e.get("line", 0))
		var kind: String = str(e.get("kind", ""))
		if kind == "data" and not label.is_empty():
			btn.text = label + "  (Data)"
		elif kind == "type":
			btn.text = label
		else:
			btn.text = label
		btn.add_theme_font_size_override("font_size", 10)
		_style_link_button(btn, line_no == active_label_line)
		btn.pressed.connect(func() -> void:
			goto_line_requested.emit(line_no + 1)
		)
		_outline_box.add_child(btn)


func _update_heavy_panels(source: String, caret: int) -> void:
	if _code_edit == null:
		return
	if not ctx_sprite_empty(source, caret):
		if _sprite_panel.has_method("update_for_caret"):
			_sprite_panel.update_for_caret(source, caret)
	_update_file_at_caret(source, caret)
	_update_literal_at_caret(source, caret)


func ctx_sprite_empty(source: String, caret: int) -> bool:
	return Analyzer.analyze(source, caret).get("sprite", {}).is_empty()


func _render_keyword(keyword: String) -> void:
	if keyword.is_empty():
		_keyword_label.text = "[i]No keyword at caret.[/i]"
		return
	_keyword_label.text = VGCommandHelp.format_context_rail_keyword_bbcode(keyword)


func _on_summary_btn_pressed() -> void:
	var line: int = int(_summary_btn.get_meta("proc_line", -1))
	if line < 0:
		return
	summary_insert_requested.emit(line, "' @VG-Summary ")


func _on_open_full_chain() -> void:
	if _last_chain_roots.is_empty() or _last_source.is_empty():
		return
	var report := _chain.generate_chain_report(_last_source, _last_chain_roots)
	_show_chain_dialog(report)


func _show_chain_dialog(report: String) -> void:
	var window := AcceptDialog.new()
	window.title = "Causal Chain"
	window.min_size = Vector2i(640, 420)
	window.exclusive = false
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 8)
	vbox.add_theme_constant_override("margin_right", 8)
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)
	window.add_child(vbox)
	var te := TextEdit.new()
	te.text = report
	te.editable = false
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(te)
	var copy_row := HBoxContainer.new()
	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(func() -> void:
		_chain.copy_to_clipboard(report)
	)
	copy_row.add_child(copy_btn)
	vbox.add_child(copy_row)
	var host := get_tree().root if get_tree() else self
	host.add_child(window)
	window.popup_centered()


func show_file_preview(ref: Dictionary, preview_mode: String = "info") -> void:
	if is_instance_valid(_file_panel) and _file_panel.has_method("show_file_ref"):
		_file_panel.show_file_ref(ref, preview_mode)
		_set_section_active("file", true)


func preview_file_kind(kind: String) -> void:
	if is_instance_valid(_file_panel) and _file_panel.has_method("preview_kind"):
		_file_panel.preview_kind(kind)
		_set_section_active("file", true)


func _file_key_at_caret(source: String, caret: int) -> String:
	if _code_edit == null:
		return ""
	var ref := OpenPathResolver.resolve_at_caret(source, caret, _code_edit.get_caret_column())
	return ref.get("res_path", "")


func _update_file_at_caret(source: String, caret: int) -> void:
	if not is_instance_valid(_file_panel):
		return
	if _code_edit == null:
		_file_panel.clear_preview()
		_set_section_active("file", false)
		return
	var ref := OpenPathResolver.resolve_at_caret(source, caret, _code_edit.get_caret_column())
	if ref.is_empty():
		_file_panel.clear_preview()
		_set_section_active("file", false)
	else:
		_file_panel.show_file_ref(ref, "info")
		_set_section_active("file", true)


func _literal_key_at_caret(source: String, caret: int) -> String:
	if _code_edit == null:
		return ""
	var ref := LiteralResolver.resolve_at_caret(source, caret, _code_edit.get_caret_column())
	if ref.is_empty():
		return ""
	return "%d-%d:%s" % [int(ref.get("start", 0)), int(ref.get("end", 0)), ref.get("source_text", "")]


func _update_literal_at_caret(source: String, caret: int) -> void:
	if not is_instance_valid(_literal_panel):
		return
	if _code_edit == null:
		if _literal_panel.has_method("clear_section"):
			_literal_panel.clear_section()
		_set_section_active("convert", false)
		return
	if _literal_panel.has_method("update_for_caret"):
		_literal_panel.update_for_caret(source, caret, _code_edit.get_caret_column())
	var has_lit := not LiteralResolver.resolve_at_caret(source, caret, _code_edit.get_caret_column()).is_empty()
	_set_section_active("convert", has_lit)


func _on_literal_replace_requested(lit: Dictionary, new_text: String) -> void:
	if _code_edit == null or lit.is_empty() or new_text.is_empty():
		return
	var line := int(lit.get("line", _code_edit.get_caret_line()))
	var start := int(lit.get("start", 0))
	var end := int(lit.get("end", start))
	if line < 0 or line >= _code_edit.get_line_count():
		return
	var line_text := _code_edit.get_line(line)
	if end > line_text.length():
		end = line_text.length()
	var updated := line_text.substr(0, start) + new_text + line_text.substr(end)
	_code_edit.set_line(line, updated)
	_code_edit.set_caret_line(line)
	_code_edit.set_caret_column(start + new_text.length())
	notify_source_changed()
	update_from_caret()


func _on_keyword_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	if s.begins_with("ref:"):
		var line_str := s.substr(4)
		if line_str.is_valid_int():
			VGCommandHelp.open_programmer_reference(line_str.to_int())


func _add_section(id: String, title: String, control: Control) -> void:
	var hdr := Label.new()
	hdr.text = title
	hdr.name = "Hdr_" + id
	hdr.autowrap_mode = TextServer.AUTOWRAP_OFF
	hdr.add_theme_font_size_override("font_size", 10)
	hdr.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(hdr)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(control)
	var sep := HSeparator.new()
	sep.name = "Sep_" + id
	_body.add_child(sep)
	_sections[id] = {"header": hdr, "content": control, "sep": sep}


func _set_section_active(id: String, active: bool) -> void:
	if not _sections.has(id):
		return
	var sec: Dictionary = _sections[id]
	sec["header"].visible = active
	sec["content"].visible = active
	sec["sep"].visible = active


func _style_link_button(btn: LinkButton, emphasis: bool = false) -> void:
	var link := Color(0.0, 0.0, 0.55) if emphasis else Color(0.12, 0.12, 0.45)
	var hover := Color(0.0, 0.0, 0.75)
	btn.add_theme_color_override("font_color", link)
	btn.add_theme_color_override("font_hover_color", hover)
	btn.add_theme_color_override("font_focus_color", hover)
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.35))
