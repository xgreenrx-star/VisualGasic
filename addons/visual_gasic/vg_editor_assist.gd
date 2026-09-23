@tool
extends RefCounted
## Shared caret-driven updates for Command Help + sprite Data panel (VG IDE + Godot editor).

const VGCommandHelp = preload("res://addons/visual_gasic/vg_command_help.gd")
const VGUserSymbolHelp = preload("res://addons/visual_gasic/vg_user_symbol_help.gd")
const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const VectorResolver := preload("res://addons/visual_gasic/vg_vector_data_resolver.gd")
const WireResolver := preload("res://addons/visual_gasic/vg_wire_model_resolver.gd")


static func get_keyword_at_cursor(code_edit: CodeEdit) -> String:
	if code_edit == null:
		return ""
	var line_idx := code_edit.get_caret_line()
	var col := code_edit.get_caret_column()
	var line_text := code_edit.get_line(line_idx)
	if line_text.is_empty():
		return ""
	var word_start := col
	var word_end := col
	while word_start > 0 and (line_text[word_start - 1].is_valid_identifier() or line_text[word_start - 1] == "_"):
		word_start -= 1
	while word_end < line_text.length() and (line_text[word_end].is_valid_identifier() or line_text[word_end] == "_"):
		word_end += 1
	if word_start >= word_end:
		return ""
	var word := line_text.substr(word_start, word_end - word_start).strip_edges()
	var lower := word.to_lower()
	if lower == "end":
		var rest := line_text.substr(word_end).strip_edges()
		if not rest.is_empty():
			return "End " + rest.split(" ")[0]
	if lower == "select" and line_text.substr(word_end).strip_edges().to_lower().begins_with("case"):
		return "Select Case"
	return word


static func render_command_help(
	help_label: RichTextLabel,
	keyword: String,
	scroll: ScrollContainer = null,
	source_text: String = "",
) -> void:
	if help_label == null:
		return
	if scroll:
		scroll.scroll_vertical = 0
	help_label.text = ""
	if keyword.is_empty():
		help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")
		return
	var entry: Dictionary = VGCommandHelp.lookup(keyword)
	var is_builtin := not entry.is_empty()
	if entry.is_empty() and not source_text.is_empty():
		entry = VGUserSymbolHelp.lookup(keyword, source_text)
	if entry.is_empty():
		help_label.append_text("[color=#555555][i]No documentation for \"%s\"[/i][/color]" % keyword)
		return
	help_label.append_text("[b][color=#00006B][font_size=12]%s[/font_size][/color][/b]\n\n" % entry.get("keyword", keyword))
	var syntax_text: String = entry.get("syntax", "")
	if not syntax_text.is_empty():
		help_label.append_text("[b][color=#00006B]Syntax[/color][/b]\n")
		help_label.append_text("[color=#333333][code]%s[/code][/color]\n\n" % syntax_text)
	help_label.append_text("[b][color=#00006B]Description[/color][/b]\n")
	var desc: String = str(entry.get("desc", ""))
	if is_builtin:
		desc = VGCommandHelp.linkify_cross_references(desc)
	help_label.append_text("[color=#222222]%s[/color]\n" % desc)
	_append_user_symbol_help_extras(help_label, entry, keyword, is_builtin)


static func _append_user_symbol_help_extras(
	help_label: RichTextLabel,
	entry: Dictionary,
	keyword: String,
	is_builtin: bool,
) -> void:
	var symbol_kind: String = entry.get("symbol_kind", "")
	if symbol_kind.is_empty():
		if is_builtin:
			var see_also: Array = VGCommandHelp.get_see_also(keyword)
			if not see_also.is_empty():
				help_label.append_text("\n[b][color=#00006B]See Also[/color][/b]\n")
				help_label.append_text("[color=#333333]👉 %s[/color]\n" % ", ".join(see_also))
		return

	var kind_labels := {
		"sub": "Subroutine",
		"function": "Function",
		"variable": "Variable",
		"const": "Constant",
		"type": "Type",
	}
	var kind_label: String = kind_labels.get(symbol_kind, symbol_kind.capitalize())
	help_label.append_text("\n[color=#555555]🏷️ User-Defined %s[/color]\n" % kind_label)
	var def_line: int = entry.get("defined_on_line", 0)
	if def_line > 0:
		help_label.append_text(
			"[color=#555555]📍 [/color][url=goto:%d][color=#0000CC][b]Go to Definition (line %d)[/b][/color][/url]\n"
			% [def_line, def_line]
		)

	var comment: String = entry.get("comment", "")
	if not comment.is_empty():
		help_label.append_text("\n[b][color=#00006B]Developer Note[/color][/b]\n")
		help_label.append_text("[color=#336633]💬 %s[/color]\n" % comment)

	var scope_info: String = entry.get("scope_info", "")
	if not scope_info.is_empty():
		help_label.append_text("\n[color=#555555]📌 Scope: [b]%s[/b][/color]\n" % scope_info)

	var type_members: Array = entry.get("type_members", [])
	if not type_members.is_empty():
		help_label.append_text("\n[b][color=#00006B]Members[/color][/b]\n")
		for member in type_members:
			help_label.append_text("[color=#333333]  • [code]%s[/code][/color]\n" % str(member))

	_append_line_link_list(help_label, "🔍 Used on lines", entry.get("used_on_lines", []), "#0000CC")
	_append_line_link_list(help_label, "✏️ Modified on lines", entry.get("modified_on_lines", []), "#CC6600")
	_append_line_link_list(help_label, "📞 Called from lines", entry.get("called_from_lines", []), "#0000CC")


static func _append_line_link_list(help_label: RichTextLabel, title: String, lines: Array, color_hex: String) -> void:
	if lines.is_empty():
		return
	help_label.append_text("\n[color=#555555]%s: " % title)
	for ui in lines.size():
		if ui > 0:
			help_label.append_text(", ")
		var ln: int = lines[ui]
		help_label.append_text("[url=goto:%d][color=%s]%d[/color][/url]" % [ln, color_hex, ln])
	help_label.append_text("[/color]\n")


static func update_sprite_panel(sprite_panel: Control, code_edit: CodeEdit) -> void:
	if sprite_panel == null or not sprite_panel.has_method("update_for_caret"):
		return
	if code_edit == null:
		sprite_panel.call("clear_section")
		return
	sprite_panel.call("update_for_caret", code_edit.text, code_edit.get_caret_line())


static func update_vector_panel(vector_panel: Control, code_edit: CodeEdit) -> void:
	if vector_panel == null or not vector_panel.has_method("update_for_caret"):
		return
	if code_edit == null:
		vector_panel.call("clear_section")
		return
	vector_panel.call("update_for_caret", code_edit.text, code_edit.get_caret_line())


static func caret_assist_update(
	code_edit: CodeEdit,
	help_label: RichTextLabel,
	sprite_panel: Control,
	state: Dictionary,
	help_scroll: ScrollContainer = null,
	vector_panel: Control = null,
) -> void:
	if code_edit == null:
		return
	var keyword := get_keyword_at_cursor(code_edit)
	if keyword != state.get("last_keyword", ""):
		state["last_keyword"] = keyword
		render_command_help(help_label, keyword, help_scroll, code_edit.text)
	update_sprite_panel(sprite_panel, code_edit)
	update_vector_panel(vector_panel, code_edit)
	var sec := Resolver.resolve_at_line(code_edit.text, code_edit.get_caret_line())
	state["in_sprite_block"] = not sec.is_empty()
	var vsec := VectorResolver.resolve_at_line(code_edit.text, code_edit.get_caret_line())
	var wsec := WireResolver.resolve_at_line(code_edit.text, code_edit.get_caret_line())
	state["in_vector_block"] = not vsec.is_empty() or not wsec.is_empty()
