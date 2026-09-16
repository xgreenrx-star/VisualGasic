@tool
extends RefCounted
## Detects file path string literals in Open / LoadPicture / Sound.Play lines.

const AUDIO_EXTS: PackedStringArray = ["wav", "ogg", "mp3"]
const IMAGE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "gif"]
const VECTOR_EXTS: PackedStringArray = ["svg"]
const TEXT_EXTS: PackedStringArray = ["txt", "json", "cfg", "csv", "log", "md", "vg", "ini", "xml"]
const BINARY_EXTS: PackedStringArray = ["bin", "dat"]

enum FileMenuAction {
	SELECT_FILE = 1,
	PREVIEW = 2,
	PLAY_AUDIO = 3,
	OPEN_HEX = 4,
	OPEN_SPRITE = 5,
	REVEAL_BROWSER = 6,
	SHOW_IN_FOLDER = 7,
	COPY_PATH = 8,
	OPEN_EXTERNAL = 9,
	FIND_USAGES = 10,
	OPEN_VECTOR = 11,
	CREATE_IF_MISSING = 12,
}


static var _open_re: RegEx
static var _loadpicture_re: RegEx
static var _sound_play_re: RegEx
static var _load_re: RegEx


static func _open_rx() -> RegEx:
	if _open_re == null:
		_open_re = RegEx.new()
		_open_re.compile("(?i)^\\s*Open\\s+\"([^\"]*)\"\\s+For\\s+(\\w+)")
	return _open_re


static func _loadpicture_rx() -> RegEx:
	if _loadpicture_re == null:
		_loadpicture_re = RegEx.new()
		_loadpicture_re.compile("(?i)LoadPicture\\s+\"([^\"]*)\"")
	return _loadpicture_re


static func _sound_play_rx() -> RegEx:
	if _sound_play_re == null:
		_sound_play_re = RegEx.new()
		_sound_play_re.compile("(?i)Sound\\.Play\\s*(?:\\(\\s*)?\"([^\"]*)\"")
	return _sound_play_re


static func _load_rx() -> RegEx:
	if _load_re == null:
		_load_re = RegEx.new()
		_load_re.compile("(?i)\\bLoad\\s+\"([^\"]*)\"")
	return _load_re


## Returns {} when caret is not on a path literal in a recognized file command.
static func resolve_at_caret(source: String, line_index: int, column: int) -> Dictionary:
	if source.is_empty() or line_index < 0:
		return {}
	var lines := source.split("\n")
	if line_index >= lines.size():
		return {}
	var line := lines[line_index]
	if line.is_empty():
		return {}
	var lit := _string_literal_at_column(line, column)
	if lit.is_empty():
		return {}
	var path: String = lit.get("path", "")
	if path.is_empty():
		return {}
	var cmd := _command_for_line(line)
	if cmd.is_empty():
		return {}
	var mode := _open_mode_for_line(line) if cmd == "open" else ""
	var res_path := normalize_project_path(path)
	return {
		"path": path,
		"res_path": res_path,
		"exists": FileAccess.file_exists(res_path),
		"ext": res_path.get_extension().to_lower(),
		"kind": file_kind(res_path.get_extension(), mode),
		"command": cmd,
		"mode": mode,
		"line": line_index,
		"literal_start": lit.get("start", 0),
		"literal_end": lit.get("end", 0),
		"quote": lit.get("quote", "\""),
	}


static func normalize_project_path(path: String) -> String:
	var p := path.strip_edges()
	if p.begins_with("res://") or p.begins_with("user://"):
		return p
	if p.begins_with("/"):
		return "res:/" + p
	return "res://" + p


static func file_kind(ext: String, open_mode: String = "") -> String:
	var e := ext.to_lower()
	if e in AUDIO_EXTS:
		return "audio"
	if e in VECTOR_EXTS:
		return "vector"
	if e in IMAGE_EXTS:
		return "image"
	if e in TEXT_EXTS:
		return "text"
	if open_mode.to_lower() == "binary" or e in BINARY_EXTS:
		return "binary"
	return "unknown"


static func globalize(res_path: String) -> String:
	if res_path.begins_with("res://") or res_path.begins_with("user://"):
		return ProjectSettings.globalize_path(res_path)
	return res_path


static func file_size_label(res_path: String) -> String:
	if not FileAccess.file_exists(res_path):
		return "missing"
	var sz := FileAccess.get_file_as_bytes(res_path).size()
	if sz < 1024:
		return "%d B" % sz
	if sz < 1024 * 1024:
		return "%.1f KB" % (float(sz) / 1024.0)
	return "%.1f MB" % (float(sz) / (1024.0 * 1024.0))


static func _string_literal_at_column(line: String, column: int) -> Dictionary:
	if line.is_empty():
		return {}
	var col := clampi(column, 0, line.length())
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "\"":
			var start := i
			i += 1
			while i < line.length():
				if line[i] == "\"" and (i == 0 or line[i - 1] != "\\"):
					var end := i
					if col >= start and col <= end:
						return {
							"path": line.substr(start + 1, end - start - 1),
							"start": start,
							"end": end,
							"quote": "\"",
						}
					break
				i += 1
		i += 1
	return {}


static func _command_for_line(line: String) -> String:
	if _open_rx().search(line) != null:
		return "open"
	if _loadpicture_rx().search(line) != null:
		return "loadpicture"
	if _sound_play_rx().search(line) != null:
		return "sound.play"
	if _load_rx().search(line) != null:
		return "load"
	return ""


static func _open_mode_for_line(line: String) -> String:
	var m := _open_rx().search(line)
	if m == null:
		return ""
	return m.get_string(2).to_lower()


## All quoted path literals on Open / LoadPicture / Sound.Play / Load lines.
static func enumerate_path_literals(source: String) -> Array:
	var lines := source.split("\n")
	var out: Array = []
	for line_idx in lines.size():
		var line: String = lines[line_idx]
		var cmd := _command_for_line(line)
		if cmd.is_empty():
			continue
		var mode := _open_mode_for_line(line) if cmd == "open" else ""
		var col := 0
		while col < line.length():
			if line[col] != "\"":
				col += 1
				continue
			var start := col
			col += 1
			while col < line.length():
				if line[col] == "\"" and (col == 0 or line[col - 1] != "\\"):
					break
				col += 1
			if col >= line.length():
				break
			var end := col
			var path := line.substr(start + 1, end - start - 1)
			var res_path := normalize_project_path(path)
			out.append({
				"path": path,
				"res_path": res_path,
				"exists": FileAccess.file_exists(res_path),
				"ext": res_path.get_extension().to_lower(),
				"kind": file_kind(res_path.get_extension(), mode),
				"command": cmd,
				"mode": mode,
				"line": line_idx,
				"literal_start": start,
				"literal_end": end,
				"quote": "\"",
			})
			col += 1
	return out
