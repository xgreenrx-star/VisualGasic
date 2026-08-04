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
##   open_file        {path:str}   -- .vg files ONLY; opens in the embedded
##                                    VG editor tab for the USER to see. For
##                                    investigating any other file type
##                                    (.gd, .tscn, etc.) use read_file
##                                    instead, which doesn't touch the UI.
##   insert_text      {line:int, text:str, path?:str}  # insert BEFORE 1-based line
##   replace_range    {start_line:int, end_line:int, text:str, path?:str}  # inclusive
##   replace_in_buffer{find:str, replace:str, all?:bool, path?:str}
##   set_buffer_text  {text:str, path?:str}            # full-buffer replace
##   save_file        {}
##
## insert_text/replace_range/replace_in_buffer/set_buffer_text always act on
## whichever file is CURRENTLY OPEN in the embedded editor tab -- they have
## no independent file targeting. The optional `path` field is a SAFETY
## CHECK ONLY: if given and it doesn't match the active tab, the call fails
## with a clear error instead of silently editing nothing (no tab open) or
## the WRONG file (a different tab happens to be open). When editing a file
## that may not be the active tab, prefer write_file (path + full contents)
## instead -- it always targets the right file regardless of what's open.
##   write_file       {path:str, contents:str}        # routed through SafeWrite
##   read_file        {path:str, start_line?:int, max_lines?:int}  # echoes a
##                                                    # window of contents to
##                                                    # chat; start_line is
##                                                    # 1-based (default 1)
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
	# Plugin read tools
	"get_wn_project", "get_agck_project",
	"get_form_controls", "get_2d_scene_tree", "get_3d_scene",
	"get_vgmusic_project",
	# Triggers a filesystem rescan — no file writes, safe to auto-run.
	"reload_scripts",
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
	# Plugin mutating tools
	"load_wn_project", "load_agck_project",
	"build_form", "set_form_control_prop",
	"load_2d_scene", "load_3d_scene",
	# IDE self-modification tools
	"backup_addon", "enable_addon_editing", "disable_addon_editing",
	"restore_addon",
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
		# ── Plugin tools ─────────────────────────────────────────
		"get_wn_project":
			return _do_get_wn_project()
		"load_wn_project":
			return _do_load_wn_project(d)
		"get_agck_project":
			return _do_get_agck_project()
		"load_agck_project":
			return _do_load_agck_project(d)
		"get_form_controls":
			return _do_get_form_controls()
		"build_form":
			return _do_build_form(d)
		"set_form_control_prop":
			return _do_set_form_control_prop(d)
		"get_2d_scene_tree":
			return _do_get_2d_scene_tree()
		"load_2d_scene":
			return _do_load_2d_scene(d)
		"get_3d_scene":
			return _do_get_3d_scene()
		"load_3d_scene":
			return _do_load_3d_scene(d)
		# ── IDE self-modification tools ───────────────────────────
		"backup_addon":
			return _do_backup_addon()
		"enable_addon_editing":
			return _do_enable_addon_editing()
		"disable_addon_editing":
			return _do_disable_addon_editing()
		"restore_addon":
			return _do_restore_addon(d)
		"reload_scripts":
			return _do_reload_scripts()
		"get_vgmusic_project":
			return _do_get_vgmusic_project()
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
	# The embedded editor is a VisualGasic-only view -- its live syntax/error
	# checker always parses whatever buffer it holds AS VG source. Loading a
	# non-.vg file (e.g. a GDScript addon file) into it swaps out the user's
	# current tab AND corrupts the display with bogus VG parse errors (e.g.
	# GDScript's `@tool` annotation trips "Unexpected character: @"). Only
	# .vg files are safe to open here; anything else should be inspected
	# with read_file instead, which never touches the editor UI.
	if path.get_extension().to_lower() != "vg":
		return ("[open_file] refused: only .vg files can be opened in the VG code editor " +
			"— use read_file to inspect %s instead") % path
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
	var mismatch := _check_active_path(d)
	if not mismatch.is_empty():
		return "[insert_text] " + mismatch
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
	var new_text := head + sep + txt + tail
	var nested_line := _check_nested_if_vg(new_text)
	if nested_line > 0:
		return ("[insert_text] REFUSED: would create a nested Sub/Function declaration at line %d -- " +
			"VG has no nested procedures. Insert the new Sub/Function as a top-level sibling " +
			"AFTER the enclosing Sub's End Sub, not inside its body.") % nested_line
	ce.text = new_text
	_mark_dirty()
	var inserted_count := txt.count("\n")
	return "[insert_text] inserted %d line(s) before line %d" % [inserted_count, line + 1]


func _do_replace_range(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[replace_range] no code editor open"
	var mismatch := _check_active_path(d)
	if not mismatch.is_empty():
		return "[replace_range] " + mismatch
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
	var new_text := head + head_sep + middle + tail_sep + tail
	var nested_line := _check_nested_if_vg(new_text)
	if nested_line > 0:
		return ("[replace_range] REFUSED: would create a nested Sub/Function declaration at line %d -- " +
			"VG has no nested procedures. Keep the replacement as a top-level sibling " +
			"AFTER the enclosing Sub's End Sub, not inside its body.") % nested_line
	ce.text = new_text
	_mark_dirty()
	return "[replace_range] replaced lines %d-%d" % [sl + 1, el + 1]


func _do_replace_in_buffer(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[replace_in_buffer] no code editor open"
	var mismatch := _check_active_path(d)
	if not mismatch.is_empty():
		return "[replace_in_buffer] " + mismatch
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
		var new_text_one := src.substr(0, i) + rep_s + src.substr(i + find_s.length())
		var nested_line_one := _check_nested_if_vg(new_text_one)
		if nested_line_one > 0:
			return ("[replace_in_buffer] REFUSED: would create a nested Sub/Function declaration at line %d -- " +
				"VG has no nested procedures. Keep the replacement as a top-level sibling " +
				"AFTER the enclosing Sub's End Sub, not inside its body.") % nested_line_one
		ce.text = new_text_one
		_mark_dirty()
		return "[replace_in_buffer] replaced 1 occurrence"
	var count := src.count(find_s)
	if count == 0:
		return "[replace_in_buffer] no match"
	var new_text_all := src.replace(find_s, rep_s)
	var nested_line_all := _check_nested_if_vg(new_text_all)
	if nested_line_all > 0:
		return ("[replace_in_buffer] REFUSED: would create a nested Sub/Function declaration at line %d -- " +
			"VG has no nested procedures. Keep the replacement as a top-level sibling " +
			"AFTER the enclosing Sub's End Sub, not inside its body.") % nested_line_all
	ce.text = new_text_all
	_mark_dirty()
	return "[replace_in_buffer] replaced %d occurrence(s)" % count


func _do_set_buffer_text(d: Dictionary) -> String:
	var ce := _get_code_edit()
	if ce == null:
		return "[set_buffer_text] no code editor open"
	var mismatch := _check_active_path(d)
	if not mismatch.is_empty():
		return "[set_buffer_text] " + mismatch
	if not d.has("text"):
		return "[set_buffer_text] missing 'text'"
	var new_text := str(d.get("text"))
	var nested_line := _check_nested_if_vg(new_text)
	if nested_line > 0:
		return ("[set_buffer_text] REFUSED: nested Sub/Function declaration at line %d -- " +
			"VG has no nested procedures. Move the new Sub/Function to top-level " +
			"scope, as a sibling AFTER the enclosing Sub's End Sub, then try again.") % nested_line
	ce.text = new_text
	_mark_dirty()
	return "[set_buffer_text] wrote %d bytes to buffer" % ce.text.length()


func _do_save_file() -> String:
	var ece := _get_embedded_editor()
	if ece == null or not ece.has_method("save_file"):
		return "[save_file] embedded code editor not available"
	# If the buffer is a .vg form file, normalize before saving — AI tool
	# sequences (open_file → insert_text → save_file) bypass _do_write_file
	# so the Class wrapper / VB6 alias / duplicate-Option-Explicit landmines
	# reappear here.
	var path := ""
	if ece.has_method("get_file_path"):
		path = ece.get_file_path()
	if path.ends_with(".vg"):
		var ce := _get_code_edit()
		if ce != null:
			var src: String = ce.text
			var alias_map: Dictionary = _build_vb6_alias_map_from_designer()
			var normalized: String = _normalize_vg_source(src, alias_map)
			# Refuse to save a file with a nested Sub/Function — VG has no
			# nested procedures; it would compile with zero error but the
			# nested one is never callable and fails LATER at runtime (this
			# has bitten c64_main.vg's paste routine twice already). Leave
			# the buffer untouched (dirty, unsaved) so the caller can see
			# this error and fix it before retrying.
			var nested_line := _find_nested_procedure_line(normalized)
			if nested_line > 0:
				return ("[save_file] REFUSED: nested Sub/Function declaration at line %d in %s — " +
					"VG has no nested procedures. Move the new Sub/Function to top-level " +
					"scope, as a sibling AFTER the enclosing Sub's End Sub, then save again.") % [nested_line, path]
			if normalized != src:
				ce.text = normalized
	ece.save_file()
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
	var contents := str(d.get("contents"))
	# --- VB6 form .vg post-processing ---------------------------------
	# When Narcea (or any AI) writes a .vg file via the tool channel
	# (bypassing vg-code-spec), it tends to:
	#   • wrap the body in `Class Form1 / Inherits Form … End Class`
	#     (VB6 forms have no Class wrapper)
	#   • use VB6 alias names (`TextBox1`, `Command1`) that don't
	#     match the actual Godot control names (`LineEdit1`, `Button1`)
	# Both produce non-running code.  Normalize here before the write.
	if path.ends_with(".vg"):
		contents = _normalize_vg_for_form(contents, path)
	# -----------------------------------------------------------------
	# Refuse to write a .vg file containing a Sub/Function nested inside
	# another Sub/Function's body — see _find_nested_procedure_line().
	if path.ends_with(".vg"):
		var nested_line := _find_nested_procedure_line(contents)
		if nested_line > 0:
			return ("[write_file] REFUSED: nested Sub/Function declaration at line %d in %s — " +
				"VG has no nested procedures. Move the new Sub/Function to top-level " +
				"scope, as a sibling AFTER the enclosing Sub's End Sub, then write again.") % [nested_line, path]
	var safe = _get_safe()
	if safe == null:
		return "[write_file] safe-write not available"
	var res: Array = safe.write(path, contents)
	# After a successful .vg write, reload it in the embedded code
	# editor so the user immediately sees the new code (instead of
	# the Module1.vg placeholder that opened the IDE).
	if res[0] and path.ends_with(".vg"):
		_reload_vg_in_editor(path)
	return "[write_file] " + ("ok: " + str(res[1]) if res[0] else "REFUSED: " + str(res[1]))


## Normalize a .vg form source written via the raw write_file tool.
## Strips spurious `Class X / Inherits Form / End Class` wrappers and
## remaps VB6 alias control names (TextBox1, Command1, …) onto the
## actual Godot-style names declared by the FormDesigner for the
## sibling .tscn.  Idempotent: if nothing matches, returns src as-is.
func _normalize_vg_for_form(src: String, vg_path: String) -> String:
	if src.is_empty():
		return src
	# 1. Build VB6-alias → actual-name map from the live form designer.
	var alias_map: Dictionary = _build_vb6_alias_map_from_designer()
	return _normalize_vg_source(src, alias_map)


## Guard for the buffer-editing tools (insert_text/replace_range/
## replace_in_buffer/set_buffer_text), which act on whatever's open in the
## embedded editor rather than an explicit path -- only run the nested-
## procedure scan when that buffer is a .vg file, and only for the
## RESULTING full text (never the raw find/replace/insert snippet alone,
## since nesting is a whole-file depth property, not something a snippet
## can be judged on in isolation). Returns the 1-based offending line, or
## -1/0 when the buffer isn't .vg or the text is clean.
func _check_nested_if_vg(new_full_text: String) -> int:
	if not _active_editor_path().to_lower().ends_with(".vg"):
		return -1
	return _find_nested_procedure_line(new_full_text)


## Scan VG source for a Sub/Function declared INSIDE another Sub/Function's
## body — VG has no nested procedures (see KNOWLEDGE block in
## vg_ai_narcea.gd). Returns the 1-based line number of the FIRST nested
## declaration found, or -1 if the source is clean. Depth-tracking rather
## than indentation-based so it can't be fooled by inconsistent whitespace —
## exactly mirrors how the VG parser itself has no concept of nesting.
func _find_nested_procedure_line(src: String) -> int:
	var depth := 0
	var lines: PackedStringArray = src.split("\n")
	var open_re := RegEx.new()
	open_re.compile("(?i)^\\s*(Public\\s+|Private\\s+|Static\\s+)?(Sub|Function)\\s+\\w")
	var close_re := RegEx.new()
	close_re.compile("(?i)^\\s*End\\s+(Sub|Function)\\b")
	for i in lines.size():
		var ln := lines[i]
		if close_re.search(ln) != null:
			depth = maxi(0, depth - 1)
			continue
		if open_re.search(ln) != null:
			if depth > 0:
				return i + 1
			depth += 1
	return -1


## Pure-source normalizer — no plugin/designer access, fully testable.
func _normalize_vg_source(src: String, alias_map: Dictionary) -> String:
	if src.is_empty():
		return src
	# 2. Strip Class wrapper.  We match a `Class XXX` line optionally
	#    followed by `Inherits Form/UserForm`, and the matching `End
	#    Class` at the tail, preserving everything in between.
	var lines: PackedStringArray = src.split("\n")
	var out_lines: Array[String] = []
	var skip_inherits := false
	for ln in lines:
		var s := ln.strip_edges()
		var sl := s.to_lower()
		if sl.begins_with("class ") and not sl.begins_with("classmodule"):
			skip_inherits = true
			continue
		if skip_inherits and sl.begins_with("inherits "):
			skip_inherits = false
			continue
		skip_inherits = false
		if sl == "end class":
			continue
		out_lines.append(ln)
	# 2b. Collapse duplicate `Option Explicit` lines and duplicate
	#     `' Visual Gasic Form Script` headers — keep only the first
	#     occurrence of each.  AI insert_text sequences love to glue
	#     a second header onto the buffer.
	var seen_opt_explicit := false
	var seen_form_header := false
	var dedup_lines: Array[String] = []
	for ln in out_lines:
		var sl := ln.strip_edges().to_lower()
		if sl == "option explicit":
			if seen_opt_explicit:
				continue
			seen_opt_explicit = true
		elif sl.begins_with("' visual gasic form script") or sl.begins_with("'visual gasic form script"):
			if seen_form_header:
				continue
			seen_form_header = true
		dedup_lines.append(ln)
	src = "\n".join(dedup_lines)
	# 3. Remap VB6 alias names onto actual names (whole-word).
	for vb6_name in alias_map:
		var real_name: String = alias_map[vb6_name]
		src = src.replace(vb6_name + ".", real_name + ".")
		src = src.replace(vb6_name + "_", real_name + "_")
		src = src.replace(vb6_name + " ", real_name + " ")
		src = src.replace(vb6_name + "\t", real_name + "\t")
		src = src.replace(vb6_name + "\n", real_name + "\n")
	return src


## Inspect the live FormDesigner (if any) and produce a map of
## VB6-alias control names → actual Godot-style names.
func _build_vb6_alias_map_from_designer() -> Dictionary:
	var alias_map: Dictionary = {}
	var host = _get_plugin()
	if host == null or not ("_form_designer" in host):
		return alias_map
	var fd = host.get("_form_designer")
	if not is_instance_valid(fd) or not fd.has_method("get_control_count") or not fd.has_method("get_control_info"):
		return alias_map
	const VB6_ALIASES: Dictionary = {
		"TextBox": "LineEdit", "Text": "LineEdit",
		"Command": "Button", "Frame": "Panel",
		"ComboBox": "OptionButton", "ListBox": "ItemList",
		"Shape": "ColorRect", "Image": "TextureRect",
		"PictureBox": "TextureRect",
	}
	for i in range(fd.get_control_count()):
		var info: Dictionary = fd.get_control_info(i)
		var actual_name: String = str(info.get("name", ""))
		var actual_type: String = str(info.get("type", ""))
		if actual_name.is_empty() or actual_type.is_empty():
			continue
		for vb6_type in VB6_ALIASES:
			if actual_type.begins_with(VB6_ALIASES[vb6_type]):
				var suffix: String = actual_name.substr(VB6_ALIASES[vb6_type].length())
				var vb6_guess: String = vb6_type + suffix
				if vb6_guess != actual_name:
					alias_map[vb6_guess] = actual_name
	return alias_map


## Reload `vg_path` in the embedded VB6-style code editor so the user
## sees freshly-written code instead of the stale placeholder.
func _reload_vg_in_editor(vg_path: String) -> void:
	var host = _get_plugin()
	if host == null or not is_instance_valid(host):
		return
	if not ("_embedded_code_editor" in host):
		return
	var ece = host.get("_embedded_code_editor")
	if ece == null or not is_instance_valid(ece) or not ece.has_method("load_file"):
		return
	if not FileAccess.file_exists(vg_path):
		return
	ece.call_deferred("load_file", vg_path)


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
	var total_lines: int = lines.size()
	# 1-based, like every other line-number arg in this file. Clamp into
	# range rather than erroring, so an over-shoot start_line (e.g. asking
	# for line 900 of an 800-line file) degrades to "nothing left" instead
	# of a hard failure.
	var start_line: int = int(d.get("start_line", 1))
	var start_idx: int = clampi(start_line - 1, 0, total_lines)
	var end_idx: int = mini(start_idx + max_lines, total_lines)
	var trimmed: bool = end_idx < total_lines or start_idx > 0
	s = "\n".join(lines.slice(start_idx, end_idx))
	var range_note := ""
	if trimmed:
		range_note = " (showing lines %d-%d)" % [start_idx + 1, end_idx]
	var note := "[read_file] %s — %d lines%s\n%s" % [
		path, total_lines, range_note, s
	]
	return note


func _do_list_dir(d: Dictionary) -> String:
	var path := str(d.get("path", "res://")).strip_edges()
	if path.is_empty():
		path = "res://"
	var safe = _get_safe()
	if safe != null:
		var ok: Array = safe.is_safe(path if not path.ends_with("/") else path)
		# is_safe expects file-ish paths; try a synthetic file under the dir.
		# NOTE: don't rstrip("/") first — for root paths like "res://" or
		# "user://" that strips BOTH slashes (collapsing to "res:"), which
		# then fails the "res://" prefix check in _resolve() and makes
		# is_safe() refuse every listing of the project root. Just ensure
		# exactly one trailing slash instead.
		var probe: String = (path if path.ends_with("/") else path + "/") + "_probe"
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
	# NOTE: don't rstrip("/") before joining — for root paths like "res://"
	# or "user://" that strips BOTH trailing slashes (collapsing to
	# "res:"), producing malformed joined paths like "res:/demos" (single
	# slash). DirAccess.open() then fails to resolve those, silently
	# killing recursion one level below any root, and the malformed
	# "res:/..." prefix also fails the "res://" checks in
	# vg_ai_safe_write.gd's _resolve()/is_safe(), so even top-level
	# entries get rejected downstream. Ensure exactly one trailing slash
	# before appending instead.
	var base_slash := base if base.ends_with("/") else base + "/"
	while name != "":
		if name == "." or name == "..":
			name = d.get_next()
			continue
		var sub := base_slash + name
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
# IDE self-modification tools
# ---------------------------------------------------------------------------

const ADDON_ROOT := "res://addons/visual_gasic/"
const BACKUP_DIR := "res://backups/"

func _do_backup_addon() -> String:
	# Walk the entire addon tree and zip it.
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var zip_name := "vg_addon_backup_%s.zip" % ts
	var zip_res := BACKUP_DIR + zip_name
	var zip_abs := ProjectSettings.globalize_path(zip_res)
	var backups_abs := ProjectSettings.globalize_path(BACKUP_DIR)

	var derr := DirAccess.make_dir_recursive_absolute(backups_abs)
	if derr != OK and derr != ERR_ALREADY_EXISTS:
		return "[backup_addon] could not create backups/ dir (err %d)" % derr

	var files: Array = []
	_walk_dir(ADDON_ROOT, true, files, 999999)

	var zp := ZIPPacker.new()
	var zerr := zp.open(zip_abs)
	if zerr != OK:
		return "[backup_addon] could not open zip for writing (err %d): %s" % [zerr, zip_abs]

	var count := 0
	for entry in files:
		var fp := str(entry)
		if fp.ends_with("/"):
			continue
		var fh := FileAccess.open(fp, FileAccess.READ)
		if fh == null:
			continue
		var data := fh.get_buffer(fh.get_length())
		fh.close()
		# Store with path relative to res:// so it's easy to restore.
		var rel := fp.trim_prefix("res://")
		zp.start_file(rel)
		zp.write_file(data)
		zp.close_file()
		count += 1

	zp.close()
	_read_results_buffer.append({"tool": "backup_addon", "args": {}, "output": zip_res})
	return "[backup_addon] archived %d files → %s" % [count, zip_res]


func _do_enable_addon_editing() -> String:
	# 1. Create backup first.
	var backup_result := _do_backup_addon()
	if not backup_result.begins_with("[backup_addon] archived"):
		return "[enable_addon_editing] backup failed — addon editing NOT unlocked.\n%s" % backup_result
	# 2. Unlock writes.
	var safe = _get_safe()
	if safe == null:
		return "[enable_addon_editing] SafeWrite not available"
	safe.allow_addon_writes(true)
	return "[enable_addon_editing] addon editing UNLOCKED.\n%s\nYou may now use write_file on res://addons/visual_gasic/ paths.\nCall disable_addon_editing when finished." % backup_result


func _do_disable_addon_editing() -> String:
	var safe = _get_safe()
	if safe == null:
		return "[disable_addon_editing] SafeWrite not available"
	safe.allow_addon_writes(false)
	return "[disable_addon_editing] addon editing re-locked."


func _do_restore_addon(d: Dictionary) -> String:
	var zip_path: String = str(d.get("path", "")).strip_edges()
	if zip_path.is_empty():
		return "[restore_addon] 'path' required (e.g. res://backups/vg_addon_backup_<ts>.zip)"
	if not FileAccess.file_exists(zip_path):
		return "[restore_addon] file not found: %s" % zip_path
	var zip_abs := ProjectSettings.globalize_path(zip_path)
	var zr := ZIPReader.new()
	var zerr := zr.open(zip_abs)
	if zerr != OK:
		return "[restore_addon] could not open zip (err %d): %s" % [zerr, zip_abs]
	var count := 0
	for rel in zr.get_files():
		var data := zr.read_file(rel)
		var dest := "res://" + rel
		var dest_abs := ProjectSettings.globalize_path(dest)
		var ddir := dest_abs.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ddir)
		var f := FileAccess.open(dest, FileAccess.WRITE)
		if f:
			f.store_buffer(data)
			f.close()
			count += 1
	zr.close()
	# Rescan so Godot picks up the restored scripts.
	if Engine.is_editor_hint():
		var efs = EditorInterface.get_resource_filesystem()
		if efs:
			efs.scan()
	return "[restore_addon] restored %d files from %s" % [count, zip_path]


func _do_reload_scripts() -> String:
	if not Engine.is_editor_hint():
		return "[reload_scripts] only available in editor"
	var efs = EditorInterface.get_resource_filesystem()
	if efs == null:
		return "[reload_scripts] resource filesystem not available"
	efs.scan()
	return "[reload_scripts] filesystem scan triggered — Godot will reload changed scripts"


func _do_get_vgmusic_project() -> String:
	# VGMusic uses a Controller autoload exposed via SceneTree root.
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return "[get_vgmusic_project] no SceneTree available"
	var ctrl = loop.root.get_node_or_null("Controller")
	if ctrl == null:
		return "[get_vgmusic_project] VGMusic Controller not found (plugin may not be active)"
	var song = ctrl.get("current_song") if "current_song" in ctrl else null
	if song == null:
		return "[get_vgmusic_project] no song loaded"
	var result := {
		"title": song.get("title") if "title" in song else "",
		"filename": song.get("filename") if "filename" in song else "",
		"bpm": song.get("bpm") if "bpm" in song else 0,
		"pattern_count": song.get("patterns").size() if "patterns" in song else 0,
		"instrument_count": song.get("instruments").size() if "instruments" in song else 0,
	}
	# Arrangement length
	if "arrangement" in song:
		var arr = song.get("arrangement")
		if arr and "timeline_length" in arr:
			result["arrangement_bars"] = arr.get("timeline_length")
	# Instrument names
	if "instruments" in song:
		var names: Array = []
		for inst in song.get("instruments"):
			names.append(inst.get("name") if "name" in inst else "?")
		result["instruments"] = names
	var json := JSON.stringify(result, "\t")
	_read_results_buffer.append({"tool": "get_vgmusic_project", "args": {}, "output": json})
	return "[get_vgmusic_project] bpm=%d patterns=%d\n%s" % [
		result.get("bpm", 0), result.get("pattern_count", 0), json
	]


# ---------------------------------------------------------------------------
# Plugin tools — Working Nodes
# ---------------------------------------------------------------------------

func _do_get_wn_project() -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[get_wn_project] plugin manager not found"
	var wn = pm.get_plugin("working_nodes")
	if wn == null:
		return "[get_wn_project] working_nodes plugin not loaded"
	if not ("_editor" in wn) or not is_instance_valid(wn.get("_editor")):
		return "[get_wn_project] working_nodes editor not ready"
	var editor = wn.get("_editor")
	if not editor.has_method("_collect_graph_data"):
		return "[get_wn_project] _collect_graph_data not found"
	var data: Dictionary = editor._collect_graph_data()
	var json := JSON.stringify(data, "\t")
	_read_results_buffer.append({"tool": "get_wn_project", "args": {}, "output": json})
	return "[get_wn_project] returned %d node(s)\n%s" % [data.get("nodes", []).size(), json]


func _do_load_wn_project(d: Dictionary) -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[load_wn_project] plugin manager not found"
	var wn = pm.get_plugin("working_nodes")
	if wn == null:
		return "[load_wn_project] working_nodes plugin not loaded"
	if not ("_editor" in wn) or not is_instance_valid(wn.get("_editor")):
		return "[load_wn_project] working_nodes editor not ready"
	var editor = wn.get("_editor")
	if not editor.has_method("_apply_loaded_data"):
		return "[load_wn_project] _apply_loaded_data not found"
	var data = d.get("data", null)
	if typeof(data) != TYPE_DICTIONARY:
		return "[load_wn_project] missing 'data' dict"
	editor._apply_loaded_data(data)
	return "[load_wn_project] applied %d node(s)" % data.get("nodes", []).size()


# ---------------------------------------------------------------------------
# Plugin tools — AGCK
# ---------------------------------------------------------------------------

func _do_get_agck_project() -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[get_agck_project] plugin manager not found"
	var agck = pm.get_plugin("agck")
	if agck == null:
		return "[get_agck_project] agck plugin not loaded"
	if not agck.has_method("_collect_all_data"):
		return "[get_agck_project] _collect_all_data not found"
	var data: Dictionary = agck._collect_all_data()
	var json := JSON.stringify(data, "\t")
	_read_results_buffer.append({"tool": "get_agck_project", "args": {}, "output": json})
	return "[get_agck_project] returned project data\n%s" % json


func _do_load_agck_project(d: Dictionary) -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[load_agck_project] plugin manager not found"
	var agck = pm.get_plugin("agck")
	if agck == null:
		return "[load_agck_project] agck plugin not loaded"
	var path: String = str(d.get("path", "")).strip_edges()
	if path.is_empty():
		return "[load_agck_project] missing 'path' (res:// path to .agck file)"
	if not agck.has_method("load_project"):
		return "[load_agck_project] load_project not found"
	var ok: bool = agck.load_project(path)
	return "[load_agck_project] %s" % ("loaded: " + path if ok else "failed to load: " + path)


# ---------------------------------------------------------------------------
# Plugin tools — Forms
# ---------------------------------------------------------------------------

func _do_get_form_controls() -> String:
	var host = _get_plugin()
	if host == null:
		return "[get_form_controls] host plugin not found"
	if not ("_form_designer" in host) or not is_instance_valid(host.get("_form_designer")):
		return "[get_form_controls] form designer not ready"
	var fd = host.get("_form_designer")
	if not fd.has_method("get_control_count"):
		return "[get_form_controls] get_control_count not found"
	var count: int = fd.get_control_count()
	var form_name: String = fd.get_form_name() if fd.has_method("get_form_name") else "Form1"
	var controls: Array = []
	for i in range(count):
		var info: Dictionary = fd.get_control_info(i) if fd.has_method("get_control_info") else {}
		info["index"] = i
		controls.append(info)
	var result := {"form_name": form_name, "controls": controls}
	var json := JSON.stringify(result, "\t")
	_read_results_buffer.append({"tool": "get_form_controls", "args": {}, "output": json})
	return "[get_form_controls] form '%s' has %d control(s)\n%s" % [form_name, count, json]


func _do_build_form(d: Dictionary) -> String:
	var host = _get_plugin()
	if host == null:
		return "[build_form] host plugin not found"
	if not ("_form_designer" in host) or not is_instance_valid(host.get("_form_designer")):
		return "[build_form] form designer not ready"
	var fd = host.get("_form_designer")
	# Load vg_ai_form_spec helper to reuse its apply logic.
	var spec_script = load("res://addons/visual_gasic/vg_ai_form_spec.gd")
	if spec_script == null:
		return "[build_form] vg_ai_form_spec.gd not found"
	var spec_helper = spec_script.new()
	# Accept either a raw spec dict or a JSON string.
	var spec = d.get("spec", d)
	if typeof(spec) == TYPE_STRING:
		spec = JSON.parse_string(spec)
	if typeof(spec) != TYPE_DICTIONARY:
		return "[build_form] 'spec' must be a JSON object matching the form spec schema"
	var errs: Array = spec_helper.apply_to_designer(spec, fd)
	# After building, save the form to disk so the .tscn file exists before
	# open_form_in_designer tries to load it as a Godot scene tab.
	# CRITICAL: form_name MUST be non-empty — empty name produces "res://.tscn"
	# which Godot's resource saver mangles into a garbage temp filename.
	var form_name: String = str(spec.get("form_name", "Form1")).strip_edges()
	if form_name.is_empty():
		form_name = "Form1"
	var tscn_path := ""
	if fd.has_method("get_form_path"):
		tscn_path = str(fd.get_form_path())
	# Validate any existing path — reject degenerate forms like "res://.tscn".
	if not tscn_path.is_empty():
		var _fn := tscn_path.get_file().get_basename()
		if _fn.is_empty():
			tscn_path = ""
	if tscn_path.is_empty():
		# Derive from the spec's vg-code-spec path, or fall back to convention.
		var spec_path := str(spec.get("path", "")).strip_edges()
		if not spec_path.is_empty() and spec_path.ends_with(".vg"):
			tscn_path = spec_path.get_basename() + ".tscn"
		else:
			tscn_path = "res://forms/%s.tscn" % form_name
	if not tscn_path.is_empty():
		# Ensure parent directory exists — save_form_as() fails silently
		# if it doesn't (test17 landmine: no forms/ → no .tscn).
		var _dir_abs := ProjectSettings.globalize_path(tscn_path.get_base_dir())
		DirAccess.make_dir_recursive_absolute(_dir_abs)
		# Save to disk first (creating the .tscn) then open in designer.
		var _save_ok := true
		if fd.has_method("save_form_as"):
			fd.save_form_as(tscn_path)
			_save_ok = FileAccess.file_exists(tscn_path)
		if _save_ok:
			# Make this form the project's main scene so the Play button
			# actually runs something (otherwise pressing Play opens the
			# "Choose main scene" dialog and the user sees nothing happen).
			if ProjectSettings.get_setting("application/run/main_scene", "") == "":
				ProjectSettings.set_setting("application/run/main_scene", tscn_path)
				ProjectSettings.save()
			if host.has_method("open_form_in_designer"):
				host.call_deferred("open_form_in_designer", tscn_path)
		else:
			push_warning("[build_form] save_form_as('%s') produced no file" % tscn_path)
	if errs.is_empty():
		return "[build_form] form '%s' built with %d control(s) — saved %s" % [
			form_name, spec.get("controls", []).size(), tscn_path
		]
	return "[build_form] built with warnings: %s" % str(errs)


func _do_set_form_control_prop(d: Dictionary) -> String:
	var host = _get_plugin()
	if host == null:
		return "[set_form_control_prop] host plugin not found"
	if not ("_form_designer" in host) or not is_instance_valid(host.get("_form_designer")):
		return "[set_form_control_prop] form designer not ready"
	var fd = host.get("_form_designer")
	if not fd.has_method("set_control_property"):
		return "[set_form_control_prop] set_control_property not available"
	var idx = d.get("index", -1)
	if typeof(idx) != TYPE_INT and typeof(idx) != TYPE_FLOAT:
		return "[set_form_control_prop] 'index' (int) required"
	var prop: String = str(d.get("property", "")).strip_edges()
	if prop.is_empty():
		return "[set_form_control_prop] 'property' required"
	var value = d.get("value", null)
	if value == null:
		return "[set_form_control_prop] 'value' required"
	fd.set_control_property(int(idx), prop, value)
	return "[set_form_control_prop] control[%d].%s = %s" % [int(idx), prop, str(value)]


# ---------------------------------------------------------------------------
# Plugin tools — 2D Scene
# ---------------------------------------------------------------------------

func _do_get_2d_scene_tree() -> String:
	var host = _get_plugin()
	if host == null:
		return "[get_2d_scene_tree] host plugin not found"
	if not ("_vg_2d_editor" in host) or not is_instance_valid(host.get("_vg_2d_editor")):
		return "[get_2d_scene_tree] 2D editor not ready"
	var ed = host.get("_vg_2d_editor")
	if not ed.has_method("get_scene_node_info"):
		return "[get_2d_scene_tree] get_scene_node_info not found"
	var info: Array = ed.get_scene_node_info()
	var path: String = ed.get_scene_path() if ed.has_method("get_scene_path") else ""
	var result := {"scene_path": path, "nodes": info}
	var json := JSON.stringify(result, "\t")
	_read_results_buffer.append({"tool": "get_2d_scene_tree", "args": {}, "output": json})
	return "[get_2d_scene_tree] %d node(s) in '%s'\n%s" % [info.size(), path, json]


func _do_load_2d_scene(d: Dictionary) -> String:
	var host = _get_plugin()
	if host == null:
		return "[load_2d_scene] host plugin not found"
	if not ("_vg_2d_editor" in host) or not is_instance_valid(host.get("_vg_2d_editor")):
		return "[load_2d_scene] 2D editor not ready"
	var ed = host.get("_vg_2d_editor")
	var path: String = str(d.get("path", "")).strip_edges()
	if path.is_empty():
		return "[load_2d_scene] missing 'path'"
	if not ed.has_method("load_scene"):
		return "[load_2d_scene] load_scene not found"
	ed.load_scene(path)
	return "[load_2d_scene] loaded '%s'" % path


# ---------------------------------------------------------------------------
# Plugin tools — 3D Scene
# ---------------------------------------------------------------------------

func _do_get_3d_scene() -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[get_3d_scene] plugin manager not found"
	var vg3d = pm.get_plugin("vg3d")
	if vg3d == null:
		return "[get_3d_scene] vg3d plugin not loaded"
	if not vg3d.has_method("get_project_data"):
		return "[get_3d_scene] get_project_data not available (vg3d plugin needs update)"
	var data: Dictionary = vg3d.get_project_data()
	var json := JSON.stringify(data, "\t")
	_read_results_buffer.append({"tool": "get_3d_scene", "args": {}, "output": json})
	return "[get_3d_scene] %d block(s)\n%s" % [data.get("blocks", []).size(), json]


func _do_load_3d_scene(d: Dictionary) -> String:
	var pm = _get_plugin_manager()
	if pm == null:
		return "[load_3d_scene] plugin manager not found"
	var vg3d = pm.get_plugin("vg3d")
	if vg3d == null:
		return "[load_3d_scene] vg3d plugin not loaded"
	if not vg3d.has_method("set_project_data"):
		return "[load_3d_scene] set_project_data not available (vg3d plugin needs update)"
	var data = d.get("data", null)
	if typeof(data) != TYPE_DICTIONARY:
		return "[load_3d_scene] missing 'data' dict with 'blocks' array"
	vg3d.set_project_data(data)
	return "[load_3d_scene] applied %d block(s)" % data.get("blocks", []).size()


# ---------------------------------------------------------------------------
# Editor / safe-write lookups
# ---------------------------------------------------------------------------

func _get_plugin_manager():
	var p := _get_plugin()
	if p == null:
		return null
	if not ("_vg_plugin_manager" in p):
		return null
	var pm = p.get("_vg_plugin_manager")
	if pm == null or not is_instance_valid(pm):
		return null
	return pm


func _get_plugin() -> Object:
	if not Engine.is_editor_hint():
		return null
	# EditorInterface may not be initialised in script-only / headless
	# runs (e.g. test harnesses).  Guard so we never crash here.
	if not OS.has_feature("editor"):
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


## Path of the file currently open in the embedded editor, or "" if none.
func _active_editor_path() -> String:
	var ece := _get_embedded_editor()
	if ece == null or not ece.has_method("get_file_path"):
		return ""
	return str(ece.get_file_path())


## Buffer-editing tools (insert_text/replace_range/replace_in_buffer/
## set_buffer_text) don't address a file directly -- they always act on
## whatever's open in the embedded editor. If the call includes an
## optional "path" safety-check field and it doesn't match what's
## actually open, return a clear, actionable error string instead of
## silently editing nothing or the wrong file. Returns "" when there's
## no mismatch (either no "path" was given, or it matches).
func _check_active_path(d: Dictionary) -> String:
	var target := str(d.get("path", "")).strip_edges()
	if target.is_empty():
		return ""
	var active := _active_editor_path()
	if active.is_empty():
		return ""
	if active.strip_edges().to_lower() == target.to_lower():
		return ""
	return ("target file mismatch: the currently open editor is '%s', not '%s' -- " +
		"use write_file(path=\"%s\", contents=...) instead, it always targets " +
		"the right file regardless of what's open") % [active, target, target]


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
