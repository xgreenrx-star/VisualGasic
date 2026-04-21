@tool
## OpenGameArt.org Browser — search and download CC-licensed 2D art, textures, music, and SFX.
## OGA has no REST API, so we scrape the HTML search results.
## All assets on OGA are free (CC0, CC-BY, CC-BY-SA, GPL).
extends RefCounted

# ─── Configuration ────────────────────────────────────────────────────────────
const OGA_BASE := "https://opengameart.org"
const DOWNLOAD_DIR_ART := "res://assets/art/"
const DOWNLOAD_DIR_AUDIO := "res://assets/sounds/"
const DOWNLOAD_DIR_MISC := "res://assets/downloads/"

# Art type IDs from OGA advanced search form
const ART_TYPES := {
	"2D Art": "9",
	"3D Art": "10",
	"Texture": "14",
	"Concept Art": "7338",
	"Music": "12",
	"Sound Effect": "13",
}

# ─── State ────────────────────────────────────────────────────────────────────
var _dialog: AcceptDialog = null
var _host: Node = null
var _http: HTTPRequest = null
var _download_http: HTTPRequest = null
var _results_box: VBoxContainer = null
var _search_edit: LineEdit = null
var _type_option: OptionButton = null
var _license_option: OptionButton = null
var _page_label: Label = null
var _status_label: Label = null
var _page := 0
var _items: Array = []  # parsed search results [{title, url, preview_url, type}]
var _selected_index := -1
var _selected_row: PanelContainer = null
var _kid_mode := false
var _preview_images: Dictionary = {}  # index → TextureRect (for lazy image loading)
var _img_http_queue: Array = []
var _img_http: HTTPRequest = null
var _download_stage := ""  # "page" | "file"
var _download_item: Dictionary = {}
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
	_dialog.title = "🎨 OpenGameArt — Free Game Assets" if not _kid_mode else "🎨 Art Library"
	_dialog.min_size = Vector2(840, 720)
	_dialog.ok_button_text = "Close"
	_dialog.exclusive = true
	_dialog.popup_window = true
	var cleanup := func():
		_dialog.queue_free()
		_dialog = null
		_results_box = null
		_selected_row = null
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

	var lbl := Label.new()
	lbl.text = "Search:"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	search_row.add_child(lbl)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "e.g. platformer, dungeon, rpg tiles, sword..." if not _kid_mode else "Type what you need..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 13)
	search_row.add_child(_search_edit)

	# Type filter
	var lbl_type := Label.new()
	lbl_type.text = "Type:"
	lbl_type.add_theme_font_size_override("font_size", 13)
	lbl_type.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	search_row.add_child(lbl_type)

	_type_option = OptionButton.new()
	_type_option.add_theme_font_size_override("font_size", 13)
	_type_option.add_item("All Types", 0)
	var ti := 1
	for type_name in ART_TYPES:
		_type_option.add_item(type_name, ti)
		ti += 1
	search_row.add_child(_type_option)

	if not _kid_mode:
		# License filter
		var lbl_lic := Label.new()
		lbl_lic.text = "License:"
		lbl_lic.add_theme_font_size_override("font_size", 13)
		lbl_lic.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		search_row.add_child(lbl_lic)

		_license_option = OptionButton.new()
		_license_option.add_theme_font_size_override("font_size", 13)
		_license_option.add_item("Any License", 0)
		_license_option.add_item("CC0 (Public Domain)", 1)
		_license_option.add_item("CC-BY", 2)
		_license_option.add_item("CC-BY-SA", 3)
		search_row.add_child(_license_option)

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
			["🧱 Tiles", "tileset", 1],
			["🧍 Characters", "character sprite", 1],
			["⚔️ Items", "item weapon", 1],
			["🏰 Backgrounds", "background", 1],
			["👾 Enemies", "enemy monster", 1],
			["💎 Icons", "icon ui", 1],
			["🎵 Music", "background music", 5],
			["💥 SFX", "sound effect", 6],
		]
		for cat in categories:
			var btn := Button.new()
			btn.text = cat[0]
			btn.add_theme_font_size_override("font_size", 12)
			var query_text: String = cat[1]
			var type_idx: int = cat[2]
			btn.pressed.connect(func():
				_search_edit.text = query_text
				_type_option.selected = type_idx
				_do_search(0)
			)
			cat_row.add_child(btn)

	# ── Results ──
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

	_page_label = Label.new()
	_page_label.text = ""
	_page_label.add_theme_font_size_override("font_size", 13)
	_page_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_page_label)

	# ── Bottom ──
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

	var btn_open := Button.new()
	btn_open.text = "🌐 Open on OGA"
	btn_open.add_theme_font_size_override("font_size", 13)
	btn_open.pressed.connect(func():
		if _selected_index >= 0 and _selected_index < _items.size():
			OS.shell_open(OGA_BASE + _items[_selected_index].get("url", ""))
	)
	bottom.add_child(btn_open)

	var btn_download := Button.new()
	btn_download.text = "⬇ Auto Download"
	btn_download.add_theme_font_size_override("font_size", 13)
	btn_download.tooltip_text = "Try direct download/install from the asset page; falls back to browser if needed"
	btn_download.pressed.connect(_download_selected_asset)
	bottom.add_child(btn_download)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(_status_label)

	var hint := Label.new()
	hint.text = "Click to select · Double-click to open on OpenGameArt.org · Auto Download tries direct file install, then falls back to browser"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(hint)

	_dialog.popup_centered()

	if _kid_mode:
		_search_edit.text = "platformer"
		_type_option.selected = 1  # 2D Art
		_do_search(0)


# ─── Search ──────────────────────────────────────────────────────────────────

func _do_search(page: int) -> void:
	_page = page
	var query := _search_edit.text.strip_edges() if _search_edit else ""
	if query == "":
		query = "game"

	# Build OGA search URL
	var url := OGA_BASE + "/art-search-advanced?keys=" + query.uri_encode()

	# Art type
	if _type_option and _type_option.selected > 0:
		var type_names := ART_TYPES.keys()
		var sel_name: String = type_names[_type_option.selected - 1]
		url += "&field_art_type_tid=" + ART_TYPES[sel_name]

	# License
	if _license_option and _license_option.selected > 0:
		var lic_map := ["", "2", "4", "3"]  # OGA license IDs: CC0=2, CC-BY=4, CC-BY-SA=3
		if _license_option.selected < lic_map.size():
			url += "&field_art_licenses_tid=" + lic_map[_license_option.selected]

	url += "&sort_by=count&sort_order=DESC&items_per_page=24"
	if page > 0:
		url += "&page=" + str(page)

	_clear_results()
	_add_message("⏳ Searching OpenGameArt.org...")

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

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_add_message("❌ Request failed (HTTP %d)" % response_code)
		return

	var html := body.get_string_from_utf8()
	_items = _parse_oga_results(html)

	if _items.is_empty():
		_add_message("No results found. Try different search terms.")
		return

	# Parse total from "Displaying 1 - 24 of XXXX"
	var total_str := ""
	var disp_idx := html.find("Displaying")
	if disp_idx >= 0:
		var of_idx := html.find(" of ", disp_idx)
		if of_idx >= 0:
			var end := html.find("<", of_idx + 4)
			if end < 0:
				end = of_idx + 20
			total_str = html.substr(of_idx + 4, end - of_idx - 4).strip_edges()

	for i in range(_items.size()):
		var item: Dictionary = _items[i]
		var title: String = item.get("title", "Untitled")
		var preview_url: String = item.get("preview_url", "")

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

		# Thumbnail placeholder
		if preview_url != "":
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row_hbox.add_child(tex_rect)
			_preview_images[i] = tex_rect
			_img_http_queue.append({"index": i, "url": preview_url})

		# Title
		var title_lbl := Label.new()
		title_lbl.text = "🎨 " + title
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(title_lbl)

	# Start loading thumbnails
	_load_next_thumbnail()

	if _page_label and is_instance_valid(_page_label):
		var info := "— Page %d" % (_page + 1)
		if total_str != "":
			info += "  |  %s results" % total_str
		info += " —"
		_page_label.text = info


func _load_next_thumbnail() -> void:
	if _img_http_queue.is_empty():
		return
	var entry: Dictionary = _img_http_queue.pop_front()
	var idx: int = entry["index"]
	var url: String = entry["url"]
	if not url.begins_with("http"):
		url = OGA_BASE + url

	if _img_http != null and is_instance_valid(_img_http):
		_img_http.queue_free()
	_img_http = HTTPRequest.new()
	var captured_idx := idx
	_img_http.request_completed.connect(func(res, code, _h, img_body):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200 and img_body.size() > 100:
			var img := Image.new()
			var load_err := img.load_png_from_buffer(img_body)
			if load_err != OK:
				load_err = img.load_jpg_from_buffer(img_body)
			if load_err != OK:
				load_err = img.load_webp_from_buffer(img_body)
			if load_err == OK and _preview_images.has(captured_idx):
				var tex := ImageTexture.create_from_image(img)
				var tr: TextureRect = _preview_images[captured_idx]
				if is_instance_valid(tr):
					tr.texture = tex
		# Load next
		_load_next_thumbnail()
	)
	_host.add_child(_img_http)
	_img_http.request(url)


# ─── HTML Parser ─────────────────────────────────────────────────────────────

func _parse_oga_results(html: String) -> Array:
	## Parse OGA search results page HTML to extract titles and thumbnail URLs.
	## OGA structure: <span class="art-grid-cell"> containing <a href="/content/..."> and <img src="...">
	var results: Array = []
	var search_start := 0

	# Look for art grid items — they follow pattern: href="/content/SLUG" ... Preview ... img src="..."
	while true:
		var a_idx := html.find('/content/', search_start)
		if a_idx < 0:
			break

		# Find the href start
		var href_start := html.rfind('href="', a_idx)
		if href_start < 0 or (a_idx - href_start) > 50:
			search_start = a_idx + 10
			continue

		# Extract URL
		var href_end := html.find('"', a_idx)
		if href_end < 0:
			search_start = a_idx + 10
			continue
		var item_url := html.substr(a_idx, href_end - a_idx)

		# Skip non-content URLs (forums, blogs, etc.)
		if "/content/" not in item_url or item_url.count("/") > 2:
			search_start = href_end + 1
			continue

		# Extract title from URL slug
		var slug := item_url.replace("/content/", "")
		var title := slug.replace("-", " ").capitalize()

		# Look for preview image nearby (within 500 chars)
		var preview_url := ""
		var img_search_start := href_end
		var img_search_end := mini(img_search_start + 800, html.length())
		var chunk := html.substr(img_search_start, img_search_end - img_search_start)
		var img_idx := chunk.find("img")
		if img_idx >= 0:
			var src_idx := chunk.find('src="', img_idx)
			if src_idx >= 0:
				var src_start := src_idx + 5
				var src_end := chunk.find('"', src_start)
				if src_end >= 0:
					preview_url = chunk.substr(src_start, src_end - src_start)

		# Deduplicate
		var dupe := false
		for existing in results:
			if existing["url"] == item_url:
				dupe = true
				break
		if not dupe and item_url.length() > 10:
			results.append({
				"title": title,
				"url": item_url,
				"preview_url": preview_url,
			})

		search_start = href_end + 1
		if results.size() >= 30:
			break

	return results


# ─── Row Interaction ─────────────────────────────────────────────────────────

func _row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
		# Open on OGA
		if index >= 0 and index < _items.size():
			OS.shell_open(OGA_BASE + _items[index].get("url", ""))
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


# ─── Direct Download / Install ──────────────────────────────────────────────

func _download_selected_asset() -> void:
	if _selected_index < 0 or _selected_index >= _items.size():
		_set_status("Select an item first.")
		return

	_download_item = _items[_selected_index]
	var rel_url: String = _download_item.get("url", "")
	if rel_url == "":
		_set_status("No asset URL found.")
		return

	var page_url := rel_url if rel_url.begins_with("http") else (OGA_BASE + rel_url)
	_set_status("⏳ Fetching asset page...")

	if _download_http != null and is_instance_valid(_download_http):
		_download_http.cancel_request()
		_download_http.queue_free()
	_download_http = HTTPRequest.new()
	_download_http.request_completed.connect(_on_download_request_completed)
	_host.add_child(_download_http)
	_download_stage = "page"
	var err := _download_http.request(page_url)
	if err != OK:
		_set_status("❌ Could not fetch asset page (error %d)." % err)


func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _download_stage == "page":
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			_set_status("❌ Could not load asset page (HTTP %d). Opening browser..." % response_code)
			_open_selected_in_browser()
			return

		var html := body.get_string_from_utf8()
		var links := _extract_download_links(html)
		if links.is_empty():
			_set_status("⚠ No direct file links found. Opening browser...")
			_open_selected_in_browser()
			return

		var picked := _choose_best_download_link(links)
		if picked == "":
			_set_status("⚠ No suitable file link found. Opening browser...")
			_open_selected_in_browser()
			return

		_download_url = picked
		_download_stage = "file"
		_set_status("⬇ Downloading: " + _download_url)
		var err := _download_http.request(_download_url)
		if err != OK:
			_set_status("❌ Download request failed (error %d). Opening browser..." % err)
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
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f == null:
			_set_status("❌ Could not write file to project: " + save_path)
			_open_selected_in_browser()
			return
		f.store_buffer(body)
		f.close()

		var extracted := false
		if ext == "zip":
			var extract_dir := target_dir.path_join(filename.get_basename())
			extracted = _extract_zip(save_path, extract_dir)

		_rescan_filesystem()
		if extracted:
			_set_status("✅ Downloaded and extracted to " + save_path.get_base_dir())
		else:
			_set_status("✅ Downloaded to " + save_path)


func _extract_download_links(html: String) -> Array:
	var links: Array = []
	var seen := {}
	var idx := 0
	while true:
		var href_idx := html.find('href="', idx)
		if href_idx < 0:
			break
		var start := href_idx + 6
		var end := html.find('"', start)
		if end < 0:
			break
		var href := html.substr(start, end - start).strip_edges()
		idx = end + 1

		if href == "" or href.begins_with("#") or href.begins_with("mailto:"):
			continue

		var abs := href if href.begins_with("http") else (OGA_BASE + href)
		var l := abs.to_lower()

		# OGA files are often under /sites/default/files/ and may be png/ogg/zip/etc.
		var is_file_link := (
			"/sites/default/files/" in l
			or l.ends_with(".zip")
			or l.ends_with(".png")
			or l.ends_with(".jpg")
			or l.ends_with(".jpeg")
			or l.ends_with(".webp")
			or l.ends_with(".ogg")
			or l.ends_with(".wav")
			or l.ends_with(".mp3")
			or l.ends_with(".flac")
		)
		if is_file_link and not seen.has(abs):
			seen[abs] = true
			links.append(abs)

	return links


func _choose_best_download_link(links: Array) -> String:
	if links.is_empty():
		return ""

	var prefer_audio := false
	if _type_option and _type_option.selected > 0:
		var names := ART_TYPES.keys()
		if (_type_option.selected - 1) < names.size():
			var sel_name: String = names[_type_option.selected - 1]
			prefer_audio = (sel_name == "Music" or sel_name == "Sound Effect")

	var score_best := -99999
	var best := ""
	for url in links:
		var fname := _filename_from_url(url)
		var ext := fname.get_extension().to_lower()
		var s := 0
		if ext == "zip":
			s += 200
		elif ext in ["7z", "rar", "tar", "gz"]:
			s += 150
		elif ext in ["png", "jpg", "jpeg", "webp"]:
			s += 100
		elif ext in ["ogg", "wav", "mp3", "flac"]:
			s += 100

		if prefer_audio:
			if ext in ["ogg", "wav", "mp3", "flac"]:
				s += 80
			if ext in ["png", "jpg", "jpeg", "webp"]:
				s -= 40
		else:
			if ext in ["png", "jpg", "jpeg", "webp"]:
				s += 40

		if s > score_best:
			score_best = s
			best = url

	return best


func _filename_from_url(url: String) -> String:
	var base := url.split("?")[0].split("#")[0].get_file()
	if base == "":
		base = "oga_asset.bin"
	base = base.uri_decode()
	base = base.replace(" ", "_")
	base = base.replace("/", "_")
	base = base.replace("\\", "_")
	base = base.replace(":", "_")
	if base.length() > 120:
		base = base.substr(0, 120)
	return base


func _target_dir_for_extension(ext: String) -> String:
	if ext in ["ogg", "wav", "mp3", "flac"]:
		return DOWNLOAD_DIR_AUDIO
	if ext in ["png", "jpg", "jpeg", "webp", "zip", "svg"]:
		return DOWNLOAD_DIR_ART
	return DOWNLOAD_DIR_MISC


func _ensure_res_dir(res_dir: String) -> void:
	var abs := ProjectSettings.globalize_path(res_dir)
	DirAccess.make_dir_recursive_absolute(abs)


func _extract_zip(zip_path: String, dest_dir: String) -> bool:
	_ensure_res_dir(dest_dir)
	var zr := ZIPReader.new()
	var open_err := zr.open(zip_path)
	if open_err != OK:
		return false

	var files := zr.get_files()
	var extracted_any := false
	for rel in files:
		if rel.ends_with("/"):
			continue
		if ".." in rel:
			continue
		var out_path := dest_dir.path_join(rel)
		var out_dir := out_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		var bytes: PackedByteArray = zr.read_file(rel)
		var out := FileAccess.open(out_path, FileAccess.WRITE)
		if out != null:
			out.store_buffer(bytes)
			out.close()
			extracted_any = true
	zr.close()
	return extracted_any


func _rescan_filesystem() -> void:
	if _host and _host.has_method("get_editor_interface"):
		var ei = _host.get_editor_interface()
		if ei and ei.get_resource_filesystem():
			ei.get_resource_filesystem().scan()


func _open_selected_in_browser() -> void:
	if _selected_index >= 0 and _selected_index < _items.size():
		OS.shell_open(OGA_BASE + _items[_selected_index].get("url", ""))


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
