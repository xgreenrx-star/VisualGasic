@tool
extends RefCounted
class_name VGTweakPersistence

# Stores per-target overrides as JSON under user:// (writable in all builds)
# with a project-level mirror under res://.vg_tweaks.json so the file ships
# alongside source when the user commits it.

const USER_PATH := "user://vg_tweaks.json"
const RES_PATH := "res://.vg_tweaks.json"

static func load_all() -> Dictionary:
	var data := _read_json(RES_PATH)
	if data.is_empty():
		data = _read_json(USER_PATH)
	return data

static func save_all(overrides: Dictionary) -> bool:
	var ok := _write_json(USER_PATH, overrides)
	# Best-effort res:// mirror so committed tweaks travel with the project.
	_write_json(RES_PATH, overrides)
	return ok

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return _decode(parsed)
	return {}

static func _write_json(path: String, overrides: Dictionary) -> bool:
	var encoded := _encode(overrides)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(encoded, "  "))
	f.close()
	return true

# JSON has no Vector2/Color — encode as tagged arrays.
static func _encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for k in value.keys():
				out[str(k)] = _encode(value[k])
			return out
		TYPE_ARRAY:
			var out := []
			for v in value:
				out.append(_encode(v))
			return out
		TYPE_VECTOR2:
			return {"__t": "v2", "x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"__t": "v3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_RECT2:
			return {"__t": "r2", "x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_COLOR:
			return {"__t": "c", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_TRANSFORM2D:
			return {"__t": "t2",
				"xx": value.x.x, "xy": value.x.y,
				"yx": value.y.x, "yy": value.y.y,
				"ox": value.origin.x, "oy": value.origin.y}
	return value

static func _decode(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var t = value.get("__t", "")
		match t:
			"v2": return Vector2(value.get("x", 0.0), value.get("y", 0.0))
			"v3": return Vector3(value.get("x", 0.0), value.get("y", 0.0), value.get("z", 0.0))
			"r2": return Rect2(value.get("x", 0.0), value.get("y", 0.0), value.get("w", 0.0), value.get("h", 0.0))
			"c": return Color(value.get("r", 1.0), value.get("g", 1.0), value.get("b", 1.0), value.get("a", 1.0))
			"t2":
				return Transform2D(
					Vector2(value.get("xx", 1.0), value.get("xy", 0.0)),
					Vector2(value.get("yx", 0.0), value.get("yy", 1.0)),
					Vector2(value.get("ox", 0.0), value.get("oy", 0.0))
				)
		var out := {}
		for k in value.keys():
			out[k] = _decode(value[k])
		return out
	if typeof(value) == TYPE_ARRAY:
		var out := []
		for v in value:
			out.append(_decode(v))
		return out
	return value
