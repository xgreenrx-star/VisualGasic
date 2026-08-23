@tool
extends PanelContainer
## VG Context Rail — docked audit sidecar beside the code editor (AI write / user audit).

signal goto_line_requested(line: int)
signal file_action_requested(action: int, ref: Dictionary)

const Analyzer := preload("res://addons/visual_gasic/vg_context_analyzer.gd")
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

var _code_edit: CodeEdit
var _scroll: ScrollContainer
var _body: VBoxContainer
var _where_label: Label
var _procedure_label: Label
var _sprite_panel: VBoxContainer
var _file_panel: VBoxContainer
var _literal_panel: VBoxContainer
var _keyword_label: RichTextLabel
var _chain_label: Label
var _last_ctx_key: String = ""
var _chain: VGCausalChain


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
	_procedure_label = _body_label()
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
	_chain_label = _body_label()

	_add_section("Where", _where_label)
	_add_section("Procedure", _procedure_label)
	_add_section("Sprite data", _sprite_panel)
	_add_section("File", _file_panel)
	_add_section("Convert", _literal_panel)
	_add_section("Reference", _keyword_label)
	_add_section("Causal chain", _chain_label)

	_chain = VGCausalChain.new()
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


func notify_source_changed() -> void:
	_last_ctx_key = ""


func update_from_caret() -> void:
	if _code_edit == null:
		_render_idle()
		return
	var source := _code_edit.text
	var caret := _code_edit.get_caret_line()
	var ctx := Analyzer.analyze(source, caret)
	var key := "%s|%s|%dx%d|%s|%s" % [
		caret,
		ctx.get("region_title", ""),
		int(ctx.get("sprite", {}).get("w", 0)),
		int(ctx.get("sprite", {}).get("h", 0)),
		_file_key_at_caret(source, caret),
		_literal_key_at_caret(source, caret),
	]
	if key == _last_ctx_key:
		if not ctx.get("sprite", {}).is_empty() and _sprite_panel.has_method("update_for_caret"):
			_sprite_panel.update_for_caret(source, caret)
		_update_file_at_caret(source, caret)
		_update_literal_at_caret(source, caret)
		return
	_last_ctx_key = key
	_render(ctx, source, caret)


func _render_idle() -> void:
	if _where_label == null:
		return
	_where_label.text = "Open a .vg file and place the caret in code."
	_procedure_label.text = ""
	_keyword_label.text = "[i]Keyword help appears when the caret is on a VG keyword or builtin.[/i]"
	_chain_label.text = ""
	_sprite_panel.visible = false
	if is_instance_valid(_file_panel) and _file_panel.has_method("clear_preview"):
		_file_panel.clear_preview()
	if is_instance_valid(_literal_panel) and _literal_panel.has_method("clear_section"):
		_literal_panel.clear_section()


func _render(ctx: Dictionary, source: String, caret: int) -> void:
	if _where_label == null:
		return
	var line_h := caret + 1
	_where_label.text = "Line %d · %s\n%s" % [
		line_h,
		ctx.get("region_title", ""),
		ctx.get("region_detail", ""),
	]

	var proc: Dictionary = ctx.get("procedure", {})
	if proc.is_empty():
		_procedure_label.text = "Not inside a Sub/Function."
	else:
		var txt := "%s\n%s" % [proc.get("signature", ""), proc.get("summary", "")]
		if str(proc.get("summary", "")).is_empty():
			txt += "\nAdd a comment above the Sub or ' @VG-Summary … for audit notes."
		if ctx.get("is_event_handler", false):
			txt += "\nEvent: %s" % ctx.get("event_label", "")
		_procedure_label.text = txt.strip_edges()

	var sprite: Dictionary = ctx.get("sprite", {})
	if sprite.is_empty():
		_sprite_panel.visible = false
	else:
		_sprite_panel.visible = true
		if _sprite_panel.has_method("update_for_caret"):
			_sprite_panel.update_for_caret(source, caret)

	var kw := EditorAssist.get_keyword_at_cursor(_code_edit) if _code_edit else ""
	_render_keyword(kw)

	var roots: Array = ctx.get("chain_roots", [])
	if roots.is_empty():
		_chain_label.text = "Move into an event handler (e.g. btnOK_Click) for a causal chain preview."
	else:
		var report := _chain.generate(source, roots)
		var lines := report.split("\n")
		if lines.size() > 14:
			lines = lines.slice(0, 14)
			lines.append("…")
		_chain_label.text = "\n".join(lines)

	_update_file_at_caret(source, caret)
	_update_literal_at_caret(source, caret)


func show_file_preview(ref: Dictionary, preview_mode: String = "info") -> void:
	if is_instance_valid(_file_panel) and _file_panel.has_method("show_file_ref"):
		_file_panel.show_file_ref(ref, preview_mode)


func preview_file_kind(kind: String) -> void:
	if is_instance_valid(_file_panel) and _file_panel.has_method("preview_kind"):
		_file_panel.preview_kind(kind)


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
		return
	var ref := OpenPathResolver.resolve_at_caret(source, caret, _code_edit.get_caret_column())
	if ref.is_empty():
		_file_panel.clear_preview()
	else:
		_file_panel.show_file_ref(ref, "info")


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
		return
	if _literal_panel.has_method("update_for_caret"):
		_literal_panel.update_for_caret(source, caret, _code_edit.get_caret_column())


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


func _render_keyword(keyword: String) -> void:
	if keyword.is_empty():
		_keyword_label.text = "[i]No keyword at caret.[/i]"
		return
	_keyword_label.text = VGCommandHelp.format_context_rail_keyword_bbcode(keyword)


func _on_keyword_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	if s.begins_with("ref:"):
		var line_str := s.substr(4)
		if line_str.is_valid_int():
			VGCommandHelp.open_programmer_reference(line_str.to_int())


func _add_section(title: String, control: Control) -> void:
	var hdr := Label.new()
	hdr.text = title
	hdr.autowrap_mode = TextServer.AUTOWRAP_OFF
	hdr.add_theme_font_size_override("font_size", 10)
	hdr.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(hdr)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(control)
	var sep := HSeparator.new()
	_body.add_child(sep)
