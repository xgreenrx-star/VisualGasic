@tool
extends RefCounted
class_name VGCursorHandoff
## Tier 1 — hand off Narcea / AI Pair context to Cursor (Composer).
##
## Writes `.vg/cursor_handoff.md`, copies a Composer-ready prompt to the
## clipboard, and launches `cursor` on the project folder when the CLI exists.
## Does not require Cursor to use VG — this path is optional.

const HANDOFF_REL := ".vg/cursor_handoff.md"
const MAX_HISTORY_TURNS := 3

## Full handoff: write context file, clipboard prompt, try to open Cursor.
## Returns { ok: bool, handoff_path: String, cursor_launched: bool, message: String }
static func perform_handoff(opts: Dictionary) -> Dictionary:
	var plugin: Object = opts.get("plugin")
	var persona_id: String = str(opts.get("persona_id", "narcea"))
	var draft: String = str(opts.get("draft_prompt", "")).strip_edges()
	var history: Array = opts.get("conversation_history", [])
	var query_hint := draft
	if query_hint.is_empty() and not history.is_empty():
		for i in range(history.size() - 1, -1, -1):
			var entry = history[i]
			if typeof(entry) == TYPE_DICTIONARY and str(entry.get("role", "")) == "user":
				query_hint = str(entry.get("content", "")).strip_edges()
				if not query_hint.is_empty():
					break

	var ctx := _collect_context(plugin, persona_id, query_hint, draft, history)
	var mcp_result: Dictionary = _ensure_mcp_config(ctx.project_root)
	ctx["mcp_config"] = mcp_result
	var write_result := _write_handoff_file(ctx)
	if not write_result.ok:
		return write_result

	var composer_prompt := _build_composer_prompt(ctx)
	DisplayServer.clipboard_set(composer_prompt)

	var launched := _launch_cursor(ctx)
	var msg := "Handoff written to %s.\nComposer prompt copied to clipboard." % write_result.handoff_path
	if bool(mcp_result.get("ok", false)):
		msg += "\n" + str(mcp_result.get("message", ""))
	if launched:
		msg += "\nOpened project in Cursor — paste into Composer (Ctrl+L / Cmd+L)."
	else:
		msg += "\nCursor CLI not found — open this folder in Cursor manually, then paste the prompt."
	return {
		"ok": true,
		"handoff_path": write_result.handoff_path,
		"cursor_launched": launched,
		"message": msg,
	}


static func _collect_context(
	plugin: Object,
	persona_id: String,
	query_hint: String,
	draft: String,
	history: Array
) -> Dictionary:
	var project_root := ProjectSettings.globalize_path("res://")
	var file_info := _detect_open_file(plugin)
	var open_res: String = file_info.open_res
	var open_abs: String = file_info.open_abs
	var caret_line: int = file_info.caret_line

	var narcea_block := ""
	var n_script = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	if n_script != null:
		var narcea = n_script.new()
		if narcea.has_method("set_query_hint"):
			narcea.set_query_hint(query_hint)
		if narcea.has_method("build_slim_context_block"):
			narcea_block = str(narcea.build_slim_context_block(plugin))
		elif narcea.has_method("build_context_block"):
			narcea_block = str(narcea.build_context_block(plugin))

	var history_md := _format_history_excerpt(history)
	var task := draft
	if task.is_empty() and not history_md.is_empty():
		task = _last_user_message(history)

	return {
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"persona_id": persona_id,
		"project_root": project_root,
		"open_file_res": open_res,
		"open_file_abs": open_abs,
		"caret_line": caret_line,
		"draft_prompt": draft,
		"task": task,
		"history_excerpt": history_md,
		"narcea_context": narcea_block,
		"last_assistant_excerpt": _last_assistant_excerpt(history),
		"focus_files": _focus_files_from_open(open_res),
	}


static func _focus_files_from_open(open_res: String) -> PackedStringArray:
	if open_res.is_empty():
		return PackedStringArray()
	return PackedStringArray([open_res])


static func _detect_open_file(plugin: Object) -> Dictionary:
	var open_res := ""
	var open_abs := ""
	var caret_line := 1
	if plugin == null or not is_instance_valid(plugin):
		return {"open_res": open_res, "open_abs": open_abs, "caret_line": caret_line}
	if not ("_embedded_code_editor" in plugin):
		return {"open_res": open_res, "open_abs": open_abs, "caret_line": caret_line}
	var ece = plugin.get("_embedded_code_editor")
	if ece == null or not is_instance_valid(ece):
		return {"open_res": open_res, "open_abs": open_abs, "caret_line": caret_line}
	if ece.has_method("get_file_path"):
		var fp := str(ece.get_file_path())
		if not fp.is_empty():
			open_res = fp if fp.begins_with("res://") else ("res://" + fp.trim_prefix("/"))
			open_abs = ProjectSettings.globalize_path(open_res)
	elif "current_file" in ece:
		var v = ece.get("current_file")
		if typeof(v) == TYPE_STRING and not v.is_empty():
			open_res = str(v)
			open_abs = ProjectSettings.globalize_path(open_res)
	if ece.has_method("get_code_edit"):
		var ce = ece.get_code_edit()
		if ce != null and is_instance_valid(ce) and ce.has_method("get_caret_line"):
			caret_line = int(ce.get_caret_line()) + 1
	return {"open_res": open_res, "open_abs": open_abs, "caret_line": caret_line}


static func _format_history_excerpt(history: Array) -> String:
	if history.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var turns := 0
	for i in range(history.size() - 1, -1, -1):
		if turns >= MAX_HISTORY_TURNS * 2:
			break
		var entry = history[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var role := str(entry.get("role", ""))
		var content := str(entry.get("content", "")).strip_edges()
		if content.is_empty():
			continue
		if content.length() > 1200:
			content = content.substr(0, 1200) + "\n…(truncated)"
		lines.insert(0, "**%s:**\n%s" % [role.capitalize(), content])
		turns += 1
	return "\n\n".join(lines)


static func _last_user_message(history: Array) -> String:
	for i in range(history.size() - 1, -1, -1):
		var entry = history[i]
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("role", "")) == "user":
			return str(entry.get("content", "")).strip_edges()
	return ""


static func _build_handoff_markdown(ctx: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("# Visual Gasic → Cursor handoff")
	parts.append("")
	parts.append("Generated from **Narcea AI Pair** in Godot (%s)." % ctx.timestamp_utc)
	parts.append("")
	parts.append("## Quick start in Cursor")
	parts.append("")
	parts.append("1. Open **Composer** (Ctrl+L / Cmd+L) — a prompt is already on your clipboard.")
	parts.append("2. Paste and send. Cursor loads project rules from `.cursor/rules/`.")
	parts.append("3. Enable **visual-gasic** MCP in Cursor → Settings → Tools & MCP (Godot must be running).")
	parts.append("")
	parts.append("## Project")
	parts.append("")
	parts.append("- Root: `%s`" % ctx.project_root)
	parts.append("- Persona in VG: `%s`" % ctx.persona_id)
	if not str(ctx.open_file_res).is_empty():
		parts.append("- Open file: `%s` (line %d)" % [ctx.open_file_res, ctx.caret_line])
	if not str(ctx.task).is_empty():
		parts.append("")
		parts.append("## Task")
		parts.append("")
		parts.append(str(ctx.task))
	if not str(ctx.history_excerpt).is_empty():
		parts.append("")
		parts.append("## Recent AI Pair conversation")
		parts.append("")
		parts.append(str(ctx.history_excerpt))
	if not str(ctx.narcea_context).is_empty():
		parts.append("")
		parts.append("## Narcea context snapshot (slim)")
		parts.append("")
		parts.append(str(ctx.narcea_context))
	var mcp: Variant = ctx.get("mcp_config")
	if typeof(mcp) == TYPE_DICTIONARY and bool(mcp.get("ok", false)):
		parts.append("")
		parts.append("## MCP")
		parts.append("")
		parts.append("- Config: `%s`" % str(mcp.get("path", ".cursor/mcp.json")))
		parts.append("- Server key: **visual-gasic** — enable in Cursor → Settings → Tools & MCP")
	parts.append("")
	parts.append("---")
	parts.append("*Re-run **Continue in Cursor** from AI Pair to refresh this file.*")
	return "\n".join(parts)


static func _build_composer_prompt(ctx: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var task := str(ctx.get("task", "")).strip_edges()
	var task_kind := _infer_task_kind(task)
	lines.append("Continuing from Visual Gasic Narcea AI Pair (Godot editor).")
	lines.append("Mode: %s" % task_kind)
	lines.append("")
	lines.append("Project: %s" % ctx.project_root)
	if not str(ctx.open_file_res).is_empty():
		lines.append("Start here: %s (line %d)" % [ctx.open_file_res, ctx.caret_line])
	var focus: PackedStringArray = ctx.get("focus_files", PackedStringArray())
	if focus.size() > 0:
		lines.append("Also review: " + ", ".join(focus))
	lines.append("")
	if not task.is_empty():
		lines.append("Task:")
		lines.append(task)
	else:
		lines.append("Task: (see .vg/cursor_handoff.md)")
	var last_asst := str(ctx.get("last_assistant_excerpt", "")).strip_edges()
	if not last_asst.is_empty():
		lines.append("")
		lines.append("Last AI Pair reply (excerpt):")
		lines.append(last_asst)
	lines.append("")
	lines.append("Follow `.cursor/rules/visual-gasic-godot.mdc`. Use `.vg` syntax in `.vg` files.")
	lines.append("Enable MCP **visual-gasic** in Cursor while Godot is running (.cursor/mcp.json).")
	return "\n".join(lines)


static func _infer_task_kind(task: String) -> String:
	var lower := task.to_lower()
	if lower.contains("fix") or lower.contains("bug") or lower.contains("error"):
		return "debug"
	if lower.contains("refactor") or lower.contains("clean up") or lower.contains("reorganiz"):
		return "refactor"
	if lower.contains("add ") or lower.contains("create") or lower.contains("implement") or lower.contains("build"):
		return "implement"
	return "general"


static func _last_assistant_excerpt(history: Array, max_chars: int = 800) -> String:
	for i in range(history.size() - 1, -1, -1):
		var entry = history[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("role", "")) != "assistant":
			continue
		var content := str(entry.get("content", "")).strip_edges()
		if content.is_empty():
			continue
		if content.length() > max_chars:
			return content.substr(0, max_chars) + "\n…(truncated)"
		return content
	return ""


static func _ensure_mcp_config(project_root: String) -> Dictionary:
	var McpCfg = load("res://addons/visual_gasic/vg_cursor_mcp_config.gd")
	if McpCfg == null:
		return {"ok": false, "message": "MCP config module missing."}
	return McpCfg.ensure_project_mcp_config(project_root)


static func _write_handoff_file(ctx: Dictionary) -> Dictionary:
	var project_root: String = ctx.project_root
	var abs_path := project_root.path_join(HANDOFF_REL)
	var dir_path := abs_path.get_base_dir()
	var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_err != OK and not DirAccess.dir_exists_absolute(dir_path):
		return {"ok": false, "handoff_path": abs_path, "message": "Could not create %s" % dir_path}

	var body := _build_handoff_markdown(ctx)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "handoff_path": abs_path, "message": "Could not write handoff file"}
	f.store_string(body)
	f.close()
	return {"ok": true, "handoff_path": abs_path}


static func resolve_cursor_cli() -> String:
	var output: Array = []
	var exit := OS.execute("bash", ["-lc", "command -v cursor 2>/dev/null || true"], output, true, false)
	if exit == 0 and output.size() > 0:
		var p := str(output[0]).strip_edges()
		if not p.is_empty() and FileAccess.file_exists(p):
			return p
	var fallbacks := [
		"/usr/bin/cursor",
		"/usr/local/bin/cursor",
		"/opt/Cursor/cursor",
	]
	if OS.get_name() == "macOS":
		fallbacks.append("/Applications/Cursor.app/Contents/Resources/app/bin/cursor")
	for path in fallbacks:
		if FileAccess.file_exists(path):
			return path
	return ""


static func _launch_cursor(ctx: Dictionary) -> bool:
	var cli := resolve_cursor_cli()
	if cli.is_empty():
		return false
	var project_root: String = ctx.project_root
	var args: PackedStringArray = PackedStringArray(["-n"])
	var open_abs: String = str(ctx.open_file_abs)
	var line: int = int(ctx.caret_line)
	if not open_abs.is_empty() and FileAccess.file_exists(open_abs):
		args.append("-g")
		if line > 0:
			args.append("%s:%d" % [open_abs, line])
		else:
			args.append(open_abs)
	args.append(project_root)
	var pid := OS.create_process(cli, args)
	return pid > 0
