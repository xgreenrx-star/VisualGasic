@tool
extends RefCounted
## Per-project expectation manifest. User actions (accept / reject /
## accept_current) update protected checks. Narcea can only propose.

const SCHEMA := "vg-expectations/1"
const MANIFEST_FILE := "vg_expectations.json"
const REFUSAL_TAIL := ". The expectation can only be changed with propose_expectation_change."

static var _root := ""
static var _manifest: Dictionary = {"schema": SCHEMA, "protected": []}
static var _loaded := false
static var _pending: Dictionary = {}
static var _seq := 0


func load_manifest(project_root: String) -> Dictionary:
	_root = _normalize_root(project_root)
	_loaded = false
	return _read_from_disk()


func ensure(_ignored: String = "") -> void:
	if _loaded:
		return
	_root = _normalize_root(ProjectSettings.globalize_path("res://"))
	_read_from_disk()


func is_protected(path: String) -> bool:
	if _root.is_empty():
		return false
	var abs_path := _to_abs(path)
	if abs_path.is_empty():
		return false
	if _same(abs_path, _manifest_abs()):
		return true
	for entry in _manifest.get("protected", []):
		var listed := str(entry.get("path", ""))
		if listed.is_empty():
			continue
		var listed_abs := _to_abs(listed)
		if listed.ends_with("/"):
			if _under(listed_abs, abs_path):
				return true
		elif _same(listed_abs, abs_path):
			return true
	return false


func status(path: String) -> String:
	if not is_protected(path):
		return "unprotected"
	var abs_path := _to_abs(path)
	var entry := _entry_for(path)
	if entry.is_empty():
		if not FileAccess.file_exists(abs_path):
			return "missing"
		if _same(abs_path, _manifest_abs()):
			return "accepted" if _manifest_hash_matches() else "modified"
		return "modified"
	if not FileAccess.file_exists(abs_path):
		return "missing"
	var digest := _hash_bytes(FileAccess.get_file_as_bytes(abs_path))
	if _same(abs_path, _manifest_abs()):
		return "accepted" if _manifest_hash_matches() else "modified"
	if digest == str(entry.get("sha256", "")):
		return "accepted"
	return "modified"


func refusal_for(path: String) -> String:
	return "protected expectation: %s%s" % [path, REFUSAL_TAIL]


func propose_change(path: String, new_bytes_or_text, reason: String) -> String:
	_seq += 1
	var id := "exp-%d" % _seq
	var text: String = new_bytes_or_text.get_string_from_utf8() if new_bytes_or_text is PackedByteArray else str(new_bytes_or_text)
	_pending[id] = {
		"id": id,
		"path": path,
		"contents": text,
		"reason": reason,
	}
	return id


func pending() -> Array:
	var out: Array = []
	for id in _pending.keys():
		out.append((_pending[id] as Dictionary).duplicate(true))
	return out


func accept(proposal_id: String) -> Array:
	if not _pending.has(proposal_id):
		return [false, "unknown proposal"]
	var proposal: Dictionary = _pending[proposal_id]
	var path := str(proposal.get("path", ""))
	var contents := str(proposal.get("contents", ""))
	var abs_path := _to_abs(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return [false, "could not write %s" % path]
	f.store_string(contents)
	f.close()
	_pending.erase(proposal_id)
	_upsert(path, _hash_bytes(contents.to_utf8_buffer()), str(proposal.get("reason", "")))
	_seal_and_write()
	_audit("EXPECTATION_ACCEPTED", path, contents.length(), str(proposal.get("reason", "")))
	return [true, "accepted %s" % path]


func reject(proposal_id: String) -> void:
	_pending.erase(proposal_id)


func blocks_ai_write(path: String) -> bool:
	if not _loaded:
		ensure(ProjectSettings.globalize_path("res://"))
	if not is_protected(path):
		return false
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if Safe != null:
		Safe.new().audit("BLOCK_EXPECTATION", path, 0, refusal_for(path))
	return true


func accept_current(path: String) -> Array:
	var abs_path := _to_abs(path)
	if not FileAccess.file_exists(abs_path):
		return [false, "missing"]
	var bytes := FileAccess.get_file_as_bytes(abs_path)
	if _same(abs_path, _manifest_abs()):
		_seal_and_write()
		_audit("EXPECTATION_ACCEPTED", path, bytes.size(), "accept_current")
		return [true, "accepted"]
	_upsert(path, _hash_bytes(bytes), "")
	_seal_and_write()
	_audit("EXPECTATION_ACCEPTED", path, bytes.size(), "accept_current")
	return [true, "accepted"]


func _read_from_disk() -> Dictionary:
	var path := _manifest_abs()
	if not FileAccess.file_exists(path):
		_manifest = {"schema": SCHEMA, "protected": []}
		_loaded = true
		return _manifest.duplicate(true)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_manifest = {"schema": SCHEMA, "protected": []}
	else:
		_manifest = _canonical(parsed)
	_loaded = true
	return _manifest.duplicate(true)


func _canonical(data: Dictionary) -> Dictionary:
	var protected: Array = []
	for entry in data.get("protected", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		protected.append({
			"path": str(entry.get("path", "")),
			"sha256": str(entry.get("sha256", "")),
			"accepted_at": str(entry.get("accepted_at", "")),
			"note": str(entry.get("note", "")),
		})
	return {"schema": SCHEMA, "protected": protected}


func _upsert(path: String, digest: String, note: String) -> void:
	var display := path if path.begins_with("res://") else _to_res(path)
	var rows: Array = _manifest.get("protected", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		if _same(_to_abs(str(row.get("path", ""))), _to_abs(path)):
			row["sha256"] = digest
			row["accepted_at"] = _now()
			if not note.is_empty():
				row["note"] = note
			rows[i] = row
			_manifest["protected"] = rows
			return
	rows.append({
		"path": display,
		"sha256": digest,
		"accepted_at": _now(),
		"note": note,
	})
	_manifest["protected"] = rows


func _seal_and_write() -> void:
	var rows: Array = _manifest.get("protected", [])
	var have_self := false
	var now := _now()
	for row in rows:
		if _same(_to_abs(str(row.get("path", ""))), _manifest_abs()):
			row["sha256"] = ""
			row["accepted_at"] = now
			have_self = true
	if not have_self:
		rows.append({
			"path": "res://%s" % MANIFEST_FILE,
			"sha256": "",
			"accepted_at": now,
			"note": "manifest",
		})
	_manifest["protected"] = rows
	var digest := _hash_text(JSON.stringify(_canonical(_manifest), "\t"))
	for row in rows:
		if _same(_to_abs(str(row.get("path", ""))), _manifest_abs()):
			row["sha256"] = digest
	_manifest = _canonical({"schema": SCHEMA, "protected": rows})
	var f := FileAccess.open(_manifest_abs(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_manifest, "\t"))
	f.close()


func _manifest_hash_matches() -> bool:
	var entry := _entry_for(_manifest_abs())
	if entry.is_empty():
		return false
	var data := _canonical(_manifest)
	for row in data["protected"]:
		if _same(_to_abs(str(row.get("path", ""))), _manifest_abs()):
			row["sha256"] = ""
	return _hash_text(JSON.stringify(data, "\t")) == str(entry.get("sha256", ""))


func _entry_for(path: String) -> Dictionary:
	var abs_path := _to_abs(path)
	for entry in _manifest.get("protected", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("path", "")).ends_with("/"):
			continue
		if _same(_to_abs(str(entry.get("path", ""))), abs_path):
			return entry
	return {}


func _manifest_abs() -> String:
	return _root.rstrip("/") + "/" + MANIFEST_FILE


func _to_res(path: String) -> String:
	var abs_path := _to_abs(path)
	var prefix := _root.rstrip("/") + "/"
	if abs_path.begins_with(prefix):
		return "res://" + abs_path.substr(prefix.length())
	return path


func _normalize_root(project_root: String) -> String:
	var p := project_root.strip_edges().replace("\\", "/")
	if p.is_empty() or p == "res://":
		p = ProjectSettings.globalize_path("res://")
	elif p.begins_with("res://") or p.begins_with("user://"):
		p = ProjectSettings.globalize_path(p)
	return _simplify(p).rstrip("/")


func _to_abs(path: String) -> String:
	var p := path.strip_edges().replace("\\", "/")
	if p.begins_with("res://"):
		var rest := p.substr(6)
		while rest.begins_with("/"):
			rest = rest.substr(1)
		while rest.find("//") != -1:
			rest = rest.replace("//", "/")
		if rest.begins_with("./"):
			rest = rest.substr(2)
		return _canonicalize(_simplify(_root.rstrip("/") + "/" + rest))
	if p.begins_with("user://"):
		return _canonicalize(_simplify(ProjectSettings.globalize_path(p)))
	if p.begins_with("./"):
		return _canonicalize(_simplify(_root.rstrip("/") + "/" + p.substr(2)))
	if p.begins_with("/"):
		return _canonicalize(_simplify(p))
	return _canonicalize(_simplify(_root.rstrip("/") + "/" + p))


func _canonicalize(abs_path: String) -> String:
	var out: Array = []
	var code := OS.execute("readlink", PackedStringArray(["-f", abs_path]), out, true)
	if code == 0 and not out.is_empty():
		var resolved := str(out[0]).strip_edges()
		if not resolved.is_empty():
			return resolved
	return abs_path


func _simplify(abs_path: String) -> String:
	var parts := abs_path.split("/")
	var out: Array = []
	for part in parts:
		if part.is_empty() or part == ".":
			continue
		if part == "..":
			if not out.is_empty():
				out.pop_back()
			continue
		out.append(part)
	return "/" + "/".join(out)


func _same(a: String, b: String) -> bool:
	return _fold(a) == _fold(b)


func _under(dir_abs: String, file_abs: String) -> bool:
	var base := _fold(dir_abs.rstrip("/"))
	var file := _fold(file_abs)
	return file == base or file.begins_with(base + "/")


func _fold(path: String) -> String:
	var name := OS.get_name()
	if name == "Windows" or name == "macOS":
		return path.to_lower()
	return path


func _hash_text(text: String) -> String:
	return _hash_bytes(text.to_utf8_buffer())


func _hash_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _now() -> String:
	return Time.get_datetime_string_from_system(true)


func _audit(action: String, path: String, size: int, note: String) -> void:
	var Safe = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	if Safe == null:
		return
	var safe = Safe.new()
	safe.audit(action, path, size, note)
