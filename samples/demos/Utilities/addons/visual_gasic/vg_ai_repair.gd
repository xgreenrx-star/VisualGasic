@tool
extends AcceptDialog
## VisualGasic AI Repair — "🩹 Fix with AI"
##
## Tier 2 of the AI roadmap (v5.1.x).  When the user hits the "🩹 Fix with AI"
## button on the Exception Assistant, this dialog:
##   1. Reads the affected .vg / .gd file and grabs context around the error line.
##   2. Sends a structured prompt to the configured AI provider asking for a JSON
##      patch (see PATCH_FORMAT below).
##   3. Parses the response, validates the patch, and shows a red/green diff
##      preview with the model's one-sentence explanation.
##   4. On Accept → writes the patched file back to disk and (when possible)
##      reloads the embedded code editor.  On Reject → closes silently.
##   5. Retry → re-asks the model with the same context.
##
## The dialog is self-contained: it talks directly to the provider via the
## existing vg_ai_providers.gd abstraction, but uses non-streaming requests so
## the response is a single JSON blob that's easy to parse.

signal repair_applied(file: String, line_count_changed: int)
signal repair_rejected()

const AIProviders := preload("res://addons/visual_gasic/vg_ai_providers.gd")

# How many lines of context above/below the error to send to the model.
const CONTEXT_BEFORE := 12
const CONTEXT_AFTER := 8

# Hard cap on the request — refuse to repair files larger than this many lines.
const MAX_FILE_LINES := 5000

# Network timeout (cold local models can take a while).
const REQUEST_TIMEOUT := 180.0

const SYSTEM_PROMPT := """You are a VisualGasic (VG) code-repair assistant.  VG uses VB6 syntax \
that compiles to bytecode.  Common syntax: Dim x As Integer | Sub Name()/End Sub | \
Function F() As T/End Function | If/ElseIf/Else/End If | For i = 1 To 10/Next | \
Do While/Loop | Class Name/End Class | Me.Property | & for string concat | ' comments.

VG has NO nested Sub/Function declarations. If the error is \
"Sub or Function not defined: X" but a `Sub X(...)`/`Function X(...)` clearly \
exists somewhere in the file, check whether it's mistakenly nested INSIDE \
another Sub's body (e.g. pasted in the middle of a different Sub instead of \
appended after its End Sub) — this compiles with no error but is never \
callable. The fix is to move it out to top-level scope as a sibling \
declaration, not to write a new stub function.

Your job: given a runtime error and the surrounding code, return a MINIMAL patch \
that fixes the bug.  Do not refactor.  Do not add features.  Preserve indentation."""

const PATCH_FORMAT := """Return ONLY a single JSON object — no markdown fences, no commentary.
Schema:
{
  "explanation": "one short sentence diagnosing the bug",
  "confidence": "high" | "medium" | "low",
  "patch": [
    { "line": <1-based line number from the original file>,
      "action": "replace" | "delete" | "insert_before" | "insert_after",
      "text":   "new line content (omit for delete; may contain leading whitespace)" }
  ]
}
Rules:
- "line" refers to the line numbers shown in the CODE block below.
- For multi-line replacements, emit consecutive entries (e.g. delete line 5, insert_after line 4 twice).
- Keep the patch minimal — ideally 1–3 entries.
- If you cannot fix the error confidently, return an empty patch and confidence:"low"."""

# ─── State ──────────────────────────────────────────────────────────────────
var _file_path: String = ""
var _error_line: int = 0
var _error_message: String = ""
var _error_code: int = 0
var _error_variables: Dictionary = {}

var _file_lines: PackedStringArray = PackedStringArray()
var _context_start_line: int = 1   # 1-based first line of the snippet sent to the model
var _patch: Array = []             # parsed patch entries
var _explanation: String = ""
var _confidence: String = ""

var _http: HTTPRequest
var _provider_id: String = "ollama"
var _provider_info = null
var _model: String = ""

# ─── UI ─────────────────────────────────────────────────────────────────────
var _status_label: Label
var _explanation_label: RichTextLabel
var _diff_view: RichTextLabel
var _apply_btn: Button
var _retry_btn: Button
var _cancel_btn: Button
var _spinner_timer: Timer
var _spinner_phase: int = 0

func _init() -> void:
	title = "🩹 Fix with AI"
	exclusive = true
	min_size = Vector2i(680, 480)
	get_ok_button().visible = false

func _ready() -> void:
	_setup_ui()
	# Match the configured provider + model from the AI Help panel preferences.
	_provider_id = AIProviders.load_preferred_provider()
	_provider_info = AIProviders.find_provider(_provider_id)
	if _provider_info == null:
		_provider_id = "ollama"
		_provider_info = AIProviders.find_provider("ollama")
	if _provider_info:
		_model = _provider_info.default_model

func _setup_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header — provider/status line
	var header := HBoxContainer.new()
	root.add_child(header)
	var icon := Label.new()
	icon.text = "🩹"
	icon.add_theme_font_size_override("font_size", 28)
	header.add_child(icon)
	var title_lbl := Label.new()
	title_lbl.text = "  Repair this error with AI"
	title_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(title_lbl)
	header.add_child(_make_spacer())
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(_status_label)

	root.add_child(HSeparator.new())

	# Explanation row
	var exp_lbl := Label.new()
	exp_lbl.text = "Diagnosis:"
	exp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	root.add_child(exp_lbl)

	_explanation_label = RichTextLabel.new()
	_explanation_label.bbcode_enabled = true
	_explanation_label.fit_content = true
	_explanation_label.custom_minimum_size = Vector2(0, 50)
	_explanation_label.text = "[color=gray]Waiting for AI response…[/color]"
	root.add_child(_explanation_label)

	# Diff preview
	var diff_lbl := Label.new()
	diff_lbl.text = "Proposed patch (red = remove, green = add):"
	diff_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	root.add_child(diff_lbl)

	_diff_view = RichTextLabel.new()
	_diff_view.bbcode_enabled = true
	_diff_view.scroll_active = true
	_diff_view.selection_enabled = true
	_diff_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diff_view.custom_minimum_size = Vector2(0, 240)
	_diff_view.add_theme_font_size_override("normal_font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	_diff_view.add_theme_stylebox_override("normal", style)
	root.add_child(_diff_view)

	root.add_child(HSeparator.new())

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	root.add_child(btn_row)

	_retry_btn = Button.new()
	_retry_btn.text = "🔄 Retry"
	_retry_btn.tooltip_text = "Ask the model again"
	_retry_btn.disabled = true
	_retry_btn.pressed.connect(_on_retry)
	btn_row.add_child(_retry_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "✗ Cancel"
	_cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(_cancel_btn)

	_apply_btn = Button.new()
	_apply_btn.text = "✓ Apply Patch"
	_apply_btn.tooltip_text = "Write the patch to disk"
	_apply_btn.disabled = true
	_apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(_apply_btn)

	# HTTP + spinner
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_http_response)

	_spinner_timer = Timer.new()
	_spinner_timer.wait_time = 0.25
	_spinner_timer.timeout.connect(_on_spinner)
	add_child(_spinner_timer)

func _make_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

# ─── Public API ─────────────────────────────────────────────────────────────

## Open the dialog and start a repair request for the given error.
func request_repair(file: String, line: int, message: String, code: int, variables: Dictionary) -> void:
	_file_path = file
	_error_line = line
	_error_message = message
	_error_code = code
	_error_variables = variables.duplicate()
	_patch.clear()
	_explanation = ""
	_confidence = ""
	_apply_btn.disabled = true
	_retry_btn.disabled = true
	_explanation_label.text = "[color=gray]Waiting for AI response…[/color]"
	_diff_view.clear()

	popup_centered()
	move_to_foreground()
	_send_repair_request()

# ─── Request building ───────────────────────────────────────────────────────

func _send_repair_request() -> void:
	if not _load_file_lines():
		return
	var prompt := _build_user_prompt()
	if prompt.is_empty():
		_show_error("Could not build a repair prompt (file too large or unreadable).")
		return

	# Force non-streaming for a clean single-blob response.
	var api_key: String = AIProviders.load_api_key(_provider_id) if _provider_info and not _provider_info.is_local else ""
	if _provider_info and not _provider_info.is_local and api_key.is_empty():
		_show_error("No API key configured for %s.  Open the AI Help panel ⚙️ to set one." % _provider_info.display_name)
		return

	var req: Dictionary = AIProviders.build_request(_provider_id, _model, SYSTEM_PROMPT, [], prompt, api_key)
	# Patch the body to disable streaming.
	var body_str: String = req.get("body", "")
	var body_obj = JSON.parse_string(body_str)
	if body_obj is Dictionary:
		body_obj["stream"] = false
		# OpenAI/Ollama use "stream"; Gemini ignores it (we'll switch endpoint below).
		body_str = JSON.stringify(body_obj)

	var headers: Array = req.get("headers", [])
	var path: String = req.get("path", "")

	# For Gemini, swap the streaming endpoint for the single-shot one.
	if _provider_id == "gemini":
		path = path.replace(":streamGenerateContent?alt=sse", ":generateContent?")

	# Build a fully-qualified URL.  HTTPRequest needs scheme + host.
	var url: String = ""
	if _provider_info.use_tls:
		url = "https://" + _provider_info.api_host + path
	else:
		url = "http://" + _provider_info.api_host + ":" + str(_provider_info.api_port) + path

	# Convert headers Array → PackedStringArray.
	var header_arr := PackedStringArray()
	for h in headers:
		header_arr.append(String(h))

	_status_label.text = "💭 Asking %s…" % (_provider_info.display_name if _provider_info else "AI")
	_spinner_phase = 0
	_spinner_timer.start()
	_apply_btn.disabled = true
	_retry_btn.disabled = true

	var err := _http.request(url, header_arr, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		_spinner_timer.stop()
		_show_error("Failed to send request: " + error_string(err))

func _on_spinner() -> void:
	var dots := ["·  ", "·· ", "···"]
	_status_label.text = "💭 Asking %s %s" % [
		(_provider_info.display_name if _provider_info else "AI"),
		dots[_spinner_phase % 3]]
	_spinner_phase += 1

func _load_file_lines() -> bool:
	_file_lines.clear()
	if _file_path.is_empty():
		_show_error("No source file recorded for this error — cannot build a repair prompt.")
		return false
	var f := FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		_show_error("Cannot read %s — file missing or no permission." % _file_path)
		return false
	var text := f.get_as_text()
	f.close()
	# Normalise line endings.
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	_file_lines = text.split("\n")
	if _file_lines.size() > MAX_FILE_LINES:
		_show_error("File has %d lines (limit %d) — too large for AI repair." % [_file_lines.size(), MAX_FILE_LINES])
		return false
	return true

func _build_user_prompt() -> String:
	# 1-based line numbers.  Clamp window to file extent.
	var first := maxi(1, _error_line - CONTEXT_BEFORE)
	var last := mini(_file_lines.size(), _error_line + CONTEXT_AFTER)
	_context_start_line = first

	var snippet := ""
	for i in range(first, last + 1):
		var marker := ">>> " if i == _error_line else "    "
		# _file_lines is 0-based.
		var raw_line: String = _file_lines[i - 1] if i - 1 < _file_lines.size() else ""
		snippet += "%s%5d | %s\n" % [marker, i, raw_line]

	var prompt := ""
	prompt += "ERROR:\n"
	prompt += "  File: %s\n" % _file_path.get_file()
	prompt += "  Line: %d\n" % _error_line
	prompt += "  Code: %d\n" % _error_code
	prompt += "  Message: %s\n" % _error_message
	if not _error_variables.is_empty():
		prompt += "\nVARIABLES at the crash site:\n"
		var count := 0
		for k in _error_variables.keys():
			if count >= 20:
				break
			var sv: String = str(_error_variables[k])
			if sv.length() > 80:
				sv = sv.substr(0, 80) + "…"
			prompt += "  %s = %s\n" % [str(k), sv]
			count += 1
	prompt += "\nCODE (line numbers shown, error marked with >>>):\n```vb\n"
	prompt += snippet
	prompt += "```\n\n"
	prompt += PATCH_FORMAT
	return prompt

# ─── Response parsing ───────────────────────────────────────────────────────

func _on_http_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_spinner_timer.stop()
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("HTTP error: %s" % error_string(result))
		return
	if code != 200:
		var snippet := body.get_string_from_utf8()
		if snippet.length() > 240:
			snippet = snippet.substr(0, 240) + "…"
		_show_error("HTTP %d from %s\n%s" % [code, _provider_info.display_name if _provider_info else "AI", snippet])
		return

	var raw_text := _extract_response_text(body.get_string_from_utf8())
	if raw_text.is_empty():
		_show_error("Empty response from the model.")
		return

	var json: Variant = _extract_json_blob(raw_text)
	if json == null:
		_show_error("Could not parse a JSON patch from the response.\n\nRaw reply:\n" + raw_text.substr(0, 800))
		return

	if not (json is Dictionary):
		_show_error("Model returned non-object JSON.")
		return

	_explanation = String(json.get("explanation", "")).strip_edges()
	_confidence = String(json.get("confidence", "")).strip_edges().to_lower()
	var patch_arr = json.get("patch", [])
	if not (patch_arr is Array):
		_show_error("Patch is not an array.")
		return

	_patch.clear()
	for entry in patch_arr:
		if not (entry is Dictionary):
			continue
		var line_n: int = int(entry.get("line", 0))
		var action: String = String(entry.get("action", "")).to_lower()
		var text: String = String(entry.get("text", ""))
		if line_n <= 0 or line_n > _file_lines.size():
			continue
		if not (action in ["replace", "delete", "insert_before", "insert_after"]):
			continue
		_patch.append({"line": line_n, "action": action, "text": text})

	if _patch.is_empty():
		_render_no_patch()
		return

	_render_diff()
	_apply_btn.disabled = false
	_retry_btn.disabled = false
	var conf_color := "yellow"
	if _confidence == "high":
		conf_color = "#88ff88"
	elif _confidence == "low":
		conf_color = "#ff8888"
	_status_label.text = ""
	_explanation_label.text = "[color=%s][b]%s[/b][/color] confidence — %s" % [
		conf_color,
		_confidence.capitalize() if not _confidence.is_empty() else "Unknown",
		_explanation if not _explanation.is_empty() else "(no diagnosis given)"]

## Pull the assistant's text from a non-streaming provider response.
func _extract_response_text(body_text: String) -> String:
	var parsed = JSON.parse_string(body_text)
	if parsed == null:
		return ""
	match _provider_id:
		"ollama":
			return String(parsed.get("response", ""))
		"openai":
			var choices = parsed.get("choices", [])
			if choices is Array and choices.size() > 0:
				var msg = choices[0].get("message", {})
				return String(msg.get("content", ""))
		"claude":
			var content_arr = parsed.get("content", [])
			if content_arr is Array and content_arr.size() > 0:
				return String(content_arr[0].get("text", ""))
		"gemini":
			var candidates = parsed.get("candidates", [])
			if candidates is Array and candidates.size() > 0:
				var c = candidates[0]
				var parts = c.get("content", {}).get("parts", [])
				if parts is Array and parts.size() > 0:
					return String(parts[0].get("text", ""))
	return ""

## Locate and parse a JSON object inside an LLM response.  Tolerates
## ```json fences and stray prose around the object.
func _extract_json_blob(text: String):
	var s := text.strip_edges()
	# Strip common fence patterns.
	if s.begins_with("```"):
		var first_nl := s.find("\n")
		if first_nl > 0:
			s = s.substr(first_nl + 1)
		if s.ends_with("```"):
			s = s.substr(0, s.length() - 3)
		s = s.strip_edges()

	# Try a direct parse first.
	var direct = JSON.parse_string(s)
	if direct is Dictionary:
		return direct

	# Fall back to brace-balance extraction.
	var start := s.find("{")
	if start < 0:
		return null
	var depth := 0
	var end := -1
	var i := start
	var in_str := false
	var escape := false
	while i < s.length():
		var ch := s[i]
		if in_str:
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				in_str = false
		else:
			if ch == "\"":
				in_str = true
			elif ch == "{":
				depth += 1
			elif ch == "}":
				depth -= 1
				if depth == 0:
					end = i
					break
		i += 1
	if end < 0:
		return null
	var blob := s.substr(start, end - start + 1)
	return JSON.parse_string(blob)

# ─── Diff rendering ─────────────────────────────────────────────────────────

func _render_no_patch() -> void:
	_explanation_label.text = "[color=#ffaa66]The model could not propose a patch.[/color]\n%s" % _explanation
	_diff_view.text = "[color=gray](no changes)[/color]"
	_apply_btn.disabled = true
	_retry_btn.disabled = false
	_status_label.text = ""

func _render_diff() -> void:
	# Group entries by their target line for compact display.
	var by_line: Dictionary = {}
	for e in _patch:
		var ln: int = e.line
		if not by_line.has(ln):
			by_line[ln] = []
		by_line[ln].append(e)

	var sorted_lines := by_line.keys()
	sorted_lines.sort()

	var out := ""
	for ln in sorted_lines:
		var entries: Array = by_line[ln]
		var orig: String = _file_lines[ln - 1] if ln - 1 < _file_lines.size() else ""
		out += "[color=gray]@@ line %d @@[/color]\n" % ln
		# Show the original line for context unless we're only inserting.
		var has_replace_or_delete := false
		for e in entries:
			if e.action == "replace" or e.action == "delete":
				has_replace_or_delete = true
				break
		if not has_replace_or_delete:
			# Pure insert — show context line in white first.
			out += "[color=#888888]  %s[/color]\n" % _esc(orig)

		for e in entries:
			match e.action:
				"replace":
					out += "[color=#ff7777]- %s[/color]\n" % _esc(orig)
					out += "[color=#77dd77]+ %s[/color]\n" % _esc(e.text)
				"delete":
					out += "[color=#ff7777]- %s[/color]\n" % _esc(orig)
				"insert_before":
					out += "[color=#77dd77]+ %s[/color]\n" % _esc(e.text)
					if not has_replace_or_delete:
						pass # context already shown
				"insert_after":
					if not has_replace_or_delete:
						pass # context already shown
					out += "[color=#77dd77]+ %s[/color]\n" % _esc(e.text)
		out += "\n"
	_diff_view.text = out

func _esc(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

# ─── Apply / Retry / Cancel ─────────────────────────────────────────────────

func _on_apply() -> void:
	var new_lines: Variant = _apply_patch_to_lines()
	if new_lines == null:
		_show_error("Patch failed to apply (line numbers no longer valid).")
		return

	# Write the file back.
	var f := FileAccess.open(_file_path, FileAccess.WRITE)
	if f == null:
		_show_error("Cannot write %s — file is read-only?" % _file_path)
		return
	f.store_string("\n".join(new_lines))
	f.close()

	var delta: int = new_lines.size() - _file_lines.size()
	repair_applied.emit(_file_path, delta)
	hide()

func _apply_patch_to_lines():
	# Build an edit list keyed by original line number, then walk the file
	# once producing the patched output.
	var edits_by_line: Dictionary = {}
	for e in _patch:
		var ln: int = e.line
		if not edits_by_line.has(ln):
			edits_by_line[ln] = []
		edits_by_line[ln].append(e)

	var out := PackedStringArray()
	for one_based in range(1, _file_lines.size() + 1):
		var orig: String = _file_lines[one_based - 1]
		var entries: Array = edits_by_line.get(one_based, [])
		var skip_orig := false

		# insert_before fires first.
		for e in entries:
			if e.action == "insert_before":
				out.append(e.text)
		# replace / delete consume the original.
		for e in entries:
			if e.action == "replace":
				out.append(e.text)
				skip_orig = true
			elif e.action == "delete":
				skip_orig = true
		if not skip_orig:
			out.append(orig)
		# insert_after last.
		for e in entries:
			if e.action == "insert_after":
				out.append(e.text)
	return out

func _on_retry() -> void:
	_send_repair_request()

func _on_cancel() -> void:
	repair_rejected.emit()
	hide()

# ─── Error helper ───────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	_spinner_timer.stop()
	_status_label.text = ""
	_explanation_label.text = "[color=#ff8888][b]✗ %s[/b][/color]" % msg
	_diff_view.text = ""
	_apply_btn.disabled = true
	_retry_btn.disabled = false
