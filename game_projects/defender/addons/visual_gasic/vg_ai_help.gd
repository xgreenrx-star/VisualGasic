@tool
extends MarginContainer
## AI Help panel — talks to local Ollama or cloud providers (OpenAI, Claude, Gemini).
## Provides VisualGasic-aware code help, error explanations, and GDScript↔VG translation.

signal ai_panel_ready

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const OLLAMA_URL := "http://127.0.0.1:11434/api/generate"
const OLLAMA_HOST := "127.0.0.1"
const OLLAMA_PORT := 11434
const DEFAULT_MODEL := "qwen2.5-coder:7b"
const CONNECT_TIMEOUT := 3.0
const REQUEST_TIMEOUT := 300.0  # Cold model load can take 60-120s
const FIRST_TOKEN_TIMEOUT := 90.0  # Abort if no tokens arrive within this window (model runner may be hung)
const WARMUP_TIMEOUT := 180.0
const STREAM_POLL_INTERVAL := 0.016  # ~60 fps polling for streaming chunks

# Provider system
var AIProviders = null  # Loaded dynamically
var _provider_id := "ollama"
var _provider_info = null  # current ProviderInfo
var _provider_dropdown: OptionButton
var _api_key_btn: Button

const SYSTEM_PROMPT := """You are a VisualGasic (VG) programming assistant. VisualGasic is a VB6-syntax \
language that compiles to bytecode (with optional multi-tier JIT) and runs inside the \
Godot 4 game engine via GDExtension.

=== CORE SYNTAX ===
Variables:     Dim x As Integer  |  Dim name As String  |  Dim v As Variant
Subroutines:   Sub Name() ... End Sub
Functions:     Function Name(a As Integer) As String ... End Function
Conditionals:  If ... Then ... ElseIf ... Else ... End If
Loops:         For i = 1 To 10 Step 2 ... Next
               For Each item In collection ... Next
               Do While cond ... Loop  |  Do ... Loop Until cond
               While cond ... Wend
Select:        Select Case x ... Case 1 ... Case 2, 3 ... Case Is > 10 ... Case Else ... End Select
Comments:      ' single-line comment
String concat: & operator
Print:         Print "text"  (stdout)  |  Debug.Print "text" (Immediate Window)
Assertions:    Debug.Assert condition, "optional message"

=== SCOPE & DECLARATIONS ===
Public x As Integer     ' module-level, visible everywhere
Private y As String     ' module-level, internal only
Global z As Single      ' global across all modules
Static counter As Integer  ' retains value between calls inside a Sub/Function
Const PI = 3.14159

=== CLASSES ===
Class Person
    Private _name As String
    Private _age As Integer

    Sub Class_Initialize()   ' constructor — called by New
        _age = 0
    End Sub

    Property Get Name() As String
        Name = _name
    End Property

    Property Let Name(value As String)
        _name = value
    End Property

    Public Function Greet() As String
        Greet = "Hi, I'm " & _name
    End Function
End Class

Dim p = New Person
p.Name = "Alice"

Inherits:     Class Enemy  /  Inherits CharacterBody2D  /  End Class
Implements:   Implements IComparable

=== TYPE (User-Defined Structs) ===
Type Vector2D
    X As Integer
    Y As Integer
End Type
Dim pos As Vector2D
pos.X = 10 : pos.Y = 20

=== ENUM ===
Enum Direction
    North = 0
    East = 1
    South = 2
    West = 3
End Enum

=== FUNCTIONAL PROGRAMMING ===
Dim doubled  = Map(arr, Fn(x) => x * 2)
Dim evens    = Filter(arr, Fn(x) => x Mod 2 = 0)
Dim total    = Reduce(arr, Fn(acc, x) => acc + x, 0)
Dim hasLarge = Any(arr, Fn(x) => x > 100)
Dim allPos   = All(arr, Fn(x) => x > 0)
Dim first    = Find(arr, Fn(x) => x > 5)

Lambda forms:  Fn(x) => x * 2  |  Fn(x, y) => x + y
Block lambda:  Function(x) ... Return x * 2 ... End Function
Block sub:     Sub(x) ... Print x ... End Sub

=== MODERN OPERATORS ===
Compound:           +=  -=  *=  /=  &=  \\=  ^=  <<=  >>=
Increment/Decrement: ++  --
Null coalescing:     result = x ?? defaultValue
Optional chaining:   value = obj?.Property
String interpolation: msg = $"Hello {name}, you are {age} years old"
Range:               arr = [1..10]
Short-circuit:       If x > 0 AndAlso y / x > 2 Then ...
IIf:                 result = IIf(score >= 60, "Pass", "Fail")
Swap:                Swap a, b

=== ERROR HANDLING ===
On Error GoTo handler  |  On Error Resume Next  |  On Error GoTo 0
Try ... Catch ex As Exception ... Finally ... End Try
GoSub label ... Return  |  On expr GoTo label1, label2
On expr GoSub label1, label2

=== DATA / READ / RESTORE (classic BASIC) ===
Data 10, "Hello", 3.14
Read a, b, c
Restore        ' reset data pointer

=== GODOT INTEGRATION ===
Access nodes:     GetNode("name")  |  Me.controlName  |  Me.Name
Load scenes:      LoadForm "res://Scene.tscn"
Create controls:  CreateButton, CreateLabel, CreateTimer, CreateTextBox, CreateSprite2D
Signals:          ConnectSignal "body_entered", "OnBodyEntered"
                  DisconnectSignal "ready", "OnReady"
WithEvents:       Dim WithEvents obj As MyClass  ' auto-connects signal handlers

VB6 property aliases on Godot nodes (62+ aliases):
  Caption/Text → text,  Left → position.x,  Top → position.y
  Width → size.x,  Height → size.y,  Visible → visible
  Enabled → !disabled,  BackColor → self_modulate,  ForeColor → font_color
  FontSize, FontBold, FontItalic, FontName, Name, Tag, hWnd, Opacity, ZOrder

Events (auto-wired by naming convention  ControlName_EventName):
  Sub btnStart_Click()    ' button clicked
  Sub Timer1_Timer()      ' timer fires
  Sub txtName_Change()    ' text changed
  Sub Form_Load()         ' form loaded

Godot virtual callbacks:
  Sub _Ready()                 ' node enters scene tree
  Sub _Process(delta)          ' every graphics frame
  Sub _PhysicsProcess(delta)   ' every physics tick (60 Hz)
  Sub _Input(event)            ' input event received
  Sub _Draw()                  ' custom drawing

=== BUILT-INS ===
Constants: vbRed, vbBlue, vbGreen, vbWhite, vbBlack, vbCrLf, vbTab, True, False
Functions: Len, Left, Right, Mid, InStr, Replace, Split, Join, Trim, UCase, LCase,
           Val, Str, CInt, CLng, CDbl, Abs, Int, Rnd, Timer, Now, Format,
           MsgBox, InputBox, Print, Array(), Dictionary()

=== RULES ===
Keep answers concise. Always use VB6/VisualGasic syntax in code examples. \
Never use GDScript syntax unless the user explicitly asks for a translation."""

# ---------------------------------------------------------------------------
# UI nodes
# ---------------------------------------------------------------------------
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

# Main-thread HTTPClient streaming state (no threads — polls in timer)
var _stream_http: HTTPClient           # Persistent HTTP connection for streaming
var _stream_buf := ""                  # Partial JSON line buffer
var _poll_timer: Timer
var _stream_done := false              # True when Ollama sends done
var _stream_error := ""                # Non-empty on error
var _stream_started := false           # True once we've printed the "AI:" header
var _stream_token_count := 0           # Tokens received so far
var _stream_start_time := 0.0          # Time.get_ticks_msec() when query sent
var _stream_first_token_time := 0.0    # Time of first token (0 = not yet)
var _stream_http_phase := 0            # 0=idle, 1=connecting, 2=requesting, 3=body

# Preset quick-action buttons
var _explain_error_btn: Button
var _explain_code_btn: Button
var _translate_btn: Button

# Queued query — sent automatically once model warmup finishes
var _queued_query := ""

# Conversation history — last few exchanges for context-aware replies
# Each entry is { "role": "user"|"assistant", "content": "..." }
var _conversation_history: Array = []
const MAX_HISTORY_EXCHANGES := 3  # Keep last N user+assistant pairs (6 entries max)
var _current_prompt := ""  # Tracks the prompt of the in-flight query

# External context (set by plugin.gd)
var _last_error_context := {}
var _last_selected_code := ""

## Grab the current selection from the embedded VB6 code editor.
## Falls back to the text of the Sub/Function surrounding the caret,
## or _last_selected_code if the editor isn't reachable.
func _get_editor_selected_code() -> String:
	# 1. Try to reach the embedded code editor through the plugin instance
	var code_edit: CodeEdit = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			var plugin = base.get_meta("visual_gasic_plugin_instance")
			if plugin and is_instance_valid(plugin):
				# The plugin stores the embedded code editor in _embedded_code_editor
				if "_embedded_code_editor" in plugin:
					var ece = plugin._embedded_code_editor
					if is_instance_valid(ece) and ece.has_method("get_code_edit"):
						code_edit = ece.get_code_edit()

	if code_edit == null:
		return _last_selected_code

	# 2. If user has an active selection, use it
	if code_edit.has_selection():
		var sel := code_edit.get_selected_text()
		if not sel.strip_edges().is_empty():
			_last_selected_code = sel
			return sel

	# 3. No selection → extract the Sub/Function block the caret is inside
	var caret_line := code_edit.get_caret_line()
	var line_count := code_edit.get_line_count()

	# Walk upward to find "Sub " or "Function "
	var start_line := -1
	for i in range(caret_line, -1, -1):
		var lt := code_edit.get_line(i).strip_edges()
		if lt.begins_with("Sub ") or lt.begins_with("Private Sub ") or lt.begins_with("Public Sub ") \
			or lt.begins_with("Function ") or lt.begins_with("Private Function ") or lt.begins_with("Public Function "):
			start_line = i
			break

	if start_line < 0:
		return _last_selected_code  # caret isn't inside a Sub/Function

	# Walk downward to find "End Sub" or "End Function"
	var end_line := -1
	for i in range(start_line, line_count):
		var lt := code_edit.get_line(i).strip_edges()
		if lt == "End Sub" or lt == "End Function":
			end_line = i
			break

	if end_line < 0:
		return _last_selected_code

	# Collect the lines
	var lines := PackedStringArray()
	for i in range(start_line, end_line + 1):
		lines.append(code_edit.get_line(i))
	var result := "\n".join(lines)
	_last_selected_code = result
	return result

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Load the provider abstraction
	AIProviders = load("res://addons/visual_gasic/vg_ai_providers.gd")
	if AIProviders:
		_provider_id = AIProviders.load_preferred_provider()
		_provider_info = AIProviders.find_provider(_provider_id)
	if _provider_info == null:
		_provider_id = "ollama"
		_provider_info = AIProviders.find_provider("ollama") if AIProviders else null
	_setup_ui()
	_setup_poll_timer()
	_setup_http()
	_activate_provider()

func _enter_tree() -> void:
	if _ping_http:
		_reinit_after_reparent.call_deferred()

func _reinit_after_reparent() -> void:
	_ping_http.cancel_request()
	if _is_generating:
		_stop_generation()
	_warmup_http.cancel_request()
	if _health_check_http != null:
		_health_check_http.cancel_request()
	if _stream_http != null:
		_stream_http.close()
		_stream_http = null
	_health_pending_prompt = ""
	_is_generating = false
	_ollama_available = false
	_model_warm = false
	_stream_http_phase = 0
	_ping_ollama()

func _exit_tree() -> void:
	_stop_generation()

func _setup_poll_timer() -> void:
	_poll_timer = Timer.new()
	_poll_timer.name = "StreamPollTimer"
	_poll_timer.wait_time = 0.05  # 20 Hz — fast enough for smooth token display
	_poll_timer.one_shot = false
	_poll_timer.autostart = false
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_on_poll_timer)

## Main-thread timer callback — polls HTTPClient and processes tokens directly.
func _on_poll_timer() -> void:
	if not _is_generating:
		_poll_timer.stop()
		return

	if _stream_http == null:
		_stream_error = "HTTPClient was closed unexpectedly"
		_stream_done = true

	# --- Drive the HTTPClient state machine ---
	if not _stream_done and _stream_error.is_empty() and _stream_http != null:
		_stream_http.poll()
		var status := _stream_http.get_status()

		if _stream_http_phase == 1:  # Connecting
			if status == HTTPClient.STATUS_CONNECTED:
				# Connection established — send the request
				var headers: PackedStringArray
				var path: String
				if _provider_info and not _provider_info.is_local and not _cloud_request_headers.is_empty():
					# Cloud provider — use provider-specific headers and path
					headers = PackedStringArray(_cloud_request_headers)
					path = _cloud_request_path
				else:
					# Local Ollama
					headers = PackedStringArray(["Content-Type: application/json", "Accept: */*"])
					path = "/api/generate"
				var err := _stream_http.request(HTTPClient.METHOD_POST, path, headers, _stream_json_body)
				if err != OK:
					_stream_error = "Failed to send request: " + error_string(err)
					_stream_done = true
				else:
					_stream_http_phase = 2
			elif status != HTTPClient.STATUS_CONNECTING and status != HTTPClient.STATUS_RESOLVING:
				_stream_error = "Connection failed (status=%d)" % status
				_stream_done = true

		elif _stream_http_phase == 2:  # Requesting (waiting for response headers)
			if _stream_http.has_response():
				var code := _stream_http.get_response_code()
				if code != 200:
					var pname: String = _provider_info.display_name if _provider_info else "API"
					_stream_error = "%s error: HTTP %d" % [pname, code]
					_stream_done = true
				else:
					_stream_http_phase = 3
			elif status != HTTPClient.STATUS_REQUESTING and status != HTTPClient.STATUS_CONNECTED:
				_stream_error = "Lost connection waiting for response (status=%d)" % status
				_stream_done = true

		elif _stream_http_phase == 3:  # Reading body
			if status == HTTPClient.STATUS_BODY:
				var chunk := _stream_http.read_response_body_chunk()
				if chunk.size() > 0:
					_stream_buf += chunk.get_string_from_utf8()
					# Parse complete lines (JSON for Ollama, SSE for cloud)
					while _stream_buf.find("\n") >= 0:
						var nl := _stream_buf.find("\n")
						var line := _stream_buf.left(nl).strip_edges()
						_stream_buf = _stream_buf.substr(nl + 1)
						if line.is_empty():
							continue
						# Use provider-aware parser
						if AIProviders and _provider_info and not _provider_info.is_local:
							var parsed: Dictionary = AIProviders.parse_stream_line(_provider_id, line)
							var token: String = parsed.get("token", "")
							if not token.is_empty():
								_display_token(token)
							if parsed.get("done", false):
								_stream_done = true
								break
							if parsed.get("error", false):
								_stream_error = parsed.get("message", "Unknown API error")
								_stream_done = true
								break
						else:
							# Ollama: raw JSON lines
							if line[0] != "{":
								continue
							var json = JSON.parse_string(line)
							if json == null:
								continue
							var token: String = json.get("response", "")
							if not token.is_empty():
								_display_token(token)
							if json.get("done", false):
								_stream_done = true
								break
			elif status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_DISCONNECTED:
				# Body finished (connection closed or no more body)
				_stream_done = true

	# --- Check for completion or error ---
	if _stream_done or not _stream_error.is_empty():
		if _stream_started:
			_output.append_text("[/color]\n")
		if not _stream_error.is_empty():
			_append_system("[color=red]%s[/color]\n" % _stream_error)
		else:
			# Show timing stats
			var elapsed_ms := Time.get_ticks_msec() - _stream_start_time
			var elapsed_s := elapsed_ms / 1000.0
			if _stream_token_count > 0 and elapsed_s > 0:
				var tok_per_sec := _stream_token_count / elapsed_s
				var ttft := _stream_first_token_time - _stream_start_time if _stream_first_token_time > 0 else 0
				_append_system("[color=gray](%d tokens in %.1fs — %.1f tok/s, first token %.0fms)[/color]\n\n" % [
					_stream_token_count, elapsed_s, tok_per_sec, ttft])
			elif not _stream_started:
				_append_system("[color=gray](Empty response)[/color]\n")
		_finish_generation()
		return

	# Safety timeout — two tiers:
	# 1. If no tokens arrived at all, abort early (model runner likely hung)
	# 2. Overall hard timeout for very long responses
	var elapsed := (Time.get_ticks_msec() - _stream_start_time) / 1000.0
	if _is_generating:
		if not _stream_started and elapsed > FIRST_TOKEN_TIMEOUT:
			_stop_generation()
			var pname: String = _provider_info.display_name if _provider_info else "AI provider"
			_append_system("[color=red]No response from %s after %ds.[/color]\n" % [pname, int(FIRST_TOKEN_TIMEOUT)])
			if _provider_info and _provider_info.is_local:
				_append_system("[color=yellow]Try: [color=gray]sudo systemctl restart ollama[/color] then click Send again.[/color]\n")
			else:
				_append_system("[color=yellow]Check your API key and internet connection.[/color]\n")
			_model_warm = false  # Force re-warmup on next query
		elif elapsed > REQUEST_TIMEOUT:
			_stop_generation()
			_append_system("[color=red]Request timed out after %ds.[/color]\n" % int(REQUEST_TIMEOUT))

## Display a single token on screen (called from poll timer).
func _display_token(token: String) -> void:
	if not _stream_started:
		_stream_started = true
		_output.append_text("\n[color=#44bb88][b]AI:[/b][/color]\n[color=#dddddd]")
		_stream_first_token_time = Time.get_ticks_msec()
	_stream_token_count += 1
	_accumulated_response += token
	_output.append_text(_escape_bbcode(token))

## Clean up after generation completes normally.
func _finish_generation() -> void:
	_poll_timer.stop()
	_is_generating = false
	if _stream_http != null:
		_stream_http.close()
		_stream_http = null
	_stream_http_phase = 0

	# Save this exchange to conversation history for context-aware follow-ups
	if not _current_prompt.is_empty() and not _accumulated_response.is_empty():
		_conversation_history.append({"role": "user", "content": _current_prompt})
		_conversation_history.append({"role": "assistant", "content": _accumulated_response})
		# Trim to last N exchanges (N user + N assistant = 2N entries)
		while _conversation_history.size() > MAX_HISTORY_EXCHANGES * 2:
			_conversation_history.pop_front()
	_current_prompt = ""

	if is_instance_valid(_send_btn):
		_send_btn.visible = true
	if is_instance_valid(_stop_btn):
		_stop_btn.visible = false
	if is_instance_valid(_status_label):
		var pname: String = _provider_info.display_name if _provider_info else "Ollama"
		_status_label.text = ("✅ %s ready" % pname) if _ollama_available else ("❌ %s not found" % pname)
		_status_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if _ollama_available else Color(1.0, 0.4, 0.4))

## Force-stop generation (abort button or reparent).
func _stop_generation() -> void:
	# Stop the poll timer right away
	if is_instance_valid(_poll_timer):
		_poll_timer.stop()

	# Close the streaming HTTP connection
	if _stream_http != null:
		_stream_http.close()
		_stream_http = null

	_is_generating = false
	_stream_http_phase = 0
	_stream_done = false
	_stream_error = ""
	_stream_started = false
	_stream_token_count = 0
	_stream_buf = ""
	_accumulated_response = ""
	if is_instance_valid(_send_btn):
		_send_btn.visible = true
	if is_instance_valid(_stop_btn):
		_stop_btn.visible = false
	if is_instance_valid(_status_label):
		var pname: String = _provider_info.display_name if _provider_info else "Ollama"
		_status_label.text = ("✅ %s ready" % pname) if _ollama_available else ("❌ %s not found" % pname)
		_status_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if _ollama_available else Color(1.0, 0.4, 0.4))

func _setup_http() -> void:
	_ping_http = HTTPRequest.new()
	_ping_http.name = "PingRequest"
	_ping_http.timeout = CONNECT_TIMEOUT
	add_child(_ping_http)
	_ping_http.request_completed.connect(_on_ping_response)

	_warmup_http = HTTPRequest.new()
	_warmup_http.name = "WarmupRequest"
	_warmup_http.timeout = WARMUP_TIMEOUT
	_warmup_http.use_threads = true  # Warmup can take a while
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

	# ── Provider selector ──
	_provider_dropdown = OptionButton.new()
	_provider_dropdown.tooltip_text = "Select AI provider (Local or Cloud)"
	if AIProviders:
		for p in AIProviders.get_providers():
			_provider_dropdown.add_item(p.display_name)
		# Select saved provider
		var providers = AIProviders.get_providers()
		for i in range(providers.size()):
			if providers[i].id == _provider_id:
				_provider_dropdown.selected = i
				break
	else:
		_provider_dropdown.add_item("🏠 Ollama (Local)")
	_provider_dropdown.item_selected.connect(_on_provider_selected)
	_style_option_button(_provider_dropdown)
	toolbar.add_child(_provider_dropdown)

	# ── API Key button ──
	_api_key_btn = Button.new()
	_api_key_btn.text = "⚙️"
	_api_key_btn.tooltip_text = "Configure API keys for cloud providers"
	_api_key_btn.pressed.connect(_show_api_key_dialog)
	_style_small_button(_api_key_btn)
	toolbar.add_child(_api_key_btn)

	toolbar.add_child(_make_separator())

	_model_dropdown = OptionButton.new()
	_update_model_dropdown()
	_model_dropdown.item_selected.connect(_on_model_selected)
	_model_dropdown.tooltip_text = "Select model"
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
	_append_system("Providers: [color=cyan]Ollama[/color] (local), [color=green]OpenAI[/color], [color=#bb77ff]Claude[/color], [color=#4488ff]Gemini[/color]. Click ⚙️ to set API keys.\n")

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
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.32, 1.0)
	style.border_color = Color(0.45, 0.45, 0.55, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.35, 0.35, 0.42, 1.0)
	hover.border_color = Color(0.55, 0.55, 0.65, 0.8)
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
	opt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.24, 1.0)
	style.border_color = Color(0.4, 0.4, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	opt.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.25, 0.25, 0.32, 1.0)
	hover.border_color = Color(0.5, 0.5, 0.6, 0.8)
	opt.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.22, 0.22, 0.30, 1.0)
	opt.add_theme_stylebox_override("pressed", pressed)

# ---------------------------------------------------------------------------
# Ollama connectivity
# ---------------------------------------------------------------------------
func _ping_ollama() -> void:
	_status_label.text = "⏳ Checking Ollama..."
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	var err := _ping_http.request("http://127.0.0.1:11434/api/tags")
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
	_status_label.text = "🔥 Loading model (first query may be queued)..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	# Disable Send while model loads — queries will be queued instead
	if is_instance_valid(_send_btn):
		_send_btn.disabled = true
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
	# Enable Send button now that the model is ready
	if is_instance_valid(_send_btn):
		_send_btn.disabled = false
	# Fire any queued query that the user typed while the model was loading
	if not _queued_query.is_empty():
		var pending := _queued_query
		_queued_query = ""
		_append_system("[color=#44bb88]Sending queued query now...[/color]\n")
		# User message + history were already handled when the query was first queued,
		# so call _send_query_internal directly (skips health check too — warmup
		# just proved the model runner is alive).
		_send_query_internal(pending)

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

## Quick health check — verifies Ollama can accept requests before sending.
## Detects a hung model runner that still passes /api/tags but can't generate.
var _health_check_http: HTTPRequest
var _health_pending_prompt := ""

func _ensure_health_check_http() -> void:
	if _health_check_http == null:
		_health_check_http = HTTPRequest.new()
		_health_check_http.name = "HealthCheckRequest"
		_health_check_http.timeout = 10.0  # Fast check
		add_child(_health_check_http)
		_health_check_http.request_completed.connect(_on_health_check_response)
	else:
		_health_check_http.cancel_request()

func _on_health_check_response(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_append_system("[color=red]Ollama health check failed — the service may need restarting.[/color]\n")
		_append_system("[color=yellow]Try: [color=gray]sudo systemctl restart ollama[/color][/color]\n")
		_model_warm = false
		if is_instance_valid(_send_btn):
			_send_btn.visible = true
		if is_instance_valid(_stop_btn):
			_stop_btn.visible = false
		_health_pending_prompt = ""
		return
	# Health check passed — send the pending query
	if not _health_pending_prompt.is_empty():
		var p := _health_pending_prompt
		_health_pending_prompt = ""
		_send_query_internal(p)

func _send_query(prompt: String) -> void:
	if not _ollama_available:
		if _provider_info and _provider_info.is_local:
			_append_system("[color=yellow]Ollama is not running. Start it first.[/color]\n")
			_ping_ollama()
		else:
			_append_system("[color=yellow]%s is not ready. Check your API key (⚙️).[/color]\n" % (_provider_info.display_name if _provider_info else "Provider"))
			_activate_provider()
		return
	if _is_generating:
		_append_system("[color=yellow]Already generating — click Stop first.[/color]\n")
		return

	# Cloud providers — skip warmup and health check, send directly
	if _provider_info and not _provider_info.is_local:
		_history.append(prompt)
		_history_idx = _history.size()
		_input.text = ""
		_append_user(prompt)
		_send_cloud_query(prompt)
		return

	# If the model is still loading into memory, queue the query
	if not _model_warm:
		_queued_query = prompt
		_history.append(prompt)
		_history_idx = _history.size()
		_input.text = ""
		_append_user(prompt)
		_append_system("[color=#ffcc44]⏳ Model is still loading — your query will be sent automatically when ready...[/color]\n")
		# Re-trigger warmup so queued query doesn't sit forever
		_warmup_model()
		return

	# Run a fast health check before sending the real query
	_ensure_health_check_http()
	_health_pending_prompt = prompt
	_history.append(prompt)
	_history_idx = _history.size()
	_input.text = ""
	_append_user(prompt)
	var hc_body := JSON.stringify({"model": _current_model, "prompt": "", "stream": false, "options": {"num_predict": 0}})
	var hc_err := _health_check_http.request(OLLAMA_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, hc_body)
	if hc_err != OK:
		# Health check couldn't even start — just send directly
		_health_pending_prompt = ""
		_send_query_internal(prompt)
	return

## Internal: actually sends the query (called after health check passes).
var _stream_json_body := ""  # Stored for deferred sending after connect

func _send_query_internal(prompt: String) -> void:
	if _is_generating:
		return

	# Build context-aware prompt with conversation history
	var full_prompt := ""
	if _conversation_history.size() > 0:
		full_prompt += "Previous conversation:\n"
		for entry in _conversation_history:
			if entry["role"] == "user":
				full_prompt += "User: " + entry["content"] + "\n"
			else:
				full_prompt += "Assistant: " + entry["content"] + "\n"
		full_prompt += "\nCurrent question:\n"
	full_prompt += prompt
	_current_prompt = prompt

	# Build the request body — streaming mode
	var body := {
		"model": _current_model,
		"prompt": full_prompt,
		"system": SYSTEM_PROMPT,
		"stream": true,
		"options": {
			"temperature": 0.3,
			"num_predict": 2048,
		}
	}
	_stream_json_body = JSON.stringify(body)

	# Reset state
	_stream_done = false
	_stream_error = ""
	_stream_buf = ""
	_stream_started = false
	_stream_token_count = 0
	_stream_start_time = Time.get_ticks_msec()
	_stream_first_token_time = 0.0
	_accumulated_response = ""

	# Create HTTPClient and start non-blocking connect
	# The poll timer will drive the state machine (connect → request → read body)
	if _stream_http != null:
		_stream_http.close()
	_stream_http = HTTPClient.new()
	var err := _stream_http.connect_to_host(OLLAMA_HOST, OLLAMA_PORT)
	if err != OK:
		_stream_error = "Failed to connect to Ollama: " + error_string(err)
		_stream_done = true
		_stream_http = null

	_stream_http_phase = 1  # Connecting
	_is_generating = true
	_send_btn.visible = false
	_stop_btn.visible = true
	_status_label.text = "💭 Thinking..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_poll_timer.start()

func _on_stop() -> void:
	if _is_generating:
		_stop_generation()
		_append_system("[color=gray](Generation stopped)[/color]\n")

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
	var code := _get_editor_selected_code()
	if code.strip_edges().is_empty():
		_append_system("[color=yellow]No code selected. Select code in the editor first, or it will use the current Sub.[/color]\n")
		return
	var prompt := "Explain this VisualGasic code line by line:\n\n```vb\n%s\n```" % code
	_send_query(prompt)

func _on_translate() -> void:
	var code := _get_editor_selected_code()
	if code.strip_edges().is_empty():
		_append_system("[color=yellow]Select GDScript code in the editor first.[/color]\n")
		return
	var prompt := "Translate this GDScript code to VisualGasic (VB6 syntax):\n\n```gdscript\n%s\n```\n\nProvide only the VisualGasic translation." % code
	_send_query(prompt)

func _on_model_selected(idx: int) -> void:
	_current_model = _model_dropdown.get_item_text(idx)
	_append_system("Model changed to [color=cyan]%s[/color]\n" % _current_model)

func _on_clear() -> void:
	_output.clear()
	_conversation_history.clear()
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
	_activate_provider()

# ---------------------------------------------------------------------------
# Provider management
# ---------------------------------------------------------------------------

## Activate the currently selected provider — ping Ollama or verify API key.
func _activate_provider() -> void:
	if _provider_info == null:
		return
	if _provider_info.is_local:
		_ping_ollama()
	else:
		# Cloud provider — check if API key exists
		var key: String = AIProviders.load_api_key(_provider_id) if AIProviders else ""
		if key.is_empty():
			_ollama_available = false
			_status_label.text = "🔑 API key needed"
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			_append_system("[color=yellow]%s requires an API key. Click ⚙️ to configure.[/color]\n" % _provider_info.display_name)
		else:
			_ollama_available = true
			_model_warm = true  # Cloud providers don't need warmup
			_status_label.text = "✅ %s ready" % _provider_info.display_name
			_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			_append_system("Connected to [color=cyan]%s[/color] — model: [color=cyan]%s[/color]\n" % [_provider_info.display_name, _current_model])
			ai_panel_ready.emit()

func _on_provider_selected(idx: int) -> void:
	if not AIProviders:
		return
	var providers = AIProviders.get_providers()
	if idx < 0 or idx >= providers.size():
		return
	_provider_id = providers[idx].id
	_provider_info = providers[idx]
	_current_model = _provider_info.default_model
	_model_warm = false
	_ollama_available = false
	_conversation_history.clear()
	AIProviders.save_preferred_provider(_provider_id)
	_update_model_dropdown()
	_append_system("\nSwitched to [color=cyan]%s[/color]\n" % _provider_info.display_name)
	_activate_provider()

func _update_model_dropdown() -> void:
	if not is_instance_valid(_model_dropdown):
		return
	_model_dropdown.clear()
	if _provider_info:
		for m in _provider_info.models:
			_model_dropdown.add_item(m)
		# Select default
		var didx: int = _provider_info.models.find(_provider_info.default_model)
		_model_dropdown.selected = maxi(didx, 0)
		_current_model = _provider_info.default_model

# ---------------------------------------------------------------------------
# API Key Settings Dialog
# ---------------------------------------------------------------------------
func _show_api_key_dialog() -> void:
	if not AIProviders:
		return
	var dlg := AcceptDialog.new()
	dlg.title = "⚙️  AI Provider API Keys"
	dlg.size = Vector2(520, 400)
	dlg.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dlg.add_child(vbox)

	var desc := Label.new()
	desc.text = "Enter API keys for cloud AI providers.\nKeys are stored locally in user://vg_ai_keys.cfg"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	var key_edits := {}  # provider_id -> LineEdit
	for p in AIProviders.get_providers():
		if p.is_local:
			continue  # Skip Ollama
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)

		var lbl := Label.new()
		lbl.text = p.display_name + ":"
		lbl.custom_minimum_size.x = 120
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		var edit := LineEdit.new()
		edit.text = AIProviders.load_api_key(p.id)
		edit.placeholder_text = "sk-... / api-key-..."
		edit.secret = true
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_font_size_override("font_size", 12)
		hbox.add_child(edit)
		key_edits[p.id] = edit

		# Show/hide toggle
		var eye := Button.new()
		eye.text = "👁"
		eye.tooltip_text = "Show/hide key"
		eye.pressed.connect(func(): edit.secret = not edit.secret)
		hbox.add_child(eye)

	vbox.add_child(HSeparator.new())

	var hints := Label.new()
	hints.text = "Get keys from:\n• OpenAI: platform.openai.com/api-keys\n• Claude: console.anthropic.com/settings/keys\n• Gemini: aistudio.google.com/apikey"
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hints)

	dlg.confirmed.connect(func():
		for pid in key_edits:
			AIProviders.save_api_key(pid, key_edits[pid].text.strip_edges())
		_append_system("[color=green]API keys saved.[/color]\n")
		_activate_provider()
		dlg.queue_free()
	)

	# Use EditorInterface if available to host the dialog
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base:
			base.add_child(dlg)
		else:
			add_child(dlg)
	else:
		add_child(dlg)
	dlg.popup_centered()

# ---------------------------------------------------------------------------
# Cloud provider streaming
# ---------------------------------------------------------------------------

## Override _send_query_internal for cloud providers.
## Uses HTTPS via HTTPClient with TLS for cloud APIs.
func _send_cloud_query(prompt: String) -> void:
	if _is_generating:
		return
	if not AIProviders:
		return

	var api_key: String = AIProviders.load_api_key(_provider_id)
	if api_key.is_empty() and not _provider_info.is_local:
		_append_system("[color=yellow]No API key configured for %s. Click ⚙️ to set one.[/color]\n" % _provider_info.display_name)
		return

	var req_data: Dictionary = AIProviders.build_request(
		_provider_id, _current_model, SYSTEM_PROMPT,
		_conversation_history, prompt, api_key)

	_stream_json_body = req_data["body"]
	_current_prompt = prompt

	# Reset stream state
	_stream_done = false
	_stream_error = ""
	_stream_buf = ""
	_stream_started = false
	_stream_token_count = 0
	_stream_start_time = Time.get_ticks_msec()
	_stream_first_token_time = 0.0
	_accumulated_response = ""

	# Create HTTPClient and connect with TLS for cloud providers
	if _stream_http != null:
		_stream_http.close()
	_stream_http = HTTPClient.new()

	var host: String = _provider_info.api_host
	var port: int = _provider_info.api_port
	var err: int

	if _provider_info.use_tls:
		err = _stream_http.connect_to_host(host, port, TLSOptions.client())
	else:
		err = _stream_http.connect_to_host(host, port)

	if err != OK:
		_stream_error = "Failed to connect to %s: %s" % [host, error_string(err)]
		_stream_done = true
		_stream_http = null

	_cloud_request_headers = req_data["headers"]
	_cloud_request_path = req_data["path"]
	_stream_http_phase = 1  # Connecting
	_is_generating = true
	_send_btn.visible = false
	_stop_btn.visible = true
	_status_label.text = "💭 Thinking... (%s)" % _provider_info.display_name
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_poll_timer.start()

var _cloud_request_headers: Array = []
var _cloud_request_path: String = ""
