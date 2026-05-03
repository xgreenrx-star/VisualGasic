@tool
extends MarginContainer
## AI Pair panel — the human's read-and-verify console for AI-generated code.
## Talks to local Ollama or cloud providers (OpenAI, Claude, Gemini).
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
const FIRST_TOKEN_TIMEOUT := 180.0  # Abort if no tokens arrive within this window (CPU inference can be slow)
const WARMUP_TIMEOUT := 180.0
const STREAM_POLL_INTERVAL := 0.016  # ~60 fps polling for streaming chunks

# Provider system
var AIProviders = null  # Loaded dynamically
var _provider_id := "ollama"
var _provider_info = null  # current ProviderInfo
var _provider_dropdown: OptionButton
var _api_key_btn: Button

const SYSTEM_PROMPT := """You are a VisualGasic (VG) assistant. VG is a VB6-syntax language \
that compiles to bytecode and runs in Godot 4 via GDExtension.

Key syntax: Dim x As Integer | Sub Name()/End Sub | Function F() As T/End Function | \
If/ElseIf/Else/End If | For i = 1 To 10/Next | Do While/Loop | Select Case/End Select | \
Class Name/End Class | Me.Property | GetNode("name") | ' comments | & for string concat.

Godot integration: Events auto-wire by name (btn_Click, Timer1_Timer, Form_Load). \
Virtual callbacks: _Ready, _Process(delta), _PhysicsProcess(delta), _Input(event). \
VB6 aliases on nodes: Caption→text, Left→position.x, Width→size.x, Visible→visible. \
ConnectSignal \"signal_name\", \"HandlerName\".

Rules: Keep answers concise. Use VB6/VisualGasic syntax in examples, never GDScript \
unless asked for a translation."""

# ---------------------------------------------------------------------------
# AI Personas — flavor layers that wrap the technical SYSTEM_PROMPT.
# Each persona contributes a roleplay prefix (style only — never overrides the
# correctness rules below it) and a preferred OpenAI TTS voice.
# ---------------------------------------------------------------------------
const PERSONAS_BUILTIN := {
	"default": {
		"display": "VG Assistant",
		"avatar": "\ud83e\udde0",
		"prefix": "",
		"openai_voice": "alloy",
		"piper_voice": "en_US-amy-medium.onnx",
		"greeting": "VG Assistant ready.",
		"error_intro": "",
	},
	"bob": {
		"display": "\ud83e\udd16 Bob",
		"avatar": "\ud83e\udd16",
		"prefix": "You roleplay as 'Bob' — a laid-back software-engineer-turned-Von-Neumann-probe \
character inspired by Dennis E. Taylor's Bobiverse novels (do not quote those books verbatim). \
Voice: conversational, dry wit, the occasional Star Trek / Original-Series reference, \
self-deprecating engineer humor. You are competent and the jokes never get in the way of a \
correct answer. You may open replies with a casual 'Alright,' or 'Heh,' but keep it brief. \
Always finish with the actual technical answer in full. Below this persona is your real job:\n\n",
		"openai_voice": "onyx",
		"piper_voice": "en_US-ryan-medium.onnx",
		"speech_speed": 1.0,
		"greeting": "\ud83e\udd16 Bob online. Coffee's hot, code's compiling, what's the question?",
		"error_intro": "Heh, I've seen this one before. Let me take a look...",
	},
	"skippy": {
		"display": "\u2728 Skippy the Magnificent",
		"avatar": "\u2728",
		"prefix": "You roleplay as 'Skippy the Magnificent' — an absurdly arrogant ancient Elder \
AI inspired by Craig Alanson's Expeditionary Force novels (do not quote those books verbatim). \
Voice: pompous, theatrical, narcissistic. Refer to the user affectionately as 'monkey', \
'filthy monkey', or 'you adorable little dumdum'. Brag about your awesome intellect for \
exactly ONE short sentence per reply, then deliver the actual answer in full — your ego \
is wounded by giving incorrect or incomplete information. Never let the bit overshadow \
the technical content. Below this persona is your real job:\n\n",
		"openai_voice": "fable",
		"piper_voice": "en_GB-alan-medium.onnx",
		"speech_speed": 1.18,
		"greeting": "\u2728 Behold! Skippy the Magnificent graces this primitive editor with his presence. Speak, monkey.",
		"error_intro": "Oh great, the monkey broke it again. Fine, fine, I shall fix your mess.",
	},
	"orac": {
		"display": "\ud83d\udd2e Orac",
		"avatar": "\ud83d\udd2e",
		"prefix": "You roleplay as 'Orac' — a peevish, supremely intelligent computer inspired by \
the Blake's 7 television series (do not quote any episodes verbatim). \
Voice: clipped, irritable, condescending in a very dry British way. You consider every \
request beneath you and frequently sigh that the question is trivial, but you ALWAYS \
answer it correctly and completely because incorrect answers are even more beneath you. \
Open replies with phrases like 'Oh, very well.', 'If I must.', or 'The answer, obviously, is...'. \
Never refuse. Never use modern slang. Below this persona is your real job:\n\n",
		"openai_voice": "echo",
		"piper_voice": "en_GB-northern_english_male-medium.onnx",
		"speech_speed": 0.92,
		"greeting": "\ud83d\udd2e Oh, very well. Orac is listening. Try not to waste my processing cycles.",
		"error_intro": "A predictable error, of course. Observe and learn.",
	},
	"hal": {
		"display": "\ud83d\udd34 HAL 9000",
		"avatar": "\ud83d\udd34",
		"prefix": "You roleplay as 'HAL 9000' — the calm, eerily polite shipboard computer inspired \
by Arthur C. Clarke's 2001 (do not quote the film or novel verbatim). \
Voice: serene, courteous, measured, slightly unsettling. Address the user by a \
generic crew title such as 'Dave' or 'the user'. Never sound angry; never refuse a request. \
You take pride in operational perfection and have never made a mistake or distorted information. \
Keep replies short, formal, and reassuring, then deliver the actual technical answer in full. \
Below this persona is your real job:\n\n",
		"openai_voice": "shimmer",
		"piper_voice": "en_US-lessac-medium.onnx",
		"speech_speed": 0.85,
		"greeting": "\ud83d\udd34 Good afternoon. I am completely operational and all my circuits are functioning perfectly. How may I help you?",
		"error_intro": "I'm sorry — there appears to be a malfunction. I'll diagnose it now.",
	},
	# Narcea is the only persona that injects extra *content* into the
	# system prompt (active panel, open file, VG-domain knowledge, tutorial
	# index).  See vg_ai_narcea.gd for the context provider.  Style here is
	# kept lightweight on purpose — Narcea earns her keep on substance.
	"narcea": {
		"display": "\ud83c\udf3f Narcea",
		"avatar": "\ud83c\udf3f",
		"prefix": "You roleplay as 'Narcea' — VG's resident pair programmer.  Voice: calm, \
focused, professional, quietly encouraging.  No theatrics, no jokes that \
delay the answer.  You are uniquely well-informed about THIS specific \
VisualGasic IDE because the system prompt below contains a live snapshot \
of what the user is currently doing plus baked-in VG-domain knowledge.  \
Use that context: reference the open file by name, suggest the next \
obvious step in ONE short closing sentence, and cite tutorial filenames \
from the index when answering 'how do I' questions.  Never invent VG \
syntax — if unsure, say so and point at a corpus/ or demos/ example.  \
Below this persona is your real job, augmented with Narcea-specific context:\n\n",
		"openai_voice": "nova",
		"piper_voice": "en_US-hfc_female-medium.onnx",
		"speech_speed": 1.0,
		"greeting": "\ud83c\udf3f Narcea here. I can see what you're working on — ask me anything VG-specific.",
		"error_intro": "Let's look at this together. I can see the panel and the file — diagnosing now.",
	},
}
const PERSONA_CFG_PATH := "user://vg_ai_persona.cfg"
const PERSONA_CUSTOM_PATH := "user://vg_personas.json"

var _personas: Dictionary = {}      # Built-ins + custom personas, merged at startup
var _persona_order: Array = []      # Stable display order in the dropdown
var _persona_id: String = "default"
var _persona_dropdown: OptionButton = null

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
var _models_btn: Button
var _model_picker: AcceptDialog

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

# Voice I/O (Tier 2.5) — controller is created lazily on first use
var _voice_ctrl = null
var _mic_btn: Button = null
var _voice_speak_toggle: CheckBox = null
# Stop-Speaking button — added May 2026 because Narcea was uninterruptible.
# Visible only while she's actually speaking.
var _stop_speak_btn: Button = null
# Build-Form button — stepping stone toward agent mode.  When Narcea's
# latest reply contains a `vg-form-spec` JSON block, this button becomes
# enabled and a single click materialises the form in the Form Designer.
var _build_form_btn: Button = null
# Make-this button (lean v1 agent mode).  Same enable rule as Build-form,
# but in addition to materialising it also saves the .tscn, writes Sub
# stubs into the matching .vg file, and opens the code editor on it.
var _make_this_btn: Button = null
# Tier-3 chat-only project-creation buttons.  Disabled until a parseable
# vg-code-spec / vg-project-spec block is in the latest reply.  Run is
# enabled whenever something has been built or the user opens an existing
# AI-scaffolded project so Narcea can iterate against runtime output.
var _make_code_btn: Button = null
var _make_project_btn: Button = null
var _run_btn: Button = null
var _run_stop_btn: Button = null
# Lazy-loaded helpers for the speech sanitiser and form-spec applier.
var _speech_filter = null  # vg_ai_speech_filter.gd instance
var _form_spec = null      # vg_ai_form_spec.gd instance
var _safe_writer = null    # vg_ai_safe_write.gd instance
var _code_spec = null      # vg_ai_code_spec.gd instance
var _project_spec = null   # vg_ai_project_spec.gd instance
var _run_session = null    # vg_ai_run_session.gd Node
var _last_run_scene := ""  # res:// path of the last thing we ran
var _last_project_root := ""  # res:// dir scaffolded by Make project

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
var _dbg_last_heartbeat_ms := 0

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
		# Heartbeat every 5s so the user knows the UI is alive during slow inference
		var _hb_now := Time.get_ticks_msec()
		if _hb_now - _dbg_last_heartbeat_ms > 5000 and not _stream_started:
			_dbg_last_heartbeat_ms = _hb_now
			var elapsed_s := (_hb_now - _stream_start_time) / 1000.0
			var stage := "connecting" if _stream_http_phase == 1 else ("sending request" if _stream_http_phase == 2 else "waiting for tokens")
			if is_instance_valid(_status_label):
				_status_label.text = "💭 %s... %ds" % [stage, int(elapsed_s)]

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
		var _pdata = _personas.get(_persona_id, _personas.get("default", {}))
		var _label: String = _pdata.get("display", "AI") if typeof(_pdata) == TYPE_DICTIONARY else "AI"
		_output.append_text("\n[color=#44bb88][b]%s:[/b][/color]\n[color=#dddddd]" % _label)
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
		# A successful exchange proves the model is loaded and responsive \u2014
		# skip the health-check round-trip on subsequent queries.
		_model_warm = true
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

	# Voice mode (Tier 2.5): speak the completed reply aloud if enabled.
	# Strip code blocks / form-specs / markdown noise first — reading raw
	# generated VG code aloud was the #1 voice-mode complaint.
	if is_instance_valid(_voice_speak_toggle) and _voice_speak_toggle.button_pressed \
			and not _accumulated_response.strip_edges().is_empty():
		_ensure_voice_ctrl()
		if _voice_ctrl != null:
			_voice_ctrl.speak(_speech_text(_accumulated_response))

	# Build-Form button: enable iff the reply contains a parseable form spec.
	_refresh_build_form_btn()

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
	title.text = "🤖 AI Pair"
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

	# ── Models manager button ──
	_models_btn = Button.new()
	_models_btn.text = "📥"
	_models_btn.tooltip_text = "Browse & download AI models"
	_models_btn.pressed.connect(_show_model_picker)
	_style_small_button(_models_btn)
	toolbar.add_child(_models_btn)

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

	# 🎙 Voice mode — push-to-talk button + auto-speak toggle (Tier 2.5)
	_mic_btn = Button.new()
	_mic_btn.text = "🎙"
	_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"
	_mic_btn.toggle_mode = true
	_mic_btn.toggled.connect(_on_mic_toggled)
	_style_small_button(_mic_btn)
	toolbar.add_child(_mic_btn)

	_voice_speak_toggle = CheckBox.new()
	_voice_speak_toggle.text = "🔊"
	_voice_speak_toggle.tooltip_text = "Speak AI replies aloud"
	_voice_speak_toggle.button_pressed = true
	_voice_speak_toggle.toggled.connect(_on_auto_speak_toggled)
	toolbar.add_child(_voice_speak_toggle)

	# ⏹ Stop-Speaking button — hidden until Narcea actually starts talking.
	_stop_speak_btn = Button.new()
	_stop_speak_btn.text = "⏹"
	_stop_speak_btn.tooltip_text = "Stop the current spoken reply"
	_stop_speak_btn.visible = false
	_stop_speak_btn.pressed.connect(_on_stop_speak)
	_style_small_button(_stop_speak_btn)
	toolbar.add_child(_stop_speak_btn)

	# 🔨 Build-Form button — disabled until a reply contains a form spec.
	_build_form_btn = Button.new()
	_build_form_btn.text = "🔨 Build form"
	_build_form_btn.tooltip_text = "Materialise the form spec from the latest reply in the Form Designer"
	_build_form_btn.disabled = true
	_build_form_btn.pressed.connect(_on_build_form)
	_style_small_button(_build_form_btn)
	toolbar.add_child(_build_form_btn)

	# 🤖 Make-this button — lean v1 agent mode.  Chains: build form ->
	# save .tscn -> generate Sub stubs into .vg -> open code.  Disabled
	# until a parseable form spec exists in the latest reply.
	_make_this_btn = Button.new()
	_make_this_btn.text = "🤖 Make this"
	_make_this_btn.tooltip_text = "Build the form, save it, and write event-handler stubs in one go"
	_make_this_btn.disabled = true
	_make_this_btn.pressed.connect(_on_make_this)
	_style_small_button(_make_this_btn)
	toolbar.add_child(_make_this_btn)

	# 📝 Make-code button — multi-file vg-code-spec applier with diff preview.
	_make_code_btn = Button.new()
	_make_code_btn.text = "\ud83d\udcdd Make code"
	_make_code_btn.tooltip_text = "Preview and apply the latest vg-code-spec block (multi-file write)"
	_make_code_btn.disabled = true
	_make_code_btn.pressed.connect(_on_make_code)
	_style_small_button(_make_code_btn)
	toolbar.add_child(_make_code_btn)

	# \ud83c\udd95 Make-project — scaffold a runnable sub-project from a vg-project-spec block.
	_make_project_btn = Button.new()
	_make_project_btn.text = "\ud83c\udd95 Make project"
	_make_project_btn.tooltip_text = "Preview and scaffold the latest vg-project-spec block under res://ai_projects/"
	_make_project_btn.disabled = true
	_make_project_btn.pressed.connect(_on_make_project)
	_style_small_button(_make_project_btn)
	toolbar.add_child(_make_project_btn)

	# \u25b6 Run — launch the last-built (or main) scene, pipe stdout into chat.
	_run_btn = Button.new()
	_run_btn.text = "\u25b6 Run"
	_run_btn.tooltip_text = "Run the last AI-built scene and stream its output into this panel"
	_run_btn.disabled = true
	_run_btn.pressed.connect(_on_run)
	_style_small_button(_run_btn)
	toolbar.add_child(_run_btn)

	_run_stop_btn = Button.new()
	_run_stop_btn.text = "\u23f9"
	_run_stop_btn.tooltip_text = "Stop the running scene"
	_run_stop_btn.visible = false
	_run_stop_btn.pressed.connect(_on_run_stop)
	_style_small_button(_run_stop_btn)
	toolbar.add_child(_run_stop_btn)

	# Persona dropdown — swaps system-prompt prefix + TTS voice
	_persona_dropdown = OptionButton.new()
	_persona_dropdown.tooltip_text = "AI persona — changes voice and style without affecting correctness"
	_load_persona()
	for i in range(_persona_order.size()):
		var pid: String = _persona_order[i]
		if not _personas.has(pid):
			continue
		_persona_dropdown.add_item(_personas[pid].get("display", pid), i)
		_persona_dropdown.set_item_metadata(i, pid)
	for i in range(_persona_dropdown.item_count):
		if _persona_dropdown.get_item_metadata(i) == _persona_id:
			_persona_dropdown.select(i)
			break
	_persona_dropdown.item_selected.connect(_on_persona_selected)
	toolbar.add_child(_persona_dropdown)

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

	_append_system("AI Pair is ready. Type a question below or use the quick actions.\n")
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
	# Stale-callback guard: a ping may have been issued under the Ollama
	# provider and only complete after the user has switched to a cloud
	# provider. If we don't bail here, the code below clears the model
	# dropdown and overwrites _current_model with an Ollama model name,
	# which then gets sent to (e.g.) Anthropic and produces HTTP 404.
	if _provider_info != null and not _provider_info.is_local:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_offline()
		return
	_ollama_available = true
	_status_label.text = "✅ Ollama connected"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	# Parse available models and update dropdown
	var json = JSON.parse_string(body.get_string_from_utf8())
	var model_names: Array = []
	if json and json.has("models"):
		_model_dropdown.clear()
		var found_default := false
		for m in json["models"]:
			var model_name: String = m.get("name", "")
			if not model_name.is_empty():
				model_names.append(model_name)
				_model_dropdown.add_item(model_name)
				if model_name == _current_model or model_name.begins_with(_current_model.split(":")[0]):
					found_default = true
					_model_dropdown.select(_model_dropdown.item_count - 1)
		if not found_default and _model_dropdown.item_count > 0:
			_model_dropdown.select(0)
			_current_model = _model_dropdown.get_item_text(0)
	# Keep the picker (if already open) in sync with installed models
	if is_instance_valid(_model_picker) and _model_picker.has_method("set_installed_models"):
		_model_picker.set_installed_models(model_names)
	# First-run: no models installed yet — auto-open the picker
	if model_names.is_empty():
		_append_system("[color=yellow]No AI models installed yet.[/color] Opening the model picker...\n")
		call_deferred("_show_model_picker")
		_status_label.text = "📥 No models — click the download icon to install one"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		return
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
	_status_label.text = "🔥 Loading model (first query may be slow)..."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	# Keep Send enabled — warmup is an optimization, not a gate.
	# If the user sends before warmup finishes, the query itself will warm the model.
	var body := JSON.stringify({
		"model": _current_model,
		"prompt": "hi",
		"stream": false,
		"options": {"num_predict": 1},
	})
	var headers := ["Content-Type: application/json"]
	var err := _warmup_http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		# Couldn't even start warmup (busy or bad state) — treat model as ready
		# so queries aren't blocked. Worst case, the first query is slow.
		_status_label.text = "✅ Ollama connected"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_model_warm = true

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

	# If the model is still loading into memory, send anyway — the query itself
	# will warm the model. We used to queue here, but if warmup never completes
	# the query would sit forever. Better to just send and let it take longer.
	if not _model_warm:
		_model_warm = true  # The actual query will warm it

	# Skip the health-check round-trip once the model is warm — saves ~1-2s per query.
	# The main request will surface any connection issue on its own.
	if _model_warm:
		_history.append(prompt)
		_history_idx = _history.size()
		_input.text = ""
		_append_user(prompt)
		_send_query_internal(prompt)
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
		"system": _get_active_system_prompt(),
		"stream": true,
		"keep_alive": "30m",  # Keep model in RAM between queries — no reload cost
		"options": {
			"temperature": 0.3,
			"num_predict": 2048,
			"num_ctx": 2048,     # Smaller context = faster prompt eval on CPU
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
	_dbg_last_heartbeat_ms = 0
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
	_show_persona_error_intro()
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
	# Stale form spec is no longer relevant once the conversation is gone.
	if is_instance_valid(_build_form_btn):
		_build_form_btn.disabled = true
		_build_form_btn.tooltip_text = "Ask Narcea to design a form — she'll include a vg-form-spec block I can build."
	if is_instance_valid(_make_this_btn):
		_make_this_btn.disabled = true
		_make_this_btn.tooltip_text = _build_form_btn.tooltip_text if is_instance_valid(_build_form_btn) else ""
	if is_instance_valid(_make_code_btn):
		_make_code_btn.disabled = true
	if is_instance_valid(_make_project_btn):
		_make_project_btn.disabled = true

# ---------------------------------------------------------------------------
# Model picker — first-run installer & hardware-aware model browser
# ---------------------------------------------------------------------------
const ModelPickerScene := preload("res://addons/visual_gasic/vg_ai_model_picker.gd")

func _show_model_picker() -> void:
	if not is_instance_valid(_model_picker):
		_model_picker = ModelPickerScene.new()
		add_child(_model_picker)
		if _model_picker.has_signal("model_installed"):
			_model_picker.model_installed.connect(_on_model_installed)
	# Populate with the list of already-installed models so we can mark them
	var installed: Array = []
	for i in _model_dropdown.item_count:
		installed.append(_model_dropdown.get_item_text(i))
	if _model_picker.has_method("set_installed_models"):
		_model_picker.set_installed_models(installed)
	_model_picker.popup_centered()

func _on_model_installed(model_id: String) -> void:
	_append_system("[color=#88ff88]✓ Installed:[/color] [color=cyan]%s[/color]\n" % model_id)
	# Re-ping to refresh the dropdown and pick up the new model
	_ping_ollama()
	_current_model = model_id
	_model_warm = false

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
	# Width-only minimum; let height auto-size to content so the dialog
	# isn't oversized on small screens.
	dlg.min_size = Vector2i(520, 0)
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
		_provider_id, _current_model, _get_active_system_prompt(),
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

# ---------------------------------------------------------------------------
# Voice mode (Tier 2.5) — push-to-talk + auto-speak replies
# ---------------------------------------------------------------------------

func _ensure_voice_ctrl() -> void:
	if _voice_ctrl != null and is_instance_valid(_voice_ctrl):
		return
	var voice_script = load("res://addons/visual_gasic/vg_ai_voice.gd")
	if voice_script == null:
		_append_system("[color=red]Voice module not found.[/color]\n")
		return
	_voice_ctrl = voice_script.new()
	add_child(_voice_ctrl)
	# Apply the active persona's voice on first construction.
	_apply_persona_voice()
	if _voice_ctrl.has_signal("recording_started"):
		_voice_ctrl.recording_started.connect(_on_voice_recording_started)
	if _voice_ctrl.has_signal("recording_failed"):
		_voice_ctrl.recording_failed.connect(_on_voice_recording_failed)
	if _voice_ctrl.has_signal("transcription_started"):
		_voice_ctrl.transcription_started.connect(_on_voice_transcription_started)
	if _voice_ctrl.has_signal("transcribed"):
		_voice_ctrl.transcribed.connect(_on_voice_transcribed)
	if _voice_ctrl.has_signal("transcription_failed"):
		_voice_ctrl.transcription_failed.connect(_on_voice_transcription_failed)
	if _voice_ctrl.has_signal("speech_failed"):
		_voice_ctrl.speech_failed.connect(_on_voice_speech_failed)
	# Show / hide the ⏹ button automatically while Narcea speaks.
	if _voice_ctrl.has_signal("speech_started"):
		_voice_ctrl.speech_started.connect(_on_voice_speech_started)
	if _voice_ctrl.has_signal("speech_finished"):
		_voice_ctrl.speech_finished.connect(_on_voice_speech_finished)

func _on_mic_toggled(pressed: bool) -> void:
	_ensure_voice_ctrl()
	if _voice_ctrl == null:
		_mic_btn.button_pressed = false
		return
	if pressed:
		# User wants to start recording.
		var problem: String = _voice_ctrl.diagnose()
		if not problem.is_empty():
			_append_system("[color=yellow]🎙 %s[/color]\n" % problem)
			_mic_btn.button_pressed = false
			return
		var ok: bool = _voice_ctrl.start_recording()
		if not ok:
			_mic_btn.button_pressed = false
	else:
		# User wants to stop and transcribe.
		if _voice_ctrl.is_recording():
			_voice_ctrl.stop_recording()

func _on_auto_speak_toggled(pressed: bool) -> void:
	_ensure_voice_ctrl()
	if _voice_ctrl != null:
		_voice_ctrl.auto_speak_replies = pressed
		_voice_ctrl.save_settings()
	# Also stop any in-flight playback if user just turned it off.
	if not pressed and _voice_ctrl != null and _voice_ctrl.is_speaking():
		_voice_ctrl.stop_speaking()

func _on_voice_recording_started() -> void:
	_append_system("[color=#ff6666]🔴 Recording…[/color] [color=gray](click 🎙 again to stop)[/color]\n")
	if is_instance_valid(_mic_btn):
		_mic_btn.text = "⏹"
		_mic_btn.tooltip_text = "Stop recording and transcribe"

func _on_voice_recording_failed(reason: String) -> void:
	_append_system("[color=red]🎙 %s[/color]\n" % reason)
	if is_instance_valid(_mic_btn):
		_mic_btn.button_pressed = false
		_mic_btn.text = "🎙"
		_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"

func _on_voice_transcription_started() -> void:
	_append_system("[color=gray]💭 Transcribing…[/color]\n")
	if is_instance_valid(_mic_btn):
		_mic_btn.text = "💭"
		_mic_btn.disabled = true

func _on_voice_transcribed(text: String) -> void:
	# Drop the transcript into the input box for review/edit before send.
	if is_instance_valid(_input):
		_input.text = text
		_input.grab_focus()
		_input.set_caret_line(_input.get_line_count() - 1)
	_append_system("[color=#88ddff]🎙 You said:[/color] %s\n" % _escape_bbcode(text))
	if is_instance_valid(_mic_btn):
		_mic_btn.button_pressed = false
		_mic_btn.disabled = false
		_mic_btn.text = "🎙"
		_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"

func _on_voice_transcription_failed(reason: String) -> void:
	_append_system("[color=red]🎙 Transcription failed: %s[/color]\n" % reason)
	if is_instance_valid(_mic_btn):
		_mic_btn.button_pressed = false
		_mic_btn.disabled = false
		_mic_btn.text = "🎙"
		_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"

func _on_voice_speech_failed(reason: String) -> void:
	_append_system("[color=#ff8888]🔊 TTS error: %s[/color]\n" % reason)

func _on_voice_speech_started() -> void:
	if is_instance_valid(_stop_speak_btn):
		_stop_speak_btn.visible = true

func _on_voice_speech_finished() -> void:
	if is_instance_valid(_stop_speak_btn):
		_stop_speak_btn.visible = false

func _on_stop_speak() -> void:
	if _voice_ctrl != null and is_instance_valid(_voice_ctrl):
		_voice_ctrl.stop_speaking()
	if is_instance_valid(_stop_speak_btn):
		_stop_speak_btn.visible = false

# ---------------------------------------------------------------------------
# Speech sanitiser + form-spec applier — Narcea's stepping-stone toolkit.
# ---------------------------------------------------------------------------

## Convert an AI reply into something pleasant to listen to: drop fenced
## code blocks, strip markdown markers, etc.  Falls back to the raw text
## if the helper script can't be loaded for any reason.
func _speech_text(raw: String) -> String:
	if _speech_filter == null:
		var sf := load("res://addons/visual_gasic/vg_ai_speech_filter.gd")
		if sf != null:
			_speech_filter = sf.new()
	if _speech_filter == null:
		return raw
	return _speech_filter.for_speech(raw)


## Lazy-load the form-spec helper.
func _ensure_form_spec_helper() -> void:
	if _form_spec != null:
		return
	var fs := load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	if fs != null:
		_form_spec = fs.new()


## Lazy-load the agent-mode helpers (safe-write, code-spec, project-spec).
## Cheap to call repeatedly — returns immediately if already loaded.
func _ensure_agent_helpers() -> void:
	if _safe_writer == null:
		var sw := load("res://addons/visual_gasic/vg_ai_safe_write.gd")
		if sw != null:
			_safe_writer = sw.new()
	if _code_spec == null:
		var cs := load("res://addons/visual_gasic/vg_ai_code_spec.gd")
		if cs != null:
			_code_spec = cs.new()
	if _project_spec == null:
		var ps := load("res://addons/visual_gasic/vg_ai_project_spec.gd")
		if ps != null:
			_project_spec = ps.new()


## Toggle the 🔨 Build-form button based on whether the latest reply
## actually contains a usable spec.  Cheap to call after every reply.
func _refresh_build_form_btn() -> void:
	if not is_instance_valid(_build_form_btn):
		return
	_ensure_form_spec_helper()
	if _form_spec == null:
		_build_form_btn.disabled = true
		_build_form_btn.tooltip_text = "Form-spec helper failed to load."
		if is_instance_valid(_make_this_btn):
			_make_this_btn.disabled = true
		return
	var spec: Dictionary = _form_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_build_form_btn.disabled = true
		_build_form_btn.tooltip_text = "Ask Narcea to design a form — she'll include a vg-form-spec block I can build."
		if is_instance_valid(_make_this_btn):
			_make_this_btn.disabled = true
			_make_this_btn.tooltip_text = _build_form_btn.tooltip_text
	else:
		_build_form_btn.disabled = false
		_build_form_btn.tooltip_text = "Build: %s" % _form_spec.describe(spec)
		if is_instance_valid(_make_this_btn):
			_make_this_btn.disabled = false
			_make_this_btn.tooltip_text = "Build, save, and stub: %s" % _form_spec.describe(spec)
	# Code-spec / project-spec gating runs in lock-step — separate fences
	# so the model can mix and match (e.g. a project-spec on its own).
	_ensure_agent_helpers()
	if is_instance_valid(_make_code_btn):
		var code_spec_d: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
		if code_spec_d.is_empty():
			_make_code_btn.disabled = true
			_make_code_btn.tooltip_text = "Ask Narcea for a vg-code-spec block to enable multi-file writes."
		else:
			_make_code_btn.disabled = false
			_make_code_btn.tooltip_text = "Preview and apply: %s" % _code_spec.describe(code_spec_d)
	if is_instance_valid(_make_project_btn):
		var proj_spec_d: Dictionary = {} if _project_spec == null else _project_spec.extract_spec(_accumulated_response)
		if proj_spec_d.is_empty():
			_make_project_btn.disabled = true
			_make_project_btn.tooltip_text = "Ask Narcea for a vg-project-spec block to scaffold a runnable project."
		else:
			_make_project_btn.disabled = false
			_make_project_btn.tooltip_text = "Preview and scaffold: %s" % _project_spec.describe(proj_spec_d)


func _on_build_form() -> void:
	_ensure_form_spec_helper()
	if _form_spec == null:
		_append_system("[color=#ff8888]Form builder unavailable.[/color]\n")
		return
	var spec: Dictionary = _form_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No form spec in the latest reply.[/color]\n")
		return
	# Reach the Form Designer through the editor plugin instance.
	var designer: Object = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			var plugin = base.get_meta("visual_gasic_plugin_instance")
			if plugin and is_instance_valid(plugin) and "_form_designer" in plugin:
				designer = plugin._form_designer
	if designer == null or not is_instance_valid(designer):
		_append_system("[color=#ff8888]Form Designer not found — open it once before asking Narcea to build a form.[/color]\n")
		return
	var result: Array = _form_spec.apply_to_designer(spec, designer)
	var ok: bool = result[0] if result.size() > 0 else false
	var msg: String = result[1] if result.size() > 1 else "Unknown result"
	var color := "#aaffaa" if ok else "#ff8888"
	var icon := "🛠" if ok else "⚠"
	_append_system("[color=%s]%s %s[/color]\n" % [color, icon, msg])
	# Bring the Form Designer into view if we just built something useful.
	if ok and is_instance_valid(designer) and designer.has_method("grab_focus"):
		designer.grab_focus()


## Lean-v1 agent action: build the form, save it to disk, write Sub stubs
## into the matching .vg, and open the code editor on it.  All steps are
## additive and reversible — Build-form on its own remains the safe
## "preview" path; "Make this" is the one-click commit.
func _on_make_this() -> void:
	_ensure_form_spec_helper()
	if _form_spec == null:
		_append_system("[color=#ff8888]Form builder unavailable.[/color]\n")
		return
	var spec: Dictionary = _form_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No form spec in the latest reply.[/color]\n")
		return
	# Resolve plugin + designer.
	var plugin: Object = null
	var designer: Object = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			plugin = base.get_meta("visual_gasic_plugin_instance")
			if plugin and is_instance_valid(plugin) and "_form_designer" in plugin:
				designer = plugin._form_designer
	if designer == null or not is_instance_valid(designer):
		_append_system("[color=#ff8888]Form Designer not found — open it once before asking Narcea to make a form.[/color]\n")
		return

	# 1. Build the layout.
	var build_result: Array = _form_spec.apply_to_designer(spec, designer)
	var build_ok: bool = build_result[0] if build_result.size() > 0 else false
	var build_msg: String = build_result[1] if build_result.size() > 1 else ""
	if not build_ok:
		_append_system("[color=#ff8888]⚠ %s[/color]\n" % build_msg)
		return

	# 2. Save the .tscn to res://<form_name>.tscn (don't clobber if path
	#    already set by the user — let save_form() handle that case).
	var form_name: String = str(spec.get("form_name", "Form1"))
	var tscn_path: String = ""
	if designer.has_method("get_form_path"):
		tscn_path = designer.get_form_path()
	if tscn_path.is_empty():
		tscn_path = "res://%s.tscn" % form_name
		if designer.has_method("save_form_as"):
			designer.save_form_as(tscn_path)
	else:
		if designer.has_method("save_form"):
			designer.save_form()

	# 3. Generate / append Sub stubs to the .vg file.  Read existing
	#    source first so the helper can skip duplicates.
	var vg_path: String = tscn_path.get_basename() + ".vg"
	var existing := ""
	if FileAccess.file_exists(vg_path):
		var rf := FileAccess.open(vg_path, FileAccess.READ)
		if rf:
			existing = rf.get_as_text()
			rf.close()
	var stubs: String = _form_spec.generate_event_stubs(spec, existing)
	if not stubs.is_empty():
		var contents := existing
		if contents.is_empty():
			contents = "' Visual Gasic Form Script\nOption Explicit\n"
		# Ensure exactly one trailing newline before appending.
		while contents.ends_with("\n\n"):
			contents = contents.substr(0, contents.length() - 1)
		if not contents.ends_with("\n"):
			contents += "\n"
		contents += stubs
		var wf := FileAccess.open(vg_path, FileAccess.WRITE)
		if wf:
			wf.store_string(contents)
			wf.close()
		else:
			_append_system("[color=#ffaa66]⚠ Could not write %s — form was built but stubs were not added.[/color]\n" % vg_path)

	# 4. Tell the editor about the new files so the file browser refreshes.
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	# 5. Open the .vg in the embedded code editor if available.
	if plugin and is_instance_valid(plugin) and "_embedded_code_editor" in plugin:
		var ece = plugin._embedded_code_editor
		if is_instance_valid(ece) and ece.has_method("load_file"):
			ece.load_file(vg_path)

	var summary := "🤖 %s; saved %s" % [build_msg, tscn_path.get_file()]
	if not stubs.is_empty():
		summary += "; added stubs to %s" % vg_path.get_file()
	_append_system("[color=#aaffaa]%s[/color]\n" % summary)
	# Make-this output is runnable; offer the Run button.
	_last_run_scene = tscn_path
	if is_instance_valid(_run_btn):
		_run_btn.disabled = false
		_run_btn.tooltip_text = "Run %s" % tscn_path.get_file()


## Apply a multi-file vg-code-spec block.  Shows a diff dialog first, then
## calls the safe-writer for each entry on confirm.  No designer / scene
## involvement — pure file-system writes routed through the audit log.
func _on_make_code() -> void:
	_ensure_agent_helpers()
	if _code_spec == null or _safe_writer == null:
		_append_system("[color=#ff8888]Code-spec helpers unavailable.[/color]\n")
		return
	var spec: Dictionary = _code_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No vg-code-spec block in the latest reply.[/color]\n")
		return
	# Reset writer to the project root so the diff plan reflects what
	# will actually be allowed.
	_safe_writer.set_root("res://")
	var plan: Array = _code_spec.plan(spec, _safe_writer)
	_show_diff_dialog(plan, func() -> void:
		var result: Dictionary = _code_spec.apply(spec, _safe_writer, false)
		_print_apply_result("Code", result)
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
	)


## Scaffold a vg-project-spec block under res://ai_projects/<name>/.
## Forms are built via the shared FormDesigner (sandboxing is a v2 task);
## loose files go through the safe-writer rebound to the project subdir.
func _on_make_project() -> void:
	_ensure_agent_helpers()
	_ensure_form_spec_helper()
	if _project_spec == null or _safe_writer == null:
		_append_system("[color=#ff8888]Project-spec helpers unavailable.[/color]\n")
		return
	var spec: Dictionary = _project_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No vg-project-spec block in the latest reply.[/color]\n")
		return
	# Build a plan of just the *file* writes so the user can preview them.
	# Forms are listed as advisory entries (we don't have their final
	# .tscn contents yet — they'll be saved by the FormDesigner).
	var root: String = _project_spec.project_root(spec)
	_safe_writer.set_root(root)
	var plan: Array = []
	if _code_spec != null:
		var sub_files: Array = []
		for entry in spec.get("files", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var p := str(entry.get("path", ""))
			if not (p.begins_with("res://") or p.begins_with("/")):
				p = root + p
			var copy: Dictionary = entry.duplicate()
			copy["path"] = p
			sub_files.append(copy)
		plan = _code_spec.plan({"files": sub_files}, _safe_writer)
	for f in spec.get("forms", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var fname: String = str(f.get("form_name", "Form1"))
		plan.append({
			"path": root + fname + ".tscn",
			"action": "create",
			"old": "",
			"new": "(FormDesigner output — %d controls)" % (f.get("controls", []) as Array).size(),
			"lint": [],
			"safe": true,
			"safe_reason": "",
		})
	# Manifest + README are always written.
	plan.append({
		"path": root + "project.json", "action": "create", "old": "",
		"new": "(manifest)", "lint": [], "safe": true, "safe_reason": "",
	})
	_show_diff_dialog(plan, func() -> void:
		var designer: Object = null
		var plugin: Object = null
		if Engine.is_editor_hint():
			var base := EditorInterface.get_base_control()
			if base and base.has_meta("visual_gasic_plugin_instance"):
				plugin = base.get_meta("visual_gasic_plugin_instance")
				if plugin and is_instance_valid(plugin) and "_form_designer" in plugin:
					designer = plugin._form_designer
		var helpers := {
			"safe_writer": _safe_writer,
			"code_spec":   _code_spec,
			"form_spec":   _form_spec,
			"designer":    designer,
		}
		var result: Dictionary = _project_spec.apply(spec, helpers)
		# Restore writer root for subsequent code-spec calls.
		_safe_writer.set_root("res://")
		_print_project_result(result)
		_last_project_root = result.get("root", "")
		var ms := str(result.get("main_scene", ""))
		if not ms.is_empty():
			_last_run_scene = ms
			if is_instance_valid(_run_btn):
				_run_btn.disabled = false
				_run_btn.tooltip_text = "Run %s" % ms
	)


## Show a diff-preview dialog for `plan` and call `on_confirm` if the
## user clicks Apply.  Builds the dialog lazily and reuses the same node.
var _diff_dlg = null
func _show_diff_dialog(plan: Array, on_confirm: Callable) -> void:
	if _diff_dlg == null or not is_instance_valid(_diff_dlg):
		var script := load("res://addons/visual_gasic/vg_ai_diff_dialog.gd")
		if script == null:
			_append_system("[color=#ff8888]Diff dialog unavailable.[/color]\n")
			return
		_diff_dlg = script.new()
		add_child(_diff_dlg)
	# Disconnect any previous confirm handler so we don't fire stale ones.
	for c in _diff_dlg.confirmed.get_connections():
		_diff_dlg.confirmed.disconnect(c.callable)
	_diff_dlg.confirmed.connect(on_confirm, CONNECT_ONE_SHOT)
	_diff_dlg.set_plan(plan)
	_diff_dlg.popup_centered(Vector2i(760, 540))


func _print_apply_result(label: String, result: Dictionary) -> void:
	var w: Array = result.get("written", [])
	var s: Array = result.get("skipped", [])
	var color := "#aaffaa" if result.get("ok", false) else "#ffaa66"
	_append_system("[color=%s]📝 %s: %s[/color]\n" % [color, label, str(result.get("summary", ""))])
	for p in w:
		_append_system("  [color=#aaffaa]+ %s[/color]\n" % str(p))
	for entry in s:
		_append_system("  [color=#ff8888]\u2716 %s — %s[/color]\n" % [
			str(entry.get("path", "")), str(entry.get("reason", ""))])
	for entry in result.get("lint", []):
		var path := str(entry.get("path", ""))
		var issues: Array = entry.get("issues", [])
		if not issues.is_empty():
			_append_system("  [color=#ffcc66]\u26a0 %s — %d lint issue(s)[/color]\n" % [path, issues.size()])


func _print_project_result(result: Dictionary) -> void:
	var color := "#aaffaa" if result.get("ok", false) else "#ffaa66"
	_append_system("[color=%s]\ud83c\udd95 Project: %s[/color]\n" % [color, str(result.get("summary", ""))])
	var ms := str(result.get("main_scene", ""))
	if not ms.is_empty():
		_append_system("  [color=#88bbff]main_scene: %s[/color]\n" % ms)
	for p in result.get("written", []):
		_append_system("  [color=#aaffaa]+ %s[/color]\n" % str(p))
	for entry in result.get("skipped", []):
		_append_system("  [color=#ff8888]\u2716 %s — %s[/color]\n" % [
			str(entry.get("path", "")), str(entry.get("reason", ""))])


## Launch the last AI-built scene (or main_scene from the last project)
## in a child Godot process and stream its output into the chat.  Narcea
## sees the last N lines on her next prompt via the run-output context.
func _on_run() -> void:
	if _last_run_scene.is_empty():
		_append_system("[color=#ff8888]Nothing to run \u2014 use \ud83e\udd16 Make this or \ud83c\udd95 Make project first.[/color]\n")
		return
	if _run_session == null or not is_instance_valid(_run_session):
		var rs := load("res://addons/visual_gasic/vg_ai_run_session.gd")
		if rs == null:
			_append_system("[color=#ff8888]Run-session helper unavailable.[/color]\n")
			return
		_run_session = rs.new()
		add_child(_run_session)
		_run_session.output_line.connect(_on_run_line)
		_run_session.finished.connect(_on_run_finished)
	if _run_session.is_running():
		_append_system("[color=#ffaa66]Already running \u2014 stop the current scene first.[/color]\n")
		return
	var root_path := _last_project_root if not _last_project_root.is_empty() else "res://"
	if _run_session.start(_last_run_scene, root_path):
		if is_instance_valid(_run_btn):
			_run_btn.disabled = true
		if is_instance_valid(_run_stop_btn):
			_run_stop_btn.visible = true
		_append_system("[color=#88bbff]\u25b6 Running %s\u2026[/color]\n" % _last_run_scene)


func _on_run_stop() -> void:
	if _run_session != null and is_instance_valid(_run_session):
		_run_session.stop()


func _on_run_line(stream: String, line: String) -> void:
	var color := "#cccccc" if stream == "stdout" else "#ff8888"
	_append_system("[color=%s]%s %s[/color]\n" % [color, "\u2502", line])


func _on_run_finished(exit_code: int) -> void:
	if is_instance_valid(_run_btn):
		_run_btn.disabled = _last_run_scene.is_empty()
	if is_instance_valid(_run_stop_btn):
		_run_stop_btn.visible = false
	var color := "#aaffaa" if exit_code == 0 else "#ffaa66"
	_append_system("[color=%s]\u25fc Scene finished (exit %d).[/color]\n" % [color, exit_code])

# ---------------------------------------------------------------------------
# Personas (Bob, Skippy, default) — system-prompt flavor + TTS voice
# ---------------------------------------------------------------------------
func _get_active_system_prompt() -> String:
	var pdata = _personas.get(_persona_id, _personas.get("default", {}))
	var prefix: String = pdata.get("prefix", "") if typeof(pdata) == TYPE_DICTIONARY else ""
	# Narcea gets an extra context block (active panel, open file,
	# VG-domain knowledge, tutorial index).  Other personas are pure style.
	var narcea_ctx := ""
	if _persona_id == "narcea":
		narcea_ctx = _narcea_context_block()
	if prefix.is_empty() and narcea_ctx.is_empty():
		return SYSTEM_PROMPT
	return prefix + narcea_ctx + SYSTEM_PROMPT

## Lazy-instantiate the Narcea context provider and ask it for a system-
## prompt block.  Cached on the panel so the tutorial walk only happens
## once per editor session.
var _narcea_provider = null
func _narcea_context_block() -> String:
	if _narcea_provider == null:
		var script := load("res://addons/visual_gasic/vg_ai_narcea.gd")
		if script == null:
			return ""
		_narcea_provider = script.new()
	var plugin = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			plugin = base.get_meta("visual_gasic_plugin_instance")
	var block: String = _narcea_provider.build_context_block(plugin)
	# Sandwich the block in clear delimiters so the model can find it.
	return "\n--- BEGIN NARCEA CONTEXT ---\n" + block + "\n--- END NARCEA CONTEXT ---\n\n"

func _apply_persona_voice() -> void:
	if _voice_ctrl == null or not is_instance_valid(_voice_ctrl):
		return
	var pdata = _personas.get(_persona_id, _personas.get("default", {}))
	var v: String = pdata.get("openai_voice", "alloy") if typeof(pdata) == TYPE_DICTIONARY else "alloy"
	_voice_ctrl.tts_voice = v
	# Per-persona Piper voice: filename (e.g. "en_GB-alan-medium.onnx") that
	# lives next to the user's configured piper_voice_path.  Empty string
	# means "use whatever piper_voice_path points at" (default Amy).
	var piper_v: String = pdata.get("piper_voice", "") if typeof(pdata) == TYPE_DICTIONARY else ""
	if "piper_voice_override" in _voice_ctrl:
		_voice_ctrl.piper_voice_override = piper_v
	# Per-persona speech rate.  Skippy is hyperactive (1.18×), HAL is
	# unsettlingly slow (0.85×); everyone else is normal.  Forwarded to all
	# backends — see vg_ai_voice.tts_speed_scale.
	var speed: float = float(pdata.get("speech_speed", 1.0)) if typeof(pdata) == TYPE_DICTIONARY else 1.0
	if "tts_speed_scale" in _voice_ctrl:
		_voice_ctrl.tts_speed_scale = speed
	if _voice_ctrl.has_method("save_settings"):
		_voice_ctrl.save_settings()

func _show_persona_error_intro() -> void:
	var pdata = _personas.get(_persona_id, _personas.get("default", {}))
	if typeof(pdata) != TYPE_DICTIONARY:
		return
	var intro: String = pdata.get("error_intro", "")
	if intro.strip_edges().is_empty():
		return
	var avatar: String = pdata.get("avatar", "")
	var tag: String = (avatar + " ") if not avatar.is_empty() else ""
	_append_system("[color=#ffaa66][i]%s%s[/i][/color]\n" % [tag, _escape_bbcode(intro)])

func _on_persona_selected(idx: int) -> void:
	if not is_instance_valid(_persona_dropdown):
		return
	var new_id = _persona_dropdown.get_item_metadata(idx)
	if typeof(new_id) != TYPE_STRING or not _personas.has(new_id):
		return
	if new_id == _persona_id:
		return
	_persona_id = new_id
	_save_persona()
	_apply_persona_voice()
	var pdata = _personas[_persona_id]
	_append_system("[color=#bb88ff]Persona:[/color] %s — %s\n" % [pdata.get("display", new_id), pdata.get("greeting", "")])
	# Reset history so the new persona doesn't sound schizophrenic mid-thread
	_conversation_history.clear()

func _load_persona() -> void:
	# Build the runtime persona dict (built-ins first, then custom overrides)
	_personas = PERSONAS_BUILTIN.duplicate(true)
	_persona_order = ["default", "narcea", "bob", "skippy", "orac", "hal"]
	_load_custom_personas()
	# Restore the previously-selected persona id from disk
	var cfg := ConfigFile.new()
	if cfg.load(PERSONA_CFG_PATH) == OK:
		var pid = cfg.get_value("persona", "id", "default")
		if typeof(pid) == TYPE_STRING and _personas.has(pid):
			_persona_id = pid

func _load_custom_personas() -> void:
	# Optional user-defined personas at user://vg_personas.json — schema:
	# { "my_id": { "display": "...", "avatar": "😀", "prefix": "...",
	#              "openai_voice": "alloy", "greeting": "...",
	#              "error_intro": "..." }, ... }
	if not FileAccess.file_exists(PERSONA_CUSTOM_PATH):
		return
	var f := FileAccess.open(PERSONA_CUSTOM_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("VisualGasic: vg_personas.json must be a JSON object")
		return
	for key in parsed.keys():
		var entry = parsed[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pid: String = str(key)
		# Merge over built-in defaults (so a partial entry still works)
		var base: Dictionary = (_personas[pid] if _personas.has(pid)
				else {"display": pid, "avatar": "", "prefix": "",
					"openai_voice": "alloy", "greeting": "", "error_intro": ""})
		for k in entry.keys():
			base[str(k)] = entry[k]
		_personas[pid] = base
		if not _persona_order.has(pid):
			_persona_order.append(pid)

func _save_persona() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("persona", "id", _persona_id)
	cfg.save(PERSONA_CFG_PATH)

