@tool
extends RefCounted
## Rewrites labeled sprite Data rows in a CodeEdit from a flat pixel buffer.

const Resolver := preload("res://addons/visual_gasic/vg_sprite_data_resolver.gd")
const Palettes := preload("res://addons/visual_gasic/vg_sprite_data_palettes.gd")

const META_GUARD := "vg_sprite_sync_guard"
const DEFAULT_LABEL := "NewSprite"


static func apply_pixels(code_edit: CodeEdit, section: Dictionary, pixels: PackedInt32Array) -> bool:
	if code_edit == null or section.is_empty():
		return false
	var w: int = section.get("w", 0)
	var h: int = section.get("h", 0)
	var start_line: int = section.get("data_start_line", -1)
	if w < 1 or h < 1 or start_line < 0:
		return false
	if pixels.size() != w * h:
		return false

	code_edit.set_meta(META_GUARD, true)
	# Keep header + pixel rows indented under the label so the block stays foldable.
	var header_line: int = int(section.get("header_line", -1))
	if header_line >= 0 and header_line < code_edit.get_line_count():
		var header_raw := code_edit.get_line(header_line).strip_edges()
		var header_prefix := _indent_prefix(code_edit.get_line(header_line))
		if header_prefix.is_empty():
			header_prefix = "\t"
		code_edit.set_line(header_line, header_prefix + header_raw)
	for row in h:
		var parts: PackedStringArray = PackedStringArray()
		for col in w:
			parts.append(str(pixels[row * w + col]))
		var prefix := _indent_prefix(code_edit.get_line(start_line + row))
		if prefix.is_empty():
			prefix = "\t"
		var line_text := prefix + "Data " + ", ".join(parts)
		code_edit.set_line(start_line + row, line_text)
	code_edit.remove_meta(META_GUARD)
	# set_line does not emit text_changed — notify the embedded editor so
	# dirty tracking, context rail, and flush_for_run see the edit.
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


## Rewrite header + pixel rows (supports size / palette / transparent changes).
static func apply_section(
	code_edit: CodeEdit,
	section: Dictionary,
	pixels: PackedInt32Array,
	w: int = -1,
	h: int = -1,
	transparent: int = -1,
	palette_id: int = -1
) -> bool:
	if code_edit == null or section.is_empty():
		return false
	if w < 0:
		w = int(section.get("w", 0))
	if h < 0:
		h = int(section.get("h", 0))
	if transparent < 0:
		transparent = int(section.get("transparent", 0))
	if palette_id < 0:
		palette_id = int(section.get("palette_id", 0))
	w = clampi(w, 1, Resolver.MAX_INLINE_W)
	h = clampi(h, 1, Resolver.MAX_INLINE_H)
	if pixels.size() != w * h:
		return false
	var header_line: int = int(section.get("header_line", -1))
	var old_end: int = int(section.get("data_end_line", -1))
	if header_line < 0 or old_end < header_line:
		return false

	# Indent Data rows under the label so CodeEdit can fold the whole block.
	var prefix := _indent_prefix(code_edit.get_line(header_line))
	if prefix.is_empty():
		prefix = "\t"
	var new_lines: PackedStringArray = PackedStringArray()
	new_lines.append(prefix + "Data %d, %d, %d, %d" % [w, h, transparent, palette_id])
	for row in h:
		var parts: PackedStringArray = PackedStringArray()
		for col in w:
			parts.append(str(pixels[row * w + col]))
		new_lines.append(prefix + "Data " + ", ".join(parts))

	var old_count := old_end - header_line + 1
	var new_count := new_lines.size()
	code_edit.set_meta(META_GUARD, true)
	while old_count > new_count:
		code_edit.remove_line_at(old_end)
		old_end -= 1
		old_count -= 1
	while old_count < new_count:
		old_end += 1
		code_edit.insert_line_at(old_end, new_lines[old_count])
		old_count += 1
	for i in new_count:
		code_edit.set_line(header_line + i, new_lines[i])
	code_edit.remove_meta(META_GUARD)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()
	return true


static func insert_new_block(
	code_edit: CodeEdit,
	caret_line: int,
	label: String,
	w: int,
	h: int,
	transparent: int = 0,
	palette_id: int = 0
) -> Dictionary:
	var out := {"ok": false, "error": "", "section": {}, "label_line": -1}
	if code_edit == null:
		out["error"] = "No code editor"
		return out
	var lbl := normalize_label(label)
	var err := validate_new_label(code_edit.text, lbl)
	if not err.is_empty():
		out["error"] = err
		return out
	w = clampi(w, 1, Resolver.MAX_INLINE_W)
	h = clampi(h, 1, Resolver.MAX_INLINE_H)
	transparent = clampi(transparent, 0, 15)
	palette_id = clampi(palette_id, 0, Palettes.PALETTE_NAMES.size() - 1)

	var pixels := PackedInt32Array()
	pixels.resize(w * h)
	for i in pixels.size():
		pixels[i] = transparent

	var lines: PackedStringArray = PackedStringArray()
	lines.append(lbl + ":")
	# Tab-indent Data under the label → native CodeEdit fold + thumbnail header.
	lines.append("\tData %d, %d, %d, %d" % [w, h, transparent, palette_id])
	for row in h:
		var parts: PackedStringArray = PackedStringArray()
		for _col in w:
			parts.append(str(transparent))
		lines.append("\tData " + ", ".join(parts))

	var line := clampi(caret_line, 0, code_edit.get_line_count())
	code_edit.set_meta(META_GUARD, true)
	for i in range(lines.size() - 1, -1, -1):
		code_edit.insert_line_at(line, lines[i])
	# Blank line after the block for readability when not at EOF.
	var after := line + lines.size()
	if after < code_edit.get_line_count():
		var next_txt := code_edit.get_line(after).strip_edges()
		if not next_txt.is_empty():
			code_edit.insert_line_at(after, "")
	code_edit.remove_meta(META_GUARD)
	code_edit.set_caret_line(line)
	code_edit.set_caret_column(0)
	if code_edit.has_signal("text_changed"):
		code_edit.text_changed.emit()

	var sec := Resolver.resolve_at_line(code_edit.text, line)
	if sec.is_empty():
		out["error"] = "Inserted block but could not resolve it"
		return out
	out["ok"] = true
	out["section"] = sec
	out["label_line"] = line
	return out


static func normalize_label(label: String) -> String:
	var lbl := label.strip_edges()
	if lbl.ends_with(":"):
		lbl = lbl.substr(0, lbl.length() - 1).strip_edges()
	return lbl


static func is_valid_label(label: String) -> bool:
	var lbl := normalize_label(label)
	if lbl.is_empty():
		return false
	var re := RegEx.new()
	re.compile("^[A-Za-z_]\\w*$")
	return re.search(lbl) != null and Resolver.is_sprite_label(lbl)


static func validate_new_label(source: String, label: String) -> String:
	var lbl := normalize_label(label)
	if not is_valid_label(lbl):
		return "Label must be an identifier ending with Sprite (e.g. PlayerSprite)"
	for b in Resolver.enumerate_blocks(source):
		if str(b.get("label", "")).to_lower() == lbl.to_lower():
			return "A sprite block named %s already exists" % lbl
	# Also reject duplicate labels that aren't valid sprite blocks yet
	var lines := source.split("\n")
	var label_re := RegEx.new()
	label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	for line in lines:
		var m := label_re.search(line)
		if m != null and m.get_string(1).to_lower() == lbl.to_lower():
			return "Label %s is already used in this file" % lbl
	return ""


static func suggest_label(source: String) -> String:
	var used: Dictionary = {}
	var label_re := RegEx.new()
	label_re.compile("^\\s*([A-Za-z_]\\w*)\\s*:\\s*(?:'.*)?$")
	for line in source.split("\n"):
		var m := label_re.search(line)
		if m != null:
			used[m.get_string(1).to_lower()] = true
	if not used.has(DEFAULT_LABEL.to_lower()):
		return DEFAULT_LABEL
	var n := 2
	while used.has(("%s%d" % [DEFAULT_LABEL, n]).to_lower()):
		n += 1
	return "%s%d" % [DEFAULT_LABEL, n]


static func image_from_pixels(
	pixels: PackedInt32Array,
	w: int,
	h: int,
	palette_id: int,
	transparent: int
) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if pixels.size() < w * h:
		return img
	for y in h:
		for x in w:
			var idx := pixels[y * w + x]
			if idx == transparent:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var c: Color = Palettes.color_for_index(palette_id, idx)
				c.a = 1.0
				img.set_pixel(x, y, c)
	return img


static func pixels_from_image(
	img: Image,
	palette_id: int,
	transparent: int
) -> PackedInt32Array:
	var w := img.get_width()
	var h := img.get_height()
	var cols: Array = Palettes.colors_for_id(palette_id)
	var pixels := PackedInt32Array()
	pixels.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				pixels[y * w + x] = transparent
			else:
				pixels[y * w + x] = _nearest_palette_index(c, cols, transparent)
	return pixels


static func _nearest_palette_index(color: Color, cols: Array, transparent: int) -> int:
	var best := 0
	var best_d := INF
	for i in cols.size():
		if i == transparent:
			continue
		var pc: Color = cols[i]
		var dr := color.r - pc.r
		var dg := color.g - pc.g
		var db := color.b - pc.b
		var d := dr * dr + dg * dg + db * db
		if d < best_d:
			best_d = d
			best = i
	if cols.is_empty():
		return transparent
	# Prefer an exact-ish match; if every color is distant and transparent
	# was skipped, still return best opaque index.
	return best


static func is_sync_guarded(code_edit: CodeEdit) -> bool:
	return code_edit != null and code_edit.has_meta(META_GUARD)


## Leading whitespace on a line, or empty if the line is not indented.
static func _indent_prefix(line: String) -> String:
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch != "\t" and ch != " ":
			break
		i += 1
	if i <= 0:
		return ""
	return line.substr(0, i)
