#!/usr/bin/env -S godot --headless --script
extends SceneTree

# Multi-preset persistence test for Make EXE…
# Verifies that `_collect_other_presets(exclude_name)` correctly:
#   - parses every [preset.N] block,
#   - extracts the quoted `name=`,
#   - keeps presets whose name != exclude_name,
#   - drops the active preset.
#
# We can't easily instantiate the whole EditorPlugin in headless mode,
# so we use a duck-typed reimplementation that mirrors the function in
# visual_gasic_plugin.gd ~L6371. If the production function ever
# diverges, this test will need to be re-synced.

var _failures: Array[String] = []

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK   ", msg)
	else:
		print("  FAIL ", msg)
		_failures.append(msg)

func _collect_other_presets_from_text(text: String, exclude_name: String) -> Array:
	var lines := text.split("\n")
	var i := 0
	var result: Array = []
	while i < lines.size():
		var ln := String(lines[i]).strip_edges()
		var is_header := ln.begins_with("[preset.") and ln.ends_with("]") and not ln.ends_with(".options]")
		if not is_header:
			i += 1
			continue
		i += 1
		var head_body := ""
		var name_in_block := ""
		while i < lines.size():
			var l2 := String(lines[i])
			if l2.strip_edges().begins_with("["):
				break
			head_body += l2 + "\n"
			var stripped := l2.strip_edges()
			if stripped.begins_with("name="):
				var rhs := stripped.substr(5).strip_edges()
				if rhs.length() >= 2 and rhs.begins_with("\"") and rhs.ends_with("\""):
					name_in_block = rhs.substr(1, rhs.length() - 2)
				else:
					name_in_block = rhs
			i += 1
		var opts_body := ""
		if i < lines.size():
			var next_hdr := String(lines[i]).strip_edges()
			if next_hdr.begins_with("[preset.") and next_hdr.ends_with(".options]"):
				i += 1
				while i < lines.size():
					var l3 := String(lines[i])
					if l3.strip_edges().begins_with("["):
						break
					opts_body += l3 + "\n"
					i += 1
		if name_in_block != exclude_name and name_in_block != "":
			result.append([head_body, opts_body, name_in_block])
	return result

func _initialize() -> void:
	print("=== multi-preset persistence test ===")

	# Synthetic cfg with three presets: Linux, Windows, Web.
	var cfg := """[preset.0]

name=\"Linux/X11\"
platform=\"Linux/X11\"
runnable=true
export_path=\"build/game.x86_64\"

[preset.0.options]

binary_format/embed_pck=false

[preset.1]

name=\"Windows Desktop\"
platform=\"Windows Desktop\"
runnable=true
export_path=\"build/game.exe\"

[preset.1.options]

application/icon=\"\"

[preset.2]

name=\"Web\"
platform=\"Web\"
runnable=true
export_path=\"build/web/index.html\"

[preset.2.options]

html/canvas_resize_policy=2
"""

	# (1) Exclude Linux → keep Windows + Web (in order)
	var keep_excl_linux := _collect_other_presets_from_text(cfg, "Linux/X11")
	_ok(keep_excl_linux.size() == 2, "exclude Linux: 2 kept (got %d)" % keep_excl_linux.size())
	if keep_excl_linux.size() == 2:
		_ok(keep_excl_linux[0][2] == "Windows Desktop", "exclude Linux: first kept is Windows (got '%s')" % keep_excl_linux[0][2])
		_ok(keep_excl_linux[1][2] == "Web", "exclude Linux: second kept is Web (got '%s')" % keep_excl_linux[1][2])
		_ok(keep_excl_linux[0][0].find("platform=\"Windows Desktop\"") >= 0, "Windows header_body retained platform")
		_ok(keep_excl_linux[1][1].find("html/canvas_resize_policy=2") >= 0, "Web options_body retained html setting")

	# (2) Exclude Web → keep Linux + Windows
	var keep_excl_web := _collect_other_presets_from_text(cfg, "Web")
	_ok(keep_excl_web.size() == 2, "exclude Web: 2 kept (got %d)" % keep_excl_web.size())
	if keep_excl_web.size() == 2:
		_ok(keep_excl_web[0][2] == "Linux/X11", "exclude Web: first kept is Linux")
		_ok(keep_excl_web[1][2] == "Windows Desktop", "exclude Web: second kept is Windows")

	# (3) Exclude a name not in file → all three kept
	var keep_excl_none := _collect_other_presets_from_text(cfg, "macOS")
	_ok(keep_excl_none.size() == 3, "exclude unknown: 3 kept (got %d)" % keep_excl_none.size())

	# (4) Empty cfg → empty result
	var keep_empty := _collect_other_presets_from_text("", "Anything")
	_ok(keep_empty.size() == 0, "empty cfg: 0 kept")

	# (5) Cfg with only the active preset → empty result
	var single := "[preset.0]\n\nname=\"Windows Desktop\"\nplatform=\"Windows Desktop\"\n\n[preset.0.options]\n\nfoo=bar\n"
	var keep_only_active := _collect_other_presets_from_text(single, "Windows Desktop")
	_ok(keep_only_active.size() == 0, "only active: 0 kept")

	print("=== %d failure(s) ===" % _failures.size())
	for m in _failures:
		print("    !! ", m)
	quit(0 if _failures.is_empty() else 1)
