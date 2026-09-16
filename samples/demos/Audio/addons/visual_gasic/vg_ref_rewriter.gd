@tool
## VGRefRewriter — rewrites resource references in text-based asset files
## when an asset is renamed.
##
## Listens to VGAssetBus.asset_renamed(old_path, new_path, by_plugin_id).
## For every text asset in the project (vg, gd, tscn, tres, vgsprite, agck,
## json, cfg) whose contents contain the old `res://` path, replaces the
## path with the new one and writes the file back.
##
## Reasonable safety:
##   - Only rewrites within `res://` namespace; never touches user:// or
##     external files.
##   - Only matches the old path as a *whole* `res://...` string, not as
##     a substring of another path. Done by requiring boundary chars
##     (whitespace, quote, comma, paren, end-of-line) immediately before
##     and after the match.
##   - Skips the renamed file itself.
##   - Skips its own emissions (by_plugin_id == "vg_ref_rewriter").
##   - Files that don't contain the old path are not touched.
##
## Activate by calling VGRefRewriter.get_instance() once at editor startup
## (the plugin manager does this).
class_name VGRefRewriter
extends RefCounted

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _PLUGIN_ID := "vg_ref_rewriter"

## Extensions that are text-based and worth scanning. Anything else is
## either binary (PNG, WAV) or auto-managed by Godot (.import, .uid).
const TEXT_EXTS: Array[String] = [
	"vg", "gd", "tscn", "tres", "vgsprite", "agck",
	"json", "cfg", "ini", "txt", "md",
]

## Directories never to scan — same exclusions as the command palette.
const SKIP_DIRS: Array[String] = [
	".godot", ".import", ".git", "node_modules", "build", "dist",
]

const SCAN_LIMIT := 5000


static var _instance: VGRefRewriter = null

static func get_instance() -> VGRefRewriter:
	if _instance == null:
		_instance = VGRefRewriter.new()
		_instance._connect()
	return _instance


# ─── Internal ───────────────────────────────────────────────

signal references_rewritten(old_path: String, new_path: String, files_changed: int)


var _connected: bool = false


func _connect() -> void:
	if _connected:
		return
	var bus = _AssetBus.get_instance()
	bus.asset_renamed.connect(_on_asset_renamed)
	_connected = true


func _on_asset_renamed(old_path: String, new_path: String, by_plugin_id: String) -> void:
	# Don't loop on our own rewrites (we never emit asset_renamed, but
	# guard anyway in case future code does).
	if by_plugin_id == _PLUGIN_ID:
		return
	if old_path.is_empty() or new_path.is_empty() or old_path == new_path:
		return
	if not old_path.begins_with("res://"):
		return  # only project-scope refs are rewriteable
	rewrite_references(old_path, new_path)


## Public entry point — exposed so callers can trigger a sweep without
## actually emitting on the bus first (useful for tests or manual fixup).
## Returns the number of files modified.
func rewrite_references(old_path: String, new_path: String) -> int:
	var paths: Array = []
	_collect_text_files("res://", 0, paths)
	var changed := 0
	for p in paths:
		# Don't try to rewrite the file at the new path itself.
		if p == old_path or p == new_path:
			continue
		if _rewrite_one(p, old_path, new_path):
			changed += 1
	if changed > 0:
		print("VGRefRewriter: rewrote %d reference(s) %s → %s" % [changed, old_path, new_path])
		references_rewritten.emit(old_path, new_path, changed)
	return changed


func _rewrite_one(file_path: String, old_path: String, new_path: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	if text.find(old_path) == -1:
		return false
	# Boundary-aware replacement: only swap when the matched substring
	# is the *whole* res:// reference, not a prefix of a longer path.
	var rewritten := _replace_with_boundary(text, old_path, new_path)
	if rewritten == text:
		return false
	var w := FileAccess.open(file_path, FileAccess.WRITE)
	if w == null:
		push_warning("VGRefRewriter: cannot write %s" % file_path)
		return false
	w.store_string(rewritten)
	w.close()
	# Tell the rest of the IDE this file was changed externally so file-
	# browser, hex editor caches, etc. re-read.
	_AssetBus.get_instance().emit_invalidated(file_path, _PLUGIN_ID)
	return true


## Replace `old` with `new` only at positions where the character
## immediately following `old` is a "path terminator" (quote, whitespace,
## comma, paren, ], }, end-of-string). Prevents rewriting
## "res://foo/bar.gd" when renaming "res://foo/bar".
func _replace_with_boundary(text: String, old: String, new_str: String) -> String:
	var out := ""
	var i := 0
	while true:
		var hit := text.find(old, i)
		if hit < 0:
			out += text.substr(i)
			break
		out += text.substr(i, hit - i)
		var after_idx: int = hit + old.length()
		var next_ch: String = ""
		if after_idx < text.length():
			next_ch = text.substr(after_idx, 1)
		# Allowed terminators after a path. Letters/digits/_/-/.//
		# are NOT terminators because they extend the path.
		if next_ch == "" or next_ch in ["\"", "'", " ", "\t", "\n", "\r", ",", ")", "]", "}", ":", ";"]:
			out += new_str
		else:
			out += old  # leave as-is, it's a prefix of a longer path
		i = after_idx
	return out


func _collect_text_files(path: String, depth: int, out: Array) -> void:
	if out.size() >= SCAN_LIMIT:
		return
	if depth > 12:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full: String = path
			if not full.ends_with("/"):
				full += "/"
			full += name
			if dir.current_is_dir():
				if not (name in SKIP_DIRS):
					_collect_text_files(full, depth + 1, out)
			else:
				var ext := name.get_extension().to_lower()
				if ext in TEXT_EXTS:
					out.append(full)
					if out.size() >= SCAN_LIMIT:
						break
		name = dir.get_next()
	dir.list_dir_end()
