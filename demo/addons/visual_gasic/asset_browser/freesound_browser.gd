@tool
## Freesound.org Sound Browser — search, preview, and download CC-licensed sound effects & music.
## Uses the Freesound APIv2 (requires a free API key from https://freesound.org/apiv2/apply/).
## Works in both VG (advanced) and AGCK (kid-friendly) modes.
extends RefCounted

# ─── Configuration ────────────────────────────────────────────────────────────
const API_BASE := "https://freesound.org/apiv2"
const CONFIG_PATH := "user://vg_freesound_config.json"
const DOWNLOAD_DIR := "res://assets/sounds/"

# Free API key — users can override via the config dialog
const DEFAULT_API_KEY := ""

# ─── State ────────────────────────────────────────────────────────────────────
var _dialog: AcceptDialog = null
var _host: Node = null  # parent node for add_child
var _http: HTTPRequest = null
var _preview_http: HTTPRequest = null
var _download_http: HTTPRequest = null
var _results_box: VBoxContainer = null
var _search_edit: LineEdit = null
var _filter_option: OptionButton = null
var _sort_option: OptionButton = null
var _page_label: Label = null
var _status_label: Label = null
var _page := 0
var _sounds: Array = []
var _total := 0
var _selected_index := -1
var _selected_row: PanelContainer = null
var _api_key := ""
var _kid_mode := false  # AGCK simplified UI
var _preview_player: AudioStreamPlayer = null
var _currently_previewing := -1

# ─── Public API ───────────────────────────────────────────────────────────────

func open(host: Node, kid_mode: bool = false) -> void:
	_host = host
	_kid_mode = kid_mode
	_load_config()
	if _api_key == "":
		_show_api_key_dialog()
		return
	_show_browser()


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		_api_key = str(json.data.get("api_key", ""))
	f.close()


func _save_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"api_key": _api_key}))
	f.close()


# ─── API Key Dialog ──────────────────────────────────────────────────────────

func _show_api_key_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "🔑 Freesound API Key Required"
	dlg.min_size = Vector2(520, 220)
	dlg.ok_button_text = "Save & Continue"
	_host.add_child(dlg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dlg.add_child(vbox)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.custom_minimum_size = Vector2(480, 0)
	info.text = "[b]Freesound.org[/b] provides 700,000+ free sounds (CC0/CC-BY).\n\nTo use this browser, you need a [b]free API key[/b]:\n1. Visit [url=https://freesound.org/apiv2/apply/]freesound.org/apiv2/apply[/url]\n2. Create a free account and apply for a key\n3. Paste the key below"
	info.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	vbox.add_child(info)

	var key_edit := LineEdit.new()
	key_edit.placeholder_text = "Paste your Freesound API key here..."
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.add_theme_font_size_override("font_size", 14)
	vbox.add_child(key_edit)

	var open_btn := Button.new()
	open_btn.text = "🌐 Open Freesound.org to get a key"
	open_btn.pressed.connect(func(): OS.shell_open("https://freesound.org/apiv2/apply/"))
	vbox.add_child(open_btn)

	dlg.confirmed.connect(func():
		var k := key_edit.text.strip_edges()
		if k.length() >= 10:
			_api_key = k
			_save_config()
			dlg.queue_free()
			_show_browser()
		else:
			key_edit.placeholder_text = "Key too short — paste the full token"
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


# ─── Browser Dialog ──────────────────────────────────────────────────────────

func _show_browser() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
		_dialog = null

	_dialog = AcceptDialog.new()
	_dialog.title = "🔊 Freesound — Browse Free Sounds" if not _kid_mode else "🔊 Sound Library"
	_dialog.min_size = Vector2(820, 720)
	_dialog.ok_button_text = "Close"
	_dialog.exclusive = true
	_dialog.popup_window = true
	var cleanup := func():
		_stop_preview()
		_dialog.queue_free()
		_dialog = null
		_results_box = null
		_selected_row = null
		_page_label = null
	_dialog.confirmed.connect(cleanup)
	_dialog.canceled.connect(cleanup)
	_host.add_child(_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_dialog.add_child(vbox)

	# ── Search row ──
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	vbox.add_child(search_row)

	var lbl_search := Label.new()
	lbl_search.text = "Search:"
	lbl_search.add_theme_font_size_override("font_size", 13)
	lbl_search.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	search_row.add_child(lbl_search)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "e.g. explosion, footstep, sword, rain..." if not _kid_mode else "Type a sound name..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 13)
	search_row.add_child(_search_edit)

	if not _kid_mode:
		# Filter by type
		var lbl_filter := Label.new()
		lbl_filter.text = "Filter:"
		lbl_filter.add_theme_font_size_override("font_size", 13)
		lbl_filter.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		search_row.add_child(lbl_filter)

		_filter_option = OptionButton.new()
		_filter_option.add_theme_font_size_override("font_size", 13)
		_filter_option.add_item("All", 0)
		_filter_option.add_item("WAV", 1)
		_filter_option.add_item("OGG", 2)
		_filter_option.add_item("MP3", 3)
		search_row.add_child(_filter_option)

	# Sort
	var lbl_sort := Label.new()
	lbl_sort.text = "Sort:"
	lbl_sort.add_theme_font_size_override("font_size", 13)
	lbl_sort.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	search_row.add_child(lbl_sort)

	_sort_option = OptionButton.new()
	_sort_option.add_theme_font_size_override("font_size", 13)
	_sort_option.add_item("Relevant", 0)
	_sort_option.add_item("Popular", 1)
	_sort_option.add_item("Rating", 2)
	_sort_option.add_item("Newest", 3)
	if _kid_mode:
		_sort_option.add_item("Shortest", 4)
	search_row.add_child(_sort_option)

	var btn_search := Button.new()
	btn_search.text = "🔍 Search"
	btn_search.add_theme_font_size_override("font_size", 13)
	btn_search.pressed.connect(_do_search.bind(0))
	search_row.add_child(btn_search)

	_search_edit.text_submitted.connect(func(_t): _do_search(0))

	# ── Quick category buttons for kid mode ──
	if _kid_mode:
		var cat_row := HBoxContainer.new()
		cat_row.add_theme_constant_override("separation", 4)
		vbox.add_child(cat_row)
		var categories := [
			["💥 Explosions", "explosion"],
			["👣 Footsteps", "footstep"],
			["⚔️ Weapons", "sword weapon"],
			["🎵 Music", "background music loop"],
			["🐱 Animals", "animal"],
			["🚗 Vehicles", "car engine"],
			["🔔 UI", "interface click button"],
			["🌧️ Nature", "rain wind nature"],
			["👾 Retro", "8bit retro game"],
		]
		for cat in categories:
			var btn := Button.new()
			btn.text = cat[0]
			btn.add_theme_font_size_override("font_size", 12)
			var query_text: String = cat[1]
			btn.pressed.connect(func():
				_search_edit.text = query_text
				_do_search(0)
			)
			cat_row.add_child(btn)

	# ── Scrollable results ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 440)
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
	_results_box.add_theme_constant_override("separation", 4)
	scroll_panel.add_child(_results_box)

	# ── Status / page label ──
	_page_label = Label.new()
	_page_label.text = ""
	_page_label.add_theme_font_size_override("font_size", 13)
	_page_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_page_label)

	# ── Bottom row ──
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	var btn_prev := Button.new()
	btn_prev.text = "◀ Prev"
	btn_prev.add_theme_font_size_override("font_size", 13)
	btn_prev.pressed.connect(func(): if _page > 0: _do_search(_page - 1))
	bottom.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "Next ▶"
	btn_next.add_theme_font_size_override("font_size", 13)
	btn_next.pressed.connect(func(): _do_search(_page + 1))
	bottom.add_child(btn_next)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	var btn_preview := Button.new()
	btn_preview.text = "▶ Preview"
	btn_preview.add_theme_font_size_override("font_size", 13)
	btn_preview.pressed.connect(_preview_selected)
	bottom.add_child(btn_preview)

	var btn_stop := Button.new()
	btn_stop.text = "⏹ Stop"
	btn_stop.add_theme_font_size_override("font_size", 13)
	btn_stop.pressed.connect(_stop_preview)
	bottom.add_child(btn_stop)

	var btn_download := Button.new()
	btn_download.text = "⬇️ Download to Project"
	btn_download.add_theme_font_size_override("font_size", 13)
	btn_download.pressed.connect(_download_selected)
	bottom.add_child(btn_download)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(_status_label)

	# Hint
	var hint := Label.new()
	hint.text = "Click to select · Double-click to preview · Right-click to open on freesound.org"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)

	_dialog.popup_centered()

	# Auto-search if kid mode
	if _kid_mode:
		_search_edit.text = "game sound effect"
		_do_search(0)


# ─── Search ──────────────────────────────────────────────────────────────────

func _do_search(page: int) -> void:
	_page = page
	var query := _search_edit.text.strip_edges() if _search_edit else ""
	if query == "":
		query = "game"

	var sort_map := ["score", "downloads_desc", "rating_desc", "created_desc", "duration_asc"]
	var sort_idx := _sort_option.selected if _sort_option else 0
	var sort_str: String = sort_map[sort_idx] if sort_idx < sort_map.size() else "score"

	# Build filter
	var filter_parts: Array = []
	if _filter_option and _filter_option.selected > 0:
		var type_map := ["", "wav", "ogg", "mp3"]
		filter_parts.append("type:" + type_map[_filter_option.selected])
	# For kid mode, keep sounds short
	if _kid_mode:
		filter_parts.append("duration:[0 TO 30]")

	var filter_str := "&filter=" + "%20".join(filter_parts) if filter_parts.size() > 0 else ""
	var fields := "id,name,tags,username,license,duration,avg_rating,num_downloads,previews,type"
	var url := "%s/search/?query=%s&sort=%s&fields=%s&page=%d&page_size=20%s&token=%s" % [
		API_BASE, query.uri_encode(), sort_str, fields, page + 1, filter_str, _api_key
	]

	_clear_results()
	_add_message("⏳ Searching Freesound...")

	if _http != null and is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.request_completed.connect(_on_search_response)
	_host.add_child(_http)
	var err := _http.request(url)
	if err != OK:
		_clear_results()
		_add_message("❌ HTTP request failed (error %d)" % err)


func _on_search_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _results_box == null or not is_instance_valid(_results_box):
		return
	_clear_results()

	if result != HTTPRequest.RESULT_SUCCESS:
		_add_message("❌ Connection failed (result %d)" % result)
		return
	if response_code == 401:
		_add_message("❌ Invalid API key. Close and reopen to enter a new key.")
		return
	if response_code != 200:
		_add_message("❌ Request failed (HTTP %d)" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_add_message("❌ Failed to parse response")
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	_total = int(data.get("count", 0))
	_sounds = data.get("results", [])

	if _sounds.is_empty():
		_add_message("No sounds found. Try different search terms.")
		return

	for i in range(_sounds.size()):
		var snd: Dictionary = _sounds[i]
		var sname: String = snd.get("name", "Untitled")
		var user: String = snd.get("username", "?")
		var dur: float = snd.get("duration", 0.0)
		var rating: float = snd.get("avg_rating", 0.0)
		var downloads: int = int(snd.get("num_downloads", 0))
		var lic: String = snd.get("license", "?")
		var stype: String = snd.get("type", "?")
		var tags: Array = snd.get("tags", [])

		# Short license display
		var lic_short := "CC0" if "Creative Commons 0" in lic else ("CC-BY" if "Attribution" in lic else lic)
		if "NonCommercial" in lic:
			lic_short = "CC-BY-NC"

		# Build row
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

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 2)
		row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row_vbox)

		# Title line
		var title_lbl := Label.new()
		if _kid_mode:
			title_lbl.text = "🔊 %s  (%s, %.1fs)" % [sname, stype.to_upper(), dur]
		else:
			title_lbl.text = "🔊 %s  [%s]  %.1fs  ★%.1f  ⬇%d  📝%s" % [sname, stype.to_upper(), dur, rating, downloads, lic_short]
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(title_lbl)

		# Tags / author line
		var detail_lbl := Label.new()
		var tag_str := ", ".join(tags.slice(0, 6)) if tags.size() > 0 else ""
		detail_lbl.text = "by %s  —  %s" % [user, tag_str]
		detail_lbl.add_theme_font_size_override("font_size", 10)
		detail_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		detail_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(detail_lbl)

	# Page info
	var page_count := ceili(float(_total) / 20.0)
	if _page_label and is_instance_valid(_page_label):
		_page_label.text = "— Page %d / %d  |  %d sounds found —" % [_page + 1, page_count, _total]


# ─── Row Interaction ─────────────────────────────────────────────────────────

func _row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Right-click → open on freesound.org
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if index >= 0 and index < _sounds.size():
			var sid := int(_sounds[index].get("id", 0))
			if sid > 0:
				OS.shell_open("https://freesound.org/people/%s/sounds/%d/" % [str(_sounds[index].get("username", "")), sid])
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Deselect previous
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
		if event.double_click:
			_preview_selected()


# ─── Preview ─────────────────────────────────────────────────────────────────

func _preview_selected() -> void:
	if _selected_index < 0 or _selected_index >= _sounds.size():
		return
	var snd: Dictionary = _sounds[_selected_index]
	var previews: Dictionary = snd.get("previews", {})
	# Prefer OGG for Godot, fallback to MP3
	var preview_url: String = previews.get("preview-hq-ogg", previews.get("preview-hq-mp3", previews.get("preview-lq-ogg", previews.get("preview-lq-mp3", ""))))
	if preview_url == "":
		_set_status("❌ No preview available for this sound")
		return
	# Add token
	if "?" in preview_url:
		preview_url += "&token=" + _api_key
	else:
		preview_url += "?token=" + _api_key

	_set_status("⏳ Loading preview...")
	_stop_preview()

	if _preview_http != null and is_instance_valid(_preview_http):
		_preview_http.cancel_request()
		_preview_http.queue_free()
	_preview_http = HTTPRequest.new()
	_preview_http.request_completed.connect(_on_preview_response)
	_host.add_child(_preview_http)
	_preview_http.request(preview_url)
	_currently_previewing = _selected_index


func _on_preview_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_status("❌ Preview failed (HTTP %d)" % response_code)
		return
	if body.size() < 100:
		_set_status("❌ Preview data too small")
		return

	# Determine format from content-type header or URL
	var is_ogg := false
	var is_mp3 := false
	for h in headers:
		var hl := h.to_lower()
		if "content-type" in hl:
			if "ogg" in hl:
				is_ogg = true
			elif "mpeg" in hl or "mp3" in hl:
				is_mp3 = true

	var stream: AudioStream = null
	if is_ogg:
		var ogg := AudioStreamOggVorbis.new()
		# Godot 4.x needs to load from PacketSequence — save temp file
		var tmp_path := "user://vg_freesound_preview.ogg"
		var f := FileAccess.open(tmp_path, FileAccess.WRITE)
		if f:
			f.store_buffer(body)
			f.close()
			stream = AudioStreamOggVorbis.load_from_file(tmp_path)
	elif is_mp3:
		var mp3 := AudioStreamMP3.new()
		mp3.data = body
		stream = mp3
	else:
		# Try MP3 as default
		var mp3 := AudioStreamMP3.new()
		mp3.data = body
		stream = mp3

	if stream == null:
		_set_status("❌ Could not decode preview audio")
		return

	_stop_preview()
	_preview_player = AudioStreamPlayer.new()
	_preview_player.stream = stream
	_preview_player.bus = "Master"
	_host.add_child(_preview_player)
	_preview_player.play()
	var sname := str(_sounds[_currently_previewing].get("name", "")) if _currently_previewing >= 0 and _currently_previewing < _sounds.size() else ""
	_set_status("▶ Playing: %s" % sname)


func _stop_preview() -> void:
	if _preview_player != null and is_instance_valid(_preview_player):
		_preview_player.stop()
		_preview_player.queue_free()
		_preview_player = null
	_currently_previewing = -1
	_set_status("")


# ─── Download ────────────────────────────────────────────────────────────────

func _download_selected() -> void:
	if _selected_index < 0 or _selected_index >= _sounds.size():
		_set_status("❌ No sound selected")
		return
	var snd: Dictionary = _sounds[_selected_index]
	var previews: Dictionary = snd.get("previews", {})
	# Download the HQ preview (no OAuth2 needed) in a usable format
	# Prefer OGG for Godot
	var dl_url: String = previews.get("preview-hq-ogg", previews.get("preview-hq-mp3", ""))
	if dl_url == "":
		_set_status("❌ No downloadable preview for this sound")
		return
	var ext := ".ogg" if "ogg" in dl_url else ".mp3"
	var sname: String = snd.get("name", "sound").replace(" ", "_").replace("/", "_").to_lower()
	# Clean filename
	var clean_name := ""
	for c in sname:
		if c.is_valid_identifier() or c == "_" or c == "-":
			clean_name += c
	if clean_name == "":
		clean_name = "freesound_%d" % int(snd.get("id", 0))
	var filename := clean_name + ext

	if "?" in dl_url:
		dl_url += "&token=" + _api_key
	else:
		dl_url += "?token=" + _api_key

	_set_status("⏳ Downloading %s..." % filename)

	if _download_http != null and is_instance_valid(_download_http):
		_download_http.cancel_request()
		_download_http.queue_free()

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)

	_download_http = HTTPRequest.new()
	_download_http.download_file = DOWNLOAD_DIR + filename
	var dl_filename := filename  # capture for lambda
	_download_http.request_completed.connect(func(res, code, _h, _b):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200:
			_set_status("✅ Saved to %s%s" % [DOWNLOAD_DIR, dl_filename])
			# Tell editor to rescan
			if Engine.is_editor_hint():
				var ei := EditorInterface
				if ei:
					ei.get_resource_filesystem().scan()
		else:
			_set_status("❌ Download failed (HTTP %d)" % code)
	)
	_host.add_child(_download_http)
	_download_http.request(dl_url)


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


func _set_status(msg: String) -> void:
	if _status_label and is_instance_valid(_status_label):
		_status_label.text = msg
