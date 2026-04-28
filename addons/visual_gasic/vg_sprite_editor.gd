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

# Plugin id used when announcing events on VGAssetBus / VGContextBroker.
# The editor isn't a real plugin (it lives at the top of addons/visual_gasic/
# rather than under plugins/), but the bus tags every event with the
# originator so listeners — and the registry's "default editor for…"
# preference — can attribute and route events correctly.
const _ASSET_PLUGIN_ID := "sprite_editor"
const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ContextBroker := preload("res://addons/visual_gasic/vg_context_broker.gd")

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
const FREESOUND_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/freesound_browser.gd")
const OPENGAMEART_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/opengameart_browser.gd")
const KENNEY_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/kenney_browser.gd")

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
	MAGIC_WAND,
	OUTLINE,
	GRADIENT,
	LASSO,
}

# Blend modes for layers
enum BlendMode {
	NORMAL,
	MULTIPLY,
	SCREEN,
	OVERLAY,
	ADD,
	SUBTRACT,
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
var _clipboard_image: Image = null  ## copy/paste clipboard

# Feature toggles
var _pixel_grid_enabled := true       ## show pixel grid at high zoom
var _contiguous_fill := true          ## fill only contiguous region
var _checker_bg_enabled := true       ## show checkerboard transparency bg
var _ink_opacity := 1.0               ## pen opacity (0.0 – 1.0)
var _tiled_preview := false           ## show tiled/wrapping preview

# Lasso selection
var _lasso_points: Array[Vector2i] = []  ## polygon vertices for lasso
var _lasso_drawing := false

# Brush stamp (custom brush from selection)
var _brush_stamp: Image = null

# Animation tags  { "name": String, "from": int, "to": int, "color": Color }
var _animation_tags: Array = []

# Reference layer (non-exportable background reference image)
var _reference_image: Image = null
var _reference_visible := false
var _reference_opacity := 0.4

# Custom (downloaded/imported) palettes — persisted to disk
const CUSTOM_PALETTES_PATH := "user://vg_custom_palettes.json"
var _custom_palettes: Dictionary = {}  ## name → Array of "#RRGGBB"
var _palette_remove_btn: Button = null

# Lospec palette browser
var _lospec_http: HTTPRequest = null
var _lospec_dialog: AcceptDialog = null
var _lospec_results_box: VBoxContainer = null  ## scroll container child
var _lospec_search_edit: LineEdit = null
var _lospec_sort_option: OptionButton = null
var _lospec_page := 0
var _lospec_palettes: Array = []  ## cached API response palette dicts
var _lospec_total := 0
var _lospec_selected_index := -1
var _lospec_selected_row: PanelContainer = null
var _lospec_page_label: Label = null
var _freesound_browser: RefCounted = null
var _opengameart_browser: RefCounted = null
var _kenney_browser: RefCounted = null

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

var _pixel_grid_btn: CheckButton = null
var _checker_bg_btn: CheckButton = null
var _contiguous_fill_btn: CheckButton = null
var _ink_opacity_slider: HSlider = null
var _ink_opacity_label: Label = null
var _tiled_preview_btn: CheckButton = null

# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_blank_sprite()
	_build_ui()

func _init_blank_sprite() -> void:
	var img := Image.create(_canvas_size.x, _canvas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_layers = [{ "name": "Layer 1", "image": img, "visible": true, "opacity": 1.0, "locked": false, "blend_mode": BlendMode.NORMAL }]
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
		[Tool.MAGIC_WAND,     "🪄", "Magic Wand (W)"],
		[Tool.OUTLINE,        "🔲", "Outline (Shift+L)"],
		[Tool.GRADIENT,       "🌈", "Gradient (Shift+G)"],
		[Tool.LASSO,          "⛏",  "Lasso Select (Shift+S)"],
	]

	for def in tool_defs:
		var btn := Button.new()
		btn.text = def[1]
		btn.tooltip_text = def[2]
		btn.custom_minimum_size = Vector2(48, 40)
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

	# ── Option toggles ──
	var opts_row1 := HBoxContainer.new()
	opts_row1.add_theme_constant_override("separation", 4)
	parent.add_child(opts_row1)
	_pixel_grid_btn = CheckButton.new()
	_pixel_grid_btn.text = "Grid"
	_pixel_grid_btn.button_pressed = _pixel_grid_enabled
	_pixel_grid_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_pixel_grid_btn.add_theme_font_size_override("font_size", 10)
	_pixel_grid_btn.toggled.connect(func(v): _pixel_grid_enabled = v; _refresh_canvas())
	opts_row1.add_child(_pixel_grid_btn)
	_checker_bg_btn = CheckButton.new()
	_checker_bg_btn.text = "Checker"
	_checker_bg_btn.button_pressed = _checker_bg_enabled
	_checker_bg_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_checker_bg_btn.add_theme_font_size_override("font_size", 10)
	_checker_bg_btn.toggled.connect(func(v): _checker_bg_enabled = v; _refresh_canvas())
	opts_row1.add_child(_checker_bg_btn)

	var opts_row2 := HBoxContainer.new()
	opts_row2.add_theme_constant_override("separation", 4)
	parent.add_child(opts_row2)
	_contiguous_fill_btn = CheckButton.new()
	_contiguous_fill_btn.text = "Contig Fill"
	_contiguous_fill_btn.button_pressed = _contiguous_fill
	_contiguous_fill_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_contiguous_fill_btn.add_theme_font_size_override("font_size", 10)
	_contiguous_fill_btn.toggled.connect(func(v): _contiguous_fill = v)
	opts_row2.add_child(_contiguous_fill_btn)
	_tiled_preview_btn = CheckButton.new()
	_tiled_preview_btn.text = "Tiled"
	_tiled_preview_btn.button_pressed = _tiled_preview
	_tiled_preview_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_tiled_preview_btn.add_theme_font_size_override("font_size", 10)
	_tiled_preview_btn.toggled.connect(func(v): _tiled_preview = v; _refresh_canvas())
	opts_row2.add_child(_tiled_preview_btn)

	# Ink opacity slider
	var opacity_row := HBoxContainer.new()
	opacity_row.add_theme_constant_override("separation", 4)
	parent.add_child(opacity_row)
	var op_lbl := Label.new()
	op_lbl.text = "Ink:"
	op_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	op_lbl.add_theme_font_size_override("font_size", 11)
	opacity_row.add_child(op_lbl)
	_ink_opacity_slider = HSlider.new()
	_ink_opacity_slider.min_value = 0.0
	_ink_opacity_slider.max_value = 1.0
	_ink_opacity_slider.step = 0.05
	_ink_opacity_slider.value = _ink_opacity
	_ink_opacity_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_ink_opacity_slider.custom_minimum_size = Vector2(60, 0)
	_ink_opacity_slider.value_changed.connect(func(v):
		_ink_opacity = v
		if is_instance_valid(_ink_opacity_label):
			_ink_opacity_label.text = str(int(v * 100)) + "%"
	)
	opacity_row.add_child(_ink_opacity_slider)
	_ink_opacity_label = Label.new()
	_ink_opacity_label.text = "100%"
	_ink_opacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_ink_opacity_label.add_theme_font_size_override("font_size", 10)
	opacity_row.add_child(_ink_opacity_label)

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

	# HSV Picker + Color Ramp buttons
	var color_btn_row := HBoxContainer.new()
	color_btn_row.add_theme_constant_override("separation", 4)
	parent.add_child(color_btn_row)
	var hsv_btn := Button.new()
	hsv_btn.text = "🎨 HSV"
	hsv_btn.tooltip_text = "Open HSV Color Picker"
	hsv_btn.add_theme_font_size_override("font_size", 10)
	hsv_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	hsv_btn.pressed.connect(_show_hsv_picker)
	color_btn_row.add_child(hsv_btn)
	var ramp_btn := Button.new()
	ramp_btn.text = "🌈 Ramp"
	ramp_btn.tooltip_text = "Generate Color Ramp"
	ramp_btn.add_theme_font_size_override("font_size", 10)
	ramp_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	ramp_btn.pressed.connect(_show_color_ramp_dialog)
	color_btn_row.add_child(ramp_btn)

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

	# Load custom palettes from disk
	_load_custom_palettes()

	# Palette dropdown row with remove button
	var pal_select_row := HBoxContainer.new()
	pal_select_row.add_theme_constant_override("separation", 4)
	parent.add_child(pal_select_row)

	_palette_option = OptionButton.new()
	_palette_option.add_theme_font_size_override("font_size", 11)
	_palette_option.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_palette_option.size_flags_horizontal = SIZE_EXPAND_FILL
	var idx := 0
	for pname in PALETTES:
		_palette_option.add_item(pname)
		if pname == "NES":
			_palette_option.selected = idx
		idx += 1
	# Add custom palettes after built-ins (with ★ prefix)
	for cname in _custom_palettes:
		_palette_option.add_item("★ " + cname)
	_palette_option.item_selected.connect(func(i): _load_palette(_palette_option.get_item_text(i)); _update_remove_btn_state())
	pal_select_row.add_child(_palette_option)

	_palette_remove_btn = Button.new()
	_palette_remove_btn.text = "🗑️"
	_palette_remove_btn.tooltip_text = "Remove this custom palette"
	_palette_remove_btn.add_theme_font_size_override("font_size", 11)
	_palette_remove_btn.disabled = true
	_palette_remove_btn.pressed.connect(_on_remove_palette_pressed)
	pal_select_row.add_child(_palette_remove_btn)

	# Import / Export palette buttons
	var pal_btn_row := HBoxContainer.new()
	pal_btn_row.add_theme_constant_override("separation", 4)
	parent.add_child(pal_btn_row)
	var btn_import_pal := Button.new()
	btn_import_pal.text = "📂 Import Palette"
	btn_import_pal.tooltip_text = "Import palette from .gpl, .hex, or .pal file"
	btn_import_pal.add_theme_font_size_override("font_size", 10)
	btn_import_pal.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_import_pal.pressed.connect(_on_import_palette_pressed)
	pal_btn_row.add_child(btn_import_pal)
	var btn_export_pal := Button.new()
	btn_export_pal.text = "💾 Export Palette"
	btn_export_pal.tooltip_text = "Export current palette as .gpl file"
	btn_export_pal.add_theme_font_size_override("font_size", 10)
	btn_export_pal.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_export_pal.pressed.connect(_on_export_palette_pressed)
	pal_btn_row.add_child(btn_export_pal)

	# Lospec browse button
	var lospec_btn_row := HBoxContainer.new()
	lospec_btn_row.add_theme_constant_override("separation", 4)
	parent.add_child(lospec_btn_row)
	var btn_lospec := Button.new()
	btn_lospec.text = "🌐 Browse Lospec (4000+ palettes)"
	btn_lospec.tooltip_text = "Browse and install palettes from lospec.com"
	btn_lospec.add_theme_font_size_override("font_size", 10)
	btn_lospec.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_lospec.pressed.connect(_show_lospec_browser)
	lospec_btn_row.add_child(btn_lospec)

	# Asset browser buttons
	var asset_btn_row := HBoxContainer.new()
	asset_btn_row.add_theme_constant_override("separation", 4)
	parent.add_child(asset_btn_row)
	var btn_freesound := Button.new()
	btn_freesound.text = "🔊 Freesound"
	btn_freesound.tooltip_text = "Browse & download free sounds from Freesound.org"
	btn_freesound.add_theme_font_size_override("font_size", 10)
	btn_freesound.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_freesound.pressed.connect(func():
		_freesound_browser = FREESOUND_BROWSER_SCRIPT.new()
		_freesound_browser.open(self, false)
	)
	asset_btn_row.add_child(btn_freesound)
	var btn_oga := Button.new()
	btn_oga.text = "🎨 OpenGameArt"
	btn_oga.tooltip_text = "Browse free game art from OpenGameArt.org"
	btn_oga.add_theme_font_size_override("font_size", 10)
	btn_oga.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_oga.pressed.connect(func():
		_opengameart_browser = OPENGAMEART_BROWSER_SCRIPT.new()
		_opengameart_browser.open(self, false)
	)
	asset_btn_row.add_child(btn_oga)
	var btn_kenney := Button.new()
	btn_kenney.text = "📦 Kenney"
	btn_kenney.tooltip_text = "Browse free CC0 assets from Kenney.nl"
	btn_kenney.add_theme_font_size_override("font_size", 10)
	btn_kenney.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_kenney.pressed.connect(func():
		_kenney_browser = KENNEY_BROWSER_SCRIPT.new()
		_kenney_browser.open(self, false)
	)
	asset_btn_row.add_child(btn_kenney)

	_palette_grid = GridContainer.new()
	_palette_grid.columns = 8
	_palette_grid.add_theme_constant_override("h_separation", 1)
	_palette_grid.add_theme_constant_override("v_separation", 1)
	parent.add_child(_palette_grid)

func _load_palette(palette_name: String) -> void:
	# Clear existing
	for c in _palette_grid.get_children():
		c.queue_free()

	var colors: Array = []
	if palette_name in PALETTES:
		colors = PALETTES[palette_name]
	elif palette_name.begins_with("★ "):
		var cname := palette_name.substr(2)
		if cname in _custom_palettes:
			colors = _custom_palettes[cname]
	else:
		return
	if colors.is_empty():
		return
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

func _on_import_palette_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.title = "Import Palette"
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.gpl ; GIMP Palette", "*.hex ; Hex Color List", "*.pal ; Paint.NET Palette", "*.txt ; Text Palette"])
	dlg.size = Vector2i(600, 400)
	dlg.file_selected.connect(func(path: String):
		var colors := _parse_palette_file(path)
		if colors.size() > 0:
			var pal_name := path.get_file().get_basename()
			_load_palette_from_colors(colors, pal_name)
			_add_custom_palette(pal_name, colors)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func _on_export_palette_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.title = "Export Palette as GPL"
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.gpl ; GIMP Palette"])
	dlg.size = Vector2i(600, 400)
	dlg.file_selected.connect(func(path: String):
		_export_palette_gpl(path)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func _parse_palette_file(path: String) -> Array:
	## Parse .gpl, .hex, .pal, or .txt palette files → Array of "#RRGGBB" strings
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		push_warning("VG SpriteEditor: Cannot open palette file: " + path)
		return []
	var text := fa.get_as_text()
	fa.close()
	var colors: Array = []
	var ext := path.get_extension().to_lower()

	if ext == "gpl":
		# GIMP Palette: skip header lines, parse "R G B" or "R G B\tName"
		for line in text.split("\n"):
			line = line.strip_edges()
			if line.begins_with("GIMP Palette") or line.begins_with("Name:") or line.begins_with("Columns:") or line.begins_with("#") or line.is_empty():
				continue
			var parts := line.split("\t")[0].strip_edges()  # drop optional name
			var nums := parts.split(" ", false)
			if nums.size() >= 3:
				var r := nums[0].to_int()
				var g := nums[1].to_int()
				var b := nums[2].to_int()
				colors.append("#%02X%02X%02X" % [r, g, b])
	elif ext == "hex":
		# One hex color per line: "RRGGBB" or "#RRGGBB"
		for line in text.split("\n"):
			line = line.strip_edges()
			if line.is_empty() or line.begins_with(";"):
				continue
			if not line.begins_with("#"):
				line = "#" + line
			if line.length() >= 7:
				colors.append(line.substr(0, 7))
	elif ext == "pal":
		# Paint.NET / JASC palette: skip header, parse "R G B" lines
		var lines := text.split("\n")
		var start := 0
		for i in range(lines.size()):
			if lines[i].strip_edges().is_valid_int() and i > 0:
				start = i + 1
				break
		for i in range(start, lines.size()):
			var nums := lines[i].strip_edges().split(" ", false)
			if nums.size() >= 3:
				var r := nums[0].to_int()
				var g := nums[1].to_int()
				var b := nums[2].to_int()
				colors.append("#%02X%02X%02X" % [r, g, b])
	else:
		# Generic: try to find hex colors or R G B lines
		for line in text.split("\n"):
			line = line.strip_edges()
			if line.is_empty():
				continue
			if line.begins_with("#") and line.length() >= 7:
				colors.append(line.substr(0, 7))
			elif line.begins_with("0x") and line.length() >= 8:
				colors.append("#" + line.substr(2, 6))

	return colors

func _load_palette_from_colors(colors: Array, name: String) -> void:
	## Load an array of "#RRGGBB" strings into the palette grid
	for c in _palette_grid.get_children():
		c.queue_free()
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
	print("VG SpriteEditor: Loaded palette '%s' with %d colors" % [name, colors.size()])

func _export_palette_gpl(path: String) -> void:
	## Export current palette swatches as a GIMP .gpl file
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		push_warning("VG SpriteEditor: Cannot write to: " + path)
		return
	fa.store_line("GIMP Palette")
	fa.store_line("Name: " + path.get_file().get_basename())
	fa.store_line("Columns: 8")
	fa.store_line("#")
	for child in _palette_grid.get_children():
		if child is ColorRect:
			var cr: ColorRect = child as ColorRect
			var c: Color = cr.color
			var r := int(c.r * 255)
			var g := int(c.g * 255)
			var b := int(c.b * 255)
			fa.store_line("%3d %3d %3d\tColor" % [r, g, b])
	fa.close()
	print("VG SpriteEditor: Exported palette to " + path)

# ─────────────────────────────────────────────────────────────────────────────
# LOSPEC PALETTE BROWSER
# ─────────────────────────────────────────────────────────────────────────────
func _show_lospec_browser() -> void:
	## Open the Lospec palette browser dialog — recreate each time (matches other dialogs)
	if _lospec_dialog != null and is_instance_valid(_lospec_dialog):
		_lospec_dialog.queue_free()
		_lospec_dialog = null

	# Build dialog — simple pattern like every other working dialog
	_lospec_dialog = AcceptDialog.new()
	_lospec_dialog.title = "🌐 Browse Lospec Palettes"
	_lospec_dialog.min_size = Vector2(780, 700)
	_lospec_dialog.ok_button_text = "Close"
	_lospec_dialog.exclusive = true
	_lospec_dialog.popup_window = true
	_lospec_dialog.confirmed.connect(func(): _lospec_dialog.queue_free(); _lospec_dialog = null; _lospec_results_box = null; _lospec_selected_row = null; _lospec_page_label = null)
	_lospec_dialog.canceled.connect(func(): _lospec_dialog.queue_free(); _lospec_dialog = null; _lospec_results_box = null; _lospec_selected_row = null; _lospec_page_label = null)
	add_child(_lospec_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_lospec_dialog.add_child(vbox)

	# Search row
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	vbox.add_child(search_row)

	var lbl_search := Label.new()
	lbl_search.text = "Tag:"
	lbl_search.add_theme_font_size_override("font_size", 13)
	lbl_search.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	search_row.add_child(lbl_search)

	_lospec_search_edit = LineEdit.new()
	_lospec_search_edit.placeholder_text = "e.g. gameboy, retro, fantasy..."
	_lospec_search_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_lospec_search_edit.add_theme_font_size_override("font_size", 13)
	search_row.add_child(_lospec_search_edit)

	var lbl_sort := Label.new()
	lbl_sort.text = "Sort:"
	lbl_sort.add_theme_font_size_override("font_size", 13)
	lbl_sort.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	search_row.add_child(lbl_sort)

	_lospec_sort_option = OptionButton.new()
	_lospec_sort_option.add_theme_font_size_override("font_size", 13)
	_lospec_sort_option.add_item("Popular", 0)
	_lospec_sort_option.add_item("Newest", 1)
	_lospec_sort_option.add_item("Default", 2)
	search_row.add_child(_lospec_sort_option)

	var btn_search := Button.new()
	btn_search.text = "🔍 Search"
	btn_search.add_theme_font_size_override("font_size", 13)
	btn_search.pressed.connect(_lospec_do_search.bind(0))
	search_row.add_child(btn_search)

	_lospec_search_edit.text_submitted.connect(func(_t): _lospec_do_search(0))

	# Scrollable results area — use a Panel inside the scroll so bg covers full viewport
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 480)
	vbox.add_child(scroll)

	# PanelContainer as the single scroll child — its bg fills the entire scroll viewport
	var scroll_inner_panel := PanelContainer.new()
	scroll_inner_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var scroll_inner_bg := StyleBoxFlat.new()
	scroll_inner_bg.bg_color = Color(0.14, 0.14, 0.18, 1.0)
	scroll_inner_bg.set_corner_radius_all(4)
	scroll_inner_bg.set_content_margin_all(4)
	scroll_inner_panel.add_theme_stylebox_override("panel", scroll_inner_bg)
	scroll.add_child(scroll_inner_panel)

	_lospec_results_box = VBoxContainer.new()
	_lospec_results_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_lospec_results_box.add_theme_constant_override("separation", 4)
	scroll_inner_panel.add_child(_lospec_results_box)

	# Page info label — outside scroll so always visible
	_lospec_page_label = Label.new()
	_lospec_page_label.text = ""
	_lospec_page_label.add_theme_font_size_override("font_size", 13)
	_lospec_page_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	_lospec_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_lospec_page_label)

	# Bottom row: page nav + install button
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom_row)

	var btn_prev := Button.new()
	btn_prev.text = "◀ Prev"
	btn_prev.add_theme_font_size_override("font_size", 13)
	btn_prev.pressed.connect(_lospec_prev_page)
	bottom_row.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "Next ▶"
	btn_next.add_theme_font_size_override("font_size", 13)
	btn_next.pressed.connect(_lospec_next_page)
	bottom_row.add_child(btn_next)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

	var btn_install := Button.new()
	btn_install.text = "✅ Install Selected Palette"
	btn_install.add_theme_font_size_override("font_size", 13)
	btn_install.pressed.connect(_on_lospec_install)
	bottom_row.add_child(btn_install)

	# Hint label
	var hint := Label.new()
	hint.text = "Click to select, double-click to install, right-click to open on lospec.com"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

	_lospec_dialog.popup_centered()
	# Auto-search popular on first open
	_lospec_do_search(0)


func _lospec_clear_results() -> void:
	if _lospec_results_box == null:
		return
	for child in _lospec_results_box.get_children():
		child.queue_free()
	_lospec_selected_index = -1
	_lospec_selected_row = null


func _lospec_add_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	_lospec_results_box.add_child(lbl)


func _lospec_do_search(page: int) -> void:
	## Send HTTP request to Lospec API
	_lospec_page = page
	var sort_map := ["downloads", "newest", "default"]
	var sort_idx := _lospec_sort_option.selected if _lospec_sort_option else 0
	var sort_str: String = sort_map[sort_idx] if sort_idx < sort_map.size() else "downloads"
	var tag: String = _lospec_search_edit.text.strip_edges() if _lospec_search_edit else ""
	var url := "https://lospec.com/palette-list/load?page=%d&tag=%s&sortingType=%s&colorNumberFilterType=any" % [page, tag.uri_encode(), sort_str]
	_lospec_clear_results()
	_lospec_add_message("⏳ Loading palettes from Lospec...")
	# Cancel any pending request and recreate HTTPRequest to reset error state
	if _lospec_http != null and is_instance_valid(_lospec_http):
		_lospec_http.cancel_request()
		_lospec_http.queue_free()
	_lospec_http = HTTPRequest.new()
	_lospec_http.request_completed.connect(_on_lospec_response)
	add_child(_lospec_http)
	var err := _lospec_http.request(url)
	if err != OK:
		_lospec_clear_results()
		_lospec_add_message("❌ HTTP request failed (error %d). Check internet connection and try again." % err)


func _on_lospec_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	## Handle Lospec API response
	if _lospec_results_box == null or not is_instance_valid(_lospec_results_box):
		return
	_lospec_clear_results()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_lospec_add_message("❌ Request failed (HTTP %d)" % response_code)
		return
	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_lospec_add_message("❌ Failed to parse JSON response")
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	_lospec_palettes = data.get("palettes", [])
	_lospec_total = int(data.get("totalCount", data.get("totalPalettes", 0)))
	if _lospec_palettes.is_empty():
		_lospec_add_message("No palettes found. Try a different tag.")
		return
	for i in range(_lospec_palettes.size()):
		var pal: Dictionary = _lospec_palettes[i]
		var title: String = pal.get("title", "Untitled")
		var n_colors: int = int(pal.get("numberOfColors", 0))
		var downloads: String = str(pal.get("downloads", "0"))
		var colors_arr: Array = pal.get("colors", [])
		# Build row: PanelContainer > VBox > [info_row, swatch_row]
		var panel := PanelContainer.new()
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0.19, 0.20, 0.25, 1.0)
		style_normal.set_corner_radius_all(4)
		style_normal.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style_normal)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i  # capture
		panel.gui_input.connect(_lospec_row_input.bind(idx, panel))
		_lospec_results_box.add_child(panel)
		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 3)
		row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row_vbox)
		# Info label
		var info_lbl := Label.new()
		info_lbl.text = "%s  (%d colors)  ⬇%s" % [title, n_colors, downloads]
		info_lbl.add_theme_font_size_override("font_size", 13)
		info_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
		info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(info_lbl)
		# Color swatch row
		var swatch_row := HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 1)
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(swatch_row)
		var max_swatches := mini(colors_arr.size(), 24)
		for ci in range(max_swatches):
			var cr := ColorRect.new()
			cr.custom_minimum_size = Vector2(18, 18)
			cr.color = Color("#" + str(colors_arr[ci]).strip_edges())
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(cr)
		if colors_arr.size() > 24:
			var more_lbl := Label.new()
			more_lbl.text = "+%d" % (colors_arr.size() - 24)
			more_lbl.add_theme_font_size_override("font_size", 10)
			more_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			more_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(more_lbl)
	# Page info footer — update the label outside the scroll
	if _lospec_page_label != null and is_instance_valid(_lospec_page_label):
		_lospec_page_label.text = "— Page %d  |  %d palettes total —" % [_lospec_page + 1, _lospec_total]


func _lospec_row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	## Handle click/double-click on a palette row
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Right-click → open palette page in default browser
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if index >= 0 and index < _lospec_palettes.size():
			var slug: String = _lospec_palettes[index].get("slug", "")
			if slug != "":
				OS.shell_open("https://lospec.com/palette-list/" + slug)
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Deselect previous
		if _lospec_selected_row != null and is_instance_valid(_lospec_selected_row):
			var old_style := StyleBoxFlat.new()
			old_style.bg_color = Color(0.19, 0.20, 0.25, 1.0)
			old_style.set_corner_radius_all(4)
			old_style.set_content_margin_all(6)
			_lospec_selected_row.add_theme_stylebox_override("panel", old_style)
		# Select this one
		_lospec_selected_index = index
		_lospec_selected_row = panel
		var sel_style := StyleBoxFlat.new()
		sel_style.bg_color = Color(0.22, 0.36, 0.56, 1.0)
		sel_style.set_corner_radius_all(4)
		sel_style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", sel_style)
		# Double-click = install
		if event.double_click:
			_lospec_install_index(index)


func _on_lospec_install() -> void:
	## Install button clicked
	if _lospec_selected_index < 0:
		return
	_lospec_install_index(_lospec_selected_index)


func _lospec_install_index(index: int) -> void:
	## Install a palette from cached Lospec results
	if index < 0 or index >= _lospec_palettes.size():
		return
	var pal: Dictionary = _lospec_palettes[index]
	var title: String = pal.get("title", "Lospec Palette")
	var colors_raw: Array = pal.get("colors", [])
	if colors_raw.is_empty():
		return
	# Convert bare hex to #RRGGBB
	var colors: Array = []
	for hex_str in colors_raw:
		var s: String = str(hex_str).strip_edges()
		if not s.begins_with("#"):
			s = "#" + s
		colors.append(s)
	_load_palette_from_colors(colors, title)
	_add_custom_palette(title, colors)
	print("VG SpriteEditor: Installed Lospec palette '%s' (%d colors)" % [title, colors.size()])


func _lospec_prev_page() -> void:
	if _lospec_page > 0:
		_lospec_do_search(_lospec_page - 1)


func _lospec_next_page() -> void:
	_lospec_do_search(_lospec_page + 1)

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOM PALETTE PERSISTENCE
# ─────────────────────────────────────────────────────────────────────────────
func _load_custom_palettes() -> void:
	## Load custom palettes from user://vg_custom_palettes.json
	_custom_palettes.clear()
	if not FileAccess.file_exists(CUSTOM_PALETTES_PATH):
		return
	var fa := FileAccess.open(CUSTOM_PALETTES_PATH, FileAccess.READ)
	if fa == null:
		return
	var text := fa.get_as_text()
	fa.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("VG SpriteEditor: Failed to parse custom palettes JSON")
		return
	var data = json.data
	if data is Dictionary:
		for key in data:
			if data[key] is Array:
				_custom_palettes[str(key)] = data[key]
	print("VG SpriteEditor: Loaded %d custom palettes" % _custom_palettes.size())


func _save_custom_palettes() -> void:
	## Save custom palettes to user://vg_custom_palettes.json
	var fa := FileAccess.open(CUSTOM_PALETTES_PATH, FileAccess.WRITE)
	if fa == null:
		push_warning("VG SpriteEditor: Cannot write to " + CUSTOM_PALETTES_PATH)
		return
	fa.store_string(JSON.stringify(_custom_palettes, "\t"))
	fa.close()


func _add_custom_palette(pname: String, colors: Array) -> void:
	## Add/update a custom palette, save to disk, update dropdown
	_custom_palettes[pname] = colors
	_save_custom_palettes()
	# Update dropdown — check if already present
	var display_name := "★ " + pname
	var found := false
	for i in range(_palette_option.item_count):
		if _palette_option.get_item_text(i) == display_name:
			_palette_option.selected = i
			found = true
			break
	if not found:
		_palette_option.add_item(display_name)
		_palette_option.selected = _palette_option.item_count - 1
	_update_remove_btn_state()


func _on_remove_palette_pressed() -> void:
	## Remove the currently selected custom palette (with confirmation)
	if _palette_option == null:
		return
	var sel := _palette_option.selected
	if sel < 0:
		return
	var display_name := _palette_option.get_item_text(sel)
	if not display_name.begins_with("★ "):
		return  # built-in, can't remove
	var cname := display_name.substr(2)
	var confirm := ConfirmationDialog.new()
	confirm.title = "Remove Palette"
	confirm.dialog_text = "Remove custom palette '%s'?\nThis cannot be undone." % cname
	confirm.ok_button_text = "Remove"
	confirm.confirmed.connect(func():
		_custom_palettes.erase(cname)
		_save_custom_palettes()
		_palette_option.remove_item(sel)
		if _palette_option.item_count > 0:
			_palette_option.selected = 0
			_load_palette(_palette_option.get_item_text(0))
		_update_remove_btn_state()
		print("VG SpriteEditor: Removed custom palette '%s'" % cname)
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	add_child(confirm)
	confirm.popup_centered()


func _update_remove_btn_state() -> void:
	## Enable remove button only when a custom (★) palette is selected
	if _palette_remove_btn == null or not is_instance_valid(_palette_remove_btn):
		return
	if _palette_option == null or _palette_option.selected < 0:
		_palette_remove_btn.disabled = true
		return
	var name := _palette_option.get_item_text(_palette_option.selected)
	_palette_remove_btn.disabled = not name.begins_with("★ ")


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

	var lock_btn := Button.new()
	lock_btn.text = "🔒"
	lock_btn.tooltip_text = "Toggle Layer Lock"
	lock_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(lock_btn)
	lock_btn.pressed.connect(_toggle_layer_lock)
	btn_row.add_child(lock_btn)

	var flatten_btn := Button.new()
	flatten_btn.text = "≡"
	flatten_btn.tooltip_text = "Flatten All Layers"
	flatten_btn.custom_minimum_size = Vector2(30, 24)
	_style_tool_button(flatten_btn)
	flatten_btn.pressed.connect(_flatten_layers)
	btn_row.add_child(flatten_btn)

	# Blend mode row
	var blend_row := HBoxContainer.new()
	blend_row.add_theme_constant_override("separation", 4)
	parent.add_child(blend_row)
	var blend_lbl := Label.new()
	blend_lbl.text = "Blend:"
	blend_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	blend_lbl.add_theme_font_size_override("font_size", 10)
	blend_row.add_child(blend_lbl)
	var blend_opt := OptionButton.new()
	blend_opt.add_theme_font_size_override("font_size", 10)
	blend_opt.add_item("Normal")
	blend_opt.add_item("Multiply")
	blend_opt.add_item("Screen")
	blend_opt.add_item("Overlay")
	blend_opt.add_item("Add")
	blend_opt.add_item("Subtract")
	blend_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	blend_opt.item_selected.connect(func(i):
		if _active_layer_idx >= 0 and _active_layer_idx < _layers.size():
			_layers[_active_layer_idx]["blend_mode"] = i as BlendMode
			_refresh_canvas()
	)
	blend_row.add_child(blend_opt)

	# Layer opacity slider
	var layer_op_row := HBoxContainer.new()
	layer_op_row.add_theme_constant_override("separation", 4)
	parent.add_child(layer_op_row)
	var lop_lbl := Label.new()
	lop_lbl.text = "Opacity:"
	lop_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lop_lbl.add_theme_font_size_override("font_size", 10)
	layer_op_row.add_child(lop_lbl)
	var lop_slider := HSlider.new()
	lop_slider.min_value = 0.0
	lop_slider.max_value = 1.0
	lop_slider.step = 0.05
	lop_slider.value = 1.0
	lop_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	lop_slider.value_changed.connect(func(v):
		if _active_layer_idx >= 0 and _active_layer_idx < _layers.size():
			_layers[_active_layer_idx]["opacity"] = v
			_refresh_canvas()
	)
	layer_op_row.add_child(lop_slider)

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

	# Outline
	var outline_btn := Button.new()
	outline_btn.text = "🔲 Outline"
	outline_btn.tooltip_text = "Outline non-transparent pixels"
	_style_tool_button(outline_btn)
	outline_btn.pressed.connect(_outline_pixels)
	toolbar.add_child(outline_btn)

	# Replace Color
	var repcol_btn := Button.new()
	repcol_btn.text = "🔄 Replace"
	repcol_btn.tooltip_text = "Replace color (primary→secondary)"
	_style_tool_button(repcol_btn)
	repcol_btn.pressed.connect(_replace_color)
	toolbar.add_child(repcol_btn)

	# Selection transforms
	var sel_flip_h := Button.new()
	sel_flip_h.text = "↔ Sel"
	sel_flip_h.tooltip_text = "Flip Selection Horizontal"
	_style_tool_button(sel_flip_h)
	sel_flip_h.pressed.connect(func(): _transform_selection("flip_h"))
	toolbar.add_child(sel_flip_h)

	var sel_flip_v := Button.new()
	sel_flip_v.text = "↕ Sel"
	sel_flip_v.tooltip_text = "Flip Selection Vertical"
	_style_tool_button(sel_flip_v)
	sel_flip_v.pressed.connect(func(): _transform_selection("flip_v"))
	toolbar.add_child(sel_flip_v)

	var sel_rot := Button.new()
	sel_rot.text = "↻ Sel"
	sel_rot.tooltip_text = "Rotate Selection 90° CW"
	_style_tool_button(sel_rot)
	sel_rot.pressed.connect(func(): _transform_selection("rot90"))
	toolbar.add_child(sel_rot)

	# Reference layer
	var ref_btn := Button.new()
	ref_btn.text = "📎 Ref"
	ref_btn.tooltip_text = "Load Reference Image"
	_style_tool_button(ref_btn)
	ref_btn.pressed.connect(_load_reference_image)
	toolbar.add_child(ref_btn)

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

	var dur_btn := Button.new()
	dur_btn.text = "⏱"
	dur_btn.tooltip_text = "Set Frame Duration (F)"
	dur_btn.custom_minimum_size = Vector2(24, 20)
	_style_tool_button(dur_btn)
	dur_btn.pressed.connect(_show_frame_duration_dialog)
	header.add_child(dur_btn)

	var tag_btn := Button.new()
	tag_btn.text = "🏷"
	tag_btn.tooltip_text = "Animation Tags"
	tag_btn.custom_minimum_size = Vector2(24, 20)
	_style_tool_button(tag_btn)
	tag_btn.pressed.connect(_show_animation_tags_dialog)
	header.add_child(tag_btn)

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
	if _checker_bg_enabled:
		_draw_checkerboard(offset, canvas_px_size)
	else:
		_canvas_panel.draw_rect(Rect2(offset, canvas_px_size), Color(0.15, 0.15, 0.18))

	# Draw the composited sprite
	_refresh_composite_texture()
	if _canvas_texture != null:
		_canvas_panel.draw_texture_rect(_canvas_texture, Rect2(offset, canvas_px_size), false)

	# Onion skin
	if _onion_skin_enabled and _frames.size() > 1:
		_draw_onion_skin(offset, canvas_px_size)

	# Pixel grid (only if zoomed enough and enabled)
	if _pixel_grid_enabled and _zoom >= 4.0:
		_draw_pixel_grid(offset, canvas_px_size)

	# Draw preview shapes (line, rect, ellipse in progress)
	if _is_drawing and _current_tool in [Tool.LINE, Tool.RECT, Tool.RECT_FILLED, Tool.ELLIPSE, Tool.ELLIPSE_FILLED]:
		_draw_shape_preview(offset)

	# Lasso path preview
	if _lasso_drawing and _lasso_points.size() >= 2:
		for i in range(_lasso_points.size() - 1):
			var p1 := offset + Vector2(_lasso_points[i]) * _zoom + Vector2(_zoom, _zoom) * 0.5
			var p2 := offset + Vector2(_lasso_points[i + 1]) * _zoom + Vector2(_zoom, _zoom) * 0.5
			_canvas_panel.draw_line(p1, p2, SELECTION_BORDER, 1.0)
		# Close line back to start
		var p_last := offset + Vector2(_lasso_points[-1]) * _zoom + Vector2(_zoom, _zoom) * 0.5
		var p_first := offset + Vector2(_lasso_points[0]) * _zoom + Vector2(_zoom, _zoom) * 0.5
		_canvas_panel.draw_line(p_last, p_first, Color(1, 1, 1, 0.4), 1.0)

	# Selection rectangle
	if _has_selection:
		var sel_rect := Rect2(
			offset + Vector2(_selection_rect.position + _selection_offset) * _zoom,
			Vector2(_selection_rect.size) * _zoom
		)
		_canvas_panel.draw_rect(sel_rect, SELECTION_BORDER, false, 1.0)
		# Dashed inner
		_canvas_panel.draw_rect(sel_rect.grow(-1), Color(0, 0, 0, 0.5), false, 1.0)

	# Tiled preview (draw 8 copies around the main canvas)
	if _tiled_preview and _canvas_texture != null:
		for ty in range(-1, 2):
			for tx in range(-1, 2):
				if tx == 0 and ty == 0:
					continue
				var tile_off := offset + Vector2(tx * canvas_px_size.x, ty * canvas_px_size.y)
				_canvas_panel.draw_texture_rect(_canvas_texture, Rect2(tile_off, canvas_px_size), false, Color(1, 1, 1, 0.4))

	# Reference layer
	if _reference_visible and _reference_image != null:
		var ref_tex := ImageTexture.create_from_image(_reference_image)
		_canvas_panel.draw_texture_rect(ref_tex, Rect2(offset, canvas_px_size), false, Color(1, 1, 1, _reference_opacity))

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
		var opacity: float = layer.get("opacity", 1.0)
		var blend: int = layer.get("blend_mode", BlendMode.NORMAL)
		if blend == BlendMode.NORMAL and opacity >= 1.0:
			result.blend_rect(img, Rect2i(Vector2i.ZERO, _canvas_size), Vector2i.ZERO)
		else:
			# Per-pixel blend with mode and opacity
			for y in range(_canvas_size.y):
				for x in range(_canvas_size.x):
					var src: Color = img.get_pixel(x, y)
					if src.a < 0.004:
						continue
					src.a *= opacity
					var dst: Color = result.get_pixel(x, y)
					var out := dst
					match blend:
						BlendMode.MULTIPLY:
							out = Color(dst.r * src.r, dst.g * src.g, dst.b * src.b, dst.a)
						BlendMode.SCREEN:
							out = Color(1.0 - (1.0 - dst.r) * (1.0 - src.r), 1.0 - (1.0 - dst.g) * (1.0 - src.g), 1.0 - (1.0 - dst.b) * (1.0 - src.b), dst.a)
						BlendMode.OVERLAY:
							var _or := 2.0 * dst.r * src.r if dst.r < 0.5 else 1.0 - 2.0 * (1.0 - dst.r) * (1.0 - src.r)
							var _og := 2.0 * dst.g * src.g if dst.g < 0.5 else 1.0 - 2.0 * (1.0 - dst.g) * (1.0 - src.g)
							var _ob := 2.0 * dst.b * src.b if dst.b < 0.5 else 1.0 - 2.0 * (1.0 - dst.b) * (1.0 - src.b)
							out = Color(_or, _og, _ob, dst.a)
						BlendMode.ADD:
							out = Color(minf(dst.r + src.r, 1.0), minf(dst.g + src.g, 1.0), minf(dst.b + src.b, 1.0), dst.a)
						BlendMode.SUBTRACT:
							out = Color(maxf(dst.r - src.r, 0.0), maxf(dst.g - src.g, 0.0), maxf(dst.b - src.b, 0.0), dst.a)
						_:  # NORMAL with opacity
							out = dst.lerp(src, src.a)
					out.a = minf(dst.a + src.a, 1.0)
					result.set_pixel(x, y, out)
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
			Tool.MAGIC_WAND:
				_push_undo()
				_magic_wand_select(px)
				_refresh_canvas()
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
			Tool.GRADIENT:
				_push_undo()
				_is_drawing = true
				_draw_start = px
				_draw_end = px
			Tool.OUTLINE:
				_outline_pixels()
				_refresh_canvas()
			Tool.LASSO:
				if not _lasso_drawing:
					_lasso_drawing = true
					_lasso_points.clear()
				_lasso_points.append(px)
				_is_drawing = true
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
				Tool.GRADIENT:
					_apply_gradient(_draw_start, px)
				Tool.LASSO:
					_finalize_lasso()
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
			Tool.LASSO:
				_lasso_points.append(px)

	_refresh_canvas()  # for cursor highlight

# ─────────────────────────────────────────────────────────────────────────────
# DRAWING OPERATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _draw_pen_stroke(pos: Vector2i, color: Color) -> void:
	var img := _get_active_image()
	if img == null:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
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
			if _ink_opacity < 1.0:
				var existing := img.get_pixel(x, y)
				var blended := existing.lerp(color, _ink_opacity)
				blended.a = maxf(existing.a, color.a * _ink_opacity)
				img.set_pixel(x, y, blended)
			else:
				img.set_pixel(x, y, color)

func _flood_fill(start: Vector2i, fill_color: Color) -> void:
	var img := _get_active_image()
	if img == null:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	if start.x < 0 or start.x >= _canvas_size.x or start.y < 0 or start.y >= _canvas_size.y:
		return
	var target_color := img.get_pixel(start.x, start.y)
	if target_color.is_equal_approx(fill_color):
		return
	if not _contiguous_fill:
		# Non-contiguous: replace ALL pixels of this color in the image
		for y in range(_canvas_size.y):
			for x in range(_canvas_size.x):
				if img.get_pixel(x, y).is_equal_approx(target_color):
					img.set_pixel(x, y, fill_color)
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

func _magic_wand_select(start: Vector2i) -> void:
	## Select all contiguous pixels of the same color (tolerance-based flood select)
	var img := _get_active_image()
	if img == null:
		return
	if start.x < 0 or start.x >= _canvas_size.x or start.y < 0 or start.y >= _canvas_size.y:
		return
	var target_color := img.get_pixel(start.x, start.y)
	var stack: Array[Vector2i] = [start]
	var visited := {}
	var min_x := start.x
	var min_y := start.y
	var max_x := start.x
	var max_y := start.y
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= _canvas_size.x or p.y < 0 or p.y >= _canvas_size.y:
			continue
		var key := p.x * 10000 + p.y
		if key in visited:
			continue
		visited[key] = true
		var pc := img.get_pixel(p.x, p.y)
		# Tolerance: colors must be very similar (within ~5% per channel)
		if absf(pc.r - target_color.r) > 0.05 or absf(pc.g - target_color.g) > 0.05 or absf(pc.b - target_color.b) > 0.05 or absf(pc.a - target_color.a) > 0.05:
			continue
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
		max_x = maxi(max_x, p.x)
		max_y = maxi(max_y, p.y)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	# Create a bounding-box selection around the wand result
	_has_selection = true
	_selection_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_selection_offset = Vector2i.ZERO
	_selection_image = null  # No floating image, just a selection region

## Copy the current selection (or entire canvas) to the internal clipboard.
func _copy_selection() -> void:
	var img := _get_active_image()
	if img == null:
		return
	if _has_selection and _selection_rect.size.x > 0 and _selection_rect.size.y > 0:
		var r := _selection_rect
		# Clamp to canvas bounds
		var x0 := clampi(r.position.x, 0, _canvas_size.x)
		var y0 := clampi(r.position.y, 0, _canvas_size.y)
		var x1 := clampi(r.position.x + r.size.x, 0, _canvas_size.x)
		var y1 := clampi(r.position.y + r.size.y, 0, _canvas_size.y)
		if x1 <= x0 or y1 <= y0:
			return
		_clipboard_image = img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	else:
		# No selection — copy entire canvas
		_clipboard_image = img.duplicate()
	# Also push to system clipboard so other apps can paste it
	_copy_image_to_system_clipboard(_clipboard_image)

## Paste the clipboard onto the active layer at the top-left corner.
func _paste_clipboard() -> void:
	# Always try system clipboard first — allows pasting from external apps
	var sys_img := _paste_image_from_system_clipboard()
	if sys_img != null and not sys_img.is_empty():
		_clipboard_image = sys_img
	if _clipboard_image == null or _clipboard_image.is_empty():
		return
	var img := _get_active_image()
	if img == null:
		return
	_push_undo()
	# Blit pasted pixels onto the active layer at (0,0)
	var src_size := _clipboard_image.get_size()
	var dst_rect := Rect2i(Vector2i.ZERO, Vector2i(
		mini(src_size.x, _canvas_size.x),
		mini(src_size.y, _canvas_size.y)
	))
	img.blend_rect(_clipboard_image, Rect2i(Vector2i.ZERO, dst_rect.size), Vector2i.ZERO)
	# Set selection around the pasted area so user can see / move it
	_has_selection = true
	_selection_rect = dst_rect
	_selection_offset = Vector2i.ZERO
	_selection_image = null
	_refresh_canvas()

## ── System clipboard helpers (OS.execute bridge) ──────────────
## Uses xclip / xsel / wl-copy on Linux, pbcopy/pbpaste on macOS,
## PowerShell on Windows.  Transfers PNG via temp file.
## Will be replaced by native C++ GDExtension in v5.1.

func _copy_image_to_system_clipboard(img: Image) -> void:
	if img == null or img.is_empty():
		return
	var tmp_path := OS.get_cache_dir().path_join("vg_clipboard.png")
	var err := img.save_png(tmp_path)
	if err != OK:
		push_warning("[VG Sprite] Could not save temp PNG for clipboard: ", err)
		return
	var os_name := OS.get_name()
	if os_name == "Linux" or os_name == "FreeBSD":
		# Use a background shell so xclip doesn't block Godot.
		# xclip -selection clipboard forks to hold the selection; run via bash &
		var output := []
		if OS.execute("which", ["xclip"], output) == 0:
			# Run in background: xclip needs to stay alive to own the X selection
			OS.create_process("bash", ["-c", "xclip -selection clipboard -t image/png -i " + tmp_path + " &"])
		elif OS.execute("which", ["wl-copy"], output) == 0:
			OS.create_process("bash", ["-c", "wl-copy --type image/png < " + tmp_path + " &"])
		elif OS.execute("which", ["xsel"], output) == 0:
			OS.create_process("bash", ["-c", "xsel --clipboard --input < " + tmp_path + " &"])
		else:
			push_warning("[VG Sprite] No clipboard tool found (install xclip, xsel, or wl-copy)")
	elif os_name == "macOS":
		# osascript: each -e is one line of the script
		OS.execute("osascript", [
			"-e", 'set the clipboard to (read (POSIX file "' + tmp_path + '") as {«class PNGf»})'])
	elif os_name == "Windows":
		# PowerShell: load both assemblies, copy image to clipboard, then dispose
		var ps_cmd := "Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Windows.Forms; "
		ps_cmd += "$i = [System.Drawing.Image]::FromFile('" + tmp_path.replace("/", "\\") + "'); "
		ps_cmd += "[System.Windows.Forms.Clipboard]::SetImage($i); $i.Dispose()"
		OS.execute("powershell.exe", ["-NoProfile", "-Command", ps_cmd])

func _paste_image_from_system_clipboard() -> Image:
	var tmp_path := OS.get_cache_dir().path_join("vg_clipboard_paste.png")
	var os_name := OS.get_name()
	var ok := false
	if os_name == "Linux" or os_name == "FreeBSD":
		var output := []
		if OS.execute("which", ["xclip"], output) == 0:
			var exit_code := OS.execute("bash", ["-c", "xclip -selection clipboard -t image/png -o > " + tmp_path + " 2>/dev/null"])
			if exit_code == 0:
				ok = true
		elif OS.execute("which", ["wl-paste"], output) == 0:
			var exit_code := OS.execute("bash", ["-c", "wl-paste --type image/png > " + tmp_path + " 2>/dev/null"])
			if exit_code == 0:
				ok = true
	elif os_name == "macOS":
		# Use osascript with separate -e lines to read PNG from clipboard
		var exit_code := OS.execute("osascript", [
			"-e", "try",
			"-e", 'set img to the clipboard as «class PNGf»',
			"-e", 'set f to open for access POSIX file "' + tmp_path + '" with write permission',
			"-e", "set eof of f to 0",
			"-e", "write img to f",
			"-e", "close access f",
			"-e", "end try"])
		if exit_code == 0 and FileAccess.file_exists(tmp_path):
			ok = true
	elif os_name == "Windows":
		# PowerShell: read image from clipboard and save as PNG
		var ps_cmd := "Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName System.Windows.Forms; "
		ps_cmd += "$i = [System.Windows.Forms.Clipboard]::GetImage(); "
		ps_cmd += "if ($i) { $i.Save('" + tmp_path.replace("/", "\\") + "', [System.Drawing.Imaging.ImageFormat]::Png); $i.Dispose() }"
		var exit_code := OS.execute("powershell.exe", ["-NoProfile", "-Command", ps_cmd])
		if exit_code == 0:
			ok = true
	if not ok:
		return null
	if not FileAccess.file_exists(tmp_path):
		return null
	var img := Image.new()
	var err := img.load(tmp_path)
	if err != OK or img.is_empty():
		return null
	return img

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
	_layers.insert(0, { "name": new_name, "image": img, "visible": true, "opacity": 1.0, "locked": false, "blend_mode": BlendMode.NORMAL })
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
		var lock_icon := "🔒" if layer.get("locked", false) else ""
		_layer_list.add_item(vis_icon + " " + lock_icon + layer["name"])
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
			"locked": false,
			"blend_mode": BlendMode.NORMAL,
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
		# Use per-frame duration if available, otherwise fall back to global FPS
		var frame_duration: float = _frames[_preview_frame_idx].get("duration", 1.0 / _fps)
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
# CUT / DELETE SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _cut_selection() -> void:
	## Copy selection to clipboard, then clear selected region to transparent.
	_copy_selection()
	_delete_selection()

func _delete_selection() -> void:
	## Clear selected region to transparent.
	var img := _get_active_image()
	if img == null or not _has_selection:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	_push_undo()
	var r := _selection_rect
	var x0 := clampi(r.position.x + _selection_offset.x, 0, _canvas_size.x)
	var y0 := clampi(r.position.y + _selection_offset.y, 0, _canvas_size.y)
	var x1 := clampi(r.position.x + _selection_offset.x + r.size.x, 0, _canvas_size.x)
	var y1 := clampi(r.position.y + _selection_offset.y + r.size.y, 0, _canvas_size.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# OUTLINE PIXELS
# ─────────────────────────────────────────────────────────────────────────────
func _outline_pixels() -> void:
	## Draw a 1px outline around all non-transparent pixels using primary color.
	var img := _get_active_image()
	if img == null:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	_push_undo()
	# Find all edge pixels: transparent pixels adjacent to non-transparent
	var outline_pixels: Array[Vector2i] = []
	for y in range(_canvas_size.y):
		for x in range(_canvas_size.x):
			if img.get_pixel(x, y).a < 0.01:
				# Check if any neighbor is non-transparent
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and nx < _canvas_size.x and ny >= 0 and ny < _canvas_size.y:
						if img.get_pixel(nx, ny).a > 0.01:
							outline_pixels.append(Vector2i(x, y))
							break
	for p in outline_pixels:
		img.set_pixel(p.x, p.y, _primary_color)
	_sync_frame_from_layers()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# REPLACE COLOR
# ─────────────────────────────────────────────────────────────────────────────
func _replace_color() -> void:
	## Replace all pixels of primary color with secondary color on active layer.
	var img := _get_active_image()
	if img == null:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	_push_undo()
	var count := 0
	for y in range(_canvas_size.y):
		for x in range(_canvas_size.x):
			if img.get_pixel(x, y).is_equal_approx(_primary_color):
				img.set_pixel(x, y, _secondary_color)
				count += 1
	_sync_frame_from_layers()
	_refresh_canvas()
	print("[VG Sprite Editor] Replaced %d pixels" % count)

# ─────────────────────────────────────────────────────────────────────────────
# FLATTEN LAYERS
# ─────────────────────────────────────────────────────────────────────────────
func _flatten_layers() -> void:
	## Merge all layers into a single layer.
	if _layers.size() <= 1:
		return
	_push_undo()
	var composite := _composite_layers()
	_layers = [{ "name": "Layer 1", "image": composite, "visible": true, "opacity": 1.0, "locked": false, "blend_mode": BlendMode.NORMAL }]
	_active_layer_idx = 0
	_sync_frame_from_layers()
	_refresh_layer_list()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# TOGGLE LAYER LOCK
# ─────────────────────────────────────────────────────────────────────────────
func _toggle_layer_lock() -> void:
	if _active_layer_idx < 0 or _active_layer_idx >= _layers.size():
		return
	_layers[_active_layer_idx]["locked"] = not _layers[_active_layer_idx].get("locked", false)
	_refresh_layer_list()

# ─────────────────────────────────────────────────────────────────────────────
# SELECTION TRANSFORMS (flip/rotate on selection only)
# ─────────────────────────────────────────────────────────────────────────────
func _transform_selection(op: String) -> void:
	## Apply flip/rotate to the selected region only.
	var img := _get_active_image()
	if img == null or not _has_selection:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	_push_undo()
	var r := _selection_rect
	var x0 := clampi(r.position.x, 0, _canvas_size.x)
	var y0 := clampi(r.position.y, 0, _canvas_size.y)
	var x1 := clampi(r.position.x + r.size.x, 0, _canvas_size.x)
	var y1 := clampi(r.position.y + r.size.y, 0, _canvas_size.y)
	var sub := img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	match op:
		"flip_h":
			sub.flip_x()
		"flip_v":
			sub.flip_y()
		"rot90":
			sub.rotate_90(CLOCKWISE)
			# If selection is non-square, adjust selection rect
			if r.size.x != r.size.y:
				_selection_rect = Rect2i(x0, y0, r.size.y, r.size.x)
		"rot180":
			sub.rotate_180()
		"scale_2x":
			sub.resize(sub.get_width() * 2, sub.get_height() * 2, Image.INTERPOLATE_NEAREST)
		"scale_half":
			sub.resize(maxi(sub.get_width() / 2, 1), maxi(sub.get_height() / 2, 1), Image.INTERPOLATE_NEAREST)
	# Clear original region
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	# Blit transformed sub back
	var blit_w := mini(sub.get_width(), _canvas_size.x - x0)
	var blit_h := mini(sub.get_height(), _canvas_size.y - y0)
	img.blend_rect(sub, Rect2i(0, 0, blit_w, blit_h), Vector2i(x0, y0))
	_sync_frame_from_layers()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# GRADIENT TOOL
# ─────────────────────────────────────────────────────────────────────────────
func _apply_gradient(from: Vector2i, to: Vector2i) -> void:
	## Draw a linear gradient from primary to secondary color.
	var img := _get_active_image()
	if img == null:
		return
	if _active_layer_idx >= 0 and _active_layer_idx < _layers.size() and _layers[_active_layer_idx].get("locked", false):
		return
	var dx := float(to.x - from.x)
	var dy := float(to.y - from.y)
	var length := sqrt(dx * dx + dy * dy)
	if length < 1.0:
		return
	# Work within selection if active, otherwise full canvas
	var x0 := 0; var y0 := 0; var x1 := _canvas_size.x; var y1 := _canvas_size.y
	if _has_selection:
		x0 = clampi(_selection_rect.position.x, 0, _canvas_size.x)
		y0 = clampi(_selection_rect.position.y, 0, _canvas_size.y)
		x1 = clampi(_selection_rect.position.x + _selection_rect.size.x, 0, _canvas_size.x)
		y1 = clampi(_selection_rect.position.y + _selection_rect.size.y, 0, _canvas_size.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var px_dx := float(x - from.x)
			var px_dy := float(y - from.y)
			var t := clampf((px_dx * dx + px_dy * dy) / (length * length), 0.0, 1.0)
			img.set_pixel(x, y, _primary_color.lerp(_secondary_color, t))
	_sync_frame_from_layers()
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# REFERENCE LAYER
# ─────────────────────────────────────────────────────────────────────────────
func _load_reference_image() -> void:
	var dlg := FileDialog.new()
	dlg.title = "Load Reference Image"
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.png;PNG", "*.jpg;JPEG", "*.webp;WebP", "*.bmp;BMP"])
	dlg.size = Vector2i(600, 400)
	dlg.file_selected.connect(func(path: String):
		var img := Image.load_from_file(path)
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			img.resize(_canvas_size.x, _canvas_size.y, Image.INTERPOLATE_LANCZOS)
			_reference_image = img
			_reference_visible = true
			_refresh_canvas()
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# BRUSH STAMP (custom brush from selection)
# ─────────────────────────────────────────────────────────────────────────────
func _capture_brush_stamp() -> void:
	## Capture the current selection as a reusable brush stamp.
	var img := _get_active_image()
	if img == null or not _has_selection:
		return
	var r := _selection_rect
	var x0 := clampi(r.position.x, 0, _canvas_size.x)
	var y0 := clampi(r.position.y, 0, _canvas_size.y)
	var x1 := clampi(r.position.x + r.size.x, 0, _canvas_size.x)
	var y1 := clampi(r.position.y + r.size.y, 0, _canvas_size.y)
	_brush_stamp = img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	print("[VG Sprite Editor] Captured brush stamp %dx%d" % [_brush_stamp.get_width(), _brush_stamp.get_height()])

func _paint_brush_stamp(pos: Vector2i) -> void:
	## Paint the captured brush stamp centered at pos.
	var img := _get_active_image()
	if img == null or _brush_stamp == null:
		return
	var bw := _brush_stamp.get_width()
	var bh := _brush_stamp.get_height()
	var dst := Vector2i(pos.x - bw / 2, pos.y - bh / 2)
	var src_rect := Rect2i(0, 0, mini(bw, _canvas_size.x - dst.x), mini(bh, _canvas_size.y - dst.y))
	img.blend_rect(_brush_stamp, src_rect, Vector2i(maxi(dst.x, 0), maxi(dst.y, 0)))

# ─────────────────────────────────────────────────────────────────────────────
# LASSO SELECTION
# ─────────────────────────────────────────────────────────────────────────────
func _finalize_lasso() -> void:
	## Create a rectangular selection from the bounding box of lasso points.
	if _lasso_points.size() < 3:
		_lasso_points.clear()
		_lasso_drawing = false
		return
	var min_x := _canvas_size.x; var min_y := _canvas_size.y
	var max_x := 0; var max_y := 0
	for p in _lasso_points:
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
		max_x = maxi(max_x, p.x)
		max_y = maxi(max_y, p.y)
	min_x = clampi(min_x, 0, _canvas_size.x - 1)
	min_y = clampi(min_y, 0, _canvas_size.y - 1)
	max_x = clampi(max_x, 0, _canvas_size.x - 1)
	max_y = clampi(max_y, 0, _canvas_size.y - 1)
	_has_selection = true
	_selection_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_selection_offset = Vector2i.ZERO
	_selection_image = null
	_lasso_points.clear()
	_lasso_drawing = false
	_refresh_canvas()

# ─────────────────────────────────────────────────────────────────────────────
# COLOR RAMP GENERATOR
# ─────────────────────────────────────────────────────────────────────────────
func _show_color_ramp_dialog() -> void:
	## Generate a ramp of colors between primary and secondary and load as palette.
	var dlg := AcceptDialog.new()
	dlg.title = "Color Ramp Generator"
	dlg.size = Vector2i(300, 140)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dlg.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Steps (primary → secondary):"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(lbl)
	var steps_spin := SpinBox.new()
	steps_spin.min_value = 2
	steps_spin.max_value = 64
	steps_spin.value = 8
	vbox.add_child(steps_spin)
	dlg.confirmed.connect(func():
		var steps := int(steps_spin.value)
		var colors: Array = []
		for i in range(steps):
			var t := float(i) / float(steps - 1)
			var c := _primary_color.lerp(_secondary_color, t)
			colors.append("#%02X%02X%02X" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)])
		_load_palette_from_colors(colors, "Ramp")
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# HSV COLOR PICKER
# ─────────────────────────────────────────────────────────────────────────────
func _show_hsv_picker() -> void:
	## Show a popup with an HSV color picker for more precise color selection.
	var dlg := AcceptDialog.new()
	dlg.title = "HSV Color Picker"
	dlg.size = Vector2i(340, 360)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dlg.add_child(vbox)
	var picker := ColorPicker.new()
	picker.color = _primary_color
	picker.color_modes_visible = true
	picker.sliders_visible = true
	picker.hex_visible = true
	picker.presets_visible = false
	picker.custom_minimum_size = Vector2(300, 280)
	vbox.add_child(picker)
	dlg.confirmed.connect(func():
		_set_primary_color(picker.color)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION TAGS
# ─────────────────────────────────────────────────────────────────────────────
func _show_animation_tags_dialog() -> void:
	## Manage animation tags (named frame ranges).
	var dlg := AcceptDialog.new()
	dlg.title = "Animation Tags"
	dlg.size = Vector2i(400, 320)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dlg.add_child(vbox)

	var tag_list := ItemList.new()
	tag_list.custom_minimum_size = Vector2(0, 140)
	var tl_style := StyleBoxFlat.new()
	tl_style.bg_color = Color(0.14, 0.14, 0.17)
	tag_list.add_theme_stylebox_override("panel", tl_style)
	tag_list.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(tag_list)

	# Populate
	for tag in _animation_tags:
		tag_list.add_item("%s [%d-%d]" % [tag["name"], tag["from"] + 1, tag["to"] + 1])

	# Add tag controls
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	vbox.add_child(add_row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Tag name"
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	add_row.add_child(name_edit)
	var from_spin := SpinBox.new()
	from_spin.min_value = 1
	from_spin.max_value = maxi(_frames.size(), 1)
	from_spin.value = _active_frame_idx + 1
	from_spin.prefix = "From:"
	add_row.add_child(from_spin)
	var to_spin := SpinBox.new()
	to_spin.min_value = 1
	to_spin.max_value = maxi(_frames.size(), 1)
	to_spin.value = _active_frame_idx + 1
	to_spin.prefix = "To:"
	add_row.add_child(to_spin)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)
	var add_btn := Button.new()
	add_btn.text = "+ Add Tag"
	_style_tool_button(add_btn)
	add_btn.pressed.connect(func():
		if name_edit.text.strip_edges().is_empty():
			return
		_animation_tags.append({
			"name": name_edit.text.strip_edges(),
			"from": int(from_spin.value) - 1,
			"to": int(to_spin.value) - 1,
			"color": Color(randf(), randf(), randf(), 1.0),
		})
		tag_list.add_item("%s [%d-%d]" % [name_edit.text.strip_edges(), int(from_spin.value), int(to_spin.value)])
		name_edit.text = ""
	)
	btn_row.add_child(add_btn)
	var del_btn := Button.new()
	del_btn.text = "− Remove"
	_style_tool_button(del_btn)
	del_btn.pressed.connect(func():
		var sel := tag_list.get_selected_items()
		if sel.size() > 0:
			_animation_tags.remove_at(sel[0])
			tag_list.remove_item(sel[0])
	)
	btn_row.add_child(del_btn)

	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

# ─────────────────────────────────────────────────────────────────────────────
# PER-FRAME DURATION
# ─────────────────────────────────────────────────────────────────────────────
func _show_frame_duration_dialog() -> void:
	## Set duration for the current frame.
	var dlg := AcceptDialog.new()
	dlg.title = "Frame Duration"
	dlg.size = Vector2i(260, 120)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dlg.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Duration (ms) for frame %d:" % (_active_frame_idx + 1)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(lbl)
	var dur_spin := SpinBox.new()
	dur_spin.min_value = 10
	dur_spin.max_value = 10000
	dur_spin.step = 10
	var current_dur: float = _frames[_active_frame_idx].get("duration", 1.0 / _fps)
	dur_spin.value = current_dur * 1000.0
	dur_spin.suffix = "ms"
	vbox.add_child(dur_spin)
	dlg.confirmed.connect(func():
		_frames[_active_frame_idx]["duration"] = dur_spin.value / 1000.0
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

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
	# Announce save on the process-wide bus so file browsers, thumbnail
	# caches, and any other open editor referencing this PNG can refresh.
	_AssetBus.get_instance().emit_saved(_file_path, _ASSET_PLUGIN_ID)
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
	# After a successful load, announce that this editor now owns the
	# given asset. Other UI (file-browser highlight, breadcrumb, command
	# palette "recent files") observes ContextBroker.context_changed.
	if _file_path == path:
		_AssetBus.get_instance().emit_opened(path, _ASSET_PLUGIN_ID)
		_ContextBroker.get_instance().set_current_asset(path, _ASSET_PLUGIN_ID)


## VGPluginRegistry contract — dispatched by registry.open_asset().
## Returns true if the editor accepted the file. Existing callers should
## keep using open_file(); this is just a registry-friendly alias.
func open_asset(path: String) -> bool:
	open_file(path)
	return _file_path == path


func _on_open_file(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		push_warning("[VG Sprite Editor] Could not load: " + path)
		return
	_canvas_size = Vector2i(img.get_width(), img.get_height())
	img.convert(Image.FORMAT_RGBA8)
	_layers = [{ "name": "Layer 1", "image": img, "visible": true, "opacity": 1.0, "locked": false, "blend_mode": BlendMode.NORMAL }]
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
	_AssetBus.get_instance().emit_saved(path, _ASSET_PLUGIN_ID)
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
# Use _shortcut_input instead of _unhandled_key_input so shortcuts fire
# BEFORE the Godot editor's own menus / controls consume Ctrl+C/V/Z etc.
func _shortcut_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and ev.pressed:
		var handled := true
		if ev.ctrl_pressed:
			match ev.keycode:
				KEY_Z: _undo()
				KEY_Y: _redo()
				KEY_S: _save()
				KEY_N: _show_new_dialog()
				KEY_O: _show_open_dialog()
				KEY_E: _show_export_dialog()
				KEY_C: _copy_selection()
				KEY_V: _paste_clipboard()
				KEY_X: _cut_selection()
				KEY_A:
					_has_selection = true
					_selection_rect = Rect2i(0, 0, _canvas_size.x, _canvas_size.y)
					_selection_offset = Vector2i.ZERO
					_refresh_canvas()
				_: handled = false
		else:
			match ev.keycode:
				KEY_P: _select_tool(Tool.PEN)
				KEY_E: _select_tool(Tool.ERASER)
				KEY_L:
					if ev.shift_pressed:
						_select_tool(Tool.OUTLINE)
					else:
						_select_tool(Tool.LINE)
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
				KEY_G:
					if ev.shift_pressed:
						_select_tool(Tool.GRADIENT)
					else:
						_select_tool(Tool.FILL)
				KEY_I: _select_tool(Tool.COLOR_PICKER)
				KEY_S:
					if ev.shift_pressed:
						_select_tool(Tool.LASSO)
					else:
						_select_tool(Tool.SELECT)
				KEY_M: _select_tool(Tool.MOVE)
				KEY_H: _select_tool(Tool.MIRROR_PEN)
				KEY_D: _select_tool(Tool.DITHER_PEN)
				KEY_U: _select_tool(Tool.LIGHTEN)
				KEY_J: _select_tool(Tool.DARKEN)
				KEY_W: _select_tool(Tool.MAGIC_WAND)
				KEY_X: _swap_colors()
				KEY_DELETE:
					_delete_selection()
					_refresh_canvas()
				KEY_F:
					_show_frame_duration_dialog()
				KEY_BRACKETLEFT:
					_pen_size = maxi(_pen_size - 1, 1)
					if is_instance_valid(_pen_size_spin):
						_pen_size_spin.value = _pen_size
				KEY_BRACKETRIGHT:
					_pen_size = mini(_pen_size + 1, 32)
					if is_instance_valid(_pen_size_spin):
						_pen_size_spin.value = _pen_size
				_: handled = false
		if handled:
			get_viewport().set_input_as_handled()

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
		Tool.MAGIC_WAND: "Magic Wand", Tool.OUTLINE: "Outline",
		Tool.GRADIENT: "Gradient", Tool.LASSO: "Lasso",
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
	btn.add_theme_font_size_override("font_size", 16)

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
