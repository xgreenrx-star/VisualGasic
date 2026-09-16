@tool
## OpenGameArt.org Browser — search and download CC-licensed 2D art, textures, music, and SFX.
## OGA has no REST API, so we scrape the HTML search results.
## All assets on OGA are free (CC0, CC-BY, CC-BY-SA, GPL).
extends RefCounted

## Emitted after a successful download. `local_path` is the saved file,
## `was_extracted` is true when a ZIP was unpacked. Listeners (e.g. the AGCK
## actor editor) connect to this to auto-import the asset.
signal asset_downloaded(local_path: String, was_extracted: bool)

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
const MAX_PARALLEL_THUMBS := 4
const OGA_DONATE_URL := "https://opengameart.org/donate"
var _img_http_active: int = 0
var _download_stage := ""  # "page" | "file"
var _download_item: Dictionary = {}
var _download_url := ""

# Big preview modal + slideshow
var _preview_dialog: AcceptDialog = null
var _preview_tex_rect: TextureRect = null
var _preview_status_lbl: Label = null
var _preview_item: Dictionary = {}
var _preview_http: HTTPRequest = null
var _slideshow_urls: Array = []
var _slideshow_textures: Array = []
var _slideshow_index: int = 0
var _slideshow_timer: Timer = null
var _slideshow_counter_lbl: Label = null

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
	_style_dark_option(_type_option)
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
		_style_dark_option(_license_option)
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
	_style_dark_scroll(scroll)
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
	while _img_http_active < MAX_PARALLEL_THUMBS and not _img_http_queue.is_empty():
		var entry: Dictionary = _img_http_queue.pop_front()
		_dispatch_thumbnail(entry)


func _dispatch_thumbnail(entry: Dictionary) -> void:
	var idx: int = entry["index"]
	var url: String = entry["url"]
	if not url.begins_with("http"):
		url = OGA_BASE + url
	if not _preview_images.has(idx) or not is_instance_valid(_preview_images[idx]):
		_load_next_thumbnail()
		return
	if _host == null or not is_instance_valid(_host):
		return
	var req := HTTPRequest.new()
	_host.add_child(req)
	_img_http_active += 1
	var captured_idx := idx
	var captured_req := req
	req.request_completed.connect(func(res, code, _h, img_body):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200 and img_body.size() > 100:
			var img: Image = _decode_image_buffer(img_body)
			if img != null and _preview_images.has(captured_idx):
				var tr: TextureRect = _preview_images[captured_idx]
				if is_instance_valid(tr):
					tr.texture = ImageTexture.create_from_image(img)
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


# Sniff image format from magic bytes; only call the matching loader.
func _decode_image_buffer(body: PackedByteArray):
	if body == null or body.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_INVALID_DATA
	if body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47:
		err = img.load_png_from_buffer(body)
	elif body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		err = img.load_jpg_from_buffer(body)
	elif body[0] == 0x52 and body[1] == 0x49 and body[2] == 0x46 and body[3] == 0x46 \
			and body[8] == 0x57 and body[9] == 0x45 and body[10] == 0x42 and body[11] == 0x50:
		err = img.load_webp_from_buffer(body)
	else:
		return null
	if err != OK:
		return null
	return img


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
	# Double-click → large preview modal (with slideshow + download).
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if index >= 0 and index < _items.size():
			_show_big_preview(index)
		return
	# Right-click → open page on opengameart.org.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if index >= 0 and index < _items.size():
			OS.shell_open(OGA_BASE + _items[index].get("url", ""))
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
		asset_downloaded.emit(save_path, extracted)


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
	_img_http_active = 0


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
	if _preview_status_lbl and is_instance_valid(_preview_status_lbl):
		_preview_status_lbl.text = msg


# ─── Big preview modal ──────────────────────────────────────────────────────
# Double-click a row → larger preview + slideshow + Download + Donate buttons.

func _show_big_preview(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_preview_item = _items[index]
	if _preview_dialog and is_instance_valid(_preview_dialog):
		_preview_dialog.queue_free()
	_preview_dialog = AcceptDialog.new()
	_preview_dialog.title = "🖼  " + str(_preview_item.get("title", "Preview"))
	_preview_dialog.min_size = Vector2(560, 580)
	_preview_dialog.ok_button_text = "Close"
	# Don't request exclusivity — _dialog already has it on the same parent.
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
	# Parent under the main dialog so we don't conflict with its exclusive child.
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.add_child(_preview_dialog)
	else:
		_host.add_child(_preview_dialog)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_preview_dialog.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = str(_preview_item.get("title", ""))
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	vb.add_child(name_lbl)

	var meta := Label.new()
	meta.text = "OpenGameArt.org · CC-licensed"
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.62, 0.62, 0.70))
	vb.add_child(meta)

	_preview_tex_rect = TextureRect.new()
	_preview_tex_rect.custom_minimum_size = Vector2(520, 380)
	_preview_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vb.add_child(_preview_tex_rect)

	# Reuse already-loaded thumbnail if available.
	if _preview_images.has(index):
		var tr_cached = _preview_images[index]
		if tr_cached != null and is_instance_valid(tr_cached) and tr_cached.texture != null:
			_preview_tex_rect.texture = tr_cached.texture

	# Slideshow controls (◀  N / M  ▶)
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
	_slideshow_counter_lbl.text = "loading…"
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
	dl_btn.pressed.connect(func():
		_selected_index = index
		if _preview_status_lbl and is_instance_valid(_preview_status_lbl):
			_preview_status_lbl.text = "⏳  Resolving direct download URL…"
		_download_selected_asset()
	)
	btns.add_child(dl_btn)

	var open_btn := Button.new()
	open_btn.text = "🌐  Open page on OpenGameArt"
	open_btn.add_theme_font_size_override("font_size", 12)
	open_btn.pressed.connect(func():
		var u: String = str(_preview_item.get("url", ""))
		if u != "":
			OS.shell_open(u if u.begins_with("http") else (OGA_BASE + u))
	)
	btns.add_child(open_btn)

	var donate_btn := Button.new()
	donate_btn.text = "❤  Donate to OpenGameArt"
	donate_btn.tooltip_text = "Open OpenGameArt's donation page in your browser. OGA is community-run; donations keep the site online."
	donate_btn.add_theme_font_size_override("font_size", 12)
	donate_btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	donate_btn.pressed.connect(func(): OS.shell_open(OGA_DONATE_URL))
	btns.add_child(donate_btn)

	_preview_status_lbl = Label.new()
	_preview_status_lbl.text = ""
	_preview_status_lbl.add_theme_font_size_override("font_size", 11)
	_preview_status_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_preview_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_preview_status_lbl)

	_preview_dialog.popup_centered()
	# Fetch the OGA page to harvest all preview images for the slideshow.
	var item_url: String = str(_preview_item.get("url", ""))
	if item_url != "":
		var page_url := item_url if item_url.begins_with("http") else (OGA_BASE + item_url)
		_fetch_oga_page_for_slideshow(page_url)


func _fetch_oga_page_for_slideshow(page_url: String) -> void:
	if _preview_http != null and is_instance_valid(_preview_http):
		_preview_http.queue_free()
	_preview_http = HTTPRequest.new()
	_host.add_child(_preview_http)
	_preview_http.request_completed.connect(func(res, code, _h, body):
		if res == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 256:
			var html: String = body.get_string_from_utf8()
			var imgs := _extract_oga_preview_urls(html)
			if not imgs.is_empty():
				_start_slideshow_with_urls(imgs)
	)
	_preview_http.request(page_url)


func _extract_oga_preview_urls(html: String) -> Array:
	# OGA serves the actual artwork files at /sites/default/files/<name>.<ext>
	# (no /styles/ thumbnail path, no /js/ scripts, no /pictures/ user avatars).
	# We collect <img src="…"> hits matching that pattern, deduped, in order.
	var urls: Array = []
	var seen := {}
	var rx := RegEx.new()
	if rx.compile("(?:src|content)=[\"']([^\"']+sites/default/files/[^\"']+\\.(?:png|jpg|jpeg|webp|gif))[\"']") != OK:
		return urls
	for m in rx.search_all(html):
		var u: String = m.get_string(1)
		# Skip thumbnail variants and user avatars.
		if "/styles/" in u or "/pictures/" in u:
			continue
		if not u.begins_with("http"):
			u = OGA_BASE + u
		if not seen.has(u):
			seen[u] = true
			urls.append(u)
	# Also grab og:image as a fallback first slide (highest-priority preview).
	var og_rx := RegEx.new()
	if og_rx.compile("<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']") == OK:
		var og := og_rx.search(html)
		if og != null:
			var og_url: String = og.get_string(1)
			if og_url != "" and not seen.has(og_url):
				urls.insert(0, og_url)
				seen[og_url] = true
	return urls


func _start_slideshow_with_urls(urls: Array) -> void:
	_slideshow_urls = urls.duplicate()
	_slideshow_textures.clear()
	for _i in range(_slideshow_urls.size()):
		_slideshow_textures.append(null)
	_slideshow_index = 0
	_update_slideshow_counter()
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
				if captured_slot == _slideshow_index and is_instance_valid(_preview_tex_rect):
					_preview_tex_rect.texture = _slideshow_textures[captured_slot]
				elif is_instance_valid(_preview_tex_rect) and _preview_tex_rect.texture == null:
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
	var pos := 0
	for i in range(_slideshow_index + 1):
		if i < _slideshow_textures.size() and _slideshow_textures[i] != null:
			pos += 1
	if pos == 0:
		pos = 1
	_slideshow_counter_lbl.text = "%d / %d" % [pos, loaded]


# ─── Dark-theme styling helpers (Linux X11-safe) ─────────────────────────────
# These mirror the proven recipe from vg_2d_editor.gd `_style_popup_dark`
# and the AGCK editor's `_apply_dark_popup` / `_apply_scroll_styling`. They
# fix two long-standing complaints:
#   1) OptionButton popups render dark-on-dark, only hovered row legible.
#   2) ScrollContainer scrollbars have invisible grabbers on dark panels.
# Recipe is fragile — see /memories/repo/gdscript_landmines.md
# "OptionButton dropdown" section. Key things that ARE NOT done here:
# - No `popup.modulate` / `popup.self_modulate` (PopupMenu is a Window,
#   setting those raises a runtime error and aborts the rest of the func).


func _style_dark_option(opt: OptionButton) -> void:
	# Style the OptionButton's CLOSED face plus apply the dark popup recipe
	# to its dropdown. Both halves are needed: the closed button uses Button
	# styleboxes (normal/hover/pressed/focus/disabled), and the popup is a
	# separate PopupMenu node with its own theme resolution.
	if not is_instance_valid(opt):
		return
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(0.18, 0.18, 0.22)
	nb.set_corner_radius_all(3)
	nb.content_margin_left = 8; nb.content_margin_right = 8
	nb.content_margin_top = 4;  nb.content_margin_bottom = 4
	nb.border_color = Color(0.32, 0.32, 0.40)
	nb.set_border_width_all(1)
	var hb := nb.duplicate()
	hb.bg_color = Color(0.24, 0.24, 0.30)
	var pb := nb.duplicate()
	pb.bg_color = Color(0.28, 0.28, 0.36)
	opt.add_theme_stylebox_override("normal", nb)
	opt.add_theme_stylebox_override("hover", hb)
	opt.add_theme_stylebox_override("pressed", pb)
	opt.add_theme_stylebox_override("focus", hb)
	opt.add_theme_stylebox_override("disabled", nb)
	opt.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	opt.add_theme_color_override("font_hover_color", Color.WHITE)
	opt.add_theme_color_override("font_pressed_color", Color.WHITE)
	opt.add_theme_color_override("font_focus_color", Color(0.88, 0.88, 0.92))
	opt.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	var popup := opt.get_popup()
	_style_dark_popup(popup)
	# Re-apply every time the popup opens — the editor theme re-asserts
	# itself between setup and first paint, so styling done at construction
	# alone is not enough.
	if not popup.has_meta("_oga_popup_styled"):
		popup.set_meta("_oga_popup_styled", true)
		popup.about_to_popup.connect(func():
			_style_dark_popup(popup)
			_style_dark_popup.call_deferred(popup))


func _style_dark_popup(popup: PopupMenu) -> void:
	# Mirrors vg_2d_editor's `_style_popup_dark` recipe. Applies overrides
	# via BOTH a full Theme resource AND local add_theme_*_override calls;
	# either alone is insufficient against the editor theme.
	if not is_instance_valid(popup):
		return
	# IMPORTANT: do NOT touch popup.modulate / popup.self_modulate (Window,
	# not Control — raises runtime error and aborts the function).
	popup.transparent = false  # ARGB on X11 breaks font rendering — keep opaque
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.19, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.32, 0.32, 0.40)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(4)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.28, 0.38, 0.58)
	hover_style.set_corner_radius_all(3)
	hover_style.set_content_margin_all(2)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.30, 0.30, 0.38)
	sep_style.content_margin_top = 1; sep_style.content_margin_bottom = 1
	var t := Theme.new()
	for tn in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
		t.set_stylebox("panel", tn, panel_style)
	t.set_stylebox("hover", "PopupMenu", hover_style)
	t.set_stylebox("separator", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_left", "PopupMenu", sep_style)
	t.set_stylebox("labeled_separator_right", "PopupMenu", sep_style)
	t.set_color("font_color", "PopupMenu", Color(0.92, 0.92, 0.94))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.50, 0.50, 0.50))
	t.set_color("font_separator_color", "PopupMenu", Color(0.55, 0.55, 0.55))
	t.set_color("font_accelerator_color", "PopupMenu", Color(0.55, 0.65, 0.85))
	# The SELECTED row is painted with font_focus / font_pressed /
	# font_selected — all default to alpha 0 in the editor theme. Without
	# these the currently-chosen item appears blank.
	t.set_color("font_focus_color", "PopupMenu", Color(0.92, 0.92, 0.94))
	t.set_color("font_pressed_color", "PopupMenu", Color(0.92, 0.92, 0.94))
	t.set_color("font_selected_color", "PopupMenu", Color(0.92, 0.92, 0.94))
	# Kill any transparent outline that would eat glyph alpha.
	t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
	t.set_constant("outline_size", "PopupMenu", 0)
	popup.theme = t
	popup.add_theme_stylebox_override("panel", panel_style)
	popup.add_theme_stylebox_override("hover", hover_style)
	popup.add_theme_stylebox_override("separator", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_left", sep_style)
	popup.add_theme_stylebox_override("labeled_separator_right", sep_style)
	popup.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(0.50, 0.50, 0.50))
	popup.add_theme_color_override("font_separator_color", Color(0.55, 0.55, 0.55))
	popup.add_theme_color_override("font_accelerator_color", Color(0.55, 0.65, 0.85))
	popup.add_theme_color_override("font_focus_color", Color(0.92, 0.92, 0.94))
	popup.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.94))
	popup.add_theme_color_override("font_selected_color", Color(0.92, 0.92, 0.94))
	popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	popup.add_theme_constant_override("outline_size", 0)
	popup.notification(Window.NOTIFICATION_THEME_CHANGED)


func _style_dark_scroll(sc: ScrollContainer) -> void:
	# Make the V/HScrollBars on a ScrollContainer visible against dark
	# panels. The editor theme's default grabber stylebox is near-
	# transparent — bar track shows, thumb does not. We override `grabber`,
	# `grabber_highlight` and `grabber_pressed` with opaque StyleBoxFlats.
	if not is_instance_valid(sc):
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.12, 0.15)
	track.set_corner_radius_all(2)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.50, 0.50, 0.60)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 2; grab.content_margin_right = 2
	grab.content_margin_top = 2;  grab.content_margin_bottom = 2
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = Color(0.65, 0.65, 0.78)
	var grab_pr := grab.duplicate()
	grab_pr.bg_color = Color(0.80, 0.80, 0.92)
	for bar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		if bar == null:
			continue
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("scroll_focus", track)
		bar.add_theme_stylebox_override("grabber", grab)
		bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
		bar.add_theme_stylebox_override("grabber_pressed", grab_pr)
		# Force a minimum thickness — some editor themes set the bar's
		# custom_minimum_size to zero, which makes the bar invisible even
		# with a styled grabber.
		if bar is VScrollBar:
			bar.custom_minimum_size.x = 12
		elif bar is HScrollBar:
			bar.custom_minimum_size.y = 12
