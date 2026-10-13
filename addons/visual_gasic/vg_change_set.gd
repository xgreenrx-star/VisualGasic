@tool
extends RefCounted
## Records file mutations for one Narcea apply and can roll them back.
## Bytes are stored under user://vg_change_sets, never under res://.

const SCHEMA := "vg-change-set/1"
const KEEP := 10

static var _store_root := ""
static var _rollback_root := ""
static var _open: Dictionary = {}
static var _seq := 0
static var _replaying := false
static var _unsaved: Array = []


static func set_store_root(path: String) -> void:
	_store_root = path


static func set_rollback_root(path: String) -> void:
	_rollback_root = path


static func drop_memory() -> void:
	_open = {}


static func set_unsaved_paths(paths: Array) -> void:
	_unsaved = paths.duplicate()


static func has_open() -> bool:
	return not _open.is_empty()


static func begin(label: String, source: String, reply: String = "") -> String:
	if not _open.is_empty():
		return str(_open.get("id", ""))
	# _seq is per-process; continue from stored sets so ids stay unique and ordered after a restart.
	_seq = maxi(_seq, _max_stored_seq()) + 1
	var id := "%d-%04d" % [int(Time.get_unix_time_from_system()), _seq]
	_open = {
		"schema": SCHEMA,
		"id": id,
		"label": label,
		"source": source,
		"status": "open",
		"reply": reply,
		"started_unix": int(Time.get_unix_time_from_system()),
		"ended_unix": 0,
		"seq": _seq,
		"entries": [],
		"not_tracked": [],
		"pre_seq": 0,
	}
	return id


static func end() -> Dictionary:
	if _open.is_empty():
		return {}
	_open["status"] = "frozen"
	_open["ended_unix"] = int(Time.get_unix_time_from_system())
	var frozen: Dictionary = _open.duplicate(true)
	frozen.erase("pre_seq")
	write_set(frozen)
	_open = {}
	_prune()
	return frozen


static func note_untracked(path: String, reason: String) -> void:
	if _open.is_empty() or _replaying:
		return
	var rows: Array = _open.get("not_tracked", [])
	rows.append({"path": path, "reason": reason})
	_open["not_tracked"] = rows


static func note_created_dirs(dir_abs: String) -> void:
	if _open.is_empty() or _replaying:
		return
	for dir in _missing_chain(dir_abs):
		_append_mkdir(str(dir))


static func capture_write(path: String) -> Dictionary:
	if _open.is_empty() or _replaying:
		return {}
	var abs := _abs(path)
	var existed := FileAccess.file_exists(abs)
	var pre := PackedByteArray()
	if existed:
		pre = FileAccess.get_file_as_bytes(abs)
	return {
		"op": "write",
		"path": abs,
		"existed": existed,
		"pre": pre,
		"dirs": _missing_chain(abs.get_base_dir()),
	}


static func commit_write(token: Dictionary) -> void:
	if token.is_empty() or _open.is_empty() or _replaying:
		return
	var abs := str(token.get("path", ""))
	for dir in token.get("dirs", []):
		_append_mkdir(str(dir))
	var post := PackedByteArray()
	var present := FileAccess.file_exists(abs)
	if present:
		post = FileAccess.get_file_as_bytes(abs)
	var pre: PackedByteArray = token.get("pre", PackedByteArray())
	var entries: Array = _open.get("entries", [])
	entries.append({
		"op": "write",
		"path": abs,
		"existed": bool(token.get("existed", false)),
		"binary": _is_binary(pre) or _is_binary(post),
		"pre_hash": _sha(pre),
		"post_hash": _sha(post) if present else "",
		"pre_size": pre.size(),
		"post_size": post.size() if present else 0,
		"pre_file": _store_pre(pre),
	})
	_open["entries"] = entries


static func capture_remove(path: String) -> Dictionary:
	if _open.is_empty() or _replaying:
		return {}
	var abs := _abs(path)
	if not FileAccess.file_exists(abs):
		return {}
	return {"op": "remove", "path": abs, "pre": FileAccess.get_file_as_bytes(abs)}


static func commit_remove(token: Dictionary) -> void:
	if token.is_empty() or _open.is_empty() or _replaying:
		return
	var pre: PackedByteArray = token.get("pre", PackedByteArray())
	var entries: Array = _open.get("entries", [])
	entries.append({
		"op": "remove",
		"path": str(token.get("path", "")),
		"existed": true,
		"binary": _is_binary(pre),
		"pre_hash": _sha(pre),
		"post_hash": "",
		"pre_size": pre.size(),
		"post_size": 0,
		"pre_file": _store_pre(pre),
	})
	_open["entries"] = entries


static func capture_rename(from_path: String, to_path: String) -> Dictionary:
	if _open.is_empty() or _replaying:
		return {}
	var from_abs := _abs(from_path)
	var to_abs := _abs(to_path)
	var to_existed := FileAccess.file_exists(to_abs)
	return {
		"op": "rename",
		"from": from_abs,
		"to": to_abs,
		"pre": FileAccess.get_file_as_bytes(from_abs) if FileAccess.file_exists(from_abs) else PackedByteArray(),
		"to_existed": to_existed,
		"pre_to": FileAccess.get_file_as_bytes(to_abs) if to_existed else PackedByteArray(),
		"dirs": _missing_chain(to_abs.get_base_dir()),
	}


static func commit_rename(token: Dictionary) -> void:
	if token.is_empty() or _open.is_empty() or _replaying:
		return
	for dir in token.get("dirs", []):
		_append_mkdir(str(dir))
	var to_abs := str(token.get("to", ""))
	var present := FileAccess.file_exists(to_abs)
	var post := FileAccess.get_file_as_bytes(to_abs) if present else PackedByteArray()
	var pre: PackedByteArray = token.get("pre", PackedByteArray())
	var pre_to: PackedByteArray = token.get("pre_to", PackedByteArray())
	var to_existed := bool(token.get("to_existed", false))
	var entry := {
		"op": "rename",
		"from": str(token.get("from", "")),
		"to": to_abs,
		"path": to_abs,
		"existed": true,
		"to_existed": to_existed,
		"binary": _is_binary(pre) or _is_binary(pre_to) or _is_binary(post),
		"pre_hash": _sha(pre),
		"pre_to_hash": _sha(pre_to) if to_existed else "",
		"post_hash": _sha(post) if present else "",
		"pre_size": pre.size(),
		"post_size": post.size() if present else 0,
		"pre_file": _store_pre(pre),
	}
	if to_existed:
		entry["pre_to_file"] = _store_pre(pre_to)
	var entries: Array = _open.get("entries", [])
	entries.append(entry)
	_open["entries"] = entries


static func record_user_summary(id: String, text: String) -> void:
	var manifest := read_set(id)
	if manifest.is_empty():
		return
	manifest["user_summary"] = {
		"source": "user",
		"text": text,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	write_set(manifest)


static func read_set(id: String) -> Dictionary:
	var path := _manifest_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func write_set(manifest: Dictionary) -> void:
	var id := str(manifest.get("id", ""))
	if id.is_empty():
		return
	var dir := _global(_set_dir(id))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()


static func list_ids() -> Array:
	var root := _global(_store())
	if not DirAccess.dir_exists_absolute(root):
		return []
	var rows: Array = []
	var da := DirAccess.open(root)
	if da == null:
		return []
	for name in da.get_directories():
		var manifest := read_set(name)
		if manifest.is_empty():
			continue
		rows.append({"id": name, "seq": int(manifest.get("seq", 0)), "ended": int(manifest.get("ended_unix", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("seq", 0)) == int(b.get("seq", 0)):
			return int(a.get("ended", 0)) < int(b.get("ended", 0))
		return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)
	var ids: Array = []
	for row in rows:
		ids.append(str(row.get("id", "")))
	return ids


static func _max_stored_seq() -> int:
	var best := 0
	for id in list_ids():
		best = maxi(best, int(read_set(str(id)).get("seq", 0)))
	return best


static func preview(id: String) -> Dictionary:
	var manifest := read_set(id)
	if manifest.is_empty():
		return {"status": "unavailable", "reason": "set pruned", "conflicts": []}
	var status := str(manifest.get("status", ""))
	if status == "rolled_back":
		return {"status": "rolled_back", "conflicts": []}
	if status != "frozen":
		return {"status": "unavailable", "reason": "set is not frozen", "conflicts": []}
	var conflicts := _conflicts(manifest)
	if not conflicts.is_empty():
		return {"status": "conflict", "conflicts": conflicts}
	var blocked := _preflight(manifest)
	if not blocked.is_empty():
		return {"status": "refused", "reason": str(blocked[0].get("reason", "")), "paths": blocked, "conflicts": []}
	return {"status": "available", "conflicts": []}


static func rollback(id: String) -> Dictionary:
	var manifest_now := read_set(id)
	if not manifest_now.is_empty() and str(manifest_now.get("status", "")) == "rolled_back":
		return {"status": "refused", "reason": "already rolled back", "conflicts": []}
	var look := preview(id)
	if str(look.get("status", "")) != "available":
		return look
	var manifest := read_set(id)
	_replaying = true
	var SafeScript = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var safe = SafeScript.new()
	var root := _rollback_root if not _rollback_root.is_empty() else "res://"
	safe.set_root(root)
	var entries: Array = manifest.get("entries", [])
	var failed := ""
	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var op := str(entry.get("op", ""))
		var result := [true, ""]
		if op == "write":
			result = _undo_write(safe, manifest, entry)
		elif op == "remove":
			result = _undo_remove(safe, manifest, entry)
		elif op == "rename":
			result = _undo_rename(safe, manifest, entry)
		elif op == "mkdir":
			_undo_mkdir(entry)
		if not bool(result[0]):
			failed = str(result[1])
			break
	_replaying = false
	if not failed.is_empty():
		return {"status": "refused", "reason": failed, "conflicts": []}
	manifest["status"] = "rolled_back"
	write_set(manifest)
	_refresh_editor(_touched_paths(manifest))
	return {"status": "rolled_back", "conflicts": []}


static func latest_id() -> String:
	var ids := list_ids()
	if ids.is_empty():
		return ""
	return str(ids[ids.size() - 1])


static func legacy_file_undo_refusal(path: String) -> String:
	var abs := _abs(path)
	var ids := list_ids()
	ids.reverse()
	for id in ids:
		var manifest := read_set(str(id))
		if str(manifest.get("status", "")) != "frozen":
			continue
		var expected := _expected_state(manifest)
		if not expected.has(abs):
			continue
		var want: Dictionary = expected[abs]
		var have := _disk_state(abs)
		var same := bool(want.get("present", false)) == bool(have.get("present", false)) and str(want.get("hash", "")) == str(have.get("hash", ""))
		if not same:
			return "Refused: %s was edited after the change. Use Roll back in Code Navigator to see conflicts." % path
		return ""
	return ""


static func read_pre_bytes(id: String, rel: String) -> PackedByteArray:
	return _read_rel(id, rel)


static func _conflicts(manifest: Dictionary) -> Array:
	var expected := _expected_state(manifest)
	var found: Array = []
	for path in expected.keys():
		var abs := str(path)
		if _is_unsaved(abs):
			found.append({"path": abs, "reason": "unsaved editor changes"})
			continue
		var want: Dictionary = expected[abs]
		var have := _disk_state(abs)
		if bool(want.get("present", false)) and not bool(have.get("present", false)):
			found.append({"path": abs, "reason": "deleted after change"})
		elif not bool(want.get("present", false)) and bool(have.get("present", false)):
			found.append({"path": abs, "reason": "recreated after change"})
		elif str(want.get("hash", "")) != str(have.get("hash", "")):
			found.append({"path": abs, "reason": "edited after change"})
	return found


static func _expected_state(manifest: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	for entry in manifest.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var op := str(entry.get("op", ""))
		if op == "write" or op == "remove":
			var path := str(entry.get("path", ""))
			var post := str(entry.get("post_hash", ""))
			expected[path] = {"present": not post.is_empty(), "hash": post}
		elif op == "rename":
			expected[str(entry.get("from", ""))] = {"present": false, "hash": ""}
			var post_hash := str(entry.get("post_hash", ""))
			expected[str(entry.get("to", ""))] = {"present": not post_hash.is_empty(), "hash": post_hash}
	return expected


static func _preflight(manifest: Dictionary) -> Array:
	var SafeScript = load("res://addons/visual_gasic/vg_ai_safe_write.gd")
	var safe = SafeScript.new()
	var root := _rollback_root if not _rollback_root.is_empty() else "res://"
	safe.set_root(root)
	var blocked: Array = []
	for entry in manifest.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var op := str(entry.get("op", ""))
		var paths: Array = []
		if op == "rename":
			paths = [str(entry.get("from", "")), str(entry.get("to", ""))]
		elif op == "write" or op == "remove":
			paths = [str(entry.get("path", ""))]
		for path in paths:
			if str(path).is_empty():
				continue
			var safety: Array = safe.is_safe(str(path))
			if not bool(safety[0]):
				blocked.append({"path": str(path), "reason": str(safety[1])})
	return blocked


static func _undo_write(safe, manifest: Dictionary, entry: Dictionary) -> Array:
	var path := str(entry.get("path", ""))
	if bool(entry.get("existed", false)):
		return safe.write_bytes(path, _read_rel(str(manifest.get("id", "")), str(entry.get("pre_file", ""))))
	return safe.remove(path)


static func _undo_remove(safe, manifest: Dictionary, entry: Dictionary) -> Array:
	var path := str(entry.get("path", ""))
	return safe.write_bytes(path, _read_rel(str(manifest.get("id", "")), str(entry.get("pre_file", ""))))


static func _undo_rename(safe, manifest: Dictionary, entry: Dictionary) -> Array:
	var from_path := str(entry.get("from", ""))
	var to_path := str(entry.get("to", ""))
	var renamed: Array = safe.rename_path(to_path, from_path)
	if not bool(renamed[0]):
		return renamed
	if bool(entry.get("to_existed", false)):
		return safe.write_bytes(to_path, _read_rel(str(manifest.get("id", "")), str(entry.get("pre_to_file", ""))))
	return [true, ""]


static func _undo_mkdir(entry: Dictionary) -> void:
	var path := _global(str(entry.get("path", "")))
	if not DirAccess.dir_exists_absolute(path):
		return
	if _dir_empty(path):
		DirAccess.remove_absolute(path)


static func _touched_paths(manifest: Dictionary) -> Array:
	var paths: Array = []
	for entry in manifest.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		for key in ["path", "from", "to"]:
			var path := str(entry.get(key, ""))
			if not path.is_empty() and not paths.has(path):
				paths.append(path)
	return paths


static func _refresh_editor(paths: Array) -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()
	for path in paths:
		var res_path := ProjectSettings.localize_path(str(path))
		if not res_path.begins_with("res://"):
			continue
		if not res_path.ends_with(".gd") and not res_path.ends_with(".vg"):
			continue
		if not FileAccess.file_exists(res_path):
			continue
		var res = load(res_path)
		if res is Script:
			res.reload()


static func _append_mkdir(dir_abs: String) -> void:
	if dir_abs.is_empty() or _has_mkdir(dir_abs):
		return
	var entries: Array = _open.get("entries", [])
	entries.append({"op": "mkdir", "path": dir_abs, "existed": false})
	_open["entries"] = entries


static func _has_mkdir(dir_abs: String) -> bool:
	for entry in _open.get("entries", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("op", "")) == "mkdir" and str(entry.get("path", "")) == dir_abs:
			return true
	return false


static func _store_pre(data: PackedByteArray) -> String:
	var n := int(_open.get("pre_seq", 0))
	_open["pre_seq"] = n + 1
	var rel := "pre/%d.bin" % n
	var dir := _global(_set_dir(str(_open.get("id", ""))).path_join("pre"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("%d.bin" % n), FileAccess.WRITE)
	if f != null:
		f.store_buffer(data)
		f.close()
	return rel


static func _read_rel(id: String, rel: String) -> PackedByteArray:
	if rel.is_empty():
		return PackedByteArray()
	var path := _global(_set_dir(id).path_join(rel))
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


static func _prune() -> void:
	var ids := list_ids()
	while ids.size() > KEEP:
		_erase_dir(_global(_set_dir(str(ids[0]))))
		ids.pop_front()


static func _erase_dir(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	for file_name in da.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in da.get_directories():
		_erase_dir(path.path_join(dir_name))
	DirAccess.remove_absolute(path)


static func _missing_chain(dir_abs: String) -> Array:
	var found: Array = []
	var dir := dir_abs
	while dir.length() > 1 and not DirAccess.dir_exists_absolute(_global(dir)):
		found.append(dir)
		var parent := dir.get_base_dir()
		if parent == dir:
			break
		dir = parent
	found.reverse()
	return found


static func _dir_empty(path: String) -> bool:
	var da := DirAccess.open(path)
	if da == null:
		return false
	return da.get_files().is_empty() and da.get_directories().is_empty()


static func _disk_state(abs: String) -> Dictionary:
	if not FileAccess.file_exists(abs):
		return {"present": false, "hash": ""}
	return {"present": true, "hash": _sha(FileAccess.get_file_as_bytes(abs))}


static func _is_unsaved(path: String) -> bool:
	var abs := _abs(path)
	for item in _unsaved:
		if _abs(str(item)) == abs:
			return true
	if not Engine.is_editor_hint():
		return false
	var editor = EditorInterface.get_script_editor()
	if editor == null or not editor.has_method("get_open_script_editors"):
		return false
	for pane in editor.get_open_script_editors():
		if pane == null or not pane.has_method("is_unsaved") or not pane.is_unsaved():
			continue
		if not pane.has_method("get_edited_resource"):
			continue
		var res = pane.get_edited_resource()
		if res != null and _abs(str(res.resource_path)) == abs:
			return true
	return false


static func _is_binary(data: PackedByteArray) -> bool:
	if data.is_empty() or data.find(0) >= 0:
		return not data.is_empty()
	return data.get_string_from_utf8().to_utf8_buffer() != data


static func _sha(data: PackedByteArray) -> String:
	if data.is_empty():
		return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


static func _store() -> String:
	if _store_root.is_empty():
		return "user://vg_change_sets"
	return _store_root


static func _set_dir(id: String) -> String:
	return _store().path_join(id)


static func _manifest_path(id: String) -> String:
	return _global(_set_dir(id).path_join("manifest.json"))


static func _global(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _abs(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
