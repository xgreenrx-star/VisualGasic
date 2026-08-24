@tool
extends RefCounted
## Classify external data files for Context rail preview.

enum Kind {
	MISSING,
	RAW,
	VGD,
	CSV,
	PNG,
	IMAGE,
	TILED_JSON,
	TILED_TMX,
	TEXT,
}

static var _vgd_magic: PackedByteArray = PackedByteArray([0x56, 0x47, 0x44, 0x01])


static func sniff_path(abs_path: String) -> Dictionary:
	var out := {
		"kind": Kind.MISSING,
		"kind_name": "missing",
		"exists": false,
		"size": 0,
		"width": 0,
		"height": 0,
		"elem_size": 1,
		"palette_id": 255,
	}
	if abs_path.is_empty():
		return out
	if not FileAccess.file_exists(abs_path):
		return out
	out["exists"] = true
	out["size"] = FileAccess.get_file_as_bytes(abs_path).size()
	var head := _read_head(abs_path, 512)
	if head.size() >= 4 and head.slice(0, 4) == _vgd_magic:
		out["kind"] = Kind.VGD
		out["kind_name"] = "vgd"
		if head.size() >= 32:
			out["width"] = _u32_le(head, 8)
			out["height"] = _u32_le(head, 12)
			out["elem_size"] = head[16]
			out["palette_id"] = head[17]
		return out
	var ext := abs_path.get_extension().to_lower()
	if ext == "csv":
		out["kind"] = Kind.CSV
		out["kind_name"] = "csv"
		_sniff_csv_dims(abs_path, out)
		return out
	if ext == "tmx":
		out["kind"] = Kind.TILED_TMX
		out["kind_name"] = "tiled_tmx"
		return out
	if ext in ["png", "jpg", "jpeg", "webp", "bmp", "gif"]:
		out["kind"] = Kind.PNG if ext == "png" else Kind.IMAGE
		out["kind_name"] = "image"
		return out
	if ext == "json":
		var txt := _read_text_sample(abs_path, 8192)
		if '"layers"' in txt and '"tilewidth"' in txt:
			out["kind"] = Kind.TILED_JSON
			out["kind_name"] = "tiled_json"
			return out
	if _looks_like_csv(head):
		out["kind"] = Kind.CSV
		out["kind_name"] = "csv"
		_sniff_csv_dims(abs_path, out)
		return out
	var txt_head := head.get_string_from_utf8().strip_edges()
	if not txt_head.is_empty() and _is_mostly_printable(txt_head):
		out["kind"] = Kind.TEXT
		out["kind_name"] = "text"
	else:
		out["kind"] = Kind.RAW
		out["kind_name"] = "raw"
	return out


static func _read_head(abs_path: String, max_bytes: int) -> PackedByteArray:
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var n: int = mini(max_bytes, int(f.get_length()))
	var b := f.get_buffer(n)
	f.close()
	return b


static func _u32_le(b: PackedByteArray, off: int) -> int:
	if off + 4 > b.size():
		return 0
	return b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24)


static func _looks_like_csv(head: PackedByteArray) -> bool:
	if _bytes_contain_nul(head):
		return false
	var s := head.get_string_from_utf8()
	if s.is_empty():
		return false
	var lines := s.split("\n", false)
	if lines.is_empty():
		return false
	var sample := lines[0]
	if not ("," in sample or ";" in sample):
		return false
	for ch in sample:
		if ch in "0123456789,-. \t\r":
			continue
		if ch == '"' or ch == "'":
			continue
		return false
	return true


static func _is_mostly_printable(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 32 and c < 127:
			continue
		if c in [9, 10, 13]:
			continue
		return false
	return true


static func _sniff_csv_dims(abs_path: String, out: Dictionary) -> void:
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.is_empty() or _bytes_contain_nul(raw):
		return
	var txt := raw.get_string_from_utf8()
	var rows := txt.strip_edges().split("\n")
	var grid_w := 0
	var grid_h := 0
	for row in rows:
		if str(row).strip_edges().is_empty():
			continue
		grid_h += 1
		grid_w = maxi(grid_w, str(row).split(",").size())
	if grid_w > 0 and grid_h > 0:
		out["width"] = grid_w
		out["height"] = grid_h
		out["elem_size"] = 1


static func _read_text_sample(abs_path: String, max_bytes: int) -> String:
	var raw := _read_head(abs_path, max_bytes)
	if _bytes_contain_nul(raw):
		return ""
	return raw.get_string_from_utf8()


static func _bytes_contain_nul(raw: PackedByteArray) -> bool:
	for b in raw:
		if b == 0:
			return true
	return false


## Look for a Tiled project/export beside a data file (world.vgd → world.tmj / world.json).
static func find_tiled_companion(abs_path: String) -> String:
	if abs_path.is_empty():
		return ""
	var base := abs_path.get_basename()
	for ext in ["tmj", "json"]:
		var candidate: String = base + "." + ext
		if FileAccess.file_exists(candidate):
			if ext == "json":
				var head := _read_head(candidate, 4096).get_string_from_utf8()
				if '"layers"' in head and '"tilewidth"' in head:
					return candidate
			else:
				return candidate
	var dir := abs_path.get_base_dir()
	var stem := abs_path.get_file().get_basename()
	for name in ["%s.tmj" % stem, "map.tmj", "level.tmj"]:
		var p := dir.path_join(name)
		if FileAccess.file_exists(p):
			return p
	var json_path := dir.path_join(stem + ".json")
	if FileAccess.file_exists(json_path):
		var head := _read_head(json_path, 4096).get_string_from_utf8()
		if '"layers"' in head:
			return json_path
	return ""


## Distinct preview colors for common tile IDs (floor / wall / spawn / …).
static func tile_preview_color(tile_id: int) -> Color:
	match tile_id:
		0:
			return Color(0.82, 0.84, 0.88)
		1:
			return Color(0.22, 0.24, 0.30)
		2:
			return Color(0.35, 0.72, 0.98)
		3:
			return Color(0.95, 0.78, 0.25)
		_:
			var hue := fmod(float(tile_id) * 0.137, 1.0)
			return Color.from_hsv(hue, 0.55, 0.88)
