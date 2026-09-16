@tool
extends RefCounted
class_name VGDualEditorBridge
## Tracks which VG code surface last edited a .vg file and detects stale buffers
## when the embedded Code view and Godot's Script tab both hold the same path.

const SIDE_EMBEDDED := 0
const SIDE_NATIVE := 1

const SIDE_LABEL := {
	SIDE_EMBEDDED: "VG Code view",
	SIDE_NATIVE: "Godot Script tab",
}

var _authority: Dictionary = {}       # path -> int side
var _popup_shown: Dictionary = {}   # "path|side" -> true until refresh/dismiss


func note_modified(path: String, side: int) -> void:
	if path.is_empty() or not path.ends_with(".vg"):
		return
	var prev: int = int(_authority.get(path, -1))
	_authority[path] = side
	# Only re-arm the stale-side popup when editing authority switches editors —
	# not on every keystroke in the same buffer.
	if prev != side:
		var stale_side := SIDE_EMBEDDED if side == SIDE_NATIVE else SIDE_NATIVE
		_popup_shown.erase(_popup_key(path, stale_side))


func clear_path(path: String) -> void:
	if path.is_empty():
		return
	_authority.erase(path)
	_clear_popup_flags(path)


func authority_label(path: String) -> String:
	if not _authority.has(path):
		return ""
	return SIDE_LABEL.get(_authority[path], "")


## Returns { embedded_stale, native_stale, authority } for a path when both
## editors hold text. Empty path or matching text → neither stale.
func evaluate(path: String, embedded_text: String, native_text: String, native_open: bool) -> Dictionary:
	var out := {
		"embedded_stale": false,
		"native_stale": false,
		"authority": null,
		"authority_label": "",
	}
	if path.is_empty() or not native_open:
		return out
	if embedded_text == native_text:
		_clear_popup_flags(path)
		return out
	if not _authority.has(path):
		return out
	var auth: int = _authority[path]
	out["authority"] = auth
	out["authority_label"] = SIDE_LABEL.get(auth, "")
	out["embedded_stale"] = auth == SIDE_NATIVE
	out["native_stale"] = auth == SIDE_EMBEDDED
	return out


func should_popup(path: String, side: int, stale: bool) -> bool:
	if not stale:
		return false
	var key := _popup_key(path, side)
	if _popup_shown.get(key, false):
		return false
	_popup_shown[key] = true
	return true


func dismiss_popup(path: String, side: int) -> void:
	_popup_shown[_popup_key(path, side)] = true


func _clear_popup_flags(path: String) -> void:
	_popup_shown.erase(_popup_key(path, SIDE_EMBEDDED))
	_popup_shown.erase(_popup_key(path, SIDE_NATIVE))


func _popup_key(path: String, side: int) -> String:
	return path + "|" + str(side)
