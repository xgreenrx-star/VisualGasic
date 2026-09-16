@tool
extends RefCounted
class_name VGCursorMcpConfig
## Writes/merges `.cursor/mcp.json` so Cursor can reach VG MCP while Godot runs.
##
## Idempotent — safe to call on handoff and when activating the Cursor provider.

const SERVER_KEY := "visual-gasic"
const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 8766
const MCP_REL := ".cursor/mcp.json"


static func mcp_url(host: String = DEFAULT_HOST, port: int = DEFAULT_PORT) -> String:
	return "http://%s:%d/mcp" % [host, port]


static func config_abs_path(project_root: String = "") -> String:
	var root := project_root if not project_root.is_empty() else ProjectSettings.globalize_path("res://")
	return root.path_join(MCP_REL)


## Merge the VG MCP server entry into the project's `.cursor/mcp.json`.
## Returns { ok: bool, path: String, created: bool, updated: bool, message: String }
static func ensure_project_mcp_config(project_root: String = "", port: int = DEFAULT_PORT) -> Dictionary:
	var root := project_root if not project_root.is_empty() else ProjectSettings.globalize_path("res://")
	var abs_path := config_abs_path(root)
	var cursor_dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(cursor_dir):
		var err := DirAccess.make_dir_recursive_absolute(cursor_dir)
		if err != OK:
			return {
				"ok": false,
				"path": abs_path,
				"created": false,
				"updated": false,
				"message": "Could not create %s" % cursor_dir,
			}

	var created := not FileAccess.file_exists(abs_path)
	var root_obj: Dictionary = {"mcpServers": {}}
	if not created:
		var existing_text := _read_text(abs_path)
		if not existing_text.is_empty():
			var parsed = JSON.parse_string(existing_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				root_obj = parsed
			else:
				return {
					"ok": false,
					"path": abs_path,
					"created": false,
					"updated": false,
					"message": "Existing %s is not valid JSON — fix manually." % MCP_REL,
				}

	if typeof(root_obj.get("mcpServers")) != TYPE_DICTIONARY:
		root_obj["mcpServers"] = {}

	var servers: Dictionary = root_obj["mcpServers"]
	var entry := {
		"url": mcp_url(DEFAULT_HOST, port),
	}
	var updated := false
	if not servers.has(SERVER_KEY):
		updated = true
	else:
		var prev = servers[SERVER_KEY]
		if typeof(prev) != TYPE_DICTIONARY or str(prev.get("url", "")) != str(entry["url"]):
			updated = true
	servers[SERVER_KEY] = entry
	root_obj["mcpServers"] = servers

	var out := JSON.stringify(root_obj, "\t") + "\n"
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return {
			"ok": false,
			"path": abs_path,
			"created": created,
			"updated": false,
			"message": "Could not write %s" % abs_path,
		}
	f.store_string(out)
	f.close()

	var msg := "VG MCP configured in %s (%s)." % [MCP_REL, mcp_url(DEFAULT_HOST, port)]
	if created:
		msg += " Enable it in Cursor → Settings → Tools & MCP (requires Godot + Visual Gasic running)."
	elif updated:
		msg += " Updated existing entry."
	else:
		msg += " Already up to date."

	return {
		"ok": true,
		"path": abs_path,
		"created": created,
		"updated": updated,
		"message": msg,
	}


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
