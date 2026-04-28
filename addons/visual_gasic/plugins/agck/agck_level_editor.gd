@tool
## AGCK Level Editor — WYSIWYG tile-based level designer
##
## Visual tile palette with real pixel-art thumbnails. The grid renders
## actual tile textures for a true What-You-See-Is-What-You-Get experience.
## Double-click any tile in the palette to open the inline sprite editor
## and customize it. Edited tiles update the grid in real-time.
extends VBoxContainer

signal level_changed(level_id: int)
signal edit_tile_requested(block_type: int, tile_index: int)

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR     = Color(0.13, 0.13, 0.16)
const HEADER_BG    = Color(0.10, 0.10, 0.13)
const TOOLBAR_BG   = Color(0.11, 0.11, 0.14)
const WHITE        = Color(1.0, 1.0, 1.0)
const LABEL_CLR    = Color(0.88, 0.86, 0.80)
const ACCENT       = Color(1.0, 0.82, 0.35)
const DIM          = Color(0.50, 0.50, 0.55)
const GRID_LINE    = Color(0.22, 0.22, 0.26)
const CURSOR_COLOR = Color(1.0, 1.0, 0.4, 0.7)

# Block types — Bloxels-style color-coded
const BLOCK_EMPTY      = 0
const BLOCK_BARRIER    = 1
const BLOCK_LADDER     = 2
const BLOCK_DEADLY     = 3
const BLOCK_BACKGROUND = 4
const BLOCK_TELEPORT   = 5
const BLOCK_SWITCH     = 6

const BLOCK_NAMES  = ["Empty", "Barrier", "Ladder", "Deadly", "Background", "Teleport", "Switch"]
const BLOCK_COLORS = [
	Color(0.12, 0.12, 0.14),
	Color(0.50, 0.55, 0.60),
	Color(0.30, 0.75, 0.30),
	Color(0.85, 0.20, 0.20),
	Color(0.25, 0.40, 0.60),
	Color(0.65, 0.30, 0.85),
	Color(0.90, 0.80, 0.20),
]
const BLOCK_ICONS = ["  ", "B ", "L ", "D ", "Bg", "T ", "S "]

const MAX_LEVELS = 50

# ─── Per-Tile Shader FX ──────────────────────────────────────
const SPRITE_FX_NAMES: Array = [
	"(None)", "Outline", "Glow", "Hologram", "Flash",
	"Rainbow", "Shimmer", "Dissolve", "Pixelate",
]
const SPRITE_FX_UNIFORMS: Dictionary = {
	"Outline": [
		{"name": "outline_width", "label": "Width", "default": 1.0, "min": 0.5, "max": 4.0, "step": 0.5},
	],
	"Glow": [
		{"name": "glow_size", "label": "Size", "default": 3.0, "min": 1.0, "max": 8.0, "step": 0.5},
	],
	"Hologram": [
		{"name": "scan_speed", "label": "Speed", "default": 2.0, "min": 0.5, "max": 5.0, "step": 0.5},
		{"name": "scan_density", "label": "Density", "default": 40.0, "min": 10.0, "max": 100.0, "step": 5.0},
	],
	"Flash": [
		{"name": "flash_amount", "label": "Amount", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.05},
	],
	"Rainbow": [
		{"name": "speed", "label": "Speed", "default": 1.0, "min": 0.1, "max": 5.0, "step": 0.1},
		{"name": "saturation", "label": "Saturation", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.05},
	],
	"Shimmer": [
		{"name": "shimmer_speed", "label": "Speed", "default": 2.0, "min": 0.5, "max": 5.0, "step": 0.5},
		{"name": "shimmer_amount", "label": "Amount", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.05},
	],
	"Dissolve": [
		{"name": "amount", "label": "Amount", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.05},
		{"name": "edge_width", "label": "Edge Width", "default": 0.05, "min": 0.01, "max": 0.2, "step": 0.01},
	],
	"Pixelate": [
		{"name": "pixel_size", "label": "Pixel Size", "default": 4.0, "min": 2.0, "max": 16.0, "step": 1.0},
	],
}
# ── Level grid size ────────────────────────────────────────────
# Historically these were `const GRID_W = 20` / `const GRID_H = 12`,
# but levels are now PER-LEVEL sized: the dict carries `grid_w` /
# `grid_h` keys (defaulting to these values). Use `_lvl_w()` /
# `_lvl_h()` to read the active level's dimensions throughout this
# editor — the constants below are *defaults only* for new levels.
const DEFAULT_GRID_W = 20
const DEFAULT_GRID_H = 12
const MIN_GRID_W = 8
const MIN_GRID_H = 6
const MAX_GRID_W = 200
const MAX_GRID_H = 60
const BASE_CELL_PX: float = 28.0
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 0.25

# ─── Data ────────────────────────────────────────────────────
var levels: Array = []
var selected_level: int = 0
var selected_block: int = BLOCK_BARRIER
var selected_tile_index: int = 0
var selected_actor: int = -1
var is_painting: bool = false
var actor_names: Array = ["Hero", "Enemy 1", "Bullet"]
var actor_types: Array = ["Player", "Drone", "Missile"]
var _waypoint_mode: bool = false
var _waypoint_actor_idx: int = -1  # placed-actor index being path-edited
var _waypoint_target_type: String = ""  # "actor" or "block"
var _waypoint_block_pos: Vector2i = Vector2i(-1, -1)  # block grid pos being edited
var _flood_fill_mode: bool = false  # bucket-fill tool
var _dirty: bool = false  # unsaved-changes indicator
var _zoom: float = 1.0  # grid zoom level (Shift+Scroll)

# Reference to the tile library (set by agck_plugin.gd)
var tile_library = null

# ─── Undo/Redo ───────────────────────────────────────────────
var _undo_stack: Array = []   # Array of {level: int, grid: Array, actors: Array}
var _redo_stack: Array = []
var _stroke_snapshot = null    # snapshot taken on mouse-down, committed on mouse-up
const MAX_UNDO = 50
var _last_mouse_pos: Vector2 = Vector2.ZERO  # for Delete key

# ─── UI Refs ─────────────────────────────────────────────────
var _grid_canvas: Control = null
var _grid_scroll: ScrollContainer = null
var _zoom_lbl: Label = null
var _block_btns: Array = []
var _tile_palette_scroll: ScrollContainer = null
var _tile_palette: HBoxContainer = null
var _tile_btns: Array = []
var _level_opt: OptionButton = null
var _actor_picker_btn: Button = null
var _actor_picker_popup: PopupPanel = null
var _actor_picker_grid: GridContainer = null
var _waypoint_btn: Button = null

const ACTOR_TYPE_COLORS = {
	"Player":   Color(0.30, 0.75, 0.95),
	"Drone":    Color(0.85, 0.30, 0.30),
	"Missile":  Color(0.95, 0.60, 0.15),
	"Sentry":   Color(0.70, 0.40, 0.90),
	"Computer": Color(0.40, 0.80, 0.40),
	"Zombie":   Color(0.45, 0.65, 0.30),
	"Boss":     Color(0.80, 0.20, 0.50),
	"Bat":      Color(0.50, 0.35, 0.55),
	"NPC":      Color(0.85, 0.70, 0.45),
	"Tank":     Color(0.40, 0.50, 0.35),
	"Fireball": Color(1.00, 0.45, 0.10),
}
var _status_lbl: Label = null
var _name_edit: LineEdit = null
var _fric_slider: HSlider = null
var _elast_slider: HSlider = null
var _death_action_opt: OptionButton = null
var _death_target_spin: SpinBox = null
var _death_target_lbl: Label = null
var _flood_btn: Button = null
var _tile_filter: LineEdit = null
var _tile_import_dialog: FileDialog = null
var _confirm_dialog: ConfirmationDialog = null
var _pending_confirm_action: Callable
var _dirty_lbl: Label = null

# Inline editor popup
var _edit_popup: Window = null
var _edit_canvas: Control = null
var _edit_image: Image = null
var _edit_block_type: int = -1
var _edit_tile_index: int = -1
var _edit_color: Color = Color.WHITE
var _edit_erasing: bool = false
var _edit_name_edit: LineEdit = null
var _edit_palette_btns: Array = []
var _edit_palette_colors: Array = []
var _edit_shader_fx_opt: OptionButton = null
var _edit_shader_params_grid: GridContainer = null


func _ls(size: int, color: Color) -> LabelSettings:
	var s = LabelSettings.new()
	s.font_size = size
	s.font_color = color
	return s


func _style_option(opt: OptionButton) -> void:
	var nb = StyleBoxFlat.new()
	nb.bg_color = Color(0.18, 0.18, 0.22)
	nb.set_corner_radius_all(3)
	nb.content_margin_left = 6
	nb.content_margin_right = 6
	nb.content_margin_top = 3
	nb.content_margin_bottom = 3
	opt.add_theme_stylebox_override("normal", nb)
	var hb = nb.duplicate()
	hb.bg_color = Color(0.22, 0.22, 0.28)
	opt.add_theme_stylebox_override("hover", hb)
	opt.add_theme_stylebox_override("pressed", hb)
	opt.add_theme_stylebox_override("focus", hb)
	opt.add_theme_color_override("font_color", LABEL_CLR)
	opt.add_theme_color_override("font_hover_color", WHITE)
	opt.add_theme_color_override("font_pressed_color", WHITE)
	opt.add_theme_color_override("font_focus_color", LABEL_CLR)
	# Dark popup — OPAQUE window (transparent=true breaks Linux X11 compositors)
	# See POPUP_THEME_FIX.md for the full explanation.
	var popup := opt.get_popup()
	_apply_dark_popup(popup)
	if not popup.has_meta("_agck_popup_styled"):
		popup.set_meta("_agck_popup_styled", true)
		popup.about_to_popup.connect(func():
			_apply_dark_popup(popup)
			_apply_dark_popup.call_deferred(popup)
		)
		popup.visibility_changed.connect(func():
			if popup.visible:
				_apply_dark_popup(popup)
		)


## Linux X11 popup fix — DO NOT use transparent viewports for popups.
## Transparent ARGB visuals cause font rendering to break on X11 compositors
## (text becomes invisible or unreadable). Instead, use an opaque window with
## a dark Theme covering PopupMenu + Window + Panel type names, plus direct
## theme_override calls for highest priority.
func _apply_dark_popup(popup: PopupMenu) -> void:
	if not is_instance_valid(popup):
		return
	popup.transparent = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.15, 0.19, 1.0)
	ps.set_corner_radius_all(0)
	ps.content_margin_left = 6; ps.content_margin_right = 6
	ps.content_margin_top = 4;  ps.content_margin_bottom = 4
	ps.border_width_bottom = 1; ps.border_width_top = 1
	ps.border_width_left = 1;   ps.border_width_right = 1
	ps.border_color = Color(0.30, 0.30, 0.35)
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.25, 0.35, 0.55)
	hs.set_corner_radius_all(3)
	hs.content_margin_left = 6; hs.content_margin_right = 6
	hs.content_margin_top = 2;  hs.content_margin_bottom = 2
	var t := Theme.new()
	for type_name in ["PopupMenu", "PopupPanel", "Panel", "Control", "Window"]:
		t.set_stylebox("panel", type_name, ps)
	t.set_stylebox("hover", "PopupMenu", hs)
	t.set_color("font_color", "PopupMenu", LABEL_CLR)
	t.set_color("font_hover_color", "PopupMenu", WHITE)
	t.set_color("font_disabled_color", "PopupMenu", DIM)
	t.set_color("font_separator_color", "PopupMenu", DIM)
	t.set_color("font_accelerator_color", "PopupMenu", DIM)
	t.set_color("font_outline_color", "PopupMenu", Color.TRANSPARENT)
	popup.theme = t
	popup.add_theme_stylebox_override("panel", ps)
	popup.add_theme_stylebox_override("hover", hs)
	popup.add_theme_color_override("font_color", LABEL_CLR)
	popup.add_theme_color_override("font_hover_color", WHITE)
	popup.add_theme_color_override("font_disabled_color", DIM)
	popup.add_theme_color_override("font_separator_color", DIM)
	popup.add_theme_color_override("font_accelerator_color", DIM)
	popup.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	for c in popup.get_children(true):
		if c is Control:
			c.add_theme_stylebox_override("panel", ps)
			c.queue_redraw()


func _ready() -> void:
	_init_levels()
	_build_ui()


func _init_levels() -> void:
	levels.clear()
	for i in range(MAX_LEVELS):
		levels.append(_make_empty_level(i + 1))


func _make_empty_level(num: int, w: int = DEFAULT_GRID_W, h: int = DEFAULT_GRID_H) -> Dictionary:
	# Clamp to safe ranges so a corrupt project file can't allocate a billion cells.
	w = clampi(w, MIN_GRID_W, MAX_GRID_W)
	h = clampi(h, MIN_GRID_H, MAX_GRID_H)
	var grid: Array = []
	for _y in range(h):
		var row: Array = []
		for _x in range(w):
			row.append({"block_type": BLOCK_EMPTY, "tile_index": 0})
		grid.append(row)
	return {
		"name": "Level " + str(num),
		"grid": grid,
		"grid_w": w,
		"grid_h": h,
		"actors": [],
		"block_paths": {},
		"material_friction": 50,
		"material_elasticity": 50,
		"death_action": "Restart Level",
		"death_action_target": 1,
	}


# Active level dimensions — fall back to the grid array's own shape if
# the dict is missing grid_w/grid_h (older project files), and only fall
# back to the constants when even that's unavailable. This makes legacy
# levels load transparently.
func _lvl_w() -> int:
	if selected_level < 0 or selected_level >= levels.size():
		return DEFAULT_GRID_W
	var lvl: Dictionary = levels[selected_level]
	if lvl.has("grid_w"):
		return int(lvl["grid_w"])
	var grid: Array = lvl.get("grid", [])
	if grid.size() > 0 and grid[0] is Array:
		return grid[0].size()
	return DEFAULT_GRID_W


func _lvl_h() -> int:
	if selected_level < 0 or selected_level >= levels.size():
		return DEFAULT_GRID_H
	var lvl: Dictionary = levels[selected_level]
	if lvl.has("grid_h"):
		return int(lvl["grid_h"])
	var grid: Array = lvl.get("grid", [])
	if grid.size() > 0:
		return grid.size()
	return DEFAULT_GRID_H


func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# ---- TOP BAR: Level selector + name ----
	var top_bar = PanelContainer.new()
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = TOOLBAR_BG
	tb_style.content_margin_left = 8
	tb_style.content_margin_right = 8
	tb_style.content_margin_top = 6
	tb_style.content_margin_bottom = 6
	top_bar.add_theme_stylebox_override("panel", tb_style)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top_bar)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_hbox)

	var lv_lbl = Label.new()
	lv_lbl.text = "Level:"
	lv_lbl.label_settings = _ls(12, LABEL_CLR)
	top_hbox.add_child(lv_lbl)

	_level_opt = OptionButton.new()
	_level_opt.add_theme_font_size_override("font_size", 11)
	_level_opt.custom_minimum_size.x = 130
	_level_opt.item_selected.connect(_on_level_selected)
	top_hbox.add_child(_level_opt)
	_style_option(_level_opt)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Level name"
	_name_edit.custom_minimum_size.x = 120
	_name_edit.add_theme_font_size_override("font_size", 11)
	_name_edit.text_changed.connect(_on_name_changed)
	top_hbox.add_child(_name_edit)

	top_hbox.add_child(VSeparator.new())

	var add_btn = Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Find next empty level"
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.pressed.connect(_on_add_level)
	top_hbox.add_child(add_btn)
	var dup_btn = Button.new()
	dup_btn.text = "Dup"
	dup_btn.tooltip_text = "Duplicate level"
	dup_btn.add_theme_font_size_override("font_size", 12)
	dup_btn.pressed.connect(_on_dup_level)
	top_hbox.add_child(dup_btn)
	var clr_btn = Button.new()
	clr_btn.text = "X"
	clr_btn.tooltip_text = "Clear level"
	clr_btn.add_theme_font_size_override("font_size", 12)
	clr_btn.pressed.connect(_on_clear_level)
	top_hbox.add_child(clr_btn)
	# Per-level grid resize: opens a small dialog with W/H spinners.
	# Existing tile/actor data is preserved on resize (cropped if shrinking,
	# right/bottom-padded with empty cells if growing).
	var resize_btn = Button.new()
	resize_btn.text = "⤢"
	resize_btn.tooltip_text = "Resize this level (width × height)"
	resize_btn.add_theme_font_size_override("font_size", 12)
	resize_btn.pressed.connect(_on_resize_level_pressed)
	top_hbox.add_child(resize_btn)

	top_hbox.add_child(VSeparator.new())

	_actor_picker_btn = Button.new()
	_actor_picker_btn.text = "Place Actor..."
	_actor_picker_btn.tooltip_text = "Open the visual actor picker"
	_actor_picker_btn.add_theme_font_size_override("font_size", 11)
	var apb_s = StyleBoxFlat.new()
	apb_s.bg_color = Color(0.20, 0.22, 0.28)
	apb_s.set_corner_radius_all(4)
	apb_s.content_margin_left = 10; apb_s.content_margin_right = 10
	apb_s.content_margin_top = 3; apb_s.content_margin_bottom = 3
	_actor_picker_btn.add_theme_stylebox_override("normal", apb_s)
	_actor_picker_btn.add_theme_color_override("font_color", LABEL_CLR)
	_actor_picker_btn.add_theme_color_override("font_hover_color", WHITE)
	_actor_picker_btn.pressed.connect(_on_actor_picker_pressed)
	top_hbox.add_child(_actor_picker_btn)

	_actor_picker_popup = PopupPanel.new()
	var pp_sb = StyleBoxFlat.new()
	pp_sb.bg_color = Color(0.12, 0.12, 0.16)
	pp_sb.border_color = Color(0.35, 0.35, 0.45)
	pp_sb.set_border_width_all(1)
	pp_sb.set_corner_radius_all(6)
	pp_sb.content_margin_left = 8; pp_sb.content_margin_right = 8
	pp_sb.content_margin_top = 8; pp_sb.content_margin_bottom = 8
	_actor_picker_popup.add_theme_stylebox_override("panel", pp_sb)
	add_child(_actor_picker_popup)

	var picker_scroll = ScrollContainer.new()
	picker_scroll.custom_minimum_size = Vector2(440, 320)
	_actor_picker_popup.add_child(picker_scroll)
	_apply_dark_scrollbar_theme(picker_scroll)

	_actor_picker_grid = GridContainer.new()
	_actor_picker_grid.columns = 4
	_actor_picker_grid.add_theme_constant_override("h_separation", 6)
	_actor_picker_grid.add_theme_constant_override("v_separation", 6)
	picker_scroll.add_child(_actor_picker_grid)

	_rebuild_actor_picker()

	top_hbox.add_child(VSeparator.new())

	_waypoint_btn = Button.new()
	_waypoint_btn.text = "\U0001F4CD Waypoints"
	_waypoint_btn.tooltip_text = "Toggle waypoint mode — click an actor or block to start editing its path, then right-click to place waypoints"
	_waypoint_btn.add_theme_font_size_override("font_size", 11)
	_waypoint_btn.toggle_mode = true
	_waypoint_btn.button_pressed = false
	var wp_ns = StyleBoxFlat.new()
	wp_ns.bg_color = Color(0.18, 0.18, 0.22)
	wp_ns.set_corner_radius_all(4)
	wp_ns.content_margin_left = 8; wp_ns.content_margin_right = 8
	wp_ns.content_margin_top = 3;  wp_ns.content_margin_bottom = 3
	_waypoint_btn.add_theme_stylebox_override("normal", wp_ns)
	var wp_ps = wp_ns.duplicate()
	wp_ps.bg_color = Color(0.85, 0.45, 0.10)
	wp_ps.border_width_bottom = 2; wp_ps.border_color = Color(1.0, 0.6, 0.1)
	_waypoint_btn.add_theme_stylebox_override("pressed", wp_ps)
	var wp_hs = wp_ns.duplicate()
	wp_hs.bg_color = Color(0.25, 0.22, 0.18)
	_waypoint_btn.add_theme_stylebox_override("hover", wp_hs)
	_waypoint_btn.add_theme_color_override("font_color", LABEL_CLR)
	_waypoint_btn.add_theme_color_override("font_pressed_color", WHITE)
	_waypoint_btn.add_theme_color_override("font_hover_color", WHITE)
	_waypoint_btn.toggled.connect(_on_waypoint_mode_toggled)
	top_hbox.add_child(_waypoint_btn)

	# Flood-fill (bucket) button
	_flood_btn = Button.new()
	_flood_btn.text = "\U0001FAA3 Fill"
	_flood_btn.tooltip_text = "Flood fill — click a tile and every connected tile of the same type gets replaced"
	_flood_btn.add_theme_font_size_override("font_size", 11)
	_flood_btn.toggle_mode = true
	_flood_btn.button_pressed = false
	var fl_ns = StyleBoxFlat.new()
	fl_ns.bg_color = Color(0.18, 0.18, 0.22)
	fl_ns.set_corner_radius_all(4)
	fl_ns.content_margin_left = 8; fl_ns.content_margin_right = 8
	fl_ns.content_margin_top = 3;  fl_ns.content_margin_bottom = 3
	_flood_btn.add_theme_stylebox_override("normal", fl_ns)
	var fl_ps = fl_ns.duplicate()
	fl_ps.bg_color = Color(0.20, 0.55, 0.85)
	fl_ps.border_width_bottom = 2; fl_ps.border_color = Color(0.3, 0.7, 1.0)
	_flood_btn.add_theme_stylebox_override("pressed", fl_ps)
	var fl_hs = fl_ns.duplicate()
	fl_hs.bg_color = Color(0.18, 0.25, 0.30)
	_flood_btn.add_theme_stylebox_override("hover", fl_hs)
	_flood_btn.add_theme_color_override("font_color", LABEL_CLR)
	_flood_btn.add_theme_color_override("font_pressed_color", WHITE)
	_flood_btn.add_theme_color_override("font_hover_color", WHITE)
	_flood_btn.toggled.connect(func(pressed: bool): _flood_fill_mode = pressed)
	top_hbox.add_child(_flood_btn)

	# Dirty indicator
	_dirty_lbl = Label.new()
	_dirty_lbl.text = ""
	_dirty_lbl.label_settings = _ls(12, Color(1, 0.7, 0.2))
	top_hbox.add_child(_dirty_lbl)

	# ---- BLOCK TYPE TABS ----
	var type_bar = PanelContainer.new()
	var type_style = StyleBoxFlat.new()
	type_style.bg_color = Color(0.08, 0.08, 0.10)
	type_style.content_margin_left = 8
	type_style.content_margin_right = 8
	type_style.content_margin_top = 4
	type_style.content_margin_bottom = 4
	type_bar.add_theme_stylebox_override("panel", type_style)
	type_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(type_bar)

	var type_hbox = HBoxContainer.new()
	type_hbox.add_theme_constant_override("separation", 4)
	type_bar.add_child(type_hbox)

	var type_lbl = Label.new()
	type_lbl.text = "Block Type:"
	type_lbl.label_settings = _ls(11, DIM)
	type_hbox.add_child(type_lbl)

	for i in range(BLOCK_NAMES.size()):
		var btn = Button.new()
		btn.text = BLOCK_ICONS[i] + " " + BLOCK_NAMES[i]
		btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_block)
		btn.pressed.connect(_on_block_selected.bind(i))
		btn.custom_minimum_size = Vector2(0, 26)

		var ns = StyleBoxFlat.new()
		ns.bg_color = BLOCK_COLORS[i].darkened(0.5)
		ns.set_corner_radius_all(4)
		ns.content_margin_left = 6
		ns.content_margin_right = 6
		ns.content_margin_top = 2
		ns.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", ns)

		var ps = ns.duplicate()
		ps.bg_color = BLOCK_COLORS[i]
		ps.border_width_bottom = 3
		ps.border_color = WHITE
		btn.add_theme_stylebox_override("pressed", ps)

		var hs = ns.duplicate()
		hs.bg_color = BLOCK_COLORS[i].darkened(0.2)
		btn.add_theme_stylebox_override("hover", hs)

		btn.add_theme_color_override("font_color", WHITE)
		btn.add_theme_color_override("font_pressed_color", WHITE)
		btn.add_theme_color_override("font_hover_color", WHITE)

		type_hbox.add_child(btn)
		_block_btns.append(btn)

	# ---- TILE PALETTE ----
	var pal_bar = PanelContainer.new()
	var pal_style = StyleBoxFlat.new()
	pal_style.bg_color = Color(0.09, 0.09, 0.12)
	pal_style.content_margin_left = 8
	pal_style.content_margin_right = 8
	pal_style.content_margin_top = 4
	pal_style.content_margin_bottom = 4
	pal_bar.add_theme_stylebox_override("panel", pal_style)
	pal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(pal_bar)

	var pal_vbox = VBoxContainer.new()
	pal_vbox.add_theme_constant_override("separation", 2)
	pal_bar.add_child(pal_vbox)

	var pal_header = HBoxContainer.new()
	pal_header.add_theme_constant_override("separation", 6)
	pal_vbox.add_child(pal_header)

	var pal_lbl = Label.new()
	pal_lbl.text = "Tiles -- click to select, double-click to edit"
	pal_lbl.label_settings = _ls(10, DIM)
	pal_header.add_child(pal_lbl)

	_tile_filter = LineEdit.new()
	_tile_filter.placeholder_text = "\U0001F50D Search tiles..."
	_tile_filter.tooltip_text = "Type a name to filter the tile palette"
	_tile_filter.custom_minimum_size.x = 120
	_tile_filter.add_theme_font_size_override("font_size", 10)
	var tf_style = StyleBoxFlat.new()
	tf_style.bg_color = Color(0.12, 0.12, 0.15)
	tf_style.set_corner_radius_all(3)
	tf_style.content_margin_left = 6; tf_style.content_margin_right = 6
	tf_style.content_margin_top = 2;  tf_style.content_margin_bottom = 2
	tf_style.border_width_bottom = 1; tf_style.border_color = Color(0.30, 0.30, 0.35)
	_tile_filter.add_theme_stylebox_override("normal", tf_style)
	_tile_filter.add_theme_color_override("font_color", WHITE)
	_tile_filter.add_theme_color_override("font_placeholder_color", DIM)
	_tile_filter.text_changed.connect(func(_t): _rebuild_tile_palette())
	pal_header.add_child(_tile_filter)

	var import_tile_btn = Button.new()
	import_tile_btn.text = "📂 Import"
	import_tile_btn.tooltip_text = "Import tile(s) from PNG file(s) into the current block type"
	import_tile_btn.add_theme_font_size_override("font_size", 10)
	var itb_s = StyleBoxFlat.new()
	itb_s.bg_color = Color(0.35, 0.45, 0.60)
	itb_s.set_corner_radius_all(3)
	itb_s.content_margin_left = 6; itb_s.content_margin_right = 6
	itb_s.content_margin_top = 2;  itb_s.content_margin_bottom = 2
	import_tile_btn.add_theme_stylebox_override("normal", itb_s)
	import_tile_btn.add_theme_color_override("font_color", WHITE)
	import_tile_btn.pressed.connect(_on_import_tile_pressed)
	pal_header.add_child(import_tile_btn)

	_tile_palette_scroll = ScrollContainer.new()
	_tile_palette_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tile_palette_scroll.custom_minimum_size.y = 52
	_tile_palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pal_vbox.add_child(_tile_palette_scroll)

	_tile_palette = HBoxContainer.new()
	_tile_palette.add_theme_constant_override("separation", 4)
	_tile_palette_scroll.add_child(_tile_palette)

	# ---- GRID CANVAS (scrollable + zoomable) ----
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var gs_style = StyleBoxFlat.new()
	gs_style.bg_color = Color(0.08, 0.08, 0.10)
	_grid_scroll.add_theme_stylebox_override("panel", gs_style)
	add_child(_grid_scroll)

	_grid_canvas = Control.new()
	# Initial size based on the first level's dims; _apply_zoom() refreshes
	# this whenever the user resizes the level or switches levels.
	_grid_canvas.custom_minimum_size = Vector2(_lvl_w() * BASE_CELL_PX + 2, _lvl_h() * BASE_CELL_PX + 2)
	_grid_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_canvas.draw.connect(_draw_grid)
	_grid_canvas.gui_input.connect(_on_grid_input)
	_grid_canvas.focus_mode = Control.FOCUS_CLICK
	_grid_scroll.add_child(_grid_canvas)

	# ---- BOTTOM BAR ----
	var bot_bar = PanelContainer.new()
	var bb_style = StyleBoxFlat.new()
	bb_style.bg_color = TOOLBAR_BG
	bb_style.content_margin_left = 10
	bb_style.content_margin_right = 10
	bb_style.content_margin_top = 4
	bb_style.content_margin_bottom = 4
	bot_bar.add_theme_stylebox_override("panel", bb_style)
	bot_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(bot_bar)

	var bot_hbox = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 8)
	bot_bar.add_child(bot_hbox)

	var f_lbl = Label.new()
	f_lbl.text = "Friction:"
	f_lbl.label_settings = _ls(11, DIM)
	bot_hbox.add_child(f_lbl)
	_fric_slider = HSlider.new()
	_fric_slider.min_value = 0
	_fric_slider.max_value = 100
	_fric_slider.value = 50
	_fric_slider.custom_minimum_size.x = 80
	_fric_slider.value_changed.connect(_on_friction_changed)
	bot_hbox.add_child(_fric_slider)

	var e_lbl = Label.new()
	e_lbl.text = "Elasticity:"
	e_lbl.label_settings = _ls(11, DIM)
	bot_hbox.add_child(e_lbl)
	_elast_slider = HSlider.new()
	_elast_slider.min_value = 0
	_elast_slider.max_value = 100
	_elast_slider.value = 50
	_elast_slider.custom_minimum_size.x = 80
	_elast_slider.value_changed.connect(_on_elasticity_changed)
	bot_hbox.add_child(_elast_slider)

	bot_hbox.add_child(VSeparator.new())

	var da_lbl = Label.new()
	da_lbl.text = "On Death:"
	da_lbl.label_settings = _ls(11, DIM)
	bot_hbox.add_child(da_lbl)
	_death_action_opt = OptionButton.new()
	_death_action_opt.add_theme_font_size_override("font_size", 11)
	_death_action_opt.add_item("Restart Level")
	_death_action_opt.add_item("Go To Level...")
	_death_action_opt.add_item("Lose Item...")
	_death_action_opt.add_item("End Game")
	_death_action_opt.item_selected.connect(_on_death_action_changed)
	bot_hbox.add_child(_death_action_opt)
	_style_option(_death_action_opt)

	_death_target_lbl = Label.new()
	_death_target_lbl.text = "→ Lvl:"
	_death_target_lbl.label_settings = _ls(11, DIM)
	_death_target_lbl.visible = false
	bot_hbox.add_child(_death_target_lbl)
	_death_target_spin = SpinBox.new()
	_death_target_spin.min_value = 1
	_death_target_spin.max_value = MAX_LEVELS
	_death_target_spin.value = 1
	_death_target_spin.custom_minimum_size.x = 60
	_death_target_spin.add_theme_font_size_override("font_size", 11)
	_death_target_spin.visible = false
	_death_target_spin.value_changed.connect(_on_death_target_changed)
	bot_hbox.add_child(_death_target_spin)

	bot_hbox.add_child(VSeparator.new())

	_status_lbl = Label.new()
	_status_lbl.text = "LClick=paint | RClick=place actor | Shift+RClick=add waypoint | Ctrl+RClick=remove"
	_status_lbl.label_settings = _ls(10, LABEL_CLR)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hbox.add_child(_status_lbl)

	bot_hbox.add_child(VSeparator.new())
	_zoom_lbl = Label.new()
	_zoom_lbl.text = "100%"
	_zoom_lbl.label_settings = _ls(10, ACCENT)
	_zoom_lbl.tooltip_text = "Zoom level — Shift+Scroll to zoom in/out"
	bot_hbox.add_child(_zoom_lbl)

	_refresh_level_list()
	_refresh_ui()
	_rebuild_tile_palette()

	# Confirmation dialog (reusable)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Are you sure?"
	_confirm_dialog.unresizable = true
	_confirm_dialog.confirmed.connect(func():
		if _pending_confirm_action.is_valid():
			_pending_confirm_action.call()
	)
	add_child(_confirm_dialog)


# ─── Tile Palette ────────────────────────────────────────────

func _rebuild_tile_palette() -> void:
	if not is_instance_valid(_tile_palette):
		return
	for c in _tile_palette.get_children():
		c.queue_free()
	_tile_btns.clear()

	if not tile_library:
		var lbl = Label.new()
		lbl.text = "(Tile library loading...)"
		lbl.label_settings = _ls(10, DIM)
		_tile_palette.add_child(lbl)
		return

	if selected_block == BLOCK_EMPTY:
		var lbl = Label.new()
		lbl.text = "Empty -- eraser (click grid to clear tiles)"
		lbl.label_settings = _ls(10, DIM)
		_tile_palette.add_child(lbl)
		return

	var tile_count = tile_library.get_tile_count(selected_block)
	if tile_count == 0:
		var lbl = Label.new()
		lbl.text = "(No tiles for " + BLOCK_NAMES[selected_block] + ")"
		lbl.label_settings = _ls(10, DIM)
		_tile_palette.add_child(lbl)
		return

	var filter_text: String = ""
	if is_instance_valid(_tile_filter):
		filter_text = _tile_filter.text.strip_edges().to_lower()

	for i in range(tile_count):
		var tex = tile_library.get_tile_texture(selected_block, i)
		var tname = tile_library.get_tile_name(selected_block, i)

		# Filter by name if search text is entered
		if filter_text.length() > 0 and tname.to_lower().find(filter_text) < 0:
			continue

		var btn_container = VBoxContainer.new()
		btn_container.add_theme_constant_override("separation", 1)

		var btn = Button.new()
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_tile_index)
		btn.tooltip_text = tname + " -- Double-click to edit"
		btn.custom_minimum_size = Vector2(40, 40)

		var ns = StyleBoxFlat.new()
		ns.bg_color = Color(0.15, 0.15, 0.18)
		ns.set_corner_radius_all(4)
		ns.content_margin_left = 2
		ns.content_margin_right = 2
		ns.content_margin_top = 2
		ns.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", ns)

		var ps = ns.duplicate()
		ps.bg_color = BLOCK_COLORS[selected_block].darkened(0.2)
		ps.border_width_bottom = 3
		ps.border_color = ACCENT
		btn.add_theme_stylebox_override("pressed", ps)

		var hs = ns.duplicate()
		hs.bg_color = Color(0.20, 0.20, 0.25)
		btn.add_theme_stylebox_override("hover", hs)

		if tex:
			var tex_rect = TextureRect.new()
			tex_rect.texture = tex
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.custom_minimum_size = Vector2(36, 36)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tex_rect)

		btn.pressed.connect(_on_tile_selected.bind(i))
		btn.gui_input.connect(_on_tile_btn_input.bind(i))

		btn_container.add_child(btn)

		var name_lbl = Label.new()
		name_lbl.text = tname
		name_lbl.label_settings = _ls(8, DIM)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.custom_minimum_size.x = 40
		name_lbl.clip_text = true
		btn_container.add_child(name_lbl)

		_tile_palette.add_child(btn_container)
		_tile_btns.append(btn)


func _on_tile_selected(idx: int) -> void:
	selected_tile_index = idx
	selected_actor = -1
	if is_instance_valid(_actor_picker_btn):
		_actor_picker_btn.text = "Place Actor..."
		_actor_picker_btn.icon = null
	for i in range(_tile_btns.size()):
		_tile_btns[i].button_pressed = (i == idx)
	var tname = ""
	if tile_library:
		tname = tile_library.get_tile_name(selected_block, idx)
	_status_lbl.text = "Selected: " + BLOCK_NAMES[selected_block] + " -> " + tname


func _on_tile_btn_input(event: InputEvent, tile_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_open_inline_tile_editor(selected_block, tile_idx)


# ─── Drawing ─────────────────────────────────────────────────

func _draw_grid() -> void:
	if not is_instance_valid(_grid_canvas):
		return
	var canvas_size = _grid_canvas.size
	if canvas_size.x < 10 or canvas_size.y < 10:
		return

	var gw: int = _lvl_w()
	var gh: int = _lvl_h()
	var cw: float = canvas_size.x / float(gw)
	var ch: float = canvas_size.y / float(gh)
	var cs: float = minf(cw, ch)
	var ox: float = (canvas_size.x - cs * gw) * 0.5
	var oy: float = (canvas_size.y - cs * gh) * 0.5

	_grid_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.08, 0.08, 0.10))

	var lvl = levels[selected_level]
	var grid: Array = lvl["grid"]

	# Draw cells with WYSIWYG textures
	for y in range(gh):
		for x in range(gw):
			var cell = grid[y][x]
			var block_type: int = 0
			var tile_idx: int = 0

			if cell is Dictionary:
				block_type = cell.get("block_type", 0)
				tile_idx = cell.get("tile_index", 0)
			elif cell is int or cell is float:
				block_type = int(cell)
				tile_idx = 0

			var rect = Rect2(ox + x * cs, oy + y * cs, cs, cs)

			if block_type == BLOCK_EMPTY:
				_grid_canvas.draw_rect(rect, BLOCK_COLORS[BLOCK_EMPTY])
			else:
				var tex: Texture2D = null
				if tile_library:
					tex = tile_library.get_tile_texture(block_type, tile_idx)

				if tex:
					_grid_canvas.draw_texture_rect(tex, rect, false)
					# Color-coded outline at 35% alpha for block type hints
					var outline_color = BLOCK_COLORS[block_type]
					outline_color.a = 0.35
					_grid_canvas.draw_rect(rect, outline_color, false, 2.0)
				else:
					_grid_canvas.draw_rect(rect, BLOCK_COLORS[block_type])

			_grid_canvas.draw_rect(rect, GRID_LINE, false, 1.0)

	# Actor markers with sprites
	for actor_data in lvl["actors"]:
		var ax: int = actor_data.get("x", 0)
		var ay: int = actor_data.get("y", 0)
		var aid: int = actor_data.get("actor_id", 0)
		var m: float = cs * 0.08
		var actor_rect = Rect2(ox + ax * cs + m, oy + ay * cs + m, cs - m * 2, cs - m * 2)

		var actor_tex: Texture2D = null
		if tile_library:
			actor_tex = tile_library.get_actor_texture(aid)

		if actor_tex:
			_grid_canvas.draw_texture_rect(actor_tex, actor_rect, false)
			_grid_canvas.draw_rect(actor_rect, Color(1.0, 0.9, 0.3, 0.6), false, 2.0)
		else:
			_grid_canvas.draw_rect(actor_rect, Color(1.0, 0.8, 0.2, 0.8))
			_grid_canvas.draw_rect(actor_rect, Color(1.0, 0.9, 0.3), false, 2.0)

		var path: Array = actor_data.get("path", [])
		if path.size() > 1:
			var path_color = Color(1, 0.5, 0, 0.8)
			var dot_color = Color(1, 0.7, 0.2, 0.9)
			for i in range(path.size() - 1):
				var p1x = path[i]["x"] if path[i] is Dictionary else path[i].x
				var p1y = path[i]["y"] if path[i] is Dictionary else path[i].y
				var p2x = path[i + 1]["x"] if path[i + 1] is Dictionary else path[i + 1].x
				var p2y = path[i + 1]["y"] if path[i + 1] is Dictionary else path[i + 1].y
				var p1 = Vector2(ox + p1x * cs + cs * 0.5, oy + p1y * cs + cs * 0.5)
				var p2 = Vector2(ox + p2x * cs + cs * 0.5, oy + p2y * cs + cs * 0.5)
				_grid_canvas.draw_line(p1, p2, path_color, 2.0)
			# Draw waypoint dots
			for i in range(path.size()):
				var px = path[i]["x"] if path[i] is Dictionary else path[i].x
				var py = path[i]["y"] if path[i] is Dictionary else path[i].y
				var center = Vector2(ox + px * cs + cs * 0.5, oy + py * cs + cs * 0.5)
				_grid_canvas.draw_circle(center, cs * 0.15, dot_color)
				# Draw waypoint number
				if i > 0:
					_grid_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-3, 4), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.BLACK)

	# Draw block paths (moving platform waypoints)
	var block_paths: Dictionary = lvl.get("block_paths", {})
	for bp_key in block_paths:
		var bp_path: Array = block_paths[bp_key]
		if bp_path.size() < 2:
			continue
		var bp_color = Color(0.3, 0.7, 1.0, 0.8)
		var bp_dot = Color(0.4, 0.85, 1.0, 0.9)
		for i in range(bp_path.size() - 1):
			var p1x = bp_path[i]["x"] if bp_path[i] is Dictionary else bp_path[i].x
			var p1y = bp_path[i]["y"] if bp_path[i] is Dictionary else bp_path[i].y
			var p2x = bp_path[i + 1]["x"] if bp_path[i + 1] is Dictionary else bp_path[i + 1].x
			var p2y = bp_path[i + 1]["y"] if bp_path[i + 1] is Dictionary else bp_path[i + 1].y
			var p1 = Vector2(ox + p1x * cs + cs * 0.5, oy + p1y * cs + cs * 0.5)
			var p2 = Vector2(ox + p2x * cs + cs * 0.5, oy + p2y * cs + cs * 0.5)
			_grid_canvas.draw_line(p1, p2, bp_color, 2.0)
		for i in range(bp_path.size()):
			var ppx = bp_path[i]["x"] if bp_path[i] is Dictionary else bp_path[i].x
			var ppy = bp_path[i]["y"] if bp_path[i] is Dictionary else bp_path[i].y
			var center = Vector2(ox + ppx * cs + cs * 0.5, oy + ppy * cs + cs * 0.5)
			_grid_canvas.draw_circle(center, cs * 0.12, bp_dot)
			if i > 0:
				_grid_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-3, 4), str(i), HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color.BLACK)

	# Waypoint mode visual overlay
	if _waypoint_mode and _last_mouse_pos != Vector2.ZERO:
		var wp_gp = _grid_pos(_last_mouse_pos)
		# Draw cursor cell with orange highlight
		var wp_rect = Rect2(ox + wp_gp.x * cs, oy + wp_gp.y * cs, cs, cs)
		_grid_canvas.draw_rect(wp_rect, Color(1.0, 0.5, 0.0, 0.3))
		_grid_canvas.draw_rect(wp_rect, Color(1.0, 0.6, 0.1, 0.8), false, 2.0)
		var wp_center = wp_rect.position + wp_rect.size * 0.5
		_grid_canvas.draw_circle(wp_center - Vector2(0, cs * 0.1), cs * 0.12, Color(1.0, 0.5, 0.0, 0.9))
		_grid_canvas.draw_circle(wp_center - Vector2(0, cs * 0.1), cs * 0.06, Color(1.0, 0.8, 0.3))
		# Highlight locked target with glowing outline
		if _waypoint_target_type == "actor" and _waypoint_actor_idx >= 0 and _waypoint_actor_idx < lvl["actors"].size():
			var na = lvl["actors"][_waypoint_actor_idx]
			var na_rect = Rect2(ox + na["x"] * cs, oy + na["y"] * cs, cs, cs)
			_grid_canvas.draw_rect(na_rect, Color(1.0, 0.5, 0.0, 0.6), false, 3.0)
			var na_path: Array = na.get("path", [])
			var line_start: Vector2
			if na_path.size() > 0:
				var last_wp = na_path[na_path.size() - 1]
				var lwx = last_wp["x"] if last_wp is Dictionary else last_wp.x
				var lwy = last_wp["y"] if last_wp is Dictionary else last_wp.y
				line_start = Vector2(ox + lwx * cs + cs * 0.5, oy + lwy * cs + cs * 0.5)
			else:
				line_start = Vector2(ox + na["x"] * cs + cs * 0.5, oy + na["y"] * cs + cs * 0.5)
			_grid_canvas.draw_dashed_line(line_start, wp_center, Color(1.0, 0.6, 0.1, 0.5), 2.0, 4.0)
		elif _waypoint_target_type == "block" and _waypoint_block_pos.x >= 0:
			var bx = _waypoint_block_pos.x
			var by = _waypoint_block_pos.y
			var b_rect = Rect2(ox + bx * cs, oy + by * cs, cs, cs)
			_grid_canvas.draw_rect(b_rect, Color(0.3, 0.7, 1.0, 0.6), false, 3.0)
			var bp_key = str(bx) + "," + str(by)
			var b_path: Array = lvl.get("block_paths", {}).get(bp_key, [])
			var bline_start: Vector2
			if b_path.size() > 0:
				var last_bp = b_path[b_path.size() - 1]
				var lbx = last_bp["x"] if last_bp is Dictionary else last_bp.x
				var lby = last_bp["y"] if last_bp is Dictionary else last_bp.y
				bline_start = Vector2(ox + lbx * cs + cs * 0.5, oy + lby * cs + cs * 0.5)
			else:
				bline_start = Vector2(ox + bx * cs + cs * 0.5, oy + by * cs + cs * 0.5)
			_grid_canvas.draw_dashed_line(bline_start, wp_center, Color(0.3, 0.7, 1.0, 0.5), 2.0, 4.0)


func _grid_pos(pixel_pos: Vector2) -> Vector2i:
	var canvas_size = _grid_canvas.size
	var gw: int = _lvl_w()
	var gh: int = _lvl_h()
	var cw: float = canvas_size.x / float(gw)
	var ch: float = canvas_size.y / float(gh)
	var cs: float = minf(cw, ch)
	var ox: float = (canvas_size.x - cs * gw) * 0.5
	var oy: float = (canvas_size.y - cs * gh) * 0.5
	var gx: int = int((pixel_pos.x - ox) / cs)
	var gy: int = int((pixel_pos.y - oy) / cs)
	return Vector2i(clampi(gx, 0, gw - 1), clampi(gy, 0, gh - 1))


func _apply_zoom() -> void:
	if not is_instance_valid(_grid_canvas):
		return
	_grid_canvas.custom_minimum_size = Vector2(
		_lvl_w() * BASE_CELL_PX * _zoom + 2,
		_lvl_h() * BASE_CELL_PX * _zoom + 2
	)
	_grid_canvas.queue_redraw()
	if is_instance_valid(_zoom_lbl):
		_zoom_lbl.text = str(int(_zoom * 100)) + "%"
	if is_instance_valid(_status_lbl):
		_status_lbl.text = "Zoom: " + str(int(_zoom * 100)) + "% — Shift+Scroll to adjust"


func _on_grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey):
		return
	# Keyboard shortcuts: Ctrl+Z = Undo, Ctrl+Y / Ctrl+Shift+Z = Redo
	# Delete = remove actor or waypoint under cursor
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
			_undo()
			return
		if event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
			_redo()
			return
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_actor_or_waypoint_at_cursor()
			return
	if event is InputEventMouseButton:
		# Shift+Scroll Wheel: zoom in/out
		if event.shift_pressed and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_zoom()
				_grid_canvas.accept_event()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_zoom()
				_grid_canvas.accept_event()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _waypoint_mode:
					# In waypoint mode: left-click selects target actor or block
					_waypoint_select_target(event.position)
				elif _flood_fill_mode:
					_begin_stroke()
					_flood_fill_at(event.position)
					_end_stroke()
				else:
					# Take snapshot before starting a paint stroke
					_begin_stroke()
					is_painting = true
					_paint_at(event.position)
			else:
				# End stroke — commit the snapshot if grid changed
				is_painting = false
				_end_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _waypoint_mode:
				# Waypoint mode: must have a locked target
				if _waypoint_target_type.is_empty():
					_status_lbl.text = "📍 Click an actor or block first to lock waypoint target"
				elif event.ctrl_pressed:
					_begin_stroke()
					_remove_last_waypoint()
					_end_stroke()
				else:
					_begin_stroke()
					_add_waypoint(event.position)
					_end_stroke()
			elif event.ctrl_pressed:
				# Ctrl+Right-click: remove actor
				_begin_stroke()
				_remove_actor_at(event.position)
				_end_stroke()
			elif selected_actor >= 0:
				_begin_stroke()
				_place_actor(event.position)
				_end_stroke()
	elif event is InputEventMouseMotion:
		if is_painting:
			_paint_at(event.position)
		# Track cursor position for Delete key
		_last_mouse_pos = event.position
		# Redraw for waypoint cursor overlay
		if _waypoint_mode:
			_grid_canvas.queue_redraw()


## Take a snapshot of the current level's grid + actors for undo.
func _begin_stroke() -> void:
	var lvl = levels[selected_level]
	_stroke_snapshot = {
		"level": selected_level,
		"grid": lvl["grid"].duplicate(true),
		"actors": lvl["actors"].duplicate(true),
		"block_paths": lvl.get("block_paths", {}).duplicate(true),
	}


## Commit the snapshot if the grid actually changed.
func _end_stroke() -> void:
	if _stroke_snapshot == null:
		return
	var lvl = levels[selected_level]
	# Only push to undo if something changed
	if lvl["grid"] != _stroke_snapshot["grid"] or lvl["actors"] != _stroke_snapshot["actors"] or lvl.get("block_paths", {}) != _stroke_snapshot.get("block_paths", {}):
		_undo_stack.append(_stroke_snapshot)
		if _undo_stack.size() > MAX_UNDO:
			_undo_stack.pop_front()
		_redo_stack.clear()
	_stroke_snapshot = null


func _undo() -> void:
	if _undo_stack.is_empty():
		_status_lbl.text = "Nothing to undo"
		return
	var snap = _undo_stack.pop_back()
	var lvl_idx: int = snap["level"]
	# Push current state to redo
	_redo_stack.append({
		"level": lvl_idx,
		"grid": levels[lvl_idx]["grid"].duplicate(true),
		"actors": levels[lvl_idx]["actors"].duplicate(true),
		"block_paths": levels[lvl_idx].get("block_paths", {}).duplicate(true),
	})
	# Restore
	levels[lvl_idx]["grid"] = snap["grid"]
	levels[lvl_idx]["actors"] = snap["actors"]
	levels[lvl_idx]["block_paths"] = snap.get("block_paths", {})
	if lvl_idx == selected_level:
		_grid_canvas.queue_redraw()
	_status_lbl.text = "Undo (" + str(_undo_stack.size()) + " remaining)"
	level_changed.emit(selected_level)


func _redo() -> void:
	if _redo_stack.is_empty():
		_status_lbl.text = "Nothing to redo"
		return
	var snap = _redo_stack.pop_back()
	var lvl_idx: int = snap["level"]
	# Push current state to undo
	_undo_stack.append({
		"level": lvl_idx,
		"grid": levels[lvl_idx]["grid"].duplicate(true),
		"actors": levels[lvl_idx]["actors"].duplicate(true),
		"block_paths": levels[lvl_idx].get("block_paths", {}).duplicate(true),
	})
	# Restore
	levels[lvl_idx]["grid"] = snap["grid"]
	levels[lvl_idx]["actors"] = snap["actors"]
	levels[lvl_idx]["block_paths"] = snap.get("block_paths", {})
	if lvl_idx == selected_level:
		_grid_canvas.queue_redraw()
	_status_lbl.text = "Redo (" + str(_redo_stack.size()) + " remaining)"
	level_changed.emit(selected_level)


func _paint_at(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	if gp.x < 0 or gp.x >= _lvl_w() or gp.y < 0 or gp.y >= _lvl_h():
		return
	var lvl = levels[selected_level]
	var cell = lvl["grid"][gp.y][gp.x]

	if cell is Dictionary:
		cell["block_type"] = selected_block
		cell["tile_index"] = selected_tile_index if selected_block != BLOCK_EMPTY else 0
	else:
		lvl["grid"][gp.y][gp.x] = {
			"block_type": selected_block,
			"tile_index": selected_tile_index if selected_block != BLOCK_EMPTY else 0,
		}

	_grid_canvas.queue_redraw()
	var tname = ""
	if tile_library and selected_block != BLOCK_EMPTY:
		tname = " (" + tile_library.get_tile_name(selected_block, selected_tile_index) + ")"
	_status_lbl.text = "Painted " + BLOCK_NAMES[selected_block] + tname + " at (" + str(gp.x) + ", " + str(gp.y) + ")"
	_mark_dirty()
	level_changed.emit(selected_level)


## Flood fill — BFS replacing all connected cells of the same block type.
func _flood_fill_at(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	if gp.x < 0 or gp.x >= _lvl_w() or gp.y < 0 or gp.y >= _lvl_h():
		return
	var lvl = levels[selected_level]
	var grid: Array = lvl["grid"]
	var target_cell = grid[gp.y][gp.x]
	var target_bt: int = 0
	var target_ti: int = 0
	if target_cell is Dictionary:
		target_bt = target_cell.get("block_type", 0)
		target_ti = target_cell.get("tile_index", 0)
	elif target_cell is int or target_cell is float:
		target_bt = int(target_cell)
	# Don't fill if target is already the selected block+tile
	if target_bt == selected_block and target_ti == selected_tile_index:
		return
	var replace_ti: int = selected_tile_index if selected_block != BLOCK_EMPTY else 0
	var queue: Array = [gp]
	var visited: Dictionary = {}
	visited[gp] = true
	var filled: int = 0
	while queue.size() > 0:
		var p: Vector2i = queue.pop_front()
		var c = grid[p.y][p.x]
		var c_bt: int = 0
		var c_ti: int = 0
		if c is Dictionary:
			c_bt = c.get("block_type", 0)
			c_ti = c.get("tile_index", 0)
		elif c is int or c is float:
			c_bt = int(c)
		if c_bt != target_bt or c_ti != target_ti:
			continue
		grid[p.y][p.x] = {"block_type": selected_block, "tile_index": replace_ti}
		filled += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np: Vector2i = p + d
			if np.x >= 0 and np.x < _lvl_w() and np.y >= 0 and np.y < _lvl_h():
				if not visited.has(np):
					visited[np] = true
					queue.append(np)
	_grid_canvas.queue_redraw()
	var tname = ""
	if tile_library and selected_block != BLOCK_EMPTY:
		tname = " (" + tile_library.get_tile_name(selected_block, selected_tile_index) + ")"
	_status_lbl.text = "Flood-filled " + str(filled) + " tiles with " + BLOCK_NAMES[selected_block] + tname
	_mark_dirty()
	level_changed.emit(selected_level)


func _place_actor(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	if gp.x < 0 or gp.x >= _lvl_w() or gp.y < 0 or gp.y >= _lvl_h():
		return
	var lvl = levels[selected_level]
	lvl["actors"].append({"actor_id": selected_actor, "x": gp.x, "y": gp.y, "path": []})
	_grid_canvas.queue_redraw()
	var aname = actor_names[selected_actor] if selected_actor < actor_names.size() else "Actor"
	_status_lbl.text = "Placed " + aname + " at (" + str(gp.x) + ", " + str(gp.y) + ")"
	level_changed.emit(selected_level)


## Find the placed actor at an exact grid position, or -1.
func _find_actor_at(gp: Vector2i) -> int:
	var lvl = levels[selected_level]
	for i in range(lvl["actors"].size()):
		var a = lvl["actors"][i]
		if a["x"] == gp.x and a["y"] == gp.y:
			return i
	return -1


## Find the nearest placed actor within a max grid distance. Returns -1 if none close enough.
func _find_nearest_actor(gp: Vector2i, max_dist: float = 3.0) -> int:
	var lvl = levels[selected_level]
	var actors_arr: Array = lvl["actors"]
	var best_idx: int = -1
	var best_dist: float = max_dist * max_dist  # compare squared
	for i in range(actors_arr.size()):
		var a = actors_arr[i]
		var dx: float = a["x"] - gp.x
		var dy: float = a["y"] - gp.y
		var d: float = dx * dx + dy * dy
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


## Waypoint mode: left-click selects/locks target actor or block.
func _waypoint_select_target(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	var lvl = levels[selected_level]
	# First check for an actor at this exact position
	var actor_idx = _find_actor_at(gp)
	if actor_idx >= 0:
		_waypoint_actor_idx = actor_idx
		_waypoint_target_type = "actor"
		_waypoint_block_pos = Vector2i(-1, -1)
		var a = lvl["actors"][actor_idx]
		var aname = actor_names[a["actor_id"]] if a["actor_id"] < actor_names.size() else "Actor"
		_status_lbl.text = "📍 Locked to " + aname + " — RClick=add waypoint, Ctrl+RClick=undo last, click another to switch"
		_grid_canvas.queue_redraw()
		return
	# Check for a non-empty block at this position
	var cell = lvl["grid"][gp.y][gp.x]
	var block_type: int = 0
	if cell is Dictionary:
		block_type = cell.get("block_type", 0)
	elif cell is int or cell is float:
		block_type = int(cell)
	if block_type > 0:
		_waypoint_target_type = "block"
		_waypoint_block_pos = gp
		_waypoint_actor_idx = -1
		# Ensure block_paths dict exists
		if not lvl.has("block_paths"):
			lvl["block_paths"] = {}
		_status_lbl.text = "📍 Locked to " + BLOCK_NAMES[block_type] + " block at (" + str(gp.x) + "," + str(gp.y) + ") — RClick=add waypoint"
		_grid_canvas.queue_redraw()
		return
	_status_lbl.text = "📍 No actor or block at (" + str(gp.x) + ", " + str(gp.y) + ") — click on one to lock"


## Right-click in waypoint mode: add a waypoint to the locked target.
func _add_waypoint(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	if gp.x < 0 or gp.x >= _lvl_w() or gp.y < 0 or gp.y >= _lvl_h():
		return
	var lvl = levels[selected_level]

	if _waypoint_target_type == "actor" and _waypoint_actor_idx >= 0 and _waypoint_actor_idx < lvl["actors"].size():
		var actor_data = lvl["actors"][_waypoint_actor_idx]
		var path: Array = actor_data.get("path", [])
		# First waypoint = actor's own position (start of path)
		if path.is_empty():
			path.append({"x": actor_data["x"], "y": actor_data["y"]})
		path.append({"x": gp.x, "y": gp.y})
		actor_data["path"] = path
		_grid_canvas.queue_redraw()
		var aname = actor_names[actor_data["actor_id"]] if actor_data["actor_id"] < actor_names.size() else "Actor"
		_status_lbl.text = "Added waypoint " + str(path.size()) + " for " + aname + " at (" + str(gp.x) + ", " + str(gp.y) + ")"
		level_changed.emit(selected_level)

	elif _waypoint_target_type == "block" and _waypoint_block_pos.x >= 0:
		if not lvl.has("block_paths"):
			lvl["block_paths"] = {}
		var bp_key = str(_waypoint_block_pos.x) + "," + str(_waypoint_block_pos.y)
		var path: Array = lvl["block_paths"].get(bp_key, [])
		# First waypoint = block's own position
		if path.is_empty():
			path.append({"x": _waypoint_block_pos.x, "y": _waypoint_block_pos.y})
		path.append({"x": gp.x, "y": gp.y})
		lvl["block_paths"][bp_key] = path
		_grid_canvas.queue_redraw()
		_status_lbl.text = "Added waypoint " + str(path.size()) + " for block at (" + str(_waypoint_block_pos.x) + "," + str(_waypoint_block_pos.y) + ")"
		level_changed.emit(selected_level)
	else:
		_status_lbl.text = "📍 No target locked — click an actor or block first"


## Ctrl+Right-click in waypoint mode: remove the last waypoint from locked target.
func _remove_last_waypoint() -> void:
	var lvl = levels[selected_level]
	if _waypoint_target_type == "actor" and _waypoint_actor_idx >= 0 and _waypoint_actor_idx < lvl["actors"].size():
		var actor_data = lvl["actors"][_waypoint_actor_idx]
		var path: Array = actor_data.get("path", [])
		if path.size() > 0:
			path.pop_back()
			if path.size() <= 1:
				actor_data["path"] = []
			_grid_canvas.queue_redraw()
			var aname = actor_names[actor_data["actor_id"]] if actor_data["actor_id"] < actor_names.size() else "Actor"
			_status_lbl.text = "Removed last waypoint from " + aname + " (" + str(path.size()) + " pts)"
			level_changed.emit(selected_level)
		else:
			_status_lbl.text = "No waypoints to remove"
	elif _waypoint_target_type == "block" and _waypoint_block_pos.x >= 0:
		var bp_key = str(_waypoint_block_pos.x) + "," + str(_waypoint_block_pos.y)
		var bp_dict: Dictionary = lvl.get("block_paths", {})
		var path: Array = bp_dict.get(bp_key, [])
		if path.size() > 0:
			path.pop_back()
			if path.size() <= 1:
				bp_dict.erase(bp_key)
			else:
				bp_dict[bp_key] = path
			_grid_canvas.queue_redraw()
			_status_lbl.text = "Removed last waypoint from block (" + str(path.size()) + " pts)"
			level_changed.emit(selected_level)
		else:
			_status_lbl.text = "No waypoints to remove"
	else:
		_status_lbl.text = "No target locked"


## Ctrl+Right-click (non-waypoint mode): remove the actor at this position.
func _remove_actor_at(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	var lvl = levels[selected_level]
	for i in range(lvl["actors"].size()):
		var a = lvl["actors"][i]
		if a["x"] == gp.x and a["y"] == gp.y:
			var aname = actor_names[a["actor_id"]] if a["actor_id"] < actor_names.size() else "Actor"
			lvl["actors"].remove_at(i)
			_grid_canvas.queue_redraw()
			_status_lbl.text = "Removed " + aname + " from (" + str(gp.x) + ", " + str(gp.y) + ")"
			level_changed.emit(selected_level)
			return
	_status_lbl.text = "No actor at (" + str(gp.x) + ", " + str(gp.y) + ")"


## Delete/Backspace key: remove actor under cursor, or last waypoint if in waypoint mode.
func _delete_actor_or_waypoint_at_cursor() -> void:
	if _last_mouse_pos == Vector2.ZERO:
		return
	_begin_stroke()
	if _waypoint_mode and not _waypoint_target_type.is_empty():
		_remove_last_waypoint()
	else:
		_remove_actor_at(_last_mouse_pos)
	_end_stroke()

# ─── Dirty indicator ─────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true
	if is_instance_valid(_dirty_lbl):
		_dirty_lbl.text = "\u2022 unsaved"

func mark_clean() -> void:
	_dirty = false
	if is_instance_valid(_dirty_lbl):
		_dirty_lbl.text = ""

# ─── Confirmation helper ─────────────────────────────────────

func _ask_confirm(msg: String, action: Callable) -> void:
	if not is_instance_valid(_confirm_dialog):
		action.call()
		return
	_confirm_dialog.dialog_text = msg
	_pending_confirm_action = action
	_confirm_dialog.popup_centered()

# ─── Callbacks ───────────────────────────────────────────────

func _on_level_selected(idx: int) -> void:
	selected_level = idx
	_refresh_ui()

func _on_block_selected(idx: int) -> void:
	selected_block = idx
	selected_tile_index = 0
	selected_actor = -1
	if is_instance_valid(_actor_picker_btn):
		_actor_picker_btn.text = "Place Actor..."
		_actor_picker_btn.icon = null
	for i in range(_block_btns.size()):
		_block_btns[i].button_pressed = (i == idx)
	_status_lbl.text = "Block type: " + BLOCK_ICONS[idx] + " " + BLOCK_NAMES[idx]
	_rebuild_tile_palette()

func _on_waypoint_mode_toggled(pressed: bool) -> void:
	_waypoint_mode = pressed
	if pressed:
		_waypoint_actor_idx = -1
		_waypoint_target_type = ""
		_waypoint_block_pos = Vector2i(-1, -1)
		_status_lbl.text = "\U0001F4CD WAYPOINT MODE — Click an actor or block to lock, then RClick=add waypoints | Ctrl+RClick=undo last"
		_grid_canvas.queue_redraw()
	else:
		_waypoint_actor_idx = -1
		_waypoint_target_type = ""
		_waypoint_block_pos = Vector2i(-1, -1)
		_status_lbl.text = "LClick=paint | RClick=place actor | Ctrl+RClick=remove"
		_grid_canvas.queue_redraw()


func _on_actor_picker_pressed() -> void:
	if is_instance_valid(_actor_picker_popup):
		_rebuild_actor_picker()
		var btn_rect = _actor_picker_btn.get_global_rect()
		_actor_picker_popup.popup(Rect2i(
			int(btn_rect.position.x), int(btn_rect.position.y + btn_rect.size.y + 2),
			460, 340
		))

func _on_actor_picked(actor_idx: int) -> void:
	_actor_picker_popup.hide()
	if actor_idx < 0:
		selected_actor = -1
		_status_lbl.text = "Tile painting mode"
		_actor_picker_btn.text = "Place Actor..."
		_actor_picker_btn.icon = null
	else:
		selected_actor = actor_idx
		var aname: String = actor_names[actor_idx] if actor_idx < actor_names.size() else "Actor"
		_status_lbl.text = "Right-click to place " + aname + " - Left-click still paints tiles"
		_actor_picker_btn.text = aname
		if tile_library:
			var tex: Texture2D = tile_library.get_actor_texture(actor_idx)
			if tex:
				_actor_picker_btn.icon = tex
				_actor_picker_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Turn off waypoint mode when switching actor tool
	if _waypoint_mode:
		_waypoint_mode = false
		_waypoint_actor_idx = -1
		_waypoint_target_type = ""
		_waypoint_block_pos = Vector2i(-1, -1)
		if _waypoint_btn:
			_waypoint_btn.button_pressed = false

func _rebuild_actor_picker() -> void:
	if not is_instance_valid(_actor_picker_grid):
		return
	for c in _actor_picker_grid.get_children():
		c.queue_free()

	# -- Tiles mode card --
	var tiles_card = _make_picker_card(-1, "Tiles Mode", "", null, Color(0.5, 0.5, 0.55), selected_actor == -1)
	_actor_picker_grid.add_child(tiles_card)

	# -- Actor cards --
	for i in range(actor_names.size()):
		var aname: String = actor_names[i] if i < actor_names.size() else "Actor"
		var atype: String = actor_types[i] if i < actor_types.size() else "Drone"
		var color: Color = ACTOR_TYPE_COLORS.get(atype, DIM)
		var tex: Texture2D = null
		if tile_library:
			tile_library.ensure_actor_sprite(i, aname, atype)
			tex = tile_library.get_actor_texture(i)
		var is_sel: bool = (selected_actor == i)
		var anim_info: String = ""
		if tile_library:
			var sprite_data: Dictionary = tile_library.actor_sprites.get(i, {})
			var anims: Dictionary = sprite_data.get("anims", {})
			if anims.size() > 0:
				var parts: Array = []
				for anim_key in anims.keys():
					parts.append(str(anim_key) + "(" + str(anims[anim_key].size()) + ")")
				anim_info = ", ".join(parts)
		var card = _make_picker_card(i, aname, atype, tex, color, is_sel, anim_info)
		_actor_picker_grid.add_child(card)

func _make_picker_card(idx: int, aname: String, atype: String, tex: Texture2D, color: Color, is_selected: bool, anim_info: String = "") -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.26, 0.40) if is_selected else Color(0.16, 0.16, 0.20)
	style.set_corner_radius_all(6)
	style.border_width_left = 3
	style.border_color = color
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 6; style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(100, 90)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Sprite thumbnail
	if tex:
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)
	else:
		# Placeholder for tiles mode
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.25, 0.25, 0.30)
		placeholder.custom_minimum_size = Vector2(48, 48)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(placeholder)
		var grid_lbl = Label.new()
		grid_lbl.text = "#"
		grid_lbl.label_settings = _ls(20, DIM)
		grid_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.add_child(grid_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = aname
	name_lbl.label_settings = _ls(10, WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Type
	if atype != "":
		var type_lbl = Label.new()
		type_lbl.text = atype
		type_lbl.label_settings = _ls(9, color)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(type_lbl)

	# Anim info
	if anim_info != "":
		var anim_lbl = Label.new()
		anim_lbl.text = anim_info
		anim_lbl.label_settings = _ls(8, DIM)
		anim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		anim_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(anim_lbl)

	# Invisible click button
	var btn = Button.new()
	btn.flat = true
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_actor_picked.bind(idx))
	btn.mouse_entered.connect(func():
		style.bg_color = Color(0.28, 0.32, 0.48)
		card.queue_redraw()
	)
	btn.mouse_exited.connect(func():
		style.bg_color = Color(0.22, 0.26, 0.40) if (selected_actor == idx) else Color(0.16, 0.16, 0.20)
		card.queue_redraw()
	)
	card.add_child(btn)

	return card

func _on_name_changed(new_text: String) -> void:
	levels[selected_level]["name"] = new_text
	_refresh_level_list()

func _on_friction_changed(val: float) -> void:
	levels[selected_level]["material_friction"] = int(val)

func _on_elasticity_changed(val: float) -> void:
	levels[selected_level]["material_elasticity"] = int(val)

const DEATH_ACTION_NAMES: Array = ["Restart Level", "Go To Level", "Lose Item", "End Game"]

func _on_death_action_changed(idx: int) -> void:
	var action_name: String = DEATH_ACTION_NAMES[clampi(idx, 0, DEATH_ACTION_NAMES.size() - 1)]
	levels[selected_level]["death_action"] = action_name
	# Show/hide the target SpinBox (only visible for "Go To Level")
	var show_target: bool = (idx == 1)
	if is_instance_valid(_death_target_lbl):
		_death_target_lbl.visible = show_target
	if is_instance_valid(_death_target_spin):
		_death_target_spin.visible = show_target



func _on_death_target_changed(val: float) -> void:
	levels[selected_level]["death_action_target"] = int(val)

func _on_add_level() -> void:
	for i in range(levels.size()):
		var all_empty = true
		var grid = levels[i]["grid"]
		for row in grid:
			for cell in row:
				var bt = 0
				if cell is Dictionary:
					bt = cell.get("block_type", 0)
				elif cell is int or cell is float:
					bt = int(cell)
				if bt != BLOCK_EMPTY:
					all_empty = false
					break
			if not all_empty:
				break
		if all_empty and levels[i]["actors"].size() == 0:
			selected_level = i
			_level_opt.selected = i
			_refresh_ui()
			_status_lbl.text = "Selected empty level " + str(i + 1)
			return
	_status_lbl.text = "All " + str(MAX_LEVELS) + " levels are in use!"

func _on_dup_level() -> void:
	var next = selected_level + 1
	if next >= MAX_LEVELS:
		_status_lbl.text = "Cannot duplicate -- at max level"
		return
	levels[next] = levels[selected_level].duplicate(true)
	levels[next]["name"] = levels[selected_level]["name"] + " (copy)"
	selected_level = next
	_refresh_level_list()
	_level_opt.selected = selected_level
	_refresh_ui()

func _on_clear_level() -> void:
	_ask_confirm("Clear all tiles and actors from this level?", func():
		var keep_w := _lvl_w()
		var keep_h := _lvl_h()
		levels[selected_level] = _make_empty_level(selected_level + 1, keep_w, keep_h)
		_refresh_ui()
		_mark_dirty()
		_status_lbl.text = "Level cleared"
	)


# ─── Per-level resize ────────────────────────────────────────
# Pop a tiny modal with W/H spinners, default to current dims.
# On confirm: resize the active level's grid in-place, preserving
# overlapping cells. Actors and block-paths beyond the new bounds
# are dropped (with a status-bar count so the user knows).
func _on_resize_level_pressed() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Resize Level " + str(selected_level + 1)
	dlg.dialog_hide_on_ok = false
	dlg.add_cancel_button("Cancel")
	dlg.ok_button_text = "Apply"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var info := Label.new()
	info.text = "Width  (cells, " + str(MIN_GRID_W) + "–" + str(MAX_GRID_W) + ")"
	vbox.add_child(info)
	var w_spin := SpinBox.new()
	w_spin.min_value = MIN_GRID_W
	w_spin.max_value = MAX_GRID_W
	w_spin.step = 1
	w_spin.value = _lvl_w()
	vbox.add_child(w_spin)
	var info2 := Label.new()
	info2.text = "Height (cells, " + str(MIN_GRID_H) + "–" + str(MAX_GRID_H) + ")"
	vbox.add_child(info2)
	var h_spin := SpinBox.new()
	h_spin.min_value = MIN_GRID_H
	h_spin.max_value = MAX_GRID_H
	h_spin.step = 1
	h_spin.value = _lvl_h()
	vbox.add_child(h_spin)
	var hint := Label.new()
	hint.text = "Tip: existing tiles are preserved. Cells beyond\nthe new bounds (and out-of-range actors) are dropped."
	hint.modulate = Color(0.7, 0.75, 0.85)
	vbox.add_child(hint)
	dlg.add_child(vbox)
	dlg.confirmed.connect(func():
		_resize_active_level(int(w_spin.value), int(h_spin.value))
		dlg.hide()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered(Vector2i(280, 200))


# Resize the active level's grid in place. Existing cells in the
# overlap region are preserved exactly; new cells are empty; cells
# outside the new bounds are silently dropped. Actor/block-path
# entries with coords ≥ new dims are also dropped.
func _resize_active_level(new_w: int, new_h: int) -> void:
	new_w = clampi(new_w, MIN_GRID_W, MAX_GRID_W)
	new_h = clampi(new_h, MIN_GRID_H, MAX_GRID_H)
	var lvl: Dictionary = levels[selected_level]
	var old_grid: Array = lvl.get("grid", [])
	var new_grid: Array = []
	for y in range(new_h):
		var row: Array = []
		for x in range(new_w):
			# Preserve existing cell when in overlap region; else empty.
			if y < old_grid.size() and old_grid[y] is Array and x < old_grid[y].size():
				row.append(old_grid[y][x])
			else:
				row.append({"block_type": BLOCK_EMPTY, "tile_index": 0})
		new_grid.append(row)
	lvl["grid"] = new_grid
	lvl["grid_w"] = new_w
	lvl["grid_h"] = new_h
	# Drop actors that no longer fit.
	var dropped_actors := 0
	var kept_actors: Array = []
	for a in lvl.get("actors", []):
		if int(a.get("x", 0)) < new_w and int(a.get("y", 0)) < new_h:
			kept_actors.append(a)
		else:
			dropped_actors += 1
	lvl["actors"] = kept_actors
	# Drop block-path keys whose anchor cell is now out of range.
	var bps: Dictionary = lvl.get("block_paths", {})
	var dead_keys: Array = []
	for k in bps.keys():
		var parts := String(k).split(",")
		if parts.size() == 2:
			if int(parts[0]) >= new_w or int(parts[1]) >= new_h:
				dead_keys.append(k)
	for k in dead_keys:
		bps.erase(k)
	_refresh_ui()
	_apply_zoom()
	_mark_dirty()
	var msg := "Resized to %d × %d" % [new_w, new_h]
	if dropped_actors > 0:
		msg += " (dropped %d actor%s)" % [dropped_actors, "" if dropped_actors == 1 else "s"]
	_status_lbl.text = msg
	level_changed.emit(selected_level)


# ─── Refresh ─────────────────────────────────────────────────

func _refresh_level_list() -> void:
	_level_opt.clear()
	for i in range(levels.size()):
		var has_content = false
		for row in levels[i]["grid"]:
			for cell in row:
				var bt = 0
				if cell is Dictionary:
					bt = cell.get("block_type", 0)
				elif cell is int or cell is float:
					bt = int(cell)
				if bt != BLOCK_EMPTY:
					has_content = true
					break
			if has_content:
				break
		if not has_content and levels[i]["actors"].size() > 0:
			has_content = true
		var prefix = "[*] " if has_content else "[ ] "
		_level_opt.add_item(prefix + str(i + 1) + ": " + levels[i]["name"])
	if selected_level >= 0 and selected_level < levels.size():
		_level_opt.selected = selected_level

func _refresh_ui() -> void:
	if selected_level < 0 or selected_level >= levels.size():
		return
	var lvl = levels[selected_level]
	_name_edit.text = lvl["name"]
	_fric_slider.value = lvl["material_friction"]
	_elast_slider.value = lvl["material_elasticity"]
	# Restore death action dropdown
	var da: String = lvl.get("death_action", "Restart Level")
	var da_idx: int = DEATH_ACTION_NAMES.find(da)
	if da_idx < 0:
		da_idx = 0
	if is_instance_valid(_death_action_opt):
		_death_action_opt.selected = da_idx
	var show_target: bool = (da_idx == 1)  # Go To Level
	if is_instance_valid(_death_target_lbl):
		_death_target_lbl.visible = show_target
	if is_instance_valid(_death_target_spin):
		_death_target_spin.visible = show_target
		_death_target_spin.value = lvl.get("death_action_target", 1)
	if is_instance_valid(_grid_canvas):
		_grid_canvas.queue_redraw()


# ─── Inline Tile Editor (popup pixel editor) ─────────────────

func _open_inline_tile_editor(block_type: int, tile_idx: int) -> void:
	if not tile_library:
		return
	var img = tile_library.get_tile_image(block_type, tile_idx)
	if not img:
		return

	_edit_block_type = block_type
	_edit_tile_index = tile_idx
	_edit_image = img.duplicate()
	_edit_color = BLOCK_COLORS[block_type].lightened(0.1)
	_edit_erasing = false
	_edit_palette_colors = _build_edit_palette(block_type)

	if _edit_popup and is_instance_valid(_edit_popup):
		_edit_popup.queue_free()

	_edit_popup = Window.new()
	_edit_popup.title = "Edit Tile: " + tile_library.get_tile_name(block_type, tile_idx)
	_edit_popup.size = Vector2i(440, 480)
	_edit_popup.unresizable = false
	_edit_popup.close_requested.connect(_on_edit_popup_close)
	add_child(_edit_popup)

	# Dark background panel so the popup matches the AGCK dark theme
	var bg_panel = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = BG_COLOR
	bg_style.content_margin_left = 6
	bg_style.content_margin_right = 6
	bg_style.content_margin_top = 6
	bg_style.content_margin_bottom = 6
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit_popup.add_child(bg_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	bg_panel.add_child(main_vbox)

	# Name row
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(name_row)
	var n_lbl = Label.new()
	n_lbl.text = "Name:"
	n_lbl.label_settings = _ls(11, LABEL_CLR)
	name_row.add_child(n_lbl)
	_edit_name_edit = LineEdit.new()
	_edit_name_edit.text = tile_library.get_tile_name(block_type, tile_idx)
	_edit_name_edit.add_theme_font_size_override("font_size", 11)
	_edit_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var le_style = StyleBoxFlat.new()
	le_style.bg_color = Color(0.10, 0.10, 0.13)
	le_style.set_corner_radius_all(3)
	le_style.content_margin_left = 6
	le_style.content_margin_right = 6
	le_style.content_margin_top = 4
	le_style.content_margin_bottom = 4
	le_style.border_width_bottom = 1
	le_style.border_color = Color(0.30, 0.30, 0.35)
	_edit_name_edit.add_theme_stylebox_override("normal", le_style)
	_edit_name_edit.add_theme_color_override("font_color", WHITE)
	_edit_name_edit.add_theme_color_override("caret_color", ACCENT)
	name_row.add_child(_edit_name_edit)

	# Shader FX row
	var sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sfx_row)
	var sfx_lbl = Label.new()
	sfx_lbl.text = "🔮 Shader:"
	sfx_lbl.label_settings = _ls(11, ACCENT)
	sfx_row.add_child(sfx_lbl)
	_edit_shader_fx_opt = OptionButton.new()
	_edit_shader_fx_opt.add_theme_font_size_override("font_size", 11)
	var cur_sfx: String = "(None)"
	if tile_library:
		cur_sfx = tile_library.get_tile_shader_fx(block_type, tile_idx)
	for i in range(SPRITE_FX_NAMES.size()):
		_edit_shader_fx_opt.add_item(SPRITE_FX_NAMES[i])
		if SPRITE_FX_NAMES[i] == cur_sfx:
			_edit_shader_fx_opt.selected = i
	_edit_shader_fx_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_shader_fx_opt.item_selected.connect(_on_edit_shader_fx_changed)
	_style_option(_edit_shader_fx_opt)
	sfx_row.add_child(_edit_shader_fx_opt)

	# Shader FX parameter sliders container
	_edit_shader_params_grid = GridContainer.new()
	_edit_shader_params_grid.columns = 2
	_edit_shader_params_grid.add_theme_constant_override("h_separation", 8)
	_edit_shader_params_grid.add_theme_constant_override("v_separation", 3)
	main_vbox.add_child(_edit_shader_params_grid)
	_rebuild_edit_shader_params()

	# Toolbar
	var tool_row = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(tool_row)

	var eraser_btn = Button.new()
	eraser_btn.text = "Eraser"
	eraser_btn.toggle_mode = true
	eraser_btn.add_theme_font_size_override("font_size", 11)
	var er_n = StyleBoxFlat.new()
	er_n.bg_color = Color(0.22, 0.22, 0.28)
	er_n.set_corner_radius_all(4)
	er_n.content_margin_left = 8
	er_n.content_margin_right = 8
	er_n.content_margin_top = 3
	er_n.content_margin_bottom = 3
	eraser_btn.add_theme_stylebox_override("normal", er_n)
	var er_p = er_n.duplicate()
	er_p.bg_color = Color(0.85, 0.30, 0.30)
	eraser_btn.add_theme_stylebox_override("pressed", er_p)
	eraser_btn.add_theme_color_override("font_color", WHITE)
	eraser_btn.add_theme_color_override("font_pressed_color", WHITE)
	eraser_btn.toggled.connect(func(v): _edit_erasing = v)
	tool_row.add_child(eraser_btn)

	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_row.add_child(spc)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(_on_edit_save)
	var save_s = StyleBoxFlat.new()
	save_s.bg_color = Color(0.25, 0.65, 0.30)
	save_s.set_corner_radius_all(4)
	save_s.content_margin_left = 10
	save_s.content_margin_right = 10
	save_s.content_margin_top = 3
	save_s.content_margin_bottom = 3
	save_btn.add_theme_stylebox_override("normal", save_s)
	save_btn.add_theme_color_override("font_color", WHITE)
	tool_row.add_child(save_btn)

	var save_as_btn = Button.new()
	save_as_btn.text = "Save As New"
	save_as_btn.add_theme_font_size_override("font_size", 12)
	save_as_btn.pressed.connect(_on_edit_save_as_new)
	var sa_s = StyleBoxFlat.new()
	sa_s.bg_color = Color(0.30, 0.50, 0.80)
	sa_s.set_corner_radius_all(4)
	sa_s.content_margin_left = 10
	sa_s.content_margin_right = 10
	sa_s.content_margin_top = 3
	sa_s.content_margin_bottom = 3
	save_as_btn.add_theme_stylebox_override("normal", sa_s)
	save_as_btn.add_theme_color_override("font_color", WHITE)
	tool_row.add_child(save_as_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 11)
	var cn_s = StyleBoxFlat.new()
	cn_s.bg_color = Color(0.25, 0.25, 0.30)
	cn_s.set_corner_radius_all(4)
	cn_s.content_margin_left = 10
	cn_s.content_margin_right = 10
	cn_s.content_margin_top = 3
	cn_s.content_margin_bottom = 3
	cancel_btn.add_theme_stylebox_override("normal", cn_s)
	cancel_btn.add_theme_color_override("font_color", LABEL_CLR)
	cancel_btn.pressed.connect(_on_edit_popup_close)
	tool_row.add_child(cancel_btn)

	# Color palette
	var palette_row = HBoxContainer.new()
	palette_row.add_theme_constant_override("separation", 2)
	main_vbox.add_child(palette_row)

	var p_lbl = Label.new()
	p_lbl.text = "Color:"
	p_lbl.label_settings = _ls(10, DIM)
	palette_row.add_child(p_lbl)

	_edit_palette_btns.clear()
	for ci in range(_edit_palette_colors.size()):
		var cbtn = Button.new()
		cbtn.custom_minimum_size = Vector2(18, 18)
		cbtn.toggle_mode = true
		cbtn.button_pressed = (ci == 0)
		var cstyle = StyleBoxFlat.new()
		cstyle.bg_color = _edit_palette_colors[ci]
		cstyle.set_corner_radius_all(2)
		cbtn.add_theme_stylebox_override("normal", cstyle)
		var csp = cstyle.duplicate()
		csp.border_width_bottom = 2
		csp.border_width_top = 2
		csp.border_width_left = 2
		csp.border_width_right = 2
		csp.border_color = ACCENT
		cbtn.add_theme_stylebox_override("pressed", csp)
		cbtn.pressed.connect(_on_edit_color_selected.bind(ci))
		palette_row.add_child(cbtn)
		_edit_palette_btns.append(cbtn)

	# Big pixel canvas
	_edit_canvas = Control.new()
	_edit_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_canvas.custom_minimum_size = Vector2(200, 200)
	_edit_canvas.draw.connect(_draw_edit_canvas)
	_edit_canvas.gui_input.connect(_on_edit_canvas_input)
	main_vbox.add_child(_edit_canvas)

	_edit_popup.popup_centered()


func _build_edit_palette(block_type: int) -> Array:
	var base = BLOCK_COLORS[block_type]
	var colors: Array = []
	colors.append(base)
	colors.append(base.lightened(0.15))
	colors.append(base.lightened(0.30))
	colors.append(base.lightened(0.45))
	colors.append(base.darkened(0.15))
	colors.append(base.darkened(0.30))
	colors.append(base.darkened(0.45))
	colors.append(Color.WHITE)
	colors.append(Color(0.7, 0.7, 0.7))
	colors.append(Color(0.4, 0.4, 0.4))
	colors.append(Color(0.15, 0.15, 0.15))
	colors.append(Color.BLACK)
	colors.append(Color(0.85, 0.20, 0.15))
	colors.append(Color(0.25, 0.70, 0.25))
	colors.append(Color(0.20, 0.45, 0.85))
	colors.append(Color(0.90, 0.75, 0.20))
	colors.append(Color(0.65, 0.30, 0.85))
	colors.append(Color(0.90, 0.55, 0.15))
	colors.append(Color(0.45, 0.30, 0.18))
	colors.append(Color(0.15, 0.35, 0.55))
	return colors


func _on_edit_color_selected(idx: int) -> void:
	_edit_color = _edit_palette_colors[idx]
	_edit_erasing = false
	for i in range(_edit_palette_btns.size()):
		_edit_palette_btns[i].button_pressed = (i == idx)


func _draw_edit_canvas() -> void:
	if not _edit_image or not is_instance_valid(_edit_canvas):
		return
	var canvas_size = _edit_canvas.size
	var img_w = _edit_image.get_width()
	var img_h = _edit_image.get_height()

	var pixel_size = minf(canvas_size.x / float(img_w), canvas_size.y / float(img_h))
	var ox_val = (canvas_size.x - pixel_size * img_w) * 0.5
	var oy_val = (canvas_size.y - pixel_size * img_h) * 0.5

	_edit_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.12, 0.12, 0.14))
	for y in range(img_h):
		for x in range(img_w):
			var rect = Rect2(ox_val + x * pixel_size, oy_val + y * pixel_size, pixel_size, pixel_size)
			if (x + y) % 2 == 0:
				_edit_canvas.draw_rect(rect, Color(0.18, 0.18, 0.20))
			else:
				_edit_canvas.draw_rect(rect, Color(0.14, 0.14, 0.16))

			var c = _edit_image.get_pixel(x, y)
			if c.a > 0.01:
				_edit_canvas.draw_rect(rect, c)

	for y in range(img_h + 1):
		_edit_canvas.draw_line(
			Vector2(ox_val, oy_val + y * pixel_size),
			Vector2(ox_val + img_w * pixel_size, oy_val + y * pixel_size),
			Color(0.3, 0.3, 0.35, 0.3), 1.0)
	for x in range(img_w + 1):
		_edit_canvas.draw_line(
			Vector2(ox_val + x * pixel_size, oy_val),
			Vector2(ox_val + x * pixel_size, oy_val + img_h * pixel_size),
			Color(0.3, 0.3, 0.35, 0.3), 1.0)


func _on_edit_canvas_input(event: InputEvent) -> void:
	if not _edit_image:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_edit_pixel_at(event.position)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_edit_pixel_at(event.position)


func _edit_pixel_at(pos: Vector2) -> void:
	if not _edit_image or not is_instance_valid(_edit_canvas):
		return
	var canvas_size = _edit_canvas.size
	var img_w = _edit_image.get_width()
	var img_h = _edit_image.get_height()
	var pixel_size = minf(canvas_size.x / float(img_w), canvas_size.y / float(img_h))
	var ox_val = (canvas_size.x - pixel_size * img_w) * 0.5
	var oy_val = (canvas_size.y - pixel_size * img_h) * 0.5

	var px = int((pos.x - ox_val) / pixel_size)
	var py = int((pos.y - oy_val) / pixel_size)
	if px >= 0 and px < img_w and py >= 0 and py < img_h:
		if _edit_erasing:
			_edit_image.set_pixel(px, py, Color.TRANSPARENT)
		else:
			_edit_image.set_pixel(px, py, _edit_color)
		_edit_canvas.queue_redraw()


func _on_edit_save() -> void:
	if tile_library and _edit_block_type >= 0 and _edit_tile_index >= 0:
		tile_library.update_tile(_edit_block_type, _edit_tile_index, _edit_image)
		var tiles_arr = tile_library.get_tiles_for_type(_edit_block_type)
		if _edit_tile_index < tiles_arr.size() and is_instance_valid(_edit_name_edit):
			tiles_arr[_edit_tile_index]["name"] = _edit_name_edit.text
		# Save shader FX selection
		if is_instance_valid(_edit_shader_fx_opt):
			var sfx_name: String = SPRITE_FX_NAMES[_edit_shader_fx_opt.selected]
			var sfx_params: Dictionary = {}
			if sfx_name != "(None)" and SPRITE_FX_UNIFORMS.has(sfx_name):
				sfx_params = tile_library.get_tile_shader_params(_edit_block_type, _edit_tile_index)
			tile_library.set_tile_shader_fx(_edit_block_type, _edit_tile_index, sfx_name, sfx_params)
		_rebuild_tile_palette()
		_grid_canvas.queue_redraw()
		_status_lbl.text = "Tile saved! Grid updated."
		# Flash the popup title to confirm save
		if _edit_popup and is_instance_valid(_edit_popup):
			var tname = tile_library.get_tile_name(_edit_block_type, _edit_tile_index) if tile_library else "Tile"
			_edit_popup.title = "✓ Saved: " + tname
		_mark_dirty()
		level_changed.emit(selected_level)


func _on_edit_save_as_new() -> void:
	if tile_library and _edit_block_type >= 0:
		var new_name = _edit_name_edit.text if is_instance_valid(_edit_name_edit) else "Custom Tile"
		if not new_name.ends_with(" (custom)"):
			new_name += " (custom)"
		var new_idx = tile_library.add_custom_tile(_edit_block_type, new_name, _edit_image)
		selected_tile_index = new_idx
		_rebuild_tile_palette()
		_grid_canvas.queue_redraw()
		_status_lbl.text = "New tile '" + new_name + "' created!"
	_close_edit_popup()


func _on_edit_popup_close() -> void:
	_close_edit_popup()


func _close_edit_popup() -> void:
	if _edit_popup and is_instance_valid(_edit_popup):
		_edit_popup.queue_free()
		_edit_popup = null
	_edit_image = null


func _on_edit_shader_fx_changed(idx: int) -> void:
	if not tile_library or _edit_block_type < 0 or _edit_tile_index < 0:
		return
	var sfx_name: String = SPRITE_FX_NAMES[idx]
	var sfx_params: Dictionary = {}
	if sfx_name != "(None)":
		for u in SPRITE_FX_UNIFORMS.get(sfx_name, []):
			sfx_params[u["name"]] = u["default"]
	tile_library.set_tile_shader_fx(_edit_block_type, _edit_tile_index, sfx_name, sfx_params)
	_rebuild_edit_shader_params()
	_mark_dirty()
	level_changed.emit(selected_level)


func _rebuild_edit_shader_params() -> void:
	if not is_instance_valid(_edit_shader_params_grid):
		return
	# Clear existing children
	for ch in _edit_shader_params_grid.get_children():
		ch.queue_free()
	if not is_instance_valid(_edit_shader_fx_opt):
		return
	var sfx_name: String = SPRITE_FX_NAMES[_edit_shader_fx_opt.selected]
	if sfx_name == "(None)" or not SPRITE_FX_UNIFORMS.has(sfx_name):
		return
	var sparams: Dictionary = {}
	if tile_library and _edit_block_type >= 0 and _edit_tile_index >= 0:
		sparams = tile_library.get_tile_shader_params(_edit_block_type, _edit_tile_index)
	for u in SPRITE_FX_UNIFORMS[sfx_name]:
		var lbl = Label.new()
		lbl.text = u["label"]
		lbl.label_settings = _ls(10, DIM)
		lbl.custom_minimum_size.x = 70
		_edit_shader_params_grid.add_child(lbl)
		var sl = HSlider.new()
		sl.min_value = u["min"]
		sl.max_value = u["max"]
		sl.step = u["step"]
		sl.value = sparams.get(u["name"], u["default"])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size.x = 80
		var uname: String = u["name"]
		sl.value_changed.connect(func(v):
			if tile_library and _edit_block_type >= 0 and _edit_tile_index >= 0:
				var cur_params = tile_library.get_tile_shader_params(_edit_block_type, _edit_tile_index)
				cur_params[uname] = v
				tile_library.set_tile_shader_fx(_edit_block_type, _edit_tile_index,
					SPRITE_FX_NAMES[_edit_shader_fx_opt.selected], cur_params)
				_mark_dirty()
				level_changed.emit(selected_level))
		_edit_shader_params_grid.add_child(sl)


# ─── Tile Import ─────────────────────────────────────────────

func _on_import_tile_pressed() -> void:
	if _tile_import_dialog and is_instance_valid(_tile_import_dialog):
		_tile_import_dialog.queue_free()
	_tile_import_dialog = FileDialog.new()
	_tile_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_tile_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_tile_import_dialog.title = "Import Tile(s) from PNG"
	_tile_import_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	_tile_import_dialog.size = Vector2i(700, 450)
	_tile_import_dialog.files_selected.connect(_on_tile_files_selected)
	add_child(_tile_import_dialog)
	_tile_import_dialog.popup_centered()


func _on_tile_files_selected(paths: PackedStringArray) -> void:
	if not tile_library:
		return
	var count := 0
	for path in paths:
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			push_warning("AGCK: Could not load image: " + path)
			continue
		var fname: String = path.get_file().get_basename()
		# Detect tilesheet: if width is a multiple of height and wider than 1 tile
		var w := img.get_width()
		var h := img.get_height()
		if w > h and w % h == 0:
			# Split into individual tiles
			var tile_count := w / h
			for i in range(tile_count):
				var tile_img := img.get_region(Rect2i(i * h, 0, h, h))
				tile_img.resize(18, 18, Image.INTERPOLATE_NEAREST)
				var tile_name := fname + "_" + str(i + 1) + " (imported)"
				tile_library.add_custom_tile(selected_block, tile_name, tile_img)
				count += 1
		else:
			# Single tile — resize to 18x18
			img.resize(18, 18, Image.INTERPOLATE_NEAREST)
			var tile_name := fname + " (imported)"
			tile_library.add_custom_tile(selected_block, tile_name, img)
			count += 1
	_rebuild_tile_palette()
	_grid_canvas.queue_redraw()
	if count > 0:
		_status_lbl.text = "Imported " + str(count) + " tile(s)!"
	else:
		_status_lbl.text = "No tiles imported."


# ─── Actor Sync ──────────────────────────────────────────────

func set_actor_names(names: Array, types: Array = []) -> void:
	actor_names = names.duplicate()
	if types.size() > 0:
		actor_types = types.duplicate()
	else:
		actor_types.resize(actor_names.size())
		for i in range(actor_types.size()):
			if actor_types[i] == null:
				actor_types[i] = "Drone"
	_rebuild_actor_picker()
	# Update the button label if the currently selected actor was renamed
	if selected_actor >= 0 and selected_actor < actor_names.size():
		_actor_picker_btn.text = actor_names[selected_actor]
		if tile_library:
			tile_library.ensure_actor_sprite(selected_actor, actor_names[selected_actor], actor_types[selected_actor])
			var tex: Texture2D = tile_library.get_actor_texture(selected_actor)
			if tex:
				_actor_picker_btn.icon = tex


func refresh_all() -> void:
	_rebuild_tile_palette()
	if is_instance_valid(_grid_canvas):
		_grid_canvas.queue_redraw()


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Array:
	return levels.duplicate(true)

func set_data(data: Array) -> void:
	levels = data.duplicate(true)
	while levels.size() < MAX_LEVELS:
		levels.append(_make_empty_level(levels.size() + 1))
	# Migrate old int-based grids to new dict format
	for lvl in levels:
		var grid = lvl.get("grid", [])
		for y in range(grid.size()):
			for x in range(grid[y].size()):
				var cell = grid[y][x]
				if cell is int or cell is float:
					grid[y][x] = {"block_type": int(cell), "tile_index": 0}
		# Migrate: add death_action if missing
		if not lvl.has("death_action"):
			lvl["death_action"] = "Restart Level"
		if not lvl.has("death_action_target"):
			lvl["death_action_target"] = 1
		# Migrate: add block_paths if missing
		if not lvl.has("block_paths"):
			lvl["block_paths"] = {}
	selected_level = 0
	_refresh_level_list()
	_refresh_ui()
	_rebuild_tile_palette()


# ─── Dark Scrollbar Theme (matches code editor) ─────────────
func _apply_dark_scrollbar_theme(node: Control) -> void:
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.25, 0.25, 0.22)
	grab.border_color = Color(0.15, 0.15, 0.12)
	grab.set_border_width_all(1)
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 3; grab.content_margin_right = 3
	grab.content_margin_top = 3;  grab.content_margin_bottom = 3

	var grab_hl := grab.duplicate()
	grab_hl.bg_color = Color(0.18, 0.18, 0.16)

	var grab_pr := grab.duplicate()
	grab_pr.bg_color = Color(0.10, 0.10, 0.08)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.14, 0.18)

	var t := Theme.new()
	for sb_type in ["VScrollBar", "HScrollBar", "ScrollBar"]:
		t.set_stylebox("grabber", sb_type, grab)
		t.set_stylebox("grabber_highlight", sb_type, grab_hl)
		t.set_stylebox("grabber_pressed", sb_type, grab_pr)
		t.set_stylebox("scroll", sb_type, track)
	node.theme = t

	# Also override per-node on internal scrollbar children
	for i in node.get_child_count(true):
		var child = node.get_child(i, true)
		if child is VScrollBar or child is HScrollBar:
			child.add_theme_stylebox_override("grabber", grab)
			child.add_theme_stylebox_override("grabber_highlight", grab_hl)
			child.add_theme_stylebox_override("grabber_pressed", grab_pr)
			child.add_theme_stylebox_override("scroll", track)
			child.custom_minimum_size = Vector2(12, 12)
