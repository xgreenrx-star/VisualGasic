@tool
extends VBoxContainer
## Context Rail preview for DataFile "path" and labeled external data.

signal action_requested(action: String, ref: Dictionary)

const Resolver := preload("res://addons/visual_gasic/vg_datafile_resolver.gd")
const Sniff := preload("res://addons/visual_gasic/vg_datafile_sniff.gd")
const GridIO := preload("res://addons/visual_gasic/vg_datafile_grid_io.gd")
const DatafileExternal := preload("res://addons/visual_gasic/vg_datafile_external.gd")

const PREVIEW_MAX := 128
const PREVIEW_TEXT_MAX := 65536
const CREAM_BG := Color(0.96, 0.95, 0.92)
const TEXT_DARK := Color(0.1, 0.1, 0.1)
const MUTED := Color(0.35, 0.35, 0.5)
const GRID_BG := Color(0.55, 0.57, 0.62)

var _info: Label
var _hint: Label
var _grid_frame: PanelContainer
var _grid: TextureRect
var _text_view: TextEdit
var _action_row: HBoxContainer
var _new_level_btn: Button
var _save_btn: Button
var _current_ref: Dictionary = {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_color_override("font_color", TEXT_DARK)
	_info.text = "Place the caret on DataFile \"path\", or click New level…"
	add_child(_info)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.visible = false
	add_child(_hint)
	_grid_frame = PanelContainer.new()
	var grid_sb := StyleBoxFlat.new()
	grid_sb.bg_color = GRID_BG
	grid_sb.set_border_width_all(1)
	grid_sb.border_color = Color(0.45, 0.47, 0.52)
	grid_sb.set_corner_radius_all(3)
	grid_sb.content_margin_left = 4
	grid_sb.content_margin_right = 4
	grid_sb.content_margin_top = 4
	grid_sb.content_margin_bottom = 4
	_grid_frame.add_theme_stylebox_override("panel", grid_sb)
	_grid_frame.visible = false
	_grid_frame.custom_minimum_size = Vector2(0, 128)
	add_child(_grid_frame)
	_grid = TextureRect.new()
	_grid.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_grid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_grid.custom_minimum_size = Vector2(120, 120)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_frame.add_child(_grid)
	_text_view = TextEdit.new()
	_text_view.editable = false
	_text_view.custom_minimum_size = Vector2(0, 100)
	_text_view.visible = false
	_text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_apply_text_edit_theme(_text_view)
	_text_view.text_changed.connect(_on_preview_text_changed)
	add_child(_text_view)
	_save_btn = Button.new()
	_save_btn.text = "Save CSV"
	_save_btn.visible = false
	_save_btn.tooltip_text = "Write edits back to the file on disk"
	_save_btn.pressed.connect(_on_save_csv_pressed)
	add_child(_save_btn)
	_new_level_btn = Button.new()
	_new_level_btn.text = "New level…"
	_new_level_btn.tooltip_text = "Create a labeled DataFile, empty grid file, and source block"
	_new_level_btn.pressed.connect(func() -> void: action_requested.emit("new_level", {}))
	add_child(_new_level_btn)
	_action_row = HBoxContainer.new()
	_action_row.visible = false
	_action_row.add_theme_constant_override("separation", 4)
	add_child(_action_row)


func clear_preview() -> void:
	_current_ref = {}
	_info.text = "Place the caret on DataFile \"path\", or click New level…"
	_hint.visible = false
	_save_btn.visible = false
	_grid_frame.visible = false
	_grid.texture = null
	_text_view.visible = false
	_text_view.editable = false
	_action_row.visible = false
	for c in _action_row.get_children():
		c.queue_free()


func show_notice(extra_line: String) -> void:
	if extra_line.is_empty():
		return
	var base := _info.text.strip_edges()
	if base.is_empty():
		_info.text = extra_line
	else:
		_info.text = base + "\n" + extra_line


func update_for_caret(source: String, caret_line: int) -> void:
	var ref := Resolver.resolve_at_line(source, caret_line)
	if ref.is_empty():
		clear_preview()
		return
	show_ref(ref)


func show_ref(ref: Dictionary) -> void:
	_current_ref = ref.duplicate(true)
	var sniff: Dictionary = ref.get("sniff", {})
	var kind: String = str(sniff.get("kind_name", "missing"))
	var path: String = str(ref.get("path", ""))
	var label: String = str(ref.get("label", ""))
	var lines: PackedStringArray = []
	if not label.is_empty():
		lines.append("%s:" % label)
	lines.append('DataFile "%s"' % path)
	lines.append("Kind: %s" % kind)
	if bool(sniff.get("exists", false)):
		lines.append("Size: %d bytes" % int(sniff.get("size", 0)))
		if int(sniff.get("width", 0)) > 0:
			lines.append("Grid: %d×%d  elem=%d" % [
				int(sniff.get("width", 0)),
				int(sniff.get("height", 0)),
				int(sniff.get("elem_size", 1)),
			])
	else:
		lines.append("File not found on disk.")
	_info.text = "\n".join(lines)
	_hint.visible = false
	_save_btn.visible = false
	_rebuild_actions(ref, sniff)
	_render_preview(ref, sniff)


func _rebuild_actions(ref: Dictionary, sniff: Dictionary) -> void:
	for c in _action_row.get_children():
		c.queue_free()
	_action_row.visible = false
	if not bool(sniff.get("exists", false)):
		var create_btn := Button.new()
		create_btn.text = "Create placeholder"
		create_btn.pressed.connect(func() -> void: action_requested.emit("create_placeholder", ref.duplicate(true)))
		_action_row.add_child(create_btn)
		_action_row.visible = true
		return
	var kind: String = str(sniff.get("kind_name", ""))
	if kind in ["csv", "vgd"]:
		var edit_btn := Button.new()
		edit_btn.text = "Edit Grid…"
		edit_btn.tooltip_text = "Open the VG Grid Editor (paint tiles, fill, save)"
		edit_btn.pressed.connect(func() -> void: action_requested.emit("edit_grid", ref.duplicate(true)))
		_action_row.add_child(edit_btn)
	var choose_btn := Button.new()
	choose_btn.text = "Choose file…"
	choose_btn.tooltip_text = "Point this DataFile label at a different CSV or .vgd"
	choose_btn.pressed.connect(func() -> void: action_requested.emit("choose_file", ref.duplicate(true)))
	_action_row.add_child(choose_btn)
	if kind in ["csv", "text", "tiled_json", "tiled_tmx", "vgd", "png", "image", "raw"]:
		var open_btn := Button.new()
		open_btn.text = "Open file"
		var ext_hint := DatafileExternal.get_configured_executable()
		if ext_hint.is_empty():
			open_btn.tooltip_text = (
				"Open in external editor — set Project Settings → Vg → Datafile → External Editor"
			)
		else:
			open_btn.tooltip_text = "Open in: " + ext_hint.get_file()
		open_btn.pressed.connect(func() -> void: action_requested.emit("open_external", ref.duplicate(true)))
		_action_row.add_child(open_btn)
	if kind in ["tiled_json", "tiled_tmx"]:
		var import_btn := Button.new()
		import_btn.text = "Import → .vgd"
		import_btn.pressed.connect(func() -> void: action_requested.emit("import_tiled", ref.duplicate(true)))
		_action_row.add_child(import_btn)
	if kind == "csv":
		var conv := Button.new()
		conv.text = "Convert → .vgd"
		conv.pressed.connect(func() -> void: action_requested.emit("convert_csv", ref.duplicate(true)))
		_action_row.add_child(conv)
	if kind in ["vgd", "raw"]:
		var hex_btn := Button.new()
		hex_btn.text = "Hex Editor"
		hex_btn.tooltip_text = "Open in VG Hex Editor (bottom panel)"
		hex_btn.pressed.connect(func() -> void: action_requested.emit("open_hex", ref.duplicate(true)))
		_action_row.add_child(hex_btn)
	_action_row.visible = true


func _render_preview(ref: Dictionary, sniff: Dictionary) -> void:
	_grid_frame.visible = false
	_grid.texture = null
	_text_view.visible = false
	if not bool(sniff.get("exists", false)):
		return
	var abs_path: String = str(ref.get("abs_path", ""))
	var kind: String = str(sniff.get("kind_name", ""))
	if kind == "vgd" and int(sniff.get("width", 0)) > 0:
		_show_grid_texture(_mini_grid_texture_vgd(abs_path, sniff))
	elif kind == "csv":
		var grid_tex := _mini_grid_texture_csv(abs_path)
		if grid_tex != null:
			_show_grid_texture(grid_tex)
		var txt := GridIO.read_text_file(abs_path)
		if txt.is_empty() and grid_tex == null:
			_text_view.text = "(Binary or non-text file — use Edit Grid…)"
			_text_view.editable = false
			_text_view.visible = true
			_save_btn.visible = false
		elif not txt.is_empty():
			var editable := txt.length() <= PREVIEW_TEXT_MAX
			_text_view.text = txt if editable else txt.substr(0, PREVIEW_TEXT_MAX) + "\n… (file too large — use Open file)"
			_text_view.editable = editable
			_text_view.visible = true
			_text_view.custom_minimum_size.y = 72 if grid_tex != null else 100
			_save_btn.visible = editable
		_hint.text = "Edit in Grid Editor, or CSV below + Save CSV."
		_hint.visible = true
	elif kind in ["png", "image"]:
		var img := Image.load_from_file(abs_path)
		if img:
			_show_grid_texture(ImageTexture.create_from_image(img))
	elif kind == "text":
		var txt := GridIO.read_text_file(abs_path)
		if not txt.is_empty():
			_text_view.text = txt.substr(0, mini(txt.length(), PREVIEW_TEXT_MAX))
			_text_view.visible = true
	elif kind == "raw":
		var head := FileAccess.get_file_as_bytes(abs_path).slice(0, 64)
		_text_view.text = "Hex preview:\n" + head.hex_encode()
		_text_view.visible = true


func _show_grid_texture(tex: Texture2D) -> void:
	if tex == null:
		return
	_grid.texture = tex
	_grid_frame.visible = true


func _mini_grid_texture_vgd(abs_path: String, sniff: Dictionary) -> Texture2D:
	var raw := FileAccess.get_file_as_bytes(abs_path)
	if raw.size() < 32:
		return null
	var payload_len: int = _u32(raw, 24)
	if raw.size() < 32 + payload_len:
		return null
	var w: int = int(sniff.get("width", 0))
	var h: int = int(sniff.get("height", 0))
	var elem: int = int(sniff.get("elem_size", 1))
	if w <= 0 or h <= 0:
		return null
	return _cells_to_texture(w, h, raw.slice(32, 32 + payload_len), elem)


func _mini_grid_texture_csv(abs_path: String) -> Texture2D:
	var loaded := GridIO.load_csv(abs_path)
	if not bool(loaded.get("ok", false)):
		return null
	var w: int = int(loaded.get("width", 0))
	var h: int = int(loaded.get("height", 0))
	var cells: PackedByteArray = loaded.get("cells", PackedByteArray())
	if w <= 0 or h <= 0:
		return null
	return _cells_to_texture(w, h, cells, 1)


func _cells_to_texture(w: int, h: int, payload: PackedByteArray, elem: int) -> Texture2D:
	var img_w: int = mini(w, PREVIEW_MAX)
	var img_h: int = mini(h, PREVIEW_MAX)
	var img := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.38, 0.40, 0.45))
	var sx: float = float(w) / float(img_w)
	var sy: float = float(h) / float(img_h)
	for py in img_h:
		for px in img_w:
			var sx_i: int = int(floor(px * sx))
			var sy_i: int = int(floor(py * sy))
			var idx: int = sy_i * w + sx_i
			var off: int = idx * elem
			if off + elem > payload.size():
				continue
			var v: int = payload[off]
			if elem >= 2:
				v = payload[off] | (payload[off + 1] << 8)
			v = v & 0xFFFF
			img.set_pixel(px, py, Sniff.tile_preview_color(v))
	return ImageTexture.create_from_image(img)


static func _u32(b: PackedByteArray, off: int) -> int:
	if off + 4 > b.size():
		return 0
	return b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24)


func _apply_text_edit_theme(te: TextEdit) -> void:
	te.add_theme_font_size_override("font_size", 10)
	te.add_theme_color_override("font_color", TEXT_DARK)
	te.add_theme_color_override("font_readonly_color", TEXT_DARK)
	te.add_theme_color_override("font_placeholder_color", MUTED)
	te.add_theme_color_override("caret_color", Color(0.0, 0.0, 0.55))
	te.add_theme_color_override("selection_color", Color(0.35, 0.55, 0.85, 0.35))
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM_BG
	sb.border_color = Color(0.75, 0.73, 0.68)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	te.add_theme_stylebox_override("normal", sb)
	te.add_theme_stylebox_override("focus", sb)
	te.add_theme_stylebox_override("read_only", sb)


func _on_preview_text_changed() -> void:
	if _text_view.editable:
		_save_btn.text = "Save CSV *"


func _on_save_csv_pressed() -> void:
	var abs_path: String = str(_current_ref.get("abs_path", ""))
	if abs_path.is_empty():
		return
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		show_notice("Could not save: " + abs_path)
		return
	f.store_string(_text_view.text)
	f.close()
	_save_btn.text = "Save CSV"
	var ref := _current_ref.duplicate(true)
	ref["sniff"] = Sniff.sniff_path(abs_path)
	show_ref(ref)
	show_notice("Saved. Re-run Play to reload map data.")
