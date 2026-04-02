@tool
extends MarginContainer
## AI Help panel — talks to a local Ollama instance (free, no subscription).
## Provides VisualGasic-aware code help, error explanations, and GDScript↔VG translation.

signal ai_panel_ready

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const OLLAMA_URL := "http://localhost:11434/api/generate"
const DEFAULT_MODEL := "qwen2.5-coder:7b"
const CONNECT_TIMEOUT := 3.0
const REQUEST_TIMEOUT := 300.0  # Cold model load can take 60-120s
const WARMUP_TIMEOUT := 180.0

const SYSTEM_PROMPT := """You are a VisualGasic programming assistant. VisualGasic is a VB6-syntax language that compiles to bytecode and runs inside the Godot 4 game engine via GDExtension.

Key syntax rules:
- Variables: Dim x As Integer, Dim name As String
- Subroutines: Sub name() ... End Sub
- Functions: Function name() As Type ... End Function
- Conditionals: If ... Then ... ElseIf ... Else ... End If
- Loops: For i = 1 To 10 ... Next, Do While ... Loop, Do ... Loop Until
- Select: Select Case x ... Case 1 ... Case Else ... End Select
- Classes: Class MyClass ... End Class
- Error handling: On Error GoTo handler / On Error Resume Next
- String concat: & operator
- Print to console: Print "text"
- Comments: ' single-line comment

VB6 property aliases on Godot nodes:
- Caption/Text → text, Left → position.x, Top → position.y
- Width → size.x, Height → size.y, Visible → visible
- Enabled → !disabled, BackColor → self_modulate, ForeColor → font_color
- FontSize, FontBold, FontItalic, FontName, Name, Tag, hWnd, Opacity, ZOrder

Events use auto-wiring — name the Sub ControlName_EventName():
- Sub btnStart_Click()  — button clicked
- Sub Timer1_Timer()    — timer fires
- Sub txtName_Change()  — text changed
- Sub Form_Load()       — form loaded

Access nodes: GetNode("name"), Me.controlName, Me.Name
Load scenes: LoadForm "res://Scene.tscn"
Create controls: CreateButton, CreateLabel, CreateTimer, CreateTextBox, CreateSprite2D

Built-in constants: vbRed, vbBlue, vbGreen, vbWhite, vbBlack, vbCrLf, vbTab, True, False
Built-in functions: Len, Left, Right, Mid, InStr, Replace, Split, Join, Trim, UCase, LCase, Val, Str, CInt, CLng, CDbl, Abs, Int, Rnd, Timer, Now, Format, MsgBox, InputBox, Print

Keep answers concise and use VB6/VisualGasic syntax in all code examples. Never use GDScript syntax unless the user explicitly asks for a translation."""

# ---------------------------------------------------------------------------
# UI nodes
# ---------------------------------------------------------------------------
var _http: HTTPRequest
var _ping_http: HTTPRequest
var _warmup_http: HTTPRequest
var _output: RichTextLabel
var _input: CodeEdit
var _send_btn: Button
var _model_dropdown: OptionButton
var _status_label: Label
var _clear_btn: Button
var _stop_btn: Button

var _ollama_available := false
var _is_generating := false
var _model_warm := false
var _current_model := DEFAULT_MODEL
var _history: PackedStringArray = PackedStringArray()
var _history_idx := -1
var _accumulated_response := ""

# Preset quick-action buttons
var _explain_error_btn: Button
var _explain_code_btn: Button
var _translate_btn: Button

# External context (set by plugin.gd)
var _last_error_context := {}
var _last_selected_code := ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_setup_ui()
	_setup_http()
	_ping_ollama()

func _enter_tree() -> void:
	# When the panel is reparented (e.g. from plugin → bottom tab),
	# _ready() doesn't fire again, but the pending HTTP requests were
	# cancelled when the node exited the tree.  Re-ping to recover.
	if _ping_http:  # Guard: skip the very first _enter_tree (before _ready)
		_reinit_after_reparent.call_deferred()

## Cancel stale HTTP state and re-ping Ollama after reparent.
func _reinit_after_reparent() -> void:
	_ping_http.cancel_request()
	if _is_generating:
		_http.cancel_request()
	_warmup_http.cancel_request()
	_is_generating = false
	_ollama_available = false
	_model_warm = false
	_ping_ollama()

func _setup_http() -> void:
	_http = HTTPRequest.new()
	_http.name = "AIRequest"
	_http.timeout = REQUEST_TIMEOUT
	_http.use_threads = true  # Required: Ollama uses chunked encoding for long responses
	add_child(_http)
	_http.request_completed.connect(_on_response)

	_ping_http = HTTPRequest.new()
	_ping_http.name = "PingRequest"
	_ping_http.timeout = CONNECT_TIMEOUT
	add_child(_ping_http)
	_ping_http.request_completed.connect(_on_ping_response)

	_warmup_http = HTTPRequest.new()
	_warmup_http.name = "WarmupRequest"
	_warmup_http.timeout = WARMUP_TIMEOUT
	add_child(_warmup_http)
	_warmup_http.request_completed.connect(_on_warmup_response)

# ---------------------------------------------------------------------------
# UI construction — all in code, matching Immediate Window patterns
# ---------------------------------------------------------------------------
func _setup_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# --- Toolbar ---
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	main_vbox.add_child(toolbar)

	var title := Label.new()
	title.text = "🤖 AI Help"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	toolbar.add_child(title)

	toolbar.add_child(_make_separator())

	_model_dropdown = OptionButton.new()
	_model_dropdown.add_item("qwen2.5-coder:7b")
	_model_dropdown.add_item("deepseek-coder-v2:16b")
	_model_dropdown.add_item("codellama:7b")
	_model_dropdown.add_item("phi3:mini")
	_model_dropdown.add_item("llama3.1:8b")
	_model_dropdown.add_item("gemma2:9b")
	_model_dropdown.item_selected.connect(_on_model_selected)
	_model_dropdown.tooltip_text = "Select Ollama model"
	_style_option_button(_model_dropdown)
	toolbar.add_child(_model_dropdown)

	toolbar.add_child(_make_separator())

	_status_label = Label.new()
	_status_label.text = "⏳ Checking Ollama..."
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	toolbar.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_clear_btn = Button.new()
	_clear_btn.text = "🗑 Clear"
	_clear_btn.tooltip_text = "Clear conversation"
	_clear_btn.pressed.connect(_on_clear)
	_style_small_button(_clear_btn)
	toolbar.add_child(_clear_btn)

	# --- Quick action buttons ---
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	main_vbox.add_child(actions)

	_explain_error_btn = Button.new()
	_explain_error_btn.text = "🐛 Explain Last Error"
	_explain_error_btn.tooltip_text = "Ask AI to explain the last runtime error"
	_explain_error_btn.pressed.connect(_on_explain_error)
	_style_action_button(_explain_error_btn, Color(1.0, 0.5, 0.5))
	actions.add_child(_explain_error_btn)

	_explain_code_btn = Button.new()
	_explain_code_btn.text = "📖 Explain Code"
	_explain_code_btn.tooltip_text = "Explain selected code or current Sub"
	_explain_code_btn.pressed.connect(_on_explain_code)
	_style_action_button(_explain_code_btn, Color(0.5, 0.8, 1.0))
	actions.add_child(_explain_code_btn)

	_translate_btn = Button.new()
	_translate_btn.text = "🔄 GDScript → VG"
	_translate_btn.tooltip_text = "Translate GDScript to VisualGasic"
	_translate_btn.pressed.connect(_on_translate)
	_style_action_button(_translate_btn, Color(0.6, 1.0, 0.6))
	actions.add_child(_translate_btn)

	# --- Output area ---
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 13)

	var out_style := StyleBoxFlat.new()
	out_style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	out_style.set_content_margin_all(8)
	out_style.set_corner_radius_all(4)
	_output.add_theme_stylebox_override("normal", out_style)
	main_vbox.add_child(_output)

	_append_system("AI Help is ready. Type a question below or use the quick actions.\n")
	_append_system("Requires [color=cyan]Ollama[/color] running locally: [color=gray]curl -fsSL https://ollama.com/install.sh | sh[/color]\n")

	# --- Input row ---
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(input_row)

	_input = CodeEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size.y = 60
	_input.placeholder_text = "Ask about VisualGasic, Godot, VB6 syntax..."
	_input.scroll_past_end_of_file = false
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.gutters_draw_line_numbers = false
	_input.gui_input.connect(_on_input_key)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	input_style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	input_style.set_border_width_all(1)
	input_style.set_content_margin_all(6)
	input_style.set_corner_radius_all(4)
	_input.add_theme_stylebox_override("normal", input_style)

	var input_focus := input_style.duplicate()
	input_focus.border_color = Color(0.4, 0.65, 1.0, 1.0)
	_input.add_theme_stylebox_override("focus", input_focus)
	_input.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	input_row.add_child(_input)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)
	input_row.add_child(btn_col)

	_send_btn = Button.new()
	_send_btn.text = "Send"
	_send_btn.custom_minimum_size = Vector2(70, 0)
	_send_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_send_btn.pressed.connect(_on_send)
	_style_send_button(_send_btn)
	btn_col.add_child(_send_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.custom_minimum_size = Vector2(70, 0)
	_stop_btn.pressed.connect(_on_stop)
	_stop_btn.visible = false
	_style_stop_button(_stop_btn)
	btn_col.add_child(_stop_btn)

# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------
func _make_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	return sep

func _style_small_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.3, 0.3, 0.35, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

func _style_action_button(btn: Button, color: Color) -> void:
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.8)
	style.border_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.9)
	btn.add_theme_stylebox_override("hover", hover)

func _style_send_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.45, 0.8, 1.0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var hover := style.duplicate()
	hover.bg_color = Color(0.3, 0.55, 0.9, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

func _style_stop_button(btn: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.7, 0.2, 0.2, 1.0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var hover := style.duplicate()
	hover.bg_color = Color(0.85, 0.3, 0.3, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

func _style_option_button(opt: OptionButton) -> void:
	opt.add_theme_font_size_override("font_size", 11)

# ---------------------------------------------------------------------------
# Ollama connectivity
# ---------------------------------------------------------------------------
func _ping_ollama() -> void:
	_status_label.text = "⏳ Checking Ollama..."
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	var err := _ping_http.request("http://localhost:11434/api/tags")
	if err != OK:
		_set_offline()

func _on_ping_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_offline()
		return
	_ollama_available = true
	_status_label.text = "✅ Ollama connected"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	# Parse available models and update dropdown
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("models"):
		_model_dropdown.clear()
		var found_default := false
		for m in json["models"]:
			var model_name: String = m.get("name", "")
			if not model_name.is_empty():
				_model_dropdown.add_item(model_name)
				if model_name == _current_model or model_name.begins_with(_current_model.split(":")[0]):
					found_default = true
					_model_dropdown.select(_model_dropdown.item_count - 1)
		if not found_default and _model_dropdown.item_count > 0:
			_model_dropdown.select(0)
			_current_model = _model_dropdown.get_item_text(0)
	_append_system("Connected to Ollama. Model: [color=cyan]%s[/color]\n" % _current_model)
	ai_panel_ready.emit()
	# Pre-warm the model so the first real query doesn't wait 60+ seconds
	if not _model_warm:
		_warmup_model()

func _set_offline() -> void:
	_ollama_available = false
	_status_label.text = "❌ Ollama not found"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_append_system("[color=yellow]Ollama is not running.[/color] Install it with:\n")
	_append_system("[color=gray]  curl -fsSL https://ollama.com/install.sh | sh[/color]\n")
	_append_system("[color=gray]  ollama pull %s[/color]\n" % DEFAULT_MODEL)
	_append_system("[color=gray]  ollama serve[/color]\n\n")

# ---------------------------------------------------------------------------
# Model pre-warming — load the model into memory in the background so the
# first real query doesn't stall for 60–120 seconds.
# ---------------------------------------------------------------------------
func _warmup_model() -> void:
	if _model_warm or not _ollama_available:
		return
	_status_label.text = "🔥 Loading model..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	var body := JSON.stringify({
		"model": _current_model,
		"prompt": "hi",
		"stream": false,
		"options": {"num_predict": 1},
	})
	var headers := ["Content-Type: application/json"]
	var err := _warmup_http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		# Non-critical — the first real query will just be slower
		_status_label.text = "✅ Ollama connected"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

func _on_warmup_response(result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_model_warm = true
	if result == HTTPRequest.RESULT_SUCCESS:
		_status_label.text = "✅ Ready"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_append_system("[color=green]Model loaded and ready.[/color]\n")
	else:
		# Warmup failed — non-critical, just reset status
		_status_label.text = "✅ Ollama connected"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------
func _on_input_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and not event.shift_pressed:
			_input.get_viewport().set_input_as_handled()
			_on_send()
		elif event.keycode == KEY_UP and _input.get_caret_line() == 0:
			_navigate_history(-1)
		elif event.keycode == KEY_DOWN and _input.get_caret_line() == _input.get_line_count() - 1:
			_navigate_history(1)

func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_idx = clampi(_history_idx + direction, 0, _history.size() - 1)
	_input.text = _history[_history_idx]
	_input.set_caret_line(_input.get_line_count() - 1)
	_input.set_caret_column(_input.get_line(_input.get_caret_line()).length())

# ---------------------------------------------------------------------------
# Sending queries
# ---------------------------------------------------------------------------
func _on_send() -> void:
	var prompt := _input.text.strip_edges()
	if prompt.is_empty():
		return
	_send_query(prompt)

func _send_query(prompt: String) -> void:
	if not _ollama_available:
		_append_system("[color=yellow]Ollama is not running. Start it first.[/color]\n")
		_ping_ollama()
		return
	if _is_generating:
		_append_system("[color=yellow]Already generating — click Stop first.[/color]\n")
		return

	# Save to history
	_history.append(prompt)
	_history_idx = _history.size()
	_input.text = ""

	# Show the user's question
	_append_user(prompt)

	# Build the request
	var body := {
		"model": _current_model,
		"prompt": prompt,
		"system": SYSTEM_PROMPT,
		"stream": false,
		"options": {
			"temperature": 0.3,
			"num_predict": 2048,
		}
	}

	var headers := ["Content-Type: application/json"]
	var json_body := JSON.stringify(body)
	var err := _http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_append_system("[color=red]Failed to send request: %s[/color]\n" % error_string(err))
		return

	_is_generating = true
	_send_btn.visible = false
	_stop_btn.visible = true
	_status_label.text = "💭 Thinking..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

func _on_stop() -> void:
	if _is_generating:
		_http.cancel_request()
		_is_generating = false
		_send_btn.visible = true
		_stop_btn.visible = false
		_status_label.text = "✅ Ollama connected"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_append_system("[color=gray](Generation stopped)[/color]\n")

# ---------------------------------------------------------------------------
# Response handling
# ---------------------------------------------------------------------------
func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_generating = false
	_send_btn.visible = true
	_stop_btn.visible = false
	_status_label.text = "✅ Ollama connected"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	if result != HTTPRequest.RESULT_SUCCESS:
		_append_system("[color=red]Request failed (result=%d). Is Ollama still running?[/color]\n" % result)
		_ping_ollama()
		return

	if code != 200:
		var error_text := body.get_string_from_utf8()
		_append_system("[color=red]Ollama returned HTTP %d: %s[/color]\n" % [code, error_text.left(200)])
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_append_system("[color=red]Failed to parse Ollama response.[/color]\n")
		return

	var response_text: String = json.get("response", "")
	if response_text.is_empty():
		_append_system("[color=gray](Empty response)[/color]\n")
		return

	_append_ai(response_text)

	# Show timing info
	var total_ns: int = json.get("total_duration", 0)
	var eval_count: int = json.get("eval_count", 0)
	if total_ns > 0:
		var secs := total_ns / 1_000_000_000.0
		var tok_per_sec := eval_count / secs if secs > 0 else 0
		_append_system("[color=gray](%d tokens in %.1fs — %.1f tok/s)[/color]\n\n" % [eval_count, secs, tok_per_sec])

# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------
func _append_user(text: String) -> void:
	_output.append_text("\n[color=#6688cc][b]You:[/b][/color]\n")
	_output.append_text("[color=#cccccc]%s[/color]\n" % _escape_bbcode(text))

func _append_ai(text: String) -> void:
	_output.append_text("\n[color=#44bb88][b]AI:[/b][/color]\n")
	# Convert markdown code blocks to BBCode
	var formatted := _format_code_blocks(text)
	_output.append_text(formatted + "\n")

func _append_system(text: String) -> void:
	_output.append_text("[color=gray]%s[/color]" % text)

func _escape_bbcode(text: String) -> String:
	# Character-by-character to avoid double-escaping
	# (the old .replace("[","[lb]").replace("]","[rb]") mangled [lb] → [lb[rb])
	var result := ""
	for i in text.length():
		var c := text[i]
		if c == "[":
			result += "[lb]"
		elif c == "]":
			result += "[rb]"
		else:
			result += c
	return result

func _format_code_blocks(text: String) -> String:
	# Convert ```vb ... ``` or ```bas ... ``` blocks to colored BBCode
	var result := ""
	var lines := text.split("\n")
	var in_code := false

	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("```") and not in_code:
			in_code = true
			result += "[color=#1a1a2e]━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n"
			continue
		elif stripped == "```" and in_code:
			in_code = false
			result += "[color=#1a1a2e]━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n"
			continue

		if in_code:
			result += "[color=#e0c080]%s[/color]\n" % _escape_bbcode(line)
		else:
			# Bold markdown **text** → BBCode [b]text[/b]
			var formatted_line := line
			while formatted_line.find("**") >= 0:
				var start := formatted_line.find("**")
				var end := formatted_line.find("**", start + 2)
				if end < 0:
					break
				var before := formatted_line.left(start)
				var bold_text := formatted_line.substr(start + 2, end - start - 2)
				var after := formatted_line.substr(end + 2)
				formatted_line = before + "[b]" + bold_text + "[/b]" + after
			# Inline code `text` → colored
			while formatted_line.find("`") >= 0:
				var start := formatted_line.find("`")
				var end := formatted_line.find("`", start + 1)
				if end < 0:
					break
				var before := formatted_line.left(start)
				var code_text := formatted_line.substr(start + 1, end - start - 1)
				var after := formatted_line.substr(end + 1)
				formatted_line = before + "[color=#e0c080]" + _escape_bbcode(code_text) + "[/color]" + after
			result += "[color=#dddddd]%s[/color]\n" % formatted_line

	return result

# ---------------------------------------------------------------------------
# Quick actions
# ---------------------------------------------------------------------------
func _on_explain_error() -> void:
	if _last_error_context.is_empty():
		_append_system("[color=yellow]No error to explain. Run your program and trigger an error first.[/color]\n")
		return
	var prompt := "Explain this VisualGasic runtime error and suggest a fix:\n\n"
	prompt += "File: %s\n" % _last_error_context.get("file", "unknown")
	prompt += "Line: %s\n" % str(_last_error_context.get("line", "?"))
	prompt += "Error: %s\n" % _last_error_context.get("message", "unknown error")
	if _last_error_context.has("code_context"):
		prompt += "\nCode around the error:\n```vb\n%s\n```\n" % _last_error_context["code_context"]
	if _last_error_context.has("variables"):
		prompt += "\nVariable values at the time of error:\n"
		for k in _last_error_context["variables"]:
			prompt += "  %s = %s\n" % [k, str(_last_error_context["variables"][k])]
	_send_query(prompt)

func _on_explain_code() -> void:
	if _last_selected_code.strip_edges().is_empty():
		_append_system("[color=yellow]No code selected. Select code in the editor first, or it will use the current Sub.[/color]\n")
		return
	var prompt := "Explain this VisualGasic code line by line:\n\n```vb\n%s\n```" % _last_selected_code
	_send_query(prompt)

func _on_translate() -> void:
	if _last_selected_code.strip_edges().is_empty():
		_append_system("[color=yellow]Select GDScript code in the editor first.[/color]\n")
		return
	var prompt := "Translate this GDScript code to VisualGasic (VB6 syntax):\n\n```gdscript\n%s\n```\n\nProvide only the VisualGasic translation." % _last_selected_code
	_send_query(prompt)

func _on_model_selected(idx: int) -> void:
	_current_model = _model_dropdown.get_item_text(idx)
	_append_system("Model changed to [color=cyan]%s[/color]\n" % _current_model)

func _on_clear() -> void:
	_output.clear()
	_append_system("Conversation cleared.\n")

# ---------------------------------------------------------------------------
# Public API — called from plugin.gd
# ---------------------------------------------------------------------------

## Called by the exception assistant when the user clicks "Ask AI"
func set_error_context(file: String, line: int, message: String, variables: Dictionary = {}, code_context: String = "") -> void:
	_last_error_context = {
		"file": file,
		"line": line,
		"message": message,
		"variables": variables,
		"code_context": code_context,
	}

## Called by the code editor to pass the current selection
func set_selected_code(code: String) -> void:
	_last_selected_code = code

## Ask a question programmatically (used by "Ask AI" button in exception assistant)
func ask(prompt: String) -> void:
	_send_query(prompt)

## Retry Ollama connection
func retry_connection() -> void:
	_ping_ollama()
