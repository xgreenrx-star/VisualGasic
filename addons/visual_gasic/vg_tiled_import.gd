@tool
extends RefCounted
## Import Tiled JSON exports to .vgd grid_u16 tilemaps.

const VgdWriter := preload("res://addons/visual_gasic/vg_vgd_writer.gd")


static func import_tiled_json(json_path: String, vgd_path: String, layer_name: String = "") -> Dictionary:
	var out := {"ok": false, "error": "", "width": 0, "height": 0}
	if not FileAccess.file_exists(json_path):
		out["error"] = "JSON not found: " + json_path
		return out
	var txt := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		out["error"] = "Invalid Tiled JSON"
		return out
	var root: Dictionary = parsed
	var layers: Array = root.get("layers", [])
	if layers.is_empty():
		out["error"] = "No layers in Tiled JSON"
		return out
	var layer: Dictionary = {}
	if layer_name.is_empty():
		for ly in layers:
			if typeof(ly) == TYPE_DICTIONARY and str(ly.get("type", "")) == "tilelayer":
				layer = ly
				break
	else:
		for ly in layers:
			if typeof(ly) == TYPE_DICTIONARY and str(ly.get("name", "")) == layer_name:
				layer = ly
				break
	if layer.is_empty():
		out["error"] = "Tile layer not found"
		return out
	var w: int = int(layer.get("width", 0))
	var h: int = int(layer.get("height", 0))
	var data: Array = layer.get("data", [])
	if w <= 0 or h <= 0 or data.size() != w * h:
		out["error"] = "Layer size/data mismatch"
		return out
	var bytes := PackedByteArray()
	bytes.resize(w * h * 2)
	for i in data.size():
		var gid: int = int(data[i])
		var off := i * 2
		bytes[off] = gid & 0xFF
		bytes[off + 1] = (gid >> 8) & 0xFF
	var abs_vgd := ProjectSettings.globalize_path(vgd_path) if vgd_path.begins_with("res://") else vgd_path
	if not VgdWriter.write_grid_u16(abs_vgd, w, h, bytes):
		out["error"] = "Failed to write " + vgd_path
		return out
	out["ok"] = true
	out["width"] = w
	out["height"] = h
	out["vgd_path"] = vgd_path
	return out
