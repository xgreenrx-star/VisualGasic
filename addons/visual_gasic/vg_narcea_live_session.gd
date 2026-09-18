extends RefCounted
class_name VGNarceaLiveSession
## Ring buffer of local debug snapshots + metadata for Narcea / MCP (never res://).

signal session_purged
signal entry_added(entry_id: int)

const SPILL_DIR := "user://vg_narcea_live_session/"
const RAM_PNG_MAX_BYTES := 512 * 1024

var _max_entries: int = 32
var _entries: Array = []  # { id, ts, png: Image|null, png_path, meta: Dictionary }
var _next_id: int = 1


func configure(max_entries: int) -> void:
	_max_entries = maxi(1, max_entries)


func entry_count() -> int:
	return _entries.size()


func purge_all() -> void:
	_entries.clear()
	_remove_spill_dir()
	session_purged.emit()


func delete_older_than(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var cutoff := Time.get_unix_time_from_system() - seconds
	var kept: Array = []
	for e in _entries:
		if float(e.get("ts", 0)) >= cutoff:
			kept.append(e)
		else:
			_drop_entry_files(e)
	_entries = kept


func get_latest() -> Dictionary:
	if _entries.is_empty():
		return {}
	return _entries[_entries.size() - 1].duplicate(true)


func get_by_id(entry_id: int) -> Dictionary:
	for e in _entries:
		if int(e.get("id", -1)) == entry_id:
			return e.duplicate(true)
	return {}


func list_summaries() -> Array:
	var out: Array = []
	for e in _entries:
		var meta: Dictionary = e.get("meta", {})
		out.append({
			"id": e.get("id", 0),
			"ts": e.get("ts", 0),
			"file": meta.get("file", ""),
			"line": meta.get("line", 0),
			"w": meta.get("w", 0),
			"h": meta.get("h", 0),
		})
	return out


func add_entry(png: Image, meta: Dictionary) -> int:
	var id := _next_id
	_next_id += 1
	var entry := {
		"id": id,
		"ts": Time.get_unix_time_from_system(),
		"png": png,
		"png_path": "",
		"meta": meta.duplicate(true),
	}
	if png != null and not png.is_empty():
		var buf := png.save_png_to_buffer()
		if buf.size() > RAM_PNG_MAX_BYTES:
			entry["png_path"] = _spill_png(id, buf)
			entry["png"] = null
	while _entries.size() >= _max_entries:
		var old: Dictionary = _entries.pop_front()
		_drop_entry_files(old)
	_entries.append(entry)
	entry_added.emit(id)
	return id


func get_png_base64(entry_id: int) -> String:
	var e := get_by_id(entry_id)
	if e.is_empty():
		return ""
	var img: Image = e.get("png", null)
	if img != null and img is Image and not img.is_empty():
		return Marshalls.raw_to_base64(img.save_png_to_buffer())
	var path := str(e.get("png_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return Marshalls.raw_to_base64(f.get_buffer(f.get_length()))


func format_for_narcea(max_entries: int = 3, include_ui_tree: bool = true) -> String:
	if _entries.is_empty():
		return ""
	var n := mini(maxi(1, max_entries), _entries.size())
	var parts: PackedStringArray = PackedStringArray()
	parts.append("=== Live debug (local session) ===")
	parts.append("Snapshots are stored only on this machine until the game stops or you clear capture.")
	for i in range(_entries.size() - n, _entries.size()):
		var e: Dictionary = _entries[i]
		var meta: Dictionary = e.get("meta", {})
		parts.append("")
		parts.append("[Snapshot #%d @ %s]" % [e.get("id", 0), str(e.get("ts", 0))])
		if meta.has("file"):
			parts.append("Break: %s:%s" % [str(meta.get("file", "")), str(meta.get("line", 0))])
		if meta.has("w") and meta.has("h"):
			parts.append("Viewport: %sx%s px" % [str(meta.get("w", 0)), str(meta.get("h", 0))])
		if meta.has("debug_state"):
			parts.append("Debug state: %s" % JSON.stringify(meta.get("debug_state", {})))
		if meta.has("call_stack"):
			parts.append("Call stack: %s" % JSON.stringify(meta.get("call_stack", [])))
		if meta.has("locals"):
			parts.append("Locals (top frame): %s" % JSON.stringify(meta.get("locals", {})))
		if include_ui_tree and meta.has("ui_tree"):
			var tree: Array = meta.get("ui_tree", [])
			parts.append("UI controls (%d):" % tree.size())
			var show := mini(tree.size(), 40)
			for j in range(show):
				parts.append("  - %s" % JSON.stringify(tree[j]))
			if tree.size() > show:
				parts.append("  … (%d more)" % (tree.size() - show))
		if meta.has("audio_note"):
			parts.append("Audio: %s" % str(meta.get("audio_note", "")))
	parts.append("=== End live debug ===")
	return "\n".join(parts)


func _spill_png(entry_id: int, png_bytes: PackedByteArray) -> String:
	DirAccess.make_dir_recursive_absolute(SPILL_DIR)
	var path := SPILL_DIR.path_join("frame_%d.png" % entry_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(png_bytes)
	f.close()
	return path


func _drop_entry_files(entry: Dictionary) -> void:
	var path := str(entry.get("png_path", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _remove_spill_dir() -> void:
	if not DirAccess.dir_exists_absolute(SPILL_DIR):
		return
	var dir := DirAccess.open(SPILL_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		DirAccess.remove_absolute(SPILL_DIR.path_join(name))
	dir.list_dir_end()
	DirAccess.remove_absolute(SPILL_DIR)
