@tool
extends SceneTree
## Headless CLI helper for VisualGasic Package Manager.
## Invoked by `vg pkg <cmd>` via Godot --headless.
##
## Environment variables read:
##   VG_PKG_CMD     — "install" | "remove" | "search" | "list" | "info" | "init" | "update"
##   VG_PKG_ARG     — package name, search query, etc.
##   VG_PKG_VERSION — optional version constraint
##   VG_PKG_DIR     — project directory (defaults to cwd)

func _init() -> void:
	var cmd := OS.get_environment("VG_PKG_CMD")
	var arg := OS.get_environment("VG_PKG_ARG")
	var ver := OS.get_environment("VG_PKG_VERSION")
	var dir := OS.get_environment("VG_PKG_DIR")
	if dir.is_empty():
		dir = OS.get_environment("PWD")
	if dir.is_empty():
		dir = "."

	var pm = ClassDB.instantiate("VisualGasicPackage")
	if pm == null:
		print("ERROR: VisualGasicPackage class not available")
		quit(1)
		return

	pm.initialize(dir)

	match cmd:
		"install":
			_cmd_install(pm, arg, ver)
		"remove":
			_cmd_remove(pm, arg)
		"search":
			_cmd_search(pm, arg)
		"list":
			_cmd_list(pm)
		"info":
			_cmd_info(pm, arg, ver)
		"init":
			_cmd_init(pm, dir, arg)
		"update":
			_cmd_update(pm, arg, ver)
		_:
			print("ERROR: Unknown pkg command: " + cmd)
			quit(1)
			return

	pm.shutdown()
	quit(0)

# ── install ─────────────────────────────────────────────────────────────────
func _cmd_install(pm: Object, name: String, ver: String) -> void:
	if name.is_empty():
		# Install all dependencies from manifest
		var deps := pm.get_project_dependencies() as Dictionary
		if deps.is_empty():
			print("No dependencies found in project manifest.")
			return
		var result := pm.install_packages(deps.keys()) as Dictionary
		print("Installed " + str(result.get("installed_packages", []).size()) + " package(s).")
		return

	var result := pm.install_package(name, ver) as Dictionary
	if result.get("success", false):
		print("OK: " + name + " installed")
		if result.has("version"):
			print("  version: " + str(result["version"]))
	else:
		print("FAIL: " + str(result.get("message", "unknown error")))

# ── remove ──────────────────────────────────────────────────────────────────
func _cmd_remove(pm: Object, name: String) -> void:
	if name.is_empty():
		print("ERROR: Package name required")
		return
	if pm.uninstall_package(name):
		print("OK: " + name + " removed")
	else:
		print("FAIL: could not remove " + name)

# ── search ──────────────────────────────────────────────────────────────────
func _cmd_search(pm: Object, query: String) -> void:
	if query.is_empty():
		print("ERROR: Search query required")
		return
	var results := pm.search_packages(query) as Array
	if results.is_empty():
		print("No packages found for: " + query)
		return
	print("Found " + str(results.size()) + " package(s):")
	for pkg in results:
		var d := pkg as Dictionary
		print("  " + str(d.get("name", "?")) + " @ " + str(d.get("version", "?")) + "  — " + str(d.get("description", "")))

# ── list ────────────────────────────────────────────────────────────────────
func _cmd_list(pm: Object) -> void:
	var pkgs := pm.get_installed_packages() as Dictionary
	if pkgs.is_empty():
		print("No packages installed.")
		return
	print("Installed packages:")
	for name in pkgs:
		var info := pkgs[name] as Dictionary
		print("  " + str(name) + " @ " + str(info.get("version", "?")))

# ── info ────────────────────────────────────────────────────────────────────
func _cmd_info(pm: Object, name: String, ver: String) -> void:
	if name.is_empty():
		print("ERROR: Package name required")
		return
	var info := pm.get_package_info(name, ver) as Dictionary
	if info.is_empty():
		print("Package not found: " + name)
		return
	print("Package: " + str(info.get("name", name)))
	print("  Version:     " + str(info.get("version", "?")))
	print("  Description: " + str(info.get("description", "")))
	print("  Author:      " + str(info.get("author", "")))
	print("  License:     " + str(info.get("license", "")))
	if info.has("dependencies"):
		print("  Dependencies: " + str(info["dependencies"]))

# ── init ────────────────────────────────────────────────────────────────────
func _cmd_init(pm: Object, dir: String, name: String) -> void:
	if name.is_empty():
		name = dir.get_file()
		if name.is_empty():
			name = "my_vg_package"
	var result := pm.initialize_project(dir) as Dictionary
	if result.get("success", false):
		print("OK: Created vg.json in " + dir)
	else:
		# Fallback: create a minimal vg.json manually
		var manifest := {
			"name": name,
			"version": "1.0.0",
			"description": "",
			"author": "",
			"license": "MIT",
			"dependencies": {},
			"main": "main.vg"
		}
		var json_str := JSON.stringify(manifest, "  ")
		var path := dir.path_join("vg.json")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(json_str)
			f.close()
			print("OK: Created " + path)
		else:
			print("FAIL: Could not create vg.json")

# ── update ──────────────────────────────────────────────────────────────────
func _cmd_update(pm: Object, name: String, ver: String) -> void:
	if name.is_empty():
		var result := pm.update_all_packages() as Dictionary
		var count := (result.get("updated", []) as Array).size()
		print("Updated " + str(count) + " package(s).")
		return
	var result := pm.update_package(name, ver) as Dictionary
	if result.get("success", false):
		print("OK: " + name + " updated to " + str(result.get("version", "?")))
	else:
		print("FAIL: " + str(result.get("message", "unknown error")))
