@tool
extends RefCounted
class_name VGAiProviderHealth
## Readiness checks for AI providers (used in the ⚙️ API keys dialog).

static func check_cursor() -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var ok := true

	var key: String = ""
	var Prov = load("res://addons/visual_gasic/vg_ai_providers.gd")
	if Prov != null:
		key = Prov.load_api_key("cursor")
	if key.is_empty():
		lines.append("❌ API key — not set (cursor.com/dashboard/integrations)")
		ok = false
	else:
		lines.append("✅ API key — configured")

	var CursorSession = load("res://addons/visual_gasic/vg_ai_cursor_session.gd")
	var python := ""
	if CursorSession != null:
		python = CursorSession.resolve_python()
	if python.is_empty():
		lines.append("❌ python3 — not found on PATH")
		ok = false
	else:
		lines.append("✅ python3 — %s" % python)

	if CursorSession != null and not python.is_empty():
		if CursorSession.cursor_sdk_available(python):
			lines.append("✅ cursor-sdk — importable")
		else:
			lines.append("❌ cursor-sdk — click Install in ⚙️ (system pip blocked on Linux)")
			ok = false

	var Handoff = load("res://addons/visual_gasic/vg_cursor_handoff.gd")
	var cli := ""
	if Handoff != null:
		cli = Handoff.resolve_cursor_cli()
	if cli.is_empty():
		lines.append("⚠ Cursor CLI — not found (Tier 1 ↗ handoff opens folder manually)")
	else:
		lines.append("✅ Cursor CLI — %s" % cli)

	var McpCfg = load("res://addons/visual_gasic/vg_cursor_mcp_config.gd")
	if McpCfg != null:
		var mcp_path: String = McpCfg.config_abs_path()
		if FileAccess.file_exists(mcp_path):
			lines.append("✅ MCP config — .cursor/mcp.json")
		else:
			lines.append("⚠ MCP config — not written yet (select Cursor provider or click ↗ Cursor)")
	else:
		lines.append("⚠ MCP config — module missing")

	return {"ok": ok, "lines": lines}


static func format_health_block(title: String, lines: PackedStringArray) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("[b]%s[/b]" % title)
	for line in lines:
		out.append("  " + line)
	return "\n".join(out)
