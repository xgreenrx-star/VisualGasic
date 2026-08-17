@tool
extends RefCounted
## Project-spec — Narcea's chat-to-runnable-project scaffolder.
##
## v1 keeps things sandboxed: every project lives in a subdirectory
## under res://ai_projects/<name>/.  This dodges cross-Godot-instance
## coordination — the user's existing editor stays in charge, and the
## ▶ Run button (vg_ai_run_session) launches the project's main_scene
## with the same Godot binary that's already running.
##
## Schema (fenced as ```vg-project-spec):
##
##   {
##     "project_name": "PongClone",      // required, sanitised to identifier
##     "subdir":       "ai_projects",    // optional; default = "ai_projects"
##     "main_scene":   "frmGame.tscn",   // optional; relative to project root
##     "godot_version":"4.6",            // advisory only (current editor wins)
##     "forms":   [ ...vg-form-spec dicts... ],  // optional
##     "files":   [ {path, source}, ... ],       // optional code-spec files
##     "autoloads":[ {name, path}, ...]          // optional
##   }
##
## Apply order (each step is best-effort, errors do not abort):
##   1. mkdir res://ai_projects/<name>/
##   2. write a project.json manifest (so we can re-open later)
##   3. for each form  -> apply via vg_ai_form_spec.gd against a sandbox
##                        FormDesigner; save .tscn under project root
##   4. for each file  -> safe_write into project root
##   5. write a README.md explaining provenance
##   6. rescan resource filesystem
##
## NOTE: real cross-project Godot bootstrapping (separate project.godot
## with its own addons/) is on the roadmap but deferred to v2 — v1 is
## the stepping stone that already lets Narcea build a runnable thing
## from chat alone.

const CODE_FENCE_RE := "```vg-project-spec\\s*([\\s\\S]*?)```"
const DEFAULT_SUBDIR := "ai_projects"


func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(CODE_FENCE_RE)
	var m := rx.search(response_text)
	var raw := ""
	if m != null:
		raw = m.get_string(1).strip_edges()
	else:
		# Tolerate replies where the model opened ```vg-project-spec but
		# never closed the fence (truncation, max_tokens, or just plain
		# laziness — Anthropic's claude-sonnet-4-5 does this often when
		# the JSON body is large). Slurp from the open fence to EOF and
		# try to recover.
		var open_idx := response_text.find("```vg-project-spec")
		if open_idx < 0:
			return {}
		var body_start := response_text.find("\n", open_idx)
		if body_start < 0:
			return {}
		raw = response_text.substr(body_start + 1).strip_edges()
		# Drop any trailing fence remnants.
		var fence_end := raw.rfind("```")
		if fence_end >= 0:
			raw = raw.substr(0, fence_end).strip_edges()
		# If JSON is truncated, try to balance it by trimming to the
		# last full closing brace.
		var last_brace := raw.rfind("}")
		if last_brace >= 0 and last_brace < raw.length() - 1:
			raw = raw.substr(0, last_brace + 1)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Try to close truncated JSON (common when Gemini stops mid-fence).
		var balanced := _balance_truncated_json(raw)
		if not balanced.is_empty():
			parsed = JSON.parse_string(balanced)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Last-ditch: trim each trailing char until JSON parses or we
		# give up. Bounded so we don't loop forever on garbage.
		var attempts := 0
		var trim := raw
		while typeof(parsed) != TYPE_DICTIONARY and attempts < 200 and trim.length() > 32:
			trim = trim.substr(0, trim.length() - 1).strip_edges()
			# Heuristic: only retry when we end on a closing brace.
			if trim.ends_with("}"):
				parsed = JSON.parse_string(trim)
			attempts += 1
		if typeof(parsed) != TYPE_DICTIONARY:
			var balanced2 := _balance_truncated_json(raw)
			if not balanced2.is_empty():
				parsed = JSON.parse_string(balanced2)
		if typeof(parsed) != TYPE_DICTIONARY:
			return {}
	parsed = normalize_spec(parsed)
	if not parsed.has("project_name"):
		return {}
	return parsed


## Tolerate common LLM schema drift (Gemini often uses `name`, `contents`,
## PascalCase control props, etc.).
func normalize_spec(parsed: Dictionary) -> Dictionary:
	var out: Dictionary = parsed.duplicate(true)
	if not out.has("project_name"):
		if out.has("name"):
			out["project_name"] = out["name"]
		elif out.has("title"):
			out["project_name"] = out["title"]
	if out.has("root_dir"):
		var rd: String = str(out["root_dir"]).strip_edges().trim_suffix("/")
		if rd.begins_with("res://"):
			var tail := rd.substr(6)
			if tail.begins_with("ai_projects/"):
				out["subdir"] = "ai_projects"
				var pname := tail.get_file()
				if not pname.is_empty() and str(out.get("project_name", "")).is_empty():
					out["project_name"] = pname
	var files: Array = out.get("files", [])
	var norm_files: Array = []
	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var copy: Dictionary = entry.duplicate()
		if not copy.has("source"):
			if copy.has("contents"):
				copy["source"] = copy["contents"]
			elif copy.has("content"):
				copy["source"] = copy["content"]
		norm_files.append(copy)
	out["files"] = norm_files
	var project_auto: bool = bool(out.get("auto_events", false))
	var forms: Array = out.get("forms", [])
	var norm_forms: Array = []
	for f in forms:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var nf: Dictionary = _normalize_form_dict(f)
		if project_auto and not nf.has("auto_events"):
			nf["auto_events"] = true
		norm_forms.append(nf)
	out["forms"] = norm_forms
	return out


func _normalize_form_dict(form: Dictionary) -> Dictionary:
	var out: Dictionary = form.duplicate(true)
	if not out.has("form_name"):
		if out.has("name"):
			out["form_name"] = out["name"]
		elif out.has("title"):
			out["form_name"] = out["title"]
	if not out.has("form_size"):
		if out.has("width") and out.has("height"):
			out["form_size"] = [float(out["width"]), float(out["height"])]
	var controls: Array = out.get("controls", [])
	var norm_controls: Array = []
	for c in controls:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		norm_controls.append(_normalize_control_dict(c))
	out["controls"] = norm_controls
	return out


func _normalize_control_dict(ctrl: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in ctrl.keys():
		var lk: String = str(key).to_lower()
		var val = ctrl[key]
		match lk:
			"caption":
				out["caption"] = val
				if not out.has("text"):
					out["text"] = val
			"text":
				out["text"] = val
			_:
				out[lk] = val
	return out


func describe(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var name: String = str(spec.get("project_name", "Project"))
	var nf: int = (spec.get("forms", []) as Array).size()
	var nc: int = (spec.get("files", []) as Array).size()
	return "Project '%s' (%d form(s), %d file(s))" % [name, nf, nc]


## Compute the absolute res:// root for this project.  Pure function — no
## side effects.  Useful for the diff dialog.
##
## Special case: `subdir == "."` (or `"/"`, `"res://"`) means "scaffold in
## place at the current project's root" — used when the welcome shell has
## already created a fresh empty project for Narcea to fill in. In that
## mode the project_name is advisory only (it goes into the manifest /
## README); files land directly under res://.
func project_root(spec: Dictionary) -> String:
	var subdir := str(spec.get("subdir", DEFAULT_SUBDIR))
	if subdir == "." or subdir == "/" or subdir == "res://" or subdir == "./":
		return "res://"
	if subdir.is_empty():
		subdir = DEFAULT_SUBDIR
	var name := _safe_identifier(str(spec.get("project_name", "Project")), "Project")
	return "res://%s/%s/" % [subdir, name]


## Normalize a file path for scaffolding under `root`.
##   • bare relative ("Form1.vg") -> root + path
##   • already inside root -> unchanged
##   • stray res:// ("res://MainForm.vg") -> root + basename
func rebase_path(path: String, root: String, safe_writer = null) -> String:
	var p: String = path.strip_edges()
	if p.is_empty():
		return p
	if not (p.begins_with("res://") or p.begins_with("user://") or p.begins_with("/")):
		return root + p.lstrip("/")
	if safe_writer != null:
		var safety: Array = safe_writer.is_safe(p)
		if safety[0]:
			return p
	elif p.begins_with(root):
		return p
	if p.begins_with("res://"):
		var fname: String = p.get_file()
		if fname.is_empty():
			return root
		return root + fname
	return p

## Apply the spec.  `helpers` is a Dictionary holding lazy refs the
## panel already has:
##   {
##     "safe_writer": <vg_ai_safe_write instance>,
##     "code_spec":   <vg_ai_code_spec instance>,
##     "form_spec":   <vg_ai_form_spec instance>,
##     "designer":    <FormDesigner node, optional>,
##   }
##
## Returns:
##   {
##     ok: bool,
##     root: String,           # res:// path, e.g. res://ai_projects/Pong/
##     written: [String],
##     skipped: [{path, reason}],
##     summary: String,
##     main_scene: String,     # res:// absolute, "" if none
##   }
func apply(spec: Dictionary, helpers: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"root": "",
		"written": [],
		"skipped": [],
		"summary": "",
		"main_scene": "",
	}
	if spec.is_empty():
		result["summary"] = "No project spec to apply."
		return result
	var safe_writer = helpers.get("safe_writer")
	if safe_writer == null:
		result["summary"] = "Safe-writer unavailable."
		return result
	var root := project_root(spec)
	# Re-target safe_writer so writes are constrained to the project dir.
	# Caller is responsible for restoring the previous root after apply().
	safe_writer.set_root(root)
	result["root"] = root

	# 1. Write manifest (main_scene rebased to scaffold root).
	var main_scene_raw := str(spec.get("main_scene", ""))
	var main_scene_manifest := rebase_path(main_scene_raw, root, safe_writer) if not main_scene_raw.is_empty() else ""
	var manifest := {
		"project_name": spec.get("project_name", "Project"),
		"created_by":   "Narcea / VG_AI",
		"created_at":   Time.get_datetime_string_from_system(),
		"main_scene":   main_scene_manifest,
		"godot_version":spec.get("godot_version", ""),
	}
	var mres: Array = safe_writer.write(root + "project.json", JSON.stringify(manifest, "  "))
	if mres[0]:
		result["written"].append(root + "project.json")
	else:
		result["skipped"].append({"path": root + "project.json", "reason": str(mres[1])})

	# 2. Forms — apply each via vg_ai_form_spec against the FormDesigner.
	#    The designer is shared with the user's main project (sandboxing
	#    forms in a separate designer instance is a v2 task), so we save
	#    each form to <root>/<form_name>.tscn explicitly.
	var form_spec = helpers.get("form_spec")
	var designer = helpers.get("designer")
	var forms: Array = spec.get("forms", [])
	var designer_saved: PackedStringArray = PackedStringArray()
	for f in forms:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		if form_spec == null or designer == null or not is_instance_valid(designer):
			result["skipped"].append({
				"path": root + str(f.get("form_name", "Form")) + ".tscn",
				"reason": "form designer unavailable",
			})
			continue
		var fname := _safe_identifier(str(f.get("form_name", "Form1")), "Form1")
		var tscn := root + fname + ".tscn"
		form_spec.apply_to_designer(f, designer)
		var safety: Array = safe_writer.is_safe(tscn)
		if not safety[0]:
			result["skipped"].append({"path": tscn, "reason": str(safety[1])})
			continue
		_mkdir_for_path(tscn)
		if designer.has_method("save_form_as"):
			designer.save_form_as(tscn)
		if _tscn_is_valid(tscn):
			if tscn not in result["written"]:
				result["written"].append(tscn)
			var saved_key := fname.to_lower()
			if not designer_saved.has(saved_key):
				designer_saved.append(saved_key)
		else:
			result["skipped"].append({
				"path": tscn,
				"reason": "Form Designer did not produce a scene file",
			})
		# Generate event stubs into the matching .vg.
		var vg_path := root + fname + ".vg"
		var existing: String = safe_writer.read(vg_path)
		if form_spec.has_method("generate_event_stubs"):
			var stubs: String = form_spec.generate_event_stubs(f, existing)
			if not stubs.is_empty():
				var contents: String = existing
				if contents.is_empty():
					contents = "' Visual Gasic Form Script\nOption Explicit\n"
				while contents.ends_with("\n\n"):
					contents = contents.substr(0, contents.length() - 1)
				if not contents.ends_with("\n"):
					contents += "\n"
				contents += stubs
				var vres: Array = safe_writer.write(vg_path, contents)
				if vres[0]:
					result["written"].append(vg_path)
				else:
					result["skipped"].append({"path": vg_path, "reason": str(vres[1])})

	# 2b. Re-save .tscn after .vg files land so ext_resource paths/UIDs match.
	if form_spec != null and designer != null and is_instance_valid(designer) \
			and designer.has_method("save_form_as"):
		for f in forms:
			if typeof(f) != TYPE_DICTIONARY:
				continue
			var fname_resave := _safe_identifier(str(f.get("form_name", "Form1")), "Form1")
			var tscn_resave := root + fname_resave + ".tscn"
			var safety_resave: Array = safe_writer.is_safe(tscn_resave)
			if not safety_resave[0]:
				continue
			_mkdir_for_path(tscn_resave)
			designer.save_form_as(tscn_resave)
			if _tscn_is_valid(tscn_resave) and tscn_resave not in result["written"]:
				result["written"].append(tscn_resave)

	# 3. Loose code/asset files via the code-spec applier (rebound to
	#    the project root).  Reuse the same safe_writer.
	var code_spec = helpers.get("code_spec")
	var files: Array = spec.get("files", [])
	if code_spec != null and not files.is_empty():
		var sub_spec := {"files": []}
		for entry in files:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var p: String = rebase_path(str(entry.get("path", "")), root, safe_writer)
			if _skip_scaffold_file(p, spec, designer_saved):
				result["skipped"].append({
					"path": p,
					"reason": "skipped LLM .tscn — Form Designer owns form scenes",
				})
				continue
			var copy: Dictionary = entry.duplicate()
			copy["path"] = p
			if p.ends_with(".tscn"):
				copy["source"] = _rebase_tscn_script_paths(str(entry.get("source", "")), root)
			(sub_spec["files"] as Array).append(copy)
		var cres: Dictionary = code_spec.apply(sub_spec, safe_writer, false)
		for w in cres.get("written", []):
			result["written"].append(w)
		for s in cres.get("skipped", []):
			result["skipped"].append(s)

	# 3b. Fix script ext_resource paths in any .tscn written under root.
	for w in result["written"]:
		var wp := str(w)
		if not wp.ends_with(".tscn"):
			continue
		_repair_tscn_file(wp, root, safe_writer, result)

	# 3c. Repair any .tscn already on disk under root (stale LLM paths).
	_repair_tscn_tree(root, root, safe_writer, result)

	# 3d. Ensure every form .vg has a loadable paired .tscn.
	_ensure_form_tscn_files(root, spec, safe_writer, form_spec, designer, result)

	# 4. README so a human can find their way around later.
	var readme := _readme_for(spec)
	var rres: Array = safe_writer.write(root + "README.md", readme)
	if rres[0]:
		result["written"].append(root + "README.md")

	# 5. Resolve main_scene to an absolute res:// path the run session
	#    can launch.
	var main_scene := str(spec.get("main_scene", ""))
	if not main_scene.is_empty():
		main_scene = rebase_path(main_scene, root, safe_writer)
		result["main_scene"] = main_scene
		# Persist to ProjectSettings so ▶ Run Main Scene (F5/Ctrl+F5)
		# and Godot's own Play button know what to launch. Without this
		# the freshly-scaffolded project has no main_scene set and the
		# user sees nothing happen on Run.
		if Engine.is_editor_hint():
			ProjectSettings.set_setting("application/run/main_scene", main_scene)
			ProjectSettings.save()

	# 6. Rescan FS so the file browser sees the new files.
	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem():
		var fs := EditorInterface.get_resource_filesystem()
		for w in result["written"]:
			var wp := str(w)
			if wp.begins_with("res://") and FileAccess.file_exists(wp):
				fs.call_deferred("update_file", wp)
		fs.call_deferred("scan")

	result["ok"] = result["written"].size() > 0
	result["summary"] = "scaffolded %s — wrote %d, skipped %d" % [
		root, result["written"].size(), result["skipped"].size(),
	]
	return result


# --- helpers ---------------------------------------------------------------


## Close truncated LLM JSON by trimming a dangling partial field and
## appending missing ] / } in stack order.
func _balance_truncated_json(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return s
	s = _trim_incomplete_json_tail(s)
	var suffix := _json_closing_suffix(s)
	if suffix.is_empty():
		return s
	var attempt := s + suffix
	if typeof(JSON.parse_string(attempt)) == TYPE_DICTIONARY:
		return attempt
	return s


func _trim_incomplete_json_tail(s: String) -> String:
	var in_string := false
	var escape := false
	for i in s.length():
		var c: String = s[i]
		if escape:
			escape = false
			continue
		if c == "\\":
			escape = true
			continue
		if c == "\"":
			in_string = not in_string
	if in_string:
		s += "\""
	s = s.strip_edges()
	while s.length() > 0:
		var suffix := _json_closing_suffix(s)
		var attempt := s + suffix
		if typeof(JSON.parse_string(attempt)) == TYPE_DICTIONARY:
			return attempt
		var tail := s.strip_edges()
		var last := tail[-1]
		if last in [",", ":", " "]:
			s = tail.substr(0, tail.length() - 1)
			continue
		# Dangling key/value fragment (`"height"` or bare `height`) — trim to last comma.
		var last_comma := tail.rfind(",")
		if last_comma > 0:
			s = tail.substr(0, last_comma).strip_edges()
			continue
		var last_open := maxi(tail.rfind("{"), tail.rfind("["))
		if last_open >= 0 and last_open < tail.length() - 1:
			s = tail.substr(0, last_open + 1).strip_edges()
			continue
		break
	return s.strip_edges()


func _json_closing_suffix(s: String) -> String:
	var in_string := false
	var escape := false
	var stack: Array[String] = []
	for i in s.length():
		var c: String = s[i]
		if escape:
			escape = false
			continue
		if c == "\\":
			escape = true
			continue
		if c == "\"":
			in_string = not in_string
			continue
		if in_string:
			continue
		match c:
			"{": stack.append("}")
			"[": stack.append("]")
			"}":
				if not stack.is_empty() and stack.back() == "}":
					stack.pop_back()
			"]":
				if not stack.is_empty() and stack.back() == "]":
					stack.pop_back()
	var out := ""
	for j in range(stack.size() - 1, -1, -1):
		out += stack[j]
	return out


func _form_basenames(spec: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for f in spec.get("forms", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var fn := _safe_identifier(str(f.get("form_name", "Form1")), "Form1").to_lower()
		if not out.has(fn):
			out.append(fn)
	return out


## Skip LLM .tscn in files[] only when Form Designer already saved that form.
func _skip_scaffold_file(path: String, spec: Dictionary, designer_saved: PackedStringArray = PackedStringArray()) -> bool:
	if not path.get_file().to_lower().ends_with(".tscn"):
		return false
	if spec.get("forms", []).is_empty():
		return false
	var base := path.get_file().get_basename().to_lower()
	return designer_saved.has(base)


## Rewrite ext_resource script paths inside LLM-authored .tscn text.
func _rebase_tscn_script_paths(source: String, root: String) -> String:
	if source.is_empty():
		return source
	var rx := RegEx.new()
	if rx.compile("path=\"(res://[^\"]+\\.vg)\"") != OK:
		return source
	var out := source
	var offset := 0
	while true:
		var m := rx.search(out, offset)
		if m == null:
			break
		var old_p := m.get_string(1)
		var new_p := rebase_path(old_p, root, null)
		if new_p != old_p:
			out = out.substr(0, m.get_start(1)) + new_p + out.substr(m.get_end(1))
			offset = m.get_start(1) + new_p.length()
		else:
			offset = m.get_end(0)
	return out


## Fix one .tscn's ext_resource .vg paths; append to written when changed.
func _repair_tscn_file(path: String, root: String, safe_writer, result: Dictionary) -> void:
	var text: String = safe_writer.read(path)
	if text.is_empty() and FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	var fixed: String = _rebase_tscn_script_paths(text, root)
	if fixed == text:
		return
	var fix_res: Array = safe_writer.write(path, fixed)
	if fix_res[0]:
		if path not in result["written"]:
			result["written"].append(path)
	else:
		result["skipped"].append({"path": path, "reason": str(fix_res[1])})


## Walk `scan_root` recursively and repair every .tscn under scaffold `root`.
func _repair_tscn_tree(scan_root: String, root: String, safe_writer, result: Dictionary) -> void:
	var dir := DirAccess.open(scan_root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := scan_root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and name != ".godot":
				_repair_tscn_tree(full, root, safe_writer, result)
		elif name.to_lower().ends_with(".tscn"):
			_repair_tscn_file(full, root, safe_writer, result)
		name = dir.get_next()
	dir.list_dir_end()


func _tscn_is_valid(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text: String = FileAccess.get_file_as_string(path)
	return not text.strip_edges().is_empty() and text.find("[gd_scene") != -1


func _mkdir_for_path(res_path: String) -> void:
	var dir_abs := ProjectSettings.globalize_path(res_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir_abs)


func _minimal_form_tscn(vg_path: String, form_name: String) -> String:
	return "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]\n\n[node name=\"%s\" type=\"Window\"]\nscript = ExtResource(\"1_script\")\nmetadata/_vg_auto_events = true\n" % [vg_path, form_name]


## Create or replace missing/empty .tscn files paired with form .vg scripts.
func _ensure_form_tscn_files(root: String, spec: Dictionary, safe_writer, form_spec, designer, result: Dictionary) -> void:
	var form_specs_by_name: Dictionary = {}
	for f in spec.get("forms", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var fn := _safe_identifier(str(f.get("form_name", "Form1")), "Form1").to_lower()
		form_specs_by_name[fn] = f
	_ensure_tscn_tree(root, root, safe_writer, form_spec, designer, form_specs_by_name, result)


func _ensure_tscn_tree(scan_root: String, root: String, safe_writer, form_spec, designer, form_specs_by_name: Dictionary, result: Dictionary) -> void:
	var dir := DirAccess.open(scan_root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := scan_root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and name != ".godot":
				_ensure_tscn_tree(full, root, safe_writer, form_spec, designer, form_specs_by_name, result)
		elif name.to_lower().ends_with(".vg") and _looks_like_form_vg(full):
			var tscn_path := full.get_basename() + ".tscn"
			if not _tscn_is_valid(tscn_path):
				_create_missing_tscn(full, tscn_path, root, safe_writer, form_spec, designer, form_specs_by_name, result)
		name = dir.get_next()
	dir.list_dir_end()


func _looks_like_form_vg(path: String) -> bool:
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if text.is_empty():
		return false
	return text.find("Sub Form_Load") != -1 or text.find("Sub Form_") != -1 \
			or text.begins_with("VERSION ") or text.find("Begin VB.Form") != -1


func _create_missing_tscn(vg_path: String, tscn_path: String, root: String, safe_writer, form_spec, designer, form_specs_by_name: Dictionary, result: Dictionary) -> void:
	var form_name := vg_path.get_file().get_basename()
	var fn_lower := form_name.to_lower()
	if form_specs_by_name.has(fn_lower) and form_spec != null \
			and designer != null and is_instance_valid(designer):
		form_spec.apply_to_designer(form_specs_by_name[fn_lower], designer)
		_mkdir_for_path(tscn_path)
		if designer.has_method("save_form_as"):
			designer.save_form_as(tscn_path)
		if _tscn_is_valid(tscn_path):
			_repair_tscn_file(tscn_path, root, safe_writer, result)
			return
	var stub: String = _minimal_form_tscn(vg_path, form_name)
	var wres: Array = safe_writer.write(tscn_path, stub)
	if wres[0]:
		if tscn_path not in result["written"]:
			result["written"].append(tscn_path)
	else:
		result["skipped"].append({"path": tscn_path, "reason": str(wres[1])})


func _safe_identifier(s: String, fallback: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
				or (c >= "0" and c <= "9") or c == "_":
			out += c
	if out.is_empty():
		return fallback
	if out[0] >= "0" and out[0] <= "9":
		out = "_" + out
	return out


func _readme_for(spec: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# %s" % str(spec.get("project_name", "Project")))
	lines.append("")
	lines.append("Scaffolded by Narcea from a chat description on %s." % Time.get_datetime_string_from_system())
	lines.append("")
	if spec.has("main_scene"):
		lines.append("Main scene: `%s`" % str(spec.get("main_scene", "")))
		lines.append("")
	lines.append("Run with the AI panel's ▶ button or open the main scene and press F5.")
	lines.append("")
	lines.append("This directory was created by an AI agent and is not part of the")
	lines.append("VisualGasic IDE proper.  Edit, delete, or commit it freely.")
	return "\n".join(lines) + "\n"
