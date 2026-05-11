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
			return {}
	if not parsed.has("project_name"):
		return {}
	return parsed


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

	# 1. Write manifest.
	var manifest := {
		"project_name": spec.get("project_name", "Project"),
		"created_by":   "Narcea / VG_AI",
		"created_at":   Time.get_datetime_string_from_system(),
		"main_scene":   spec.get("main_scene", ""),
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
		var fres: Array = form_spec.apply_to_designer(f, designer)
		if not fres[0]:
			result["skipped"].append({"path": tscn, "reason": str(fres[1])})
			continue
		# Save into the project subdir.  save_form_as can write outside
		# the safe-writer root because it uses the C++ side, so we
		# explicitly check is_safe() first.
		var safety: Array = safe_writer.is_safe(tscn)
		if not safety[0]:
			result["skipped"].append({"path": tscn, "reason": str(safety[1])})
			continue
		if designer.has_method("save_form_as"):
			designer.save_form_as(tscn)
			result["written"].append(tscn)
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

	# 3. Loose code/asset files via the code-spec applier (rebound to
	#    the project root).  Reuse the same safe_writer.
	var code_spec = helpers.get("code_spec")
	var files: Array = spec.get("files", [])
	if code_spec != null and not files.is_empty():
		var sub_spec := {"files": []}
		for entry in files:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var p := str(entry.get("path", ""))
			# If the model gave a bare relative path, prefix with root.
			if not (p.begins_with("res://") or p.begins_with("user://") or p.begins_with("/")):
				p = root + p
			var copy: Dictionary = entry.duplicate()
			copy["path"] = p
			(sub_spec["files"] as Array).append(copy)
		var cres: Dictionary = code_spec.apply(sub_spec, safe_writer, false)
		for w in cres.get("written", []):
			result["written"].append(w)
		for s in cres.get("skipped", []):
			result["skipped"].append(s)

	# 4. README so a human can find their way around later.
	var readme := _readme_for(spec)
	var rres: Array = safe_writer.write(root + "README.md", readme)
	if rres[0]:
		result["written"].append(root + "README.md")

	# 5. Resolve main_scene to an absolute res:// path the run session
	#    can launch.
	var main_scene := str(spec.get("main_scene", ""))
	if not main_scene.is_empty():
		if not main_scene.begins_with("res://"):
			main_scene = root + main_scene
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
		EditorInterface.get_resource_filesystem().scan()

	result["ok"] = result["written"].size() > 0
	result["summary"] = "scaffolded %s — wrote %d, skipped %d" % [
		root, result["written"].size(), result["skipped"].size(),
	]
	return result


# --- helpers ---------------------------------------------------------------


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
