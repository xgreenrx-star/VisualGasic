@tool
## VG Sprite Editor — Piskel-inspired pixel art & animation editor embedded
## in the VG IDE.  Perfect for 8-bit / 16-bit retro game graphics.
##
## Features: pixel drawing canvas with zoom/pan, drawing tools (pen, eraser,
## line, rect, ellipse, fill, color picker, selection/move), animation frames
## with onion skinning & live preview, layers with visibility/opacity,
## retro color palettes (NES, GameBoy, C64, CGA, SNES), undo/redo,
## spritesheet/PNG/GIF export, and import from existing images.
##
## Architecture: HSplitContainer with a left tool/palette/layers panel and a
## right pixel canvas + frame strip area.  Follows the same pattern as the
## 2D/3D scene editors.
extends HSplitContainer

# ─────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────────────────────────────────────
signal back_to_form_requested
signal sprite_saved(path: String)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const MIN_ZOOM := 1.0
const MAX_ZOOM := 64.0
const DEFAULT_ZOOM := 12.0
const MAX_UNDO := 100
const CHECKER_LIGHT := Color(0.85, 0.85, 0.85)
const CHECKER_DARK := Color(0.7, 0.7, 0.7)
const GRID_COLOR := Color(0.3, 0.3, 0.3, 0.4)
const PIXEL_GRID_COLOR := Color(0.5, 0.5, 0.5, 0.15)
const SELECTION_BORDER := Color(1.0, 1.0, 1.0, 0.9)
const ONION_PREV_COLOR := Color(1.0, 0.2, 0.2, 0.25)
const ONION_NEXT_COLOR := Color(0.2, 0.2, 1.0, 0.25)
const PREVIEW_BG := Color(0.12, 0.12, 0.14)

# Default canvas sizes for common retro formats
const PRESET_SIZES := {
	"8×8 (tile)":   Vector2i(8, 8),
	"16×16 (NES)":  Vector2i(16, 16),
	"24×24":        Vector2i(24, 24),
	"32×32 (SNES)": Vector2i(32, 32),
	"48×48":        Vector2i(48, 48),
	"64×64":        Vector2i(64, 64),
	"128×128":      Vector2i(128, 128),
	"256×256":      Vector2i(256, 256),
	"16×32 (tall)": Vector2i(16, 32),
	"32×64 (tall)": Vector2i(32, 64),
}

# ─────────────────────────────────────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────────────────────────────────────
enum Tool {
	PEN,
	ERASER,
	LINE,
	RECT,
	RECT_FILLED,
	ELLIPSE,
	ELLIPSE_FILLED,
	FILL,
	COLOR_PICKER,
	SELECT,
	MOVE,
	MIRROR_PEN,
	DITHER_PEN,
	LIGHTEN,
	DARKEN,
}

# ─────────────────────────────────────────────────────────────────────────────
# RETRO PALETTES
# ─────────────────────────────────────────────────────────────────────────────
const PALETTES := {
	"NES": [
		"#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000",
		"#881400", "#503000", "#007800", "#006800", "#005800", "#004058", "#000000",
		"#BCBCBC", "#0078F8", "#0058F8", "#6844FC", "#D800CC", "#E40058", "#F83800",
		"#E45C10", "#AC7C00", "#00B800", "#00A800", "#00A844", "#008888", "#000000",
		"#F8F8F8", "#3CBCFC", "#6888FC", "#9878F8", "#F878F8", "#F85898", "#F87858",
		"#FCA044", "#F8B800", "#B8F818", "#58D854", "#58F898", "#00E8D8", "#787878",
		"#FCFCFC", "#A4E4FC", "#B8B8F8", "#D8B8F8", "#F8B8F8", "#F8A4C0", "#F0D0B0",
		"#FCE0A8", "#F8D878", "#D8F878", "#B8F8B8", "#B8F8D8", "#00FCFC", "#D8D8D8",
	],
	"GameBoy": [
		"#0F380F", "#306230", "#8BAC0F", "#9BBC0F",
	],
	"GameBoy Pocket": [
		"#000000", "#545454", "#A9A9A9", "#FFFFFF",
	],
	"C64": [
		"#000000", "#FFFFFF", "#880000", "#AAFFEE", "#CC44CC", "#00CC55",
		"#0000AA", "#EEEE77", "#DD8855", "#664400", "#FF7777", "#333333",
		"#777777", "#AAFF66", "#0088FF", "#BBBBBB",
	],
	"CGA": [
		"#000000", "#0000AA", "#00AA00", "#00AAAA",
		"#AA0000", "#AA00AA", "#AA5500", "#AAAAAA",
		"#555555", "#5555FF", "#55FF55", "#55FFFF",
		"#FF5555", "#FF55FF", "#FFFF55", "#FFFFFF",
	],
	"SNES": [
		"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F",
		"#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436",
		"#29ADFF", "#83769C", "#FF77A8", "#FFCCAA",
	],
	"PICO-8": [
		"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F",
		"#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436",
		"#29ADFF", "#83769C", "#FF77A8", "#FFCCAA",
	],
	"Endesga 32": [
		"#BE4A2F", "#D77643", "#EAD4AA", "#E4A672", "#B86F50", "#733E39",
		"#3E2731", "#A22633", "#E43B44", "#F77622", "#FEAE34", "#FEE761",
		"#63C74D", "#3E8948", "#265C42", "#193C3E", "#124E89", "#0099DB",
		"#2CE8F5", "#FFFFFF", "#C0CBDC", "#8B9BB4", "#5A6988", "#3A4466",
		"#262B44", "#181425", "#FF0044", "#68386C", "#B55088", "#F6757A",
		"#E8B796", "#C28569",
	],
	"Grayscale": [
		"#000000", "#111111", "#222222", "#333333", "#444444", "#555555",
		"#666666", "#777777", "#888888", "#999999", "#AAAAAA", "#BBBBBB",
		"#CCCCCC", "#DDDDDD", "#EEEEEE", "#FFFFFF",
	],
}

# ─────────────────────────────────────────────────────────────────────────────
# MEMBER VARIABLES
# ─────────────────────────────────────────────────────────────────────────────
var _canvas_size := Vector2i(32, 32)     ## pixel dimensions of the sprite
var _zoom := DEFAULT_ZOOM                ## current zoom level
var _pan_offset := Vector2.ZERO          ## camera offset (canvas coords)
var _current_tool: Tool = Tool.PEN
var _primary_color := Color.BLACK        ## left-click color
var _secondary_color := Color.WHITE      ## right-click color (eraser default)
var _pen_size := 1                       ## brush diameter in pixels
var _mirror_h := false                   ## horizontal mirror drawing
var _mirror_v := false                   ## vertical mirror drawing

# Layers — each layer is { "name": String, "image": Image, "visible": bool, "opacity": float }
var _layers: Array = []
var _active_layer_idx := 0

# Animation frames — each frame is { "layers": Array[Image], "duration": float }
# We store a flat list; _layers always refers to the active frame's layers.
var _frames: Array = []
var _active_frame_idx := 0
var _fps := 8.0
var _playing := false
var _play_timer := 0.0
var _preview_frame_idx := 0

# Onion skinning
var _onion_skin_enabled := false
var _onion_skin_prev := 1
var _onion_skin_next := 1

# Selection
var _selection_rect := Rect2i()
var _has_selection := false
var _selection_image: Image = null  ## floating selection pixels
var _selection_offset := Vector2i.ZERO

# Undo
var _undo_stack: Array = []  ## Array of snapshots
var _redo_stack: Array = []

# Drawing state
var _is_drawing := false
var _draw_start := Vector2i.ZERO
var _draw_end := Vector2i.ZERO
var _draw_preview_points: Array[Vector2i] = []
var _last_pen_pos := Vector2i(-1, -1)
var _stroke_image: Image = null  ## scratch for line/rect/ellipse preview

# Panning
var _is_panning := false
var _pan_start := Vector2.ZERO

# File
var _file_path := ""
var _dirty := false

# ── UI REFERENCES ────────────────────────────────────────────────────────────
var _canvas_panel: Control = null        ## the drawing surface
var _canvas_texture: ImageTexture = null ## composited display texture
var _preview_rect: TextureRect = null    ## animation preview
var _preview_texture: ImageTexture = null

var _tool_buttons: Dictionary = {}       ## Tool enum → Button
var _color_primary_rect: ColorRect = null
var _color_secondary_rect: ColorRect = null
var _color_picker_popup: ColorPicker = null
var _pen_size_spin: SpinBox = null

var _palette_grid: GridContainer = null
var _palette_option: OptionButton = null
var _recent_colors: Array[Color] = []
var _recent_color_grid: HBoxContainer = null

var _layer_list: ItemList = null
var _frame_strip: HBoxContainer = null
var _frame_scroll: ScrollContainer = null

var _fps_spin: SpinBox = null
var _play_btn: Button = null
var _onion_btn: CheckButton = null

var _size_label: Label = null
var _pos_label: Label = null
var _status_label: Label = null
var _zoom_label: Label = null

var _save_dialog: FileDialog = null
var _open_dialog: FileDialog = null
var _export_dialog: FileDialog = null
var _new_dialog: AcceptDialog = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_blank_sprite()
	_build_ui()

func _init_blank_sprite() -> void:
	var img := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_layers = [{ "name": "Layer 1", "image": img, "visible": true, "opacity": 1.0 }]
	_active_layer_idx = 0
	_frames = [{ "layers": [img.duplicate()], "duration": 1.0 / _fps }]
	_active_frame_idx = 0
	_undo_stack.clear()
	_redo_stack.clear()
	_dirty = false

# ─────────────────────────────────────────────────────────────────────────────
# BUILD UI
# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	split_offset = 220
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	# ── LEFT PANEL ──────────────────────────────────────────────────────
	var left_panel := PanelContainer.new()
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.16, 0.16, 0.19)
	left_style.set_content_margin_all(4)
	left_panel.add_theme_stylebox_override("panel", left_style)
	left_panel.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	left_scroll.add_child(left_vbox)

	_build_tool_panel(left_vbox)
	_add_separator(left_vbox)
	_build_color_panel(left_vbox)
	_add_separator(left_vbox)
	_build_palette_panel(left_vbox)
	_add_separator(left_vbox)
	_build_layer_panel(left_vbox)
	_add_separator(left_vbox)
	_build_preview_panel(left_vbox)

	# ── RIGHT PANEL ─────────────────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(right_vbox)

	_build_toolbar(right_vbox)
	_build_canvas(right_vbox)
	_build_frame_strip(right_vbox)
	_build_status_bar(right_vbox)

	# Initial render
	_refresh_canvas()
	_refresh_layer_list()
	_refresh_frame_strip()
	_load_palette("NES")

# ── SECTION HEADER helper ─────────────────────────────────────────────────
func _make_section_header(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.22, 0.26, 0.35)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(4)
	pc.add_theme_stylebox_override("panel", bg)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_font_size_override("font_size", 11)
	pc.add_child(lbl)
	return pc

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	parent.add_child(sep)

# ─────────────────────────────────────────────────────────────────────────────
# TOOL PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _build_tool_panel(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("🖌️  Drawing Tools"))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	var tool_defs := [
		[Tool.PEN,            "✏️", "Pen (P)"],
		[Tool.ERASER,         "🧹", "Eraser (E)"],
		[Tool.LINE,           "📏", "Line (L)"],
		[Tool.RECT,           "▭",  "Rectangle (R)"],
		[Tool.RECT_FILLED,    "■",  "Filled Rect (Shift+R)"],
		[Tool.ELLIPSE,        "○",  "Ellipse (O)"],
		[Tool.ELLIPSE_FILLED, "●",  "Filled Ellipse (Shift+O)"],
		[Tool.FILL,           "🪣", "Fill Bucket (G)"],
		[Tool.COLOR_PICKER,   "💉", "Color Picker (I)"],
		[Tool.SELECT,         "⬚",  "Select (S)"],
		[Tool.MOVE,           "✥",  "Move (M)"],
		[Tool.MIRROR_PEN,     "↔️", "Mirror Pen (H)"],
		[Tool.DITHER_PEN,     "▤",  "Dither Pen (D)"],
		[Tool.LIGHTEN,        "☀",  "Lighten (U)"],
		[Tool.DARKEN,         "🌑", "Darken (J)"],
	]

	for def in tool_defs:
		var btn := Button.new()
		btn.text = def[1]
		btn.tooltip_text = def[2]
		btn.custom_minimum_size = Vector2(40, 32)
		btn.toggle_mode = true
		btn.button_pressed = (def[0] == _current_tool)
		_style_tool_button(btn)
		var tool_id: int = def[0]
		btn.pressed.connect(func(): _select_tool(tool_id))
		grid.add_child(btn)
		_tool_buttons[def[0]] = btn

	# Pen size
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 4)
	parent.add_child(size_row)
	var size_lbl := Label.new()
	size_lbl.text = "Size:"
	size_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_lbl.add_theme_font_size_override("font_size", 11)
	size_row.add_child(size_lbl)
	_pen_size_spin = SpinBox.new()
	_pen_size_spin.min_value = 1
	_pen_size_spin.max_value = 32
	_pen_size_spin.value = _pen_size
	_pen_size_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	_pen_size_spin.value_changed.connect(func(v): _pen_size = int(v))
	size_row.add_child(_pen_size_spin)

	# Mirror toggles
	var mirror_row := HBoxContainer.new()
	mirror_row.add_theme_constant_override("separation", 4)
	parent.add_child(mirror_row)
	var mirr_h_btn := CheckButton.new()
	mirr_h_btn.text = "↔ Mirror H"
	mirr_h_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mirr_h_btn.add_theme_font_size_override("font_size", 10)
	mirr_h_btn.toggled.connect(func(v): _mirror_h = v)
	mirror_row.add_child(mirr_h_btn)
	var mirr_v_btn := CheckButton.new()
	mirr_v_btn.text = "↕ Mirror V"
	mirr_v_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mirr_v_btn.add_theme_font_size_override("font_size", 10)
	mirr_v_btn.toggled.connect(func(v): _mirror_v = v)
	mirror_row.add_child(mirr_v_btn)

# ─────────────────────────────────────────────────────────────────────────────
# COLOR PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _build_color_panel(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("🎨  Colors"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)

	# Primary color swatch
	var pri_box := VBoxContainer.new()
	pri_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(pri_box)
	var pri_lbl := Label.new()
	pri_lbl.text = "Primary"
	pri_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pri_lbl.add_theme_font_size_override("font_size", 9)
	pri_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pri_box.add_child(pri_lbl)
	_color_primary_rect = ColorRect.new()
	_color_primary_rect.color = _primary_color
	_color_primary_rect.custom_minimum_size = Vector2(48, 48)
	_color_primary_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_color_primary_rect.gui_input.connect(_on_primary_color_click)
	var pri_border := _make_color_border(_color_primary_rect)
	pri_box.add_child(pri_border)

	# Swap button
	var swap_btn := Button.new()
	swap_btn.text = "⇄"
	swap_btn.tooltip_text = "Swap Colors (X)"
	swap_btn.custom_minimum_size = Vector2(28, 28)
	_style_tool_button(swap_btn)
	swap_btn.pressed.connect(_swap_colors)
	row.add_child(swap_btn)

	# Secondary color swatch
	var sec_box := VBoxContainer.new()
	sec_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sec_box)
	var sec_lbl := Label.new()
	sec_lbl.text = "Secondary"
	sec_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sec_lbl.add_theme_font_size_override("font_size", 9)
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_box.add_child(sec_lbl)
	_color_secondary_rect = ColorRect.new()
	_color_secondary_rect.color = _secondary_color
	_color_secondary_rect.custom_minimum_size = Vector2(48, 48)
	_color_secondary_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_color_secondary_rect.gui_input.connect(_on_secondary_color_click)
	var sec_border := _make_color_border(_color_secondary_rect)
	sec_box.add_child(sec_border)

	# Recent colors
	var recent_lbl := Label.new()
	recent_lbl.text = "Recent:"
	recent_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	recent_lbl.add_theme_font_size_override("font_size", 9)
	parent.add_child(recent_lbl)
	_recent_color_grid = HBoxContainer.new()
	_recent_color_grid.add_theme_constant_override("separation", 2)
	parent.add_child(_recent_color_grid)

func _make_color_border(inner: ColorRect) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.5, 0.5)
	style.set_content_margin_all(2)
	style.set_corner_radius_all(2)
	pc.add_theme_stylebox_override("panel", style)
	pc.add_child(inner)
	return pc

# ─────────────────────────────────────────────────────────────────────────────
# PALETTE PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _build_palette_panel(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("🎮  Palette"))

	_palette_option = OptionButton.new()
	_palette_option.add_theme_font_size_override("font_size", 11)
	_palette_option.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	var idx := 0
	for pname in PALETTES:
		_palette_option.add_item(pname)
		if pname == "NES":
			_palette_option.selected = idx
		idx += 1
	_palette_option.item_selected.connect(func(i): _load_palette(_palette_option.get_item_text(i)))
	parent.add_child(_palette_option)

	_palette_grid = GridContainer.new()
	_palette_grid.columns = 8
	_palette_grid.add_theme_constant_override("h_separation", 1)
	_palette_grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(_palette_grid)

func _load_palette(palette_name: String) -> void:
	# Clear existing
	for c in _palette_grid.get_children():
		c.queue_free()

	if palette_name not in PALETTES:
		return

	var colors: Array = PALETTES[palette_name]
	for hex in colors:
		var color := Color(hex)
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.tooltip_text = hex
		swatch.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT:
					_set_primary_color(color)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					_set_secondary_color(color)
		)
		_palette_grid.add_child(swatch)

# ─────────────────────────────────────────────────────────────────────────────
# LAYER PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _build_layer_panel(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("📑  Layers"))

	_layer_list = ItemList.new()
	_layer_list.custom_minimum_size = Vector2(0, 100)
	_layer_list.max_columns = 1
	_layer_list.select_mode = ItemList.SELECT_SINGLE
	_layer_list.allow_reselect = true
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(0.14, 0.14, 0.17)
	list_style.set_border_width_all(1)
	list_style.border_color = Color(0.25, 0.25, 0.30)
	list_style.set_corner_radius_all(3)
	_layer_list.add_theme_stylebox_override("panel", list_style)
	_layer_list.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_layer_list.item_selected.connect(_on_layer_selected)
	parent.add_child(_layer_list)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 2)
	parent.add_child(btn_row)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Add Layer"
	add_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(add_btn)
	add_btn.pressed.connect(_add_layer)
	btn_row.add_child(add_btn)

	var del_btn := Button.new()
	del_btn.text = "−"
	del_btn.tooltip_text = "Delete Layer"
	del_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(del_btn)
	del_btn.pressed.connect(_delete_layer)
	btn_row.add_child(del_btn)

	var up_btn := Button.new()
	up_btn.text = "▲"
	up_btn.tooltip_text = "Move Up"
	up_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(up_btn)
	up_btn.pressed.connect(_move_layer_up)
	btn_row.add_child(up_btn)

	var down_btn := Button.new()
	down_btn.text = "▼"
	down_btn.tooltip_text = "Move Down"
	down_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(down_btn)
	down_btn.pressed.connect(_move_layer_down)
	btn_row.add_child(down_btn)

	var vis_btn := Button.new()
	vis_btn.text = "👁"
	vis_btn.tooltip_text = "Toggle Visibility"
	vis_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(vis_btn)
	vis_btn.pressed.connect(_toggle_layer_visibility)
	btn_row.add_child(vis_btn)

	var merge_btn := Button.new()
	merge_btn.text = "⊞"
	merge_btn.tooltip_text = "Merge Down"
	merge_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(merge_btn)
	merge_btn.pressed.connect(_merge_layer_down)
	btn_row.add_child(merge_btn)

# ─────────────────────────────────────────────────────────────────────────────
# PREVIEW PANEL (animation preview)
# ─────────────────────────────────────────────────────────────────────────────
func _build_preview_panel(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_header("▶️  Preview"))

	var preview_bg := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = PREVIEW_BG
	bg_style.set_corner_radius_all(3)
	bg_style.set_content_margin_all(4)
	preview_bg.add_theme_stylebox_override("panel", bg_style)
	preview_bg.custom_minimum_size = Vector2(0, 100)
	parent.add_child(preview_bg)

	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.size_flags_vertical = SIZE_EXPAND_FILL
	preview_bg.add_child(center)

	_preview_rect = TextureRect.new()
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_rect.custom_minimum_size = Vector2(80, 80)
	_preview_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	center.add_child(_preview_rect)

	# FPS & play controls
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 4)
	ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(ctrl_row)

	_play_btn = Button.new()
	_play_btn.text = "▶"
	_play_btn.tooltip_text = "Play/Pause Animation"
	_play_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(_play_btn)
	_play_btn.pressed.connect(_toggle_play)
	ctrl_row.add_child(_play_btn)

	var fps_lbl := Label.new()
	fps_lbl.text = "FPS:"
	fps_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	fps_lbl.add_theme_font_size_override("font_size", 10)
	ctrl_row.add_child(fps_lbl)

	_fps_spin = SpinBox.new()
	_fps_spin.min_value = 1
	_fps_spin.max_value = 60
	_fps_spin.value = _fps
	_fps_spin.custom_minimum_size = Vector2(60, 0)
	_fps_spin.value_changed.connect(func(v): _fps = v)
	ctrl_row.add_child(_fps_spin)

	_onion_btn = CheckButton.new()
	_onion_btn.text = "Onion"
	_onion_btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_onion_btn.add_theme_font_size_override("font_size", 10)
	_onion_btn.toggled.connect(func(v): _onion_skin_enabled = v; _refresh_canvas())
	ctrl_row.add_child(_onion_btn)

# ─────────────────────────────────────────────────────────────────────────────
# TOOLBAR (top of right panel)
# ─────────────────────────────────────────────────────────────────────────────
func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.18, 0.18, 0.22)
	tb_style.set_content_margin_all(4)
	var tb_panel := PanelContainer.new()
	tb_panel.add_theme_stylebox_override("panel", tb_style)
	parent.add_child(tb_panel)
	# Wrap toolbar in a horizontal ScrollContainer so buttons don't overflow off-screen
	var tb_scroll := ScrollContainer.new()
	tb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tb_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tb_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	tb_scroll.custom_minimum_size.y = 34
	tb_panel.add_child(tb_scroll)
	tb_scroll.add_child(toolbar)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Form"
	back_btn.custom_minimum_size = Vector2(60, 28)
	_style_tool_button(back_btn)
	back_btn.pressed.connect(func(): back_to_form_requested.emit())
	toolbar.add_child(back_btn)

	toolbar.add_child(VSeparator.new())

	# New
	var new_btn := Button.new()
	new_btn.text = "📄 New"
	new_btn.tooltip_text = "New Sprite (Ctrl+N)"
	_style_tool_button(new_btn)
	new_btn.pressed.connect(_show_new_dialog)
	toolbar.add_child(new_btn)

	# Open
	var open_btn := Button.new()
	open_btn.text = "📂 Open"
	open_btn.tooltip_text = "Open Image (Ctrl+O)"
	_style_tool_button(open_btn)
	open_btn.pressed.connect(_show_open_dialog)
	toolbar.add_child(open_btn)

	# Save
	var save_btn := Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save (Ctrl+S)"
	_style_tool_button(save_btn)
	save_btn.pressed.connect(_save)
	toolbar.add_child(save_btn)

	# Export
	var export_btn := Button.new()
	export_btn.text = "📤 Export"
	export_btn.tooltip_text = "Export Spritesheet (Ctrl+E)"
	_style_tool_button(export_btn)
	export_btn.pressed.connect(_show_export_dialog)
	toolbar.add_child(export_btn)

	toolbar.add_child(VSeparator.new())

	# Undo/Redo
	var undo_btn := Button.new()
	undo_btn.text = "↩"
	undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	_style_tool_button(undo_btn)
	undo_btn.pressed.connect(_undo)
	toolbar.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "↪"
	redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	_style_tool_button(redo_btn)
	redo_btn.pressed.connect(_redo)
	toolbar.add_child(redo_btn)

	toolbar.add_child(VSeparator.new())

	# Resize canvas
	var resize_btn := Button.new()
	resize_btn.text = "⊞ Resize"
	resize_btn.tooltip_text = "Resize Canvas"
	_style_tool_button(resize_btn)
	resize_btn.pressed.connect(_show_resize_dialog)
	toolbar.add_child(resize_btn)

	# Flip H/V
	var flip_h_btn := Button.new()
	flip_h_btn.text = "↔ Flip H"
	flip_h_btn.tooltip_text = "Flip Horizontal"
	_style_tool_button(flip_h_btn)
	flip_h_btn.pressed.connect(func(): _flip_image(true, false))
	toolbar.add_child(flip_h_btn)

	var flip_v_btn := Button.new()
	flip_v_btn.text = "↕ Flip V"
	flip_v_btn.tooltip_text = "Flip Vertical"
	_style_tool_button(flip_v_btn)
	flip_v_btn.pressed.connect(func(): _flip_image(false, true))
	toolbar.add_child(flip_v_btn)

	# Rotate 90°
	var rot_btn := Button.new()
	rot_btn.text = "↻ Rot90"
	rot_btn.tooltip_text = "Rotate 90° CW"
	_style_tool_button(rot_btn)
	rot_btn.pressed.connect(_rotate_90)
	toolbar.add_child(rot_btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# Size info
	_size_label = Label.new()
	_size_label.text = str(_canvas_size.x) + "×" + str(_canvas_size.y)
	_size_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_size_label.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(_size_label)

	# Zoom label
	_zoom_label = Label.new()
	_zoom_label.text = str(int(_zoom)) + "×"
	_zoom_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_zoom_label.add_theme_font_size_override("font_size", 11)
	toolbar.add_child(_zoom_label)

# ─────────────────────────────────────────────────────────────────────────────
# CANVAS (the main drawing surface)
# ─────────────────────────────────────────────────────────────────────────────
func _build_canvas(parent: VBoxContainer) -> void:
	_canvas_panel = Control.new()
	_canvas_panel.name = "PixelCanvas"
	_canvas_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_canvas_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_canvas_panel.clip_contents = true
	_canvas_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_panel.focus_mode = Control.FOCUS_ALL

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.14)
	_canvas_panel.add_theme_stylebox_override("panel", bg)

	_canvas_panel.draw.connect(_on_canvas_draw)
	_canvas_panel.gui_input.connect(_on_canvas_input)
	parent.add_child(_canvas_panel)

	# Create the composited texture
	_canvas_texture = ImageTexture.new()
	_preview_texture = ImageTexture.new()

# ─────────────────────────────────────────────────────────────────────────────
# FRAME STRIP (bottom of right panel)
# ─────────────────────────────────────────────────────────────────────────────
func _build_frame_strip(parent: VBoxContainer) -> void:
	var strip_panel := PanelContainer.new()
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = Color(0.14, 0.14, 0.17)
	strip_style.set_content_margin_all(4)
	strip_panel.add_theme_stylebox_override("panel", strip_style)
	strip_panel.custom_minimum_size = Vector2(0, 80)
	parent.add_child(strip_panel)

	var strip_vbox := VBoxContainer.new()
	strip_panel.add_child(strip_vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	strip_vbox.add_child(header)

	var frames_lbl := Label.new()
	frames_lbl.text = "🎞️  Frames"
	frames_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	frames_lbl.add_theme_font_size_override("font_size", 11)
	header.add_child(frames_lbl)

	var add_frame_btn := Button.new()
	add_frame_btn.text = "+"
	add_frame_btn.tooltip_text = "Add Frame"
	add_frame_btn.custom_minimum_size = Vector2(24, 20)
	_style_tool_button(add_frame_btn)
	add_frame_btn.pressed.connect(_add_frame)
	header.add_child(add_frame_btn)

	var dup_frame_btn := Button.new()
	dup_frame_btn.text = "⊡"
	dup_frame_btn.tooltip_text = "Duplicate Frame"
	dup_frame_btn.custom_minimum_size = Vector2(24, 20)
	_style_tool_button(dup_frame_btn)
	dup_frame_btn.pressed.connect(_duplicate_frame)
	header.add_child(dup_frame_btn)

	var del_frame_btn := Button.new()
	del_frame_btn.text = "−"
	del_frame_btn.tooltip_text = "Delete Frame"
	del_frame_btn.custom_minimum_size = Vector2(24, 20)
	_style_tool_button(del_frame_btn)
	del_frame_btn.pressed.connect(_delete_frame)
	header.add_child(del_frame_btn)

	# Scroll container for frame thumbnails
	_frame_scroll = ScrollContainer.new()
	_frame_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_frame_scroll.custom_minimum_size = Vector2(0, 52)
	strip_vbox.add_child(_frame_scroll)

	_frame_strip = HBoxContainer.new()
	_frame_strip.add_theme_constant_override("separation", 4)
	_frame_scroll.add_child(_frame_strip)

# ─────────────────────────────────────────────────────────────────────────────
# STATUS BAR
# ─────────────────────────────────────────────────────────────────────────────
func _build_status_bar(parent: VBoxContainer) -> void:
	_status_label = Label.new()
	_status_label.text = "  Sprite Editor — Ready"
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_status_label.add_theme_font_size_override("font_size", 11)
	parent.add_child(_status_label)

# ─────────────────────────────────────────────────────────────────────────────
# TOOL SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _select_tool(tool_id: int) -> void:
	_current_tool = tool_id as Tool
	for tid in _tool_buttons:
		_tool_buttons[tid].button_pressed = (tid == tool_id)
	_update_status()

# ─────────────────────────────────────────────────────────────────────────────
# COLOR MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _set_primary_color(c: Color) -> void:
	_primary_color = c
	if is_instance_valid(_color_primary_rect):
		_color_primary_rect.color = c
	_add_recent_color(c)

func _set_secondary_color(c: Color) -> void:
	_secondary_color = c
	if is_instance_valid(_color_secondary_rect):
		_color_secondary_rect.color = c
	_add_recent_color(c)

func _swap_colors() -> void:
	var tmp := _primary_color
	_set_primary_color(_secondary_color)
	_set_secondary_color(tmp)

func _add_recent_color(c: Color) -> void:
	# Avoid duplicates
	for rc in _recent_colors:
		if rc.is_equal_approx(c):
			return
	_recent_colors.push_front(c)
	if _recent_colors.size() > 16:
		_recent_colors.pop_back()
	_refresh_recent_colors()

func _refresh_recent_colors() -> void:
	if not is_instance_valid(_recent_color_grid):
		return
	for child in _recent_color_grid.get_children():
		child.queue_free()
	for c in _recent_colors:
		var swatch := ColorRect.new()
		swatch.color = c
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		var color_copy := c
		swatch.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT:
					_set_primary_color(color_copy)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					_set_secondary_color(color_copy)
		)
		_recent_color_grid.add_child(swatch)

func _on_primary_color_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_show_color_picker(true)

func _on_secondary_color_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_show_color_picker(false)

func _show_color_picker(is_primary: bool) -> void:
	if is_instance_valid(_color_picker_popup):
		_color_picker_popup.queue_free()

	var popup := PopupPanel.new()
	var picker := ColorPicker.new()
	picker.color = _primary_color if is_primary else _secondary_color
	picker.color_changed.connect(func(c):
		if is_primary:
			_set_primary_color(c)
		else:
			_set_secondary_color(c)
	)
	popup.add_child(picker)
	popup.size = Vector2(300, 400)
	add_child(popup)
	popup.popup_centered()
	_color_picker_popup = picker

# ─────────────────────────────────────────────────────────────────────────────
# CANVAS RENDERING
# ─────────────────────────────────────────────────────────────────────────────
func _on_canvas_draw() -> void:
	if not is_instance_valid(_canvas_panel):
		return
	var panel_size := _canvas_panel.size
	var canvas_px_size := Vector2(_canvas_size) * _zoom
	var offset := (panel_size - canvas_px_size) * 0.5 + _pan_offset

	# Draw transparency checkerboard
	_draw_checkerboard(offset, canvas_px_size)

	# Draw the composited sprite
	_refresh_composite_texture()
	if _canvas_texture != null:
		_canvas_panel.draw_texture_rect(_canvas_texture, Rect2(offset, canvas_px_size), false)

	# Onion skin
	if _onion_skin_enabled and _frames.size() > 1:
		_draw_onion_skin(offset, canvas_px_size)

	# Pixel grid (only if zoomed enough)
	if _zoom >= 4.0:
		_draw_pixel_grid(offset, canvas_px_size)

	# Draw preview shapes (line, rect, ellipse in progress)
	if _is_drawing and _current_tool in [Tool.LINE, Tool.RECT, Tool.RECT_FILLED, Tool.ELLIPSE, Tool.ELLIPSE_FILLED]:
		_draw_shape_preview(offset)

	# Selection rectangle
	if _has_selection:
		var sel_rect := Rect2(
			offset + Vector2(_selection_rect.position + _selection_offset) * _zoom,
			Vector2(_selection_rect.size) * _zoom
		)
		_canvas_panel.draw_rect(sel_rect, SELECTION_BORDER, false, 1.0)
		# Dashed inner
		_canvas_panel.draw_rect(sel_rect.grow(-1), Color(0, 0, 0, 0.5), false, 1.0)

	# Cursor crosshair
	_draw_cursor_highlight(offset)

func _draw_checkerboard(offset: Vector2, canvas_px_size: Vector2) -> void:
	var checker_size := max(_zoom, 4.0)
	var cols := int(canvas_px_size.x / checker_size) + 1
	var rows := int(canvas_px_size.y / checker_size) + 1
	for y in range(rows):
		for x in range(cols):
			var c := CHECKER_LIGHT if (x + y) % 2 == 0 else CHECKER_DARK
			var r := Rect2(
				offset + Vector2(x * checker_size, y * checker_size),
				Vector2(checker_size, checker_size)
			)
			# Clip to canvas bounds
			r = r.intersection(Rect2(offset, canvas_px_size))
			if r.size.x > 0 and r.size.y > 0:
				_canvas_panel.draw_rect(r, c)

func _draw_pixel_grid(offset: Vector2, canvas_px_size: Vector2) -> void:
	for x in range(_canvas_size.x + 1):
		var px := offset.x + x * _zoom
		_canvas_panel.draw_line(
			Vector2(px, offset.y),
			Vector2(px, offset.y + canvas_px_size.y),
			PIXEL_GRID_COLOR, 1.0
		)
	for y in range(_canvas_size.y + 1):
		var py := offset.y + y * _zoom
		_canvas_panel.draw_line(
			Vector2(offset.x, py),
			Vector2(offset.x + canvas_px_size.x, py),
			PIXEL_GRID_COLOR, 1.0
		)

func _draw_onion_skin(offset: Vector2, canvas_px_size: Vector2) -> void:
	# Previous frames
	for i in range(1, _onion_skin_prev + 1):
		var idx := _active_frame_idx - i
		if idx < 0:
			idx += _frames.size()
		if idx != _active_frame_idx and idx >= 0 and idx < _frames.size():
			var img := _composite_frame(idx)
			var tex := ImageTexture.create_from_image(img)
			_canvas_panel.draw_texture_rect(tex, Rect2(offset, canvas_px_size), false, ONION_PREV_COLOR)
	# Next frames
	for i in range(1, _onion_skin_next + 1):
		var idx := (_active_frame_idx + i) % _frames.size()
		if idx != _active_frame_idx:
			var img := _composite_frame(idx)
			var tex := ImageTexture.create_from_image(img)
			_canvas_panel.draw_texture_rect(tex, Rect2(offset, canvas_px_size), false, ONION_NEXT_COLOR)

func _draw_shape_preview(offset: Vector2) -> void:
	for px in _draw_preview_points:
		if px.x >= 0 and px.x < _canvas_size.x and px.y >= 0 and px.y < _canvas_size.y:
			var r := Rect2(offset + Vector2(px) * _zoom, Vector2(_zoom, _zoom))
			_canvas_panel.draw_rect(r, Color(_primary_color, 0.5))

func _draw_cursor_highlight(offset: Vector2) -> void:
	var mouse_pos := _canvas_panel.get_local_mouse_position()
	var px := _screen_to_pixel(mouse_pos)
	if px.x >= 0 and px.x < _canvas_size.x and px.y >= 0 and px.y < _canvas_size.y:
		var half := _pen_size / 2
		for dy in range(_pen_size):
			for dx in range(_pen_size):
				var cx := px.x - half + dx
				var cy := px.y - half + dy
				if cx >= 0 and cx < _canvas_size.x and cy >= 0 and cy < _canvas_size.y:
					var r := Rect2(offset + Vector2(cx, cy) * _zoom, Vector2(_zoom, _zoom))
					_canvas_panel.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)

# ─────────────────────────────────────────────────────────────────────────────
# COMPOSITING
# ─────────────────────────────────────────────────────────────────────────────
func _get_active_image() -> Image:
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size():
		return _layers[_active_layer_idx]["image"] as Image
	return null

func _composite_layers() -> Image:
	var result := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	for i in range(_layers.size() - 1, -1, -1):  # bottom to top
		var layer: Dictionary = _layers[i]
		if not layer["visible"]:
			continue
		var img: Image = layer["image"]
		var opacity: float = layer["opacity"]
		if opacity >= 1.0:
			result.blend_rect(img, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
		else:
			# Blend with opacity
			var tmp := img.duplicate()
			for y in range(_canvas_size.y):
				for x in range(_canvas_size.x):
					var c: Color = tmp.get_pixel(x, y)
					c.a *= opacity
					tmp.set_pixel(x, y, c)
			result.blend_rect(tmp, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
	return result

func _composite_frame(frame_idx: int) -> Image:
	var frame: Dictionary = _frames[frame_idx]
	var frame_layers: Array = frame["layers"]
	var result := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	for i in range(frame_layers.size() - 1, -1, -1):
		var img: Image = frame_layers[i]
		result.blend_rect(img, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
	return result

func _refresh_composite_texture() -> void:
	var composite := _composite_layers()
	_canvas_texture = ImageTexture.create_from_image(composite)

func _refresh_canvas() -> void:
	if is_instance_valid(_canvas_panel):
		_canvas_panel.queue_redraw()
	_refresh_preview()

# ─────────────────────────────────────────────────────────────────────────────
# CANVAS INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _on_canvas_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		_on_canvas_mouse_button(ev)
	elif ev is InputEventMouseMotion:
		_on_canvas_mouse_motion(ev)

func _screen_to_pixel(screen_pos: Vector2) -> Vector2i:
	var panel_size := _canvas_panel.size
	var canvas_px_size := Vector2(_canvas_size) * _zoom
	var offset := (panel_size - canvas_px_size) * 0.5 + _pan_offset
	var local := (screen_pos - offset) / _zoom
	return Vector2i(int(floor(local.x)), int(floor(local.y)))

func _on_canvas_mouse_button(ev: InputEventMouseButton) -> void:
	# Zoom
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom = min(_zoom * 1.25, MAX_ZOOM)
		_update_zoom_label()
		_refresh_canvas()
		return
	if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom = max(_zoom / 1.25, MIN_ZOOM)
		_update_zoom_label()
		_refresh_canvas()
		return

	# Pan with middle mouse
	if ev.button_index == MOUSE_BUTTON_MIDDLE:
		if ev.pressed:
			_is_panning = true
			_pan_start = ev.position
		else:
			_is_panning = false
		return

	var px := _screen_to_pixel(ev.position)
	var color := _primary_color if ev.button_index == MOUSE_BUTTON_LEFT else _secondary_color

	if ev.pressed:
		match _current_tool:
			Tool.PEN, Tool.ERASER, Tool.MIRROR_PEN, Tool.DITHER_PEN, Tool.LIGHTEN, Tool.DARKEN:
				_push_undo()
				_is_drawing = true
				_last_pen_pos = px
				_draw_pen_stroke(px, color)
				_refresh_canvas()
			Tool.LINE, Tool.RECT, Tool.RECT_FILLED, Tool.ELLIPSE, Tool.ELLIPSE_FILLED:
				_push_undo()
				_is_drawing = true
				_draw_start = px
				_draw_end = px
				_stroke_image = _get_active_image().duplicate() if _get_active_image() else null
			Tool.FILL:
				_push_undo()
				_flood_fill(px, color)
				_refresh_canvas()
			Tool.COLOR_PICKER:
				_pick_color(px)
			Tool.SELECT:
				if not ev.pressed:
					return
				_is_drawing = true
				_draw_start = px
				_draw_end = px
				_has_selection = false
			Tool.MOVE:
				if _has_selection:
					_is_drawing = true
					_draw_start = px
	else:
		# Button released
		if _is_drawing:
			_is_drawing = false
			match _current_tool:
				Tool.LINE:
					_commit_line(_draw_start, px, color)
				Tool.RECT:
					_commit_rect(_draw_start, px, color, false)
				Tool.RECT_FILLED:
					_commit_rect(_draw_start, px, color, true)
				Tool.ELLIPSE:
					_commit_ellipse(_draw_start, px, color, false)
				Tool.ELLIPSE_FILLED:
					_commit_ellipse(_draw_start, px, color, true)
				Tool.SELECT:
					_finalize_selection(_draw_start, px)
			_draw_preview_points.clear()
			_refresh_canvas()

func _on_canvas_mouse_motion(ev: InputEventMouseMotion) -> void:
	# Pan
	if _is_panning:
		_pan_offset += ev.relative
		_refresh_canvas()
		return

	var px := _screen_to_pixel(ev.position)
	_update_pos_label(px)

	if _is_drawing:
		var color := _primary_color
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			color = _secondary_color

		match _current_tool:
			Tool.PEN, Tool.ERASER, Tool.MIRROR_PEN, Tool.DITHER_PEN, Tool.LIGHTEN, Tool.DARKEN:
				# Interpolate from last position to current for smooth strokes
				var points := _bresenham_line(_last_pen_pos, px)
				for p in points:
					_draw_pen_stroke(p, color)
				_last_pen_pos = px
				_refresh_canvas()
			Tool.LINE, Tool.RECT, Tool.RECT_FILLED, Tool.ELLIPSE, Tool.ELLIPSE_FILLED:
				_draw_end = px
				_update_shape_preview(color)
				_refresh_canvas()
			Tool.SELECT:
				_draw_end = px
				_refresh_canvas()
			Tool.MOVE:
				if _has_selection:
					_selection_offset += px - _draw_start
					_draw_start = px
					_refresh_canvas()

	_refresh_canvas()  # for cursor highlight

# ─────────────────────────────────────────────────────────────────────────────
# DRAWING OPERATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _draw_pen_stroke(pos: Vector2i, color: Color) -> void:
	var img := _get_active_image()
	if img == null:
		return

	var half := _pen_size / 2
	for dy in range(_pen_size):
		for dx in range(_pen_size):
			var px := pos.x - half + dx
			var py := pos.y - half + dy
			_set_pixel_safe(img, px, py, color)

			if _current_tool == Tool.MIRROR_PEN or _mirror_h:
				_set_pixel_safe(img, _canvas_size.x - 1 - px, py, color)
			if _mirror_v:
				_set_pixel_safe(img, px, _canvas_size.y - 1 - py, color)
			if (_current_tool == Tool.MIRROR_PEN or _mirror_h) and _mirror_v:
				_set_pixel_safe(img, _canvas_size.x - 1 - px, _canvas_size.y - 1 - py, color)

func _set_pixel_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= _canvas_size.x or y < 0 or y >= _canvas_size.y:
		return
	match _current_tool:
		Tool.ERASER:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		Tool.LIGHTEN:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.lightened(0.1))
		Tool.DARKEN:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.darkened(0.1))
		Tool.DITHER_PEN:
			if (x + y) % 2 == 0:
				img.set_pixel(x, y, color)
		_:
			img.set_pixel(x, y, color)

func _flood_fill(start: Vector2i, fill_color: Color) -> void:
	var img := _get_active_image()
	if img == null:
		return
	if start.x < 0 or start.x >= _canvas_size.x or start.y < 0 or start.y >= _canvas_size.y:
		return
	var target_color := img.get_pixel(start.x, start.y)
	if target_color.is_equal_approx(fill_color):
		return
	var stack: Array[Vector2i] = [start]
	var visited := {}
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= _canvas_size.x or p.y < 0 or p.y >= _canvas_size.y:
			continue
		var key := p.x * 10000 + p.y
		if key in visited:
			continue
		visited[key] = true
		if not img.get_pixel(p.x, p.y).is_equal_approx(target_color):
			continue
		img.set_pixel(p.x, p.y, fill_color)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

func _pick_color(pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= _canvas_size.x or pos.y < 0 or pos.y >= _canvas_size.y:
		return
	var composite := _composite_layers()
	_set_primary_color(composite.get_pixel(pos.x, pos.y))

func _commit_line(from: Vector2i, to: Vector2i, color: Color) -> void:
	var img := _get_active_image()
	if img == null:
		return
	var points := _bresenham_line(from, to)
	for p in points:
		_set_pixel_safe(img, p.x, p.y, color)

func _commit_rect(from: Vector2i, to: Vector2i, color: Color, filled: bool) -> void:
	var img := _get_active_image()
	if img == null:
		return
	var x0 := mini(from.x, to.x)
	var y0 := mini(from.y, to.y)
	var x1 := maxi(from.x, to.x)
	var y1 := maxi(from.y, to.y)
	if filled:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				_set_pixel_safe(img, x, y, color)
	else:
		for x in range(x0, x1 + 1):
			_set_pixel_safe(img, x, y0, color)
			_set_pixel_safe(img, x, y1, color)
		for y in range(y0, y1 + 1):
			_set_pixel_safe(img, x0, y, color)
			_set_pixel_safe(img, x1, y, color)

func _commit_ellipse(from: Vector2i, to: Vector2i, color: Color, filled: bool) -> void:
	var img := _get_active_image()
	if img == null:
		return
	var cx: float = (from.x + to.x) / 2.0
	var cy: float = (from.y + to.y) / 2.0
	var rx: float = abs(to.x - from.x) / 2.0
	var ry: float = abs(to.y - from.y) / 2.0
	if rx < 0.5 or ry < 0.5:
		return
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			var dx: float = (x - cx) / rx
			var dy: float = (y - cy) / ry
			var dist: float = dx * dx + dy * dy
			if filled:
				if dist <= 1.0:
					_set_pixel_safe(img, x, y, color)
			else:
				if dist <= 1.0 and dist >= 0.7:
					_set_pixel_safe(img, x, y, color)

func _update_shape_preview(color: Color) -> void:
	_draw_preview_points.clear()
	match _current_tool:
		Tool.LINE:
			_draw_preview_points = _bresenham_line(_draw_start, _draw_end)
		Tool.RECT, Tool.RECT_FILLED:
			var x0 := mini(_draw_start.x, _draw_end.x)
			var y0 := mini(_draw_start.y, _draw_end.y)
			var x1 := maxi(_draw_start.x, _draw_end.x)
			var y1 := maxi(_draw_start.y, _draw_end.y)
			var filled := (_current_tool == Tool.RECT_FILLED)
			if filled:
				for y in range(y0, y1 + 1):
					for x in range(x0, x1 + 1):
						_draw_preview_points.append(Vector2i(x, y))
			else:
				for x in range(x0, x1 + 1):
					_draw_preview_points.append(Vector2i(x, y0))
					_draw_preview_points.append(Vector2i(x, y1))
				for y in range(y0 + 1, y1):
					_draw_preview_points.append(Vector2i(x0, y))
					_draw_preview_points.append(Vector2i(x1, y))
		Tool.ELLIPSE, Tool.ELLIPSE_FILLED:
			var cx: float = (_draw_start.x + _draw_end.x) / 2.0
			var cy: float = (_draw_start.y + _draw_end.y) / 2.0
			var rx: float = abs(_draw_end.x - _draw_start.x) / 2.0
			var ry: float = abs(_draw_end.y - _draw_start.y) / 2.0
			var filled := (_current_tool == Tool.ELLIPSE_FILLED)
			if rx >= 0.5 and ry >= 0.5:
				for y in range(mini(_draw_start.y, _draw_end.y), maxi(_draw_start.y, _draw_end.y) + 1):
					for x in range(mini(_draw_start.x, _draw_end.x), maxi(_draw_start.x, _draw_end.x) + 1):
						var ddx: float = (x - cx) / rx
						var ddy: float = (y - cy) / ry
						var d: float = ddx * ddx + ddy * ddy
						if (filled and d <= 1.0) or (not filled and d <= 1.0 and d >= 0.7):
							_draw_preview_points.append(Vector2i(x, y))

# ─────────────────────────────────────────────────────────────────────────────
# SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _finalize_selection(from: Vector2i, to: Vector2i) -> void:
	var x0 := clampi(mini(from.x, to.x), 0, _canvas_size.x - 1)
	var y0 := clampi(mini(from.y, to.y), 0, _canvas_size.y - 1)
	var x1 := clampi(maxi(from.x, to.x), 0, _canvas_size.x - 1)
	var y1 := clampi(maxi(from.y, to.y), 0, _canvas_size.y - 1)
	if x1 - x0 < 1 or y1 - y0 < 1:
		_has_selection = false
		return
	_selection_rect = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	_selection_offset = Vector2i.ZERO
	_has_selection = true

# ─────────────────────────────────────────────────────────────────────────────
# BRESENHAM LINE
# ─────────────────────────────────────────────────────────────────────────────
func _bresenham_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx - dy
	var x := from.x
	var y := from.y
	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return points

# ─────────────────────────────────────────────────────────────────────────────
# UNDO / REDO
# ─────────────────────────────────────────────────────────────────────────────
func _push_undo() -> void:
	var snapshot: Array = []
	for layer in _layers:
		snapshot.append(layer["image"].duplicate())
	_undo_stack.append(snapshot)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_dirty = true

func _undo() -> void:
	if _undo_stack.is_empty():
		return
	# Save current to redo
	var current: Array = []
	for layer in _layers:
		current.append(layer["image"].duplicate())
	_redo_stack.append(current)
	# Restore
	var snapshot: Array = _undo_stack.pop_back()
	for i in range(mini(snapshot.size(), _layers.size())):
		_layers[i]["image"] = snapshot[i]
	_sync_frame_from_layers()
	_refresh_canvas()

func _redo() -> void:
	if _redo_stack.is_empty():
		return
	var current: Array = []
	for layer in _layers:
		current.append(layer["image"].duplicate())
	_undo_stack.append(current)
	var snapshot: Array = _redo_stack.pop_back()
	for i in range(mini(snapshot.size(), _layers.size())):
		_layers[i]["image"] = snapshot[i]
	_sync_frame_from_layers()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# LAYERS
# ─────────────────────────────────────────────────────────────────────────────
func _on_layer_selected(idx: int) -> void:
	_active_layer_idx = idx

func _add_layer() -> void:
	var img := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var new_name := "Layer " + str(_layers.size() + 1)
	_layers.insert(0, { "name": new_name, "image": img, "visible": true, "opacity": 1.0 })
	_active_layer_idx = 0
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

func _delete_layer() -> void:
	if _layers.size() <= 1:
		return
	_push_undo()
	_layers.remove_at(_active_layer_idx)
	_active_layer_idx = clampi(_active_layer_idx, 0, _layers.size() - 1)
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

func _move_layer_up() -> void:
	if _active_layer_idx <= 0:
		return
	var tmp: Dictionary = _layers[_active_layer_idx]
	_layers[_active_layer_idx] = _layers[_active_layer_idx - 1]
	_layers[_active_layer_idx - 1] = tmp
	_active_layer_idx -= 1
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

func _move_layer_down() -> void:
	if _active_layer_idx >= _layers.size() - 1:
		return
	var tmp: Dictionary = _layers[_active_layer_idx]
	_layers[_active_layer_idx] = _layers[_active_layer_idx + 1]
	_layers[_active_layer_idx + 1] = tmp
	_active_layer_idx += 1
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

func _toggle_layer_visibility() -> void:
	if _active_layer_idx < 0 or _active_layer_idx >= _layers.size():
		return
	_layers[_active_layer_idx]["visible"] = not _layers[_active_layer_idx]["visible"]
	_refresh_layer_list()
	_refresh_canvas()

func _merge_layer_down() -> void:
	if _active_layer_idx >= _layers.size() - 1:
		return
	_push_undo()
	var top_img: Image = _layers[_active_layer_idx]["image"]
	var bot_img: Image = _layers[_active_layer_idx + 1]["image"]
	bot_img.blend_rect(top_img, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
	_layers.remove_at(_active_layer_idx)
	_active_layer_idx = clampi(_active_layer_idx, 0, _layers.size() - 1)
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

func _refresh_layer_list() -> void:
	if not is_instance_valid(_layer_list):
		return
	_layer_list.clear()
	for i in range(_layers.size()):
		var layer: Dictionary = _layers[i]
		var vis_icon := "👁" if layer["visible"] else "  "
		_layer_list.add_item(vis_icon + " " + layer["name"])
	if _active_layer_idx >= 0 and _active_layer_idx < _layer_list.item_count:
		_layer_list.select(_active_layer_idx)

func _sync_frame_from_layers() -> void:
	## Keep current frame's layer array in sync with _layers.
	if _active_frame_idx >= 0 and _active_frame_idx < _frames.size():
		var images: Array = []
		for layer in _layers:
			images.append(layer["image"])
		_frames[_active_frame_idx]["layers"] = images

# ─────────────────────────────────────────────────────────────────────────────
# FRAMES
# ─────────────────────────────────────────────────────────────────────────────
func _switch_to_frame(idx: int) -> void:
	if idx < 0 or idx >= _frames.size():
		return
	# Save current layers into current frame
	_sync_frame_from_layers()
	# Switch
	_active_frame_idx = idx
	var frame: Dictionary = _frames[idx]
	var frame_layers: Array = frame["layers"]
	# Rebuild _layers from frame
	_layers.clear()
	for i in range(frame_layers.size()):
		_layers.append({
			"name": "Layer " + str(i + 1),
			"image": frame_layers[i],
			"visible": true,
			"opacity": 1.0,
		})
	_active_layer_idx = 0
	_refresh_layer_list()
	_refresh_frame_strip()
	_refresh_canvas()

func _add_frame() -> void:
	_sync_frame_from_layers()
	var new_layers: Array = []
	for layer in _layers:
		var img := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		new_layers.append(img)
	_frames.append({ "layers": new_layers, "duration": 1.0 / _fps })
	_switch_to_frame(_frames.size() - 1)

func _duplicate_frame() -> void:
	_sync_frame_from_layers()
	var source: Dictionary = _frames[_active_frame_idx]
	var new_layers: Array = []
	for img in source["layers"]:
		new_layers.append(img.duplicate())
	_frames.insert(_active_frame_idx + 1, { "layers": new_layers, "duration": source["duration"] })
	_switch_to_frame(_active_frame_idx + 1)

func _delete_frame() -> void:
	if _frames.size() <= 1:
		return
	_frames.remove_at(_active_frame_idx)
	_active_frame_idx = clampi(_active_frame_idx, 0, _frames.size() - 1)
	_switch_to_frame(_active_frame_idx)

func _refresh_frame_strip() -> void:
	if not is_instance_valid(_frame_strip):
		return
	for c in _frame_strip.get_children():
		c.queue_free()
	for i in range(_frames.size()):
		var thumb := _create_frame_thumbnail(i)
		_frame_strip.add_child(thumb)

func _create_frame_thumbnail(frame_idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.toggle_mode = true
	btn.button_pressed = (frame_idx == _active_frame_idx)
	btn.tooltip_text = "Frame " + str(frame_idx + 1)

	# Style
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.18, 0.22)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.3, 0.3, 0.35)
	normal.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.30, 0.45)
	pressed.set_border_width_all(2)
	pressed.border_color = Color(0.4, 0.6, 1.0)
	pressed.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Thumbnail image
	var img := _composite_frame(frame_idx)
	var tex := ImageTexture.create_from_image(img)
	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.custom_minimum_size = Vector2(40, 40)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex_rect)

	var idx := frame_idx
	btn.pressed.connect(func(): _switch_to_frame(idx))
	return btn

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION PREVIEW
# ─────────────────────────────────────────────────────────────────────────────
func _toggle_play() -> void:
	_playing = not _playing
	if is_instance_valid(_play_btn):
		_play_btn.text = "⏸" if _playing else "▶"
	if _playing:
		_play_timer = 0.0
		_preview_frame_idx = _active_frame_idx

func _refresh_preview() -> void:
	if not is_instance_valid(_preview_rect):
		return
	var idx := _preview_frame_idx if _playing else _active_frame_idx
	if idx < 0 or idx >= _frames.size():
		return
	var img := _composite_frame(idx)
	_preview_texture = ImageTexture.create_from_image(img)
	_preview_rect.texture = _preview_texture

func _process(delta: float) -> void:
	if not visible:
		return
	if _playing and _frames.size() > 1:
		_play_timer += delta
		var frame_duration := 1.0 / _fps
		if _play_timer >= frame_duration:
			_play_timer -= frame_duration
			_preview_frame_idx = (_preview_frame_idx + 1) % _frames.size()
			_refresh_preview()

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE OPERATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _flip_image(h: bool, v: bool) -> void:
	_push_undo()
	var img := _get_active_image()
	if img == null:
		return
	if h:
		img.flip_x()
	if v:
		img.flip_y()
	_sync_frame_from_layers()
	_refresh_canvas()

func _rotate_90() -> void:
	_push_undo()
	var img := _get_active_image()
	if img == null:
		return
	img.rotate_90(CLOCKWISE)
	# If non-square, swap canvas dimensions
	if _canvas_size.x != _canvas_size.y:
		_canvas_size = Vector2i(_canvas_size.y, _canvas_size.x)
		_update_size_label()
	_sync_frame_from_layers()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# FILE OPERATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _save() -> void:
	if _file_path.is_empty():
		_show_export_dialog()
		return
	var img := _composite_layers()
	img.save_png(_file_path)
	_dirty = false
	sprite_saved.emit(_file_path)
	_update_status()
	print("[VG Sprite Editor] Saved: ", _file_path)

func _show_new_dialog() -> void:
	if is_instance_valid(_new_dialog):
		_new_dialog.queue_free()

	_new_dialog = AcceptDialog.new()
	_new_dialog.title = "New Sprite"
	_new_dialog.size = Vector2i(320, 280)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Select a preset size or enter custom dimensions:"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(lbl)

	var preset_option := OptionButton.new()
	preset_option.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	var preset_idx := 0
	for pname in PRESET_SIZES:
		preset_option.add_item(pname)
		preset_idx += 1
	vbox.add_child(preset_option)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	vbox.add_child(size_row)

	var w_lbl := Label.new()
	w_lbl.text = "W:"
	w_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_row.add_child(w_lbl)
	var w_spin := SpinBox.new()
	w_spin.min_value = 1
	w_spin.max_value = 512
	w_spin.value = 32
	w_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	size_row.add_child(w_spin)

	var h_lbl := Label.new()
	h_lbl.text = "H:"
	h_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_row.add_child(h_lbl)
	var h_spin := SpinBox.new()
	h_spin.min_value = 1
	h_spin.max_value = 512
	h_spin.value = 32
	h_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	size_row.add_child(h_spin)

	# Wire preset → spinboxes
	preset_option.item_selected.connect(func(i):
		var pname: String = preset_option.get_item_text(i)
		if pname in PRESET_SIZES:
			var sz: Vector2i = PRESET_SIZES[pname]
			w_spin.value = sz.x
			h_spin.value = sz.y
	)

	_new_dialog.confirmed.connect(func():
		var new_size := Vector2i(int(w_spin.value), int(h_spin.value))
		_canvas_size = new_size
		_zoom = DEFAULT_ZOOM
		_pan_offset = Vector2.ZERO
		_init_blank_sprite()
		_refresh_layer_list()
		_refresh_frame_strip()
		_refresh_canvas()
		_update_size_label()
		_file_path = ""
		_update_status()
	)

	add_child(_new_dialog)
	_new_dialog.popup_centered()

func _show_open_dialog() -> void:
	if is_instance_valid(_open_dialog):
		_open_dialog.queue_free()
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.filters = PackedStringArray(["*.png;PNG Image", "*.webp;WebP Image", "*.bmp;BMP Image"])
	_open_dialog.title = "Open Image"
	_open_dialog.size = Vector2i(600, 400)
	_open_dialog.file_selected.connect(_on_open_file)
	add_child(_open_dialog)
	_open_dialog.popup_centered()


## Public: open an image file directly (called by host plugin for double-click, AGCK, etc.)
func open_file(path: String) -> void:
	_on_open_file(path)


func _on_open_file(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("[VG Sprite Editor] Could not load: " + path)
		return
	_canvas_size = Vector2i(img.get_width(), img.get_height())
	img.convert(Image.FORMAT_RGBA8)
	_layers = [{ "name": "Layer 1", "image": img, "visible": true, "opacity": 1.0 }]
	_active_layer_idx = 0
	_frames = [{ "layers": [img.duplicate()], "duration": 1.0 / _fps }]
	_active_frame_idx = 0
	_undo_stack.clear()
	_redo_stack.clear()
	_file_path = path
	_dirty = false
	_zoom = clampf(min(400.0 / _canvas_size.x, 400.0 / _canvas_size.y), MIN_ZOOM, MAX_ZOOM)
	_pan_offset = Vector2.ZERO
	_refresh_layer_list()
	_refresh_frame_strip()
	_refresh_canvas()
	_update_size_label()
	_update_zoom_label()
	_update_status()
	print("[VG Sprite Editor] Opened: ", path, "  size=", _canvas_size)

func _show_export_dialog() -> void:
	if is_instance_valid(_export_dialog):
		_export_dialog.queue_free()
	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_RESOURCES
	_export_dialog.filters = PackedStringArray([
		"*.png;PNG Image",
		"*.png;Spritesheet (horizontal strip)",
	])
	_export_dialog.title = "Export Sprite"
	_export_dialog.size = Vector2i(600, 400)
	if not _file_path.is_empty():
		_export_dialog.current_path = _file_path
	else:
		_export_dialog.current_file = "sprite.png"
	_export_dialog.file_selected.connect(_on_export_file)
	add_child(_export_dialog)
	_export_dialog.popup_centered()

func _on_export_file(path: String) -> void:
	if _frames.size() <= 1:
		# Single frame — export composited image
		var img := _composite_layers()
		img.save_png(path)
	else:
		# Multiple frames — export as horizontal spritesheet
		var sheet_w := _canvas_size.x * _frames.size()
		var sheet := Image.create(sheet_w, _canvas_size.y, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0, 0))
		for i in range(_frames.size()):
			var frame_img := _composite_frame(i)
			sheet.blit_rect(frame_img, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i(i * _canvas_size.x, 0))
		sheet.save_png(path)
	_file_path = path
	_dirty = false
	sprite_saved.emit(path)
	_update_status()
	print("[VG Sprite Editor] Exported: ", path, "  frames=", _frames.size())

func _show_resize_dialog() -> void:
	if is_instance_valid(_new_dialog):
		_new_dialog.queue_free()
	_new_dialog = AcceptDialog.new()
	_new_dialog.title = "Resize Canvas"
	_new_dialog.size = Vector2i(280, 180)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Current: " + str(_canvas_size.x) + "×" + str(_canvas_size.y)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var w_lbl := Label.new()
	w_lbl.text = "W:"
	w_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(w_lbl)
	var w_spin := SpinBox.new()
	w_spin.min_value = 1
	w_spin.max_value = 512
	w_spin.value = _canvas_size.x
	w_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(w_spin)
	var h_lbl := Label.new()
	h_lbl.text = "H:"
	h_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(h_lbl)
	var h_spin := SpinBox.new()
	h_spin.min_value = 1
	h_spin.max_value = 512
	h_spin.value = _canvas_size.y
	h_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(h_spin)

	_new_dialog.confirmed.connect(func():
		_push_undo()
		var new_size := Vector2i(int(w_spin.value), int(h_spin.value))
		_resize_canvas(new_size)
	)
	add_child(_new_dialog)
	_new_dialog.popup_centered()

func _resize_canvas(new_size: Vector2i) -> void:
	for layer in _layers:
		var old_img: Image = layer["image"]
		var new_img := Image.create(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
		new_img.fill(Color(0, 0, 0, 0))
		var copy_w := mini(old_img.get_width(), new_size.x)
		var copy_h := mini(old_img.get_height(), new_size.y)
		new_img.blit_rect(old_img, Rect2i(0, 0, copy_w, copy_h), Vector2i.ZERO)
		layer["image"] = new_img
	_canvas_size = new_size
	_sync_frame_from_layers()
	_refresh_canvas()
	_update_size_label()

# ─────────────────────────────────────────────────────────────────────────────
# KEYBOARD SHORTCUTS
# ─────────────────────────────────────────────────────────────────────────────
func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed:
		if ev.ctrl_pressed:
			match ev.keycode:
				KEY_Z: _undo()
				KEY_Y: _redo()
				KEY_S: _save()
				KEY_N: _show_new_dialog()
				KEY_O: _show_open_dialog()
				KEY_E: _show_export_dialog()
				KEY_A:  # Select all
					_has_selection = true
					_selection_rect = Rect2i(0, 0, _canvas_size.x, _canvas_size.y)
					_selection_offset = Vector2i.ZERO
					_refresh_canvas()
		else:
			match ev.keycode:
				KEY_P: _select_tool(Tool.PEN)
				KEY_E: _select_tool(Tool.ERASER)
				KEY_L: _select_tool(Tool.LINE)
				KEY_R:
					if ev.shift_pressed:
						_select_tool(Tool.RECT_FILLED)
					else:
						_select_tool(Tool.RECT)
				KEY_O:
					if ev.shift_pressed:
						_select_tool(Tool.ELLIPSE_FILLED)
					else:
						_select_tool(Tool.ELLIPSE)
				KEY_G: _select_tool(Tool.FILL)
				KEY_I: _select_tool(Tool.COLOR_PICKER)
				KEY_S: _select_tool(Tool.SELECT)
				KEY_M: _select_tool(Tool.MOVE)
				KEY_H: _select_tool(Tool.MIRROR_PEN)
				KEY_D: _select_tool(Tool.DITHER_PEN)
				KEY_U: _select_tool(Tool.LIGHTEN)
				KEY_J: _select_tool(Tool.DARKEN)
				KEY_X: _swap_colors()
				KEY_BRACKETLEFT:
					_pen_size = maxi(_pen_size - 1, 1)
					if is_instance_valid(_pen_size_spin):
						_pen_size_spin.value = _pen_size
				KEY_BRACKETRIGHT:
					_pen_size = mini(_pen_size + 1, 32)
					if is_instance_valid(_pen_size_spin):
						_pen_size_spin.value = _pen_size

# ─────────────────────────────────────────────────────────────────────────────
# STATUS / LABELS
# ─────────────────────────────────────────────────────────────────────────────
func _update_status() -> void:
	if not is_instance_valid(_status_label):
		return
	var tool_names := {
		Tool.PEN: "Pen", Tool.ERASER: "Eraser", Tool.LINE: "Line",
		Tool.RECT: "Rect", Tool.RECT_FILLED: "Filled Rect",
		Tool.ELLIPSE: "Ellipse", Tool.ELLIPSE_FILLED: "Filled Ellipse",
		Tool.FILL: "Fill", Tool.COLOR_PICKER: "Picker", Tool.SELECT: "Select",
		Tool.MOVE: "Move", Tool.MIRROR_PEN: "Mirror", Tool.DITHER_PEN: "Dither",
		Tool.LIGHTEN: "Lighten", Tool.DARKEN: "Darken",
	}
	var parts := []
	if _file_path.is_empty():
		parts.append("New Sprite")
	else:
		parts.append(_file_path.get_file())
	if _dirty:
		parts.append("*")
	parts.append("|  Tool: " + tool_names.get(_current_tool, "?"))
	parts.append("|  Frame " + str(_active_frame_idx + 1) + "/" + str(_frames.size()))
	parts.append("|  Layer: " + (_layers[_active_layer_idx]["name"] if _active_layer_idx < _layers.size() else "?"))
	_status_label.text = "  " + "  ".join(parts)

func _update_size_label() -> void:
	if is_instance_valid(_size_label):
		_size_label.text = str(_canvas_size.x) + "×" + str(_canvas_size.y)

func _update_zoom_label() -> void:
	if is_instance_valid(_zoom_label):
		_zoom_label.text = str(int(_zoom)) + "×"

func _update_pos_label(px: Vector2i) -> void:
	# Show in status bar (appended)
	pass

# ─────────────────────────────────────────────────────────────────────────────
# BUTTON STYLING (matches 2D/3D editor)
# ─────────────────────────────────────────────────────────────────────────────
func _style_tool_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.22, 0.26)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.30, 0.30, 0.36)
	hover.set_corner_radius_all(3)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.28, 0.45)
	pressed.set_corner_radius_all(3)
	pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.85, 1.0))
	btn.add_theme_font_size_override("font_size", 12)

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────
func get_file_path() -> String:
	return _file_path

func is_dirty() -> bool:
	return _dirty

func get_canvas_size() -> Vector2i:
	return _canvas_size

func get_frame_count() -> int:
	return _frames.size()
