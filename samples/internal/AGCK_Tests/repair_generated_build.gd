extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		push_error("Expected at most one generated-build directory.")
		quit(1)
		return
	var directory := args[0] if args.size() == 1 else "res://build/BLUE_SCREEN"
	quit(0 if repair(directory) else 1)

static func repair_fragment(code: String, shader_id: String) -> Dictionary:
	var comments := RegEx.new()
	comments.compile("/\\*[\\s\\S]*?\\*/|//[^\\n]*")
	var masked := code
	for comment in comments.search_all(code):
		masked = masked.substr(0, comment.get_start()) + " ".repeat(comment.get_end() - comment.get_start()) + masked.substr(comment.get_end())
	var fragment_start := masked.find("void fragment() {")
	if fragment_start < 0:
		return {"ok": false, "error": "Missing fragment processor in " + shader_id}
	var depth := 0
	var fragment_end := -1
	for i in range(masked.find("{", fragment_start), code.length()):
		if masked[i] == "{":
			depth += 1
		elif masked[i] == "}":
			depth -= 1
			if depth == 0:
				fragment_end = i
				break
	if fragment_end < 0:
		return {"ok": false, "error": "Unclosed fragment processor in " + shader_id}
	var returns := RegEx.new()
	returns.compile("\\breturn\\b")
	if returns.search(masked.substr(fragment_start, fragment_end - fragment_start + 1)) == null:
		return {"ok": true, "code": code, "changed": false}
	var fragment := code.substr(fragment_start, fragment_end - fragment_start + 1)
	var parameter := "glitch_intensity" if shader_id == "shader_glitch" else "shatter_progress"
	var guard := "\tif (%s < 0.001) { COLOR = texture(screen_texture, SCREEN_UV); return; }\n" % parameter
	if not fragment.contains(guard):
		return {"ok": false, "error": "Unsupported legacy fragment-return pattern in " + shader_id}
	if shader_id == "shader_shatter":
		var final_color := "\tCOLOR = vec4(texture(screen_texture, clamp(src, cmin, cmax)).rgb * max(0.0, 1.0 - t * 0.55), 1.0);"
		var outside := "\t\treturn;\n\t}\n" + final_color
		if not fragment.contains(outside):
			return {"ok": false, "error": "Unsupported shatter bounds-return pattern"}
		fragment = fragment.replace(outside, "\t} else {\n\t" + final_color + "\n\t}")
	var replacement := "\tif (%s < 0.001) {\n\t\tCOLOR = texture(screen_texture, SCREEN_UV);\n\t} else {\n" % parameter
	fragment = fragment.replace(guard, replacement)
	fragment = fragment.trim_suffix("}") + "\t}\n}"
	if returns.search(comments.sub(fragment, "", true)) != null:
		return {"ok": false, "error": "Unrepaired fragment return in " + shader_id}
	code = code.substr(0, fragment_start) + fragment + code.substr(fragment_end + 1)
	return {"ok": true, "code": code, "changed": true}

static func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: error %s" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		push_error("Cannot finish writing %s: error %s" % [path, error])
		return false
	return true

static func repair(directory: String) -> bool:
	var scene_path := directory.path_join("Main.tscn")
	if not FileAccess.file_exists(scene_path):
		push_error("Generated scene missing: %s. Run build_bluescreen.gd first." % scene_path)
		return false
	var scene_source := FileAccess.get_file_as_string(scene_path)
	if not scene_source.begins_with("[gd_scene "):
		push_error("Invalid generated scene header: " + scene_path)
		return false
	var lines := scene_source.split("\n")
	var shader_id := ""
	var changes := 0
	var found := 0
	for i in range(lines.size()):
		if lines[i].begins_with("[sub_resource "):
			shader_id = ""
			for name in ["shader_glitch", "shader_shatter"]:
				if lines[i].contains('id="%s"' % name):
					shader_id = name
		if shader_id.is_empty() or not lines[i].begins_with("code = "):
			continue
		var decoded: Variant = JSON.parse_string(lines[i].trim_prefix("code = "))
		if not decoded is String:
			push_error("Invalid shader code string in " + scene_path)
			return false
		var result := repair_fragment(decoded, shader_id)
		if not result["ok"]:
			push_error("%s: %s" % [scene_path, result["error"]])
			return false
		found += 1
		if result["changed"]:
			lines[i] = "code = " + JSON.stringify(result["code"])
			changes += 1
	if changes > 0 and not write_text(scene_path, "\n".join(lines)):
		return false
	print("Generated shaders: %s checked, %s repaired." % [found, changes])
	var script_path := directory.path_join("Main.vg")
	if not FileAccess.file_exists(script_path):
		push_error("Generated controller missing: " + script_path)
		return false
	if FileAccess.file_exists(script_path):
		var source := FileAccess.get_file_as_string(script_path)
		if source.strip_edges().is_empty():
			push_error("Empty or unreadable generated script: " + script_path)
			return false
		var stop_music := RegEx.new()
		stop_music.compile("(?im)^\\s*Sub\\s+StopAllMusic\\s*\\(")
		var exit_tree := RegEx.new()
		exit_tree.compile("(?im)^\\s*Sub\\s+_ExitTree\\s*\\(")
		if stop_music.search(source) != null and exit_tree.search(source) == null:
			source += "\nSub _ExitTree()\n\tStopAllMusic()\nEnd Sub\n"
			if not write_text(script_path, source):
				return false
			print("Added generated-game music teardown hook.")
	var bar_path := directory.path_join("InfectionBar.tscn")
	if FileAccess.file_exists(bar_path):
		var source := FileAccess.get_file_as_string(bar_path)
		var legacy_root := '[node name="InfectionBar" type="TextureProgressBar" parent="HUD"]'
		if source.begins_with(legacy_root):
			source = source.replace(legacy_root, '[gd_scene format=3]\n\n[node name="InfectionBar" type="ProgressBar"]')
			for obsolete in ["percent_visible = false\n", "under_texture = ExtResource(1)\n", "progress_texture = ExtResource(2)\n"]:
				source = source.replace(obsolete, "")
			if not write_text(bar_path, source):
				return false
			print("Converted legacy InfectionBar fragment to a standalone scene.")
		elif not source.begins_with("[gd_scene "):
			push_error("Unsupported InfectionBar scene fragment: " + bar_path)
			return false
	print("AGCK_GENERATED_REPAIR_COMPLETED")
	return true
