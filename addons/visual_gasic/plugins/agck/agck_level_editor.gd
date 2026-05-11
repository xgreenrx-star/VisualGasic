@tool
## AGCK Level Editor — WYSIWYG tile-based level designer
##
## Visual tile palette with real pixel-art thumbnails. The grid renders
## actual tile textures for a true What-You-See-Is-What-You-Get experience.
## Double-click any tile in the palette to open the inline sprite editor
## and customize it. Edited tiles update the grid in real-time.
##
## ─── Editor-boundary policy (read this before adding power features) ───
## AGCK is the *level / scene composer*: it owns the grid, block-type
## semantics (Barrier/Ladder/Deadly/Switch/Goal/Question/Teleport),
## actor placement, waypoints, and one-click bake to a runnable game.
## VG's Sprite Editor (`vg_sprite_editor.gd`) and 2D Editor own the
## *asset / scene authoring*: pixel painting, layers, frames, free
## positioning, custom shaders, advanced transforms.
##
## When in doubt, ask: "is this about *what's in this level slot* or
## about *what this asset looks like*?" Slot questions stay here. Asset
## questions go to VG's editors via the bridge button in the inline
## popup (`_on_edit_open_in_vg_sprite_editor`).
##
## Per-instance properties on placed tiles are intentionally limited to
## the small set that meaningfully changes a *placement* without
## changing the *asset* — currently flip H / flip V (Ctrl+Click a cell
## to expose them in the right-dock Properties panel). Don't grow this
## into a full inspector; users who need rotation, modulate, or shaders
## per-instance should make tile variants or move to VG's 2D editor.
extends VBoxContainer

signal level_changed(level_id: int)
signal edit_tile_requested(block_type: int, tile_index: int)

# Online-asset browsers (optional — only loaded when user clicks 🌐)
const OPENGAMEART_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/opengameart_browser.gd")
const KENNEY_BROWSER_SCRIPT      := preload("res://addons/visual_gasic/asset_browser/kenney_browser.gd")

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
const BLOCK_GOAL       = 7

const BLOCK_NAMES  = ["Empty", "Barrier", "Ladder", "Deadly", "Background", "Teleport", "Switch", "Goal"]
const BLOCK_COLORS = [
	Color(0.12, 0.12, 0.14),
	Color(0.50, 0.55, 0.60),
	Color(0.30, 0.75, 0.30),
	Color(0.85, 0.20, 0.20),
	Color(0.25, 0.40, 0.60),
	Color(0.65, 0.30, 0.85),
	Color(0.90, 0.80, 0.20),
	Color(0.95, 0.75, 0.15),
]
const BLOCK_ICONS = ["  ", "B ", "L ", "D ", "Bg", "T ", "S ", "🏁"]

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
var _user_zoom_override: bool = false  # set true once user manually zooms; disables auto-fit

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
var _tile_palette: Container = null
var _tile_btns: Array = []
# Import + move-mode UI state.
# `_import_target_opt` is the "Into:" dropdown next to Import; the integer
# value at each option index is the destination BLOCK_* constant.
# `_move_mode_active` flips palette tiles into checkbox-style multi-select
# so the user can pick a set and reassign them to another category.
# `_move_selected` keys are tile indices within `selected_block`.
var _import_target_opt: OptionButton = null
var _move_mode_btn: Button = null
var _change_cat_btn: Button = null
var _select_all_btn: Button = null
var _clear_sel_btn: Button = null
var _move_mode_active: bool = false
var _move_selected: Dictionary = {}
# Drag-paint selection state. Rather than a rubber-band overlay (which
# fights the ScrollContainer for input), we hijack the existing tile
# buttons: pressing one in move-mode starts a drag; while the left mouse
# button stays held, `mouse_entered` on other tile buttons toggles them to
# the same on/off state as the originally-pressed tile. Releasing anywhere
# ends the drag. Works through scroll naturally.
var _drag_paint_active: bool = false
var _drag_paint_value: bool = true  # true = adding to selection, false = removing
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

# Online asset browser handles (lazy)
var _opengameart_browser: RefCounted = null
var _kenney_browser: RefCounted = null
var _online_chooser_popup: PopupPanel = null
var _online_pre_scan_files: Dictionary = {}  # path -> mtime, snapshot before browser opens

# ── Dock-layout refs (added in the v2 layout rebuild) ──
var _level_meta_btn: Button = null
var _level_meta_popup: PopupPanel = null
var _actors_list_vbox: VBoxContainer = null
var _props_vbox: VBoxContainer = null
var _hover_status_lbl: Label = null
var _props_target: Dictionary = {}  # {kind:"tile"|"actor", ...}

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

# Bridge state for "Open in VG Sprite Editor": when set, a polling Timer
# watches `_vg_bridge_path` for an mtime change and reloads the resulting
# image back into the tile library at (`_vg_bridge_bt`, `_vg_bridge_ti`).
var _vg_bridge_path: String = ""
var _vg_bridge_bt: int = -1
var _vg_bridge_ti: int = -1
var _vg_bridge_mtime: int = 0
var _vg_bridge_timer: Timer = null

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


## Apply a visible-grabber color to a ScrollContainer's V/HScrollBars.
## The editor theme's default scrollbar grabber is near-transparent on
## dark panels, so the bar tracks are visible but the thumb appears to be
## missing entirely. Override `grabber` + `grabber_highlighted` +
## `grabber_pressed` with explicit StyleBoxFlats so the user can see and
## drag the thumb. Idempotent — safe to call multiple times.
func _apply_scroll_styling(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.12, 0.15)
	track.set_corner_radius_all(2)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.45, 0.45, 0.55)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 2; grab.content_margin_right = 2
	grab.content_margin_top = 2;  grab.content_margin_bottom = 2
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = Color(0.60, 0.60, 0.70)
	var grab_pr := grab.duplicate()
	grab_pr.bg_color = Color(0.75, 0.75, 0.85)
	for bar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		if bar == null:
			continue
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("scroll_focus", track)
		bar.add_theme_stylebox_override("grabber", grab)
		bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
		bar.add_theme_stylebox_override("grabber_pressed", grab_pr)
		# Some editor themes leave the bar's min size at zero — force a
		# visible thickness so the grabber actually has pixels to render.
		if bar is VScrollBar:
			bar.custom_minimum_size.x = 12
		elif bar is HScrollBar:
			bar.custom_minimum_size.y = 12


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


## v2 dock layout. Three vertical zones:
##   ┌─ top toolbar (one row)
##   ├─ HSplit:  [left tile dock] | [grid] | [right actor/properties dock]
##   └─ status bar (one row)
##
## Per-level metadata (friction / elasticity / on-death) lives behind a
## ⚙ popover on the toolbar instead of a dedicated bottom strip.
func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	_build_top_toolbar()

	# Main 3-column body. Outer HSplit = left dock | (grid + right dock).
	var outer = HSplitContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.split_offset = 150  # left dock initial width
	add_child(outer)

	outer.add_child(_build_left_dock())

	var inner = HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.split_offset = -240  # right dock initial width (negative = right side)
	outer.add_child(inner)

	inner.add_child(_build_center_grid())
	inner.add_child(_build_right_dock())

	_build_status_bar()

	# Hidden popups parented to self so they have a window context.
	_build_actor_picker_popup()
	_build_level_meta_popup()

	_refresh_level_list()
	_refresh_ui()
	_rebuild_tile_palette()
	_rebuild_actors_list()

	# Confirmation dialog (reusable)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Are you sure?"
	_confirm_dialog.unresizable = true
	_confirm_dialog.confirmed.connect(func():
		if _pending_confirm_action.is_valid():
			_pending_confirm_action.call()
	)
	add_child(_confirm_dialog)


func _build_top_toolbar() -> void:
	var top_bar = PanelContainer.new()
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = TOOLBAR_BG
	tb_style.content_margin_left = 8
	tb_style.content_margin_right = 8
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	top_bar.add_theme_stylebox_override("panel", tb_style)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top_bar)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	top_bar.add_child(top_hbox)

	var lv_lbl = Label.new()
	lv_lbl.text = "Level"
	lv_lbl.label_settings = _ls(11, DIM)
	top_hbox.add_child(lv_lbl)

	_level_opt = OptionButton.new()
	_level_opt.add_theme_font_size_override("font_size", 11)
	_level_opt.custom_minimum_size.x = 130
	_level_opt.item_selected.connect(_on_level_selected)
	top_hbox.add_child(_level_opt)
	_style_option(_level_opt)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Level name"
	_name_edit.custom_minimum_size.x = 110
	_name_edit.add_theme_font_size_override("font_size", 11)
	_name_edit.text_changed.connect(_on_name_changed)
	top_hbox.add_child(_name_edit)

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

	var resize_btn = Button.new()
	resize_btn.text = "⤢"
	resize_btn.tooltip_text = "Resize this level (width × height)"
	resize_btn.add_theme_font_size_override("font_size", 12)
	resize_btn.pressed.connect(_on_resize_level_pressed)
	top_hbox.add_child(resize_btn)

	# Gear: per-level physics + death-action popover (#7)
	_level_meta_btn = Button.new()
	_level_meta_btn.text = "⚙"
	_level_meta_btn.tooltip_text = "Per-level settings: friction, elasticity, on-death action"
	_level_meta_btn.add_theme_font_size_override("font_size", 14)
	_level_meta_btn.pressed.connect(_on_level_meta_pressed)
	top_hbox.add_child(_level_meta_btn)

	top_hbox.add_child(VSeparator.new())

	# Tools: Place Actor, Waypoints, Fill (#3 group)
	_actor_picker_btn = Button.new()
	_actor_picker_btn.text = "Place Actor…"
	_actor_picker_btn.tooltip_text = "Open the visual actor picker"
	_actor_picker_btn.add_theme_font_size_override("font_size", 11)
	var apb_s = StyleBoxFlat.new()
	apb_s.bg_color = Color(0.20, 0.22, 0.28)
	apb_s.set_corner_radius_all(4)
	apb_s.content_margin_left = 8; apb_s.content_margin_right = 8
	apb_s.content_margin_top = 3; apb_s.content_margin_bottom = 3
	_actor_picker_btn.add_theme_stylebox_override("normal", apb_s)
	_actor_picker_btn.add_theme_color_override("font_color", LABEL_CLR)
	_actor_picker_btn.add_theme_color_override("font_hover_color", WHITE)
	_actor_picker_btn.pressed.connect(_on_actor_picker_pressed)
	top_hbox.add_child(_actor_picker_btn)

	_waypoint_btn = Button.new()
	_waypoint_btn.text = "\U0001F4CD Waypoints"
	_waypoint_btn.tooltip_text = "Toggle waypoint mode (W) — click an actor or block, then right-click to place waypoints"
	_waypoint_btn.add_theme_font_size_override("font_size", 11)
	_waypoint_btn.toggle_mode = true
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

	_flood_btn = Button.new()
	_flood_btn.text = "\U0001FAA3 Fill"
	_flood_btn.tooltip_text = "Flood fill (G) — click a tile and every connected tile of the same type gets replaced"
	_flood_btn.add_theme_font_size_override("font_size", 11)
	_flood_btn.toggle_mode = true
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

	# Spacer pushes zoom + dirty to the far right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	# Zoom controls (right side)
	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.tooltip_text = "Zoom out (Shift+Scroll down)"
	zoom_out_btn.custom_minimum_size = Vector2(26, 22)
	zoom_out_btn.add_theme_font_size_override("font_size", 14)
	zoom_out_btn.pressed.connect(func():
		_zoom = clampf(_zoom - 0.25, 0.25, 4.0)
		_user_zoom_override = true
		_apply_zoom()
	)
	top_hbox.add_child(zoom_out_btn)

	_zoom_lbl = Label.new()
	_zoom_lbl.text = "100%"
	_zoom_lbl.label_settings = _ls(11, ACCENT)
	_zoom_lbl.tooltip_text = "Click to fit grid to view"
	_zoom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_lbl.custom_minimum_size = Vector2(44, 22)
	_zoom_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_lbl.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_user_zoom_override = false
			_auto_fit_zoom()
	)
	top_hbox.add_child(_zoom_lbl)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.tooltip_text = "Zoom in (Shift+Scroll up)"
	zoom_in_btn.custom_minimum_size = Vector2(26, 22)
	zoom_in_btn.add_theme_font_size_override("font_size", 14)
	zoom_in_btn.pressed.connect(func():
		_zoom = clampf(_zoom + 0.25, 0.25, 4.0)
		_user_zoom_override = true
		_apply_zoom()
	)
	top_hbox.add_child(zoom_in_btn)

	# Dirty indicator (rightmost)
	_dirty_lbl = Label.new()
	_dirty_lbl.text = ""
	_dirty_lbl.label_settings = _ls(12, Color(1, 0.7, 0.2))
	top_hbox.add_child(_dirty_lbl)


# ── Left dock: block-type column + tile palette grid ───────────
func _build_left_dock() -> Control:
	var panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.09, 0.12)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size.x = 120

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# Block-type icon grid (compact). Two columns of color-coded icon buttons.
	var bt_grid = GridContainer.new()
	bt_grid.columns = 2
	bt_grid.add_theme_constant_override("h_separation", 3)
	bt_grid.add_theme_constant_override("v_separation", 3)
	vb.add_child(bt_grid)

	for i in range(BLOCK_NAMES.size()):
		var btn = Button.new()
		btn.text = BLOCK_ICONS[i]
		btn.tooltip_text = BLOCK_NAMES[i] + "  (" + str(i + 1) + ")"
		btn.add_theme_font_size_override("font_size", 14)
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_block)
		btn.custom_minimum_size = Vector2(52, 28)
		btn.pressed.connect(_on_block_selected.bind(i))

		var ns = StyleBoxFlat.new()
		ns.bg_color = BLOCK_COLORS[i].darkened(0.5)
		ns.set_corner_radius_all(4)
		ns.content_margin_left = 4; ns.content_margin_right = 4
		ns.content_margin_top = 2;  ns.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", ns)
		var ps = ns.duplicate()
		ps.bg_color = BLOCK_COLORS[i]
		ps.border_width_bottom = 3; ps.border_color = WHITE
		btn.add_theme_stylebox_override("pressed", ps)
		var hs = ns.duplicate()
		hs.bg_color = BLOCK_COLORS[i].darkened(0.2)
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_color_override("font_color", WHITE)
		btn.add_theme_color_override("font_pressed_color", WHITE)
		btn.add_theme_color_override("font_hover_color", WHITE)

		bt_grid.add_child(btn)
		_block_btns.append(btn)

	# Search field
	_tile_filter = LineEdit.new()
	_tile_filter.placeholder_text = "\U0001F50D Search…"
	_tile_filter.tooltip_text = "Filter tiles by name"
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
	vb.add_child(_tile_filter)

	# Import row: local file + online browser (compact)
	var import_row = HBoxContainer.new()
	import_row.add_theme_constant_override("separation", 3)
	vb.add_child(import_row)

	var import_tile_btn = Button.new()
	import_tile_btn.text = "📂 Import"
	import_tile_btn.tooltip_text = "Import tile(s) from local PNG file(s)"
	import_tile_btn.add_theme_font_size_override("font_size", 10)
	import_tile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var itb_s = StyleBoxFlat.new()
	itb_s.bg_color = Color(0.35, 0.45, 0.60)
	itb_s.set_corner_radius_all(3)
	itb_s.content_margin_left = 6; itb_s.content_margin_right = 6
	itb_s.content_margin_top = 2;  itb_s.content_margin_bottom = 2
	import_tile_btn.add_theme_stylebox_override("normal", itb_s)
	import_tile_btn.add_theme_color_override("font_color", WHITE)
	import_tile_btn.pressed.connect(_on_import_tile_pressed)
	import_row.add_child(import_tile_btn)

	var online_btn = Button.new()
	online_btn.text = "🌐 Online…"
	online_btn.tooltip_text = "Browse free CC0 game art (Kenney / OpenGameArt) and import as tiles"
	online_btn.add_theme_font_size_override("font_size", 10)
	online_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ob_s = StyleBoxFlat.new()
	ob_s.bg_color = Color(0.32, 0.55, 0.40)
	ob_s.set_corner_radius_all(3)
	ob_s.content_margin_left = 6; ob_s.content_margin_right = 6
	ob_s.content_margin_top = 2;  ob_s.content_margin_bottom = 2
	online_btn.add_theme_stylebox_override("normal", ob_s)
	online_btn.add_theme_color_override("font_color", WHITE)
	online_btn.pressed.connect(_on_online_browse_pressed)
	import_row.add_child(online_btn)

	# Second row: "Into: [category]" target picker for imports, plus
	# Move-mode toggle and Change-Category button for reassigning existing
	# tiles. These let the user split one tilesheet across Barrier / Ladder /
	# Deadly / etc. without re-importing.
	var into_row = HBoxContainer.new()
	into_row.add_theme_constant_override("separation", 3)
	vb.add_child(into_row)

	var into_lbl = Label.new()
	into_lbl.text = "Into:"
	into_lbl.add_theme_font_size_override("font_size", 10)
	into_lbl.add_theme_color_override("font_color", DIM)
	into_row.add_child(into_lbl)

	_import_target_opt = OptionButton.new()
	_import_target_opt.add_theme_font_size_override("font_size", 10)
	_import_target_opt.tooltip_text = "Category that newly imported tiles will be placed into"
	_import_target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for bt in range(BLOCK_NAMES.size()):
		if bt == BLOCK_EMPTY:
			continue
		_import_target_opt.add_item(BLOCK_NAMES[bt])
		_import_target_opt.set_item_metadata(_import_target_opt.item_count - 1, bt)
	# Default to whatever block is currently selected for painting.
	_sync_import_target_to_selected()
	# Apply the project-wide dark OptionButton + popup styling so the dropdown
	# shows readable text instead of dark-on-dark glyphs on the editor's theme.
	_style_option(_import_target_opt)
	into_row.add_child(_import_target_opt)

	_move_mode_btn = Button.new()
	_move_mode_btn.text = "✎ Move"
	_move_mode_btn.tooltip_text = "Toggle move-mode: pick multiple tiles in the current category, then click Change… to reassign them"
	_move_mode_btn.toggle_mode = true
	_move_mode_btn.add_theme_font_size_override("font_size", 10)
	var mm_s = StyleBoxFlat.new()
	mm_s.bg_color = Color(0.40, 0.40, 0.50)
	mm_s.set_corner_radius_all(3)
	mm_s.content_margin_left = 6; mm_s.content_margin_right = 6
	mm_s.content_margin_top = 2;  mm_s.content_margin_bottom = 2
	_move_mode_btn.add_theme_stylebox_override("normal", mm_s)
	var mm_ps = mm_s.duplicate()
	mm_ps.bg_color = Color(0.80, 0.55, 0.20)
	_move_mode_btn.add_theme_stylebox_override("pressed", mm_ps)
	_move_mode_btn.add_theme_color_override("font_color", WHITE)
	_move_mode_btn.toggled.connect(_on_move_mode_toggled)
	into_row.add_child(_move_mode_btn)

	_change_cat_btn = Button.new()
	_change_cat_btn.text = "→ Change…"
	_change_cat_btn.tooltip_text = "Reassign the selected tiles to a different category"
	_change_cat_btn.add_theme_font_size_override("font_size", 10)
	var cc_s = StyleBoxFlat.new()
	cc_s.bg_color = Color(0.55, 0.40, 0.65)
	cc_s.set_corner_radius_all(3)
	cc_s.content_margin_left = 6; cc_s.content_margin_right = 6
	cc_s.content_margin_top = 2;  cc_s.content_margin_bottom = 2
	_change_cat_btn.add_theme_stylebox_override("normal", cc_s)
	_change_cat_btn.add_theme_color_override("font_color", WHITE)
	_change_cat_btn.pressed.connect(_on_change_category_pressed)
	_change_cat_btn.visible = false
	into_row.add_child(_change_cat_btn)

	# Select-All / Clear buttons — visible only in move-mode. They make it
	# obvious how to reset a sticky selection (e.g. after the count drifts
	# because the user lost track of which tiles are toggled).
	_select_all_btn = Button.new()
	_select_all_btn.text = "All"
	_select_all_btn.tooltip_text = "Select every tile in the current category"
	_select_all_btn.add_theme_font_size_override("font_size", 10)
	var sa_s = StyleBoxFlat.new()
	sa_s.bg_color = Color(0.30, 0.45, 0.55)
	sa_s.set_corner_radius_all(3)
	sa_s.content_margin_left = 5; sa_s.content_margin_right = 5
	sa_s.content_margin_top = 2;  sa_s.content_margin_bottom = 2
	_select_all_btn.add_theme_stylebox_override("normal", sa_s)
	_select_all_btn.add_theme_color_override("font_color", WHITE)
	_select_all_btn.pressed.connect(_on_select_all_tiles_pressed)
	_select_all_btn.visible = false
	into_row.add_child(_select_all_btn)

	_clear_sel_btn = Button.new()
	_clear_sel_btn.text = "Clear"
	_clear_sel_btn.tooltip_text = "Deselect all tiles"
	_clear_sel_btn.add_theme_font_size_override("font_size", 10)
	var cs_s = sa_s.duplicate()
	cs_s.bg_color = Color(0.45, 0.30, 0.30)
	_clear_sel_btn.add_theme_stylebox_override("normal", cs_s)
	_clear_sel_btn.add_theme_color_override("font_color", WHITE)
	_clear_sel_btn.pressed.connect(_on_clear_tile_selection_pressed)
	_clear_sel_btn.visible = false
	into_row.add_child(_clear_sel_btn)

	# Tile palette: vertical scroll, responsive grid of thumbnails (no labels).
	# Column count auto-recomputes from the available width whenever the panel resizes.
	_tile_palette_scroll = ScrollContainer.new()
	_tile_palette_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tile_palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tile_palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tile_palette_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	# Hard cap the palette's width so it can't sprawl across the canvas
	# when the user widens the left HSplit (e.g. after importing a 200-tile
	# tilesheet). Anything wider just becomes empty padding inside the dock.
	_tile_palette_scroll.custom_minimum_size = Vector2(0, 0)
	# Style the vertical scrollbar so the grabber is actually visible
	# against our dark dock background. The editor theme's default grabber
	# is near-transparent on dark panels — looks like the scrollbar has no
	# thumb at all. Same recipe used for the grid canvas's scrollbars.
	_apply_scroll_styling(_tile_palette_scroll)
	vb.add_child(_tile_palette_scroll)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	_tile_palette_scroll.add_child(grid)
	_tile_palette = grid

	# Recompute columns whenever the scroll container is resized.
	_tile_palette_scroll.resized.connect(_update_tile_palette_columns)

	return panel


func _update_tile_palette_columns() -> void:
	if _tile_palette == null or not is_instance_valid(_tile_palette):
		return
	if _tile_palette_scroll == null or not is_instance_valid(_tile_palette_scroll):
		return
	# Each tile button is 46 px wide; grid h_separation is 3 px.
	# Reserve a little for the vertical scrollbar.
	var avail: float = _tile_palette_scroll.size.x - 18.0
	var tile_w := 46.0
	var sep := 3.0
	var cols: int = int(floor((avail + sep) / (tile_w + sep)))
	if cols < 1:
		cols = 1
	# Cap max columns so the palette can't sprawl horizontally — keeping it
	# narrow forces tiles to wrap into rows, which is what makes the vertical
	# scrollbar actually engage when there are many tiles. Without this cap,
	# widening the left HSplit creates a single huge row that covers the
	# canvas instead of scrolling. 8 cols lets the user widen the dock for
	# large tile-sets while still keeping the layout grid-like.
	if cols > 8:
		cols = 8
	if (_tile_palette as GridContainer).columns != cols:
		(_tile_palette as GridContainer).columns = cols


# ── Center: grid canvas (gets the bulk of the space) ────────────
func _build_center_grid() -> Control:
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var gs_style = StyleBoxFlat.new()
	gs_style.bg_color = Color(0.08, 0.08, 0.10)
	_grid_scroll.add_theme_stylebox_override("panel", gs_style)

	_grid_canvas = Control.new()
	_grid_canvas.custom_minimum_size = Vector2(_lvl_w() * BASE_CELL_PX + 2, _lvl_h() * BASE_CELL_PX + 2)
	_grid_canvas.draw.connect(_draw_grid)
	_grid_canvas.gui_input.connect(_on_grid_input)
	_grid_canvas.focus_mode = Control.FOCUS_CLICK
	_grid_scroll.add_child(_grid_canvas)
	# Auto-fit the grid to the visible area on open and whenever the editor is
	# resized, until the user manually zooms (then we respect their choice).
	_grid_scroll.resized.connect(_auto_fit_zoom)
	return _grid_scroll


## Pick the largest quantized zoom step where the whole grid still fits in
## `_grid_scroll`'s visible area. Honors `ZOOM_MIN`/`ZOOM_MAX`/`ZOOM_STEP`.
func _auto_fit_zoom() -> void:
	if _user_zoom_override:
		return
	if not is_instance_valid(_grid_scroll) or not is_instance_valid(_grid_canvas):
		return
	var avail: Vector2 = _grid_scroll.size
	# Account for the always-visible scrollbars the ScrollContainer reserves.
	var vbar := _grid_scroll.get_v_scroll_bar()
	var hbar := _grid_scroll.get_h_scroll_bar()
	if is_instance_valid(vbar):
		avail.x -= vbar.size.x
	if is_instance_valid(hbar):
		avail.y -= hbar.size.y
	avail -= Vector2(8, 8)  # small breathing room
	if avail.x <= 0 or avail.y <= 0:
		return
	var gw: float = float(_lvl_w() * BASE_CELL_PX)
	var gh: float = float(_lvl_h() * BASE_CELL_PX)
	if gw <= 0 or gh <= 0:
		return
	var fit: float = minf(avail.x / gw, avail.y / gh)
	# Snap down to nearest ZOOM_STEP so the result lands on clean values.
	var snapped: float = floorf(fit / ZOOM_STEP) * ZOOM_STEP
	snapped = clampf(snapped, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(snapped, _zoom):
		return
	_zoom = snapped
	_apply_zoom()


# ── Right dock: actors list + properties panel ─────────────────
func _build_right_dock() -> Control:
	var panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.09, 0.12)
	st.content_margin_left = 6; st.content_margin_right = 6
	st.content_margin_top = 6;  st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size.x = 180

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var actors_hdr = Label.new()
	actors_hdr.text = "ACTORS"
	actors_hdr.label_settings = _ls(10, ACCENT)
	vb.add_child(actors_hdr)

	var actors_scroll = ScrollContainer.new()
	actors_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actors_scroll.custom_minimum_size.y = 160
	actors_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(actors_scroll)

	_actors_list_vbox = VBoxContainer.new()
	_actors_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actors_list_vbox.add_theme_constant_override("separation", 2)
	actors_scroll.add_child(_actors_list_vbox)

	vb.add_child(HSeparator.new())

	var props_hdr = Label.new()
	props_hdr.text = "PROPERTIES"
	props_hdr.label_settings = _ls(10, ACCENT)
	vb.add_child(props_hdr)

	_props_vbox = VBoxContainer.new()
	_props_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_props_vbox.add_theme_constant_override("separation", 3)
	vb.add_child(_props_vbox)

	_refresh_props_panel()
	return panel


# ── Status bar (one line at bottom, drops the verbose 3-row footer) ──
func _build_status_bar() -> void:
	var bot_bar = PanelContainer.new()
	var bb_style = StyleBoxFlat.new()
	bb_style.bg_color = TOOLBAR_BG
	bb_style.content_margin_left = 8
	bb_style.content_margin_right = 8
	bb_style.content_margin_top = 3
	bb_style.content_margin_bottom = 3
	bot_bar.add_theme_stylebox_override("panel", bb_style)
	bot_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(bot_bar)

	var bot_hbox = HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 8)
	bot_bar.add_child(bot_hbox)

	_status_lbl = Label.new()
	_status_lbl.text = "1-8 block · B paint · G fill · W waypoints · [ ] tile · LMB paint · RMB place actor"
	_status_lbl.label_settings = _ls(10, LABEL_CLR)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hbox.add_child(_status_lbl)

	_hover_status_lbl = Label.new()
	_hover_status_lbl.text = ""
	_hover_status_lbl.label_settings = _ls(10, DIM)
	bot_hbox.add_child(_hover_status_lbl)


# ── Actor picker popup (was inline in v1, now its own builder) ─────
func _build_actor_picker_popup() -> void:
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


# ── Per-level metadata popover (#7): friction / elasticity / on-death ──
func _build_level_meta_popup() -> void:
	_level_meta_popup = PopupPanel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16)
	sb.border_color = Color(0.35, 0.35, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 10;  sb.content_margin_bottom = 10
	_level_meta_popup.add_theme_stylebox_override("panel", sb)
	add_child(_level_meta_popup)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.custom_minimum_size = Vector2(280, 0)
	_level_meta_popup.add_child(vb)

	var hdr = Label.new()
	hdr.text = "Per-Level Settings"
	hdr.label_settings = _ls(12, WHITE)
	vb.add_child(hdr)
	vb.add_child(HSeparator.new())

	var f_lbl = Label.new()
	f_lbl.text = "Friction"
	f_lbl.label_settings = _ls(11, LABEL_CLR)
	vb.add_child(f_lbl)
	_fric_slider = HSlider.new()
	_fric_slider.min_value = 0
	_fric_slider.max_value = 100
	_fric_slider.value = 50
	_fric_slider.value_changed.connect(_on_friction_changed)
	vb.add_child(_fric_slider)

	var e_lbl = Label.new()
	e_lbl.text = "Elasticity"
	e_lbl.label_settings = _ls(11, LABEL_CLR)
	vb.add_child(e_lbl)
	_elast_slider = HSlider.new()
	_elast_slider.min_value = 0
	_elast_slider.max_value = 100
	_elast_slider.value = 50
	_elast_slider.value_changed.connect(_on_elasticity_changed)
	vb.add_child(_elast_slider)

	vb.add_child(HSeparator.new())

	var da_lbl = Label.new()
	da_lbl.text = "On Death"
	da_lbl.label_settings = _ls(11, LABEL_CLR)
	vb.add_child(da_lbl)
	_death_action_opt = OptionButton.new()
	_death_action_opt.add_theme_font_size_override("font_size", 11)
	_death_action_opt.add_item("Restart Level")
	_death_action_opt.add_item("Go To Level...")
	_death_action_opt.add_item("Lose Item...")
	_death_action_opt.add_item("End Game")
	_death_action_opt.item_selected.connect(_on_death_action_changed)
	vb.add_child(_death_action_opt)
	_style_option(_death_action_opt)

	var dt_hb = HBoxContainer.new()
	vb.add_child(dt_hb)
	_death_target_lbl = Label.new()
	_death_target_lbl.text = "→ Lvl:"
	_death_target_lbl.label_settings = _ls(11, DIM)
	_death_target_lbl.visible = false
	dt_hb.add_child(_death_target_lbl)
	_death_target_spin = SpinBox.new()
	_death_target_spin.min_value = 1
	_death_target_spin.max_value = MAX_LEVELS
	_death_target_spin.value = 1
	_death_target_spin.custom_minimum_size.x = 60
	_death_target_spin.add_theme_font_size_override("font_size", 11)
	_death_target_spin.visible = false
	_death_target_spin.value_changed.connect(_on_death_target_changed)
	dt_hb.add_child(_death_target_spin)


func _on_level_meta_pressed() -> void:
	if not is_instance_valid(_level_meta_popup) or not is_instance_valid(_level_meta_btn):
		return
	var pos = _level_meta_btn.get_screen_position() + Vector2(0, _level_meta_btn.size.y + 4)
	_level_meta_popup.popup(Rect2i(Vector2i(pos), Vector2i(300, 240)))


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

		var btn = Button.new()
		btn.toggle_mode = true
		# In move-mode the button reflects "is this tile in the move set?"
		# instead of "is this the current paint tile". Different click
		# handler too — we intercept below.
		if _move_mode_active:
			btn.button_pressed = _move_selected.has(i)
		else:
			btn.button_pressed = (i == selected_tile_index)
		btn.tooltip_text = tname + " — double-click to edit"
		btn.custom_minimum_size = Vector2(46, 46)

		var ns = StyleBoxFlat.new()
		ns.bg_color = Color(0.15, 0.15, 0.18)
		ns.set_corner_radius_all(4)
		ns.content_margin_left = 2
		ns.content_margin_right = 2
		ns.content_margin_top = 2
		ns.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", ns)

		var ps = ns.duplicate()
		if _move_mode_active:
			# Distinct orange-tinted highlight for move-mode selection so the
			# user can tell at a glance which tiles will be reassigned.
			ps.bg_color = Color(0.55, 0.40, 0.15)
			ps.border_width_left = 2; ps.border_width_right = 2
			ps.border_width_top = 2; ps.border_width_bottom = 2
			ps.border_color = Color(1.0, 0.75, 0.25)
		else:
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
			tex_rect.custom_minimum_size = Vector2(40, 40)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tex_rect)

		# "NEW" watermark badge for freshly imported tiles. Cleared on
		# move and on next import wave.
		if tile_library.get_tile_is_new(selected_block, i):
			var badge := Label.new()
			badge.text = "NEW"
			badge.add_theme_font_size_override("font_size", 8)
			badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0.95, 0.40, 0.10, 0.85)
			bg.set_corner_radius_all(2)
			bg.content_margin_left = 3
			bg.content_margin_right = 3
			bg.content_margin_top = 0
			bg.content_margin_bottom = 0
			badge.add_theme_stylebox_override("normal", bg)
			# Anchor to top-right corner of the button.
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 0.0
			badge.anchor_bottom = 0.0
			badge.offset_left = -22.0
			badge.offset_right = -2.0
			badge.offset_top = 2.0
			badge.offset_bottom = 12.0
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(badge)

		# Hover updates the status bar with the tile's full name (#6).
		# In move-mode, ALSO continue any in-progress drag-paint selection.
		btn.mouse_entered.connect(func():
			if is_instance_valid(_hover_status_lbl):
				_hover_status_lbl.text = BLOCK_NAMES[selected_block] + " · " + tname
			if _move_mode_active and _drag_paint_active:
				# Only continue the drag while LMB is actually held — a
				# stale `_drag_paint_active` (mouse released outside any
				# tile) would otherwise keep painting on hover.
				if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					_drag_paint_active = false
					return
				_apply_drag_paint_to(i)
		)
		btn.mouse_exited.connect(func():
			if is_instance_valid(_hover_status_lbl):
				_hover_status_lbl.text = ""
		)
		if _move_mode_active:
			# In move-mode the button isn't a "select-for-paint" toggle —
			# it's a multi-select checkbox + drag-paint anchor. Wire to the
			# Button's native `toggled` signal so the visual state and our
			# `_move_selected` dictionary stay in lockstep (previously we
			# used `gui_input` to toggle ourselves, but the Button's own
			# toggle ran AFTER and flipped state back — so the count would
			# drift on every click). `gui_input` is still used, but only to
			# detect LMB release to end an in-progress drag-paint.
			#
			# Force PRESS action-mode so `toggled` fires the moment the
			# user clicks down — otherwise it'd only fire on release, and
			# the drag-paint flag would never be set during the drag,
			# breaking the "click + drag across tiles" workflow.
			btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			btn.toggled.connect(_on_tile_move_btn_toggled.bind(i))
			btn.gui_input.connect(_on_tile_btn_move_input.bind(i))
		else:
			btn.pressed.connect(_on_tile_selected.bind(i))
			btn.gui_input.connect(_on_tile_btn_input.bind(i))

		_tile_palette.add_child(btn)
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
	_status_lbl.text = "Selected: " + BLOCK_NAMES[selected_block] + " → " + tname
	_props_target = {}
	_refresh_props_panel()


func _on_tile_btn_input(event: InputEvent, tile_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_open_inline_tile_editor(selected_block, tile_idx)


# ─── Import target + move-mode helpers ───────────────────────

## Returns the BLOCK_* that newly imported tiles should be added to.
## Falls back to `selected_block` if the dropdown isn't ready yet (e.g.
## during very-early-startup auto-ingest).
func _get_import_target_block() -> int:
	if _import_target_opt and is_instance_valid(_import_target_opt):
		var sel: int = _import_target_opt.selected
		if sel >= 0:
			var meta = _import_target_opt.get_item_metadata(sel)
			if typeof(meta) == TYPE_INT:
				return int(meta)
	return selected_block if selected_block != BLOCK_EMPTY else BLOCK_BARRIER


func _sync_import_target_to_selected() -> void:
	if _import_target_opt == null or not is_instance_valid(_import_target_opt):
		return
	# Empty isn't an importable target; keep the dropdown wherever it was.
	if selected_block == BLOCK_EMPTY:
		return
	for i in range(_import_target_opt.item_count):
		var meta = _import_target_opt.get_item_metadata(i)
		if typeof(meta) == TYPE_INT and int(meta) == selected_block:
			_import_target_opt.select(i)
			return


func _on_move_mode_toggled(pressed: bool) -> void:
	_move_mode_active = pressed
	_move_selected.clear()
	_update_change_cat_visibility()
	_rebuild_tile_palette()
	if pressed:
		_status_lbl.text = "Move-mode: click tiles to select, then press 'Change…'"
	else:
		_status_lbl.text = ""


## Native `toggled` handler for a tile button while in move-mode. Driven
## by the Button's built-in toggle behavior so the visual `button_pressed`
## state and our `_move_selected` set are guaranteed to agree (no double-
## toggling). Also seeds drag-paint with the new state so dragging across
## neighbors paints the same on/off value.
func _on_tile_move_btn_toggled(pressed: bool, idx: int) -> void:
	if pressed:
		_move_selected[idx] = true
	else:
		_move_selected.erase(idx)
	_drag_paint_active = true
	_drag_paint_value = pressed
	_update_change_cat_visibility()


## Move-mode gui_input: detects LMB release to end an in-progress
## drag-paint. The actual toggle on click is handled by `toggled` above.
func _on_tile_btn_move_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_drag_paint_active = false


## Apply the in-progress drag-paint's "value" (add or remove) to `idx`.
## Idempotent — re-entering an already-correct tile is a no-op.
func _apply_drag_paint_to(idx: int) -> void:
	var currently: bool = _move_selected.has(idx)
	if currently == _drag_paint_value:
		return
	if _drag_paint_value:
		_move_selected[idx] = true
	else:
		_move_selected.erase(idx)
	if idx >= 0 and idx < _tile_btns.size():
		# Setting button_pressed will re-emit `toggled`, but that handler
		# is idempotent w.r.t. _move_selected (sets/erases to the same
		# state) so re-entry is safe.
		_tile_btns[idx].set_pressed_no_signal(_move_selected.has(idx))
	_update_change_cat_visibility()


## Select every visible tile in the current category.
func _on_select_all_tiles_pressed() -> void:
	if not _move_mode_active or not tile_library:
		return
	var n: int = tile_library.get_tile_count(selected_block)
	_move_selected.clear()
	for i in range(n):
		_move_selected[i] = true
	# Reflect on buttons without re-triggering signals.
	for i in range(_tile_btns.size()):
		_tile_btns[i].set_pressed_no_signal(true)
	_drag_paint_active = false
	_update_change_cat_visibility()
	_status_lbl.text = "Selected all %d tile(s) in %s." % [n, BLOCK_NAMES[selected_block]]


## Clear the entire move-mode selection.
func _on_clear_tile_selection_pressed() -> void:
	if not _move_mode_active:
		return
	_move_selected.clear()
	for i in range(_tile_btns.size()):
		_tile_btns[i].set_pressed_no_signal(false)
	_drag_paint_active = false
	_update_change_cat_visibility()
	_status_lbl.text = "Selection cleared."


func _update_change_cat_visibility() -> void:
	# Toggle visibility of the Select-All / Clear helpers along with the
	# Change button. The All/Clear buttons appear whenever move-mode is on
	# (even with zero selected — so the user can quickly grab everything),
	# while Change… only lights up when there's something to act on.
	if is_instance_valid(_select_all_btn):
		_select_all_btn.visible = _move_mode_active
	if is_instance_valid(_clear_sel_btn):
		_clear_sel_btn.visible = _move_mode_active and not _move_selected.is_empty()
	if _change_cat_btn == null or not is_instance_valid(_change_cat_btn):
		return
	_change_cat_btn.visible = _move_mode_active and not _move_selected.is_empty()
	if _change_cat_btn.visible:
		_change_cat_btn.text = "→ Change… (%d)" % _move_selected.size()


func _on_change_category_pressed() -> void:
	if _move_selected.is_empty():
		return
	# Build the dialog on the fly.
	var dlg = AcceptDialog.new()
	dlg.title = "Change Category"
	dlg.ok_button_text = "Move"
	dlg.add_cancel_button("Cancel")

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	dlg.add_child(vb)

	var lbl = Label.new()
	lbl.text = "Move %d tile(s) from %s to:" % [_move_selected.size(), BLOCK_NAMES[selected_block]]
	vb.add_child(lbl)

	# Destination dropdown — contains BOTH block-type buckets AND actor
	# types. Metadata encodes which path to take in `_apply_move_tiles`:
	#   {"kind": "tile",  "bt":   <BLOCK_*>}     — relocate within tile buckets
	#   {"kind": "actor", "type": <ACTOR_TYPE>}  — convert tile into a new actor
	var dst_opt = OptionButton.new()
	dst_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for bt in range(BLOCK_NAMES.size()):
		if bt == BLOCK_EMPTY or bt == selected_block:
			continue
		dst_opt.add_item(BLOCK_NAMES[bt])
		dst_opt.set_item_metadata(dst_opt.item_count - 1, {"kind": "tile", "bt": bt})
	dst_opt.add_separator("Actors / Enemies")
	# Sorted list of actor type names (keys of ACTOR_TYPE_COLORS).
	var actor_type_names: Array = ACTOR_TYPE_COLORS.keys()
	actor_type_names.sort()
	for atype in actor_type_names:
		dst_opt.add_item("Actor: " + String(atype))
		dst_opt.set_item_metadata(dst_opt.item_count - 1, {"kind": "actor", "type": String(atype)})
	if dst_opt.item_count > 0:
		dst_opt.select(0)
	# Apply dark OptionButton + popup styling here too — the dialog inherits
	# the editor theme, which makes the default font_color near-invisible.
	_style_option(dst_opt)
	vb.add_child(dst_opt)

	var update_chk = CheckBox.new()
	update_chk.text = "Update already-placed cells to the new category"
	update_chk.button_pressed = true
	vb.add_child(update_chk)

	var note = Label.new()
	note.text = "Tip: leave the checkbox ON unless you've changed your mind\nabout the tile's role and want existing painted cells erased\ninstead of remapped. When converting to actors, placed\ncells are erased — actors live in a separate per-level list."
	note.add_theme_color_override("font_color", DIM)
	note.add_theme_font_size_override("font_size", 10)
	vb.add_child(note)

	add_child(dlg)
	dlg.confirmed.connect(func():
		if dst_opt.item_count == 0:
			return
		var dst_meta = dst_opt.get_item_metadata(dst_opt.selected)
		if typeof(dst_meta) != TYPE_DICTIONARY:
			return
		var kind: String = String(dst_meta.get("kind", ""))
		if kind == "tile":
			_apply_move_tiles(int(dst_meta.get("bt", 0)), update_chk.button_pressed)
		elif kind == "actor":
			_apply_move_tiles_to_actor(String(dst_meta.get("type", "")), update_chk.button_pressed)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


## Reassign every tile currently in `_move_selected` (within
## `selected_block`) to `dst_bt`. If `update_cells` is true, every placed
## cell in every level that referenced one of the moved tiles is rewritten
## to the new (block_type, tile_index). Survivor tiles in the source bucket
## get index-compacted, and their placed cells are likewise updated so the
## level art doesn't shift.
func _apply_move_tiles(dst_bt: int, update_cells: bool) -> void:
	if not tile_library or _move_selected.is_empty():
		return
	var src_bt: int = selected_block
	if src_bt == dst_bt:
		_status_lbl.text = "Source and destination are the same — nothing to do."
		return
	var indices: Array = _move_selected.keys()
	indices.sort()

	# Library mutation — returns a remap covering BOTH moved tiles and
	# the survivors that shifted down.
	var remap: Dictionary = tile_library.bulk_move_tiles(src_bt, indices, dst_bt)

	# Patch placed cells across every level.
	var cells_changed: int = 0
	if update_cells:
		for lvl in levels:
			var g = lvl.get("grid", null)
			if typeof(g) != TYPE_ARRAY:
				continue
			for y in range(g.size()):
				var row = g[y]
				if typeof(row) != TYPE_ARRAY:
					continue
				for x in range(row.size()):
					var cell = row[x]
					if typeof(cell) != TYPE_DICTIONARY:
						continue
					if int(cell.get("block_type", 0)) != src_bt:
						continue
					var old_ti: int = int(cell.get("tile_index", 0))
					if not remap.has(old_ti):
						continue
					var r: Dictionary = remap[old_ti]
					var new_bt: int = int(r["bt"])
					var new_ti: int = int(r["idx"])
					if new_bt == src_bt and new_ti == old_ti:
						continue
					cell["block_type"] = new_bt
					cell["tile_index"] = new_ti
					cells_changed += 1

	# Currently selected paint tile may have moved/shifted too.
	if remap.has(selected_tile_index):
		var rs: Dictionary = remap[selected_tile_index]
		# Only follow it if it stayed in src; otherwise drop back to 0.
		if int(rs["bt"]) == src_bt:
			selected_tile_index = int(rs["idx"])
		else:
			selected_tile_index = 0

	_move_selected.clear()
	_update_change_cat_visibility()
	# Stay in move-mode; user might want to do another batch.
	_rebuild_tile_palette()
	if is_instance_valid(_grid_canvas):
		_grid_canvas.queue_redraw()
	# Undo isn't supported for this multi-level operation — make that visible.
	_status_lbl.text = "Moved %d tile(s) to %s (%d cell(s) updated)." % [
		indices.size(), BLOCK_NAMES[dst_bt], cells_changed
	]


## Convert every tile currently in `_move_selected` (within
## `selected_block`) into a brand-new actor of type `actor_type`. One actor
## per tile — they're each independent placeable entities. The source tile
## is removed from the tile bucket; placed cells that referenced it are
## erased (we don't auto-spawn actors at those positions because the
## semantics would be surprising — see the dialog's note label).
##
## `clear_cells` mirrors the "Update placed cells" checkbox. When true,
## referencing cells become Empty; when false they're left dangling
## (they'll fall back to the eraser color via the existing oob guard but
## still represent stale references — only use this if you know what you
## want).
func _apply_move_tiles_to_actor(actor_type: String, clear_cells: bool) -> void:
	if not tile_library or _move_selected.is_empty():
		return
	var src_bt: int = selected_block
	var indices: Array = _move_selected.keys()
	indices.sort()

	# Grab tile names + images BEFORE popping, so we can generate sensible
	# actor names ("Spike → Actor 'Spike'") and feed images into the
	# library's actor slot.
	var pending: Array = []  # [{name, image}, ...] in ascending src order
	for ti in indices:
		var nm: String = tile_library.get_tile_name(src_bt, ti)
		var img: Image = tile_library.get_tile_image(src_bt, ti)
		if img == null:
			continue
		pending.append({"name": nm, "image": img.duplicate()})

	# Remove the source tiles. We still need the remap so we can find/erase
	# placed cells that referenced them.
	var remap: Dictionary = tile_library.remove_tiles(src_bt, indices)

	# Spawn the actors. Indices land at `actor_names.size()` and march up
	# so `actor_sprites` keys stay aligned with the parallel name/type arrays.
	var new_actor_count: int = 0
	for rec in pending:
		var new_idx: int = actor_names.size()
		var aname: String = String(rec["name"])
		if aname.is_empty():
			aname = actor_type
		actor_names.append(aname)
		actor_types.append(actor_type)
		tile_library.add_tile_as_actor_at(new_idx, rec["image"], aname, actor_type)
		new_actor_count += 1

	# Fix up placed cells: moved tiles are now dead refs (remap bt = -1).
	# Survivors got shifted down.
	var cells_changed: int = 0
	for lvl in levels:
		var g = lvl.get("grid", null)
		if typeof(g) != TYPE_ARRAY:
			continue
		for y in range(g.size()):
			var row = g[y]
			if typeof(row) != TYPE_ARRAY:
				continue
			for x in range(row.size()):
				var cell = row[x]
				if typeof(cell) != TYPE_DICTIONARY:
					continue
				if int(cell.get("block_type", 0)) != src_bt:
					continue
				var old_ti: int = int(cell.get("tile_index", 0))
				if not remap.has(old_ti):
					continue
				var r: Dictionary = remap[old_ti]
				var new_bt: int = int(r["bt"])
				var new_ti: int = int(r["idx"])
				if new_bt == -1:
					# Source tile is gone — erase or leave dangling.
					if clear_cells:
						cell["block_type"] = BLOCK_EMPTY
						cell["tile_index"] = 0
						cells_changed += 1
				elif new_bt == src_bt and new_ti != old_ti:
					cell["tile_index"] = new_ti
					cells_changed += 1

	# Refresh current paint index if it pointed at a removed tile.
	if remap.has(selected_tile_index):
		var rs: Dictionary = remap[selected_tile_index]
		if int(rs["bt"]) == -1:
			selected_tile_index = 0
		else:
			selected_tile_index = int(rs["idx"])

	_move_selected.clear()
	_update_change_cat_visibility()
	_rebuild_tile_palette()
	_rebuild_actors_list()
	if is_instance_valid(_grid_canvas):
		_grid_canvas.queue_redraw()
	_status_lbl.text = "Created %d actor(s) of type %s (%d cell(s) cleared)." % [
		new_actor_count, actor_type, cells_changed
	]


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
			var flip_h: bool = false
			var flip_v: bool = false

			if cell is Dictionary:
				block_type = cell.get("block_type", 0)
				tile_idx = cell.get("tile_index", 0)
				flip_h = bool(cell.get("flip_h", false))
				flip_v = bool(cell.get("flip_v", false))
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
					# Per-instance flip: scale the canvas transform around
					# the cell's center, then draw with the normal positive
					# rect. Negative-size Rect2 drawing is unreliable in
					# Godot 4.6 (the texture can render in the next cell).
					if flip_h or flip_v:
						var center: Vector2 = rect.position + rect.size * 0.5
						var sx := -1.0 if flip_h else 1.0
						var sy := -1.0 if flip_v else 1.0
						_grid_canvas.draw_set_transform(
							center, 0.0, Vector2(sx, sy)
						)
						# In transform space the cell center is the origin,
						# so the rect goes from -size/2 to +size/2.
						var local_rect: Rect2 = Rect2(-rect.size * 0.5, rect.size)
						_grid_canvas.draw_texture_rect(tex, local_rect, false)
						_grid_canvas.draw_set_transform(
							Vector2.ZERO, 0.0, Vector2.ONE
						)
					else:
						_grid_canvas.draw_texture_rect(tex, rect, false)
					# Color-coded outline at 35% alpha for block type hints
					var outline_color = BLOCK_COLORS[block_type]
					outline_color.a = 0.35
					_grid_canvas.draw_rect(rect, outline_color, false, 2.0)
				else:
					_grid_canvas.draw_rect(rect, BLOCK_COLORS[block_type])

			# Selection highlight for the placed tile under inspection.
			if _props_target.get("kind", "") == "cell" \
					and int(_props_target.get("x", -1)) == x \
					and int(_props_target.get("y", -1)) == y:
				_grid_canvas.draw_rect(rect, Color(1.0, 0.85, 0.20, 0.95), false, 2.5)

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
				_user_zoom_override = true
				_apply_zoom()
				_grid_canvas.accept_event()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_user_zoom_override = true
				_apply_zoom()
				_grid_canvas.accept_event()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Ctrl+Click: select a placed tile (don't paint) so its
				# per-instance properties (flip H/V) can be edited in the
				# right-dock Properties panel. No-op for empty cells.
				if event.ctrl_pressed and not _waypoint_mode:
					_select_placed_tile(event.position)
					return
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
	# Clear any in-progress move selection — indices are scoped to a
	# single block-type bucket so they're meaningless after switching.
	_move_selected.clear()
	_sync_import_target_to_selected()
	_update_change_cat_visibility()
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
	_rebuild_actors_list()
	_refresh_props_panel()


# ── Right-dock: actors list (#2) ─────────────────────────────
func _rebuild_actors_list() -> void:
	if not is_instance_valid(_actors_list_vbox):
		return
	for c in _actors_list_vbox.get_children():
		c.queue_free()
	if selected_level < 0 or selected_level >= levels.size():
		return
	var lvl: Dictionary = levels[selected_level]
	var lvl_actors: Array = lvl.get("actors", [])
	if lvl_actors.is_empty():
		var empty = Label.new()
		empty.text = "(no actors placed)"
		empty.label_settings = _ls(10, DIM)
		_actors_list_vbox.add_child(empty)
		return
	for i in range(lvl_actors.size()):
		var a: Dictionary = lvl_actors[i]
		var idx: int = int(a.get("actor_index", 0))
		var aname: String = actor_names[idx] if idx >= 0 and idx < actor_names.size() else "Actor"
		var atype: String = actor_types[idx] if idx >= 0 and idx < actor_types.size() else ""
		var btn = Button.new()
		btn.text = "  " + aname + "  ·  " + atype + "  @ (" + str(a.get("x", 0)) + "," + str(a.get("y", 0)) + ")"
		btn.add_theme_font_size_override("font_size", 10)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = "Click to focus this actor on the grid"
		var ns = StyleBoxFlat.new()
		ns.bg_color = Color(0.14, 0.14, 0.18)
		ns.set_corner_radius_all(3)
		ns.content_margin_left = 4; ns.content_margin_right = 4
		ns.content_margin_top = 2;  ns.content_margin_bottom = 2
		var clr: Color = ACTOR_TYPE_COLORS.get(atype, Color(0.7, 0.7, 0.7))
		ns.border_width_left = 3
		ns.border_color = clr
		btn.add_theme_stylebox_override("normal", ns)
		var hs = ns.duplicate()
		hs.bg_color = Color(0.20, 0.22, 0.28)
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_color_override("font_color", LABEL_CLR)
		btn.add_theme_color_override("font_hover_color", WHITE)
		btn.pressed.connect(_on_actors_list_clicked.bind(i))
		_actors_list_vbox.add_child(btn)


func _on_actors_list_clicked(actor_idx: int) -> void:
	_props_target = {"kind": "actor", "index": actor_idx}
	_refresh_props_panel()


## Ctrl+Click handler: select the placed tile under the cursor so its
## per-instance properties show in the right-dock Properties panel.
## Empty / out-of-bounds cells clear the selection.
func _select_placed_tile(pos: Vector2) -> void:
	var gp = _grid_pos(pos)
	if gp.x < 0 or gp.x >= _lvl_w() or gp.y < 0 or gp.y >= _lvl_h():
		_props_target = {}
		_refresh_props_panel()
		_grid_canvas.queue_redraw()
		return
	var cell = levels[selected_level]["grid"][gp.y][gp.x]
	var bt: int = 0
	if cell is Dictionary:
		bt = int(cell.get("block_type", 0))
	elif cell is int or cell is float:
		bt = int(cell)
	if bt == BLOCK_EMPTY:
		_props_target = {}
	else:
		_props_target = {"kind": "cell", "x": gp.x, "y": gp.y}
	_refresh_props_panel()
	_grid_canvas.queue_redraw()


# ── Right-dock: properties panel (#2) ────────────────────────
func _refresh_props_panel() -> void:
	if not is_instance_valid(_props_vbox):
		return
	for c in _props_vbox.get_children():
		c.queue_free()
	# Show context-sensitive info: selected actor (from list) > selected
	# tile (from palette).
	if _props_target.get("kind", "") == "actor":
		var i: int = int(_props_target.get("index", -1))
		if selected_level >= 0 and i >= 0:
			var lvl: Dictionary = levels[selected_level]
			var arr: Array = lvl.get("actors", [])
			if i < arr.size():
				var a: Dictionary = arr[i]
				var idx: int = int(a.get("actor_index", 0))
				var aname: String = actor_names[idx] if idx >= 0 and idx < actor_names.size() else "Actor"
				var atype: String = actor_types[idx] if idx >= 0 and idx < actor_types.size() else ""
				_props_vbox.add_child(_props_kv("Name", aname))
				_props_vbox.add_child(_props_kv("Type", atype))
				_props_vbox.add_child(_props_kv("Position", "(" + str(a.get("x", 0)) + ", " + str(a.get("y", 0)) + ")"))
				var wp: Array = a.get("waypoints", [])
				_props_vbox.add_child(_props_kv("Waypoints", str(wp.size())))
				return
	# Placed tile inspector (Ctrl+Click on a cell): expose the small set
	# of per-instance properties that justify staying in AGCK rather than
	# bouncing to VG's full 2D editor — flip H / flip V. Anything beyond
	# this (rotation, modulate, per-instance shaders, free positioning)
	# belongs in VG's 2D editor; see header comment in this file.
	if _props_target.get("kind", "") == "cell" and selected_level >= 0:
		var cx: int = int(_props_target.get("x", -1))
		var cy: int = int(_props_target.get("y", -1))
		if cx >= 0 and cx < _lvl_w() and cy >= 0 and cy < _lvl_h():
			var grid_arr: Array = levels[selected_level]["grid"]
			var cell_v = grid_arr[cy][cx]
			# Promote primitive cells to dict so flips can be stored.
			if not (cell_v is Dictionary):
				cell_v = {
					"block_type": int(cell_v) if (cell_v is int or cell_v is float) else 0,
					"tile_index": 0,
				}
				grid_arr[cy][cx] = cell_v
			var cbt: int = int(cell_v.get("block_type", 0))
			var cti: int = int(cell_v.get("tile_index", 0))
			var cell_tname: String = "?"
			if tile_library:
				cell_tname = str(tile_library.get_tile_name(cbt, cti))
			_props_vbox.add_child(_props_kv("Cell", "(" + str(cx) + ", " + str(cy) + ")"))
			_props_vbox.add_child(_props_kv("Block", BLOCK_NAMES[cbt]))
			_props_vbox.add_child(_props_kv("Tile", cell_tname))
			_props_vbox.add_child(_make_cell_flip_check("Flip H", "flip_h", cx, cy))
			_props_vbox.add_child(_make_cell_flip_check("Flip V", "flip_v", cx, cy))
			var hint2 = Label.new()
			hint2.text = "Tip: for rotation / shaders / free positioning, open the tile in VG's Sprite Editor or 2D Editor."
			hint2.label_settings = _ls(9, DIM)
			hint2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_props_vbox.add_child(hint2)
			return
	# Fallback: show selected tile.
	if tile_library and selected_block != BLOCK_EMPTY:
		var tname := str(tile_library.get_tile_name(selected_block, selected_tile_index))
		_props_vbox.add_child(_props_kv("Tile", tname))
		_props_vbox.add_child(_props_kv("Block", BLOCK_NAMES[selected_block]))
	else:
		var hint = Label.new()
		hint.text = "Click an actor or tile to view its properties."
		hint.label_settings = _ls(10, DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_props_vbox.add_child(hint)


func _props_kv(k: String, v: String) -> Control:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var kl = Label.new()
	kl.text = k
	kl.label_settings = _ls(10, DIM)
	kl.custom_minimum_size.x = 70
	hb.add_child(kl)
	var vl = Label.new()
	vl.text = v
	vl.label_settings = _ls(10, LABEL_CLR)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.clip_text = true
	hb.add_child(vl)
	return hb


## CheckBox row for a per-instance bool on a placed tile (flip_h / flip_v).
## Toggling pushes an undo snapshot, mutates the cell dict in place, and
## refreshes the grid + properties panel.
func _make_cell_flip_check(label_text: String, key: String, cx: int, cy: int) -> Control:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var kl = Label.new()
	kl.text = label_text
	kl.label_settings = _ls(10, DIM)
	kl.custom_minimum_size.x = 70
	hb.add_child(kl)
	var cb = CheckBox.new()
	cb.add_theme_font_size_override("font_size", 10)
	var cur_val: bool = false
	if selected_level >= 0:
		var c = levels[selected_level]["grid"][cy][cx]
		if c is Dictionary:
			cur_val = bool(c.get(key, false))
	cb.button_pressed = cur_val
	cb.toggled.connect(_on_cell_flip_toggled.bind(key, cx, cy))
	hb.add_child(cb)
	return hb


func _on_cell_flip_toggled(pressed: bool, key: String, cx: int, cy: int) -> void:
	if selected_level < 0:
		return
	if cx < 0 or cx >= _lvl_w() or cy < 0 or cy >= _lvl_h():
		return
	_begin_stroke()
	var c = levels[selected_level]["grid"][cy][cx]
	if not (c is Dictionary):
		c = {"block_type": int(c) if (c is int or c is float) else 0, "tile_index": 0}
		levels[selected_level]["grid"][cy][cx] = c
	c[key] = pressed
	_end_stroke()
	_grid_canvas.queue_redraw()
	_mark_dirty()
	level_changed.emit(selected_level)


# ── Keyboard shortcuts (#8) ────────────────────────────────────
# 1-8       — block-type select        [ / ]   — prev / next tile
# B         — paint mode (clear fill / wp)     G — flood fill toggle
# E         — eraser (Empty block)             W — waypoints toggle
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Don't hijack typing in text fields.
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit or f is TextEdit or f is SpinBox:
		return
	# Only act when our editor is actually visible (the AGCK plugin tabs us
	# in/out — without this, hotkeys would fire from anywhere).
	if not is_visible_in_tree():
		return
	var k := event as InputEventKey
	# Number keys 1-8 for block types
	if k.keycode >= KEY_1 and k.keycode <= KEY_8:
		var bt: int = int(k.keycode) - int(KEY_1)
		if bt < BLOCK_NAMES.size():
			_on_block_selected(bt)
			get_viewport().set_input_as_handled()
			return
	match k.keycode:
		KEY_B:
			# Paint mode — turn off fill + waypoints
			if is_instance_valid(_flood_btn):
				_flood_btn.button_pressed = false
			if is_instance_valid(_waypoint_btn):
				_waypoint_btn.button_pressed = false
			get_viewport().set_input_as_handled()
		KEY_G:
			if is_instance_valid(_flood_btn):
				_flood_btn.button_pressed = not _flood_btn.button_pressed
			get_viewport().set_input_as_handled()
		KEY_E:
			_on_block_selected(BLOCK_EMPTY)
			get_viewport().set_input_as_handled()
		KEY_W:
			if is_instance_valid(_waypoint_btn):
				_waypoint_btn.button_pressed = not _waypoint_btn.button_pressed
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			_cycle_tile(-1)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			_cycle_tile(1)
			get_viewport().set_input_as_handled()
		# Quick per-instance flips for the placed tile under the cursor.
		# H = flip horizontal, V = flip vertical. Works on whatever cell
		# the mouse is hovering over — no Ctrl+Click needed.
		KEY_H:
			_flip_cell_at_cursor("flip_h")
			get_viewport().set_input_as_handled()
		KEY_V:
			_flip_cell_at_cursor("flip_v")
			get_viewport().set_input_as_handled()


## Toggle a flip flag on the placed tile under the cursor. Used by
## the H / V hotkeys and the right-click "Flip H/V" context menu items.
## Promotes a primitive cell to dict on first toggle.
func _flip_cell_at_cursor(key: String) -> void:
	var gp := _grid_pos(_last_mouse_pos)
	_flip_cell(gp.x, gp.y, key)


func _flip_cell(cx: int, cy: int, key: String) -> void:
	if selected_level < 0:
		return
	if cx < 0 or cx >= _lvl_w() or cy < 0 or cy >= _lvl_h():
		return
	var grid_arr: Array = levels[selected_level]["grid"]
	var cell = grid_arr[cy][cx]
	var bt: int = 0
	if cell is Dictionary:
		bt = int(cell.get("block_type", 0))
	elif cell is int or cell is float:
		bt = int(cell)
	if bt == BLOCK_EMPTY:
		_status_lbl.text = "Empty cell — place a tile first to flip it."
		return
	_begin_stroke()
	if not (cell is Dictionary):
		cell = {"block_type": bt, "tile_index": 0}
		grid_arr[cy][cx] = cell
	cell[key] = not bool(cell.get(key, false))
	_end_stroke()
	_grid_canvas.queue_redraw()
	_mark_dirty()
	level_changed.emit(selected_level)
	# If this cell is the one being inspected, refresh checkboxes.
	if _props_target.get("kind", "") == "cell" \
			and int(_props_target.get("x", -1)) == cx \
			and int(_props_target.get("y", -1)) == cy:
		_refresh_props_panel()
	var human := "Flip H" if key == "flip_h" else "Flip V"
	var on_off := "ON" if cell[key] else "OFF"
	_status_lbl.text = "%s %s @ (%d, %d)" % [human, on_off, cx, cy]


func _cycle_tile(delta: int) -> void:
	if not tile_library or selected_block == BLOCK_EMPTY:
		return
	var n: int = tile_library.get_tile_count(selected_block)
	if n <= 0:
		return
	selected_tile_index = (selected_tile_index + delta + n) % n
	_rebuild_tile_palette()
	_refresh_props_panel()


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

	# Bridge to VG's full Sprite Editor for advanced edits (rotate, layers,
	# frames, shaders, etc.). The inline editor stays as a "quick" path for
	# block-aware palette edits; anything beyond a few pixels should go to
	# VG's editor. See AGCK header comment for the editor-boundary policy.
	var open_vg_btn = Button.new()
	open_vg_btn.text = "Open in VG Sprite Editor →"
	open_vg_btn.tooltip_text = "Export this tile as PNG and open it in VG's Sprite Editor for advanced editing. Save in VG to round-trip back into the tile library."
	open_vg_btn.add_theme_font_size_override("font_size", 11)
	var ovg_s = StyleBoxFlat.new()
	ovg_s.bg_color = Color(0.45, 0.30, 0.65)
	ovg_s.set_corner_radius_all(4)
	ovg_s.content_margin_left = 8
	ovg_s.content_margin_right = 8
	ovg_s.content_margin_top = 3
	ovg_s.content_margin_bottom = 3
	open_vg_btn.add_theme_stylebox_override("normal", ovg_s)
	open_vg_btn.add_theme_color_override("font_color", WHITE)
	open_vg_btn.pressed.connect(_on_edit_open_in_vg_sprite_editor)
	tool_row.add_child(open_vg_btn)

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


## Export the current edit image to a PNG under user:// and hand it off
## to VG's full Sprite Editor via VGPluginRegistry. A Timer polls the
## file's mtime; when the user saves in the Sprite Editor the new image
## is reloaded into the tile library, replacing the original tile.
##
## This is the "advanced edits" escape hatch documented in the AGCK
## header — the inline popup is intentionally limited to block-aware
## quick edits; rotation, layers, frames, and shaders all live in VG.
func _on_edit_open_in_vg_sprite_editor() -> void:
	if not _edit_image or _edit_block_type < 0 or _edit_tile_index < 0:
		return
	# Persist current name + shader-fx selection before bouncing out so
	# the in-progress popup state isn't lost.
	var bt: int = _edit_block_type
	var ti: int = _edit_tile_index
	var dir_path := "user://agck_tile_bridge"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	# Use a stable filename per (bt, ti) so re-opening the same tile
	# reuses the same buffer rather than spawning new files.
	var file_name := "tile_%d_%d.png" % [bt, ti]
	var save_path := dir_path + "/" + file_name
	var err := _edit_image.save_png(save_path)
	if err != OK:
		_status_lbl.text = "❌ Bridge: could not write " + save_path + " (err=" + str(err) + ")"
		return
	# Close inline popup — the VG Sprite Editor takes over.
	_close_edit_popup()
	# Set up the watcher.
	_vg_bridge_path = save_path
	_vg_bridge_bt = bt
	_vg_bridge_ti = ti
	_vg_bridge_mtime = FileAccess.get_modified_time(save_path)
	if not is_instance_valid(_vg_bridge_timer):
		_vg_bridge_timer = Timer.new()
		_vg_bridge_timer.wait_time = 1.0
		_vg_bridge_timer.one_shot = false
		_vg_bridge_timer.timeout.connect(_check_vg_bridge)
		add_child(_vg_bridge_timer)
	_vg_bridge_timer.start()
	# Hand off to the registry. The registry script lives at a known
	# absolute path; load it dynamically rather than via the global
	# class_name so AGCK can be used in environments where the registry
	# isn't part of the parsed class index yet.
	var opened := false
	var reg_script := load("res://addons/visual_gasic/vg_plugin_registry.gd")
	if reg_script != null:
		var reg = reg_script.get_instance()
		if reg != null and reg.has_method("open_asset"):
			opened = bool(reg.open_asset(save_path))
	if opened:
		_status_lbl.text = "🎨 Editing tile in VG Sprite Editor — save there to round-trip back."
	else:
		_status_lbl.text = "⚠ Could not route to VG Sprite Editor; PNG written to " + save_path
		push_warning("[AGCK] Bridge: VGPluginRegistry.open_asset failed for " + save_path
			+ " — registry loaded=" + str(reg_script != null))


func _check_vg_bridge() -> void:
	if _vg_bridge_path.is_empty():
		if is_instance_valid(_vg_bridge_timer):
			_vg_bridge_timer.stop()
		return
	if not FileAccess.file_exists(_vg_bridge_path):
		return
	var m := FileAccess.get_modified_time(_vg_bridge_path)
	if m == _vg_bridge_mtime:
		return
	_vg_bridge_mtime = m
	var img := Image.load_from_file(_vg_bridge_path)
	if img == null:
		return
	if tile_library and _vg_bridge_bt >= 0 and _vg_bridge_ti >= 0:
		tile_library.update_tile(_vg_bridge_bt, _vg_bridge_ti, img)
		if is_instance_valid(_grid_canvas):
			_grid_canvas.queue_redraw()
		_rebuild_tile_palette()
		_status_lbl.text = "🔄 Tile updated from VG Sprite Editor."
		_mark_dirty()
		level_changed.emit(selected_level)


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
	# Wipe NEW marks from any prior import wave — only the freshly added
	# tiles in THIS wave should get the badge.
	tile_library.clear_new_marks()
	var count := 0
	for path in paths:
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			push_warning("AGCK: Could not load image: " + path)
			continue
		var fname: String = path.get_file().get_basename()
		count += _slice_image_into_tiles(img, fname, " (imported)")
	_rebuild_tile_palette()
	_grid_canvas.queue_redraw()
	if count > 0:
		_status_lbl.text = "Imported " + str(count) + " tile(s)!"
	else:
		_status_lbl.text = "No tiles imported."


## ─── Tilesheet auto-slicing ──────────────────────────────────────
##
## Detect a 2D tile grid in `img` and add each cell as a tile under the
## currently selected block-type. Returns the number of tiles added.
##
## Detection precedence:
##   1. Image small enough to be a single tile  -> single tile.
##   2. Standard tile size divides both axes    -> grid slice.
##   3. gcd(w, h) is reasonable                 -> grid slice.
##   4. Otherwise                               -> single tile (resized).
##
## Single-tile and 1-row-strip imports keep working — they fall out of
## case 1 / case 2 with rows=1.
func _slice_image_into_tiles(img: Image, base_name: String, suffix: String = "") -> int:
	var target_bt: int = _get_import_target_block()
	var pre_count: int = tile_library.get_tile_count(target_bt)
	var grid := _detect_tile_grid(img)
	if grid.is_empty():
		# Single tile — resize to AGCK's 18x18 cell size.
		var single := img.duplicate()
		single.resize(18, 18, Image.INTERPOLATE_NEAREST)
		tile_library.add_custom_tile(target_bt, base_name + suffix, single)
		_mark_tiles_new_since(target_bt, pre_count)
		return 1
	var cell: int = grid["cell"]
	var cols: int = grid["cols"]
	var rows: int = grid["rows"]
	var added := 0
	var idx := 0
	for ry in range(rows):
		for cx in range(cols):
			idx += 1
			var sub := img.get_region(Rect2i(cx * cell, ry * cell, cell, cell))
			if _is_image_empty(sub):
				continue  # Skip transparent/blank cells in padded sheets.
			sub.resize(18, 18, Image.INTERPOLATE_NEAREST)
			var tname := "%s_%d%s" % [base_name, idx, suffix]
			tile_library.add_custom_tile(target_bt, tname, sub)
			added += 1
	_mark_tiles_new_since(target_bt, pre_count)
	return added


## Flag every tile in `bt`'s bucket from index `since` to the end as NEW.
## Used to badge the most recently imported batch.
func _mark_tiles_new_since(bt: int, since: int) -> void:
	if not tile_library:
		return
	var count: int = tile_library.get_tile_count(bt)
	for i in range(since, count):
		tile_library.set_tile_is_new(bt, i, true)


## Returns {} if `img` should be treated as a single tile, otherwise
## {"cell": int, "cols": int, "rows": int} describing the grid.
const _TILE_SIZE_CANDIDATES := [64, 48, 32, 24, 18, 16, 96, 128, 8]

func _detect_tile_grid(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	# Tiny images are always a single tile (avoids slicing 18x18 source art).
	if max(w, h) <= 96:
		return {}
	# Try preferred cell sizes — largest first that yields >= 2 cells.
	var best: Dictionary = {}
	for cand in _TILE_SIZE_CANDIDATES:
		if cand > min(w, h):
			continue
		if w % cand != 0 or h % cand != 0:
			continue
		var cols: int = w / cand
		var rows: int = h / cand
		var cells: int = cols * rows
		if cells < 2 or cells > 1024:
			continue
		# Among valid candidates, prefer the LARGEST cell size (so we
		# don't over-slice a 64px-tile sheet into 16px chunks).
		if best.is_empty() or cand > int(best.get("cell", 0)):
			best = {"cell": cand, "cols": cols, "rows": rows}
	if not best.is_empty():
		return best
	# Fallback: gcd(w, h) when it's a reasonable tile size.
	var g := _gcd_int(w, h)
	if g >= 8 and g <= 128:
		var cols2: int = w / g
		var rows2: int = h / g
		if cols2 * rows2 >= 2 and cols2 * rows2 <= 1024:
			return {"cell": g, "cols": cols2, "rows": rows2}
	return {}


func _gcd_int(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


## True if every pixel in `img` is fully transparent. Used to skip empty
## cells in padded tilesheets (e.g. 4x4 sheet with only 12 art cells).
func _is_image_empty(img: Image) -> bool:
	if not img.detect_alpha():
		return false
	var w := img.get_width()
	var h := img.get_height()
	# Sample a sparse grid first to bail out fast on non-empty cells.
	var step: int = maxi(1, mini(w, h) / 8)
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			if img.get_pixel(x, y).a > 0.01:
				return false
			x += step
		y += step
	return true


# ─── Online Asset Browse ─────────────────────────────────────
# Pops a small chooser → opens the appropriate online browser. After the
# browser closes, scans res://assets/art/ for newly added PNGs and imports
# them as tiles for the currently selected block-type.

const _ONLINE_ASSETS_DIR := "res://assets/art/"

func _on_online_browse_pressed() -> void:
	if _online_chooser_popup and is_instance_valid(_online_chooser_popup):
		_online_chooser_popup.queue_free()
	_online_chooser_popup = PopupPanel.new()
	var pp_style := StyleBoxFlat.new()
	pp_style.bg_color = Color(0.13, 0.13, 0.16)
	pp_style.border_color = Color(0.30, 0.30, 0.34)
	pp_style.set_border_width_all(1)
	pp_style.set_corner_radius_all(4)
	pp_style.content_margin_left = 10; pp_style.content_margin_right = 10
	pp_style.content_margin_top = 10; pp_style.content_margin_bottom = 10
	_online_chooser_popup.add_theme_stylebox_override("panel", pp_style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_online_chooser_popup.add_child(vb)
	var ttl := Label.new()
	ttl.text = "Browse free CC0 game art"
	ttl.label_settings = _ls(11, ACCENT)
	vb.add_child(ttl)
	var hint := Label.new()
	hint.text = "Downloads land in res://assets/art/ and are auto-imported\nas tiles in '" + BLOCK_NAMES[selected_block] + "'."
	hint.label_settings = _ls(9, DIM)
	vb.add_child(hint)
	vb.add_child(HSeparator.new())
	var btn_oga := Button.new()
	btn_oga.text = "🎨 OpenGameArt — search & download images"
	btn_oga.add_theme_font_size_override("font_size", 11)
	btn_oga.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_oga.pressed.connect(_open_oga_browser)
	vb.add_child(btn_oga)
	var btn_kenney := Button.new()
	btn_kenney.text = "📦 Kenney.nl — curated CC0 asset packs"
	btn_kenney.add_theme_font_size_override("font_size", 11)
	btn_kenney.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_kenney.pressed.connect(_open_kenney_browser)
	vb.add_child(btn_kenney)
	var btn_scan := Button.new()
	btn_scan.text = "📁 Scan res://assets/art/ now"
	btn_scan.add_theme_font_size_override("font_size", 11)
	btn_scan.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_scan.tooltip_text = "Look for any PNGs already downloaded and import as tiles"
	btn_scan.pressed.connect(func():
		_online_chooser_popup.hide()
		var added := _ingest_assets_dir({}, 32)
		if added > 0:
			_status_lbl.text = "Imported %d tile(s) from %s" % [added, _ONLINE_ASSETS_DIR]
		else:
			_status_lbl.text = "No new PNGs found in " + _ONLINE_ASSETS_DIR
	)
	vb.add_child(btn_scan)
	add_child(_online_chooser_popup)
	_online_chooser_popup.popup_centered(Vector2i(360, 220))


func _open_oga_browser() -> void:
	if _online_chooser_popup and is_instance_valid(_online_chooser_popup):
		_online_chooser_popup.hide()
	_online_pre_scan_files = _snapshot_assets_dir()
	_opengameart_browser = OPENGAMEART_BROWSER_SCRIPT.new()
	_opengameart_browser.open(self, false)
	# When the dialog closes we ingest. The browser is a RefCounted that
	# creates its own AcceptDialog parented to `self` — wait one frame after
	# tree_exited fires, then scan.
	_watch_for_browser_close()


func _open_kenney_browser() -> void:
	if _online_chooser_popup and is_instance_valid(_online_chooser_popup):
		_online_chooser_popup.hide()
	_online_pre_scan_files = _snapshot_assets_dir()
	_kenney_browser = KENNEY_BROWSER_SCRIPT.new()
	_kenney_browser.open(self, false)
	_watch_for_browser_close()


func _watch_for_browser_close() -> void:
	# The browser dialogs add themselves as children of `self`. Poll for
	# their disappearance, then scan once.
	var t := Timer.new()
	t.wait_time = 0.6
	t.one_shot = false
	add_child(t)
	t.timeout.connect(func():
		# AcceptDialog children disappear when user closes; check.
		var any_open := false
		for c in get_children():
			if c is AcceptDialog and c.visible:
				any_open = true
				break
		if not any_open:
			t.stop()
			t.queue_free()
			var added := _ingest_assets_dir(_online_pre_scan_files, 24)
			if added > 0:
				_status_lbl.text = "Imported %d new tile(s) from downloads" % added
			else:
				_status_lbl.text = "No new image files were downloaded."
	)
	t.start()


func _snapshot_assets_dir() -> Dictionary:
	var snap: Dictionary = {}
	_walk_assets_dir(_ONLINE_ASSETS_DIR, snap)
	return snap


func _walk_assets_dir(path: String, out: Dictionary) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var f := d.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		var full := path + ("" if path.ends_with("/") else "/") + f
		if d.current_is_dir():
			_walk_assets_dir(full, out)
		else:
			var lf := f.to_lower()
			if lf.ends_with(".png") or lf.ends_with(".jpg") or lf.ends_with(".jpeg"):
				out[full] = FileAccess.get_modified_time(full)
	d.list_dir_end()


func _ingest_assets_dir(skip: Dictionary, cap: int) -> int:
	if not tile_library:
		return 0
	var current := _snapshot_assets_dir()
	# Find new files (not in skip).
	var new_paths: Array = []
	for p in current.keys():
		if not skip.has(p):
			new_paths.append(p)
	# Most-recent first; cap to avoid swamping the palette.
	new_paths.sort_custom(func(a, b): return int(current[a]) > int(current[b]))
	if new_paths.size() > cap:
		new_paths.resize(cap)
	var added := 0
	if new_paths.size() > 0:
		# Auto-ingest is its own import wave — wipe stale NEW marks first
		# so only this batch lights up.
		tile_library.clear_new_marks()
	for path in new_paths:
		var img := Image.new()
		if img.load(path) != OK:
			continue
		# Skip absurdly large sheets (anything over 4096px we leave alone).
		if img.get_width() > 4096 or img.get_height() > 4096:
			continue
		var fname: String = path.get_file().get_basename()
		added += _slice_image_into_tiles(img, fname, "")
	if added > 0:
		_rebuild_tile_palette()
		if is_instance_valid(_grid_canvas):
			_grid_canvas.queue_redraw()
	return added


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
