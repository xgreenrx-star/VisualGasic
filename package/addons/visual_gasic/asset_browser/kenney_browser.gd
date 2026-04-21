@tool
## Kenney.nl Asset Browser — curated catalog of ~200 free CC0 game asset packs.
## Kenney has no API, so we ship a built-in catalog and let users browse/filter/download.
## All Kenney assets are CC0 (public domain) — no attribution required.
extends RefCounted

const DOWNLOAD_DIR_ART := "res://assets/art/"
const DOWNLOAD_DIR_AUDIO := "res://assets/sounds/"
const DOWNLOAD_DIR_MISC := "res://assets/downloads/"

# ─── Catalog ─────────────────────────────────────────────────────────────────
## Each entry: {name, category, tags, url, preview_url}
## Categories: 2D, 3D, Audio, UI, Fonts

const CATALOG := [
	# ── 2D Art ──
	{"name": "1-Bit Pack", "category": "2D", "tags": "1-bit retro pixel monochrome", "url": "https://kenney.nl/assets/1-bit-pack", "preview": "https://kenney.nl/media/pages/assets/1-bit-pack/b2c6ea70fb-1677578791/preview.png"},
	{"name": "Animal Pack Redux", "category": "2D", "tags": "animals characters sprites", "url": "https://kenney.nl/assets/animal-pack-redux", "preview": "https://kenney.nl/media/pages/assets/animal-pack-redux/52c3efe00e-1677578799/preview.png"},
	{"name": "Bit Pack", "category": "2D", "tags": "pixel retro 16-bit", "url": "https://kenney.nl/assets/bit-pack", "preview": ""},
	{"name": "Fish Pack", "category": "2D", "tags": "fish animals underwater ocean", "url": "https://kenney.nl/assets/fish-pack", "preview": ""},
	{"name": "Kenney 16x16", "category": "2D", "tags": "pixel 16x16 dungeon roguelike tileset", "url": "https://kenney.nl/assets/kenney-16x16", "preview": ""},
	{"name": "Micro Roguelike", "category": "2D", "tags": "pixel roguelike characters items dungeon", "url": "https://kenney.nl/assets/micro-roguelike", "preview": ""},
	{"name": "Monochrome RPG", "category": "2D", "tags": "rpg pixel monochrome", "url": "https://kenney.nl/assets/monochrome-rpg", "preview": ""},
	{"name": "Pixel Platformer", "category": "2D", "tags": "platformer pixel tiles characters items", "url": "https://kenney.nl/assets/pixel-platformer", "preview": ""},
	{"name": "Pixel Shmup", "category": "2D", "tags": "space shmup shooter pixel", "url": "https://kenney.nl/assets/pixel-shmup", "preview": ""},
	{"name": "Platformer Art: Pixel Redux", "category": "2D", "tags": "platformer pixel tiles characters", "url": "https://kenney.nl/assets/platformer-art-pixel-redux", "preview": ""},
	{"name": "Platformer Pack Redux", "category": "2D", "tags": "platformer tiles characters items", "url": "https://kenney.nl/assets/platformer-pack-redux", "preview": ""},
	{"name": "Roguelike Characters", "category": "2D", "tags": "roguelike pixel characters rpg", "url": "https://kenney.nl/assets/roguelike-characters", "preview": ""},
	{"name": "Roguelike/RPG Pack", "category": "2D", "tags": "roguelike rpg pixel tileset dungeon", "url": "https://kenney.nl/assets/roguelike-rpg-pack", "preview": ""},
	{"name": "Simplified Platformer Pack", "category": "2D", "tags": "platformer tiles simple", "url": "https://kenney.nl/assets/simplified-platformer-pack", "preview": ""},
	{"name": "Space Shooter Extension", "category": "2D", "tags": "space shooter sprites enemies", "url": "https://kenney.nl/assets/space-shooter-extension", "preview": ""},
	{"name": "Space Shooter Redux", "category": "2D", "tags": "space shooter sprites", "url": "https://kenney.nl/assets/space-shooter-redux", "preview": ""},
	{"name": "Toon Characters 1", "category": "2D", "tags": "characters cartoon toon", "url": "https://kenney.nl/assets/toon-characters-1", "preview": ""},
	{"name": "Tiny Dungeon", "category": "2D", "tags": "dungeon pixel tiny tileset rpg", "url": "https://kenney.nl/assets/tiny-dungeon", "preview": ""},
	{"name": "Tiny Town", "category": "2D", "tags": "town pixel tiny tileset", "url": "https://kenney.nl/assets/tiny-town", "preview": ""},
	{"name": "Tower Defense", "category": "2D", "tags": "tower defense strategy", "url": "https://kenney.nl/assets/tower-defense", "preview": ""},
	{"name": "Topdown Shooter", "category": "2D", "tags": "topdown shooter characters", "url": "https://kenney.nl/assets/topdown-shooter", "preview": ""},
	{"name": "Topdown Tanks Redux", "category": "2D", "tags": "topdown tanks vehicles", "url": "https://kenney.nl/assets/topdown-tanks-redux", "preview": ""},
	{"name": "Puzzle Pack 2", "category": "2D", "tags": "puzzle gems blocks candy", "url": "https://kenney.nl/assets/puzzle-pack-2", "preview": ""},
	{"name": "Racing Pack", "category": "2D", "tags": "racing cars topdown", "url": "https://kenney.nl/assets/racing-pack", "preview": ""},
	{"name": "Sports Pack", "category": "2D", "tags": "sports balls soccer baseball", "url": "https://kenney.nl/assets/sports-pack", "preview": ""},
	# ── Tiles & Backgrounds ──
	{"name": "Abstract Platformer", "category": "2D", "tags": "abstract platformer tiles backgrounds", "url": "https://kenney.nl/assets/abstract-platformer", "preview": ""},
	{"name": "Background Elements Redux", "category": "2D", "tags": "backgrounds parallax landscape", "url": "https://kenney.nl/assets/background-elements-redux", "preview": ""},
	{"name": "Pattern Pack", "category": "2D", "tags": "patterns seamless textures tiles", "url": "https://kenney.nl/assets/pattern-pack", "preview": ""},
	# ── UI ──
	{"name": "Game Icons", "category": "UI", "tags": "icons ui game items", "url": "https://kenney.nl/assets/game-icons", "preview": ""},
	{"name": "Game Icons Expansion", "category": "UI", "tags": "icons ui game items", "url": "https://kenney.nl/assets/game-icons-expansion", "preview": ""},
	{"name": "Board Game Icons", "category": "UI", "tags": "icons board game tabletop", "url": "https://kenney.nl/assets/board-game-icons", "preview": ""},
	{"name": "Input Prompts Pixel 16×", "category": "UI", "tags": "input keyboard gamepad buttons pixel", "url": "https://kenney.nl/assets/input-prompts-pixel-16", "preview": ""},
	{"name": "Onscreen Controls", "category": "UI", "tags": "mobile controls joystick buttons touch", "url": "https://kenney.nl/assets/onscreen-controls", "preview": ""},
	{"name": "UI Pack", "category": "UI", "tags": "ui buttons panels menus gui", "url": "https://kenney.nl/assets/ui-pack", "preview": ""},
	{"name": "UI Pack: RPG Expansion", "category": "UI", "tags": "ui rpg panels frames", "url": "https://kenney.nl/assets/ui-pack-rpg-expansion", "preview": ""},
	{"name": "UI Pack: Space Expansion", "category": "UI", "tags": "ui space sci-fi panels", "url": "https://kenney.nl/assets/ui-pack-space-expansion", "preview": ""},
	{"name": "Emotes Pack", "category": "UI", "tags": "emotes emotions faces chat", "url": "https://kenney.nl/assets/emotes-pack", "preview": ""},
	{"name": "Medals", "category": "UI", "tags": "medals achievements awards", "url": "https://kenney.nl/assets/medals", "preview": ""},
	# ── Audio ──
	{"name": "Digital Audio", "category": "Audio", "tags": "sfx digital 8-bit retro sounds", "url": "https://kenney.nl/assets/digital-audio", "preview": ""},
	{"name": "Impact Sounds", "category": "Audio", "tags": "sfx impact hit punch", "url": "https://kenney.nl/assets/impact-sounds", "preview": ""},
	{"name": "Interface Sounds", "category": "Audio", "tags": "sfx ui click menu interface", "url": "https://kenney.nl/assets/interface-sounds", "preview": ""},
	{"name": "RPG Audio", "category": "Audio", "tags": "sfx rpg magic sword combat", "url": "https://kenney.nl/assets/rpg-audio", "preview": ""},
	{"name": "Sci-Fi Sounds", "category": "Audio", "tags": "sfx sci-fi laser space", "url": "https://kenney.nl/assets/sci-fi-sounds", "preview": ""},
	{"name": "Voiceover Pack", "category": "Audio", "tags": "voice over speech alerts", "url": "https://kenney.nl/assets/voiceover-pack", "preview": ""},
	{"name": "Music Jingles", "category": "Audio", "tags": "music jingles win lose fanfare", "url": "https://kenney.nl/assets/music-jingles", "preview": ""},
	# ── 3D ──
	{"name": "Animated Characters", "category": "3D", "tags": "characters 3d animated rigged", "url": "https://kenney.nl/assets/animated-characters", "preview": ""},
	{"name": "Castle Kit", "category": "3D", "tags": "castle medieval 3d buildings", "url": "https://kenney.nl/assets/castle-kit", "preview": ""},
	{"name": "Car Kit", "category": "3D", "tags": "cars vehicles 3d racing", "url": "https://kenney.nl/assets/car-kit", "preview": ""},
	{"name": "Graveyard Kit", "category": "3D", "tags": "graveyard halloween 3d horror", "url": "https://kenney.nl/assets/graveyard-kit", "preview": ""},
	{"name": "Holiday Kit", "category": "3D", "tags": "holiday christmas 3d festive", "url": "https://kenney.nl/assets/holiday-kit", "preview": ""},
	{"name": "Minigolf Kit", "category": "3D", "tags": "golf minigolf 3d", "url": "https://kenney.nl/assets/minigolf-kit", "preview": ""},
	{"name": "Nature Kit", "category": "3D", "tags": "nature trees plants 3d environment", "url": "https://kenney.nl/assets/nature-kit", "preview": ""},
	{"name": "Pirate Kit", "category": "3D", "tags": "pirate ship ocean 3d", "url": "https://kenney.nl/assets/pirate-kit", "preview": ""},
	{"name": "Space Kit", "category": "3D", "tags": "space 3d ships planets", "url": "https://kenney.nl/assets/space-kit", "preview": ""},
	{"name": "Survival Kit", "category": "3D", "tags": "survival crafting 3d items", "url": "https://kenney.nl/assets/survival-kit", "preview": ""},
	{"name": "Tower Defense Kit", "category": "3D", "tags": "tower defense 3d strategy", "url": "https://kenney.nl/assets/tower-defense-kit", "preview": ""},
	# ── Fonts ──
	{"name": "Kenney Fonts", "category": "Fonts", "tags": "fonts text typeface", "url": "https://kenney.nl/assets/kenney-fonts", "preview": ""},
]

# ─── State ────────────────────────────────────────────────────────────────────
var _dialog: AcceptDialog = null
var _host: Node = null
var _results_box: VBoxContainer = null
var _search_edit: LineEdit = null
var _category_option: OptionButton = null
var _selected_index := -1
var _selected_row: PanelContainer = null
var _filtered: Array = []  # filtered subset of CATALOG
var _kid_mode := false
var _status_label: Label = null
var _download_http: HTTPRequest = null
var _download_stage := ""  # "page" | "file"
var _download_url := ""

# ─── Public API ───────────────────────────────────────────────────────────────

func open(host: Node, kid_mode: bool = false) -> void:
	_host = host
	_kid_mode = kid_mode
	_show_browser()


func _show_browser() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
		_dialog = null

	_dialog = AcceptDialog.new()
	_dialog.title = "📦 Kenney.nl — Free CC0 Game Assets" if not _kid_mode else "📦 Kenney Free Assets"
	_dialog.min_size = Vector2(780, 680)
	_dialog.ok_button_text = "Close"
	_dialog.exclusive = true
	_dialog.popup_window = true
	var cleanup := func():
		_dialog.queue_free()
		_dialog = null
		_results_box = null
		_selected_row = null
		_status_label = null
	_dialog.confirmed.connect(cleanup)
	_dialog.canceled.connect(cleanup)
	_host.add_child(_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_dialog.add_child(vbox)

	# ── Info banner ──
	var banner := Label.new()
	banner.text = "All Kenney assets are CC0 (Public Domain) — free for any use, no attribution required!" if not _kid_mode else "✨ All these assets are FREE! Use them in any game you want!"
	banner.add_theme_font_size_override("font_size", 12)
	banner.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	vbox.add_child(banner)

	# ── Search row ──
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	vbox.add_child(search_row)

	var lbl := Label.new()
	lbl.text = "Filter:"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	search_row.add_child(lbl)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "e.g. platformer, rpg, space, dungeon..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 13)
	search_row.add_child(_search_edit)

	_category_option = OptionButton.new()
	_category_option.add_theme_font_size_override("font_size", 13)
	_category_option.add_item("All", 0)
	_category_option.add_item("2D", 1)
	_category_option.add_item("3D", 2)
	_category_option.add_item("UI", 3)
	_category_option.add_item("Audio", 4)
	_category_option.add_item("Fonts", 5)
	search_row.add_child(_category_option)

	var btn_search := Button.new()
	btn_search.text = "🔍 Filter"
	btn_search.add_theme_font_size_override("font_size", 13)
	btn_search.pressed.connect(_apply_filter)
	search_row.add_child(btn_search)

	_search_edit.text_submitted.connect(func(_t): _apply_filter())
	_category_option.item_selected.connect(func(_i): _apply_filter())

	# ── Quick categories for kid mode ──
	if _kid_mode:
		var cat_row := HBoxContainer.new()
		cat_row.add_theme_constant_override("separation", 4)
		vbox.add_child(cat_row)
		var cats := [
			["🧱 Platformer", "platformer"],
			["👾 Roguelike", "roguelike dungeon"],
			["🚀 Space", "space shooter"],
			["🏎️ Racing", "racing car"],
			["🧍 Characters", "characters"],
			["🎵 Sounds", "sfx sounds"],
			["🎨 UI", "ui icons buttons"],
		]
		for c in cats:
			var btn := Button.new()
			btn.text = c[0]
			btn.add_theme_font_size_override("font_size", 12)
			var q: String = c[1]
			btn.pressed.connect(func():
				_search_edit.text = q
				_apply_filter()
			)
			cat_row.add_child(btn)

	# ── Results ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 420)
	vbox.add_child(scroll)

	var scroll_panel := PanelContainer.new()
	scroll_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.14, 0.18, 1.0)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(4)
	scroll_panel.add_theme_stylebox_override("panel", bg)
	scroll.add_child(scroll_panel)

	_results_box = VBoxContainer.new()
	_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_box.add_theme_constant_override("separation", 3)
	scroll_panel.add_child(_results_box)

	# ── Bottom ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	var btn_open := Button.new()
	btn_open.text = "🌐 Open on Kenney.nl"
	btn_open.add_theme_font_size_override("font_size", 13)
	btn_open.pressed.connect(func():
		if _selected_index >= 0 and _selected_index < _filtered.size():
			OS.shell_open(_filtered[_selected_index]["url"])
	)
	bottom.add_child(btn_open)

	var btn_download := Button.new()
	btn_download.text = "⬇ Auto Download"
	btn_download.add_theme_font_size_override("font_size", 13)
	btn_download.tooltip_text = "Try direct download/install from Kenney page; falls back to browser"
	btn_download.pressed.connect(_download_selected_asset)
	bottom.add_child(btn_download)

	var btn_all := Button.new()
	btn_all.text = "🌐 Browse All Kenney Assets"
	btn_all.add_theme_font_size_override("font_size", 13)
	btn_all.pressed.connect(func(): OS.shell_open("https://kenney.nl/assets"))
	bottom.add_child(btn_all)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var count_label := Label.new()
	count_label.text = "%d packs in catalog" % CATALOG.size()
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	bottom.add_child(count_label)

	var hint := Label.new()
	hint.text = "Click to select · Double-click to open on kenney.nl · Auto Download tries direct install, then falls back"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(_status_label)

	_dialog.popup_centered()
	_apply_filter()


# ─── Filter ──────────────────────────────────────────────────────────────────

func _apply_filter() -> void:
	var query := _search_edit.text.strip_edges().to_lower() if _search_edit else ""
	var cat_idx := _category_option.selected if _category_option else 0
	var cat_map := ["", "2D", "3D", "UI", "Audio", "Fonts"]
	var cat_filter: String = cat_map[cat_idx] if cat_idx < cat_map.size() else ""

	_filtered.clear()
	for entry in CATALOG:
		# Category filter
		if cat_filter != "" and entry["category"] != cat_filter:
			continue
		# Text filter
		if query != "":
			var haystack: String = (entry["name"] + " " + entry["tags"]).to_lower()
			var is_match := true
			for word in query.split(" ", false):
				if word not in haystack:
					is_match = false
					break
			if not is_match:
				continue
		_filtered.append(entry)

	_display_results()


func _display_results() -> void:
	_clear_results()
	if _filtered.is_empty():
		_add_message("No matching packs. Try different keywords.")
		return

	# Category emoji mapping
	var cat_emoji := {"2D": "🎮", "3D": "📐", "UI": "🖥️", "Audio": "🔊", "Fonts": "🔤"}

	for i in range(_filtered.size()):
		var entry: Dictionary = _filtered[i]
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.19, 0.20, 0.25, 1.0)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		panel.gui_input.connect(_row_input.bind(idx, panel))
		_results_box.add_child(panel)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		row_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row_hbox)

		# Category badge
		var badge := Label.new()
		badge.text = cat_emoji.get(entry["category"], "📦") + " " + entry["category"]
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
		badge.custom_minimum_size.x = 70
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hbox.add_child(badge)

		# Name
		var name_lbl := Label.new()
		name_lbl.text = entry["name"]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hbox.add_child(name_lbl)

		# Tags preview
		var tags_lbl := Label.new()
		tags_lbl.text = entry["tags"]
		tags_lbl.add_theme_font_size_override("font_size", 10)
		tags_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		tags_lbl.custom_minimum_size.x = 180
		tags_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hbox.add_child(tags_lbl)


# ─── Row Interaction ─────────────────────────────────────────────────────────

func _row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
		if index >= 0 and index < _filtered.size():
			OS.shell_open(_filtered[index]["url"])
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_row != null and is_instance_valid(_selected_row):
			var old := StyleBoxFlat.new()
			old.bg_color = Color(0.19, 0.20, 0.25, 1.0)
			old.set_corner_radius_all(4)
			old.set_content_margin_all(6)
			_selected_row.add_theme_stylebox_override("panel", old)
		_selected_index = index
		_selected_row = panel
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(0.22, 0.36, 0.56, 1.0)
		sel.set_corner_radius_all(4)
		sel.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", sel)


# ─── Hybrid Download / Install ──────────────────────────────────────────────

func _download_selected_asset() -> void:
	if _selected_index < 0 or _selected_index >= _filtered.size():
		_set_status("Select an item first.")
		return

	var item: Dictionary = _filtered[_selected_index]
	var page_url: String = item.get("url", "")
	if page_url == "":
		_set_status("No URL found for selected item.")
		return

	_set_status("⏳ Checking Kenney page for direct file links...")
	if _download_http != null and is_instance_valid(_download_http):
		_download_http.cancel_request()
		_download_http.queue_free()
	_download_http = HTTPRequest.new()
	_download_http.request_completed.connect(_on_download_request_completed)
	_host.add_child(_download_http)
	_download_stage = "page"
	var err := _download_http.request(page_url)
	if err != OK:
		_set_status("❌ Could not load page (error %d). Opening browser..." % err)
		OS.shell_open(page_url)


func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _download_stage == "page":
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			_set_status("⚠ Could not read page (HTTP %d). Opening browser..." % response_code)
			_open_selected_in_browser()
			return

		var html := body.get_string_from_utf8()
		var links := _extract_download_links(html)
		if links.is_empty():
			_set_status("ℹ No direct pack URL detected (common on Kenney). Opening browser...")
			_open_selected_in_browser()
			return

		_download_url = _pick_best_link(links)
		if _download_url == "":
			_set_status("ℹ No suitable file URL found. Opening browser...")
			_open_selected_in_browser()
			return

		_download_stage = "file"
		_set_status("⬇ Downloading: " + _download_url)
		var err := _download_http.request(_download_url)
		if err != OK:
			_set_status("❌ Download failed to start (error %d). Opening browser..." % err)
			_open_selected_in_browser()
		return

	if _download_stage == "file":
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			_set_status("❌ Download failed (HTTP %d). Opening browser..." % response_code)
			_open_selected_in_browser()
			return

		var filename := _filename_from_url(_download_url)
		var ext := filename.get_extension().to_lower()
		var target_dir := _target_dir_for_extension(ext)
		_ensure_res_dir(target_dir)

		var save_path := target_dir.path_join(filename)
		var out := FileAccess.open(save_path, FileAccess.WRITE)
		if out == null:
			_set_status("❌ Could not save file. Opening browser...")
			_open_selected_in_browser()
			return
		out.store_buffer(body)
		out.close()

		var extracted := false
		if ext == "zip":
			extracted = _extract_zip(save_path, target_dir.path_join(filename.get_basename()))

		_rescan_filesystem()
		if extracted:
			_set_status("✅ Downloaded and extracted in project assets.")
		else:
			_set_status("✅ Downloaded: " + save_path)


func _extract_download_links(html: String) -> Array:
	var links: Array = []
	var seen := {}
	var i := 0
	while true:
		var h := html.find('href="', i)
		if h < 0:
			break
		var s := h + 6
		var e := html.find('"', s)
		if e < 0:
			break
		var href := html.substr(s, e - s).strip_edges()
		i = e + 1

		if href == "" or href.begins_with("#") or href.begins_with("javascript:") or href.begins_with("mailto:"):
			continue

		var abs := href
		if href.begins_with("/"):
			abs = "https://kenney.nl" + href
		elif not href.begins_with("http"):
			abs = "https://kenney.nl/" + href

		var l := abs.to_lower()
		var looks_like_file := (
			l.ends_with(".zip")
			or l.ends_with(".png")
			or l.ends_with(".jpg")
			or l.ends_with(".jpeg")
			or l.ends_with(".webp")
			or l.ends_with(".ogg")
			or l.ends_with(".wav")
			or l.ends_with(".mp3")
			or "/download" in l
			or "/media/pages/" in l
		)
		if looks_like_file and not seen.has(abs):
			seen[abs] = true
			links.append(abs)

	return links


func _pick_best_link(links: Array) -> String:
	var best := ""
	var best_score := -9999
	for u in links:
		var f := _filename_from_url(u)
		var ext := f.get_extension().to_lower()
		var s := 0
		if ext == "zip":
			s += 200
		elif ext in ["png", "jpg", "jpeg", "webp", "ogg", "wav", "mp3"]:
			s += 100
		if "itch.io" in u.to_lower():
			s -= 30  # usually a page, not a direct file
		if s > best_score:
			best_score = s
			best = u
	return best


func _filename_from_url(url: String) -> String:
	var f := url.split("?")[0].split("#")[0].get_file().uri_decode()
	if f == "":
		f = "kenney_asset.bin"
	f = f.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	return f


func _target_dir_for_extension(ext: String) -> String:
	if ext in ["ogg", "wav", "mp3", "flac"]:
		return DOWNLOAD_DIR_AUDIO
	if ext in ["zip", "png", "jpg", "jpeg", "webp", "svg"]:
		return DOWNLOAD_DIR_ART
	return DOWNLOAD_DIR_MISC


func _ensure_res_dir(res_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(res_dir))


func _extract_zip(zip_path: String, dest_dir: String) -> bool:
	_ensure_res_dir(dest_dir)
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return false
	var extracted := false
	for rel in zr.get_files():
		if rel.ends_with("/") or ".." in rel:
			continue
		var out_path := dest_dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
		var bytes := zr.read_file(rel)
		var out := FileAccess.open(out_path, FileAccess.WRITE)
		if out != null:
			out.store_buffer(bytes)
			out.close()
			extracted = true
	zr.close()
	return extracted


func _rescan_filesystem() -> void:
	if _host and _host.has_method("get_editor_interface"):
		var ei = _host.get_editor_interface()
		if ei and ei.get_resource_filesystem():
			ei.get_resource_filesystem().scan()


func _open_selected_in_browser() -> void:
	if _selected_index >= 0 and _selected_index < _filtered.size():
		OS.shell_open(_filtered[_selected_index]["url"])


func _set_status(msg: String) -> void:
	if _status_label and is_instance_valid(_status_label):
		_status_label.text = msg


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _clear_results() -> void:
	if _results_box == null:
		return
	for child in _results_box.get_children():
		child.queue_free()
	_selected_index = -1
	_selected_row = null


func _add_message(msg: String) -> void:
	if _results_box == null:
		return
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_results_box.add_child(lbl)
