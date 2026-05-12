@tool
extends RefCounted
## AI tool-call dispatcher.
##
## Lets any AI persona (Narcea, Bob, Skippy, …) drive the VG editor by
## emitting fenced ```vg-tool``` blocks containing a single JSON object.
## Each block is one tool call.  After streaming completes, vg_ai_help.gd
## hands the full reply text to dispatch_response(), which extracts every
## block, executes each, and returns a list of human-readable result lines
## that get printed back into the chat as a "tool log".
##
## This is the AI's equivalent of the buttons / keystrokes a human uses
## in the embedded code editor: read the buffer, highlight lines, jump
## the caret, insert/replace ranges, save, or write whole files via the
## existing vg_ai_safe_write chokepoint.
##
## Tool block format:
##
##     ```vg-tool
##     {"tool": "highlight_lines", "lines": [12,13,17], "color": "yellow"}
##     ```
##
## All line numbers in arguments are 1-based (what the user sees in the
## gutter).  CodeEdit's API is 0-based; conversion happens here.
##
## Supported tools (MVP):
##   highlight_lines  {lines:[int], color?:str, duration_sec?:float}
##   clear_highlights {}
##   goto_line        {line:int, column?:int}
##   open_file        {path:str}
##   insert_text      {line:int, text:str}            # insert BEFORE 1-based line
##   replace_range    {start_line:int, end_line:int, text:str}  # inclusive
##   replace_in_buffer{find:str, replace:str, all?:bool}
##   set_buffer_text  {text:str}                      # full-buffer replace
##   save_file        {}
##   write_file       {path:str, contents:str}        # routed through SafeWrite
##   read_file        {path:str, max_lines?:int}      # echoes contents to chat
##   list_dir         {path:str, recursive?:bool, max_entries?:int}
##   find_in_files    {pattern:str, path?:str, regex?:bool, max_hits?:int}
##   vb6_canonicalize {path?:str, dry_run?:bool}      # rewrite Godot type
##                                                    # names to VB6 dialect
##                                                    # in .vg files (e.g.
##                                                    # `As LineEdit` →
##                                                    # `As TextBox`).

const HIGHLIGHT_DURATION_DEFAULT := 8.0
# NOTE: declared as `var` (not `const`) because Color(...) is not a
# constant expression in GDScript module scope.
static var HIGHLIGHT_COLORS := {
	"yellow": Color(0.95, 0.85, 0.20, 0.30),
	"green":  Color(0.30, 0.90, 0.40, 0.30),
	"red":    Color(0.95, 0.30, 0.30, 0.30),
	"blue":   Color(0.35, 0.55, 0.95, 0.30),
	"orange": Color(0.95, 0.55, 0.20, 0.30),
}

const READ_DEFAULT_LINES := 200
const FIND_MAX_HITS_DEFAULT := 50
const LISTDIR_MAX_ENTRIES_DEFAULT := 200
const SNAPSHOT_COMPRESS_THRESHOLD := 4096   # bytes — buffers bigger than this are zlib'd in undo

# Tool names whose execution is purely visual / read-only — safe to auto-run
# even when the user has approvals enabled.
const READ_ONLY_TOOLS := [
	"highlight_lines", "clear_highlights", "goto_line",
	"open_file", "read_file", "list_dir", "find_in_files", "_invalid",
]

# All known mutating tool names.  Anything not in here AND not in
# READ_ONLY_TOOLS is treated as "unknown" (still asks for approval).
const MUTATING_TOOLS := [
	"insert_text", "replace_range", "replace_in_buffer",
	"set_buffer_text", "save_file", "write_file",
	"vb6_canonicalize",
	# Tier-3 agent run-loop tools.  Mutating-classified so they go
	# through the approval bar by default.
	"play.run_main", "play.stop",
]

const UNDO_MAX := 32

# Lazy-loaded SafeWrite singleton instance.
var _safe = null

# Tier-3 run-loop handler.  vg_ai_help.gd registers a Callable here so
# the play.run_main / play.stop tools can drive the same run session the
# "▶ Run" button uses.  Signature: f(tool_name: String, args: Dictionary)
# -> String.  When unset, the tools return a clear error instead of
# crashing.
var _run_handler: Callable = Callable()

# Track painted lines per CodeEdit instance so clear_highlights() can wipe
# only what we painted (won't clobber the editor's own current-line bg).
var _painted := {}   # CodeEdit -> Array[int]

# Undo stack — each entry is one of:
#   {kind:"buffer", prev:<compressed-or-string>,        label:String}
#   {kind:"file",   path:String, prev:<compressed-or-string>,
#    existed:bool,                                       label:String}
# `prev` is a Dictionary {text:String} for small payloads or
# {compressed:PackedByteArray, size:int} for large ones.
var _undo_stack: Array = []

# Per-persona whitelist of tool names.  Empty = allow everything.  Set
# from vg_ai_help.gd before plan_response/dispatch_streaming.
var _whitelist: Array = []

# Per-turn budget — counts mutating calls *and* unknown tools.  -1 disables.
var _mutation_budget: int = -1
var _mutations_used_this_turn: int = 0

# Stash of read_file / list_dir / find_in_files results from the current
# reply.  vg_ai_help.gd consumes this to build a follow-up message in the
# multi-turn agent loop (so the model can act on what it just read).
var _read_results_buffer: Array = []  # Array[Dictionary]: {tool, args, output}


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

## Scan a full AI reply for vg-tool blocks, execute each, and return the
## human-readable result lines (one per call, ready to print).
func dispatch_response(text: String) -> Array:
	var calls := extract_tool_calls(text)
	var out: Array = []
	for c in calls:
		out.append(execute_tool(c))
	return out


## High-level planner used by vg_ai_help.gd's approval flow.
## Splits a reply's tool calls into:
##   * read_only — already executed, see "logs"
##   * mutating  — pending; caller decides whether to confirm + apply
## Also detects when the model *described* a tool call without wrapping it
## in a vg-tool fence so the panel can nudge the model.
##
## Returned dict shape:
##   {
##     "read_only":         Array[Dictionary],   # the parsed calls
##     "mutating":          Array[Dictionary],   # the parsed calls
##     "logs":              Array[String],       # one per read-only call
##     "unfenced_attempt":  bool,                # show "use the vg-tool format" nudge
##   }
func plan_response(text: String) -> Dictionary:
	var plan: Dictionary = {
		"read_only":        [],
		"mutating":         [],
		"logs":             [],
		"unfenced_attempt": false,
		"blocked":          [],   # calls dropped by whitelist or budget
	}
	_read_results_buffer.clear()
	_mutations_used_this_turn = 0
	var calls := extract_tool_calls(text)
	if calls.is_empty():
		plan["unfenced_attempt"] = _looks_like_unfenced_tool_call(text)
		return plan
	for c in calls:
		var tname := str(c.get("tool", "")).strip_edges().to_lower()
		# Persona whitelist gate
		if not _whitelist.is_empty() and not _whitelist.has(tname):
			plan["blocked"].append({"call": c, "reason": "persona disallows '%s'" % tname})
			continue
		if READ_ONLY_TOOLS.has(tname):
			var msg: String = execute_tool(c)
			plan["read_only"].append(c)
			plan["logs"].append(msg)
			# Capture context-bearing reads so vg_ai_help.gd can feed
			# them back into a follow-up turn (multi-turn agent loop).
			if tname == "read_file" or tname == "list_dir" or tname == "find_in_files":
				_read_results_buffer.append({"tool": tname, "args": c, "output": msg})
		else:
			# Budget check — refuse mutations past the configured limit.
			if _mutation_budget >= 0 and _mutations_used_this_turn >= _mutation_budget:
				plan["blocked"].append({"call": c, "reason": "tool budget %d exhausted" % _mutation_budget})
				continue
			_mutations_used_this_turn += 1
			plan["mutating"].append(c)
	return plan


# ---------------------------------------------------------------------------
# Whitelist / budget configuration (called by vg_ai_help.gd per turn)
# ---------------------------------------------------------------------------

func set_whitelist(names: Array) -> void:
	_whitelist = []
	for n in names:
		_whitelist.append(str(n).to_lower())

func clear_whitelist() -> void:
	_whitelist.clear()

func set_budget(n: int) -> void:
	_mutation_budget = n

func get_read_results() -> Array:
	return _read_results_buffer.duplicate()


## Heuristic — did the model emit JSON that LOOKS like one of our tool
## calls but never wrap it in a `vg-tool` fence?  Used to nudge smaller
## local models that paraphrase the protocol instead of using it.
func _looks_like_unfenced_tool_call(text: String) -> bool:
	if text.find("```vg-tool") >= 0:
		return false  # they did try; extract_tool_calls just rejected the JSON
	var lower := text.to_lower()
	# Must contain a "tool":"..." key — that's our protocol's tell.
	if lower.find("\"tool\"") < 0 and lower.find("'tool'") < 0:
		return false
	# AND must mention at least one known tool name in close proximity.
	for n in READ_ONLY_TOOLS + MUTATING_TOOLS:
		if n.begins_with("_"):
			continue
		if lower.find(n) >= 0:
			return true
	return false


## Returns true iff the reply contains at least one parseable vg-tool block.
func has_tool_calls(text: String) -> bool:
	return not extract_tool_calls(text).is_empty()


## Execute a mutating call AND record an undo snapshot first.  Used by
## vg_ai_help.gd after the user approves (or in bypass mode).
func execute_mutation_with_undo(d: Dictionary) -> String:
	var snap := _snapshot_for(d)
	var msg := execute_tool(d)
	if not snap.is_empty():
		_undo_stack.append(snap)
		while _undo_stack.size() > UNDO_MAX:
			_undo_stack.pop_front()
	return msg


## Pop the most recent undo snapshot and revert.  Returns a status line.
func undo_last() -> String:
	if _undo_stack.is_empty():
		return "[undo] nothing to undo"
	var s: Dictionary = _undo_stack.pop_back()
	return _apply_snapshot(s)


## Pop and revert ALL queued undo snapshots, newest first.  Returns a
## summary status line.
func undo_all() -> String:
	if _undo_stack.is_empty():
		return "[undo-all] nothing to undo"
	var n := _undo_stack.size()
	while not _undo_stack.is_empty():
		var s: Dictionary = _undo_stack.pop_back()
		_apply_snapshot(s)
	return "[undo-all] reverted %d edit(s)" % n


func _apply_snapshot(s: Dictionary) -> String:
	var label := str(s.get("label", "edit"))
	match str(s.get("kind", "")):
		"buffer":
			var ce := _get_code_edit()
			if ce == null:
				return "[undo] no code editor"
			ce.text = _restore_payload(s.get("prev", {}))
			_mark_dirty()
			return "[undo] reverted %s" % label
		"file":
			var path := str(s.get("path", ""))
			if path.is_empty():
				return "[undo] no path"
			var safe = _get_safe()
			if safe == null:
				return "[undo] safe-write unavailable"
			if bool(s.get("existed", true)):
				var res: Array = safe.write(path, _restore_payload(s.get("prev", {})))
				return "[undo] %s -> %s" % [label, str(res[1])]
			# File didn't exist before; remove it.
			var abs := path
			if path.begins_with("res://") or path.begins_with("user://"):
				abs = ProjectSettings.globalize_path(path)
			var derr := DirAccess.remove_absolute(abs)
			if derr == OK:
				return "[undo] removed %s" % path
			return "[undo] could not remove %s (err %d)" % [path, derr]
	return "[undo] unknown snapshot kind"


func has_undo() -> bool:
	return not _undo_stack.is_empty()


func undo_count() -> int:
	return _undo_stack.size()


func clear_undo() -> void:
	_undo_stack.clear()


# --- Snapshot payload (de)compression --------------------------------------
# Buffers larger than SNAPSHOT_COMPRESS_THRESHOLD get FastLZ-compressed in
# the undo stack to keep memory footprint sane on long sessions.

func _store_payload(s: String) -> Dictionary:
	var b := s.to_utf8_buffer()
	if b.size() <= SNAPSHOT_COMPRESS_THRESHOLD:
		return {"text": s}
	var c := b.compress(FileAccess.COMPRESSION_FASTLZ)
	return {"compressed": c, "size": b.size()}


func _restore_payload(p) -> String:
	if typeof(p) != TYPE_DICTIONARY:
		return ""
	if p.has("text"):
		return str(p.get("text", ""))
	if p.has("compressed"):
		var b: PackedByteArray = p.get("compressed")
		var orig: int = int(p.get("size", 0))
		var d := b.decompress(orig, FileAccess.COMPRESSION_FASTLZ)
		return d.get_string_from_utf8()
	return ""


func _snapshot_for(d: Dictionary) -> Dictionary:
	var tname := str(d.get("tool", "")).strip_edges().to_lower()
	match tname:
		"insert_text", "replace_range", "replace_in_buffer", "set_buffer_text":
			var ce := _get_code_edit()
			if ce == null:
				return {}
			return {"kind": "buffer", "prev": _store_payload(ce.text), "label": tname}
		"save_file":
			var ece := _get_embedded_editor()
			if ece == null:
				return {}
			var path := ""
			if ece.has_method("get_file_path"):
				path = ece.get_file_path()
			if path.is_empty():
				return {}
			var prev := ""
			var existed := FileAccess.file_exists(path)
			if existed:
				var f := FileAccess.open(path, FileAccess.READ)
				if f:
					prev = f.get_as_text()
					f.close()
			return {
				"kind": "file", "path": path,
				"prev": _store_payload(prev),
				"existed": existed, "label": "save_file"
			}
		"write_file":
			var p := str(d.get("path", ""))
			if p.is_empty():
				return {}
			var prev2 := ""
			var existed2 := FileAccess.file_exists(p)
			if existed2:
				var f2 := FileAccess.open(p, FileAccess.READ)
				if f2:
					prev2 = f2.get_as_text()
					f2.close()
			return {
				"kind": "file", "path": p,
				"prev": _store_payload(prev2),
				"existed": existed2, "label": "write_file %s" % p
			}
	return {}


# ---------------------------------------------------------------------------
# Diff preview (used by the approval dialog) and streaming dispatch
# ---------------------------------------------------------------------------

## Returns a plain-text unified-style preview comparing the current state
## against what `d` would produce.  Used by the approval dialog to show
## the user *exactly* what's about to change.  Best-effort and lossy —
## don't rely on it for round-tripping.
func diff_preview(d: Dictionary) -> String:
	var tname := str(d.get("tool", "")).strip_edges().to_lower()
	match tname:
		"insert_text":
			var line := int(d.get("line", 0))
			var txt := str(d.get("text", ""))
			return "@@ insert before line %d @@\n+ %s" % [line, txt.replace("\n", "\n+ ")]
		"replace_range":
			var sl := int(d.get("start_line", 0))
			var el := int(d.get("end_line", 0))
			var ce := _get_code_edit()
			var before := ""
			if ce != null:
				var lines := ce.text.split("\n")
				var s := maxi(0, sl - 1)
				var e := mini(lines.size() - 1, el - 1)
				if s <= e:
					before = "\n".join(lines.slice(s, e + 1))
			var after := str(d.get("text", ""))
			return "@@ replace lines %d-%d @@\n- %s\n+ %s" % [sl, el,
				before.replace("\n", "\n- "), after.replace("\n", "\n+ ")]
		"replace_in_buffer":
			return "@@ replace_in_buffer @@\n- %s\n+ %s" % [
				str(d.get("find", "")), str(d.get("replace", ""))]
		"set_buffer_text":
			var ce2 := _get_code_edit()
			var oldsz := 0
			if ce2 != null:
				oldsz = ce2.text.length()
			return "@@ overwrite buffer @@\n- (%d bytes existing)\n+ %s" % [
				oldsz, str(d.get("text", "")).left(400) + ("\n…" if str(d.get("text", "")).length() > 400 else "")]
		"save_file":
			return "@@ save_file @@\n(flush current buffer to disk)"
		"write_file":
			var path := str(d.get("path", ""))
			var existed := FileAccess.file_exists(path)
			var contents := str(d.get("contents", ""))
			var head := "@@ write %s (%s) @@\n" % [path, "modify" if existed else "CREATE"]
			return head + "+ " + contents.left(800).replace("\n", "\n+ ") + (
				"\n…(truncated)" if contents.length() > 800 else "")
	return "(no preview for %s)" % tname


## Streaming dispatch — extract tool calls from the partial text after the
## given watermark, run any READ-ONLY ones immediately, and return the new
## watermark plus the read-only logs.  Mutating calls are deferred to the
## final plan_response() so the user still sees a single approval batch.
##
## Returned dict: {"watermark": int, "logs": Array[String]}
func dispatch_streaming(partial: String, last_close: int) -> Dictionary:
	var out: Dictionary = {"watermark": last_close, "logs": []}
	var search_from := last_close
	while true:
		var open_i := partial.find("```vg-tool", search_from)
		if open_i < 0:
			break
		var body_start := open_i + len("```vg-tool")
		var nl := partial.find("\n", body_start)
		if nl < 0:
			break
		body_start = nl + 1
		var close_i := partial.find("```", body_start)
		if close_i < 0:
			break  # block not closed yet — wait for more tokens
		var body := partial.substr(body_start, close_i - body_start).strip_edges()
		search_from = close_i + 3
		out["watermark"] = search_from
		if body.is_empty():
			continue
		var parsed = JSON.parse_string(body)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var tname := str(parsed.get("tool", "")).strip_edges().to_lower()
		# Skip whitelist-blocked or non-read-only calls; they'll be
		# handled in the final plan.
		if not _whitelist.is_empty() and not _whitelist.has(tname):
			continue
		if not READ_ONLY_TOOLS.has(tname):
			continue
		out["logs"].append(execute_tool(parsed))
	return out



## Pull every ```vg-tool ... ``` JSON block out of a reply.  Tolerant: bad
## JSON is skipped (logged to the dispatch log instead of crashing).
func extract_tool_calls(text: String) -> Array:
	var calls: Array = []
	var search_from := 0
	while true:
		var open_i := text.find("```vg-tool", search_from)
		if open_i < 0:
			break
		# Skip past the opening fence + optional newline.
		var body_start := open_i + len("```vg-tool")
		# Allow trailing junk on the fence line; jump to next \n.
		var nl := text.find("\n", body_start)
		if nl < 0:
			break
		body_start = nl + 1
		var close_i := text.find("```", body_start)
		if close_i < 0:
			break
		var body := text.substr(body_start, close_i - body_start).strip_edges()
		search_from = close_i + 3
		if body.is_empty():
			continue
		var parsed = JSON.parse_string(body)
		if typeof(parsed) != TYPE_DICTIONARY:
			calls.append({"tool": "_invalid", "_raw": body})
			continue
		calls.append(parsed)
	return calls


## Execute one parsed tool call dict.  Returns a one-line status string.
func execute_tool(d: Dictionary) -> String:
	var tool_name := str(d.get("tool", "")).strip_edges().to_lower()
	if tool_name.is_empty():
		return "[tool] (skipped: missing 'tool' key)"
	match tool_name:
		"_invalid":
			return "[tool] (skipped: malformed JSON in vg-tool block)"
		"highlight_lines":
			return _do_highlight_lines(d)
		"clear_highlights":
			return _do_clear_highlights()
		"goto_line":
			return _do_goto_line(d)
		"open_file":
			return _do_open_file(d)
		"insert_text":
			return _do_insert_text(d)
		"replace_range":
			return _do_replace_range(d)
		"replace_in_buffer":
			return _do_replace_in_buffer(d)
		"set_buffer_text":
			return _do_set_buffer_text(d)
		"save_file":
			return _do_save_file()
		"write_file":
			return _do_write_file(d)
		"read_file":
			return _do_read_file(d)
		"list_dir":
			return _do_list_dir(d)
		"find_in_files":
			return _do_find_in_files(d)
		"vb6_canonicalize":
			return _do_vb6_canonicalize(d)
		"play.run_main":
			return _do_play_run_main(d)
		"play.stop":
			return _do_play_stop(d)
		_:
			return "[tool] unknown tool: %s" % tool_name


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

func _do_highlight_lines(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[highlight_lines] no code editor open"
	var lines_v = d.get("lines", [])
	if typeof(lines_v) != TYPE_ARRAY or lines_v.is_empty():
		return "[highlight_lines] missing or empty 'lines' array"
	var color_name := str(d.get("color", "yellow")).to_lower()
	var color: Color = HIGHLIGHT_COLORS.get(color_name, HIGHLIGHT_COLORS["yellow"])
	var dur := float(d.get("duration_sec", HIGHLIGHT_DURATION_DEFAULT))
	var painted: Array = _painted.get(ce, [])
	var count := 0
	var line_count := ce.get_line_count()
	_ensure_ai_gutter(ce)
	var gutter_idx := _ai_gutter_index(ce)
	# Pip color = full alpha version of the bg tint, for visibility.
	var pip := Color(color.r, color.g, color.b, 0.95)
	for ln in lines_v:
		var idx := int(ln) - 1
		if idx < 0 or idx >= line_count:
			continue
		ce.set_line_background_color(idx, color)
		if gutter_idx >= 0:
			var img := _make_pip_icon(pip)
			ce.set_line_gutter_icon(idx, gutter_idx, img)
		if not painted.has(idx):
			painted.append(idx)
		count += 1
	_painted[ce] = painted
	# Auto-clear after duration (best-effort; no Timer node on a RefCounted,
	# so use a SceneTreeTimer attached to the editor).
	if dur > 0.0 and ce.is_inside_tree():
		var tree := ce.get_tree()
		if tree:
			var t := tree.create_timer(dur)
			t.timeout.connect(_clear_specific.bind(ce, painted.duplicate()))
	# Scroll to the first highlighted line so the user actually sees it.
	if count > 0:
		ce.set_caret_line(int(lines_v[0]) - 1)
		if ce.has_method("center_viewport_to_caret"):
			ce.center_viewport_to_caret()
	return "[highlight_lines] painted %d line(s) %s for %.1fs" % [count, color_name, dur]


func _do_clear_highlights() -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[clear_highlights] no code editor open"
	var painted: Array = _painted.get(ce, [])
	var gutter_idx := _ai_gutter_index(ce)
	for idx in painted:
		ce.set_line_background_color(int(idx), Color(0, 0, 0, 0))
		if gutter_idx >= 0:
			ce.set_line_gutter_icon(int(idx), gutter_idx, null)
	_painted[ce] = []
	return "[clear_highlights] cleared %d line(s)" % painted.size()


func _clear_specific(ce: CodeEdit, lines: Array) -> void:
	if not is_instance_valid(ce):
		return
	var gutter_idx := _ai_gutter_index(ce)
	for idx in lines:
		ce.set_line_background_color(int(idx), Color(0, 0, 0, 0))
		if gutter_idx >= 0:
			ce.set_line_gutter_icon(int(idx), gutter_idx, null)
	# Drop these from our painted set so a later clear_highlights doesn't
	# look like it cleared more than it did.
	var still: Array = _painted.get(ce, [])
	var keep: Array = []
	for idx in still:
		if not lines.has(idx):
			keep.append(idx)
	_painted[ce] = keep


# --- AI highlight gutter ----------------------------------------------------
# We add (or reuse) a 12px-wide gutter named "_ai" to draw colored pips
# next to every AI-highlighted line.  This makes highlights visible when
# the user has scrolled away from the painted region.
const AI_GUTTER_NAME := "_ai"

func _ensure_ai_gutter(ce: CodeEdit) -> void:
	if _ai_gutter_index(ce) >= 0:
		return
	var idx := ce.get_gutter_count()
	ce.add_gutter(idx)
	ce.set_gutter_name(idx, AI_GUTTER_NAME)
	ce.set_gutter_type(idx, TextEdit.GUTTER_TYPE_ICON)
	ce.set_gutter_width(idx, 12)
	ce.set_gutter_clickable(idx, false)
	ce.set_gutter_overwritable(idx, false)


func _ai_gutter_index(ce: CodeEdit) -> int:
	for i in range(ce.get_gutter_count()):
		if ce.get_gutter_name(i) == AI_GUTTER_NAME:
			return i
	return -1


# Cache rendered pip icons keyed by color string so we don't re-allocate
# an Image for every highlighted line.
static var _PIP_CACHE: Dictionary = {}

func _make_pip_icon(c: Color) -> ImageTexture:
	var key := "%d_%d_%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
	if _PIP_CACHE.has(key):
		return _PIP_CACHE[key]
	var img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Rounded vertical bar.
	for y in range(2, 10):
		for x in range(2, 6):
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_PIP_CACHE[key] = tex
	return tex


func _do_goto_line(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[goto_line] no code editor open"
	var line := int(d.get("line", 0)) - 1
	if line < 0:
		line = 0
	var lc := ce.get_line_count()
	if line >= lc:
		line = lc - 1
	var col := int(d.get("column", 0))
	ce.set_caret_line(line)
	ce.set_caret_column(col)
	if ce.has_method("center_viewport_to_caret"):
		ce.center_viewport_to_caret()
	ce.grab_focus()
	return "[goto_line] caret -> line %d" % (line + 1)


func _do_open_file(d: Dictionary) -> String:
	var path := str(d.get("path", "")).strip_edges()
	if path.is_empty():
		return "[open_file] missing 'path'"
	var ece = _get_embedded_editor()
	if ece == null or not ece.has_method("load_file"):
		return "[open_file] embedded code editor not available"
	# Safety: respect the SafeWrite root for read access too.
	var safe = _get_safe()
	if safe != null:
		var ok: Array = safe.is_safe(path)
		if not ok[0]:
			return "[open_file] refused: %s" % str(ok[1])
	ece.load_file(path)
	return "[open_file] loaded %s" % path


func _do_insert_text(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[insert_text] no code editor open"
	var line := int(d.get("line", 0)) - 1
	var txt := str(d.get("text", ""))
	if line < 0:
		line = 0
	var lc := ce.get_line_count()
	# Insert BEFORE the given line.  Use full-buffer rebuild for robustness.
	var lines := ce.text.split("\n")
	var insert_at := mini(line, lines.size())
	# Ensure the inserted block is line-terminated.
	if not txt.ends_with("\n"):
		txt += "\n"
	var head := "\n".join(lines.slice(0, insert_at))
	var tail := "\n".join(lines.slice(insert_at))
	var sep := "\n" if not head.is_empty() else ""
	ce.text = head + sep + txt + tail
	_mark_dirty()
	var inserted_count := txt.count("\n")
	return "[insert_text] inserted %d line(s) before line %d" % [inserted_count, line + 1]


func _do_replace_range(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[replace_range] no code editor open"
	var sl := int(d.get("start_line", 0)) - 1
	var el := int(d.get("end_line", 0)) - 1
	if sl < 0 or el < sl:
		return "[replace_range] invalid line range"
	var txt := str(d.get("text", ""))
	var lines := ce.text.split("\n")
	var n := lines.size()
	if sl >= n:
		return "[replace_range] start_line past end of buffer"
	el = mini(el, n - 1)
	var head := "\n".join(lines.slice(0, sl))
	var tail := "\n".join(lines.slice(el + 1))
	var middle: String = txt
	if not middle.is_empty() and not middle.ends_with("\n"):
		middle += "\n"
	var head_sep := "\n" if not head.is_empty() else ""
	var tail_sep := "" if middle.ends_with("\n") or tail.is_empty() else "\n"
	ce.text = head + head_sep + middle + tail_sep + tail
	_mark_dirty()
	return "[replace_range] replaced lines %d-%d" % [sl + 1, el + 1]


func _do_replace_in_buffer(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[replace_in_buffer] no code editor open"
	var find_s := str(d.get("find", ""))
	if find_s.is_empty():
		return "[replace_in_buffer] empty 'find'"
	var rep_s := str(d.get("replace", ""))
	var all := bool(d.get("all", true))
	var src := ce.text
	if not all:
		var i := src.find(find_s)
		if i < 0:
			return "[replace_in_buffer] no match"
		ce.text = src.substr(0, i) + rep_s + src.substr(i + find_s.length())
		_mark_dirty()
		return "[replace_in_buffer] replaced 1 occurrence"
	var count := src.count(find_s)
	if count == 0:
		return "[replace_in_buffer] no match"
	ce.text = src.replace(find_s, rep_s)
	_mark_dirty()
	return "[replace_in_buffer] replaced %d occurrence(s)" % count


func _do_set_buffer_text(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[set_buffer_text] no code editor open"
	if not d.has("text"):
		return "[set_buffer_text] missing 'text'"
	ce.text = str(d.get("text"))
	_mark_dirty()
	return "[set_buffer_text] wrote %d bytes to buffer" % ce.text.length()


func _do_save_file() -> String:
	var ece := _get_embedded_editor()
	if ece == null or not ece.has_method("save_file"):
		return "[save_file] embedded code editor not available"
	ece.save_file()
	var path := ""
	if ece.has_method("get_file_path"):
		path = ece.get_file_path()
	return "[save_file] saved %s" % path


func _do_write_file(d: Dictionary) -> String:
	var path := str(d.get("path", "")).strip_edges()
	if path.is_empty():
		return "[write_file] missing 'path'"
	if not d.has("contents"):
		return "[write_file] missing 'contents'"
	# Case-insensitive canonicalization: if a file with the same name in
	# a different casing already exists, write to that file rather than
	# create a `module1.vg` / `Module1.vg` ghost duplicate on Linux.
	if not FileAccess.file_exists(path):
		var canonical := _case_insensitive_path(path)
		if not canonical.is_empty():
			path = canonical
	var safe = _get_safe()
	if safe == null:
		return "[write_file] safe-write not available"
	var res: Array = safe.write(path, str(d.get("contents")))
	return "[write_file] " + ("ok: " + str(res[1]) if res[0] else "REFUSED: " + str(res[1]))


## Look for a case-insensitive sibling of `path`. Returns the actual on-disk
## path if found, else "".
func _case_insensitive_path(path: String) -> String:
	var dir_part := path.get_base_dir()
	var file_part := path.get_file()
	if file_part.is_empty():
		return ""
	var dir := DirAccess.open(dir_part)
	if dir == null:
		return ""
	var target := file_part.to_lower()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and entry.to_lower() == target:
			dir.list_dir_end()
			if dir_part.is_empty():
				return entry
			return dir_part + "/" + entry
		entry = dir.get_next()
	dir.list_dir_end()
	return ""


func _do_read_file(d: Dictionary) -> String:
	var path := str(d.get("path", "")).strip_edges()
	if path.is_empty():
		return "[read_file] missing 'path'"
	var safe = _get_safe()
	if safe == null:
		return "[read_file] safe-write not available"
	var ok: Array = safe.is_safe(path)
	if not ok[0]:
		return "[read_file] refused: %s" % str(ok[1])
	if not FileAccess.file_exists(path):
		return "[read_file] not found: %s" % path
	var s: String = safe.read(path)
	var max_lines: int = int(d.get("max_lines", READ_DEFAULT_LINES))
	var lines: PackedStringArray = s.split("\n")
	var trimmed: bool = lines.size() > max_lines
	if trimmed:
		s = "\n".join(lines.slice(0, max_lines))
	var note := "[read_file] %s — %d lines%s\n%s" % [
		path, lines.size(), (" (showing first %d)" % max_lines) if trimmed else "", s
	]
	return note


func _do_list_dir(d: Dictionary) -> String:
	var path := str(d.get("path", "res://")).strip_edges()
	if path.is_empty():
		path = "res://"
	var safe = _get_safe()
	if safe != null:
		var ok: Array = safe.is_safe(path if not path.ends_with("/") else path)
		# is_safe expects file-ish paths; try a synthetic file under the dir
		var probe: String = path.rstrip("/") + "/_probe"
		ok = safe.is_safe(probe)
		if not ok[0]:
			return "[list_dir] refused: %s" % str(ok[1])
	var recursive: bool = bool(d.get("recursive", false))
	var max_entries: int = int(d.get("max_entries", LISTDIR_MAX_ENTRIES_DEFAULT))
	var collected: Array = []
	_walk_dir(path, recursive, collected, max_entries)
	var trimmed := collected.size() >= max_entries
	var body: String = "\n".join(collected)
	return "[list_dir] %s (%d entries%s)\n%s" % [
		path, collected.size(), " — TRUNCATED" if trimmed else "", body
	]


# ---------------------------------------------------------------------------
# vb6_canonicalize: rewrite Godot type names → VB6 dialect in user .vg files.
# ---------------------------------------------------------------------------
#
# Visual Gasic accepts both `As LineEdit` and `As TextBox`, but the VB6
# dialect is the canonical user-facing form. This tool walks .vg files and
# rewrites occurrences of Godot-native control type names back to their VB6
# equivalents in *type-position* contexts only:
#
#     As LineEdit          →   As TextBox
#     Dim x As LineEdit    →   Dim x As TextBox
#     ByVal Sender As Button → ByVal Sender As CommandButton
#
# It deliberately does NOT touch:
#   • String literals (preserved as-is)
#   • Comments
#   • .tscn/.gd/other non-.vg files (those remain Godot-native)
#
# Args:
#   path: optional sub-directory to scan (default "res://")
#   dry_run: if true, only report changes without writing
const _VB6_CANONICAL_REWRITES := [
	# [godot_class, vb6_canonical]  — order matters: longer/specific names
	# first so e.g. "TextureRect" doesn't get partially mangled.
	["LineEdit",     "TextBox"],
	["Button",       "CommandButton"],
	["TextureRect",  "PictureBox"],
	["ItemList",     "ListBox"],
	["PanelContainer", "Frame"],
]

func _do_vb6_canonicalize(d: Dictionary) -> String:
	var base := str(d.get("path", "res://")).strip_edges()
	if base.is_empty():
		base = "res://"
	var dry_run: bool = bool(d.get("dry_run", false))
	var safe = _get_safe()
	var files: Array = []
	_walk_dir(base, true, files, 5000)
	var rewrites: Array = []  # human-readable summary lines
	var total_subs := 0
	var files_changed := 0
	for entry in files:
		var p: String = str(entry)
		if not p.ends_with(".vg"):
			continue
		if safe != null:
			var ok: Array = safe.is_safe(p)
			if not ok[0]:
				continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		var new_src := src
		var per_file_subs := 0
		for pair in _VB6_CANONICAL_REWRITES:
			# Match "As <type>" with word boundaries so we don't mangle
			# substrings or identifiers that happen to contain the class
			# name.
			var rx := RegEx.new()
			# The (?i) inline flag would make this case-insensitive but VB6
			# type names are case-sensitive in practice (`As textbox` is
			# unusual). We keep it case-sensitive to avoid false positives.
			rx.compile("\\bAs\\s+" + pair[0] + "\\b")
			var matches := rx.search_all(new_src)
			if matches.is_empty():
				continue
			# Replace from the back so offsets stay valid.
			for i in range(matches.size() - 1, -1, -1):
				var m: RegExMatch = matches[i]
				var head := new_src.substr(0, m.get_start())
				var tail := new_src.substr(m.get_end())
				new_src = head + "As " + pair[1] + tail
			per_file_subs += matches.size()
		if per_file_subs > 0:
			files_changed += 1
			total_subs += per_file_subs
			rewrites.append("  • %s — %d substitution(s)" % [p, per_file_subs])
			if not dry_run:
				if safe != null:
					var wres: Array = safe.write(p, new_src)
					if not wres[0]:
						rewrites.append("    [SKIPPED: %s]" % str(wres[1]))
						continue
				else:
					var wf := FileAccess.open(p, FileAccess.WRITE)
					if wf == null:
						rewrites.append("    [SKIPPED: cannot write]")
						continue
					wf.store_string(new_src)
					wf.close()
	if files_changed == 0:
		return "[vb6_canonicalize] no .vg files needed canonicalization under %s" % base
	var verb := "would rewrite" if dry_run else "rewrote"
	var summary := "[vb6_canonicalize] %s %d substitution(s) in %d file(s) under %s%s" % [
		verb, total_subs, files_changed, base,
		" (dry run)" if dry_run else ""
	]
	return summary + "\n" + "\n".join(rewrites)


# ---------------------------------------------------------------------------
# Tier-3 run-loop tools (play.run_main / play.stop)
# ---------------------------------------------------------------------------

## Register a callback that handles run-loop tool dispatch.  Signature:
## `f(tool_name: String, args: Dictionary) -> String`.  vg_ai_help.gd wires
## this to a wrapper around its `_run_session` so the AI can launch and stop
## the same scene the "▶ Run" button uses.
func set_run_handler(cb: Callable) -> void:
	_run_handler = cb


func _do_play_run_main(d: Dictionary) -> String:
	if not _run_handler.is_valid():
		return "[play.run_main] no run handler registered (Tier-3 run loop disabled in this context)"
	return str(_run_handler.call("play.run_main", d))


func _do_play_stop(d: Dictionary) -> String:
	if not _run_handler.is_valid():
		return "[play.stop] no run handler registered"
	return str(_run_handler.call("play.stop", d))


func _walk_dir(base: String, recursive: bool, out: Array, cap: int) -> void:
	if out.size() >= cap:
		return
	var d := DirAccess.open(base)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name == "." or name == "..":
			name = d.get_next()
			continue
		var sub := base.rstrip("/") + "/" + name
		var is_dir := d.current_is_dir()
		out.append("%s%s" % [sub, "/" if is_dir else ""])
		if out.size() >= cap:
			d.list_dir_end()
			return
		if recursive and is_dir:
			# Skip the AI's own forbidden zones to keep listings useful.
			if name == ".git" or name == ".godot" or sub.find("/addons/visual_gasic") >= 0:
				name = d.get_next()
				continue
			_walk_dir(sub, true, out, cap)
		name = d.get_next()
	d.list_dir_end()


func _do_find_in_files(d: Dictionary) -> String:
	var pattern := str(d.get("pattern", ""))
	if pattern.is_empty():
		return "[find_in_files] missing 'pattern'"
	var base := str(d.get("path", "res://")).strip_edges()
	if base.is_empty():
		base = "res://"
	var max_hits: int = int(d.get("max_hits", FIND_MAX_HITS_DEFAULT))
	var use_regex: bool = bool(d.get("regex", false))
	var rx: RegEx = null
	if use_regex:
		rx = RegEx.new()
		if rx.compile(pattern) != OK:
			return "[find_in_files] invalid regex: %s" % pattern
	var safe = _get_safe()
	# Walk and search.
	var files: Array = []
	_walk_dir(base, true, files, 5000)
	var hits: Array = []
	for entry in files:
		if hits.size() >= max_hits:
			break
		var p: String = str(entry)
		if p.ends_with("/"):
			continue
		# Skip non-text-y suffixes to keep scans fast.
		var lower := p.to_lower()
		var ok_ext := false
		for ext in [".vg", ".gd", ".cs", ".cfg", ".tscn", ".tres", ".md", ".txt", ".json", ".xml", ".html", ".css", ".js"]:
			if lower.ends_with(ext):
				ok_ext = true
				break
		if not ok_ext:
			continue
		if safe != null:
			var ok2: Array = safe.is_safe(p)
			if not ok2[0]:
				continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var content := f.get_as_text()
		f.close()
		var lines := content.split("\n")
		for i in range(lines.size()):
			if hits.size() >= max_hits:
				break
			var line: String = lines[i]
			var matched := false
			if use_regex:
				matched = rx.search(line) != null
			else:
				matched = line.find(pattern) >= 0
			if matched:
				var snippet := line.strip_edges().left(160)
				hits.append("%s:%d: %s" % [p, i + 1, snippet])
	var trimmed := hits.size() >= max_hits
	return "[find_in_files] %d hit(s)%s\n%s" % [
		hits.size(), " (capped)" if trimmed else "", "\n".join(hits)
	]


# ---------------------------------------------------------------------------
# Editor / safe-write lookups
# ---------------------------------------------------------------------------

func _get_plugin() -> Object:
	if not Engine.is_editor_hint():
		return null
	var base := EditorInterface.get_base_control()
	if base == null or not base.has_meta("visual_gasic_plugin_instance"):
		return null
	var p = base.get_meta("visual_gasic_plugin_instance")
	if p == null or not is_instance_valid(p):
		return null
	return p


func _get_embedded_editor() -> Object:
	var p := _get_plugin()
	if p == null:
		return null
	if not ("_embedded_code_editor" in p):
		return null
	var ece = p.get("_embedded_code_editor")
	if ece == null or not is_instance_valid(ece):
		return null
	return ece


func _get_code_edit() -> CodeEdit:
	var ece := _get_embedded_editor()
	if ece == null:
		return null
	if ece.has_method("get_code_edit"):
		return ece.get_code_edit()
	if "_code_edit" in ece:
		return ece.get("_code_edit")
	return null


func _mark_dirty() -> void:
	var ece := _get_embedded_editor()
	if ece == null:
		return
	if "_dirty" in ece:
		ece.set("_dirty", true)


func _get_safe():
	if _safe != null:
		return _safe
	var script := load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if script == null:
		return null
	_safe = script.new()
	return _safe
