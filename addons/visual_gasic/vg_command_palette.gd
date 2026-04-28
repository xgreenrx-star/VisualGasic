@tool
## VGCommandPalette — quick-open + command palette popup.
##
## A single PopupPanel with a LineEdit at top and an ItemList below.
## The first character of the query selects the mode:
##   ">"  — command palette: list all registered actions and capabilities
##   "?"  — help (show keybinds / mode prefixes)
##   anything else — quick-open: fuzzy-match every file in the project
##
## Files are routed through VGPluginRegistry.open_asset(path), so any
## plugin (built-in or third-party) that claims an extension via its
## plugin.cfg [capabilities] block participates automatically — no
## hard-coded plugin ids anywhere in this file.
##
## Commands are also registry-driven: each registered provider's
## "provides" list contributes one entry per capability ("Open default
## sprite editor", "Open default sound editor", etc.). External code
## can add custom commands via register_command().
class_name VGCommandPalette
extends PopupPanel

const _Registry := preload("res://addons/visual_gasic/vg_plugin_registry.gd")
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")

## Maximum number of files to scan before bailing — keeps startup
## responsive on huge projects.
const FILE_SCAN_LIMIT := 5000

## Where the most-recently-opened files list is persisted.
const RECENT_FILES_PATH := "user://vg_recent_files.cfg"

## Cap on the recent-files list. Anything older falls off.
const RECENT_FILES_LIMIT := 30

## Extensions that are always uninteresting (binary blobs, build
## artifacts) and should never appear in quick-open.
const SKIP_EXTS: Array[String] = [
	"import", "uid", "pyc", "pyo", "tmp", "lock",
	"png.import", "wav.import",
]

## Directories to skip while scanning.
const SKIP_DIRS: Array[String] = [
	".godot", ".import", ".git", "node_modules", "build", "dist",
]

# ─── State ──────────────────────────────────────────────────

var _query_edit: LineEdit
var _list: ItemList
var _hint_label: Label

## Cached project file scan: PackedStringArray of res:// paths.
## Refreshed on every popup; cheap because list_dir is fast and we
## cap at FILE_SCAN_LIMIT.
var _file_cache: PackedStringArray = PackedStringArray()

## Custom commands registered by external code:
## { id: { "label": String, "callback": Callable, "description": String } }
var _commands: Dictionary = {}

## What's currently displayed (rows of {kind, label, payload}).
## kind: "file" | "command" | "capability"
## payload: file path / command id / capability name
var _rows: Array = []

## Most-recently-opened files (newest first), persisted to user://.
## Populated from VGAssetBus.asset_opened.
var _recent_files: Array = []


# ─── Public API ─────────────────────────────────────────────

## Register an arbitrary command. Plugins or core IDE code can call
## this in _ready() / _enter_tree() to add their own entries.
func register_command(id: String, label: String, callback: Callable, description: String = "") -> void:
	_commands[id] = {
		"label": label,
		"callback": callback,
		"description": description,
	}


## Show the palette. Pass an optional initial query.
func open_palette(initial_query: String = "") -> void:
	_refresh_file_cache()
	_query_edit.text = initial_query
	_query_edit.caret_column = initial_query.length()
	# Center on parent viewport, sized for typical IDE windows.
	var vp := get_parent_visible_rect()
	popup_centered(Vector2(min(vp.x - 80, 700), min(vp.y - 120, 480)))
	_query_edit.grab_focus()
	_refresh_results()


# ─── Lifecycle ──────────────────────────────────────────────

func _ready() -> void:
	# Build UI on first ready (PopupPanel needs a single content child).
	if get_child_count() == 0:
		_build_ui()
	# Re-route Esc to close cleanly.
	close_requested.connect(hide)
	# Track every opened asset so empty-query quick-open shows MRU.
	_load_recent_files()
	var bus = _AssetBus.get_instance()
	if not bus.asset_opened.is_connected(_on_asset_opened):
		bus.asset_opened.connect(_on_asset_opened)


func _on_asset_opened(path: String, _by_plugin_id: String) -> void:
	# Move-to-front semantics, dedup by path, drop tail past LIMIT.
	if path.is_empty():
		return
	_recent_files.erase(path)
	_recent_files.push_front(path)
	if _recent_files.size() > RECENT_FILES_LIMIT:
		_recent_files.resize(RECENT_FILES_LIMIT)
	_save_recent_files()


func _load_recent_files() -> void:
	_recent_files.clear()
	var cfg := ConfigFile.new()
	if cfg.load(RECENT_FILES_PATH) != OK:
		return
	var arr = cfg.get_value("recent", "files", [])
	if arr is Array:
		for p in arr:
			if p is String and not p.is_empty():
				_recent_files.append(p)


func _save_recent_files() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("recent", "files", _recent_files)
	cfg.save(RECENT_FILES_PATH)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_query_edit = LineEdit.new()
	_query_edit.placeholder_text = "Type to search files… ('>' for commands, '?' for help)"
	_query_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query_edit.text_changed.connect(_on_query_changed)
	_query_edit.text_submitted.connect(_on_query_submitted)
	_query_edit.gui_input.connect(_on_query_input)
	vbox.add_child(_query_edit)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(640, 360)
	_list.allow_search = false  # we drive search ourselves
	_list.item_activated.connect(_on_item_activated)
	vbox.add_child(_list)

	_hint_label = Label.new()
	_hint_label.text = "Enter: open  •  Esc: cancel  •  ↑/↓: navigate"
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_hint_label)


# ─── Input handling ─────────────────────────────────────────

## Forward Up/Down/Enter from the LineEdit to the ItemList so the user
## can navigate without taking focus off the input.
func _on_query_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var k: InputEventKey = event
	match k.keycode:
		KEY_DOWN:
			_move_selection(1)
			_query_edit.accept_event()
		KEY_UP:
			_move_selection(-1)
			_query_edit.accept_event()
		KEY_ESCAPE:
			hide()
			_query_edit.accept_event()
		KEY_PAGEDOWN:
			_move_selection(10)
			_query_edit.accept_event()
		KEY_PAGEUP:
			_move_selection(-10)
			_query_edit.accept_event()


func _move_selection(delta: int) -> void:
	if _list.item_count == 0:
		return
	var sel := _list.get_selected_items()
	var idx := 0
	if sel.size() > 0:
		idx = sel[0]
	idx = clamp(idx + delta, 0, _list.item_count - 1)
	_list.select(idx)
	_list.ensure_current_is_visible()


func _on_query_changed(_new_text: String) -> void:
	_refresh_results()


func _on_query_submitted(_text: String) -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty() and _list.item_count > 0:
		_list.select(0)
		sel = [0]
	if sel.size() > 0:
		_activate_row(sel[0])


func _on_item_activated(idx: int) -> void:
	_activate_row(idx)


# ─── Result building ────────────────────────────────────────

func _refresh_results() -> void:
	_list.clear()
	_rows.clear()
	var q: String = _query_edit.text

	if q.begins_with("?"):
		_show_help()
		return

	if q.begins_with(">"):
		_show_commands(q.substr(1).strip_edges().to_lower())
		return

	_show_files(q.strip_edges().to_lower())


func _show_help() -> void:
	var lines := [
		"Quick-open mode (default): type part of a file path.",
		"  → Opens via the registered editor for that file's extension.",
		"Command mode: prefix with '>' to list commands & capabilities.",
		"  → '> sprite' shows everything sprite-related.",
		"Help (this screen): prefix with '?'.",
		"",
		"Navigation: ↑/↓ select, Enter open, Esc cancel.",
	]
	for line in lines:
		_list.add_item(line)
		_rows.append({"kind": "help", "label": line, "payload": null})
		var idx := _list.item_count - 1
		_list.set_item_selectable(idx, false)


func _show_commands(filter: String) -> void:
	var entries: Array = []

	# Dynamic entries: one per (provider, capability) combination, so a
	# new plugin tomorrow shows up automatically.
	var providers: Dictionary = _Registry.get_instance().get_all_providers()
	for pid in providers:
		var p: Dictionary = providers[pid]
		if not p.get("enabled", true):
			continue
		for cap in p.get("provides", []):
			var label := "%s  (%s)" % [_humanize_cap(cap), p.get("name", pid)]
			entries.append({
				"kind": "capability",
				"label": label,
				"payload": {"plugin_id": pid, "capability": cap},
				"haystack": (label + " " + cap + " " + pid).to_lower(),
			})

	# Custom commands registered by external code.
	for cid in _commands:
		var c: Dictionary = _commands[cid]
		var label2: String = c.get("label", cid)
		entries.append({
			"kind": "command",
			"label": label2,
			"payload": cid,
			"haystack": (label2 + " " + cid + " " + String(c.get("description", ""))).to_lower(),
		})

	# Filter + score.
	var matches: Array = []
	for e in entries:
		if filter.is_empty():
			e["score"] = 0
			matches.append(e)
		else:
			var score := _fuzzy_score(filter, e["haystack"])
			if score > 0:
				e["score"] = score
				matches.append(e)
	matches.sort_custom(func(a, b): return a["score"] > b["score"])

	for m in matches:
		_list.add_item(m["label"])
		_rows.append(m)
	if _list.item_count > 0:
		_list.select(0)


func _show_files(filter: String) -> void:
	# Empty query → show MRU first, then full file list. Gives the user
	# instant access to whatever they were just looking at.
	if filter.is_empty() and not _recent_files.is_empty():
		var existing: Dictionary = {}
		var shown_recent := 0
		for path in _recent_files:
			if shown_recent >= 10:
				break
			# Skip stale entries the user has since deleted.
			if not (path.begins_with("res://") or FileAccess.file_exists(path)):
				continue
			if path.begins_with("res://") and not FileAccess.file_exists(path):
				continue
			existing[path] = true
			var provider_name := _provider_name_for_path(path)
			var label: String = "🕘  " + path
			if not provider_name.is_empty():
				label = "🕘  %s   — %s" % [path, provider_name]
			_list.add_item(label)
			_rows.append({"kind": "file", "label": label, "payload": path})
			shown_recent += 1
		# Visual separator: an unselectable divider entry.
		if shown_recent > 0:
			_list.add_item("──────────  All files  ──────────")
			var sep_idx := _list.item_count - 1
			_list.set_item_selectable(sep_idx, false)
			_rows.append({"kind": "separator", "label": "", "payload": null})
		# Now show the rest of the project, excluding what's already in MRU.
		var shown := 0
		for path in _file_cache:
			if shown >= 200:
				break
			if existing.has(path):
				continue
			var pname := _provider_name_for_path(path)
			var lbl: String = path
			if not pname.is_empty():
				lbl = "%s   — %s" % [path, pname]
			_list.add_item(lbl)
			_rows.append({"kind": "file", "label": lbl, "payload": path})
			shown += 1
		if _list.item_count > 0:
			_list.select(0)
		return

	var matches: Array = []
	for path in _file_cache:
		var hay: String = path.to_lower()
		if filter.is_empty():
			matches.append({"path": path, "score": 0})
		else:
			var s := _fuzzy_score(filter, hay)
			if s > 0:
				matches.append({"path": path, "score": s})
	# Sort: score desc, then shorter path first (favors exact matches).
	matches.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return String(a["path"]).length() < String(b["path"]).length()
	)

	# Cap displayed rows so huge projects don't lock the UI.
	var shown_count := 0
	for m in matches:
		if shown_count >= 200:
			break
		var path: String = m["path"]
		# Annotate which provider handles the path (if any) so the user
		# knows what's about to open.
		var provider_name := _provider_name_for_path(path)
		var label: String = path
		if not provider_name.is_empty():
			label = "%s   — %s" % [path, provider_name]
		_list.add_item(label)
		_rows.append({"kind": "file", "label": label, "payload": path})
		shown_count += 1
	if _list.item_count > 0:
		_list.select(0)


# ─── Activation ─────────────────────────────────────────────

func _activate_row(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	var row: Dictionary = _rows[idx]
	match row["kind"]:
		"file":
			_open_file(row["payload"])
		"capability":
			_activate_capability(row["payload"])
		"command":
			_run_command(row["payload"])
		_:
			return
	hide()


func _open_file(path: String) -> void:
	# Route through the registry — extension lookup picks the user's
	# default provider, falling back to highest-priority capable plugin.
	var ok := _Registry.get_instance().open_asset(path)
	if not ok:
		push_warning("VGCommandPalette: no provider could open '%s'" % path)


func _activate_capability(payload: Dictionary) -> void:
	var pid: String = payload.get("plugin_id", "")
	var cap: String = payload.get("capability", "")
	var providers: Dictionary = _Registry.get_instance().get_all_providers()
	if not providers.has(pid):
		return
	var inst = providers[pid].get("instance")
	if inst == null:
		push_warning("VGCommandPalette: provider '%s' for '%s' is registered but not loaded" % [pid, cap])
		return
	# Generic activation — the plugin's own UI handles "open empty editor"
	# or "show me your panel". If the plugin exposes activate(), use it;
	# otherwise just toggle visibility on _view if present.
	if inst.has_method("activate"):
		inst.activate()
	elif "_view" in inst and inst._view is Control:
		inst._view.visible = true


func _run_command(cid: String) -> void:
	var c: Dictionary = _commands.get(cid, {})
	var cb: Callable = c.get("callback", Callable())
	if cb.is_valid():
		cb.call()


# ─── File scan ──────────────────────────────────────────────

func _refresh_file_cache() -> void:
	_file_cache.clear()
	_scan_dir("res://", 0)


func _scan_dir(path: String, depth: int) -> void:
	if _file_cache.size() >= FILE_SCAN_LIMIT:
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
					_scan_dir(full, depth + 1)
			else:
				var ext := name.get_extension().to_lower()
				if not (ext in SKIP_EXTS):
					_file_cache.append(full)
					if _file_cache.size() >= FILE_SCAN_LIMIT:
						break
		name = dir.get_next()
	dir.list_dir_end()


# ─── Helpers ────────────────────────────────────────────────

## Simple subsequence-fuzzy score: each query character must appear in
## order in the haystack. Score rewards consecutive matches and
## prefix-of-segment matches. Returns 0 if no match.
func _fuzzy_score(query: String, haystack: String) -> int:
	if query.is_empty():
		return 1
	var qi := 0
	var score := 0
	var streak := 0
	var prev_was_sep := true
	for hi in haystack.length():
		var hc: String = haystack[hi]
		if qi < query.length() and hc == query[qi]:
			score += 1 + streak
			if prev_was_sep:
				score += 3  # bonus for matching at word boundary
			streak += 1
			qi += 1
		else:
			streak = 0
		prev_was_sep = hc in ["/", "_", "-", "."]
	if qi < query.length():
		return 0
	return score


func _provider_name_for_path(path: String) -> String:
	var pid := _Registry.get_instance().get_default_for_path(path)
	if pid.is_empty():
		return ""
	var meta: Dictionary = _Registry.get_instance().get_provider(pid)
	return meta.get("name", pid)


func _humanize_cap(cap: String) -> String:
	# "asset_editor.sprite" → "Open default sprite editor"
	# "asset_editor.audio.advanced" → "Open default audio.advanced editor"
	# "game_builder.arcade" → "Open default arcade game builder"
	var parts := cap.split(".")
	if parts.size() < 2:
		return "Activate: " + cap
	var category: String = parts[0]
	var rest := ""
	for i in range(1, parts.size()):
		if i > 1:
			rest += "."
		rest += parts[i]
	match category:
		"asset_editor":
			return "Open default %s editor" % rest
		"asset_generator":
			return "Open default %s generator" % rest
		"game_builder":
			return "Open default %s game builder" % rest
		_:
			return "Activate %s: %s" % [category, rest]


func get_parent_visible_rect() -> Vector2:
	var w := get_window()
	if w:
		return Vector2(w.size.x, w.size.y)
	return Vector2(800, 600)
