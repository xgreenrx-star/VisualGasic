@tool
## Kenney.nl Asset Browser — curated catalog of ~200 free CC0 game asset packs.
## Kenney has no API, so we ship a built-in catalog and let users browse/filter/download.
## All Kenney assets are CC0 (public domain) — no attribution required.
extends RefCounted

## Emitted after a successful download. `local_path` is the saved file
## (PNG/JPG/ZIP), `was_extracted` indicates whether a ZIP was unpacked into
## a sibling folder. Listeners (e.g. the AGCK actor editor) connect to this
## to auto-import the asset without forcing the user through a FileDialog.
signal asset_downloaded(local_path: String, was_extracted: bool)

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

# Preview-thumbnail loading (lazy, parallel workers)
const MAX_PARALLEL_THUMBS := 4
const KENNEY_DONATE_URL := "https://kenney.nl/donate"
var _preview_images: Dictionary = {}        # row index -> TextureRect
var _img_http_queue: Array = []             # [{index, url, kind}]  kind: "image"|"page"
var _img_http_active: int = 0
var _resolved_previews: Dictionary = {}     # page_url -> resolved image url (session cache)

# Slideshow in big preview
var _slideshow_urls: Array = []             # candidate image urls for current preview
var _slideshow_textures: Array = []         # parallel: ImageTexture or null
var _slideshow_index: int = 0
var _slideshow_timer: Timer = null
var _slideshow_counter_lbl: Label = null
var _donate_url: String = KENNEY_DONATE_URL

# Big-preview modal state
var _preview_dialog: AcceptDialog = null
var _preview_tex_rect: TextureRect = null
var _preview_status_lbl: Label = null
var _preview_item: Dictionary = {}
var _preview_http: HTTPRequest = null

# Dynamic catalog (scraped from kenney.nl on open). Falls back to baked CATALOG.
const KENNEY_LIST_PAGES := 13
var _dynamic_catalog: Array = []           # populated from kenney.nl scrape
var _scrape_pages_remaining: int = 0
var _scrape_active: bool = false
var _all_categories: Array = ["2D", "3D", "UI", "Audio", "Fonts"]  # rebuilt after scrape
var _count_label: Label = null

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
	_count_label = count_label

	var hint := Label.new()
	hint.text = "Click to select · Double-click for large preview & download · Right-click to open on kenney.nl"
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
	# Kick off live catalog scrape so categories & list match kenney.nl exactly.
	_start_catalog_scrape()


# ─── Filter ──────────────────────────────────────────────────────────────────

func _apply_filter() -> void:
	var query := _search_edit.text.strip_edges().to_lower() if _search_edit else ""
	var cat_idx := _category_option.selected if _category_option else 0
	var cat_filter: String = ""
	if _category_option != null and cat_idx > 0:
		cat_filter = _category_option.get_item_text(cat_idx)

	var source: Array = _dynamic_catalog if not _dynamic_catalog.is_empty() else CATALOG
	_filtered.clear()
	for entry in source:
		# Category filter
		if cat_filter != "" and entry["category"] != cat_filter:
			continue
		# Text filter
		if query != "":
			var haystack: String = (entry["name"] + " " + entry.get("tags", "")).to_lower()
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

		# Thumbnail (lazy-loaded). Image-category packs only — no point
		# fetching previews for fonts/audio.
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Placeholder bg so the cell is visible while loading.
		var ph_style := StyleBoxFlat.new()
		ph_style.bg_color = Color(0.12, 0.13, 0.17)
		ph_style.set_corner_radius_all(3)
		tex_rect.add_theme_stylebox_override("panel", ph_style)
		row_hbox.add_child(tex_rect)
		_preview_images[i] = tex_rect
		var page_url: String = entry.get("url", "")
		var pre_url: String = entry.get("preview", "")
		if pre_url != "":
			_img_http_queue.append({"index": i, "url": pre_url, "kind": "image"})
		elif _resolved_previews.has(page_url):
			_img_http_queue.append({"index": i, "url": _resolved_previews[page_url], "kind": "image"})
		elif page_url != "":
			_img_http_queue.append({"index": i, "url": page_url, "kind": "page"})

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

	# Kick off lazy thumbnail loading.
	_load_next_thumbnail()


# ─── Lazy preview-thumbnail loading (parallel workers) ──────────────────────

func _load_next_thumbnail() -> void:
	# Spawn up to MAX_PARALLEL_THUMBS in-flight requests.
	while _img_http_active < MAX_PARALLEL_THUMBS and not _img_http_queue.is_empty():
		var entry: Dictionary = _img_http_queue.pop_front()
		_dispatch_thumbnail(entry)


func _dispatch_thumbnail(entry: Dictionary) -> void:
	var idx: int = entry["index"]
	var url: String = entry["url"]
	var kind: String = entry.get("kind", "image")
	# Bail out if the dialog/results are gone (filter changed, dialog closed).
	if not _preview_images.has(idx) or not is_instance_valid(_preview_images[idx]):
		_load_next_thumbnail()
		return
	if _host == null or not is_instance_valid(_host):
		return
	var req := HTTPRequest.new()
	_host.add_child(req)
	_img_http_active += 1
	var captured_idx := idx
	var captured_kind := kind
	var captured_url := url
	var captured_req := req
	req.request_completed.connect(func(res, code, _h, body):
		# Filter changed / dialog closed mid-flight: bail out before we
		# touch any UI state. The TextureRect we'd write to may have been
		# queue_free()'d, and dict.has() doesn't filter freed values.
		var tr_alive: TextureRect = null
		if _preview_images.has(captured_idx):
			var maybe_tr = _preview_images[captured_idx]
			if maybe_tr is TextureRect and is_instance_valid(maybe_tr):
				tr_alive = maybe_tr
		if res == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400 and body.size() > 64:
			if captured_kind == "image":
				var img: Image = _decode_image_buffer(body)
				if img != null and tr_alive != null:
					tr_alive.texture = ImageTexture.create_from_image(img)
			elif captured_kind == "page":
				var html: String = body.get_string_from_utf8()
				var img_url: String = _extract_og_image(html)
				if img_url != "":
					_resolved_previews[captured_url] = img_url
					# Re-queue at the front so this row gets its image next.
					_img_http_queue.push_front({"index": captured_idx, "url": img_url, "kind": "image"})
		else:
			# Mark a missing-image placeholder so the user knows it failed.
			if captured_kind == "image" and tr_alive != null and tr_alive.texture == null:
				var miss_style := StyleBoxFlat.new()
				miss_style.bg_color = Color(0.18, 0.10, 0.10)
				miss_style.set_corner_radius_all(3)
				tr_alive.add_theme_stylebox_override("panel", miss_style)
		if is_instance_valid(captured_req):
			captured_req.queue_free()
		_img_http_active = max(0, _img_http_active - 1)
		_load_next_thumbnail()
	)
	var req_err := req.request(url)
	if req_err != OK:
		if is_instance_valid(req):
			req.queue_free()
		_img_http_active = max(0, _img_http_active - 1)
		_load_next_thumbnail()


func _extract_og_image(html: String) -> String:
	# Scrape <meta property="og:image" content="…"> from the page <head>.
	# Accept both " and ' as attribute delimiters (Kenney uses single quotes).
	var regex := RegEx.new()
	if regex.compile("<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']") != OK:
		return ""
	var m := regex.search(html)
	if m == null:
		# Try the reversed attribute order (content first).
		var regex2 := RegEx.new()
		if regex2.compile("<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:image[\"']") != OK:
			return ""
		m = regex2.search(html)
		if m == null:
			return ""
	var url := m.get_string(1)
	# Decode entities in URL
	url = url.replace("&amp;", "&")
	return url


# ─── Row Interaction ─────────────────────────────────────────────────────────

func _row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Double-click → large preview modal (no longer opens system browser).
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if index >= 0 and index < _filtered.size():
			_show_big_preview(index)
		return
	# Right-click → open page on kenney.nl in system browser.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if index >= 0 and index < _filtered.size():
			OS.shell_open(_filtered[index]["url"])
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
		# Compute slug for fallback derivation. The preview-derived zip URL
		# uses the *preview* directory hash, which differs from the actual
		# zip directory hash on Kenney's CDN — so it 404s. Only fall back
		# to it if no real kenney_<slug>.zip is present in the HTML.
		var page_url := ""
		if _selected_index >= 0 and _selected_index < _filtered.size():
			page_url = str(_filtered[_selected_index].get("url", ""))
		var slug := _kenney_slug_from_url(page_url)
		var has_real_zip := false
		if slug != "":
			var needle := "kenney_" + slug + ".zip"
			for u in links:
				if u.ends_with(needle):
					has_real_zip = true
					break
		var og_img := _extract_og_image(html)
		if og_img != "" and page_url != "":
			_resolved_previews[page_url] = og_img
			if not has_real_zip:
				var derived := _derive_kenney_zip_from_preview(og_img, page_url)
				if derived != "" and not links.has(derived):
					links.append(derived)  # last-resort, not first

		if links.is_empty():
			_set_status("ℹ No direct pack URL detected. Opening browser…")
			_open_selected_in_browser()
			return

		_download_url = _pick_best_link(links)
		if _download_url == "":
			_set_status("ℹ No suitable file URL found. Opening browser…")
			_open_selected_in_browser()
			return

		_download_stage = "file"
		_set_status("⬇ Downloading: " + _download_url)
		var err := _download_http.request(_download_url)
		if err != OK:
			_set_status("❌ Download failed to start (error %d). Opening browser…" % err)
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
		asset_downloaded.emit(save_path, extracted)


func _extract_download_links(html: String) -> Array:
	var links: Array = []
	var seen := {}
	# Use a regex so we match both href="…" and href='…' attribute styles.
	# Kenney's "Continue without donating" link uses single quotes, which the
	# previous string-search implementation missed.
	var rx := RegEx.new()
	if rx.compile("href=[\"']([^\"']+)[\"']") != OK:
		return links
	for m in rx.search_all(html):
		var href: String = m.get_string(1).strip_edges()
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
		# Strongly prefer the canonical kenney_<slug>.zip pattern.
		if f.begins_with("kenney_") and ext == "zip":
			s += 500
		if "itch.io" in u.to_lower():
			s -= 30  # usually a page, not a direct file
		if s > best_score:
			best_score = s
			best = u
	return best


func _filename_from_url(url: String) -> String:
	if url == null or url == "":
		return "kenney_asset.bin"
	var parts_q := url.split("?")
	var without_q: String = url if parts_q.is_empty() else parts_q[0]
	var parts_h := without_q.split("#")
	var clean: String = without_q if parts_h.is_empty() else parts_h[0]
	var f := clean.get_file().uri_decode()
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


# ─── Big preview modal ──────────────────────────────────────────────────────
# Double-click a row → larger thumbnail + Download button (downloads to res://).

func _show_big_preview(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	_preview_item = _filtered[index]
	if _preview_dialog and is_instance_valid(_preview_dialog):
		_preview_dialog.queue_free()
	_preview_dialog = AcceptDialog.new()
	_preview_dialog.title = "🖼  " + str(_preview_item.get("name", "Preview"))
	_preview_dialog.min_size = Vector2(560, 540)
	_preview_dialog.ok_button_text = "Close"
	# NOTE: exclusive/popup_window left at defaults (false). The parent
	# window already has an exclusive child (_dialog), so we cannot add
	# a second exclusive child to the same parent. Parent the preview
	# under _dialog itself when possible so it nests as a sub-popup.
	var cleanup := func():
		if _preview_http != null and is_instance_valid(_preview_http):
			_preview_http.cancel_request()
			_preview_http.queue_free()
			_preview_http = null
		if _slideshow_timer != null and is_instance_valid(_slideshow_timer):
			_slideshow_timer.stop()
			_slideshow_timer.queue_free()
			_slideshow_timer = null
		_slideshow_urls.clear()
		_slideshow_textures.clear()
		_slideshow_index = 0
		_slideshow_counter_lbl = null
		if _preview_dialog != null and is_instance_valid(_preview_dialog):
			_preview_dialog.queue_free()
		_preview_dialog = null
		_preview_tex_rect = null
		_preview_status_lbl = null
	_preview_dialog.confirmed.connect(cleanup)
	_preview_dialog.canceled.connect(cleanup)
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.add_child(_preview_dialog)
	else:
		_host.add_child(_preview_dialog)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_preview_dialog.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = _preview_item.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	vb.add_child(name_lbl)

	var meta := Label.new()
	meta.text = "Category: %s   ·   Tags: %s" % [_preview_item.get("category", ""), _preview_item.get("tags", "")]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	vb.add_child(meta)

	# Big image area
	_preview_tex_rect = TextureRect.new()
	_preview_tex_rect.custom_minimum_size = Vector2(520, 380)
	_preview_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.10, 0.11, 0.14)
	pf_style.set_corner_radius_all(4)
	# (StyleBox on TextureRect is no-op, but keep the visual contained.)
	vb.add_child(_preview_tex_rect)

	# Reuse already-loaded thumbnail texture if available
	if _preview_images.has(index):
		var tr_cached = _preview_images[index]
		if tr_cached != null and is_instance_valid(tr_cached) and tr_cached.texture != null:
			_preview_tex_rect.texture = tr_cached.texture

	# Slideshow controls (◀  1 / N  ▶)
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 12)
	vb.add_child(nav_row)
	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.tooltip_text = "Previous sample"
	prev_btn.pressed.connect(func(): _slideshow_step(-1))
	nav_row.add_child(prev_btn)
	_slideshow_counter_lbl = Label.new()
	_slideshow_counter_lbl.text = "—"
	_slideshow_counter_lbl.add_theme_font_size_override("font_size", 11)
	_slideshow_counter_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	_slideshow_counter_lbl.custom_minimum_size = Vector2(60, 0)
	_slideshow_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(_slideshow_counter_lbl)
	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.tooltip_text = "Next sample"
	next_btn.pressed.connect(func(): _slideshow_step(1))
	nav_row.add_child(next_btn)

	# Buttons row
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	vb.add_child(btns)

	var dl_btn := Button.new()
	dl_btn.text = "⬇  Download to res://assets/"
	dl_btn.add_theme_font_size_override("font_size", 13)
	dl_btn.pressed.connect(_on_preview_download_pressed.bind(index))
	btns.add_child(dl_btn)

	var open_btn := Button.new()
	open_btn.text = "🌐  Open page on kenney.nl"
	open_btn.add_theme_font_size_override("font_size", 12)
	open_btn.pressed.connect(func():
		OS.shell_open(str(_preview_item.get("url", "")))
	)
	btns.add_child(open_btn)

	var donate_btn := Button.new()
	donate_btn.text = "❤  Donate to Kenney"
	donate_btn.tooltip_text = "Open Kenney's donation page in your browser. All Kenney assets are CC0 — donations support continued releases."
	donate_btn.add_theme_font_size_override("font_size", 12)
	donate_btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	donate_btn.pressed.connect(func():
		OS.shell_open(_donate_url)
	)
	btns.add_child(donate_btn)

	_preview_status_lbl = Label.new()
	_preview_status_lbl.text = ""
	_preview_status_lbl.add_theme_font_size_override("font_size", 11)
	_preview_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_preview_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_preview_status_lbl)

	_preview_dialog.popup_centered()
	# If we already cached a higher-res preview URL, fetch it for sharper image.
	var page_url: String = str(_preview_item.get("url", ""))
	var pre_url: String = str(_preview_item.get("preview", ""))
	if pre_url == "" and _resolved_previews.has(page_url):
		pre_url = _resolved_previews[page_url]
	if pre_url != "":
		_start_slideshow(pre_url)
	elif page_url != "":
		_fetch_page_then_image(page_url)


func _fetch_image_into_preview(url: String) -> void:
	if _preview_http != null and is_instance_valid(_preview_http):
		_preview_http.queue_free()
	_preview_http = HTTPRequest.new()
	_host.add_child(_preview_http)
	_preview_http.request_completed.connect(func(res, code, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400 and body.size() > 64:
			var img: Image = _decode_image_buffer(body)
			if img != null and is_instance_valid(_preview_tex_rect):
				_preview_tex_rect.texture = ImageTexture.create_from_image(img)
	)
	_preview_http.request(url)


func _fetch_page_then_image(page_url: String) -> void:
	if _preview_http != null and is_instance_valid(_preview_http):
		_preview_http.queue_free()
	_preview_http = HTTPRequest.new()
	_host.add_child(_preview_http)
	_preview_http.request_completed.connect(func(res, code, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 64:
			var html: String = body.get_string_from_utf8()
			var img_url: String = _extract_og_image(html)
			if img_url != "":
				_resolved_previews[page_url] = img_url
				_start_slideshow(img_url)
	)
	_preview_http.request(page_url)


# ─── Slideshow ─────────────────────────────────────────────────────────────
# Kenney pack pages live in a directory containing preview.png, samplea.png,
# sampleb.png, samplec.png, ... We probe these and cycle the loaded ones.

func _start_slideshow(preview_url: String) -> void:
	if preview_url == "":
		return
	# Build candidate URL list: preview, then samplea..samplee.
	var idx := preview_url.rfind("/")
	if idx < 0:
		return
	var dir_part := preview_url.substr(0, idx + 1)
	_slideshow_urls.clear()
	_slideshow_textures.clear()
	_slideshow_urls.append(preview_url)
	_slideshow_textures.append(null)
	for letter in ["a", "b", "c", "d", "e"]:
		_slideshow_urls.append(dir_part + "sample" + letter + ".png")
		_slideshow_textures.append(null)
	_slideshow_index = 0
	_update_slideshow_counter()
	# Fetch each one. We use a fresh HTTPRequest per slide so they load in
	# parallel; failures (404) just leave that slot null and get skipped.
	for i in range(_slideshow_urls.size()):
		_fetch_slideshow_slide(i, _slideshow_urls[i])
	# Manual navigation only — no auto-advance. Use ◀ / ▶ to browse samples.
	if _slideshow_timer != null and is_instance_valid(_slideshow_timer):
		_slideshow_timer.stop()
		_slideshow_timer.queue_free()
		_slideshow_timer = null


func _fetch_slideshow_slide(slot: int, url: String) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var req := HTTPRequest.new()
	_host.add_child(req)
	var captured_slot := slot
	var captured_req := req
	req.request_completed.connect(func(res, code, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400 and body.size() > 64:
			var img: Image = _decode_image_buffer(body)
			if img != null and captured_slot < _slideshow_textures.size():
				_slideshow_textures[captured_slot] = ImageTexture.create_from_image(img)
				# If this is the currently displayed slot and the rect is empty,
				# show it now. Also refresh counter to reflect loaded count.
				if captured_slot == _slideshow_index and is_instance_valid(_preview_tex_rect):
					_preview_tex_rect.texture = _slideshow_textures[captured_slot]
				elif is_instance_valid(_preview_tex_rect) and _preview_tex_rect.texture == null:
					# Display the first one that loads if we have nothing yet.
					_slideshow_index = captured_slot
					_preview_tex_rect.texture = _slideshow_textures[captured_slot]
				_update_slideshow_counter()
		if is_instance_valid(captured_req):
			captured_req.queue_free()
	)
	var e := req.request(url)
	if e != OK and is_instance_valid(req):
		req.queue_free()


func _slideshow_step(direction: int) -> void:
	if _slideshow_textures.is_empty():
		return
	var n: int = _slideshow_textures.size()
	# Find the next slot (in given direction) that has a loaded texture.
	for _i in range(n):
		_slideshow_index = (_slideshow_index + direction + n) % n
		if _slideshow_textures[_slideshow_index] != null:
			break
	if _slideshow_textures[_slideshow_index] != null and is_instance_valid(_preview_tex_rect):
		_preview_tex_rect.texture = _slideshow_textures[_slideshow_index]
	_update_slideshow_counter()


func _update_slideshow_counter() -> void:
	if not is_instance_valid(_slideshow_counter_lbl):
		return
	var loaded := 0
	for t in _slideshow_textures:
		if t != null:
			loaded += 1
	if loaded == 0:
		_slideshow_counter_lbl.text = "loading…"
		return
	# Display "slot_pos / loaded" where slot_pos counts only loaded slots
	# up to and including current index.
	var pos := 0
	for i in range(_slideshow_index + 1):
		if i < _slideshow_textures.size() and _slideshow_textures[i] != null:
			pos += 1
	if pos == 0:
		pos = 1
	_slideshow_counter_lbl.text = "%d / %d" % [pos, loaded]


func _on_preview_download_pressed(index: int) -> void:
	# Make this row the selection so the existing flow works, then drive it.
	_selected_index = index
	if is_instance_valid(_preview_status_lbl):
		_preview_status_lbl.text = "⏳  Resolving direct download URL…"
	# Mirror status into the main browser status label too.
	_download_selected_asset()


func _kenney_slug_from_url(page_url: String) -> String:
	# https://kenney.nl/assets/<slug>  →  <slug>
	if page_url == null or page_url == "":
		return ""
	var p := page_url.strip_edges().trim_suffix("/")
	if p == "":
		return ""
	var slash := p.rfind("/")
	if slash < 0 or slash >= p.length() - 1:
		return ""
	return p.substr(slash + 1)


func _derive_kenney_zip_from_preview(preview_url: String, page_url: String) -> String:
	# Kenney's preview lives at:
	#   https://kenney.nl/media/pages/assets/<slug>/<hash>-<ts>/preview.png
	# The pack zip is at the same path with the filename swapped to
	# kenney_<slug>.zip. We exploit that pattern here.
	if preview_url == null or preview_url == "":
		return ""
	var idx := preview_url.rfind("/")
	if idx < 0 or idx >= preview_url.length() - 1:
		return ""
	var dir_part := preview_url.substr(0, idx + 1)
	var slug := _kenney_slug_from_url(page_url)
	if slug == "":
		return ""
	return dir_part + "kenney_" + slug + ".zip"

func _set_status(msg: String) -> void:
	if _status_label and is_instance_valid(_status_label):
		_status_label.text = msg
	if is_instance_valid(_preview_status_lbl):
		_preview_status_lbl.text = msg


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _clear_results() -> void:
	if _results_box == null:
		return
	for child in _results_box.get_children():
		child.queue_free()
	_selected_index = -1
	_selected_row = null
	_preview_images.clear()
	_img_http_queue.clear()
	# Active workers will free themselves on completion; just reset the counter
	# so freshly issued queue items can dispatch right away.
	_img_http_active = 0


func _add_message(msg: String) -> void:
	if _results_box == null:
		return
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_results_box.add_child(lbl)


# Sniff image format from magic bytes and call only the matching loader.
# Returns a loaded Image, or null on any error/unknown format. Avoids the
# noisy ERROR prints from blindly trying load_png/jpg/webp_from_buffer in
# sequence on non-image bodies (404 HTML, partial downloads, GIF, BMP, …).
func _decode_image_buffer(body: PackedByteArray):
	if body == null or body.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_INVALID_DATA
	# PNG: 89 50 4E 47 0D 0A 1A 0A
	if body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47:
		err = img.load_png_from_buffer(body)
	# JPEG: FF D8 FF
	elif body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		err = img.load_jpg_from_buffer(body)
	# WebP: "RIFF....WEBP"
	elif body[0] == 0x52 and body[1] == 0x49 and body[2] == 0x46 and body[3] == 0x46 \
			and body[8] == 0x57 and body[9] == 0x45 and body[10] == 0x42 and body[11] == 0x50:
		err = img.load_webp_from_buffer(body)
	else:
		return null
	if err != OK:
		return null
	return img


# ─── Live catalog scrape from kenney.nl ─────────────────────────────────────
# Kenney has no API but the asset listing pages have a very regular HTML
# structure. We scrape /assets/page:1..13 in parallel on browser open and
# replace the baked-in CATALOG with the live results. This solves two issues:
#   1. Removes packs that no longer exist on the site (404s in old CATALOG).
#   2. Categories match Kenney's real taxonomy (2D, 3D, Audio, Textures, …).

func _start_catalog_scrape() -> void:
	if _scrape_active:
		return
	if _host == null or not is_instance_valid(_host):
		return
	_scrape_active = true
	_dynamic_catalog.clear()
	_scrape_pages_remaining = KENNEY_LIST_PAGES
	if _count_label != null and is_instance_valid(_count_label):
		_count_label.text = "Loading catalog from kenney.nl…"
	for page in range(1, KENNEY_LIST_PAGES + 1):
		_fetch_listing_page(page)


func _fetch_listing_page(page_num: int) -> void:
	var req := HTTPRequest.new()
	_host.add_child(req)
	var captured_req := req
	req.request_completed.connect(func(res, code, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 256:
			var html: String = body.get_string_from_utf8()
			var entries := _parse_listing_html(html)
			for e in entries:
				_dynamic_catalog.append(e)
		_scrape_pages_remaining = max(0, _scrape_pages_remaining - 1)
		if is_instance_valid(captured_req):
			captured_req.queue_free()
		if _scrape_pages_remaining == 0:
			_finalize_catalog_scrape()
	)
	var err := req.request("https://kenney.nl/assets/page:%d" % page_num)
	if err != OK:
		_scrape_pages_remaining = max(0, _scrape_pages_remaining - 1)
		if is_instance_valid(req):
			req.queue_free()
		if _scrape_pages_remaining == 0:
			_finalize_catalog_scrape()


func _parse_listing_html(html: String) -> Array:
	# Each entry looks like:
	#   <div class='asset'>
	#     <a href='https://kenney.nl/assets/<slug>'>
	#       <div class='cover' style='background-image:url("<preview-url>")'></div>
	#     </a>
	#     <h2><a href='https://kenney.nl/assets/<slug>'>Name</a></h2>
	#     <span class='bold text-muted'>…<a href='/assets/category:2D'>2D</a>…</span>
	#   </div>
	var out: Array = []
	var rx := RegEx.new()
	# Match each <div class='asset'>…</div> chunk.
	if rx.compile("<div class='asset'>([\\s\\S]*?)</div>\\s*</div>") != OK:
		return out
	for m in rx.search_all(html):
		var chunk: String = m.get_string(1)
		var slug: String = _rx1(chunk, "href='https://kenney\\.nl/assets/([a-z0-9][a-z0-9-]*)'")
		if slug == "":
			continue
		var name: String = _rx1(chunk, "<h2><a [^>]*>([^<]+)</a></h2>")
		if name == "":
			name = slug.capitalize().replace("-", " ")
		var preview: String = _rx1(chunk, "background-image:url\\(\"([^\"]+)\"\\)")
		var category: String = _rx1(chunk, "href='https://kenney\\.nl/assets/category:([A-Za-z0-9]+)'")
		if category == "":
			category = "Other"
		# Tags: collect any series:* names as comma-separated tag string.
		var tags := PackedStringArray()
		var trx := RegEx.new()
		if trx.compile("href='https://kenney\\.nl/assets/series:([^']+)'") == OK:
			for tm in trx.search_all(chunk):
				var t: String = tm.get_string(1).uri_decode().to_lower()
				if t != "" and not tags.has(t):
					tags.append(t)
		out.append({
			"name": name.strip_edges(),
			"category": category,
			"tags": " ".join(tags),
			"url": "https://kenney.nl/assets/" + slug,
			"preview": preview,
		})
	return out


func _rx1(text: String, pattern: String) -> String:
	var rx := RegEx.new()
	if rx.compile(pattern) != OK:
		return ""
	var m := rx.search(text)
	if m == null:
		return ""
	return m.get_string(1)


func _finalize_catalog_scrape() -> void:
	_scrape_active = false
	if _dynamic_catalog.is_empty():
		# Fallback: stick with baked CATALOG. Still update count label.
		if _count_label != null and is_instance_valid(_count_label):
			_count_label.text = "%d packs (offline catalog)" % CATALOG.size()
		return
	# Sort alphabetically by name for predictable browsing.
	_dynamic_catalog.sort_custom(func(a, b): return a["name"].naturalnocasecmp_to(b["name"]) < 0)
	# Rebuild category list from observed values.
	var cats := {}
	for e in _dynamic_catalog:
		cats[e["category"]] = true
	_all_categories.clear()
	var keys: Array = cats.keys()
	keys.sort()
	for k in keys:
		_all_categories.append(k)
	# Rebuild category dropdown.
	if _category_option != null and is_instance_valid(_category_option):
		var prev_sel := _category_option.get_item_text(_category_option.selected) if _category_option.selected >= 0 else "All"
		_category_option.clear()
		_category_option.add_item("All", 0)
		var idx := 1
		for c in _all_categories:
			_category_option.add_item(c, idx)
			if c == prev_sel:
				_category_option.select(idx)
			idx += 1
	if _count_label != null and is_instance_valid(_count_label):
		_count_label.text = "%d packs (live from kenney.nl)" % _dynamic_catalog.size()
	# Refresh the visible list with the fresh catalog.
	_apply_filter()
