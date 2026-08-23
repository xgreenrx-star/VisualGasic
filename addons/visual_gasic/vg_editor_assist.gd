@tool
extends RefCounted
## Shared caret-driven updates for Command Help + sprite Data panel (VG IDE + Godot editor).

const VGCommandHelp = preload("res://addons/visual_gasic/vg_command_help.gd")
const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")


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


static func render_command_help(help_label: RichTextLabel, keyword: String, scroll: ScrollContainer = null) -> void:
	if help_label == null:
		return
	if scroll:
		scroll.scroll_vertical = 0
	help_label.text = ""
	if keyword.is_empty():
		help_label.append_text("[color=#555555][i]Place the cursor on a keyword to see its documentation.[/i][/color]")
		return
	var entry: Dictionary = VGCommandHelp.lookup(keyword)
	if entry.is_empty():
		help_label.append_text("[color=#555555][i]No documentation for \"%s\"[/i][/color]" % keyword)
		return
	help_label.append_text("[b][color=#00006B][font_size=12]%s[/font_size][/color][/b]\n\n" % entry.get("keyword", keyword))
	var syntax_text: String = entry.get("syntax", "")
	if not syntax_text.is_empty():
		help_label.append_text("[b][color=#00006B]Syntax[/color][/b]\n")
		help_label.append_text("[color=#333333][code]%s[/code][/color]\n\n" % syntax_text)
	help_label.append_text("[b][color=#00006B]Description[/color][/b]\n")
	help_label.append_text("[color=#222222]%s[/color]\n" % entry.get("desc", ""))


static func update_sprite_panel(sprite_panel: Control, code_edit: CodeEdit) -> void:
	if sprite_panel == null or not sprite_panel.has_method("update_for_caret"):
		return
	if code_edit == null:
		sprite_panel.call("clear_section")
		return
	var path := ""
	if code_edit.has_method("get_meta") and code_edit.has_meta("vg_file_path"):
		path = str(code_edit.get_meta("vg_file_path"))
	if not path.ends_with(".vg"):
		# Still allow if buffer looks like VG (Godot script editor path).
		pass
	sprite_panel.call("update_for_caret", code_edit.text, code_edit.get_caret_line())


static func caret_assist_update(
	code_edit: CodeEdit,
	help_label: RichTextLabel,
	sprite_panel: Control,
	state: Dictionary,
	help_scroll: ScrollContainer = null,
) -> void:
	if code_edit == null:
		return
	var keyword := get_keyword_at_cursor(code_edit)
	if keyword != state.get("last_keyword", ""):
		state["last_keyword"] = keyword
		render_command_help(help_label, keyword, help_scroll)
	update_sprite_panel(sprite_panel, code_edit)
	var sec := Resolver.resolve_at_line(code_edit.text, code_edit.get_caret_line())
	state["in_sprite_block"] = not sec.is_empty()
