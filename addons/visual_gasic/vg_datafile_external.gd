@tool
extends RefCounted
## Open DataFile assets in a user-configured external editor (Project Settings).

const SETTING_PATH := "vg/datafile/external_editor"
const LEGACY_TILED_PATH := "vg/datafile/tiled_executable"


static func get_configured_executable() -> String:
	for key in [SETTING_PATH, LEGACY_TILED_PATH]:
		var p := str(ProjectSettings.get_setting(key, "")).strip_edges()
		if not p.is_empty() and FileAccess.file_exists(p):
			return p
	return ""


static func open_file(abs_path: String) -> Dictionary:
	var out := {"ok": false, "message": ""}
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		out["message"] = "File not found."
		return out
	var exe := get_configured_executable()
	if not exe.is_empty():
		if _run_exe_with_file(exe, abs_path):
			out["ok"] = true
			out["message"] = "Opened in external editor."
		else:
			out["message"] = "Failed to launch: " + exe
		return out
	var err := OS.shell_open(abs_path)
	if err == OK:
		out["ok"] = true
		out["message"] = (
			"Opened with the system default app. "
			+ "For .vgd/binary files, set Project Settings → Vg → Datafile → External Editor."
		)
	else:
		out["message"] = (
			"No app associated with this file. "
			+ "Set Project Settings → Vg → Datafile → External Editor."
		)
	return out


static func _run_exe_with_file(exe: String, abs_path: String) -> bool:
	if exe.begins_with("flatpak run "):
		var app_id := exe.substr("flatpak run ".length()).strip_edges()
		return OS.execute("flatpak", ["run", app_id, abs_path], [], false) == 0
	if exe.contains(" ") and not exe.begins_with("/"):
		var parts: PackedStringArray = exe.split(" ", false)
		if parts.is_empty():
			return false
		var args: PackedStringArray = PackedStringArray()
		for idx in range(1, parts.size()):
			args.append(parts[idx])
		args.append(abs_path)
		return OS.execute(parts[0], args, [], false) == 0
	return OS.execute(exe, [abs_path], [], false) == 0
