@tool
extends RefCounted
## Sanitise an AI reply for text-to-speech.
##
## Problems we fix (May 3 2026 user feedback):
##   1. Narcea was reading every line of generated code aloud — unbearable
##      for anything longer than a 3-line snippet.
##   2. Markdown formatting (**bold**, ##headings, `inline code`) gets
##      pronounced as literal asterisks and pound signs by both Piper and
##      OpenAI TTS.
##   3. URLs and file paths are read character-by-character which sounds
##      awful.
##   4. JSON form-spec blocks (Narcea's new structured output) MUST be
##      kept silent — they're for the Build-form button, not the user.
##
## Strategy: replace fenced code blocks with a one-line summary, strip
## markdown emphasis markers, collapse whitespace.  Keep the rest verbatim
## so Narcea's prose still sounds natural.

const FENCE_RE := "```([a-zA-Z0-9_+-]*)\\s*([\\s\\S]*?)```"
const INLINE_CODE_RE := "`([^`\\n]+)`"
const URL_RE := "(https?://\\S+)"


## Return a TTS-friendly version of `text`.  Original is unchanged.
func for_speech(text: String) -> String:
	if text.is_empty():
		return text
	var s := text

	# 1. Replace fenced code blocks with short summaries.
	var rx := RegEx.new()
	rx.compile(FENCE_RE)
	var matches: Array = rx.search_all(s)
	# Replace from the end so offsets stay valid.
	matches.reverse()
	for m in matches:
		var lang: String = m.get_string(1).strip_edges().to_lower()
		var body: String = m.get_string(2)
		s = s.substr(0, m.get_start()) + _summarise_block(lang, body) + s.substr(m.get_end())

	# 2. Inline `code` → just say the contents without the backticks.
	rx.compile(INLINE_CODE_RE)
	while true:
		var im := rx.search(s)
		if im == null:
			break
		s = s.substr(0, im.get_start()) + im.get_string(1) + s.substr(im.get_end())

	# 3. Skip URLs entirely — say "see the link" instead.
	rx.compile(URL_RE)
	while true:
		var um := rx.search(s)
		if um == null:
			break
		s = s.substr(0, um.get_start()) + "(see the link)" + s.substr(um.get_end())

	# 4. Strip bullet markers / heading hashes / bold-italic asterisks.
	var lines: Array[String] = []
	for raw in s.split("\n"):
		var line := raw
		line = line.lstrip(" \t")
		# Leading markdown markers.
		while line.begins_with("#"):
			line = line.substr(1)
		line = line.lstrip(" \t")
		if line.begins_with("- ") or line.begins_with("* "):
			line = line.substr(2)
		if line.begins_with("> "):
			line = line.substr(2)
		# Inline emphasis: ** bold **, * italic *, __underscore__
		line = line.replace("**", "")
		line = line.replace("__", "")
		# Single asterisks used for italic — drop them but keep multiplication.
		line = _strip_lonely_asterisks(line)
		lines.append(line)

	s = "\n".join(lines)

	# 5. Collapse runs of whitespace / blank lines.
	while s.find("\n\n\n") != -1:
		s = s.replace("\n\n\n", "\n\n")
	s = s.strip_edges()
	return s


## Decide what (if anything) to say in place of a code/spec block.
func _summarise_block(lang: String, body: String) -> String:
	# Form/code/project specs and tool calls are structural — never read aloud.
	if lang.ends_with("-spec") or lang == "vg-tool":
		return ""
	if lang in ["vg", "vb", "basic", "json", "gdscript", "python", "javascript", "typescript"]:
		var line_count := 0
		for ln in body.split("\n"):
			if not ln.strip_edges().is_empty():
				line_count += 1
		if line_count == 0:
			return ""
		var label := lang
		if label == "vg" or label == "vb" or label == "basic":
			label = "VG code"
		return ". (See the panel for %d lines of %s.) " % [line_count, label]
	# Count non-empty lines for a quick "X lines of code" summary.
	var line_count := 0
	for ln in body.split("\n"):
		if not ln.strip_edges().is_empty():
			line_count += 1
	if line_count == 0:
		return ""
	# Single-line snippet outside code langs: keep it.
	if line_count == 1:
		return ". " + body.strip_edges() + ". "
	# Larger blocks: spoken summary only — the user can read the panel.
	var label := lang if not lang.is_empty() else "code"
	return ". (See the panel for %d lines of %s.) " % [line_count, label]


func _strip_lonely_asterisks(line: String) -> String:
	# Remove lone '*' that wraps emphasis; keep '*' that sits between two
	# digits or letters (that's almost always multiplication or a glob).
	var out := ""
	var i := 0
	while i < line.length():
		var c: String = line[i]
		if c == "*":
			var prev := line[i - 1] if i > 0 else " "
			var nxt := line[i + 1] if i + 1 < line.length() else " "
			var is_mul := _alnum(prev) and _alnum(nxt)
			if not is_mul:
				i += 1
				continue
		out += c
		i += 1
	return out


func _alnum(c: String) -> bool:
	if c.is_empty():
		return false
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
