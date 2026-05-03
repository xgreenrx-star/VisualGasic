@tool
extends RefCounted
## Safe-write chokepoint for AI-driven file mutation.
##
## Every code/project/form-spec applier funnels writes through here so we
## have one place that enforces:
##
##   * path is inside the chosen project root (resolved absolute, no ..
##     traversal allowed);
##   * path doesn't match any forbidden glob (the IDE plugin itself, .git,
##     .godot internals, the audit log itself);
##   * every write is appended to a per-session audit log so the user has
##     a paper trail of what Narcea touched.
##
## Reads are also logged (READ) so multi-step plans can be replayed.
##
## All callers receive [ok: bool, message: String] arrays — no exceptions.

# Glob patterns refused even when they're inside the project root.  Keep
# this tight: anything Narcea could clobber to brick the IDE goes here.
const FORBIDDEN_GLOBS := [
	"*/.git/*",
	"*/.godot/*",
	"*/addons/visual_gasic/*",
	"*/vg_ai_audit.log",
]

const AUDIT_PATH := "user://vg_ai_audit.log"

# Resolved absolute path of the allowed project root.  Defaults to the
# current res:// (the editor's project).  Project-spec scaffolding may
# narrow this further to e.g. res://ai_projects/<name>/.
var _root_abs: String = ""


func _init() -> void:
	set_root("res://")


## Reset the allowed write root.  Pass a res:// path or an absolute path.
## Empty string means "the current project's res://".
func set_root(root: String) -> void:
	if root.is_empty():
		root = "res://"
	_root_abs = _resolve(root).rstrip("/") + "/"


func get_root() -> String:
	return _root_abs


## Cheap check — same logic as write() runs but no I/O.
func is_safe(path: String) -> Array:
	if path.strip_edges().is_empty():
		return [false, "empty path"]
	var abs := _resolve(path)
	if abs.is_empty():
		return [false, "could not resolve path: %s" % path]
	# Reject parent traversal even if the resolved form happens to land
	# inside root (defence in depth).
	if path.find("..") != -1:
		return [false, "path contains '..': %s" % path]
	if not abs.begins_with(_root_abs):
		return [false, "outside project root (%s): %s" % [_root_abs, abs]]
	for pat in FORBIDDEN_GLOBS:
		if abs.matchn(pat):
			return [false, "forbidden path (matches %s): %s" % [pat, abs]]
	return [true, ""]


## Write a UTF-8 string.  Creates parent directories as needed.  Returns
## [ok, msg].  On success msg is "wrote N bytes to <path>"; on failure
## msg explains why (path rejected, FS error, etc.).
func write(path: String, contents: String) -> Array:
	var safety: Array = is_safe(path)
	if not safety[0]:
		_audit("BLOCK", path, 0, str(safety[1]))
		return [false, "refused: " + str(safety[1])]
	var dir := path.get_base_dir()
	if not dir.is_empty():
		var dir_abs := _resolve(dir)
		var derr := DirAccess.make_dir_recursive_absolute(dir_abs)
		if derr != OK and derr != ERR_ALREADY_EXISTS:
			_audit("ERROR", path, 0, "mkdir %s -> %s" % [dir_abs, derr])
			return [false, "could not create directory %s (err %d)" % [dir, derr]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var ferr := FileAccess.get_open_error()
		_audit("ERROR", path, 0, "open WRITE -> %s" % ferr)
		return [false, "could not open %s (err %d)" % [path, ferr]]
	f.store_string(contents)
	f.close()
	_audit("WRITE", path, contents.length(), "")
	return [true, "wrote %d bytes to %s" % [contents.length(), path]]


## Read a UTF-8 string.  Returns "" if the file doesn't exist or can't be
## opened — caller should check FileAccess.file_exists() if it cares.
## Logs a READ entry so audit trails match the actual access pattern.
func read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	_audit("READ", path, s.length(), "")
	return s


## Returns the contents of the audit log (newest entries last).  Used by
## the AI panel to print a summary when a multi-file plan completes.
func tail_audit(max_lines: int = 50) -> String:
	if not FileAccess.file_exists(AUDIT_PATH):
		return ""
	var f := FileAccess.open(AUDIT_PATH, FileAccess.READ)
	if f == null:
		return ""
	var all := f.get_as_text()
	f.close()
	var lines := all.split("\n")
	if lines.size() <= max_lines:
		return all
	return "\n".join(lines.slice(lines.size() - max_lines))


# --- internals -------------------------------------------------------------


func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _audit(action: String, path: String, size: int, note: String) -> void:
	# Open append-only.  If the file doesn't exist yet, the first WRITE
	# creates it via FileAccess.WRITE (truncate) then we'll append from
	# the second call onward via READ_WRITE + seek_end.
	var f: FileAccess
	if FileAccess.file_exists(AUDIT_PATH):
		f = FileAccess.open(AUDIT_PATH, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(AUDIT_PATH, FileAccess.WRITE)
	if f == null:
		return
	var line := "%s\t%s\t%d\t%s" % [
		Time.get_datetime_string_from_system(),
		action,
		size,
		path,
	]
	if not note.is_empty():
		line += "\t" + note
	f.store_line(line)
	f.close()
