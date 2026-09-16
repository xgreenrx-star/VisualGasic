@tool
extends SyntaxHighlighter
class_name VGCodeHighlighter
## Wraps CodeHighlighter and tints only string *content* — not the quote marks.

var base: CodeHighlighter = CodeHighlighter.new()


static func resolve_base(hl: SyntaxHighlighter) -> CodeHighlighter:
	if hl == null:
		return null
	if hl is VGCodeHighlighter:
		return (hl as VGCodeHighlighter).base
	if hl is CodeHighlighter:
		return hl as CodeHighlighter
	return null


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result: Dictionary = base.get_line_syntax_highlighting(line)
	var te := get_text_edit()
	if te == null:
		return result
	_strip_string_quote_marks(te.get_line(line), result)
	return result


static func _strip_string_quote_marks(line_text: String, result: Dictionary) -> void:
	var i := 0
	var in_string := false
	while i < line_text.length():
		var ch: String = line_text[i]
		if not in_string and ch == "'":
			break
		if ch != '"':
			i += 1
			continue
		if in_string and i + 1 < line_text.length() and line_text[i + 1] == '"':
			i += 2
			continue
		result.erase(i)
		in_string = not in_string
		i += 1
