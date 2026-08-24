@tool
extends RefCounted
## Locate Tiled Map Editor and offer one-click install hints.

const SETTING_PATH := "vg/datafile/tiled_executable"
const DOWNLOAD_URL := "https://www.mapeditor.org/download.html"
const FLATPAK_ID := "org.mapeditor.Tiled"


static func get_configured_executable() -> String:
	var p := str(ProjectSettings.get_setting(SETTING_PATH, "")).strip_edges()
	if not p.is_empty() and FileAccess.file_exists(p):
		return p
	return ""


static func find_executable() -> String:
	var cfg := get_configured_executable()
	if not cfg.is_empty():
		return cfg
	for name in ["tiled", "Tiled", "/usr/bin/tiled", "/usr/local/bin/tiled"]:
		if name.contains("/"):
			if FileAccess.file_exists(name):
				return name
		else:
			var p := _which(name)
			if not p.is_empty():
				return p
	if _flatpak_installed():
		return "flatpak run " + FLATPAK_ID
	return ""


static func is_available() -> bool:
	return not find_executable().is_empty()


static func open_file(abs_path: String) -> bool:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return false
	var exe := find_executable()
	if exe.is_empty():
		return false
	if exe.begins_with("flatpak run"):
		return OS.execute("flatpak", ["run", FLATPAK_ID, abs_path], [], false) == 0
	if exe.contains(" ") and not exe.begins_with("/"):
		var parts: PackedStringArray = exe.split(" ", false)
		var args: PackedStringArray = PackedStringArray()
		for idx in range(1, parts.size()):
			args.append(parts[idx])
		args.append(abs_path)
		return OS.execute(parts[0], args, [], false) == 0
	return OS.execute(exe, [abs_path], [], false) == 0


static func install_instructions() -> String:
	var os_name := OS.get_name()
	if os_name == "Linux":
		return (
			"Tiled is free from mapeditor.org.\n\n"
			+ "Easiest install (recommended):\n"
			+ "  flatpak install flathub org.mapeditor.Tiled\n\n"
			+ "Or: sudo apt install tiled   (Debian/Ubuntu)\n"
			+ "Or download the AppImage from:\n  " + DOWNLOAD_URL + "\n\n"
			+ "After install, click Detect Tiled or set Project Settings → Vg → Datafile → Tiled Executable."
		)
	if os_name == "Windows":
		return (
			"Install Tiled from:\n  " + DOWNLOAD_URL + "\n\n"
			+ "Or: winget install Tiled.Tiled\n\n"
			+ "Then set Project Settings → Vg → Datafile → Tiled Executable to Tiled.exe"
		)
	return "Download Tiled from " + DOWNLOAD_URL + " and set vg/datafile/tiled_executable in Project Settings."


static func try_detect_and_save() -> String:
	var found := find_executable()
	if found.is_empty():
		return ""
	ProjectSettings.set_setting(SETTING_PATH, found)
	ProjectSettings.save()
	return found


static func _which(name: String) -> String:
	var out: Array = []
	var code := OS.execute("which", [name], out, true)
	if code == 0 and not out.is_empty():
		return str(out[0]).strip_edges()
	return ""


static func _flatpak_installed() -> bool:
	var out: Array = []
	var code := OS.execute("flatpak", ["info", FLATPAK_ID], out, true)
	return code == 0
