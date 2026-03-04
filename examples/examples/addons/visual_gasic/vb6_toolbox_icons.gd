## VB6-style toolbox icons for the Visual Gasic Form Designer.
## Each icon is a 20×20 SVG rendered to an ImageTexture at runtime.
## Bold black outlines, high-contrast fills, VB6 system palette.
##
## Usage:
##   var VB6Icons = preload("res://addons/visual_gasic/vb6_toolbox_icons.gd")
##   var icons = VB6Icons.create_all(scale)
##   # icons is Dictionary { "Pointer": ImageTexture, "Label": ImageTexture, ... }

const _HDR = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">'
const _FTR = '</svg>'

# ── SVG bodies (everything between <svg …> and </svg>) ──────────────
# Each draws inside a 20×20 viewBox with bold strokes for clarity.

static func _svgs() -> Dictionary:
	return {
		# ── Pointer: mouse arrow cursor (white with black outline) ──
		"Pointer": '<polygon points="3,1 3,16 7,12 10,17 12,16 9,11 14,11" fill="#FFFFFF" stroke="#000000" stroke-width="1.2" stroke-linejoin="round"/>',

		# ── PictureBox: photo frame with landscape ──
		"Picture": '<rect x="1" y="2" width="18" height="16" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><polygon points="1,18 7,10 11,14 14,10 19,18" fill="#008000" stroke="none"/><circle cx="15" cy="6" r="2" fill="#FFFF00" stroke="#000000" stroke-width="0.5"/>',

		# ── Label: bold "A" in serif ──
		"Label": '<text x="10" y="17" text-anchor="middle" font-family="serif" font-weight="bold" font-size="18" fill="#000000">A</text>',

		# ── TextBox: white sunken edit field with "ab|" ──
		"TextBox": '<rect x="1" y="4" width="18" height="12" fill="#FFFFFF" stroke="#808080" stroke-width="1.5"/><rect x="1" y="4" width="18" height="12" fill="none" stroke="#000000" stroke-width="0.6"/><text x="4" y="14" font-family="monospace" font-size="9" fill="#000000">ab|</text>',

		# ── CommandButton: 3D raised gray button ──
		"Button": '<rect x="2" y="4" width="16" height="12" fill="#C0C0C0" stroke="#000000" stroke-width="0.6"/><line x1="2" y1="4" x2="18" y2="4" stroke="#FFFFFF" stroke-width="1.5"/><line x1="2" y1="4" x2="2" y2="16" stroke="#FFFFFF" stroke-width="1.5"/><line x1="18" y1="4" x2="18" y2="16" stroke="#808080" stroke-width="1.5"/><line x1="2" y1="16" x2="18" y2="16" stroke="#808080" stroke-width="1.5"/>',

		# ── CheckBox: white square with bold checkmark ──
		"CheckBox": '<rect x="3" y="4" width="12" height="12" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><polyline points="5,10 8,14 14,6" fill="none" stroke="#000000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',

		# ── ComboBox: edit + dropdown arrow button ──
		"ComboBox": '<rect x="1" y="5" width="18" height="11" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><rect x="13" y="5" width="6" height="11" fill="#C0C0C0" stroke="#000000" stroke-width="0.8"/><polygon points="14.5,8.5 17.5,8.5 16,12.5" fill="#000000"/>',

		# ── Frame: titled rectangle frame ──
		"Frame": '<rect x="1" y="5" width="18" height="14" rx="0" fill="none" stroke="#000000" stroke-width="1.2"/><rect x="4" y="2.5" width="12" height="5" fill="#C0C0C0" stroke="none"/><text x="5" y="7" font-family="sans-serif" font-weight="bold" font-size="6" fill="#000000">Frame</text>',

		# ── GroupBox: same as Frame but labeled Group ──
		"GroupBox": '<rect x="1" y="6" width="18" height="13" rx="1.5" fill="none" stroke="#000000" stroke-width="1.2"/><rect x="4" y="3.5" width="12" height="5" fill="#C0C0C0" stroke="none"/><text x="5" y="8" font-family="sans-serif" font-weight="bold" font-size="5.5" fill="#000000">Group</text>',

		# ── ListBox: white box with navy-selected row ──
		"ListBox": '<rect x="1" y="2" width="18" height="16" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><rect x="2" y="4" width="16" height="3" fill="#000080"/><text x="3" y="6.5" font-family="sans-serif" font-size="3.5" fill="#FFFFFF">Item 1</text><text x="3" y="10" font-family="sans-serif" font-size="3.5" fill="#000000">Item 2</text><text x="3" y="13.5" font-family="sans-serif" font-size="3.5" fill="#000000">Item 3</text>',

		# ── TreeView: tree with folder icons ──
		"TreeView": '<rect x="1" y="1" width="18" height="18" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><line x1="5" y1="5" x2="5" y2="16" stroke="#808080" stroke-width="0.8"/><line x1="5" y1="5" x2="9" y2="5" stroke="#808080" stroke-width="0.8"/><line x1="5" y1="10" x2="9" y2="10" stroke="#808080" stroke-width="0.8"/><line x1="5" y1="15" x2="9" y2="15" stroke="#808080" stroke-width="0.8"/><rect x="10" y="3.5" width="4" height="3" fill="#FFFF00" stroke="#000000" stroke-width="0.6"/><rect x="10" y="8.5" width="4" height="3" fill="#FFFF00" stroke="#000000" stroke-width="0.6"/><rect x="10" y="13.5" width="4" height="3" fill="#FFFF00" stroke="#000000" stroke-width="0.6"/>',

		# ── HScrollBar: horizontal scrollbar ──
		"HScroll": '<rect x="1" y="6" width="18" height="8" fill="#C0C0C0" stroke="#000000" stroke-width="1"/><polygon points="2.5,10 5,7.5 5,12.5" fill="#000000"/><polygon points="17.5,10 15,7.5 15,12.5" fill="#000000"/><rect x="7.5" y="7.5" width="5" height="5" fill="#C0C0C0" stroke="#808080" stroke-width="0.8"/>',

		# ── VScrollBar: vertical scrollbar ──
		"VScroll": '<rect x="6" y="1" width="8" height="18" fill="#C0C0C0" stroke="#000000" stroke-width="1"/><polygon points="10,2.5 7.5,5 12.5,5" fill="#000000"/><polygon points="10,17.5 7.5,15 12.5,15" fill="#000000"/><rect x="7.5" y="7.5" width="5" height="5" fill="#C0C0C0" stroke="#808080" stroke-width="0.8"/>',

		# ── ProgressBar: blue fill bar ──
		"ProgressBar": '<rect x="1" y="6" width="18" height="8" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><rect x="2" y="7" width="11" height="6" fill="#000080"/>',

		# ── HSlider: horizontal track with raised thumb ──
		"HSlider": '<line x1="2" y1="11" x2="18" y2="11" stroke="#808080" stroke-width="2"/><rect x="8" y="6" width="4" height="10" fill="#C0C0C0" stroke="#000000" stroke-width="0.8"/><line x1="8" y1="6" x2="12" y2="6" stroke="#FFFFFF" stroke-width="0.8"/><line x1="8" y1="6" x2="8" y2="16" stroke="#FFFFFF" stroke-width="0.8"/>',

		# ── VSlider: vertical track with raised thumb ──
		"VSlider": '<line x1="10" y1="1" x2="10" y2="19" stroke="#808080" stroke-width="2"/><rect x="5" y="8" width="10" height="4" fill="#C0C0C0" stroke="#000000" stroke-width="0.8"/><line x1="5" y1="8" x2="15" y2="8" stroke="#FFFFFF" stroke-width="0.8"/><line x1="5" y1="8" x2="5" y2="12" stroke="#FFFFFF" stroke-width="0.8"/>',

		# ── SpinBox: edit + up/down arrows ──
		"SpinBox": '<rect x="1" y="4" width="18" height="12" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><rect x="13" y="4" width="6" height="12" fill="#C0C0C0" stroke="#000000" stroke-width="0.6"/><line x1="13" y1="10" x2="19" y2="10" stroke="#000000" stroke-width="0.6"/><polygon points="16,5.5 14,8.5 18,8.5" fill="#000000"/><polygon points="16,14.5 14,11.5 18,11.5" fill="#000000"/><text x="3" y="13.5" font-family="monospace" font-size="8" fill="#000000">42</text>',

		# ── Shape: overlapping rectangle and circle ──
		"Shape": '<rect x="1" y="7" width="11" height="11" fill="none" stroke="#0000FF" stroke-width="1.5"/><circle cx="13" cy="7" r="5.5" fill="none" stroke="#FF0000" stroke-width="1.5"/>',

		# ── HLine / HSeparator: etched horizontal line ──
		"HLine": '<line x1="1" y1="9.5" x2="19" y2="9.5" stroke="#808080" stroke-width="1.5"/><line x1="1" y1="11" x2="19" y2="11" stroke="#FFFFFF" stroke-width="1"/>',

		# ── VLine / VSeparator: etched vertical line ──
		"VLine": '<line x1="9.5" y1="1" x2="9.5" y2="19" stroke="#808080" stroke-width="1.5"/><line x1="11" y1="1" x2="11" y2="19" stroke="#FFFFFF" stroke-width="1"/>',

		# ── RichText: page with formatted text ──
		"RichText": '<rect x="1" y="1" width="18" height="18" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><line x1="4" y1="5" x2="10" y2="5" stroke="#000000" stroke-width="2"/><line x1="4" y1="9" x2="16" y2="9" stroke="#000000" stroke-width="0.8"/><line x1="4" y1="12" x2="14" y2="12" stroke="#0000FF" stroke-width="0.8" text-decoration="underline"/><line x1="4" y1="15" x2="13" y2="15" stroke="#000000" stroke-width="0.8"/>',

		# ── TextArea: multi-line text field ──
		"TextArea": '<rect x="1" y="1" width="18" height="18" fill="#FFFFFF" stroke="#808080" stroke-width="1.5"/><rect x="1" y="1" width="18" height="18" fill="none" stroke="#000000" stroke-width="0.5"/><line x1="4" y1="5" x2="15" y2="5" stroke="#000000" stroke-width="0.7"/><line x1="4" y1="8.5" x2="14" y2="8.5" stroke="#000000" stroke-width="0.7"/><line x1="4" y1="12" x2="16" y2="12" stroke="#000000" stroke-width="0.7"/><line x1="4" y1="15.5" x2="10" y2="15.5" stroke="#000000" stroke-width="0.7"/>',

		# ── TabStrip: overlapping folder tabs ──
		"TabStrip": '<rect x="1" y="8" width="18" height="11" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><rect x="2" y="4" width="7" height="5" fill="#FFFFFF" stroke="#000000" stroke-width="0.8"/><rect x="9" y="5" width="6" height="4" fill="#C0C0C0" stroke="#808080" stroke-width="0.6"/><line x1="2" y1="8" x2="9" y2="8" stroke="#FFFFFF" stroke-width="1.2"/>',

		# ── Timer: clock face with hands ──
		"Timer": '<circle cx="10" cy="10" r="8" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><line x1="10" y1="10" x2="10" y2="4" stroke="#000000" stroke-width="1.2"/><line x1="10" y1="10" x2="14" y2="8" stroke="#000000" stroke-width="1"/><circle cx="10" cy="10" r="1" fill="#000000"/>',

		# ── FileDialog: yellow folder ──
		"Files": '<path d="M1,6 L1,18 L19,18 L19,6 L9,6 L7.5,3 L1,3 Z" fill="#FFFF00" stroke="#000000" stroke-width="1" stroke-linejoin="round"/>',

		# ── RadioButton / OptionButton: circle with filled dot ──
		"RadioButton": '<circle cx="10" cy="10" r="7" fill="#FFFFFF" stroke="#000000" stroke-width="1.2"/><circle cx="10" cy="10" r="3.5" fill="#000000"/>',

		# ── MenuBar: three-line menu icon ──
		"MenuBar": '<rect x="1" y="2" width="18" height="16" fill="#C0C0C0" stroke="#000000" stroke-width="1"/><text x="3" y="8" font-family="sans-serif" font-size="5" fill="#000000">File</text><text x="10" y="8" font-family="sans-serif" font-size="5" fill="#000000">Edit</text><line x1="1" y1="10" x2="19" y2="10" stroke="#808080" stroke-width="0.8"/>',

		# ── TextureButton / PictureButton: image button ──
		"PictureButton": '<rect x="2" y="3" width="16" height="14" fill="#C0C0C0" stroke="#000000" stroke-width="0.8"/><line x1="2" y1="3" x2="18" y2="3" stroke="#FFFFFF" stroke-width="1.2"/><line x1="2" y1="3" x2="2" y2="17" stroke="#FFFFFF" stroke-width="1.2"/><polygon points="5,14 9,8 12,12 14,9 17,14" fill="#008000" stroke="none"/><circle cx="14" cy="7" r="1.5" fill="#FFFF00" stroke="none"/>',

		# ── Line: diagonal line tool ──
		"Line": '<line x1="2" y1="17" x2="18" y2="3" stroke="#000000" stroke-width="2"/><circle cx="2" cy="17" r="1.5" fill="#0000FF"/><circle cx="18" cy="3" r="1.5" fill="#0000FF"/>',

		# ── DriveListBox: drive combo ──
		"DriveList": '<rect x="1" y="5" width="18" height="11" fill="#FFFFFF" stroke="#000000" stroke-width="1"/><rect x="13" y="5" width="6" height="11" fill="#C0C0C0" stroke="#000000" stroke-width="0.8"/><polygon points="14.5,8.5 17.5,8.5 16,12.5" fill="#000000"/><text x="2.5" y="12.5" font-family="sans-serif" font-size="5.5" fill="#000000">C:</text>',
	}


## Renders all SVG strings into ImageTexture objects.
## [param render_size] — pixel size of the generated bitmap (default 32×32).
## Returns { tool_name: String → ImageTexture }.
static func create_all(render_size: int = 32) -> Dictionary:
	var out := {}
	var scale := float(render_size) / 20.0  # SVGs use 20×20 viewBox
	var bodies := _svgs()
	for tool_name in bodies:
		var svg_str: String = _HDR + bodies[tool_name] + _FTR
		var img := Image.new()
		var err = img.load_svg_from_string(svg_str, scale)
		if err == OK and img.get_width() > 0:
			var tex := ImageTexture.create_from_image(img)
			out[tool_name] = tex
	return out
