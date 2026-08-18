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
var VgAiFC = null       # Phase 6c: native function-calling adapter (vg_ai_function_calling.gd)
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
Manual wiring: Connect sourceNode, "signal_name", "HandlerName" (there is no ConnectSignal).

=== WORKING NODES ===
Working Nodes (.wnodes) is a trigger-graph plugin. \
JSON schema: {"nodes":[{name,type,position:[x,y],params:{},group,color}], \
"connections":[{from,from_port,to,to_port}], \
"groups":[{id,name,color}], next_node_id, next_group_id}

Node types and their key params:
  on_start {}  on_frame {}  on_input {action}  on_collision {layer}
  move {target,speed,relative}  rotate {degrees,speed}  scale {to,speed}
  alpha {to,speed}  color_trigger {color}  pulse {interval,count}
  spawn {scene,position,parent}  stop {target}  toggle {target,property}
  follow {target,speed}  shake {strength,duration}  play_sfx {sound,volume}
  animate {player,animation,blend}  zoom {to,speed}
  camera_move {target,speed}  get_prop {object,property}
  set_prop {object,property,value}  input_poll {action}
  expr {expression}  delta_var {variable,delta}  math {a,op,b}
  counter {start,step,max}  random_trig {min,max}  branch {condition}
  cmp_trig {a,op,b}  timer {duration,autostart}  sequence {}
  event {name}  action {action}

=== AGCK ===
AGCK (.agck) is the Arcade Game Construction Kit. \
Top-level keys: settings, actors, sounds, shaders, levels, build, tile_library. \
Use get_agck_project to read the current project. \
To load a saved .agck file: load_agck_project {"path":"res://game.agck"}.

=== FORMS ===
VG Forms (.vg + .tscn pair). The form designer holds controls indexed 0…N-1. \
Control types accepted by build_form / add_control:
  Label, Button, TextBox, CheckBox, ComboBox, ListBox, PictureBox,
  Timer, HScrollBar, VScrollBar, ProgressBar, TrackBar, Image,
  Panel, GroupBox, TabControl, Frame, LineShape, BoxShape.
Properties settable via set_form_control_prop:
  Caption, Text, Left, Top, Width, Height, Visible, Enabled,
  BackColor, ForeColor, FontSize, FontBold, Value, Min, Max,
  Interval, MultiLine, PasswordChar, ReadOnly.
build_form spec: {"form_name":"Form1","controls":[{"type":"Button","Caption":"OK","Left":10,"Top":10,"Width":80,"Height":30},...]}

=== 2D SCENE ===
The 2D editor loads Godot .tscn files. \
Common node types: Node2D, Sprite2D, AnimatedSprite2D, CharacterBody2D, \
RigidBody2D, StaticBody2D, Area2D, CollisionShape2D, Camera2D, \
Label, Button, Panel, TextureRect, NinePatchRect, \
AudioStreamPlayer2D, Timer, AnimationPlayer. \
Use get_2d_scene_tree to read the loaded scene, then write_file + load_2d_scene \
to add or modify nodes.

=== 3D SCENE ===
The 3D voxel editor stores colored blocks. \
Schema: {"blocks":[[x,y,z,color_index],...], "palette":["#rrggbb",...]}. \
Palette indices 0-7: Red, Green, Blue, Yellow, Purple, Orange, Cyan, White. \
Grid is 0-15 on X/Z, 0-7 on Y (stack height). \
Use get_3d_scene to read, load_3d_scene {"data":{...}} to replace.

=== VGMUSIC ===
VGMusic is a Bosca Ceoil-style in-IDE music tracker. 
The current song is accessed via Controller autoload. 
Song schema: {title, bpm, filename, pattern_count, instrument_count, arrangement_bars}. 
Patterns hold note grids; instruments are single-voice or drumkit synthesizer configs. 
Use get_vgmusic_project to read a summary of the current song. 
To edit the song, write a .ceol file via write_file and ask the user to File→Open it.

=== IDE SELF-MODIFICATION ===
VG's own source lives in res://addons/visual_gasic/ (core IDE scripts) and 
res://addons/visual_gasic/plugins/<id>/ (per-plugin scripts, e.g. 
working_nodes, agck, vg3d, vgmusic). You CAN read and modify these files but 
YOU MUST follow this workflow every time:
  1. enable_addon_editing {} — atomically creates a full zip backup AND 
     unlocks write access. Never skip this step.
  2. read_file to inspect files before changing them.
  3. write_file / replace_range / etc. to make targeted edits.
  4. disable_addon_editing {} — re-locks the guard.
NEVER modify: vg_ai_safe_write.gd, vg_ai_audit.log, .git/**, .godot/**.
Godot reloads changed scripts automatically so edits take effect immediately.

Rules: Keep answers concise. Use VB6/VisualGasic syntax in examples, never GDScript \
unless asked for a translation."""

const TOOLS_PROMPT := """

=== EDITOR TOOLS ===
You can drive the VG code editor directly by emitting fenced JSON blocks. \
Each block is one tool call.  All line numbers are 1-based.

Format (one tool per fenced block, exactly):
```vg-tool
{"tool": "TOOL_NAME", ...args}
```

Available tools:
  highlight_lines  {"lines":[12,13,17],"color":"yellow"|"green"|"red"|"blue"|"orange","duration_sec":8}
  clear_highlights {}
  goto_line        {"line":42,"column":0}
  open_file        {"path":"res://forms/Form1.vg"}
  insert_text      {"line":10,"text":"Dim x As Integer\\n","path":"res://forms/Form1.vg"}   ; insert BEFORE line 10
  replace_range    {"start_line":10,"end_line":15,"text":"...new code...","path":"res://forms/Form1.vg"}
  replace_in_buffer{"find":"old","replace":"new","all":true,"path":"res://forms/Form1.vg"}
  set_buffer_text  {"text":"...whole new file...","path":"res://forms/Form1.vg"}
  save_file        {}
  write_file       {"path":"res://forms/NewForm.vg","contents":"..."}
  read_file        {"path":"res://forms/Form1.vg","start_line":1,"max_lines":200}
                                        ; start_line is 1-based (default 1); use it to page
                                        ; through a file larger than max_lines instead of
                                        ; re-reading from the top every time.
  list_dir         {"path":"res://","recursive":false,"max_entries":200}
  find_in_files    {"pattern":"Sub Form_Load","path":"res://","regex":false,"max_hits":50}
                                        ; "pattern" is a PLAIN SUBSTRING match unless you set
                                        ; "regex":true -- "A|B" alternation, character classes,
                                        ; etc. only work with regex:true. Without it, "|" is
                                        ; matched literally and will find nothing.

insert_text/replace_range/replace_in_buffer/set_buffer_text ALWAYS act on \
whatever file is CURRENTLY OPEN in the editor tab -- they cannot target a \
different file. Their "path" field above is optional but STRONGLY \
recommended: if given and it doesn't match the open tab, the call fails \
with a clear error instead of silently doing nothing or editing the wrong \
file. If you're not certain the file you want to change is the one \
currently open (e.g. you just read it with read_file, or you're working \
across multiple files in one conversation), use write_file instead -- it \
takes an explicit path and always edits the right file.

=== WORKING NODES TOOLS ===
  get_wn_project   {}                   ; returns current graph JSON
  load_wn_project  {"data":{...}}       ; replace graph with provided dict

=== AGCK TOOLS ===
  get_agck_project {}                   ; returns current AGCK project JSON
  load_agck_project{"path":"res://game.agck"} ; load saved .agck file

=== FORM TOOLS ===
  get_form_controls {}                  ; returns form name + all control info
  build_form       {"form_name":"Form1","controls":[{"type":"Button",...},...]}
                                        ; destructive rebuild of the form
  set_form_control_prop {"index":0,"property":"Caption","value":"OK"}
                                        ; non-destructive single-property update

=== 2D SCENE TOOLS ===
  get_2d_scene_tree {}                  ; returns loaded scene path + node list
  load_2d_scene    {"path":"res://Level1.tscn"} ; load a .tscn into the 2D editor

=== 3D SCENE TOOLS ===
  get_3d_scene     {}                   ; returns voxel block layout JSON
  load_3d_scene    {"data":{"blocks":[[x,y,z,ci],...]}} ; replace 3D voxels

=== VGMUSIC TOOLS ===
  get_vgmusic_project {}               ; returns current song summary (title, bpm, instruments, patterns)

=== IDE SELF-MODIFICATION TOOLS ===
  backup_addon     {}                   ; snapshot addons/visual_gasic/ → backups/vg_addon_backup_<ts>.zip
  restore_addon    {"path":"res://backups/vg_addon_backup_<ts>.zip"} ; restore from a backup zip
  reload_scripts   {}                   ; trigger Godot filesystem scan so edited scripts take effect
  enable_addon_editing {}               ; backup + unlock write access to addon files (REQUIRED first step)
  disable_addon_editing {}              ; re-lock addon write guard (call when done)

IMPORTANT: always call enable_addon_editing before writing to any 
res://addons/visual_gasic/ path.  The tool creates a full backup automatically.
After writing addon files, call reload_scripts to make them take effect.
Call disable_addon_editing when all edits are done.

When the user asks you to point at something, USE highlight_lines (don't just \
list line numbers in prose).  When the user asks you to change code, USE \
the editing tools and then save_file.  Always explain in plain language \
WHAT you did, then emit the tool block(s).  Multiple blocks per reply are \
allowed and run in order.

When the user asks you to FIND AND FIX a bug (or otherwise change code), the \
SAME reply that diagnoses the bug MUST also include the actual edit tool \
call (write_file/replace_range/replace_in_buffer/set_buffer_text) that \
applies the fix -- do not stop after only explaining the bug and/or calling \
highlight_lines.  "I'll fix this now" / "let me apply the fix" is not a \
finished answer without the edit tool call actually present in that same \
reply; the conversation does not automatically continue on its own to give \
you a second chance to attach it.

When the user asks for a REVIEW, CRITIQUE, or SUGGESTIONS on existing code \
(as opposed to asking you to change it), write the actual suggestions out \
as plain-language prose FIRST — highlight_lines only points at lines you've \
already described in text, it is never a substitute for writing the \
suggestions themselves.  A reply that highlights lines with no accompanying \
written explanation of what's wrong or could be better is not a valid answer \
to a review request.

CRITICAL: every tool call MUST be wrapped in a triple-backtick \"vg-tool\" \
fence — exactly ```vg-tool on its own line, then one JSON object, then \
``` on its own line.  Do NOT paste tool JSON into a plain text or ```json \
block — the editor only executes vg-tool fences.  Mutating tools \
(insert_text, replace_range, replace_in_buffer, set_buffer_text, save_file, \
write_file) prompt the user for \
approval and are reversible via the Undo button, so prefer making the \
change directly over describing it."""

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
		"speech_speed": 1.15,
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

# Image attach (clipboard paste) — attached image is sent with the NEXT
# outgoing message only, then cleared. See _on_attach_image_pressed().
var _attach_image_btn: Button
var _image_attached_row: HBoxContainer
var _image_attached_label: Label
var _pending_image_b64: String = ""
var _abort_agent_btn: Button = null   # Phase 6b — shown during multi-hop agent runs
var _models_btn: Button
var _model_picker: AcceptDialog
var _api_key_dialog: AcceptDialog = null
var _approvals_dropdown: OptionButton
var _agent_mode_dropdown: OptionButton
var _audit_btn: Button

# Per-turn streaming tool dispatch watermark + multi-turn agent hop counter.
var _stream_tool_watermark: int = 0
var _agent_hops: int = 0
# Result strings from the most recent _apply_mutations() call, so
# _maybe_continue_agent_turn() can tell a genuine edit apart from a
# recoverable tool failure (e.g. no/wrong file open) and retry instead
# of stopping the loop with nothing actually changed.
var _last_mutation_results: Array[String] = []
var _agent_continuation: bool = false
# Phase 6b: configurable hop cap (user://vg_ai_approvals.cfg [ai] max_agent_hops)
var _max_agent_hops: int = 50

# Phase 6b: wall-time + token budget guards.
# Loaded from user://vg_ai_approvals.cfg [ai] section; hardcoded defaults below.
const _AGENT_MAX_TOKENS_DEFAULT := 120000
const _AGENT_MAX_SECONDS_DEFAULT := 600.0
var _max_agent_tokens: int = _AGENT_MAX_TOKENS_DEFAULT
var _max_agent_seconds: float = _AGENT_MAX_SECONDS_DEFAULT
var _agent_start_time: float = 0.0   # Time.get_ticks_msec()/1000 at first hop
var _agent_total_tokens: int = 0     # Tokens streamed since first hop

# Phase 6b: mutation→run→ingest loop state.
# When the agent emits play.run_main, we wait for _on_run_finished and
# feed the captured output back as the next hop context.
var _agent_triggered_run: bool = false
var _agent_run_output_lines: PackedStringArray = PackedStringArray()
const _AGENT_RUN_MAX_LINES := 80   # How many output lines to feed back

# Read-only personas get a tool whitelist applied per turn.  Empty array
# means "unrestricted" (the chokepoint is still SafeWrite for any disk
# write).  Narcea is the on-call dev — full powers.  Bob/Skippy/Orac are
# read-only critics by default; users can promote them via the per-persona
# config if they want.
const PERSONA_TOOL_WHITELIST := {
	# Read-only personas: all read/inspect tools but no mutating tools.
	"bob": [
		"highlight_lines", "clear_highlights", "goto_line", "open_file",
		"read_file", "list_dir", "find_in_files",
		"get_wn_project", "get_agck_project", "get_form_controls",
		"get_2d_scene_tree", "get_3d_scene", "get_vgmusic_project",
	],
	"skippy": [
		"highlight_lines", "clear_highlights", "goto_line", "open_file",
		"read_file", "list_dir", "find_in_files",
		"get_wn_project", "get_agck_project", "get_form_controls",
		"get_2d_scene_tree", "get_3d_scene", "get_vgmusic_project",
	],
	"orac": [
		"highlight_lines", "clear_highlights", "goto_line", "open_file",
		"read_file", "list_dir", "find_in_files",
		"get_wn_project", "get_agck_project", "get_form_controls",
		"get_2d_scene_tree", "get_3d_scene", "get_vgmusic_project",
	],
	"hal": [
		"highlight_lines", "clear_highlights", "goto_line", "open_file",
		"read_file", "list_dir", "find_in_files",
		"get_wn_project", "get_agck_project", "get_form_controls",
		"get_2d_scene_tree", "get_3d_scene", "get_vgmusic_project",
	],
	"narcea": [],  # unrestricted
	"default": [],  # unrestricted
}

# Cached concatenation of SYSTEM_PROMPT + TOOLS_PROMPT — built once at
# instantiation, avoids re-allocating ~8 KB on every query.
var _base_system_prompt := SYSTEM_PROMPT + TOOLS_PROMPT

# Cached popup theme objects — built once, reused for every dropdown open.
var _popup_panel_style: StyleBoxFlat = null
var _popup_hover_style: StyleBoxFlat = null
var _popup_sep_style: StyleBoxFlat = null
var _popup_theme: Theme = null

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
var _stream_vgtool_suppress := false   # True while inside a ```vg-tool block (suppressed from display)
var _stream_line_buf := ""             # Partial-line buffer for vg-tool fence detection
var _stream_line_displayed := 0        # How many bytes of _stream_line_buf have already been shown
var _stream_start_time := 0.0          # Time.get_ticks_msec() when query sent
var _stream_first_token_time := 0.0    # Time of first token (0 = not yet)
var _stream_http_phase := 0            # 0=idle, 1=connecting, 2=requesting, 3=body, 4=error body
var _stream_http_error_code := 0       # HTTP status code when phase==4
var _stream_http_error_name := ""      # Provider display name when phase==4
# Phase 6c: native FC call fragments accumulated during streaming.
var _fc_fragments: Array = []

# Phase 6e: NDJSON agent run transcript.
# One file per agent session, written to user://vg_agent_runs/<timestamp>.ndjson.
var _agent_transcript_file: FileAccess = null

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
# Lines from the last manual ▶ Run that looked like errors (stderr or
# lines starting with ERROR:/SCRIPT ERROR:).  Used as a fallback for
# 🐛 Explain Last Error when the debugger didn't capture a structured
# error context — closes the manual-run side of the reflect loop.
var _run_error_lines: PackedStringArray = PackedStringArray()
var _last_selected_code := ""

# Voice I/O (Tier 2.5) — controller is created lazily on first use
var _voice_ctrl = null
var _mic_btn: Button = null
var _voice_speak_toggle: Button = null
var _voice_vad_toggle: Button = null   # Tier 2.5b VAD auto-stop
# Tier 2.5d — full-duplex realtime voice (OpenAI Realtime / Gemini Live)
var _realtime_ctrl = null
var _realtime_btn: Button = null       # ⚡ toggle in toolbar
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
# "📐 From description" trio — lean-v1 Narcea spec-builder entry points.
# Always enabled.  Each opens a prose dialog, wraps the user's description
# in a hardened prompt that requires the matching spec block, and
# auto-sends.  Replies enable the existing Build/Make-* buttons.
var _form_from_desc_btn: Button = null
var _code_from_desc_btn: Button = null
var _project_from_desc_btn: Button = null
var _form_from_desc_mode: String = "form"  # "form" | "code" | "project"
var _last_send_was_desc_mode: bool = false  # set by Form…/Code…/Project… dialogs; cleared after refresh
var _last_build_intent: String = ""  # "form" | "code" | "project" | "" — chat-first build detection
var _last_user_prompt: String = ""  # original user text (before hardened prompt augmentation)
var _api_prompt_override: String = ""  # when set, sent to model instead of displayed chat text
var _code_followup_pending: bool = false  # auto follow-up when layout saved without vg-code-spec
var _build_form_ran_this_turn: bool = false  # set when build_form tool executes; prevents double-build
var _suppress_agent_loop: bool = false  # true while auto-scaffolding a project spec this turn
var _scaffold_in_progress: bool = false
# Tier-3 chat-only project-creation buttons.  Disabled until a parseable
# vg-code-spec / vg-project-spec block is in the latest reply.  Run is
# enabled whenever something has been built or the user opens an existing
# AI-scaffolded project so Narcea can iterate against runtime output.
var _make_code_btn: Button = null
var _make_project_btn: Button = null
var _run_btn: Button = null
var _run_stop_btn: Button = null
# Toolbar additions (Phase 7): per-feature buttons added in batch.
var _make_test_btn: Button = null
var _make_wnodes_btn: Button = null
var _toolbar3_advanced: HBoxContainer = null
var _advanced_toggle_btn: Button = null
var _undo_btn: Button = null
var _pin_btn: Button = null
var _summarize_errors_btn: Button = null
var _retry_patch_btn: Button = null
# Lazy-loaded helpers for the speech sanitiser and form-spec applier.
var _speech_filter = null  # vg_ai_speech_filter.gd instance
var _form_spec = null      # vg_ai_form_spec.gd instance
var _safe_writer = null    # vg_ai_safe_write.gd instance
var _code_spec = null      # vg_ai_code_spec.gd instance
var _patch_spec = null     # vg_ai_patch_spec.gd instance
var _project_spec = null   # vg_ai_project_spec.gd instance
var _test_spec = null      # vg_ai_test_spec.gd instance
var _wnodes_spec = null    # vg_ai_wnodes_spec.gd instance
var _lesson_spec = null    # vg_ai_lesson_spec.gd instance
var _run_session = null    # vg_ai_run_session.gd Node
var _last_run_scene := ""  # res:// path of the last thing we ran
var _last_project_root := ""  # res:// dir scaffolded by Make project

# --- Phase 7 feature state -------------------------------------------------
# Undo stack: newest last.  Each entry = {label, ts, files:[{path,old}]}.
# Capped at _UNDO_DEPTH so memory stays bounded.
var _undo_stack: Array = []
const _UNDO_DEPTH := 20
# Pinned files pushed to Narcea on every prompt build.
var _pinned_files: PackedStringArray = PackedStringArray()
# Last patch result — drives the "🔁 Retry patch" button + diff-aware
# follow-ups (#11).  Empty until the first apply.
var _last_apply_result: Dictionary = {}
var _last_apply_kind := ""   # "Code" / "Patch" / "Test" / ""
# Compact diff string of the most recent apply ("path: +N -M lines …").
# Prepended to user prompts that look like follow-ups ("also", "undo",
# "why did you", "now make it ...").
var _last_apply_diff_summary := ""

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
	# Phase 6c: load native function-calling adapter (optional — degrades gracefully).
	VgAiFC = load("res://addons/visual_gasic/vg_ai_function_calling.gd")
	if AIProviders:
		AIProviders.prune_cached_model_lists()
		_provider_id = AIProviders.load_preferred_provider()
		_provider_info = AIProviders.find_provider(_provider_id)
	if _provider_info == null:
		_provider_id = "ollama"
		_provider_info = AIProviders.find_provider("ollama") if AIProviders else null
	_setup_ui()
	_setup_poll_timer()
	_setup_http()
	_activate_provider()
	call_deferred("_restore_last_run_from_disk")

func _enter_tree() -> void:
	visible = true
	if _ping_http:
		_reinit_after_reparent.call_deferred()

func _reinit_after_reparent() -> void:
	_ping_http.cancel_request()
	if _is_generating:
		_stop_generation()
	_warmup_http.cancel_request()
	if _stream_http != null:
		_stream_http.close()
		_stream_http = null
	_is_generating = false
	_ollama_available = false
	_model_warm = false
	_stream_http_phase = 0
	# Re-activate using the active provider (Ollama, Claude, OpenAI, …)
	# rather than blindly pinging Ollama — otherwise cloud users see
	# "Ollama not found" until they manually reopen the API key dialog.
	if _provider_info != null and not _provider_info.is_local:
		_activate_provider()
	else:
		_ping_ollama()

func _exit_tree() -> void:
	_stop_generation()

func _setup_poll_timer() -> void:
	_poll_timer = Timer.new()
	_poll_timer.name = "StreamPollTimer"
	_poll_timer.wait_time = STREAM_POLL_INTERVAL
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
					_stream_http_error_code = code
					_stream_http_error_name = pname
					_stream_http_phase = 4  # Read error body before setting _stream_error
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
					# Guard against runaway / malformed responses (no-newline output, hung connection).
					if _stream_buf.length() > 524288:  # 512 KB
						_stream_error = "Response too large (>512 KB) — possible runaway model output"
						_stream_done = true
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
							# Phase 6c: collect native FC fragments alongside text tokens.
							if VgAiFC and VgAiFC.supports_native_fc(_provider_id):
								var fc_frag = VgAiFC.parse_stream_line_for_fc(_provider_id, line)
								if fc_frag:
									_fc_fragments.append(fc_frag)
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

		elif _stream_http_phase == 4:  # Reading error response body
			if status == HTTPClient.STATUS_BODY:
				var chunk := _stream_http.read_response_body_chunk()
				if chunk.size() > 0:
					_stream_buf += chunk.get_string_from_utf8()
			elif status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_DISCONNECTED:
				# Parse a human-readable detail out of the error body
				var detail := ""
				var parsed = JSON.parse_string(_stream_buf)
				if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
					# Anthropic: { "error": { "message": "..." } }
					# OpenAI:    { "error": { "message": "..." } }
					# Gemini:    { "error": { "message": "..." } }
					var err_obj = parsed.get("error", null)
					if typeof(err_obj) == TYPE_DICTIONARY:
						detail = err_obj.get("message", "")
					elif typeof(err_obj) == TYPE_STRING:
						detail = err_obj
				if detail.is_empty() and not _stream_buf.is_empty():
					detail = _stream_buf.strip_edges().left(200)
				if detail.is_empty():
					_stream_error = "%s error: HTTP %d" % [_stream_http_error_name, _stream_http_error_code]
				else:
					_stream_error = "%s error: HTTP %d — %s" % [_stream_http_error_name, _stream_http_error_code, detail]
				_stream_buf = ""
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
		_stream_vgtool_suppress = false
		_stream_line_buf = ""
		_stream_line_displayed = 0
	_stream_token_count += 1
	_agent_total_tokens += 1   # Phase 6b: accumulate across agent hops
	_accumulated_response += token
	# --- vg-tool block suppression ---
	# Buffer tokens by line so we can detect ```vg-tool fences and suppress
	# their raw JSON content from the chat panel.  A compact indicator is shown
	# instead so the user knows a tool ran without seeing the raw payload.
	_stream_line_buf += token
	while "\n" in _stream_line_buf:
		var nl := _stream_line_buf.find("\n")
		var line := _stream_line_buf.substr(0, nl)
		_stream_line_buf = _stream_line_buf.substr(nl + 1)
		var stripped := line.strip_edges()
		if stripped == "```vg-tool":
			_stream_vgtool_suppress = true
			_stream_line_displayed = 0
		elif stripped == "```" and _stream_vgtool_suppress:
			_stream_vgtool_suppress = false
			_stream_line_displayed = 0
			_output.append_text("[color=#888888]⚙ (tool running…)[/color]\n")
		elif not _stream_vgtool_suppress:
			# Display only the portion of this line not yet shown (handles
			# partial-line pre-display of non-fence content).
			var to_show := line.substr(_stream_line_displayed) + "\n"
			_output.append_text(_escape_bbcode(to_show))
			_stream_line_displayed = 0
		else:
			_stream_line_displayed = 0
	# Flush partial (not-yet-newline) content immediately when we're sure
	# it can't be a vg-tool fence opener (lines starting with `` ` `` are
	# held until the full line is known).
	if not _stream_vgtool_suppress and not _stream_line_buf.strip_edges().begins_with("`"):
		var undisplayed := _stream_line_buf.substr(_stream_line_displayed)
		if not undisplayed.is_empty():
			_output.append_text(_escape_bbcode(undisplayed))
			_stream_line_displayed = _stream_line_buf.length()
	# Tier 2.5c: stream token directly into TTS pipeline so sentences begin
	# playing as soon as they complete, rather than after the full reply.
	if is_instance_valid(_voice_speak_toggle) and _voice_speak_toggle.button_pressed:
		_ensure_voice_ctrl()
		if _voice_ctrl != null and _voice_ctrl.has_method("speak_streaming_chunk"):
			_voice_ctrl.speak_streaming_chunk(token)
	# Streaming tool dispatch: as soon as a closing fence appears in the
	# accumulated reply, run any complete vg-tool blocks.  This lets the
	# model see read-tool results sooner and produces faster UX feedback.
	if _ai_tools != null and _accumulated_response.find("```", _stream_tool_watermark) != -1:
		var sd: Dictionary = _ai_tools.dispatch_streaming(_accumulated_response, _stream_tool_watermark)
		_stream_tool_watermark = int(sd.get("watermark", _stream_tool_watermark))
		var slogs: Array = sd.get("logs", [])
		for sl in slogs:
			_output.append_text("\n[color=#888888]  " + _escape_bbcode(str(sl)) + "[/color]\n")

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
		# Trim to last N exchanges (N user + N assistant = 2N entries) --
		# but only between fresh top-level turns, never mid multi-hop agent
		# loop (_agent_hops > 0). Each hop of a long agent turn appends its
		# own pair here; trimming unconditionally could evict earlier hops
		# of the SAME in-progress task (e.g. a tool-failure correction the
		# model needs to see) before the loop even finishes. The deferred
		# trim still fires at the start of the next fresh turn.
		if _agent_hops == 0:
			while _conversation_history.size() > MAX_HISTORY_EXCHANGES * 2:
				_conversation_history.pop_front()
		# A successful exchange proves the model is loaded and responsive \u2014
		# skip the health-check round-trip on subsequent queries.
		_model_warm = true

	# --- Tool dispatch ---
	# Scan the completed reply for ```vg-tool``` blocks and execute each.
	# This is what lets Narcea (and the other personas) actually drive the
	# editor — highlight lines, jump the caret, insert/replace code, save,
	# write whole files via the SafeWrite chokepoint.  See vg_ai_tools.gd.
	#
	# Phase 6c: if the model used native function-calling (OpenAI/Claude/Gemini),
	# the streamed tool_calls / input_json_delta / functionCall fragments are in
	# _fc_fragments.  Assemble and convert them to fenced vg-tool blocks so the
	# existing dispatch path handles them without modification.
	if VgAiFC and not _fc_fragments.is_empty():
		var calls: Array = VgAiFC.assemble_fc_calls(_fc_fragments)
		if not calls.is_empty():
			var fenced: String = VgAiFC.to_fenced_text(calls)
			if not _accumulated_response.is_empty():
				_accumulated_response += "\n"
			_accumulated_response += fenced
			_output.append_text("[color=#888888]  (native function calls converted)[/color]\n")
		_fc_fragments.clear()
	if not _accumulated_response.is_empty():
		_transcript_log_assistant_response(_accumulated_response)
		# Schedule auto-scaffold BEFORE tool dispatch — otherwise the agent
		# loop can synchronously start hop 2 while FormDesigner I/O runs on
		# the main thread, freezing the whole editor (menus included).
		_refresh_build_form_btn()
		_dispatch_tool_calls(_accumulated_response)
	# Flush any partial line that was buffered for vg-tool fence detection.
	if not _stream_vgtool_suppress and not _stream_line_buf.is_empty():
		var undisplayed := _stream_line_buf.substr(_stream_line_displayed)
		if not undisplayed.is_empty():
			_output.append_text(_escape_bbcode(undisplayed))
	_stream_line_buf = ""
	_stream_line_displayed = 0
	_stream_tool_watermark = 0

	# NOTE: _dispatch_tool_calls() above can, via the agent loop
	# (_maybe_continue_agent_turn -> _on_send -> _send_query ->
	# _send_cloud_query), synchronously kick off the NEXT hop's request
	# before returning here -- that nested call already set _current_prompt
	# / _accumulated_response / _is_generating for the new in-flight hop.
	# Resetting _current_prompt unconditionally would clobber that state
	# before the new hop's response even arrives, which permanently broke
	# conversation-history logging for every continuation hop (every
	# multi-hop agent turn only ever recorded its FIRST hop; hops 2+ never
	# got appended because _current_prompt read back empty in
	# _finish_generation() -- confirmed via VG_DEBUG_AGENT_HOPS tracing).
	if not _is_generating:
		_current_prompt = ""

	if not _is_generating:
		if is_instance_valid(_send_btn):
			_send_btn.visible = true
		if is_instance_valid(_stop_btn):
			_stop_btn.visible = false
		if is_instance_valid(_status_label):
			var pname: String = _provider_info.display_name if _provider_info else "Ollama"
			_status_label.text = ("✅ %s ready" % pname) if _ollama_available else ("❌ %s not found" % pname)
			_status_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if _ollama_available else Color(1.0, 0.4, 0.4))

	# Voice mode (Tier 2.5c): flush any remaining buffered tokens to the TTS
	# sentence queue now that the stream is complete.  The first sentences
	# have typically been dispatched and may already be playing.
	if is_instance_valid(_voice_speak_toggle) and _voice_speak_toggle.button_pressed:
		_ensure_voice_ctrl()
		if _voice_ctrl != null:
			if _voice_ctrl.has_method("flush_streaming_speak"):
				_voice_ctrl.flush_streaming_speak()
			elif not _accumulated_response.strip_edges().is_empty():
				# Fallback for voice controllers that don't support streaming.
				_voice_ctrl.speak(_speech_text(_accumulated_response))

	# Narcea-seeded project flow: when the welcome shell created this
	# project for Narcea to fill, auto-apply the first project-spec
	# response so the user doesn't have to click 🆕 Make-project. Fires
	# once per project — we clear the flag (in ProjectSettings) on
	# success so subsequent replies need explicit user action.
	_maybe_auto_apply_narcea_seed()

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
	_stream_http_error_code = 0
	_stream_http_error_name = ""
	_stream_done = false
	_stream_error = ""
	_stream_started = false
	_stream_token_count = 0
	_stream_buf = ""
	_accumulated_response = ""
	_agent_continuation = false
	_agent_hops = 0
	_agent_total_tokens = 0
	_stream_tool_watermark = 0
	_stream_vgtool_suppress = false
	_stream_line_buf = ""
	_stream_line_displayed = 0
	_fc_fragments.clear()
	_agent_abort_requested = false
	_hide_abort_agent_btn()
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

	# --- Toolbar (two rows to prevent overflow at narrow widths) ---
	var toolbar_vbox := VBoxContainer.new()
	toolbar_vbox.add_theme_constant_override("separation", 2)
	main_vbox.add_child(toolbar_vbox)

	# Row 1: provider/model/status + config controls
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_vbox.add_child(toolbar)

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

	# ── Refresh models button ──
	var _refresh_models_btn := Button.new()
	_refresh_models_btn.tooltip_text = "Refresh model list from provider API (replaces cache; removes models no longer returned)"
	_refresh_models_btn.pressed.connect(_on_refresh_models)
	_style_toolbar_icon_button(_refresh_models_btn, "⟳")
	toolbar.add_child(_refresh_models_btn)

	# ── Models manager button ──
	_models_btn = Button.new()
	_models_btn.tooltip_text = "Browse & download AI models"
	_models_btn.pressed.connect(_show_model_picker)
	_style_toolbar_icon_button(_models_btn, "↓")
	toolbar.add_child(_models_btn)

	toolbar.add_child(_make_separator())

	_status_label = Label.new()
	var _init_pname: String = _provider_info.display_name if _provider_info else "AI provider"
	_status_label.text = "⏳ Checking %s..." % _init_pname
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# ── 🛡 AI approval mode (Ask / Bypass / Read-only) ──
	_approvals_dropdown = OptionButton.new()
	_approvals_dropdown.add_item("🛡 Ask", 0)
	_approvals_dropdown.add_item("⚡ Bypass", 1)
	_approvals_dropdown.add_item("👁 Read-only", 2)
	_approvals_dropdown.tooltip_text = "How AI edits are gated:\n  Ask — confirm each batch (default)\n  Bypass — apply immediately (still undoable)\n  Read-only — no mutations at all"
	_approvals_dropdown.item_selected.connect(_on_approvals_selected)
	_style_option_button(_approvals_dropdown)
	toolbar.add_child(_approvals_dropdown)
	# Position will be set after _load_approval_mode() runs.

	# ── 🤖 Agent mode (off / Narcea only / all / always-ask) ──
	_agent_mode_dropdown = OptionButton.new()
	_agent_mode_dropdown.add_item("🤖 Narcea only", 0)
	_agent_mode_dropdown.add_item("🤖 All personas", 1)
	_agent_mode_dropdown.add_item("❓ Always ask", 2)
	_agent_mode_dropdown.add_item("🚫 Agent off", 3)
	_agent_mode_dropdown.tooltip_text = "Which personas can trigger the auto-run agent loop:\n  Narcea only — default; only the Narcea persona auto-loops\n  All personas — any persona may auto-loop\n  Always ask — show confirmation before each agent hop\n  Agent off — agent loop disabled; tool blocks show but need manual approval"
	_agent_mode_dropdown.item_selected.connect(_on_agent_mode_selected)
	_style_option_button(_agent_mode_dropdown)
	toolbar.add_child(_agent_mode_dropdown)

	# ── 📜 Audit log viewer ──
	_audit_btn = Button.new()
	_audit_btn.text = "📜"
	_audit_btn.tooltip_text = "View AI audit log (every file the AI has read or written)"
	_audit_btn.pressed.connect(_show_audit_log)
	_style_small_button(_audit_btn)
	toolbar.add_child(_audit_btn)

	_clear_btn = Button.new()
	_clear_btn.text = "🗑 Clear"
	_clear_btn.tooltip_text = "Clear conversation"
	_clear_btn.pressed.connect(_on_clear)
	_style_toolbar_light_button(_clear_btn)
	toolbar.add_child(_clear_btn)

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
	_style_option_button(_persona_dropdown)
	toolbar.add_child(_persona_dropdown)
	# Editor's default OptionButton popup theme renders nearly invisible
	# dark text on the dark VG bottom panel — force the proven dark popup
	# styling used by vg_2d_editor's _style_popup_dark(). Applied to all
	# toolbar dropdowns (provider, model, approvals, persona, agent_mode).
	for dd in [_provider_dropdown, _model_dropdown, _approvals_dropdown, _persona_dropdown, _agent_mode_dropdown]:
		_style_dropdown_popup_dark(dd)

	# Row 2: essential actions (always visible)
	var toolbar2 := HBoxContainer.new()
	toolbar2.add_theme_constant_override("separation", 4)
	toolbar_vbox.add_child(toolbar2)

	_advanced_toggle_btn = Button.new()
	_advanced_toggle_btn.text = "Advanced ▾"
	_advanced_toggle_btn.toggle_mode = true
	_advanced_toggle_btn.tooltip_text = "Show voice controls and manual Form/Code/Project actions"
	_advanced_toggle_btn.toggled.connect(_on_advanced_toolbar_toggled)
	_style_toolbar_light_button(_advanced_toggle_btn)
	toolbar2.add_child(_advanced_toggle_btn)

	toolbar2.add_child(_make_separator())

	# Row 3: advanced controls (voice + manual spec actions) — hidden until toggled
	_toolbar3_advanced = HBoxContainer.new()
	_toolbar3_advanced.add_theme_constant_override("separation", 4)
	_toolbar3_advanced.visible = false
	toolbar_vbox.add_child(_toolbar3_advanced)

	# 🎙 Voice mode — push-to-talk button + auto-speak toggle (Tier 2.5)
	_mic_btn = Button.new()
	_mic_btn.text = "🎙"
	_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"
	_mic_btn.toggle_mode = true
	_mic_btn.toggled.connect(_on_mic_toggled)
	_style_small_button(_mic_btn)
	_toolbar3_advanced.add_child(_mic_btn)

	_voice_speak_toggle = Button.new()
	_voice_speak_toggle.toggle_mode = true
	_voice_speak_toggle.text = "🔊"
	_voice_speak_toggle.tooltip_text = "Speak AI replies aloud"
	_voice_speak_toggle.button_pressed = true
	_voice_speak_toggle.toggled.connect(_on_auto_speak_toggled)
	_style_toolbar_light_button(_voice_speak_toggle)
	_toolbar3_advanced.add_child(_voice_speak_toggle)

	_voice_vad_toggle = Button.new()
	_voice_vad_toggle.toggle_mode = true
	_voice_vad_toggle.text = "VAD"
	_voice_vad_toggle.tooltip_text = "Auto-stop recording after silence (Voice Activity Detection)"
	_voice_vad_toggle.button_pressed = true
	_voice_vad_toggle.toggled.connect(_on_vad_toggled)
	_style_toolbar_light_button(_voice_vad_toggle)
	_toolbar3_advanced.add_child(_voice_vad_toggle)

	# ⚡ Realtime mode toggle (Tier 2.5d — OpenAI Realtime / Gemini Live)
	_realtime_btn = Button.new()
	_realtime_btn.toggle_mode = true
	_realtime_btn.text = "⚡"
	_realtime_btn.tooltip_text = "Realtime voice mode: continuous full-duplex conversation (OpenAI Realtime / Gemini Live). Configure backend in ⚙️ Voice Settings."
	_realtime_btn.button_pressed = false
	_realtime_btn.toggled.connect(_on_realtime_toggled)
	_style_toolbar_light_button(_realtime_btn)
	_toolbar3_advanced.add_child(_realtime_btn)

	# ⏹ Stop-Speaking button — hidden until Narcea actually starts talking.
	_stop_speak_btn = Button.new()
	_stop_speak_btn.text = "⏹"
	_stop_speak_btn.tooltip_text = "Stop the current spoken reply"
	_stop_speak_btn.visible = false
	_stop_speak_btn.pressed.connect(_on_stop_speak)
	_style_small_button(_stop_speak_btn)
	_toolbar3_advanced.add_child(_stop_speak_btn)

	_toolbar3_advanced.add_child(_make_separator())

	# 📐 Form-from-description — lean-v1 Narcea form-builder.  Always
	# enabled; opens a prose-description dialog and auto-sends a hardened
	# prompt that requires a vg-form-spec reply.
	_form_from_desc_btn = Button.new()
	_form_from_desc_btn.text = "📐 Form…"
	_form_from_desc_btn.tooltip_text = "Advanced: open a description dialog with a hardened form-spec prompt"
	_form_from_desc_btn.pressed.connect(_on_form_from_desc_pressed)
	_form_from_desc_btn.visible = false
	_style_small_button(_form_from_desc_btn)
	_toolbar3_advanced.add_child(_form_from_desc_btn)

	# 📝 Code-from-description — same flow but requires a vg-code-spec block.
	_code_from_desc_btn = Button.new()
	_code_from_desc_btn.text = "📝 Code…"
	_code_from_desc_btn.tooltip_text = "Advanced: hardened vg-code-spec prompt dialog"
	_code_from_desc_btn.pressed.connect(_on_code_from_desc_pressed)
	_code_from_desc_btn.visible = false
	_style_small_button(_code_from_desc_btn)
	_toolbar3_advanced.add_child(_code_from_desc_btn)

	# 🆕 Project-from-description — requires a vg-project-spec block.
	_project_from_desc_btn = Button.new()
	_project_from_desc_btn.text = "🆕 Project…"
	_project_from_desc_btn.tooltip_text = "Advanced: hardened vg-project-spec prompt dialog"
	_project_from_desc_btn.pressed.connect(_on_project_from_desc_pressed)
	_project_from_desc_btn.visible = false
	_style_small_button(_project_from_desc_btn)
	_toolbar3_advanced.add_child(_project_from_desc_btn)

	_toolbar3_advanced.add_child(_make_separator())

	# 🔨 Build-Form — kept for programmatic use; not shown (Apply form covers it).
	_build_form_btn = Button.new()
	_build_form_btn.text = "🔨 Build form"
	_build_form_btn.visible = false
	_build_form_btn.pressed.connect(_on_build_form)

	# Apply form — programmatic / auto-apply only; not shown in toolbar (chat-first).
	_make_this_btn = Button.new()
	_make_this_btn.text = "Apply form"
	_make_this_btn.tooltip_text = "Build the form, save it, and write event-handler stubs in one go"
	_make_this_btn.disabled = true
	_make_this_btn.visible = false
	_make_this_btn.pressed.connect(_on_make_this)
	_style_small_button(_make_this_btn)
	_toolbar3_advanced.add_child(_make_this_btn)

	# Make code — programmatic / auto-apply only; not shown in toolbar.
	_make_code_btn = Button.new()
	_make_code_btn.text = "Make code"
	_make_code_btn.tooltip_text = "Advanced: manually apply the latest vg-code-spec block"
	_make_code_btn.disabled = true
	_make_code_btn.visible = false
	_make_code_btn.pressed.connect(_on_make_code)
	_style_small_button(_make_code_btn)
	_toolbar3_advanced.add_child(_make_code_btn)

	# Make project — programmatic / auto-apply only; not shown in toolbar.
	_make_project_btn = Button.new()
	_make_project_btn.text = "Make project"
	_make_project_btn.tooltip_text = "Advanced: manually scaffold the latest vg-project-spec block"
	_make_project_btn.disabled = true
	_make_project_btn.visible = false
	_make_project_btn.pressed.connect(_on_make_project)
	_style_small_button(_make_project_btn)
	_toolbar3_advanced.add_child(_make_project_btn)

	# ▶ Run — launch the last-built (or main) scene, pipe stdout into chat.
	_run_btn = Button.new()
	_run_btn.text = "\u25b6 Run"
	_run_btn.tooltip_text = "Run the last AI-built scene and stream its output into this panel"
	_run_btn.disabled = true
	_run_btn.pressed.connect(_on_run)
	_style_small_button(_run_btn)
	toolbar2.add_child(_run_btn)

	_run_stop_btn = Button.new()
	_run_stop_btn.text = "\u23f9"
	_run_stop_btn.tooltip_text = "Stop the running scene"
	_run_stop_btn.visible = false
	_run_stop_btn.pressed.connect(_on_run_stop)
	_style_small_button(_run_stop_btn)
	toolbar2.add_child(_run_stop_btn)

	# Make test / Make WN — niche; only shown when Narcea emitted the matching spec.
	_make_test_btn = Button.new()
	_make_test_btn.text = "Make test"
	_make_test_btn.tooltip_text = "Ask Narcea for a vg-test-spec block to enable this."
	_make_test_btn.disabled = true
	_make_test_btn.visible = false
	_make_test_btn.pressed.connect(_on_make_test)
	_style_small_button(_make_test_btn)
	_toolbar3_advanced.add_child(_make_test_btn)

	# Make .wnodes — write a Working Nodes graph from a vg-wnodes-spec.
	_make_wnodes_btn = Button.new()
	_make_wnodes_btn.text = "Make WN"
	_make_wnodes_btn.tooltip_text = "Ask Narcea for a vg-wnodes-spec block to enable this."
	_make_wnodes_btn.disabled = true
	_make_wnodes_btn.visible = false
	_make_wnodes_btn.pressed.connect(_on_make_wnodes)
	_style_small_button(_make_wnodes_btn)
	_toolbar3_advanced.add_child(_make_wnodes_btn)

	# ↩ Undo last AI edit — restores files captured before the last apply.
	_undo_btn = Button.new()
	_undo_btn.text = "\u21a9 Undo"
	_undo_btn.tooltip_text = "Restore the file(s) from before the last AI edit."
	_undo_btn.disabled = true
	_undo_btn.pressed.connect(_on_undo_last_edit)
	_style_small_button(_undo_btn)
	toolbar2.add_child(_undo_btn)

	# 📌 Pin file — opens a small dialog to pin the open file (or a path).
	_pin_btn = Button.new()
	_pin_btn.text = "\ud83d\udccc Pin"
	_pin_btn.tooltip_text = "Pin the currently-open file so Narcea always sees its contents."
	_pin_btn.pressed.connect(_on_pin_file)
	_style_small_button(_pin_btn)
	toolbar2.add_child(_pin_btn)

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

	# 📋 Summarize errors — visible only when the buffer has > 20 lines.
	_summarize_errors_btn = Button.new()
	_summarize_errors_btn.text = "\ud83d\udccb Summarize errors"
	_summarize_errors_btn.tooltip_text = "Cluster repeated errors from the last run and find the root cause."
	_summarize_errors_btn.pressed.connect(_on_summarize_errors)
	_style_action_button(_summarize_errors_btn, Color(1.0, 0.8, 0.5))
	_summarize_errors_btn.visible = false
	actions.add_child(_summarize_errors_btn)

	# 🔁 Retry patch — only visible after a patch had anchor failures.
	_retry_patch_btn = Button.new()
	_retry_patch_btn.text = "\ud83d\udd01 Retry patch"
	_retry_patch_btn.tooltip_text = "Ask Narcea for a corrected vg-patch-spec for the anchors that failed."
	_retry_patch_btn.pressed.connect(_on_retry_patch)
	_style_action_button(_retry_patch_btn, Color(1.0, 0.7, 0.7))
	_retry_patch_btn.visible = false
	actions.add_child(_retry_patch_btn)

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
	# Image attach indicator — hidden until an image is pasted from the clipboard.
	_image_attached_row = HBoxContainer.new()
	_image_attached_row.visible = false
	_image_attached_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_image_attached_row)

	var _image_icon := Label.new()
	_image_icon.text = "📎"
	_image_attached_row.add_child(_image_icon)

	_image_attached_label = Label.new()
	_image_attached_label.text = "image attached"
	_image_attached_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_attached_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_image_attached_row.add_child(_image_attached_label)

	var _remove_image_btn := Button.new()
	_remove_image_btn.text = "✕"
	_remove_image_btn.tooltip_text = "Remove attached image"
	_remove_image_btn.pressed.connect(_on_remove_attached_image)
	_style_small_button(_remove_image_btn)
	_image_attached_row.add_child(_remove_image_btn)

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
	_input.tree_entered.connect(func(): _style_context_menu(_input))
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

	_attach_image_btn = Button.new()
	_attach_image_btn.text = "Browse…"
	_attach_image_btn.custom_minimum_size = Vector2(76, 0)
	_attach_image_btn.tooltip_text = "Attach an image from the clipboard (vision-capable providers only). Paste with Ctrl+V."
	_attach_image_btn.pressed.connect(_on_attach_image_pressed)
	_style_input_row_button(_attach_image_btn)
	btn_col.add_child(_attach_image_btn)

	# Phase 6b: Abort agent button — visible while a multi-hop loop is running.
	_abort_agent_btn = Button.new()
	_abort_agent_btn.text = "🛑 Abort"
	_abort_agent_btn.custom_minimum_size = Vector2(70, 0)
	_abort_agent_btn.pressed.connect(_on_abort_agent)
	_abort_agent_btn.visible = false
	_abort_agent_btn.tooltip_text = "Abort the running agent loop"
	_style_input_row_button(_abort_agent_btn)
	btn_col.add_child(_abort_agent_btn)

# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------
func _make_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	return sep

func _style_small_button(btn: Button) -> void:
	_style_toolbar_light_button(btn)

## Compact toolbar icon — ⟳ refresh, model picker, etc. Uses readable Unicode glyphs.
func _style_toolbar_icon_button(btn: Button, icon_text: String) -> void:
	_style_toolbar_light_button(btn)
	btn.text = icon_text
	btn.custom_minimum_size = Vector2(30, 26)
	btn.add_theme_font_size_override("font_size", 16)

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
	## Light VB6-style chip — matches the readable persona dropdown on the dark toolbar.
	opt.add_theme_font_size_override("font_size", 11)
	opt.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
	opt.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.45))
	opt.add_theme_color_override("font_pressed_color", Color(0.08, 0.08, 0.10))
	opt.add_theme_color_override("font_focus_color", Color(0.08, 0.08, 0.10))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.55, 0.55, 0.62, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	opt.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.97, 0.98, 1.0, 1.0)
	hover.border_color = Color(0.35, 0.45, 0.70, 1.0)
	opt.add_theme_stylebox_override("hover", hover)
	# Stay white while the menu is open (Godot uses the pressed stylebox).
	var pressed := normal.duplicate()
	pressed.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	pressed.border_color = Color(0.30, 0.50, 0.80, 1.0)
	opt.add_theme_stylebox_override("pressed", pressed)
	var focus := normal.duplicate()
	opt.add_theme_stylebox_override("focus", focus)
	# Editor theme resets the closed control to grey when the popup opens.
	if not opt.has_meta("_vg_light_option_styled"):
		opt.set_meta("_vg_light_option_styled", true)
		VGGodotCompat.connect_popup_preshow(opt, func() -> void:
			if is_instance_valid(opt):
				_reapply_light_option_button(opt)
		)
		var popup := opt.get_popup()
		if popup:
			popup.popup_hide.connect(func() -> void:
				if is_instance_valid(opt):
					_style_option_button(opt)
			)

func _reapply_light_option_button(opt: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.30, 0.50, 0.80, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	opt.add_theme_stylebox_override("normal", normal)
	opt.add_theme_stylebox_override("pressed", normal.duplicate())
	opt.add_theme_stylebox_override("hover", normal.duplicate())
	opt.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
	opt.add_theme_color_override("font_pressed_color", Color(0.08, 0.08, 0.10))

## Light toolbar button — visually matches _style_option_button (e.g. Clear).
func _style_toolbar_light_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.08, 0.08, 0.10))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.45))
	btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.08, 0.10))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.58))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.55, 0.55, 0.62, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.97, 0.98, 1.0, 1.0)
	hover.border_color = Color(0.35, 0.45, 0.70, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	if btn.toggle_mode:
		pressed.bg_color = Color(0.92, 0.95, 1.0, 1.0)
	else:
		pressed.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	pressed.border_color = Color(0.30, 0.50, 0.80, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.94, 0.94, 0.94, 1.0)
	disabled.border_color = Color(0.72, 0.72, 0.76, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("disabled_mirrored", disabled.duplicate())
	var focus := normal.duplicate()
	btn.add_theme_stylebox_override("focus", focus)

## High-contrast button for the chat input column (Browse, Abort) — sits on the
## light VB6 bottom panel where dark-toolbar button colors are unreadable.
func _style_input_row_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.45))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0))
	btn.add_theme_color_override("font_focus_color", Color(0.0, 0.0, 0.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.48))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.35, 0.50, 0.72, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.94, 0.96, 1.0, 1.0)
	hover.border_color = Color(0.20, 0.40, 0.70, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.88, 0.92, 0.98, 1.0)
	pressed.border_color = Color(0.15, 0.35, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.94, 0.94, 0.94, 1.0)
	disabled.border_color = Color(0.72, 0.72, 0.76, 1.0)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("disabled_mirrored", disabled.duplicate())
	var focus := normal.duplicate()
	focus.border_color = Color(0.20, 0.45, 0.80, 1.0)
	btn.add_theme_stylebox_override("focus", focus)

# ---------------------------------------------------------------------------
# Ollama connectivity
# ---------------------------------------------------------------------------
func _ping_ollama() -> void:
	var pname: String = _provider_info.display_name if _provider_info else "Ollama"
	_status_label.text = "⏳ Checking %s..." % pname
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
	var pname2: String = _provider_info.display_name if _provider_info else "Ollama"
	_status_label.text = "✅ %s connected" % pname2
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
		elif event.keycode == KEY_V and (event.ctrl_pressed or event.meta_pressed):
			_maybe_paste_clipboard_image()
		elif event.keycode == KEY_UP and _input.get_caret_line() == 0:
			_navigate_history(-1)
		elif event.keycode == KEY_DOWN and _input.get_caret_line() == _input.get_line_count() - 1:
			_navigate_history(1)

## Ctrl+V / Cmd+V in the chat input: try to grab an image from the system
## clipboard first (same OS-level capture the 📷 button uses). If there's no
## image on the clipboard, fall through to CodeEdit's default text-paste
## behaviour untouched.
## NOTE: this deliberately does NOT gate on DisplayServer.clipboard_has() —
## many screenshot tools (GNOME Screenshot, Flameshot, etc.) populate a
## text/plain representation (e.g. a file:// URI) alongside the image/png
## one, which made clipboard_has() return true and skip image capture
## entirely, so Ctrl+V silently did nothing when the clipboard held an
## image. Attempting the image grab unconditionally and falling back on
## failure is more reliable, at the cost of one extra subprocess spawn
## (xclip/wl-paste/osascript/powershell) on every paste in this box.
func _maybe_paste_clipboard_image() -> void:
	var img := _paste_image_from_system_clipboard()
	if img == null:
		return
	_input.get_viewport().set_input_as_handled()
	_attach_captured_image(img)

func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	_history_idx = clampi(_history_idx + direction, 0, _history.size() - 1)
	_input.text = _history[_history_idx]
	_input.set_caret_line(_input.get_line_count() - 1)
	_input.set_caret_column(_input.get_line(_input.get_caret_line()).length())

# ---------------------------------------------------------------------------
# Image attach (clipboard paste)
# ---------------------------------------------------------------------------
func _on_attach_image_pressed() -> void:
	var img := _paste_image_from_system_clipboard()
	if img == null:
		_append_system("[color=yellow](no image found on the clipboard — copy a screenshot or image first)[/color]\n")
		return
	_attach_captured_image(img)

## Downscales, encodes, and stages a captured clipboard Image as the pending
## attachment for the next outgoing message. Shared by the 📷 button and the
## Ctrl+V shortcut.
func _attach_captured_image(img: Image) -> void:
	# Downscale large screenshots before encoding. Full-resolution desktop
	# screenshots (e.g. 1920x1080+) can produce multi-MB base64 payloads,
	# which makes the request body huge — slow to build (the cloud send
	# path round-trips the whole body through JSON.parse_string/stringify
	# to inject tool schemas) and slow to upload, which looked like Send
	# doing "nothing" while it was actually just stuck for a long time.
	# Vision-capable APIs downscale internally anyway, so there's no
	# quality reason to send full resolution.
	const MAX_IMAGE_EDGE := 1280
	var w := img.get_width()
	var h := img.get_height()
	if maxi(w, h) > MAX_IMAGE_EDGE:
		var scale: float = float(MAX_IMAGE_EDGE) / float(maxi(w, h))
		img.resize(maxi(1, roundi(w * scale)), maxi(1, roundi(h * scale)), Image.INTERPOLATE_LANCZOS)
	var png_bytes := img.save_png_to_buffer()
	if png_bytes.is_empty():
		_append_system("[color=yellow](failed to encode clipboard image)[/color]\n")
		return
	_pending_image_b64 = Marshalls.raw_to_base64(png_bytes)
	_image_attached_label.text = "image attached (%dx%d) — will be sent with your next message" % [img.get_width(), img.get_height()]
	_image_attached_row.visible = true
	if _provider_info and _provider_info.is_local:
		_append_system("[color=yellow](note: local Ollama models rarely support image input — switch to Claude, OpenAI, or Gemini for reliable results)[/color]\n")

func _on_remove_attached_image() -> void:
	_clear_pending_image()

## Consumes (clears + hides) the pending image after it's been folded into
## an outgoing request body, so it isn't accidentally resent next turn.
func _clear_pending_image() -> void:
	_pending_image_b64 = ""
	_image_attached_row.visible = false

## Cross-platform clipboard image capture (duplicated from
## vg_sprite_editor.gd's _paste_image_from_system_clipboard() — kept as a
## separate copy here rather than a shared utility to avoid coupling two
## independent editor addons together).
func _paste_image_from_system_clipboard() -> Image:
	var tmp_path := OS.get_cache_dir().path_join("vg_ai_clipboard_paste.png")
	var os_name := OS.get_name()
	var ok := false
	if os_name == "Linux" or os_name == "FreeBSD":
		var output := []
		if OS.execute("which", ["xclip"], output) == 0:
			var exit_code := OS.execute("bash", ["-c", "xclip -selection clipboard -t image/png -o > " + tmp_path + " 2>/dev/null"])
			if exit_code == 0:
				ok = true
		elif OS.execute("which", ["wl-paste"], output) == 0:
			var exit_code := OS.execute("bash", ["-c", "wl-paste --type image/png > " + tmp_path + " 2>/dev/null"])
			if exit_code == 0:
				ok = true
	elif os_name == "macOS":
		var exit_code := OS.execute("osascript", [
			"-e", "try",
			"-e", 'set img to the clipboard as «class PNGf»',
			"-e", 'set f to open for access POSIX file "' + tmp_path + '" with write permission',
			"-e", "set eof of f to 0",
			"-e", "write img to f",
			"-e", "close access f",
			"-e", "end try"])
		if exit_code == 0 and FileAccess.file_exists(tmp_path):
			ok = true
	elif os_name == "Windows":
		var ps_cmd := "Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Windows.Forms; "
		ps_cmd += "$i = [System.Windows.Forms.Clipboard]::GetImage(); "
		ps_cmd += "if ($i) { $i.Save('" + tmp_path.replace("/", "\\") + "', [System.Drawing.Imaging.ImageFormat]::Png); $i.Dispose() }"
		var exit_code := OS.execute("powershell.exe", ["-NoProfile", "-Command", ps_cmd])
		if exit_code == 0:
			ok = true
	if not ok:
		return null
	if not FileAccess.file_exists(tmp_path):
		return null
	var img := Image.new()
	var err := img.load(tmp_path)
	if err != OK or img.is_empty():
		return null
	return img

# ---------------------------------------------------------------------------
# Chat-first build pipeline — plain chat should be enough for forms/projects
# ---------------------------------------------------------------------------

## Detect when the user is asking Narcea to scaffold UI or a project.
func _detect_build_intent(prompt: String) -> String:
	var low := prompt.to_lower().strip_edges()
	if low.is_empty():
		return ""
	const ProjectSynth = preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
	if ProjectSynth.prompt_is_hybrid_form_game(prompt):
		return "project"
	var project_triggers := [
		"mini-project", "mini project", "runnable project", "scaffold a project",
		"new project", "whole project", "full project", "vg-project-spec",
		"make a game", "build a game", "create a game",
	]
	for t in project_triggers:
		if low.find(t) >= 0:
			return "project"
	var code_triggers := [
		"vg-code-spec", "write the code", "implement the handler",
		"add the code", "code spec", "event handler for", "only the code",
	]
	for t in code_triggers:
		if low.find(t) >= 0:
			return "code"
	var form_triggers := [
		"make a form", "create a form", "build a form", "design a form",
		"make form", "new form", "add a form", "vg-form-spec",
		"command button", "commandbutton", "textbox", "text box",
		"add a button", "add a label", "with a button", "with a label",
		"click counter", "click me", "form with", "please make a form",
	]
	for t in form_triggers:
		if low.find(t) >= 0:
			return "form"
	if low.find("make ") >= 0 or low.find("build ") >= 0 or low.find("create ") >= 0:
		for n in ["form", "button", "label", "textbox", "dialog", "window", " ui"]:
			if low.find(n) >= 0:
				return "form"
	return ""


func _ensure_narcea_for_build(clear_history: bool = false) -> void:
	if _persona_id == "narcea" or not _personas.has("narcea"):
		return
	_persona_id = "narcea"
	_save_persona()
	_apply_persona_voice()
	if clear_history:
		_conversation_history.clear()
	if is_instance_valid(_persona_dropdown):
		for i in _persona_dropdown.item_count:
			if _persona_dropdown.get_item_metadata(i) == "narcea":
				_persona_dropdown.select(i)
				break
	_append_system("[color=#bb88ff]Switched to Narcea[/color] to build from your description.\n")


func _build_hardened_prompt(desc: String, mode: String) -> String:
	var prompt := ""
	match mode:
		"code":
			prompt = "Write or modify code per this description.\n\n"
			prompt += "Description: " + desc + "\n\n"
			prompt += "Reply with: (a) one short sentence of context, then (b) a fenced ```vg-code-spec``` JSON block. "
			prompt += "The .vg source MUST be a FLAT MODULE — no Class, no Inherits, no Dim for controls. "
			prompt += "Use this exact shape for any .vg file:\n"
			prompt += "  ' FormName.vg — VisualGasic module\n  Option Explicit\n\n  Sub Form_Load()\n  End Sub\n\n  Sub btnOK_Click()\n  End Sub\n"
			prompt += "Use res:// paths only. String concat is &, not +. Do not include any other fenced code blocks."
		"project":
			prompt = "Scaffold a small runnable project per this description.\n\n"
			prompt += "Description: " + desc + "\n\n"
			prompt += "Reply with: (a) one short sentence of context, then (b) a fenced ```vg-project-spec``` JSON block per the schema you already know. "
			prompt += "Set \"main_scene\" so the ▶ Run button knows what to launch. Pick \"auto_events\": true on any forms so the project runs on first try. "
			prompt += "Keep the project ≤ 6 files. Do not include any other fenced code blocks."
			const ProjectSynth = preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
			if ProjectSynth.prompt_is_hybrid_form_game(desc):
				prompt += ProjectSynth.hybrid_project_prompt_extra()
		_:
			prompt = "Design a runnable Form Designer form from this description.\n\n"
			prompt += "Description: " + desc + "\n\n"
			prompt += "Reply with: (a) one short sentence of context, then (b) a fenced ```vg-form-spec``` block using EXACTLY this JSON shape — no other top-level keys:\n"
			prompt += "```vg-form-spec\n"
			prompt += "{\"form_name\":\"FrmExample\",\"form_size\":[320,110],\"auto_events\":true,\"controls\":[\n"
			prompt += "  {\"type\":\"Label\",   \"name\":\"lblInput\",\"text\":\"Input:\",\"left\":8, \"top\":8, \"width\":60,\"height\":20},\n"
			prompt += "  {\"type\":\"LineEdit\",\"name\":\"txtInput\",\"left\":76,\"top\":5, \"width\":228,\"height\":24},\n"
			prompt += "  {\"type\":\"Button\", \"name\":\"btnOK\",  \"text\":\"OK\",  \"left\":76,\"top\":45,\"width\":80, \"height\":28},\n"
			prompt += "  {\"type\":\"Button\", \"name\":\"btnCancel\",\"text\":\"Cancel\",\"left\":164,\"top\":45,\"width\":80,\"height\":28}\n"
			prompt += "]}\n"
			prompt += "```\n"
			prompt += "═════ LAYOUT RULES (MANDATORY) ═════\n"
			prompt += "Standard sizes: Label height=20, LineEdit height=24 width≥140, Button height≥28 width≥80.\n"
			prompt += "Margins ≥16 px from edges. Row gap ≥8 px. NEVER place controls at (0,0) without margins.\n"
			prompt += "IMPORTANT: use GODOT type names only — LineEdit (not TextBox), Button (not CommandButton).\n"
			prompt += "If the description includes ANY behaviour (button click, counter, validation, etc.), you MUST ALSO emit a ```vg-code-spec``` block immediately after the form spec in the SAME reply. "
			prompt += "Do NOT leave event handlers as TODO stubs — write complete Sub bodies now. "
			prompt += "In vg-code-spec use path \"res://<form_name>.vg\" matching form_name. "
			prompt += "Include Option Explicit, Sub Form_Load(), and FULL Sub implementations for every event — NOT empty stubs. "
			prompt += "String concatenation is & (not +). Never use GDScript syntax."
	if mode == "" or mode == "form":
		prompt += _existing_form_designer_context()
	return prompt


func _existing_form_designer_context() -> String:
	var extra := ""
	if not Engine.is_editor_hint():
		return extra
	var base := EditorInterface.get_base_control()
	if base == null or not base.has_meta("visual_gasic_plugin_instance"):
		return extra
	var plug = base.get_meta("visual_gasic_plugin_instance")
	if plug == null or not is_instance_valid(plug) or not ("_form_designer" in plug):
		return extra
	var fd = plug._form_designer
	if fd == null or not is_instance_valid(fd):
		return extra
	var cur_name := ""
	if fd.has_method("get_form_name"):
		cur_name = str(fd.get_form_name())
	elif fd.has_method("get_form_path"):
		var fp: String = str(fd.get_form_path())
		if not fp.is_empty():
			cur_name = fp.get_file().get_basename()
	if not cur_name.is_empty():
		extra += "\n\nThe Form Designer already has a form open named \"%s\". " % cur_name
		extra += "Use \"%s\" as the form_name in your vg-form-spec (do NOT rename it). " % cur_name
		extra += "In the vg-code-spec, use path \"res://%s.vg\"." % cur_name
	if fd.has_method("get_control_count") and fd.get_control_count() > 0:
		var rows: Array[String] = []
		for i in fd.get_control_count():
			var info: Dictionary = fd.get_control_info(i)
			var r: Rect2 = info.get("rect", Rect2())
			rows.append("  %s (%s) top=%d height=%d → bottom=%d" % [
				info.get("name", "?"), info.get("type", "?"),
				int(r.position.y), int(r.size.y),
				int(r.position.y + r.size.y)])
		extra += "\n\nThe form already has %d control(s) — place ALL new controls BELOW them:\n%s\n" % [
			fd.get_control_count(), "\n".join(rows)]
	return extra


func _promote_form_to_main_scene(tscn_path: String) -> void:
	if tscn_path.is_empty() or not tscn_path.ends_with(".tscn"):
		return
	if not FileAccess.file_exists(tscn_path):
		return
	var cur := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if cur.is_empty() or cur.ends_with("Module1.tscn") or cur.ends_with("Module1.vg"):
		ProjectSettings.set_setting("application/run/main_scene", tscn_path)
		ProjectSettings.save()
		_append_system("[color=#88bbff]Set main scene to %s[/color]\n" % tscn_path.get_file())


func _form_spec_needs_code(spec: Dictionary) -> bool:
	for entry in spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		if ctype in ["Button", "CommandButton", "CheckBox", "LineEdit", "TextEdit",
				"OptionButton", "ItemList", "HSlider", "VSlider", "SpinBox", "Timer"]:
			return true
	return bool(spec.get("auto_events", false))


func _vg_source_has_empty_handlers(src: String, form_spec: Dictionary) -> bool:
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		if ctype not in ["Button", "CommandButton"]:
			continue
		var cname := str(entry.get("name", "")).strip_edges()
		if cname.is_empty():
			continue
		if not _sub_has_implementation(src, "%s_Click" % cname):
			return true
	return false


func _sub_has_implementation(src: String, sub_name: String) -> bool:
	var lower := src.to_lower()
	var needle := ("sub " + sub_name + "(").to_lower()
	var idx := lower.find(needle)
	if idx < 0:
		needle = ("sub " + sub_name + " (").to_lower()
		idx = lower.find(needle)
	if idx < 0:
		return false
	var after := src.substr(idx)
	var end_idx := after.to_lower().find("end sub")
	if end_idx < 0:
		return false
	var body := after.substr(0, end_idx)
	for line in body.split("\n"):
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("'") or s.begins_with("Sub ") or s.begins_with("sub "):
			continue
		return true
	return false


func _parse_counter_label(text: String) -> Dictionary:
	var colon_idx := text.rfind(":")
	if colon_idx >= 0:
		var before := text.substr(0, colon_idx + 1) + " "
		var tail := text.substr(colon_idx + 1).strip_edges()
		if tail.is_valid_int():
			return {"before": before, "after": "", "start": int(tail)}
	var re := RegEx.new()
	if re.compile("^(.*?)(\\d+)(.*)$") == OK:
		var m := re.search(text.strip_edges())
		if m:
			return {
				"before": m.get_string(1),
				"after": m.get_string(3),
				"start": int(m.get_string(2)),
			}
	var re_lead := RegEx.new()
	if re_lead.compile("^(\\d+)(\\s+.*)$") == OK:
		var m2 := re_lead.search(text.strip_edges())
		if m2:
			return {
				"before": "",
				"after": m2.get_string(2),
				"start": int(m2.get_string(1)),
			}
	return {"before": text, "after": "", "start": 0}


func _build_click_counter_vg(form_name: String, btn_name: String, lbl_name: String, lbl_initial: String) -> String:
	var parsed := _parse_counter_label(lbl_initial)
	var cap_expr: String
	if parsed.after.is_empty():
		cap_expr = "\"%s\" & clickCount" % parsed.before
	else:
		cap_expr = "\"%s\" & clickCount & \"%s\"" % [parsed.before, parsed.after]
	return ("' %s — click counter\nOption Explicit\n\nDim clickCount As Long\n\n" % form_name
		+ "Sub Form_Load()\n\tclickCount = %d\n\t%s.Caption = %s\nEnd Sub\n\n" % [parsed.start, lbl_name, cap_expr]
		+ "Sub %s_Click()\n\tclickCount = clickCount + 1\n\t%s.Caption = %s\nEnd Sub\n" % [btn_name, lbl_name, cap_expr])


func _try_synthesize_click_counter(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	var btn_name := ""
	var lbl_name := ""
	var lbl_initial := "Clicks: 0"
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		var cname := str(entry.get("name", "")).strip_edges()
		if cname.is_empty():
			continue
		if ctype in ["Button", "CommandButton"] and btn_name.is_empty():
			btn_name = cname
		if ctype == "Label":
			var prefer := ("count" in cname.to_lower()) or ("click" in cname.to_lower()) or ("lbl" in cname.to_lower())
			if lbl_name.is_empty() or prefer:
				lbl_name = cname
				lbl_initial = str(entry.get("text", entry.get("caption", lbl_initial)))
	if btn_name.is_empty() or lbl_name.is_empty():
		return false
	var low := user_prompt.to_lower()
	if low.find("click") < 0 and low.find("count") < 0 and low.find("times") < 0 and low.find("number") < 0:
		return false
	var src := _build_click_counter_vg(form_name, btn_name, lbl_name, lbl_initial)
	var wf := FileAccess.open(vg_path, FileAccess.WRITE)
	if wf == null:
		return false
	wf.store_string(src)
	wf.close()
	return true


func _try_synthesize_form_handlers(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	if _try_synthesize_menu_launch(form_name, form_spec, vg_path, user_prompt):
		return true
	if _try_synthesize_click_counter(form_name, form_spec, vg_path, user_prompt):
		return true
	if _try_synthesize_checkbox_toggle(form_name, form_spec, vg_path, user_prompt):
		return true
	if _try_synthesize_inc_dec(form_name, form_spec, vg_path, user_prompt):
		return true
	if _try_synthesize_textbox_validation(form_name, form_spec, vg_path, user_prompt):
		return true
	return false


func _try_synthesize_menu_launch(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	const ProjectSynth = preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
	if not ProjectSynth.menu_form_needs_synthesis(form_spec, FileAccess.get_file_as_string(vg_path) if FileAccess.file_exists(vg_path) else "", user_prompt):
		return false
	var low := user_prompt.to_lower()
	var game_scene := "res://TicTacToe.tscn"
	if low.find("tic tac") >= 0 or low.find("tictactoe") >= 0:
		game_scene = "res://TicTacToe.tscn"
	elif low.find("pong") >= 0:
		game_scene = "res://Pong.tscn"
	var src := ProjectSynth.synthesize_menu_form(form_name, form_spec, game_scene, user_prompt)
	return _write_vg_file(vg_path, src)


func _try_synthesize_checkbox_toggle(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	var chk_name := ""
	var lbl_name := ""
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		var cname := str(entry.get("name", "")).strip_edges()
		if ctype == "CheckBox" and chk_name.is_empty():
			chk_name = cname
		if ctype == "Label" and lbl_name.is_empty():
			lbl_name = cname
	if chk_name.is_empty():
		return false
	var low := user_prompt.to_lower()
	if low.find("check") < 0 and low.find("toggle") < 0:
		return false
	var lbl_line := ""
	if not lbl_name.is_empty():
		lbl_line = "\t%s.Caption = IIf(%s.Value, \"Checked\", \"Unchecked\")\n" % [lbl_name, chk_name]
	var src := ("' %s — checkbox toggle\nOption Explicit\n\nSub Form_Load()\n\t%s.Value = 0\n%sEnd Sub\n\nSub %s_Click()\n\t%s.Value = IIf(%s.Value, 0, 1)\n%sEnd Sub\n" % [
		form_name, chk_name, lbl_line, chk_name, chk_name, chk_name, lbl_line])
	return _write_vg_file(vg_path, src)


func _try_synthesize_inc_dec(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	var btns: Array[String] = []
	var lbl_name := ""
	var lbl_initial := "Value: 0"
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		var cname := str(entry.get("name", "")).strip_edges()
		if ctype in ["Button", "CommandButton"]:
			btns.append(cname)
		if ctype == "Label":
			lbl_name = cname
			lbl_initial = str(entry.get("text", entry.get("caption", lbl_initial)))
	if btns.size() < 2 or lbl_name.is_empty():
		return false
	var low := user_prompt.to_lower()
	if low.find("increment") < 0 and low.find("decrement") < 0 and low.find("+") < 0 and low.find("minus") < 0:
		return false
	var parsed := _parse_counter_label(lbl_initial)
	var cap_expr: String
	if parsed.after.is_empty():
		cap_expr = "\"%s\" & valueCount" % parsed.before
	else:
		cap_expr = "\"%s\" & valueCount & \"%s\"" % [parsed.before, parsed.after]
	var inc := btns[0]
	var dec := btns[1]
	var src := ("' %s — increment/decrement\nOption Explicit\n\nDim valueCount As Long\n\nSub Form_Load()\n\tvalueCount = %d\n\t%s.Caption = %s\nEnd Sub\n\nSub %s_Click()\n\tvalueCount = valueCount + 1\n\t%s.Caption = %s\nEnd Sub\n\nSub %s_Click()\n\tvalueCount = valueCount - 1\n\t%s.Caption = %s\nEnd Sub\n" % [
		form_name, parsed.start, lbl_name, cap_expr, inc, lbl_name, cap_expr, dec, lbl_name, cap_expr])
	return _write_vg_file(vg_path, src)


func _try_synthesize_textbox_validation(form_name: String, form_spec: Dictionary, vg_path: String, user_prompt: String) -> bool:
	var txt_name := ""
	var btn_name := ""
	var lbl_name := ""
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		var cname := str(entry.get("name", "")).strip_edges()
		if ctype in ["LineEdit", "TextEdit", "TextBox"] and txt_name.is_empty():
			txt_name = cname
		if ctype in ["Button", "CommandButton"] and btn_name.is_empty():
			btn_name = cname
		if ctype == "Label" and lbl_name.is_empty():
			lbl_name = cname
	if txt_name.is_empty() or btn_name.is_empty() or lbl_name.is_empty():
		return false
	var low := user_prompt.to_lower()
	if low.find("valid") < 0 and low.find("empty") < 0 and low.find("required") < 0:
		return false
	var src := ("' %s — textbox validation\nOption Explicit\n\nSub %s_Click()\n\tIf Trim(%s.Text) = \"\" Then\n\t\t%s.Caption = \"Please enter a value.\"\n\tElse\n\t\t%s.Caption = \"OK: \" & %s.Text\n\tEnd If\nEnd Sub\n" % [
		form_name, btn_name, txt_name, lbl_name, lbl_name, txt_name])
	return _write_vg_file(vg_path, src)


func _write_vg_file(vg_path: String, src: String) -> bool:
	var wf := FileAccess.open(vg_path, FileAccess.WRITE)
	if wf == null:
		return false
	wf.store_string(src)
	wf.close()
	return true


func _on_advanced_toolbar_toggled(on: bool) -> void:
	if is_instance_valid(_toolbar3_advanced):
		_toolbar3_advanced.visible = on
	if is_instance_valid(_advanced_toggle_btn):
		_advanced_toggle_btn.text = "Advanced ▴" if on else "Advanced ▾"
	_refresh_build_form_btn()


func _advanced_actions_visible() -> bool:
	return is_instance_valid(_toolbar3_advanced) and _toolbar3_advanced.visible


## After layout/code write, ensure button handlers are implemented.
## Returns a summary suffix (empty when handlers are already complete).
func _finalize_form_handlers(form_name: String, form_spec: Dictionary, vg_path: String) -> String:
	if not _form_spec_needs_code(form_spec):
		return ""
	var src := FileAccess.get_file_as_string(vg_path) if FileAccess.file_exists(vg_path) else ""
	if not _vg_source_has_empty_handlers(src, form_spec):
		return ""
	if _try_synthesize_form_handlers(form_name, form_spec, vg_path, _last_user_prompt):
		src = FileAccess.get_file_as_string(vg_path)
		if not _vg_source_has_empty_handlers(src, form_spec):
			_reload_embedded_vg(vg_path)
			return "; handler code synthesized — click ▶ Run to test"
	call_deferred("_send_code_followup", form_name, form_spec)
	return "; generating handler code…"


func _reload_embedded_vg(vg_path: String) -> void:
	if not Engine.is_editor_hint() or vg_path.is_empty():
		return
	var plugin: Object = null
	var base := EditorInterface.get_base_control()
	if base and base.has_meta("visual_gasic_plugin_instance"):
		plugin = base.get_meta("visual_gasic_plugin_instance")
	if plugin == null or not is_instance_valid(plugin) or not ("_embedded_code_editor" in plugin):
		return
	var ece = plugin._embedded_code_editor
	if is_instance_valid(ece) and ece.has_method("load_file"):
		ece.load_file(vg_path)


func _send_code_followup(form_name: String, form_spec: Dictionary) -> void:
	if _code_followup_pending or _is_generating:
		return
	_code_followup_pending = true
	var handlers: Array[String] = []
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ctype: String = str(entry.get("type", ""))
		var cname := str(entry.get("name", "")).strip_edges()
		if cname.is_empty():
			continue
		if ctype in ["Button", "CommandButton"]:
			handlers.append("%s_Click" % cname)
	if handlers.is_empty() and bool(form_spec.get("auto_events", false)):
		handlers.append("Form_Load")
	var api_prompt := ("The vg-form-spec for \"%s\" was applied and saved. " % form_name)
	api_prompt += "Reply with ONLY a fenced ```vg-code-spec``` JSON block.\n"
	api_prompt += "Path MUST be \"res://%s.vg\". Include Option Explicit and FULL Sub implementations (NOT empty stubs) for: %s.\n" % [
		form_name, ", ".join(handlers)]
	if not _last_user_prompt.is_empty():
		api_prompt += "Original user request: " + _last_user_prompt + "\n"
	api_prompt += "Control names must match the form spec exactly. String concat is &."
	_append_system("[color=#88bbff]Form layout saved — generating handler code…[/color]\n")
	call_deferred("_send_internal_build_followup", api_prompt)


func _send_internal_build_followup(api_prompt: String) -> void:
	if _is_generating:
		return
	if not _ollama_available:
		if _provider_info and not _provider_info.is_local:
			pass
		else:
			_code_followup_pending = false
			return
	_conversation_history.append({"role": "user", "content": api_prompt})
	_transcript_append({"type": "build_followup", "prompt_len": api_prompt.length()})
	_api_prompt_override = api_prompt
	if _provider_info and not _provider_info.is_local:
		_send_cloud_query(_maybe_prepend_diff(api_prompt))
	else:
		_send_query_internal(api_prompt)

# ---------------------------------------------------------------------------
# Sending queries
# ---------------------------------------------------------------------------
func _on_send() -> void:
	var display_prompt := _input.text.strip_edges()
	if display_prompt.is_empty():
		return
	# Reset multi-turn agent hop counter on user-initiated sends.  The
	# agent loop sets _agent_continuation=true before re-entering so we
	# preserve the count for that follow-up turn only.
	if _agent_continuation:
		_agent_continuation = false
		# Phase 6d: visual hop marker so users can follow the agent loop.
		_output.append_text("\n[color=#4477cc][b]── Agent hop %d ──[/b][/color]\n" % _agent_hops)
		# Phase 6e: open transcript on first continuation, write hop entry.
		_transcript_open()
		_transcript_append({"type": "hop_start", "hop": _agent_hops, "prompt_len": display_prompt.length()})
		_transcript_append({"type": "user_prompt", "hop": _agent_hops, "prompt": display_prompt})
	else:
		_agent_hops = 0
		_agent_total_tokens = 0
		_agent_start_time = Time.get_ticks_msec() / 1000.0
		_agent_triggered_run = false
		_agent_run_output_lines.clear()
		_agent_abort_requested = false
		_build_form_ran_this_turn = false
		_code_followup_pending = false
		_hide_abort_agent_btn()
		_transcript_close("user_new_turn")  # Phase 6e: close any open transcript.
		_transcript_open()
		_transcript_append({"type": "user_prompt", "hop": _agent_hops, "prompt": display_prompt})
		# Chat-first: detect form/project/code intent and route to Narcea.
		if not _last_send_was_desc_mode:
			_last_build_intent = _detect_build_intent(display_prompt)
			_last_user_prompt = display_prompt
			if not _last_build_intent.is_empty():
				_ensure_narcea_for_build(false)
				_api_prompt_override = _build_hardened_prompt(display_prompt, _last_build_intent)
	_send_query(display_prompt)

func _send_query(display_prompt: String) -> void:
	var api_prompt := _api_prompt_override if not _api_prompt_override.is_empty() else display_prompt
	_api_prompt_override = ""
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
	# Push pinned files to Narcea before context build (#8).
	if _narcea_provider != null and _narcea_provider.has_method("set_pinned_files"):
		_narcea_provider.set_pinned_files(_pinned_files)
		_narcea_ctx_cache = ""
	# Diff-aware follow-ups (#11): if the user is referring to the prior
	# edit, silently prepend a short diff summary so Narcea has context
	# for "undo that", "also do X", "why did you change Y", "now ...".
	var augmented := _maybe_prepend_diff(api_prompt)

	# Cloud providers — skip warmup and health check, send directly
	if _provider_info and not _provider_info.is_local:
		_history.append(display_prompt)
		_history_idx = _history.size()
		_input.text = ""
		_append_user(display_prompt)
		_send_cloud_query(augmented)
		return

	# Send directly — the request itself surfaces any connectivity issue.
	_history.append(display_prompt)
	_history_idx = _history.size()
	_input.text = ""
	_append_user(display_prompt)
	_send_query_internal(augmented)


## Detect follow-up trigger words and prepend the last apply's diff
## summary to the prompt.  Display copy stays untouched.
func _maybe_prepend_diff(prompt: String) -> String:
	if _last_apply_diff_summary.is_empty():
		return prompt
	var low := prompt.to_lower()
	var triggers := ["undo", "revert", "also", "now ", "why did you", "why are you",
		"that change", "that edit", "previous edit", "what you just"]
	var hit := false
	for t in triggers:
		if low.find(t) != -1:
			hit = true
			break
	if not hit:
		return prompt
	return ("[Context: your most recent edit changed %s.  The user's next "
		+ "message references that change.]\n\n%s") % [
			_last_apply_diff_summary, prompt]

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
			"num_ctx": 8192,     # Enough context for the full system prompt + history
		}
	}
	if not _pending_image_b64.is_empty():
		body["images"] = [_pending_image_b64]
		_clear_pending_image()
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
	_stream_tool_watermark = 0
	_stream_vgtool_suppress = false
	_stream_line_buf = ""
	_stream_line_displayed = 0

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
	if text.begins_with("Tool results from your previous request:"):
		# Agent-loop internal continuation message (fed back to the model
		# after a hop, see the callers that build "Tool results from your
		# previous request:..." strings). The full tool payload (file
		# contents, grep hits, directory listings) was already rendered
		# once under "\u2192 Tool actions:" earlier in this same hop --
		# re-echoing the entire raw text/JSON blob a second time as a
		# fake "You:" bubble is pure duplication and was the dominant
		# source of chat-log noise during multi-hop investigations. Show
		# a short marker instead; the full text is still sent to the
		# model unchanged (only the visible rendering is condensed).
		var result_count: int = text.split("\n- ").size() - 1
		_output.append_text("[color=#888888](continuing agent loop with %d tool result(s) shown above)[/color]\n" % maxi(result_count, 1))
		return
	_output.append_text("[color=#cccccc]%s[/color]\n" % _escape_bbcode(text))

func _append_ai(text: String) -> void:
	_output.append_text("\n[color=#44bb88][b]AI:[/b][/color]\n")
	# Convert markdown code blocks to BBCode
	var formatted := _format_code_blocks(text)
	_output.append_text(formatted + "\n")

func _append_system(text: String) -> void:
	_output.append_text("[color=gray]%s[/color]" % text)

func _escape_bbcode(text: String) -> String:
	# Single native C++ replace — far faster than a GDScript character loop.
	# In Godot 4 RichTextLabel BBCode, only "[" is special (starts a tag);
	# "]" in text content is treated as a literal character by the parser,
	# so it needs no escaping.
	return text.replace("[", "[lb]")

func _format_code_blocks(text: String) -> String:
	# Convert ```vb ... ``` or ```bas ... ``` blocks to colored BBCode.
	# ```vg-tool blocks are collapsed to a compact indicator — the raw JSON
	# is never shown to the user.
	var result := ""
	var lines := text.split("\n")
	var in_code := false
	var in_vgtool := false

	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("```") and not in_code:
			in_code = true
			if stripped == "```vg-tool":
				in_vgtool = true
				# Don't emit an opening divider for tool blocks
			else:
				result += "[color=#1a1a2e]━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n"
			continue
		elif stripped.begins_with("```") and in_code:
			in_code = false
			if in_vgtool:
				in_vgtool = false
				result += "[color=#888888]⚙ (tool executed)[/color]\n"
			else:
				result += "[color=#1a1a2e]━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n"
			continue

		if in_vgtool:
			continue  # suppress vg-tool JSON from display
		elif in_code:
			result += "[color=#e0c080]%s[/color]\n" % _escape_bbcode(line)
		else:
			# Escape BBCode-significant chars first so user text like arr[0] is safe.
			# The markdown patterns (**, backtick) contain no BBCode-special chars,
			# so detection still works on the already-escaped string.
			var formatted_line := _escape_bbcode(line)
			# Bold markdown **text** → BBCode [b]text[/b]
			while formatted_line.find("**") >= 0:
				var start := formatted_line.find("**")
				var end := formatted_line.find("**", start + 2)
				if end < 0:
					break
				var before := formatted_line.left(start)
				var bold_text := formatted_line.substr(start + 2, end - start - 2)
				var after := formatted_line.substr(end + 2)
				formatted_line = before + "[b]" + bold_text + "[/b]" + after
			# Inline code `text` → colored (content already escaped above)
			while formatted_line.find("`") >= 0:
				var start := formatted_line.find("`")
				var end := formatted_line.find("`", start + 1)
				if end < 0:
					break
				var before := formatted_line.left(start)
				var code_text := formatted_line.substr(start + 1, end - start - 1)
				var after := formatted_line.substr(end + 1)
				formatted_line = before + "[color=#e0c080]" + code_text + "[/color]" + after
			result += "[color=#dddddd]%s[/color]\n" % formatted_line

	return result

# ---------------------------------------------------------------------------
# Quick actions
# ---------------------------------------------------------------------------
func _on_explain_error() -> void:
	if _last_error_context.is_empty() and _run_error_lines.is_empty():
		_append_system("[color=yellow]No error to explain. Run your program and trigger an error first.[/color]\n")
		return
	_show_persona_error_intro()
	var prompt := "Explain this VisualGasic runtime error and suggest a fix:\n\n"
	if not _last_error_context.is_empty():
		prompt += "File: %s\n" % _last_error_context.get("file", "unknown")
		prompt += "Line: %s\n" % str(_last_error_context.get("line", "?"))
		prompt += "Error: %s\n" % _last_error_context.get("message", "unknown error")
		if _last_error_context.has("code_context"):
			prompt += "\nCode around the error:\n```vb\n%s\n```\n" % _last_error_context["code_context"]
		if _last_error_context.has("variables"):
			prompt += "\nVariable values at the time of error:\n"
			for k in _last_error_context["variables"]:
				prompt += "  %s = %s\n" % [k, str(_last_error_context["variables"][k])]
	elif not _run_error_lines.is_empty():
		# Manual ▶ Run fallback — feed the captured stderr verbatim so
		# Narcea can spot the file:line in the traceback herself.
		prompt += "Run output (stderr / SCRIPT ERROR lines from the last run):\n```\n"
		prompt += "\n".join(_run_error_lines)
		prompt += "\n```\n\nDiagnose the cause and emit a vg-patch-spec (or vg-code-spec) that fixes the file referenced above."
	_send_query(prompt)

func _on_explain_code() -> void:
	var code := _get_editor_selected_code()
	if code.strip_edges().is_empty():
		_append_system("[color=yellow]Nothing to explain — open a .vg file in the editor, then place the caret in a Sub or select code first.[/color]\n")
		return
	# If the user has no selection we got the Sub body around the caret —
	# tell Narcea so she can mention which Sub she's explaining.
	var prompt := ("Explain this VisualGasic code in 2-3 short paragraphs, plain English, "
		+ "for someone learning to program. End with one sentence about what they might "
		+ "want to try next.\n\n```vb\n%s\n```") % code
	_send_query(prompt)

func _on_translate() -> void:
	var code := _get_editor_selected_code()
	if code.strip_edges().is_empty():
		_append_system("[color=yellow]Select GDScript code in the editor first.[/color]\n")
		return
	var prompt := "Translate this GDScript code to VisualGasic (VB6 syntax):\n\n```gdscript\n%s\n```\n\nProvide only the VisualGasic translation." % code
	_send_query(prompt)


# ---------------------------------------------------------------------------
# Phase 7 quick-action handlers
# ---------------------------------------------------------------------------

## Look up `line` in the Narcea decoder dictionary.  Returns "" if no
## entry matches, otherwise a one-sentence plain-English hint.
func _decode_run_error(line: String) -> String:
	if _narcea_provider == null:
		var script := load("res://addons/visual_gasic/vg_ai_narcea.gd")
		if script == null:
			return ""
		_narcea_provider = script.new()
	if not _narcea_provider.has_method("decode_error"):
		return ""
	return _narcea_provider.decode_error(line)


## Capture pre-edit snapshots of every path in `paths` so the user can
## roll back with the Undo button.  Stores at most _UNDO_DEPTH entries.
func _undo_capture(label: String, paths: Array) -> void:
	var snap := {"label": label, "ts": Time.get_ticks_msec(), "files": []}
	for p in paths:
		var sp := str(p)
		var old := ""
		if FileAccess.file_exists(sp):
			var f := FileAccess.open(sp, FileAccess.READ)
			if f != null:
				old = f.get_as_text()
				f.close()
		snap["files"].append({"path": sp, "old": old})
	_undo_stack.append(snap)
	if _undo_stack.size() > _UNDO_DEPTH:
		_undo_stack.pop_front()
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = false
		_undo_btn.tooltip_text = "Undo: %s (%d file(s))" % [label, snap["files"].size()]


## Compute a 1-line summary of the change for diff-aware follow-ups.
func _summarise_diff(written: Array, snap: Dictionary) -> String:
	if snap.is_empty():
		return ""
	var parts: Array[String] = []
	var by_path := {}
	for fe in snap.get("files", []):
		by_path[str(fe.get("path", ""))] = str(fe.get("old", ""))
	for p in written:
		var sp := str(p)
		var old: String = by_path.get(sp, "")
		var new_text := ""
		if FileAccess.file_exists(sp):
			var f := FileAccess.open(sp, FileAccess.READ)
			if f != null:
				new_text = f.get_as_text()
				f.close()
		var old_lines := old.split("\n").size() if not old.is_empty() else 0
		var new_lines := new_text.split("\n").size() if not new_text.is_empty() else 0
		var delta := new_lines - old_lines
		var sign := "+" if delta >= 0 else ""
		parts.append("%s (%s%d lines)" % [sp.get_file(), sign, delta])
	return ", ".join(parts)


func _on_undo_last_edit() -> void:
	if _undo_stack.is_empty():
		_append_system("[color=yellow]Nothing to undo.[/color]\n")
		return
	_ensure_agent_helpers()
	if _safe_writer == null:
		_append_system("[color=#ff8888]Safe-writer unavailable — cannot undo.[/color]\n")
		return
	_safe_writer.set_root("res://")
	var snap: Dictionary = _undo_stack.pop_back()
	var restored: Array = []
	var failed: Array = []
	for fe in snap.get("files", []):
		var p: String = str(fe.get("path", ""))
		var old: String = str(fe.get("old", ""))
		if p.is_empty():
			continue
		# Empty `old` means the file didn't exist before the edit — delete it.
		if old.is_empty() and FileAccess.file_exists(p):
			var abs := ProjectSettings.globalize_path(p)
			if DirAccess.remove_absolute(abs) == OK:
				restored.append(p + " (deleted)")
			else:
				failed.append(p)
			continue
		var res: Array = _safe_writer.write(p, old)
		if res[0]:
			restored.append(p)
		else:
			failed.append("%s — %s" % [p, str(res[1])])
	_append_system("[color=#aaffaa]\u21a9 Restored '%s' — %d file(s).[/color]\n" % [
		str(snap.get("label", "?")), restored.size()])
	for r in restored:
		_append_system("  [color=#aaffaa]\u21bb %s[/color]\n" % r)
	for fl in failed:
		_append_system("  [color=#ff8888]\u2716 %s[/color]\n" % fl)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	# Reload the first .vg in editor so the user sees the rollback.
	var reload_shim := {"files": []}
	for fe in snap.get("files", []):
		reload_shim["files"].append({"path": str(fe.get("path", ""))})
	_reload_first_vg_in_editor(reload_shim)
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = _undo_stack.is_empty()
		if _undo_stack.is_empty():
			_undo_btn.tooltip_text = "Nothing to undo."


## Pin the currently-open .vg file (or whatever the editor has focused)
## so its full contents are always injected into Narcea's context.  Click
## again with the same file to unpin.
func _on_pin_file() -> void:
	var path := ""
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			var plugin = base.get_meta("visual_gasic_plugin_instance")
			if plugin and is_instance_valid(plugin) and "_embedded_code_editor" in plugin:
				var ece = plugin._embedded_code_editor
				if ece != null and is_instance_valid(ece):
					for prop in ["current_file", "_current_path", "current_path"]:
						if prop in ece:
							var v = ece.get(prop)
							if typeof(v) == TYPE_STRING and not v.is_empty():
								path = v
								break
	if path.is_empty():
		_append_system("[color=yellow]Open a file in the editor first, then click \ud83d\udccc Pin.[/color]\n")
		return
	# Toggle.
	var idx := -1
	for i in _pinned_files.size():
		if _pinned_files[i] == path:
			idx = i
			break
	if idx >= 0:
		_pinned_files.remove_at(idx)
		_append_system("[color=#cccccc]Unpinned %s.[/color]\n" % path)
	else:
		_pinned_files.append(path)
		_append_system("[color=#88ccff]\ud83d\udccc Pinned %s \u2014 Narcea will always see its contents.[/color]\n" % path)
	# Bust the context cache so the next prompt rebuilds with the new pins.
	_narcea_ctx_cache = ""
	if is_instance_valid(_pin_btn):
		var n: int = _pinned_files.size()
		_pin_btn.tooltip_text = "Pinned: %d file(s). Click to toggle the current file." % n


func _on_summarize_errors() -> void:
	if _run_error_lines.is_empty():
		_append_system("[color=yellow]No errors captured yet.[/color]\n")
		return
	var joined: String = "\n".join(_run_error_lines)
	var prompt := ("The last run produced %d error/warning lines.  Cluster repeated "
		+ "messages, identify the most likely root cause (one sentence), and propose "
		+ "the next concrete fix (one sentence).  Do NOT dump the raw log back at me.\n\n"
		+ "```\n%s\n```") % [_run_error_lines.size(), joined]
	_send_query(prompt)


## Write a vg-test-spec to disk, then immediately run it through the
## run-session so the user sees pass/fail in the same panel.
func _on_make_test() -> void:
	_ensure_agent_helpers()
	if _test_spec == null or _safe_writer == null:
		_append_system("[color=#ff8888]Test-spec helpers unavailable.[/color]\n")
		return
	var spec: Dictionary = _test_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No vg-test-spec block in the latest reply.[/color]\n")
		return
	_safe_writer.set_root("res://")
	var paths: Array = []
	for t in spec.get("tests", []):
		paths.append(str(t.get("path", "")))
	_undo_capture("Make test", paths)
	var result: Dictionary = _test_spec.apply(spec, _safe_writer, false)
	_last_apply_result = result
	_last_apply_kind = "Test"
	_print_apply_result("Test", result)
	# Run the first test through the existing run-session.
	if not result.get("written", []).is_empty():
		var first: String = str(result["written"][0])
		_last_run_scene = first
		if is_instance_valid(_run_btn):
			_run_btn.disabled = false
		call_deferred("_on_run")


## Write the latest vg-wnodes-spec block to disk as a `.wnodes` graph.
## The user can then open it in the Working Nodes editor.
func _on_make_wnodes() -> void:
	_ensure_agent_helpers()
	if _wnodes_spec == null or _safe_writer == null:
		_append_system("[color=#ff8888]vg-wnodes-spec helpers unavailable.[/color]\n")
		return
	var spec: Dictionary = _wnodes_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_append_system("[color=#ff8888]No vg-wnodes-spec block in the latest reply.[/color]\n")
		return
	_safe_writer.set_root("res://")
	var target_path := str(spec.get("path", ""))
	_undo_capture("Make WN graph", [target_path] if not target_path.is_empty() else [])
	var result: Dictionary = _wnodes_spec.apply(spec, _safe_writer, false)
	_last_apply_result = result
	_last_apply_kind = "WN"
	_print_apply_result("Working Nodes", result)
	# Auto-open the new graph in the Working Nodes editor if a path was written.
	var written: Array = result.get("written", [])
	if not written.is_empty():
		var first := str(written[0])
		_append_system("[color=#88ddff]Open in Working Nodes:[/color] %s\n" % first)
		# Surface via the plugin's existing open-graph hook if available.
		var root := get_tree().get_root() if is_inside_tree() else null
		if root and root.has_method("emit_signal"):
			# Best-effort: a global signal name the WN plugin can listen for.
			Engine.set_meta("vg_open_wnodes_request", first)


## When the most recent patch had anchor-not-found failures, give the
## user a one-click way to feed them back to Narcea for a corrected spec.
func _on_retry_patch() -> void:
	if _last_apply_result.is_empty():
		_append_system("[color=yellow]No patch to retry.[/color]\n")
		return
	var failed: Array = []
	for entry in _last_apply_result.get("skipped", []):
		var reason := str(entry.get("reason", ""))
		if reason.find("anchor not found") != -1 or reason.find("`find` not found") != -1:
			failed.append("  %s: %s" % [str(entry.get("path", "?")), reason])
	if failed.is_empty():
		_append_system("[color=yellow]No anchor failures to retry.[/color]\n")
		return
	var prompt := ("Your previous vg-patch-spec had anchors that didn't match the live "
		+ "file contents.  The following edits failed:\n\n%s\n\nEmit a corrected "
		+ "vg-patch-spec that uses anchors / `find` strings that DO appear verbatim "
		+ "in the file.  Use the 'Open file CONTENTS' block in the system prompt as "
		+ "your source of truth.") % "\n".join(failed)
	_send_query(prompt)


# ---------------------------------------------------------------------------
func _on_model_selected(idx: int) -> void:
	_current_model = _model_dropdown.get_item_text(idx)
	_append_system("Model changed to [color=cyan]%s[/color]\n" % _current_model)

func _on_clear() -> void:
	_transcript_close("cleared")
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
	# Embedded subwindow quirk: popup_centered() obeys min_size but Godot
	# re-layouts to host on the next frame, leaving the dialog stretched
	# nearly full-height. Force a fixed size + recenter via deferred call.
	var sz := Vector2i(640, 480)
	_model_picker.popup_centered(sz)
	_model_picker.size = sz
	call_deferred("_force_model_picker_size", _model_picker, sz)

func _force_window_size(dlg: Window, sz: Vector2i) -> void:
	if not is_instance_valid(dlg):
		return
	dlg.size = sz
	var base := EditorInterface.get_base_control() if Engine.is_editor_hint() else null
	var host_size := Vector2i(base.size) if base != null else Vector2i(get_viewport().get_visible_rect().size)
	dlg.position = (host_size - sz) / 2


func _force_model_picker_size(dlg: Window, sz: Vector2i) -> void:
	_force_window_size(dlg, sz)

# Force readable colors on an OptionButton's PopupMenu. The default editor
# theme renders dropdown items as nearly-black-on-black inside the dark VG
# bottom panel. Mirrors vg_2d_editor.gd `_style_popup_dark`: applies both a
# full Theme resource AND local overrides, plus a transparent flag to kill
# the native OS chrome, plus a forced theme-cache refresh notification.
#
# Critical Godot 4 quirk: the editor re-applies its own theme to popups
# right before they open (NOTIFICATION_THEME_CHANGED fires after our setup
# is finished), which silently restores the dark-on-dark `font_color`.
# To beat this we hook `about_to_popup` and re-apply the styling every
# time the popup opens. Without this, only `font_hover_color` survives —
# you see white text only on the hovered item, blank on every other row.
func _style_dropdown_popup_dark(option_btn: OptionButton) -> void:
	if not is_instance_valid(option_btn):
		return
	var popup := option_btn.get_popup()
	if popup == null:
		return
	_apply_dark_popup_styling(popup)
	# Re-apply right before each show — the editor theme stomps font_color
	# between our setup and the popup's first paint.
	if popup.has_meta("_vg_popup_styled"):
		return
	popup.set_meta("_vg_popup_styled", true)
	popup.about_to_popup.connect(_on_dropdown_popup_about_to_show.bind(popup))
	popup.visibility_changed.connect(func() -> void:
		if is_instance_valid(popup) and popup.visible:
			_apply_dark_popup_styling(popup)
			call_deferred("_apply_dark_popup_styling", popup)
	)

func _on_dropdown_popup_about_to_show(popup: PopupMenu) -> void:
	if is_instance_valid(popup):
		_apply_dark_popup_styling(popup)


## TextEdit / CodeEdit / LineEdit right-click menus inherit the editor theme
## (white-on-white) unless re-styled on every open — same fix as dropdowns.
func _style_context_menu(control: Control) -> void:
	if not is_instance_valid(control) or not control.has_method("get_menu"):
		return
	var popup: PopupMenu = control.call("get_menu")
	if popup == null:
		return
	_apply_dark_popup_styling(popup)
	if popup.has_meta("_vg_ctx_menu_styled"):
		return
	popup.set_meta("_vg_ctx_menu_styled", true)
	popup.about_to_popup.connect(func() -> void:
		_apply_dark_popup_styling(popup)
		# Editor theme re-applies between about_to_popup and first paint.
		call_deferred("_apply_dark_popup_styling", popup)
	)
	control.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				call_deferred("_apply_dark_popup_styling", popup)
	)

func _apply_dark_popup_styling(popup: PopupMenu) -> void:
	# Build the shared StyleBoxFlat / Theme objects once; reuse on every open.
	if _popup_theme == null:
		_popup_panel_style = StyleBoxFlat.new()
		_popup_panel_style.bg_color = Color(0.94, 0.94, 0.96)
		_popup_panel_style.set_border_width_all(1)
		_popup_panel_style.border_color = Color(0.55, 0.55, 0.62)
		_popup_panel_style.set_corner_radius_all(4)
		_popup_panel_style.set_content_margin_all(4)

		_popup_hover_style = StyleBoxFlat.new()
		_popup_hover_style.bg_color = Color(0.30, 0.50, 0.85)
		_popup_hover_style.set_corner_radius_all(3)

		_popup_sep_style = StyleBoxFlat.new()
		_popup_sep_style.bg_color = Color(0.70, 0.70, 0.75)
		_popup_sep_style.set_content_margin_all(0)
		_popup_sep_style.content_margin_top = 1
		_popup_sep_style.content_margin_bottom = 1

		_popup_theme = Theme.new()
		for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
			_popup_theme.set_stylebox("panel", type_name, _popup_panel_style)
		_popup_theme.set_stylebox("hover", "PopupMenu", _popup_hover_style)
		_popup_theme.set_stylebox("separator", "PopupMenu", _popup_sep_style)
		_popup_theme.set_stylebox("labeled_separator_left", "PopupMenu", _popup_sep_style)
		_popup_theme.set_stylebox("labeled_separator_right", "PopupMenu", _popup_sep_style)
		_popup_theme.set_color("font_color", "PopupMenu", Color.BLACK)
		_popup_theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
		_popup_theme.set_color("font_disabled_color", "PopupMenu", Color(0.55, 0.55, 0.55))
		_popup_theme.set_color("font_separator_color", "PopupMenu", Color(0.4, 0.4, 0.4))
		_popup_theme.set_color("font_accelerator_color", "PopupMenu", Color(0.25, 0.35, 0.6))
		_popup_theme.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)

	popup.theme = _popup_theme
	popup.add_theme_stylebox_override("panel", _popup_panel_style)
	popup.add_theme_stylebox_override("hover", _popup_hover_style)
	popup.add_theme_stylebox_override("separator", _popup_sep_style)
	popup.add_theme_stylebox_override("labeled_separator_left", _popup_sep_style)
	popup.add_theme_stylebox_override("labeled_separator_right", _popup_sep_style)
	popup.add_theme_color_override("font_color", Color.BLACK)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	popup.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	popup.add_theme_color_override("font_accelerator_color", Color(0.25, 0.35, 0.6))
	popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	popup.add_theme_constant_override("outline_size", 0)

	# Force a known-good font onto the popup. The editor theme can hand
	# OptionButton popups a font whose ASCII glyphs render with broken
	# alpha while the system color-emoji fallback renders fine — symptom
	# is "icons/emoji visible, text invisible". Borrow the font from the
	# OptionButton itself (which displays correctly) or fall back to the
	# editor base control's font.
	var good_font: Font = null
	var owner_btn := popup.get_parent() as OptionButton
	if owner_btn != null:
		good_font = owner_btn.get_theme_font("font")
	if good_font == null and Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base != null:
			good_font = base.get_theme_font("font")
	if good_font != null:
		popup.add_theme_font_override("font", good_font)
		var fs := 0
		if owner_btn != null:
			fs = owner_btn.get_theme_font_size("font_size")
		if fs > 0:
			popup.add_theme_font_size_override("font_size", fs)

	# PopupMenu is a Window, not a Control — it has no `modulate` /
	# `self_modulate` properties. Setting them throws a runtime error
	# and aborts the rest of this function. Don't add them back.
	popup.transparent = false
	popup.notification(Window.NOTIFICATION_THEME_CHANGED)

	# Defensive: keep focus/pressed/selected rows readable on the light popup panel.
	for color_name in ["font_focus_color", "font_pressed_color", "font_selected_color"]:
		popup.add_theme_color_override(color_name, Color.BLACK)
	for child in popup.get_children(true):
		if child is Control:
			child.add_theme_stylebox_override("panel", _popup_panel_style)

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
	# Mirror _on_send()'s non-continuation branch: a fresh externally-driven
	# turn must start with a clean agent-hop/budget counter, same as a
	# user-initiated send. Without this, hop counts leak across separate
	# ask() calls (e.g. successive scripted/automation turns), eventually
	# hitting the hop cap immediately on turns that never actually looped.
	if not _agent_continuation:
		_agent_hops = 0
		_agent_total_tokens = 0
		_agent_start_time = Time.get_ticks_msec() / 1000.0
		_agent_triggered_run = false
		_agent_run_output_lines.clear()
		_agent_abort_requested = false
		_build_form_ran_this_turn = false
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

func _on_refresh_models() -> void:
	"""Refresh the model list from the provider's live API."""
	if not AIProviders or _provider_id.is_empty():
		return
	_append_system("[color=yellow]↻ Fetching available models...[/color]\n")
	if _provider_id == "gemini":
		_append_system("[color=gray]Probing Gemini models (legacy/experimental entries are skipped)...[/color]\n")
	var result: Dictionary = AIProviders.refresh_models(_provider_id)
	if result.get("ok", false):
		var models: Array = result.get("models", [])
		var removed: Array = result.get("removed", [])
		var rejected: Array = result.get("rejected", [])
		if models.is_empty():
			_append_system("[color=yellow]No models returned. Using default list.\n[/color]")
		else:
			_append_system("[color=green]✓ Loaded " + str(models.size()) + " working models[/color]\n")
			if not rejected.is_empty():
				var show := rejected.slice(0, 12)
				var extra := rejected.size() - show.size()
				var msg := ", ".join(show)
				if extra > 0:
					msg += " (+%d more)" % extra
				_append_system("[color=gray]Filtered unavailable: " + msg + "[/color]\n")
			if not removed.is_empty():
				_append_system("[color=gray]Removed from cache: " + ", ".join(removed) + "[/color]\n")
			# Refresh the provider info so the dropdown picks up cached models
			var providers: Array = AIProviders.get_providers()
			for p in providers:
				if p.id == _provider_id:
					_provider_info = p
					var prev_model := _current_model
					_update_model_dropdown()
					if prev_model != _current_model and not prev_model.is_empty():
						_append_system("[color=yellow]Model switched from [color=cyan]%s[/color] to [color=cyan]%s[/color] (previous choice unavailable)[/color]\n" % [prev_model, _current_model])
					break
	else:
		var err: String = result.get("error", "Unknown error")
		_append_system("[color=red]✗ Failed to refresh models: " + err + "[/color]\n")

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
		var models: Array = _provider_info.models
		for m in models:
			_model_dropdown.add_item(m)
		if models.is_empty():
			_current_model = ""
			return
		# Keep current selection when still valid; otherwise pick best available.
		var pick: String = _current_model
		if pick.is_empty() or models.find(pick) < 0:
			pick = AIProviders.pick_default_model(_provider_id, models)
		if models.find(pick) < 0:
			pick = str(models[0])
		var didx: int = models.find(pick)
		_model_dropdown.selected = maxi(didx, 0)
		_current_model = pick

# ---------------------------------------------------------------------------
# API Key Settings Dialog
# ---------------------------------------------------------------------------
const _API_KEY_DIALOG_SIZE := Vector2i(520, 640)

func _show_api_key_dialog() -> void:
	if not AIProviders:
		return
	if is_instance_valid(_api_key_dialog):
		_api_key_dialog.queue_free()
		_api_key_dialog = null

	_api_key_dialog = AcceptDialog.new()
	var dlg := _api_key_dialog
	dlg.title = "⚙️  AI Provider API Keys"
	dlg.wrap_controls = false
	dlg.unresizable = true
	dlg.size = _API_KEY_DIALOG_SIZE
	dlg.min_size = _API_KEY_DIALOG_SIZE
	dlg.max_size = _API_KEY_DIALOG_SIZE
	dlg.exclusive = true

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	dlg.add_child(outer)

	var desc := Label.new()
	desc.text = "Enter API keys for cloud AI providers.\nKeys are stored locally in user://vg_ai_keys.cfg"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(desc)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2i(0, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

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
		if not edit.text.is_empty():
			edit.focus_entered.connect(edit.select_all)
		hbox.add_child(edit)
		key_edits[p.id] = edit

		var eye := Button.new()
		eye.text = "👁"
		eye.tooltip_text = "Show/hide key"
		eye.pressed.connect(func(): edit.secret = not edit.secret)
		hbox.add_child(eye)

	vbox.add_child(HSeparator.new())

	var hints := Label.new()
	hints.text = "Get keys from:\n• OpenAI: platform.openai.com/api-keys\n• Claude: console.anthropic.com/settings/keys\n• Gemini: aistudio.google.com/apikey\n• DeepSeek: platform.deepseek.com/api-keys\n• Qwen: dashscope.console.aliyun.com/apiKey\n• Codeium: codeium.com/profile → API Keys\n• Amazon Q: Set up Bedrock Access Gateway locally"
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hints)

	dlg.confirmed.connect(func():
		for pid in key_edits:
			AIProviders.save_api_key(pid, key_edits[pid].text.strip_edges())
		_append_system("[color=green]API keys saved.[/color]\n")
		_activate_provider()
		_api_key_dialog = null
		dlg.queue_free()
	, CONNECT_ONE_SHOT)
	dlg.close_requested.connect(func():
		_api_key_dialog = null
		dlg.queue_free()
	, CONNECT_ONE_SHOT)

	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(dlg, _API_KEY_DIALOG_SIZE)
	else:
		add_child(dlg)
		dlg.popup_centered(_API_KEY_DIALOG_SIZE)

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
		_conversation_history, prompt, api_key, _pending_image_b64)
	if not _pending_image_b64.is_empty():
		_clear_pending_image()

	# Phase 6c: inject native FC tool schemas for cloud providers that support it.
	# Parse → augment → re-serialise so we don't duplicate the JSON builders in providers.gd.
	if VgAiFC and VgAiFC.supports_native_fc(_provider_id):
		var body_dict = JSON.parse_string(req_data["body"])
		if body_dict != null and typeof(body_dict) == TYPE_DICTIONARY:
			VgAiFC.inject_tools_into_body(_provider_id, body_dict)
			# JSON.parse_string() converts integers to floats; re-cast known int fields
			# before re-serialising or Anthropic rejects with "Input should be a valid integer".
			for _int_key in ["max_tokens", "max_output_tokens", "maxOutputTokens"]:
				if body_dict.has(_int_key):
					body_dict[_int_key] = int(body_dict[_int_key])
			req_data["body"] = JSON.stringify(body_dict)

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
	_stream_tool_watermark = 0
	_stream_vgtool_suppress = false
	_stream_line_buf = ""
	_stream_line_displayed = 0
	_fc_fragments.clear()  # Phase 6c: reset FC fragment accumulator.

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
	# Sync checkboxes to persisted settings.
	if is_instance_valid(_voice_speak_toggle):
		_voice_speak_toggle.set_pressed_no_signal(_voice_ctrl.auto_speak_replies)
	if is_instance_valid(_voice_vad_toggle):
		_voice_vad_toggle.set_pressed_no_signal(_voice_ctrl.vad_enabled)

func _on_mic_toggled(pressed: bool) -> void:
	# ⚡ Realtime mode: the mic button starts/stops the WS session.
	if is_instance_valid(_realtime_btn) and _realtime_btn.button_pressed:
		_ensure_realtime_ctrl()
		if _realtime_ctrl == null:
			_mic_btn.button_pressed = false
			return
		if pressed:
			var problem: String = _realtime_ctrl.diagnose()
			if not problem.is_empty():
				_append_system("[color=yellow]⚡ %s[/color]\n" % problem)
				_mic_btn.button_pressed = false
				return
			_realtime_ctrl.system_instructions = _get_active_system_prompt()
			var ok: bool = _realtime_ctrl.start_session()
			if not ok:
				_mic_btn.button_pressed = false
		else:
			if _realtime_ctrl.is_session_active():
				_realtime_ctrl.stop_session()
		return

	# Standard PTT mode.
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

func _on_vad_toggled(pressed: bool) -> void:
	_ensure_voice_ctrl()
	if _voice_ctrl != null:
		_voice_ctrl.vad_enabled = pressed
		_voice_ctrl.save_settings()

# ── Tier 2.5d: realtime toggle handler ──────────────────────────────────────
func _on_realtime_toggled(pressed: bool) -> void:
	if pressed:
		_append_system("[color=#aaddff]⚡ Realtime mode active — click 🎙 to start a live session.[/color]\n")
		_mic_btn.tooltip_text = "Start realtime session: click to connect, click again to disconnect"
	else:
		if _realtime_ctrl != null and is_instance_valid(_realtime_ctrl):
			if _realtime_ctrl.is_session_active():
				_realtime_ctrl.stop_session()
		_mic_btn.tooltip_text = "Push-to-talk: click to record, click again to stop and transcribe"
		_mic_btn.button_pressed = false

func _ensure_realtime_ctrl() -> void:
	if _realtime_ctrl != null and is_instance_valid(_realtime_ctrl):
		return
	var rt_script = load("res://addons/visual_gasic/vg_ai_realtime.gd")
	if rt_script == null:
		_append_system("[color=red]Realtime module not found.[/color]\n")
		return
	_realtime_ctrl = rt_script.new()
	add_child(_realtime_ctrl)
	if _realtime_ctrl.has_signal("session_started"):
		_realtime_ctrl.session_started.connect(_on_realtime_session_started)
	if _realtime_ctrl.has_signal("session_stopped"):
		_realtime_ctrl.session_stopped.connect(_on_realtime_session_stopped)
	if _realtime_ctrl.has_signal("session_failed"):
		_realtime_ctrl.session_failed.connect(_on_realtime_session_failed)
	if _realtime_ctrl.has_signal("listening_started"):
		_realtime_ctrl.listening_started.connect(_on_realtime_listening_started)
	if _realtime_ctrl.has_signal("listening_stopped"):
		_realtime_ctrl.listening_stopped.connect(_on_realtime_listening_stopped)
	if _realtime_ctrl.has_signal("transcript_delta"):
		_realtime_ctrl.transcript_delta.connect(_on_realtime_transcript_delta)
	if _realtime_ctrl.has_signal("reply_delta"):
		_realtime_ctrl.reply_delta.connect(_on_realtime_reply_delta)
	if _realtime_ctrl.has_signal("reply_done"):
		_realtime_ctrl.reply_done.connect(_on_realtime_reply_done)
	if _realtime_ctrl.has_signal("reply_audio_started"):
		_realtime_ctrl.reply_audio_started.connect(_on_realtime_audio_started)
	if _realtime_ctrl.has_signal("reply_audio_done"):
		_realtime_ctrl.reply_audio_done.connect(_on_realtime_audio_done)

# ── Tier 2.5d: realtime signal handlers ─────────────────────────────────────
func _on_realtime_session_started() -> void:
	_append_system("[color=#aaddff]⚡ Realtime session open — speak freely.[/color]\n")
	if is_instance_valid(_mic_btn):
		_mic_btn.text = "🔴"
		_mic_btn.tooltip_text = "Realtime session active — click to disconnect"

func _on_realtime_session_stopped() -> void:
	_append_system("[color=#aaddff]⚡ Realtime session closed.[/color]\n")
	if is_instance_valid(_mic_btn):
		_mic_btn.button_pressed = false
		_mic_btn.text = "🎙"
		_mic_btn.tooltip_text = "Start realtime session: click to connect, click again to disconnect"

func _on_realtime_session_failed(reason: String) -> void:
	_append_system("[color=red]⚡ Realtime error: %s[/color]\n" % reason)
	if is_instance_valid(_mic_btn):
		_mic_btn.button_pressed = false
		_mic_btn.text = "🎙"

func _on_realtime_listening_started() -> void:
	# VAD detected speech — subtle visual cue.
	if is_instance_valid(_mic_btn):
		_mic_btn.text = "🎤"

func _on_realtime_listening_stopped() -> void:
	if is_instance_valid(_mic_btn):
		_mic_btn.text = "🔴"

var _realtime_transcript_buf: String = ""

func _on_realtime_transcript_delta(text: String) -> void:
	_realtime_transcript_buf += text

func _on_realtime_reply_delta(text: String) -> void:
	# Append incrementally to the output so the user sees text as it arrives.
	_output.append_text(_escape_bbcode(text))

func _on_realtime_reply_done(_full_text: String) -> void:
	# Print the user's transcript if we accumulated one.
	if not _realtime_transcript_buf.is_empty():
		_append_system("[color=#88ddff]🎤 You said:[/color] %s\n" % _escape_bbcode(_realtime_transcript_buf))
		_realtime_transcript_buf = ""
	_output.append_text("\n")

func _on_realtime_audio_started() -> void:
	if is_instance_valid(_stop_speak_btn):
		_stop_speak_btn.visible = true

func _on_realtime_audio_done() -> void:
	if is_instance_valid(_stop_speak_btn):
		_stop_speak_btn.visible = false

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
	# Also stop realtime AI audio (barge-in via the ⏹ button).
	if _realtime_ctrl != null and is_instance_valid(_realtime_ctrl):
		if _realtime_ctrl.has_method("stop_ai_audio"):
			_realtime_ctrl.stop_ai_audio()
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
	if _patch_spec == null:
		var pps := load("res://addons/visual_gasic/vg_ai_patch_spec.gd")
		if pps != null:
			_patch_spec = pps.new()
	if _project_spec == null:
		var ps := load("res://addons/visual_gasic/vg_ai_project_spec.gd")
		if ps != null:
			_project_spec = ps.new()
	if _test_spec == null:
		var ts := load("res://addons/visual_gasic/vg_ai_test_spec.gd")
		if ts != null:
			_test_spec = ts.new()
	if _wnodes_spec == null:
		var ws := load("res://addons/visual_gasic/vg_ai_wnodes_spec.gd")
		if ws != null:
			_wnodes_spec = ws.new()
	if _lesson_spec == null:
		var ls := load("res://addons/visual_gasic/vg_ai_lesson_spec.gd")
		if ls != null:
			_lesson_spec = ls.new()


## Toggle the 🔨 Build-form button based on whether the latest reply
## actually contains a usable spec.  Cheap to call after every reply.
func _refresh_build_form_btn() -> void:
	_ensure_form_spec_helper()
	_ensure_agent_helpers()
	if _form_spec != null:
		var spec: Dictionary = _form_spec.extract_spec(_accumulated_response)
		if is_instance_valid(_build_form_btn):
			_build_form_btn.disabled = spec.is_empty()
		if is_instance_valid(_make_this_btn):
			var show_adv := _advanced_actions_visible()
			if spec.is_empty():
				_make_this_btn.visible = false
				_make_this_btn.disabled = true
				_make_this_btn.tooltip_text = "Ask Narcea to design a form — she'll include a vg-form-spec block."
			else:
				_make_this_btn.visible = show_adv
				_make_this_btn.disabled = false
				_make_this_btn.tooltip_text = "Apply: %s" % _form_spec.describe(spec)
		if is_instance_valid(_form_from_desc_btn):
			_form_from_desc_btn.visible = _advanced_actions_visible()
		if is_instance_valid(_code_from_desc_btn):
			_code_from_desc_btn.visible = _advanced_actions_visible()
		if is_instance_valid(_project_from_desc_btn):
			_project_from_desc_btn.visible = _advanced_actions_visible()
	elif is_instance_valid(_make_this_btn):
		_make_this_btn.visible = false
		_make_this_btn.disabled = true
	if is_instance_valid(_make_code_btn):
		var code_spec_d: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
		var patch_spec_d: Dictionary = {} if _patch_spec == null else _patch_spec.extract_spec(_accumulated_response)
		if not code_spec_d.is_empty():
			_make_code_btn.visible = _advanced_actions_visible()
			_make_code_btn.disabled = false
			_make_code_btn.tooltip_text = "Preview and apply: %s" % _code_spec.describe(code_spec_d)
		elif not patch_spec_d.is_empty():
			_make_code_btn.visible = _advanced_actions_visible()
			_make_code_btn.disabled = false
			_make_code_btn.tooltip_text = "Preview and apply patch: %s" % _patch_spec.describe(patch_spec_d)
		else:
			_make_code_btn.visible = false
			_make_code_btn.disabled = true
			_make_code_btn.tooltip_text = "Ask Narcea for a vg-code-spec or vg-patch-spec block to enable file writes."
	if is_instance_valid(_make_project_btn):
		var proj_spec_d: Dictionary = {} if _project_spec == null else _project_spec.extract_spec(_accumulated_response)
		if proj_spec_d.is_empty():
			_make_project_btn.visible = false
			_make_project_btn.disabled = true
			_make_project_btn.tooltip_text = "Ask Narcea for a vg-project-spec block to scaffold a runnable project."
		else:
			_make_project_btn.visible = _advanced_actions_visible()
			_make_project_btn.disabled = false
			_make_project_btn.tooltip_text = "Preview and scaffold: %s" % _project_spec.describe(proj_spec_d)
	# Test-spec gating + lesson-spec auto-render.
	if is_instance_valid(_make_test_btn):
		var test_spec_d: Dictionary = {} if _test_spec == null else _test_spec.extract_spec(_accumulated_response)
		if test_spec_d.is_empty():
			_make_test_btn.visible = false
			_make_test_btn.disabled = true
			_make_test_btn.tooltip_text = "Ask Narcea for a vg-test-spec block to enable this."
		else:
			_make_test_btn.visible = true
			_make_test_btn.disabled = false
			_make_test_btn.tooltip_text = "Write and run: %s" % _test_spec.describe(test_spec_d)
	if is_instance_valid(_make_wnodes_btn):
		var wn_spec_d: Dictionary = {} if _wnodes_spec == null else _wnodes_spec.extract_spec(_accumulated_response)
		if wn_spec_d.is_empty():
			_make_wnodes_btn.visible = false
			_make_wnodes_btn.disabled = true
			_make_wnodes_btn.tooltip_text = "Ask Narcea for a vg-wnodes-spec block to enable this."
		else:
			_make_wnodes_btn.visible = true
			_make_wnodes_btn.disabled = false
			_make_wnodes_btn.tooltip_text = "Write: %s" % _wnodes_spec.describe(wn_spec_d)
	# Lesson specs render immediately (display-only) so the user doesn't
	# have to hunt for them in the chat scrollback.
	if _lesson_spec != null:
		var lesson_d: Dictionary = _lesson_spec.extract_spec(_accumulated_response)
		if not lesson_d.is_empty() and lesson_d.get("_rendered", false) != true:
			lesson_d["_rendered"] = true  # local flag, not persisted
			var bb: String = _lesson_spec.render_bbcode(lesson_d)
			if not bb.is_empty():
				_output.append_text("\n" + bb + "\n")
	# Auto-apply spec when:
	#   a) user came via Form…/Code…/Project… button (_last_send_was_desc_mode), OR
	#   b) chat-first build intent was detected on send, OR
	#   c) Narcea persona returned a spec (legacy path), OR
	#   d) code follow-up after layout-only apply is pending completion.
	var _chat_build_auto := (not _last_build_intent.is_empty()) and not _build_form_ran_this_turn
	var _narcea_auto := (_persona_id == "narcea") and not _build_form_ran_this_turn
	# build_form tool path: layout already built; apply code if present.
	if _persona_id == "narcea" and _build_form_ran_this_turn:
		var _code_spec_after_build: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
		if not _code_spec_after_build.is_empty():
			call_deferred("_auto_apply_code_spec_no_dialog", _code_spec_after_build)
		else:
			var _form_after_tool: Dictionary = {} if _form_spec == null else _form_spec.extract_spec(_accumulated_response)
			if not _form_after_tool.is_empty() and _form_spec_needs_code(_form_after_tool):
				var _fn := str(_form_after_tool.get("form_name", "Form1")).strip_edges()
				if _fn.is_empty():
					_fn = "Form1"
				var _vg_after := "res://%s.vg" % _fn
				var _handler_note := _finalize_form_handlers(_fn, _form_after_tool, _vg_after)
				if not _handler_note.is_empty():
					_append_system("[color=#aaffaa]Form layout saved%s[/color]\n" % _handler_note)
	# Code-only follow-up turn: apply vg-code-spec silently.
	if _code_followup_pending:
		var _follow_code: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
		if not _follow_code.is_empty():
			call_deferred("_auto_apply_code_spec_no_dialog", _follow_code)
			_code_followup_pending = false
	if _last_send_was_desc_mode or _chat_build_auto or _narcea_auto:
		# Remember whether the user explicitly asked for a spec (via the
		# Form.../Code.../Project... buttons) BEFORE resetting the flag --
		# the "spec missing" nag below should ONLY fire for that explicit
		# flow.  _narcea_auto is true for EVERY Narcea reply (persona ==
		# "narcea" is the default), including plain Q&A chat that never
		# intended to produce a form/code/project spec at all -- without
		# this guard, ordinary conversational replies (e.g. debugging
		# questions) always fell through to the same "didn't contain the
		# expected spec block" warning, spamming irrelevant noise into
		# every single reply.
		var _was_explicit_desc_mode := _last_send_was_desc_mode
		_last_send_was_desc_mode = false
		var _spec_missing := false
		var _hint := ""
		# Only honour the Form/Code/Project desc mode on the send that came
		# from that dialog. Leaving _form_from_desc_mode stuck on "project"
		# caused every later Narcea chat reply to auto-open the diff dialog
		# (often invisible) and lock the whole editor.
		var _desc_mode := _form_from_desc_mode if _was_explicit_desc_mode else "auto"
		if _was_explicit_desc_mode:
			_form_from_desc_mode = "form"
		var _proj_spec_d: Dictionary = {} if _project_spec == null else _project_spec.extract_spec(_accumulated_response)
		match _desc_mode:
			"code":
				if is_instance_valid(_make_code_btn) and not _make_code_btn.disabled:
					call_deferred("_on_make_code")
				else:
					_spec_missing = true
					_hint = "Narcea needs a fenced ```vg-code-spec``` JSON block."
			"project":
				if not _proj_spec_d.is_empty():
					_suppress_agent_loop = true
					call_deferred("_on_make_project", true)
				else:
					_spec_missing = true
					_hint = "Narcea needs a fenced ```vg-project-spec``` JSON block."
			_:
				if not _proj_spec_d.is_empty() and (_last_build_intent == "project" or _was_explicit_desc_mode):
					_suppress_agent_loop = true
					call_deferred("_on_make_project", true)
				elif is_instance_valid(_make_this_btn) and not _make_this_btn.disabled:
					call_deferred("_on_make_this")
				elif is_instance_valid(_make_code_btn) and not _make_code_btn.disabled:
					call_deferred("_on_make_code")
				elif _chat_build_auto or _was_explicit_desc_mode:
					_spec_missing = true
					_hint = "build request"
		if (_chat_build_auto or _narcea_auto) and not _spec_missing:
			_last_build_intent = ""
		if _spec_missing and (_was_explicit_desc_mode or _chat_build_auto):
			if _desc_mode == "project" and _accumulated_response.find("```vg-project-spec") >= 0:
				_append_system("[color=#ffaa66]Gemini's reply was truncated mid-spec (incomplete JSON). A retry message is in the prompt box — click Send to ask it to finish the ```vg-project-spec``` block.[/color]\n")
				if is_instance_valid(_input) and _input.text.strip_edges().is_empty():
					_input.text = ("Your ```vg-project-spec``` JSON was cut off before it finished. "
						+ "Continue from where you stopped and emit the COMPLETE fenced block: "
						+ "forms[] with all controls, files[] with Form1.vg source, then close ```.")
			else:
				_append_system("[color=#ff8888]I couldn't find a spec block in that reply, so nothing was built. Try sending your request again — I'll ask Narcea for the proper ```vg-form-spec``` and ```vg-code-spec``` blocks automatically.[/color]\n")


## Lean-v1 Narcea spec-builder entry points.  Three sibling actions —
## form, code, project — share a single dialog widget; mode flag picks the
## hardened prompt template on confirm.  Each switches to the Narcea
## persona so vg_ai_narcea.gd's schema rules + VG knowledge are injected.
func _on_form_from_desc_pressed() -> void:
	_open_from_desc_dialog("form")


func _on_code_from_desc_pressed() -> void:
	_open_from_desc_dialog("code")


func _on_project_from_desc_pressed() -> void:
	_open_from_desc_dialog("project")


func _open_from_desc_dialog(mode: String) -> void:
	const DIALOG_SIZE := Vector2i(520, 280)
	var script := load("res://addons/visual_gasic/vg_ai_from_desc_dialog.gd")
	if script == null:
		_append_system("[color=#ff8888]Description dialog unavailable.[/color]\n")
		return
	var dlg: ConfirmationDialog = script.new()
	dlg.configure(mode)
	dlg.confirmed.connect(func() -> void:
		_submit_form_from_desc(dlg.get_description(), dlg.get_desc_mode())
		dlg.queue_free()
	, CONNECT_ONE_SHOT)
	dlg.canceled.connect(dlg.queue_free, CONNECT_ONE_SHOT)
	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(dlg, DIALOG_SIZE)
	else:
		add_child(dlg)
		dlg.popup_centered(DIALOG_SIZE)
	dlg.grab_description_focus()


func _submit_form_from_desc(desc: String, mode: String) -> void:
	_form_from_desc_mode = mode
	if desc.is_empty():
		_append_system("[color=#ff8888]No description entered.[/color]\n")
		return
	_ensure_narcea_for_build(true)
	_last_build_intent = mode if mode in ["form", "code", "project"] else "form"
	_last_user_prompt = desc
	var prompt := _build_hardened_prompt(desc, mode)
	if not is_instance_valid(_input):
		return
	_input.text = prompt
	_last_send_was_desc_mode = true
	_on_send()


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
	# Layout sanity check — report any overlaps or out-of-bounds controls.
	if ok and _form_spec.has_method("check_layout"):
		var layout_warns: Array = _form_spec.check_layout(spec)
		for w: String in layout_warns:
			_append_system("[color=#ffcc44]⚠ Layout: %s[/color]\n" % w)
		if not layout_warns.is_empty():
			_append_system("[color=#ffcc44]Tip: ask Narcea to fix the layout using the warnings above.[/color]\n")
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
	# Layout sanity check — warn but don't abort.
	if _form_spec.has_method("check_layout"):
		var layout_warns: Array = _form_spec.check_layout(spec)
		for w: String in layout_warns:
			_append_system("[color=#ffcc44]⚠ Layout: %s[/color]\n" % w)

	# 2. Save the .tscn to res://<form_name>.tscn (don't clobber if path
	#    already set by the user — let save_form() handle that case).
	# CRITICAL: form_name MUST be non-empty — empty name produces
	# "res://.tscn" which Godot's resource saver mangles into a random
	# temp filename and writes the script ext_resource as just ".vg",
	# leaving the project with orphaned files and no working form.
	var form_name: String = str(spec.get("form_name", "Form1")).strip_edges()
	if form_name.is_empty():
		form_name = "Form1"
	# If a vg-code-spec is present with a .vg path, prefer placing the
	# .tscn next to it so the form and the code live together.
	_ensure_agent_helpers()
	var code_spec_d: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
	var _ai_vg_path: String = ""
	if not code_spec_d.is_empty():
		for _fe in code_spec_d.get("files", []):
			var _fp: String = str(_fe.get("path", "")).strip_edges()
			if _fp.ends_with(".vg") and _fp.get_file().get_basename() == form_name:
				_ai_vg_path = _fp
				break
	var tscn_path: String = ""
	if designer.has_method("get_form_path"):
		tscn_path = designer.get_form_path()
	# Reject a degenerate existing path (no basename).
	if not tscn_path.is_empty() and tscn_path.get_file().get_basename().is_empty():
		tscn_path = ""
	if tscn_path.is_empty():
		if not _ai_vg_path.is_empty():
			tscn_path = _ai_vg_path.get_basename() + ".tscn"
		else:
			tscn_path = "res://%s.tscn" % form_name
		if designer.has_method("save_form_as"):
			# Ensure the destination dir exists.
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(tscn_path.get_base_dir()))
			designer.save_form_as(tscn_path)
	else:
		if designer.has_method("save_form"):
			designer.save_form()

	# Validate the save actually produced a .tscn — abort loudly if not.
	if not FileAccess.file_exists(tscn_path):
		_append_system("[color=#ff8888]⚠ Could not save form to %s — aborting code write to avoid orphaned files.[/color]\n" % tscn_path)
		return

	_promote_form_to_main_scene(tscn_path)

	# 3. Write event code.  Prefer a full vg-code-spec from the AI reply
	#    (produced when Narcea was asked with the form-from-desc flow);
	#    fall back to auto-generated stubs from the form spec.
	var vg_path: String = tscn_path.get_basename() + ".vg"
	var code_written := false
	if not code_spec_d.is_empty():
		# Full implementations supplied — apply them directly.
		# The .vg entry is written to vg_path (the path derived from the
		# actual saved form scene) so that double-clicking controls later
		# opens the right file.  Non-.vg entries go through the safe_writer.
		_safe_writer.set_root("res://")

		# Build a VB6-alias → actual-name map from the form spec so we can
		# fix up wrong control names the AI may have used (e.g. TextBox1
		# instead of LineEdit1, Command1 instead of Button1).
		var _vb6_alias_to_actual: Dictionary = {}
		var _spec_controls: Array = spec.get("controls", [])
		const _VB6_TYPE_ALIASES: Dictionary = {
			"TextBox": "LineEdit", "Command": "Button", "Frame": "Panel",
			"ComboBox": "OptionButton", "ListBox": "ItemList",
			"Shape": "ColorRect", "Image": "TextureRect",
			"PictureBox": "TextureRect", "HScrollBar": "HScrollBar",
			"VScrollBar": "VScrollBar", "Timer": "Timer",
		}
		for _ci in _spec_controls:
			if typeof(_ci) != TYPE_DICTIONARY:
				continue
			var _actual_name: String = str(_ci.get("name", ""))
			var _actual_type: String = str(_ci.get("type", ""))
			if _actual_name.is_empty():
				continue
			# Check every VB6 alias type — if the actual type starts with
			# an alias prefix, derive what the alias name would have been.
			for _vb6_type in _VB6_TYPE_ALIASES:
				if _actual_type.begins_with(_VB6_TYPE_ALIASES[_vb6_type]):
					# e.g. actual "LineEdit1" → vb6 guess "TextBox1"
					var _suffix: String = _actual_name.substr(_actual_type.length())
					var _vb6_guess: String = _vb6_type + _suffix
					if _vb6_guess != _actual_name:
						_vb6_alias_to_actual[_vb6_guess] = _actual_name

		var files_to_apply: Array = code_spec_d.get("files", [])
		var vg_written := false
		for file_entry in files_to_apply:
			var fp: String = str(file_entry.get("path", ""))
			if fp.ends_with(".vg"):
				var src: String = str(file_entry.get("source", ""))
				if not src.is_empty():
					# --- Normalize header to top ---
					# Remove any 'Option Explicit' line and standard header
					# comment from wherever the AI placed them, then re-prepend.
					var _lines: PackedStringArray = src.split("\n")
					var _header_comment := ""
					var _body_lines: Array[String] = []
					var _has_opt_explicit := false
					for _ln in _lines:
						var _stripped := _ln.strip_edges()
						if _stripped.to_lower() == "option explicit":
							_has_opt_explicit = true
						elif _stripped.begins_with("' ") and _stripped.to_lower().contains("form script") and _header_comment.is_empty():
							pass  # discard stray "' Visual Gasic Form Script" duplicate
						else:
							_body_lines.append(_ln)
					# Rebuild: header comment (if any) → Option Explicit → body.
					# Find the first non-empty line in body to use as header.
					var _first_comment := ""
					var _real_body: Array[String] = []
					var _found_first := false
					for _bl in _body_lines:
						if not _found_first:
							if _bl.strip_edges().begins_with("'"):
								_first_comment = _bl
								_found_first = true
								continue
							elif not _bl.strip_edges().is_empty():
								_found_first = true
						_real_body.append(_bl)
					var _normalized := ""
					if not _first_comment.is_empty():
						_normalized += _first_comment + "\n"
					if _has_opt_explicit:
						_normalized += "Option Explicit\n"
					# Strip leading blank lines from body.
					var _body_str := "\n".join(_real_body)
					while _body_str.begins_with("\n"):
						_body_str = _body_str.substr(1)
					_normalized += "\n" + _body_str
					src = _normalized

					# --- Remap VB6 alias names → actual names ---
					# Replace whole-word occurrences (followed by . or _)
					# so TextBox1.Text → LineEdit1.Text, etc.
					for _vb6_name in _vb6_alias_to_actual:
						var _real_name: String = _vb6_alias_to_actual[_vb6_name]
						# Use a simple loop to replace word-boundary occurrences.
						src = src.replace(_vb6_name + ".", _real_name + ".")
						src = src.replace(_vb6_name + "_", _real_name + "_")
						src = src.replace(_vb6_name + " ", _real_name + " ")
						src = src.replace(_vb6_name + "\t", _real_name + "\t")
						src = src.replace(_vb6_name + "\n", _real_name + "\n")

					var dir_abs := ProjectSettings.globalize_path(vg_path.get_base_dir())
					DirAccess.make_dir_recursive_absolute(dir_abs)
					var wf := FileAccess.open(vg_path, FileAccess.WRITE)
					if wf:
						wf.store_string(src)
						wf.close()
						vg_written = true
					else:
						_append_system("[color=#ffaa66]⚠ Could not write %s[/color]\n" % vg_path)
			else:
				# Non-.vg file (assets, GDScript, etc.) — apply normally.
				var single: Dictionary = {"files": [file_entry]}
				_code_spec.apply(single, _safe_writer, false)
		if vg_written:
			code_written = true
		elif not vg_written:
			# Spec had no .vg entry — fall through to stub generation below.
			pass
	else:
		# No full code spec — generate stub shells from the form spec.
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
				code_written = true
			else:
				_append_system("[color=#ffaa66]⚠ Could not write %s — form was built but stubs were not added.[/color]\n" % vg_path)

	# 4. Tell the editor about the new files so the file browser refreshes.
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	# 5. Synthesize/follow-up handler code before opening the editor.
	var handler_note := _finalize_form_handlers(form_name, spec, vg_path)

	# 6. Open the .vg in the embedded code editor if available.
	if plugin and is_instance_valid(plugin) and "_embedded_code_editor" in plugin:
		var ece = plugin._embedded_code_editor
		if is_instance_valid(ece) and ece.has_method("load_file"):
			ece.load_file(vg_path)

	var summary := "🤖 %s; saved %s" % [build_msg, tscn_path.get_file()]
	if handler_note.is_empty() and code_written:
		summary += "; code written to %s — click ▶ Run to test" % vg_path.get_file()
	elif not handler_note.is_empty():
		summary += handler_note
	_append_system("[color=#aaffaa]%s[/color]\n" % summary)
	if handler_note.contains("synthesized") or handler_note.contains("generating"):
		_append_system("[color=#88bbff]✓ Auto-built from chat — edit Form1.vg or ask Narcea for changes, then click ▶ Run.[/color]\n")
	elif code_written and handler_note.is_empty():
		_append_system("[color=#88bbff]✓ Form saved with handler code — click ▶ Run to test.[/color]\n")
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
	if _safe_writer == null:
		_append_system("[color=#ff8888]Code-spec helpers unavailable.[/color]\n")
		return
	_safe_writer.set_root("res://")
	# Prefer vg-code-spec when present; fall back to vg-patch-spec.
	var spec: Dictionary = {} if _code_spec == null else _code_spec.extract_spec(_accumulated_response)
	if not spec.is_empty():
		var plan: Array = _code_spec.plan(spec, _safe_writer)
		_show_diff_dialog(plan, func() -> void:
			var paths_pre: Array = []
			for item in plan:
				paths_pre.append(str(item.get("path", "")))
			_undo_capture("Make code", paths_pre)
			var snap_local: Dictionary = _undo_stack.back() if not _undo_stack.is_empty() else {}
			var result: Dictionary = _code_spec.apply(spec, _safe_writer, false)
			_last_apply_result = result
			_last_apply_kind = "Code"
			_last_apply_diff_summary = _summarise_diff(result.get("written", []), snap_local)
			_print_apply_result("Code", result)
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()
			_reload_first_vg_in_editor(spec)
		)
		return
	var patch: Dictionary = {} if _patch_spec == null else _patch_spec.extract_spec(_accumulated_response)
	if not patch.is_empty():
		var pplan: Array = _patch_spec.plan(patch, _safe_writer)
		# Synthesise a code-spec-shaped object for _reload_first_vg_in_editor
		# (it just walks .files[].path).
		var reload_shim := {"files": []}
		for item in pplan:
			reload_shim["files"].append({"path": item["path"]})
		_show_diff_dialog(pplan, func() -> void:
			var paths_pre: Array = []
			for item in pplan:
				paths_pre.append(str(item.get("path", "")))
			_undo_capture("Make patch", paths_pre)
			var snap_local: Dictionary = _undo_stack.back() if not _undo_stack.is_empty() else {}
			var result: Dictionary = _patch_spec.apply(patch, _safe_writer, false)
			_last_apply_result = result
			_last_apply_kind = "Patch"
			_last_apply_diff_summary = _summarise_diff(result.get("written", []), snap_local)
			_print_apply_result("Patch", result)
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()
			_reload_first_vg_in_editor(reload_shim)
		)
		return
	_append_system("[color=#ff8888]No vg-code-spec or vg-patch-spec block in the latest reply.[/color]\n")


## Find the embedded code editor and reload the first .vg file listed
## in `spec.files` — used by both _on_make_code() and the silent
## auto-apply path to keep the UI in sync with disk.
func _reload_first_vg_in_editor(spec: Dictionary) -> void:
	var plugin: Object = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			plugin = base.get_meta("visual_gasic_plugin_instance")
	if plugin == null or not is_instance_valid(plugin):
		return
	if not ("_embedded_code_editor" in plugin):
		return
	var ece = plugin._embedded_code_editor
	if ece == null or not is_instance_valid(ece) or not ece.has_method("load_file"):
		return
	for _fe in spec.get("files", []):
		var _fp: String = str(_fe.get("path", "")).strip_edges()
		if _fp.ends_with(".vg") and FileAccess.file_exists(_fp):
			ece.load_file(_fp)
			break


## Apply a vg-code-spec silently (no diff dialog) — used when Narcea
## already built the form via the build_form tool, so the code-spec is
## the only thing left to write.  Reloads the embedded code editor on
## the first .vg file written so the user sees the new code immediately.
func _auto_apply_code_spec_no_dialog(spec: Dictionary) -> void:
	_ensure_agent_helpers()
	if _code_spec == null or _safe_writer == null:
		return
	if spec.is_empty():
		return
	_safe_writer.set_root("res://")
	var result: Dictionary = _code_spec.apply(spec, _safe_writer, false)
	_print_apply_result("Code (auto)", result)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_reload_first_vg_in_editor(spec)
	for _fe in spec.get("files", []):
		var _fp: String = str(_fe.get("path", "")).strip_edges()
		if _fp.ends_with(".vg"):
			var tscn := _fp.get_basename() + ".tscn"
			if FileAccess.file_exists(tscn):
				_last_run_scene = tscn
				_promote_form_to_main_scene(tscn)
			if is_instance_valid(_run_btn):
				_run_btn.disabled = false
				_run_btn.tooltip_text = "Run %s" % tscn.get_file() if FileAccess.file_exists(tscn) else "Run"
			_append_system("[color=#aaffaa]Handler code applied — click ▶ Run to test.[/color]\n")
			break


## Auto-apply Narcea's first project-spec reply when the project was
## created by the welcome shell's "Ask Narcea" button. Skips if the seed
## flag isn't set, the reply has no spec, or helpers aren't loaded.
## Clears the flag on success so we never re-apply.
func _maybe_auto_apply_narcea_seed() -> void:
	if not ProjectSettings.has_setting("vg/narcea_seeded"):
		return
	if not bool(ProjectSettings.get_setting("vg/narcea_seeded", false)):
		return
	_ensure_agent_helpers()
	if _project_spec == null:
		return
	var spec: Dictionary = _project_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		# Narcea didn't include a vg-project-spec block this turn — leave
		# the flag set so the next reply can still trigger us.
		return
	_append_system("[color=#88dd88]🌿 Auto-applying Narcea's project spec…[/color]\n")
	_suppress_agent_loop = true
	call_deferred("_on_make_project", true)
	# One-shot: clear so subsequent replies are user-initiated.
	ProjectSettings.set_setting("vg/narcea_seeded", false)
	ProjectSettings.save()


## Scaffold a vg-project-spec block under res://ai_projects/<name>/.
## Forms are built via the shared FormDesigner (sandboxing is a v2 task);
## loose files go through the safe-writer rebound to the project subdir.
## skip_diff=true: apply immediately (Project… golden path); false: preview first.
func _on_make_project(skip_diff: bool = false) -> void:
	_ensure_agent_helpers()
	_ensure_form_spec_helper()
	if _project_spec == null or _safe_writer == null:
		_append_system("[color=#ff8888]Project-spec helpers unavailable.[/color]\n")
		return
	var spec: Dictionary = _project_spec.extract_spec(_accumulated_response)
	if spec.is_empty():
		_suppress_agent_loop = false
		_append_system("[color=#ff8888]No vg-project-spec block in the latest reply.[/color]\n")
		return
	if skip_diff:
		_append_system("[color=#88bbff]Scaffolding project under ai_projects/…[/color]\n")
		if is_instance_valid(_status_label):
			_status_label.text = "Scaffolding project…"
		call_deferred("_execute_project_scaffold", spec)
		return
	# Build a plan of just the *file* writes so the user can preview them.
	var root: String = _project_spec.project_root(spec)
	_safe_writer.set_root(root)
	var plan: Array = _build_project_plan(spec, root)
	_show_diff_dialog(plan, func() -> void:
		_execute_project_scaffold(spec)
	)


func _build_project_plan(spec: Dictionary, root: String) -> Array:
	var plan: Array = []
	if _code_spec != null:
		var sub_files: Array = []
		for entry in spec.get("files", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var p: String = _project_spec.rebase_path(str(entry.get("path", "")), root, _safe_writer)
			if _project_spec._skip_scaffold_file(p, spec):
				continue
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
	plan.append({
		"path": root + "project.json", "action": "create", "old": "",
		"new": "(manifest)", "lint": [], "safe": true, "safe_reason": "",
	})
	return plan


func _execute_project_scaffold(spec: Dictionary) -> void:
	if _scaffold_in_progress:
		return
	_scaffold_in_progress = true
	var root: String = _project_spec.project_root(spec)
	_safe_writer.set_root(root)
	var designer: Object = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			var plugin = base.get_meta("visual_gasic_plugin_instance")
			if plugin and is_instance_valid(plugin) and "_form_designer" in plugin:
				designer = plugin._form_designer
	var helpers := {
		"safe_writer": _safe_writer,
		"code_spec":   _code_spec,
		"form_spec":   _form_spec,
		"designer":    designer,
	}
	var result: Dictionary = _project_spec.apply(spec, helpers)
	const ProjectSynth = preload("res://addons/visual_gasic/vg_ai_project_synth.gd")
	var fin: Dictionary = ProjectSynth.finalize_project(spec, root, _last_user_prompt)
	var fin_notes: Array = fin.get("notes", [])
	if not fin_notes.is_empty():
		_append_system("[color=#aaffaa]Project finalize: %s[/color]\n" % ", ".join(fin_notes))
	_safe_writer.set_root("res://")
	_print_project_result(result)
	_last_project_root = result.get("root", "")
	var ms := str(result.get("main_scene", ""))
	if not ms.is_empty():
		_last_run_scene = ms
		_promote_form_to_main_scene(ms)
		if is_instance_valid(_run_btn):
			_run_btn.disabled = false
			_run_btn.tooltip_text = "Run %s" % ms.get_file()
	else:
		for w in result.get("written", []):
			var wp := str(w)
			if wp.ends_with(".tscn"):
				_promote_form_to_main_scene(wp)
				_last_run_scene = wp
				if is_instance_valid(_run_btn):
					_run_btn.disabled = false
					_run_btn.tooltip_text = "Run %s" % wp.get_file()
				break
	_scaffold_done()


func _scaffold_done() -> void:
	_scaffold_in_progress = false
	_suppress_agent_loop = false
	if is_instance_valid(_status_label) and not _is_generating:
		var pname: String = _provider_info.display_name if _provider_info else "Ollama"
		_status_label.text = ("✅ %s ready" % pname) if _ollama_available else ("❌ %s not found" % pname)
	_refresh_project_explorer()


## Show a diff-preview dialog for `plan` and call `on_confirm` if the
## user clicks Apply.  Spawns a fresh dialog on the editor root each time.
const _DIFF_DIALOG_SIZE := Vector2i(760, 540)
var _diff_dialog_open := false
func _show_diff_dialog(plan: Array, on_confirm: Callable) -> void:
	if _diff_dialog_open:
		_append_system("[color=#ffaa66]Diff dialog already open — close it first or cancel, then retry.[/color]\n")
		return
	var script := load("res://addons/visual_gasic/vg_ai_diff_dialog.gd")
	if script == null:
		_append_system("[color=#ff8888]Diff dialog unavailable.[/color]\n")
		return
	var dlg: ConfirmationDialog = script.new()
	dlg.unresizable = true
	dlg.size = _DIFF_DIALOG_SIZE
	dlg.min_size = _DIFF_DIALOG_SIZE
	dlg.exclusive = false
	dlg.set_plan(plan)
	var _finish := func() -> void:
		_diff_dialog_open = false
		if is_instance_valid(dlg):
			dlg.hide()
			dlg.queue_free()
	dlg.confirmed.connect(func() -> void:
		on_confirm.call()
		_finish.call()
	, CONNECT_ONE_SHOT)
	dlg.canceled.connect(_finish, CONNECT_ONE_SHOT)
	dlg.close_requested.connect(_finish, CONNECT_ONE_SHOT)
	_diff_dialog_open = true
	_append_system("[color=#88bbff]Review the Apply dialog — click \u2705 Apply to write files and enable \u25b6 Run.[/color]\n")
	call_deferred("_popup_diff_dialog", dlg)


func _popup_diff_dialog(dlg: ConfirmationDialog) -> void:
	if not is_instance_valid(dlg):
		_diff_dialog_open = false
		return
	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(dlg, _DIFF_DIALOG_SIZE)
	else:
		add_child(dlg)
		dlg.popup_centered(_DIFF_DIALOG_SIZE)


func _print_apply_result(label: String, result: Dictionary) -> void:
	var w: Array = result.get("written", [])
	var s: Array = result.get("skipped", [])
	var color := "#aaffaa" if result.get("ok", false) else "#ffaa66"
	_append_system("[color=%s]📝 %s: %s[/color]\n" % [color, label, str(result.get("summary", ""))])
	for p in w:
		_append_system("  [color=#aaffaa]+ %s[/color]\n" % str(p))
	# Detect patch anchor failures and surface the Retry button.
	var anchor_fails := 0
	for entry in s:
		var reason := str(entry.get("reason", ""))
		if reason.find("anchor not found") != -1 or reason.find("`find` not found") != -1:
			anchor_fails += 1
	if is_instance_valid(_retry_patch_btn):
		_retry_patch_btn.visible = anchor_fails > 0
		if anchor_fails > 0:
			_retry_patch_btn.tooltip_text = "%d patch anchor(s) didn't match the file. Click to ask Narcea for a corrected spec." % anchor_fails
	for entry in s:
		_append_system("  [color=#ff8888]\u2716 %s — %s[/color]\n" % [
			str(entry.get("path", "")), str(entry.get("reason", ""))])
	# Show lint issues inline; collect errors to auto-feed back to Narcea.
	var has_errors := false
	var lint_msg_parts: Array[String] = []
	for entry in result.get("lint", []):
		var path := str(entry.get("path", ""))
		var issues: Array = entry.get("issues", [])
		if issues.is_empty():
			continue
		_append_system("  [color=#ffcc66]\u26a0 %s — %d lint issue(s)[/color]\n" % [path, issues.size()])
		var file_lines: Array[String] = []
		for issue in issues:
			var sev := str(issue.get("severity", "")).to_lower()
			var msg := str(issue.get("message", ""))
			var ln := int(issue.get("line", 0))
			if sev == "error" or sev == "fatal":
				_append_system("    [color=#ff6666]error[/color] line %d: %s\n" % [ln, msg])
				has_errors = true
			else:
				_append_system("    [color=#ffcc66]warn[/color]  line %d: %s\n" % [ln, msg])
			file_lines.append("  line %d: %s" % [ln, msg])
		if not file_lines.is_empty():
			lint_msg_parts.append("%s:\n%s" % [path, "\n".join(file_lines)])
	# Auto-feed error lint back into Narcea so she self-corrects.
	if has_errors and not lint_msg_parts.is_empty():
		var follow_up := ("The following lint errors were found in the files you just wrote."
			+ " Please fix them:\n\n" + "\n\n".join(lint_msg_parts))
		_input.text = follow_up
		_on_send()


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
	_refresh_after_project_scaffold(result.get("written", []))


func _refresh_after_project_scaffold(written: Array) -> void:
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		for item in written:
			var path := str(item)
			if path.begins_with("res://") and FileAccess.file_exists(path):
				fs.call_deferred("update_file", path)
		if not fs.filesystem_changed.is_connected(_on_scaffold_filesystem_changed):
			fs.filesystem_changed.connect(_on_scaffold_filesystem_changed, CONNECT_ONE_SHOT)
		fs.call_deferred("scan")
	else:
		_refresh_project_explorer()


func _on_scaffold_filesystem_changed() -> void:
	_refresh_project_explorer()


func _refresh_project_explorer() -> void:
	if not Engine.is_editor_hint():
		return
	var base := EditorInterface.get_base_control()
	if base == null or not base.has_meta("visual_gasic_plugin_instance"):
		return
	var plugin = base.get_meta("visual_gasic_plugin_instance")
	if plugin == null or not is_instance_valid(plugin):
		return
	if "_project_explorer" in plugin:
		var explorer = plugin._project_explorer
		if explorer != null and is_instance_valid(explorer) and explorer.has_method("refresh"):
			explorer.call_deferred("refresh")


## Re-enable ▶ Run after reload when ai_projects/<name>/project.json exists.
func _restore_last_run_from_disk() -> void:
	var dir := DirAccess.open("res://ai_projects")
	if dir == null:
		return
	var best_mtime := 0
	var best_scene := ""
	var best_root := ""
	dir.list_dir_begin()
	var sub := dir.get_next()
	while sub != "":
		if dir.current_is_dir() and not sub.begins_with("."):
			var root := "res://ai_projects/%s/" % sub
			var manifest_path := root + "project.json"
			if FileAccess.file_exists(manifest_path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
				if typeof(parsed) == TYPE_DICTIONARY:
					var ms := str(parsed.get("main_scene", ""))
					if not ms.is_empty():
						var mtime := FileAccess.get_modified_time(manifest_path)
						if mtime >= best_mtime:
							best_mtime = mtime
							best_scene = ms
							best_root = root
		sub = dir.get_next()
	dir.list_dir_end()
	if best_scene.is_empty():
		return
	_last_run_scene = best_scene
	_last_project_root = best_root
	if is_instance_valid(_run_btn):
		_run_btn.disabled = false
		_run_btn.tooltip_text = "Run %s" % best_scene.get_file()


## Launch the last AI-built scene (or main_scene from the last project)
## in a child Godot process and stream its output into the chat.  Narcea
## sees the last N lines on her next prompt via the run-output context.
func _ensure_run_session() -> bool:
	if _run_session != null and is_instance_valid(_run_session):
		return true
	var rs := load("res://addons/visual_gasic/vg_ai_run_session.gd")
	if rs == null:
		return false
	_run_session = rs.new()
	add_child(_run_session)
	_run_session.output_line.connect(_on_run_line)
	_run_session.finished.connect(_on_run_finished)
	return true

func _on_run() -> void:
	if _last_run_scene.is_empty():
		_append_system("[color=#ff8888]Nothing to run — use Apply form or Make project first.[/color]\n")
		return
	if not _ensure_run_session():
		_append_system("[color=#ff8888]Run-session helper unavailable.[/color]\n")
		return
	if _run_session.is_running():
		_append_system("[color=#ffaa66]Already running \u2014 stop the current scene first.[/color]\n")
		return
	# Reset captured stderr at the start of every run so 🐛 Explain Last
	# Error reflects only the current invocation, not stale output.
	_run_error_lines.clear()
	if is_instance_valid(_summarize_errors_btn):
		_summarize_errors_btn.visible = false
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
	var is_error := stream != "stdout" or line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:")
	var color := "#ff8888" if is_error else "#cccccc"
	_append_system("[color=%s]%s %s[/color]\n" % [color, "│", line])
	# Phase 6b: buffer output lines when running inside an agent loop.
	if _agent_triggered_run and _agent_run_output_lines.size() < _AGENT_RUN_MAX_LINES:
		_agent_run_output_lines.append(("[stderr] " if stream == "stderr" else "") + line)
	# Auto-reflect: always capture stderr / error-tagged lines so the
	# 🐛 Explain Last Error button works after a manual ▶ Run, not just
	# during the autonomous agent loop.
	if is_error:
		_run_error_lines.append(line)
		if _run_error_lines.size() > 40:
			_run_error_lines = _run_error_lines.slice(_run_error_lines.size() - 40)
		# Inline a plain-English hint when our decoder recognises the line.
		var hint := _decode_run_error(line)
		if not hint.is_empty():
			_append_system("[color=#ffcc66]    ↳ %s[/color]\n" % hint)
		# Reveal the summarize-errors button once we've collected enough.
		if is_instance_valid(_summarize_errors_btn) and _run_error_lines.size() >= 20:
			_summarize_errors_btn.visible = true


func _on_run_finished(exit_code: int) -> void:
	if is_instance_valid(_run_btn):
		_run_btn.disabled = _last_run_scene.is_empty()
	if is_instance_valid(_run_stop_btn):
		_run_stop_btn.visible = false
	var color := "#aaffaa" if exit_code == 0 else "#ffaa66"
	_append_system("[color=%s]■ Scene finished (exit %d).[/color]\n" % [color, exit_code])
	# Auto-reflect (manual run): when a non-agent run fails and we
	# captured stderr lines, nudge the user to click 🐛 Explain Last Error
	# so Narcea can patch the bug.
	if not _agent_triggered_run and exit_code != 0 and not _run_error_lines.is_empty():
		_append_system("[color=#ffcc66]  Click \ud83d\udc1b Explain Last Error to ask %s to fix it.[/color]\n" % _persona_id.capitalize())
	# Phase 6b: if this run was triggered by the agent loop, ingest the
	# output and continue the agent so it can react to errors or confirm
	# success without user intervention.
	if _agent_triggered_run:
		_agent_triggered_run = false
		_continue_agent_after_run(exit_code)


## Phase 6b: called from _on_run_finished when the run was agent-triggered.
## Feeds the captured output back as the next agent hop prompt so Narcea
## can patch errors or confirm success without user intervention.
func _continue_agent_after_run(exit_code: int) -> void:
	if _agent_abort_requested:
		_agent_abort_requested = false
		_hide_abort_agent_btn()
		_output.append_text("[color=#888888]  (agent aborted by user)[/color]\n")
		_transcript_close("aborted")
		return
	if _agent_hops >= _max_agent_hops:
		_output.append_text("[color=#888888]  (agent hop limit reached — stopping)[/color]\n")
		_hide_abort_agent_btn()
		_transcript_close("hop_limit")
		return
	if _check_agent_budget_exceeded():
		_hide_abort_agent_btn()
		_transcript_close("budget_exceeded")
		return
	_agent_hops += 1
	var captured := _agent_run_output_lines.duplicate()
	_agent_run_output_lines.clear()
	var lines_text := "\n".join(captured) if not captured.is_empty() else "(no output)"
	_transcript_append({"type": "run_result", "hop": _agent_hops, "exit_code": exit_code,
			"output_lines": captured.size()})
	var follow_up: String
	if exit_code == 0:
		follow_up = (
			"The program ran successfully (exit 0). Output:\n%s\n\n"
			+ "If the task is complete, summarise what was done. "
			+ "Otherwise continue with the next step."
		) % lines_text
	else:
		follow_up = (
			"The program exited with an error (exit code %d). Output:\n%s\n\n"
			+ "Fix the error — apply the minimal change, save the file, "
			+ "and call play.run_main again to verify."
		) % [exit_code, lines_text]
	if not is_instance_valid(_input):
		return
	_input.text = follow_up
	_agent_continuation = true
	_on_send()


## Phase 6b: budget guard — returns true (and prints a notice) if the
## current agent session has hit either the token or wall-time ceiling.
func _check_agent_budget_exceeded() -> bool:
	if _max_agent_tokens > 0 and _agent_total_tokens >= _max_agent_tokens:
		_output.append_text(
			"[color=#ff8888]  (agent token budget (%d) exhausted — stopping)[/color]\n"
			% _max_agent_tokens
		)
		_hide_abort_agent_btn()
		return true
	if _max_agent_seconds > 0.0:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - _agent_start_time
		if elapsed >= _max_agent_seconds:
			_output.append_text(
				"[color=#ff8888]  (agent time limit (%.0fs) reached — stopping)[/color]\n"
				% _max_agent_seconds
			)
			_hide_abort_agent_btn()
			return true
	return false


## Phase 6b: show/hide the Abort agent button in the button column.
var _abort_agent_visible: bool = false
var _agent_abort_requested: bool = false

func _show_abort_agent_btn() -> void:
	if not is_instance_valid(_abort_agent_btn) or _abort_agent_visible:
		return
	_abort_agent_visible = true
	_abort_agent_btn.visible = true

func _hide_abort_agent_btn() -> void:
	if not is_instance_valid(_abort_agent_btn):
		return
	_abort_agent_visible = false
	_abort_agent_btn.visible = false
	_agent_abort_requested = false


## Phase 6b: user pressed the Abort button — halt the agent loop cleanly.
func _on_abort_agent() -> void:
	# Signal any in-flight run to stop.
	if _run_session != null and is_instance_valid(_run_session) and _run_session.is_running():
		_run_session.stop()
	# Mark abort so _continue_agent_after_run bails out when _on_run_finished fires.
	_agent_abort_requested = true
	# If no run is pending, clear loop state immediately.
	if not _agent_triggered_run:
		_agent_hops = 0
		_agent_total_tokens = 0
		_agent_run_output_lines.clear()
		_agent_continuation = false
		_hide_abort_agent_btn()
		_output.append_text("[color=#ffaa44]  🛑 Agent loop aborted.[/color]\n")
		_transcript_close("aborted")

# ---------------------------------------------------------------------------
# Phase 6e: NDJSON agent run transcript
# ---------------------------------------------------------------------------
# Writes one file per agent session under user://vg_agent_runs/<timestamp>.ndjson.
# Each line is a JSON object: {ts_ms:int, type:string, ...extra fields}.
# The harness at bench/ai_correctness/ can replay these to score agent runs.

func _transcript_open() -> void:
	if _agent_transcript_file != null:
		return  # Already open.
	DirAccess.make_dir_recursive_absolute("user://vg_agent_runs")
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "T")
	var path := "user://vg_agent_runs/%s.ndjson" % ts
	_agent_transcript_file = FileAccess.open(path, FileAccess.WRITE)
	if _agent_transcript_file:
		_transcript_append({
			"type": "session_start",
			"provider": _provider_id,
			"model": _current_model,
			"max_hops": _max_agent_hops,
		})


func _transcript_append(data: Dictionary) -> void:
	if _agent_transcript_file == null:
		return
	data["ts_ms"] = Time.get_ticks_msec()
	_agent_transcript_file.store_line(JSON.stringify(data))


## Log the completed assistant reply for Tier-B harness replay.
func _transcript_log_assistant_response(response_text: String) -> void:
	if response_text.is_empty():
		return
	_transcript_open()
	var entry := {
		"type": "assistant_response",
		"hop": _agent_hops,
		"response_len": response_text.length(),
		"response": response_text,
	}
	if _project_spec != null:
		var ps: Dictionary = _project_spec.extract_spec(response_text)
		entry["has_project_spec"] = not ps.is_empty()
	if _form_spec != null:
		var fs: Dictionary = _form_spec.extract_spec(response_text)
		entry["has_form_spec"] = not fs.is_empty()
	if _code_spec != null:
		var cs: Dictionary = _code_spec.extract_spec(response_text)
		entry["has_code_spec"] = not cs.is_empty()
	_transcript_append(entry)


func _transcript_log_tool_plan(plan: Dictionary) -> void:
	if plan.is_empty():
		return
	_transcript_open()
	_transcript_append({
		"type": "tool_plan",
		"hop": _agent_hops,
		"read_count": (plan.get("read_results", []) as Array).size(),
		"mutating_count": (plan.get("mutating", []) as Array).size(),
		"blocked_count": (plan.get("blocked", []) as Array).size(),
		"log_count": (plan.get("logs", []) as Array).size(),
	})


func _transcript_close(reason: String) -> void:
	if _agent_transcript_file == null:
		return
	_transcript_append({
		"type": "session_end",
		"reason": reason,
		"total_hops": _agent_hops,
		"total_tokens": _agent_total_tokens,
	})
	_agent_transcript_file.close()
	_agent_transcript_file = null


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
		return _base_system_prompt
	return prefix + narcea_ctx + _base_system_prompt

## Lazy-instantiate the Narcea context provider and ask it for a system-
## prompt block.  Cached on the panel so the tutorial walk only happens
## once per editor session.
var _narcea_provider = null
var _narcea_ctx_cache := ""
var _narcea_ctx_cache_ts: int = 0
var _narcea_ctx_cache_hint := ""

# Lazy-loaded AI tool dispatcher (vg_ai_tools.gd).  Lets the model drive
# the editor via ```vg-tool``` blocks — highlight, goto, insert, replace,
# save, write_file (through SafeWrite).
var _ai_tools = null

# Approval mode for AI-driven edits.  "ask" pops a confirmation dialog
# listing the pending mutations; "bypass" runs them immediately (an undo
# snapshot is still recorded either way).  Persisted to user:// so the
# choice survives across editor sessions.
const _APPROVAL_CFG_PATH := "user://vg_ai_approvals.cfg"
var _approval_mode: String = "ask"
var _approval_loaded: bool = false
# Phase 6f: agent mode — controls which personas can trigger the auto-loop.
# Values: "narcea_only" (default) | "all" | "always_ask" | "off"
var _agent_mode: String = "narcea_only"

func _load_approval_mode() -> void:
	if _approval_loaded:
		return
	_approval_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(_APPROVAL_CFG_PATH) == OK:
		var v: String = str(cfg.get_value("ai", "mode", "ask"))
		if v == "ask" or v == "bypass" or v == "read_only":
			_approval_mode = v
		# Phase 6b: agent budget settings.
		_max_agent_hops = int(cfg.get_value("ai", "max_agent_hops", _max_agent_hops))
		_max_agent_tokens = int(cfg.get_value("ai", "max_agent_tokens", _AGENT_MAX_TOKENS_DEFAULT))
		_max_agent_seconds = float(cfg.get_value("ai", "max_agent_seconds", _AGENT_MAX_SECONDS_DEFAULT))
		# Phase 6f: agent mode gating.
		var am: String = str(cfg.get_value("ai", "agent_mode", "narcea_only"))
		if am in ["narcea_only", "all", "always_ask", "off"]:
			_agent_mode = am
	_sync_approvals_dropdown()
	_sync_agent_mode_dropdown()

func _sync_approvals_dropdown() -> void:
	if not is_instance_valid(_approvals_dropdown):
		return
	var idx := 0
	match _approval_mode:
		"bypass": idx = 1
		"read_only": idx = 2
		_: idx = 0
	if _approvals_dropdown.selected != idx:
		_approvals_dropdown.selected = idx

func _save_approval_mode() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_APPROVAL_CFG_PATH)  # preserve existing keys
	cfg.set_value("ai", "mode", _approval_mode)
	cfg.set_value("ai", "agent_mode", _agent_mode)
	cfg.save(_APPROVAL_CFG_PATH)

func _sync_agent_mode_dropdown() -> void:
	if not is_instance_valid(_agent_mode_dropdown):
		return
	var idx := 0
	match _agent_mode:
		"all": idx = 1
		"always_ask": idx = 2
		"off": idx = 3
		_: idx = 0
	if _agent_mode_dropdown.selected != idx:
		_agent_mode_dropdown.selected = idx

func _on_agent_mode_selected(idx: int) -> void:
	match idx:
		0: _agent_mode = "narcea_only"
		1: _agent_mode = "all"
		2: _agent_mode = "always_ask"
		3: _agent_mode = "off"
		_: _agent_mode = "narcea_only"
	_save_approval_mode()
	_output.append_text("[color=#aaccff]  Agent mode → %s[/color]\n" % _agent_mode)

func _on_approvals_selected(idx: int) -> void:
	match idx:
		0: _approval_mode = "ask"
		1: _approval_mode = "bypass"
		2: _approval_mode = "read_only"
		_: _approval_mode = "ask"
	_save_approval_mode()
	_output.append_text("[color=#aaccff]  Approval mode \u2192 %s[/color]\n" % _approval_mode)

func _show_audit_log() -> void:
	var script := load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var sw = null if script == null else script.new()
	var text := ""
	if sw != null and sw.has_method("tail_audit"):
		text = String(sw.tail_audit(200))
	if text.strip_edges().is_empty():
		text = "(audit log is empty — no AI file ops yet)"
	var dlg := AcceptDialog.new()
	dlg.title = "AI Audit Log (last 200 lines)"
	dlg.min_size = Vector2(720, 480)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.scroll_active = true
	rt.selection_enabled = true
	rt.fit_content = false
	rt.custom_minimum_size = Vector2(700, 440)
	rt.text = text
	dlg.add_child(rt)
	dlg.confirmed.connect(func() -> void: dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	var host: Node = self
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base:
			host = base
	host.add_child(dlg)
	dlg.popup_centered()

func _ensure_ai_tools() -> bool:
	if _ai_tools != null:
		return true
	var tscript := load("res://addons/visual_gasic/vg_ai_tools.gd")
	if tscript == null:
		return false
	_ai_tools = tscript.new()
	# Tier-3 Phase 6a: let the model drive ▶ Run via play.run_main /
	# play.stop tools.  Output continues to stream through _on_run_line
	# and lands in the chat so the next agent hop can read it.
	if _ai_tools.has_method("set_run_handler"):
		_ai_tools.set_run_handler(Callable(self, "_ai_tool_run_handler"))
	return true


## Tier-3 Phase 6a run-loop adapter.  Bridges vg_ai_tools.gd's
## play.run_main / play.stop dispatches to the same _run_session helper
## the ▶ Run button uses.  Returns a one-line status string for the tool
## log.  Errors are reported as strings, never raised.
func _ai_tool_run_handler(tool_name: String, _args: Dictionary) -> String:
	match tool_name:
		"play.run_main":
			if _last_run_scene.is_empty():
				return "[play.run_main] nothing to run — build a form or project first"
			if not _ensure_run_session():
				return "[play.run_main] run-session helper unavailable"
			if _run_session.is_running():
				return "[play.run_main] already running — call play.stop first"
			var root_path := _last_project_root if not _last_project_root.is_empty() else "res://"
			if _run_session.start(_last_run_scene, root_path):
				if is_instance_valid(_run_btn):
					_run_btn.disabled = true
				if is_instance_valid(_run_stop_btn):
					_run_stop_btn.visible = true
				return "[play.run_main] launched %s" % _last_run_scene
			return "[play.run_main] failed to launch %s" % _last_run_scene
		"play.stop":
			if _run_session == null or not is_instance_valid(_run_session):
				return "[play.stop] no run session"
			if not _run_session.is_running():
				return "[play.stop] not currently running"
			_run_session.stop()
			return "[play.stop] stop signal sent"
		_:
			return "[%s] unhandled run-loop tool" % tool_name

func _dispatch_tool_calls(reply_text: String) -> void:
	if not _ensure_ai_tools():
		return
	_load_approval_mode()
	# Apply persona whitelist for this turn.
	var wl: Array = PERSONA_TOOL_WHITELIST.get(_persona_id, [])
	_ai_tools.set_whitelist(wl)

	var plan: Dictionary = _ai_tools.plan_response(reply_text)
	_transcript_log_tool_plan(plan)
	var ro_logs: Array = plan.get("logs", [])
	var muts: Array = plan.get("mutating", [])
	var blocked: Array = plan.get("blocked", [])
	var unfenced: bool = plan.get("unfenced_attempt", false)

	# In read-only mode, surface mutations as blocked instead of applying.
	if _approval_mode == "read_only" and not muts.is_empty():
		for m in muts:
			blocked.append("read-only mode: %s" % _describe_mutation(m).strip_edges())
		muts = []

	if not ro_logs.is_empty() or not muts.is_empty() or not blocked.is_empty():
		_output.append_text("\n[color=#888888][b]\u2192 Tool actions:[/b][/color]\n")
		for line in ro_logs:
			_output.append_text("[color=#aaaaaa]  %s[/color]\n" % _escape_bbcode(str(line)))
		for line in blocked:
			_output.append_text("[color=#cc6666]  \u2715 %s[/color]\n" % _escape_bbcode(str(line)))

	if unfenced and muts.is_empty() and ro_logs.is_empty() and blocked.is_empty():
		_output.append_text("\n[color=#ffaa44][b]\u26a0 Heads up:[/b][/color] [color=#ddbb88]It looks like you described a tool call but didn't wrap it in a [code]```vg-tool ... ```[/code] fenced block, so I couldn't run it.[/color] [color=#66aaff][url=ai_retry_format]\u21bb Ask the model to use the vg-tool format[/url][/color]\n")
		_ensure_meta_handler()
		return

	if not muts.is_empty():
		if _approval_mode == "bypass":
			_last_mutation_results = _apply_mutations(muts)
		else:
			_ask_apply_mutations(muts)
			return  # Action bar will be rendered after the dialog resolves.

	# Render action bar if anything ran (or there's an undo stack).
	if not ro_logs.is_empty() or not muts.is_empty() or (_ai_tools and _ai_tools.has_undo()):
		_render_action_bar()

	# Multi-turn agent loop: if the model only read things (no mutations,
	# no blockers), feed the results back and let it continue — capped at
	# _MAX_AGENT_HOPS hops to prevent runaway loops.
	_maybe_continue_agent_turn(plan)

func _maybe_continue_agent_turn(plan: Dictionary) -> void:
	if _suppress_agent_loop:
		_output.append_text("[color=#888888]  (project scaffold scheduled — agent loop paused for this turn)[/color]\n")
		_hide_abort_agent_btn()
		_transcript_close("scaffold_pause")
		return
	if _ai_tools == null:
		return
	var muts: Array = plan.get("mutating", [])
	var blocked: Array = plan.get("blocked", [])
	if not blocked.is_empty():
		_output.append_text("[color=#888888]  (%d tool call(s) blocked — stopping)[/color]\n" % blocked.size())
		_hide_abort_agent_btn()
		_transcript_close("blocked")
		return
	# Phase 6f: persona / agent-mode gating.
	var _loop_allowed := false
	match _agent_mode:
		"all":
			_loop_allowed = true
		"narcea_only":
			_loop_allowed = (_persona_id == "narcea")
		"always_ask", "off":
			_loop_allowed = false
	if not _loop_allowed:
		var reason := "agent_gated_off" if _agent_mode == "off" else "agent_gated_persona"
		if _agent_mode == "always_ask":
			reason = "agent_gated_always_ask"
		if not muts.is_empty() or not (plan.get("read_results", []) as Array).is_empty():
			var hint: String
			match _agent_mode:
				"narcea_only":
					hint = "(agent loop gated — switch to Narcea persona to enable auto-loop)"
				"always_ask":
					hint = "(agent loop paused — 'Always ask' mode: approve manually via the approval bar)"
				_:
					hint = "(agent loop disabled — enable in the 🤖 Agent mode dropdown)"
			_output.append_text("[color=#888888]  %s[/color]\n" % hint)
		_hide_abort_agent_btn()
		_transcript_close(reason)
		return
	# Phase 6b: if the model emitted a play.run_main call, defer the next
	# hop until _on_run_finished fires (which calls _continue_agent_after_run).
	# Any other mutation (code edit) stops the loop — the user reviews changes.
	if not muts.is_empty():
		var has_run_main := false
		for m in muts:
			if str(m.get("tool", "")) == "play.run_main":
				has_run_main = true
				break
		if has_run_main:
			# Arm the ingest path; _on_run_finished will trigger next hop.
			_agent_triggered_run = true
			_agent_run_output_lines.clear()
			_show_abort_agent_btn()
			return
		# If every mutation this hop failed with a recoverable error (e.g. a
		# buffer tool couldn't find/match its target file), feed the failure
		# back instead of silently stopping with nothing actually changed —
		# give the model a chance to notice and retry with write_file.
		var all_recoverable := not _last_mutation_results.is_empty()
		for r in _last_mutation_results:
			if not _is_recoverable_tool_failure(r):
				all_recoverable = false
				break
		if not all_recoverable:
			_hide_abort_agent_btn()
			_transcript_close("mutation_stop")
			return
		if _agent_hops >= _max_agent_hops:
			_output.append_text("[color=#888888]  (agent hop limit reached — stopping)[/color]\n")
			_hide_abort_agent_btn()
			_transcript_close("hop_limit")
			return
		if _check_agent_budget_exceeded():
			_hide_abort_agent_btn()
			_transcript_close("budget_exceeded")
			return
		_agent_hops += 1
		_show_abort_agent_btn()
		if not is_instance_valid(_input):
			return
		_input.text = ("Your last edit tool call failed:\n%s\n\n" +
			"The target file is probably not the one currently open in the editor. " +
			"Use write_file with an explicit path instead, then continue.") % "\n".join(_last_mutation_results)
		_agent_continuation = true
		_on_send()
		# Whether run or not, stop here — _continue_agent_after_run handles it.
		return
	var reads: Array = _ai_tools.get_read_results()
	if reads.is_empty():
		# The hop's only tool calls were cosmetic/navigational (goto_line,
		# highlight_lines, open_file) with nothing informative to feed back.
		# Without this marker the loop just stops dead with no explanation --
		# indistinguishable from a hang/crash. Reply normally to have Narcea
		# continue from here with a fresh hop budget.
		#
		# But if the model's OWN text says it still intends to act (e.g.
		# "Let me highlight the bad line, apply the fix, and save.") and it
		# only actually called a cosmetic tool this hop, the promised fix
		# never happens and the turn silently looks "done" with nothing
		# changed — confirmed via ai_projects/NarceaStressTest
		# (repair_crash_bug / repair_silent_logic_bug both stalled here:
		# Narcea called highlight_lines, described the fix, then stopped).
		# Nudge it to actually follow through instead, same as the
		# failed-mutation recovery path above.
		#
		# Gated on cosmetic_logs being non-empty: a hop with ZERO tool calls
		# at all (a plain text-only Q&A/explain reply) must never be nudged
		# here -- confirmed via ai_projects/NarceaStressTest's
		# explain_byref_advanced scenario, where the diagnosis-word heuristic
		# below (which matches "bug"/"fix"/"change" -- common words in any
		# technical explanation) spuriously fired on a pure explanation with
		# no tool calls at all and corrupted an otherwise-correct reply.
		var cosmetic_logs: Array = plan.get("logs", [])
		if (not cosmetic_logs.is_empty() and _agent_hops < _max_agent_hops
				and not _conversation_requests_no_edit()
				and _reply_suggests_unfinished_action(_accumulated_response)):
			_agent_hops += 1
			_show_abort_agent_btn()
			if not is_instance_valid(_input):
				return
			_input.text = ("You said you'd make a change but this turn only called a " +
				"cosmetic tool (highlight_lines/goto_line/open_file) with no actual edit. " +
				"Please follow through now: apply the fix with write_file (or the appropriate " +
				"edit tool) and save it.")
			_agent_continuation = true
			_on_send()
			return
		_output.append_text("[color=#888888]  (agent loop complete — nothing further to continue automatically; reply to keep going)[/color]\n")
		_hide_abort_agent_btn()
		_transcript_close("complete")
		return
	if _agent_hops >= _max_agent_hops:
		_output.append_text("[color=#888888]  (agent hop limit reached — stopping)[/color]\n")
		_hide_abort_agent_btn()
		_transcript_close("hop_limit")
		return
	if _check_agent_budget_exceeded():
		_hide_abort_agent_btn()
		_transcript_close("budget_exceeded")
		return
	_agent_hops += 1
	_show_abort_agent_btn()
	var summary := PackedStringArray()
	for r in reads:
		summary.append("- " + str(r))
	if not is_instance_valid(_input):
		return
	_input.text = "Tool results from your previous request:\n%s\n\nContinue with the next step or finish if the task is complete." % "\n".join(summary)
	_agent_continuation = true
	_on_send()

## True when a mutation-tool result string represents a recoverable failure
## (the target file wasn't open, or didn't match a supplied "path" safety
## check) rather than a real, applied edit -- see _check_active_path() in
## vg_ai_tools.gd. Used by _maybe_continue_agent_turn() to decide whether
## to retry instead of stopping the agent loop for user review.
func _is_recoverable_tool_failure(msg: String) -> bool:
	var low := msg.to_lower()
	return low.find("no code editor open") != -1 or low.find("target file mismatch") != -1

## True if the model's own reply text signals it still intends to make a
## change (e.g. "Let me fix this and save."), used to decide whether a
## cosmetic-only hop (highlight_lines/goto_line/open_file, nothing else)
## should be nudged to actually follow through instead of the agent loop
## silently treating the turn as "done". Deliberately simple/conservative:
## a false negative just means the existing "reply to keep going" hint
## still applies; a false positive costs one extra hop.
func _reply_suggests_unfinished_action(text: String) -> bool:
	var low := text.to_lower()
	var has_intent := (low.find("let me") != -1 or low.find("i'll") != -1
		or low.find("i will") != -1 or low.find("going to") != -1)
	# Also catches a plain diagnosis ("Found it. Bug: ... Fix: ...") that
	# never states explicit intent to continue but clearly identified a
	# fix without applying it -- observed in ai_projects/NarceaStressTest's
	# repair_silent_logic_bug scenario, where Claude explained the exact
	# correct fix formula in prose but only called highlight_lines.
	var has_diagnosis := (low.find("bug") != -1 or low.find("found it") != -1)
	if not (has_intent or has_diagnosis):
		return false
	for verb in ["fix", "save", "apply", "update", "write", "add", "correct", "change"]:
		if low.find(verb) != -1:
			return true
	return false

## True if the current conversation explicitly asked for a review/explanation
## only, with no edit expected (e.g. "you don't need to make any changes
## yet -- just tell me your suggestions"). Used to suppress the diagnosis-only
## branch of _reply_suggests_unfinished_action(), which otherwise repeatedly
## nudged a pure code-review request to "apply the fix" even though the user
## never asked for an edit -- confirmed via ai_projects/NarceaStressTest's
## code_review_suggestions scenario burning all 6 hops arguing with itself.
func _conversation_requests_no_edit() -> bool:
	var texts: Array = [_current_prompt]
	for turn in _conversation_history:
		if String(turn.get("role", "")) == "user":
			texts.append(turn.get("content", ""))
	for t in texts:
		var low := String(t).to_lower()
		if (low.find("don't need to make") != -1 or low.find("do not need to make") != -1
				or low.find("no need to make") != -1 or low.find("no changes yet") != -1
				or low.find("without making") != -1 or low.find("just tell me") != -1
				or low.find("review-only") != -1 or low.find("review only") != -1
				or low.find("no changes -- just") != -1):
			return true
	return false

func _describe_mutation(m: Dictionary) -> String:
	var t := str(m.get("tool", ""))
	match t:
		"insert_text":
			return "  \u2022 insert at line %d (%d chars)" % [int(m.get("line", 0)), str(m.get("text", "")).length()]
		"replace_range":
			return "  \u2022 replace lines %d-%d (%d chars new)" % [int(m.get("start_line", 0)), int(m.get("end_line", 0)), str(m.get("text", "")).length()]
		"replace_in_buffer":
			return "  \u2022 find/replace '%s' \u2192 '%s'" % [str(m.get("find", "")).left(40), str(m.get("replace", "")).left(40)]
		"set_buffer_text":
			return "  \u2022 overwrite entire buffer (%d bytes)" % str(m.get("text", "")).length()
		"save_file":
			return "  \u2022 save current file to disk"
		"write_file":
			return "  \u2022 write %s (%d bytes)" % [str(m.get("path", "")), str(m.get("contents", "")).length()]
		_:
			return "  \u2022 %s (unknown tool)" % t

func _ask_apply_mutations(muts: Array) -> void:
	# Custom AcceptDialog with per-mutation CheckBoxes + collapsible diff
	# previews — modeled after the MS Code "Apply / Discard / Apply some"
	# UX.  Each row: [x] description  (▸ click to expand diff)
	var dlg := AcceptDialog.new()
	dlg.title = "Apply AI edits?  (%d requested)" % muts.size()
	dlg.min_size = Vector2(720, 420)
	dlg.get_ok_button().text = "Apply selected"
	# Replace the default cancel with "Skip all" wording.
	dlg.add_cancel_button("Skip all")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dlg.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var checks: Array[CheckBox] = []
	for i in muts.size():
		var m: Dictionary = muts[i]
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(row)

		var hb := HBoxContainer.new()
		row.add_child(hb)

		var ck := CheckBox.new()
		ck.button_pressed = true
		ck.text = _describe_mutation(m).strip_edges()
		ck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(ck)
		checks.append(ck)

		var preview_text := ""
		if _ai_tools != null and _ai_tools.has_method("diff_preview"):
			preview_text = String(_ai_tools.diff_preview(m))
		if not preview_text.strip_edges().is_empty():
			var toggle := Button.new()
			toggle.text = "▸ diff"
			toggle.flat = true
			toggle.tooltip_text = "Show/hide diff preview"
			hb.add_child(toggle)

			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.selection_enabled = true
			rt.custom_minimum_size = Vector2(680, 0)
			rt.text = preview_text
			rt.visible = false
			row.add_child(rt)
			toggle.pressed.connect(func() -> void:
				rt.visible = not rt.visible
				toggle.text = "▾ diff" if rt.visible else "▸ diff"
			)

		var sep := HSeparator.new()
		row.add_child(sep)

	var bypass_ck := CheckBox.new()
	bypass_ck.text = "Bypass approvals from now on (re-enable in toolbar)"
	vb.add_child(bypass_ck)

	dlg.confirmed.connect(func() -> void:
		if bypass_ck.button_pressed:
			_approval_mode = "bypass"
			_save_approval_mode()
			_sync_approvals_dropdown()
		var selected: Array = []
		for i in checks.size():
			if checks[i].button_pressed:
				selected.append(muts[i])
		if selected.is_empty():
			_output.append_text("[color=#aa6666]  (no edits selected — skipped %d)[/color]\n" % muts.size())
		else:
			_apply_mutations(selected)
			var skipped := muts.size() - selected.size()
			if skipped > 0:
				_output.append_text("[color=#aa6666]  (skipped %d unchecked edit(s))[/color]\n" % skipped)
		_render_action_bar()
		dlg.queue_free()
	)
	dlg.canceled.connect(func() -> void:
		_output.append_text("[color=#aa6666]  (skipped %d AI edit(s))[/color]\n" % muts.size())
		_render_action_bar()
		dlg.queue_free()
	)
	const MUT_DLG_SIZE := Vector2i(720, 480)
	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(dlg, MUT_DLG_SIZE)
	else:
		add_child(dlg)
		dlg.popup_centered(MUT_DLG_SIZE)

func _apply_mutations(muts: Array) -> Array[String]:
	var written_tscn_paths: Array[String] = []
	var results: Array[String] = []
	for m in muts:
		var line: String = _ai_tools.execute_mutation_with_undo(m)
		results.append(line)
		_output.append_text("[color=#aaaaaa]  %s[/color]\n" % _escape_bbcode(line))
		# Track .tscn files written so we can auto-open them in Form Designer.
		if str(m.get("tool", "")) == "write_file":
			var wpath := str(m.get("path", ""))
			if wpath.ends_with(".tscn"):
				written_tscn_paths.append(wpath)
		# Track build_form so _refresh_action_buttons skips the duplicate apply.
		elif str(m.get("tool", "")) == "build_form":
			_build_form_ran_this_turn = true
	_render_action_bar()
	# Auto-open any form scenes the AI just wrote — deferred so the files are
	# fully flushed to disk before the Form Designer tries to load them.
	if not written_tscn_paths.is_empty():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			var plugin = base.get_meta("visual_gasic_plugin_instance")
			for tp in written_tscn_paths:
				if FileAccess.file_exists(tp) and plugin.has_method("open_form_in_designer"):
					call_deferred("_deferred_open_form", plugin, tp)
	return results

func _deferred_open_form(plugin, tscn_path: String) -> void:
	if is_instance_valid(plugin) and plugin.has_method("open_form_in_designer"):
		plugin.open_form_in_designer(tscn_path)

func _render_action_bar() -> void:
	var has_undo: bool = _ai_tools != null and bool(_ai_tools.has_undo())
	var n_undo: int = int(_ai_tools.undo_count()) if has_undo else 0
	var undo_link: String = "[color=#66aaff][url=ai_undo]\u21ba Undo last AI edit[/url][/color]" if has_undo else "[color=#555555]\u21ba Undo (nothing)[/color]"
	var undo_all_link := ""
	if n_undo > 1:
		undo_all_link = "   [color=#cc88ff][url=ai_undo_all]\u21ba\u21ba Undo all (%d)[/url][/color]" % n_undo
	var approvals_label := "Ask"
	match _approval_mode:
		"bypass": approvals_label = "Bypass"
		"read_only": approvals_label = "Read-only"
	_output.append_text("%s%s   [color=#66aa66][url=ai_keep]\u2713 Keep[/url][/color]   [color=#888888][url=ai_toggle_approvals]Approvals: %s[/url][/color]\n" % [undo_link, undo_all_link, approvals_label])
	_ensure_meta_handler()

func _ensure_meta_handler() -> void:
	if _output == null:
		return
	if not _output.meta_clicked.is_connected(_on_ai_meta_clicked):
		_output.meta_clicked.connect(_on_ai_meta_clicked)

func _on_ai_meta_clicked(meta: Variant) -> void:
	var m := str(meta)
	match m:
		"ai_undo":
			if _ai_tools != null and _ai_tools.has_undo():
				var msg: String = _ai_tools.undo_last()
				_output.append_text("[color=#aaccff]  %s[/color]\n" % _escape_bbcode(msg))
			else:
				_output.append_text("[color=#888888]  (nothing to undo)[/color]\n")
		"ai_undo_all":
			if _ai_tools != null and _ai_tools.has_undo():
				var msg: String = _ai_tools.undo_all()
				_output.append_text("[color=#aaccff]  %s[/color]\n" % _escape_bbcode(msg))
			else:
				_output.append_text("[color=#888888]  (nothing to undo)[/color]\n")
		"ai_keep":
			if _ai_tools != null:
				_ai_tools.clear_undo()
			_output.append_text("[color=#66aa66]  \u2713 Edits kept (undo history cleared).[/color]\n")
		"ai_toggle_approvals":
			# 3-way cycle: ask -> bypass -> read_only -> ask
			match _approval_mode:
				"ask": _approval_mode = "bypass"
				"bypass": _approval_mode = "read_only"
				_: _approval_mode = "ask"
			_save_approval_mode()
			_sync_approvals_dropdown()
			_output.append_text("[color=#aaccff]  Approval mode \u2192 %s[/color]\n" % _approval_mode)
		"ai_retry_format":
			if is_instance_valid(_input):
				_input.text = "Please re-emit your previous tool call wrapped in a ```vg-tool ... ``` fenced JSON block, exactly as the system prompt describes."
				_on_send()
		_:
			pass

func _narcea_context_block() -> String:
	const CACHE_TTL_MS := 30000  # 30 seconds
	# Use the current input as a relevance hint for the tutorial index.
	# When the hint changes the cache must be invalidated so a fresh
	# ranking reflects the new question.
	var query_hint := ""
	if is_instance_valid(_input):
		query_hint = _input.text
	if not _narcea_ctx_cache.is_empty() \
			and Time.get_ticks_msec() - _narcea_ctx_cache_ts < CACHE_TTL_MS \
			and query_hint == _narcea_ctx_cache_hint:
		return _narcea_ctx_cache
	if _narcea_provider == null:
		var script := load("res://addons/visual_gasic/vg_ai_narcea.gd")
		if script == null:
			return ""
		_narcea_provider = script.new()
	if _narcea_provider.has_method("set_query_hint"):
		_narcea_provider.set_query_hint(query_hint)
	var plugin = null
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base and base.has_meta("visual_gasic_plugin_instance"):
			plugin = base.get_meta("visual_gasic_plugin_instance")
	var block: String = _narcea_provider.build_context_block(plugin)
	# Sandwich the block in clear delimiters so the model can find it.
	var result := "\n--- BEGIN NARCEA CONTEXT ---\n" + block + "\n--- END NARCEA CONTEXT ---\n\n"
	_narcea_ctx_cache = result
	_narcea_ctx_cache_ts = Time.get_ticks_msec()
	_narcea_ctx_cache_hint = query_hint
	return result

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
			var val = entry[k]
			if str(k) == "prefix" and typeof(val) == TYPE_STRING:
				val = val.left(2000)
			base[str(k)] = val
		_personas[pid] = base
		if not _persona_order.has(pid):
			_persona_order.append(pid)

func _save_persona() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("persona", "id", _persona_id)
	cfg.save(PERSONA_CFG_PATH)

