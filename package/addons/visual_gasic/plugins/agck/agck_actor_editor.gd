@tool
## AGCK Actor Editor — visual card gallery
##
## Actors displayed as a scrollable card grid instead of list + form.
## Click a card to expand its property panel. Color-coded by type.
extends VBoxContainer

signal actor_changed(actor_id: int)
signal switch_tab_requested(tab_index: int)  # Request plugin to switch to another editor tab

# ─── Theme ───────────────────────────────────────────────────
const BG_COLOR   = Color(0.13, 0.13, 0.16)
const HEADER_BG  = Color(0.10, 0.10, 0.13)
const CARD_BG    = Color(0.15, 0.16, 0.20)
const CARD_SEL   = Color(0.22, 0.26, 0.40)
const WHITE      = Color(1.0, 1.0, 1.0)
const LABEL_CLR  = Color(0.88, 0.86, 0.80)
const ACCENT     = Color(1.0, 0.82, 0.35)
const DIM        = Color(0.50, 0.50, 0.55)

const TYPE_COLORS = {
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
const ACTOR_TYPES    = ["Player", "Drone", "Missile", "Sentry", "Computer", "Zombie", "Boss", "Bat", "NPC", "Tank", "Fireball"]
const MAX_ACTORS     = 16
const FREESOUND_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/freesound_browser.gd")
const OPENGAMEART_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/opengameart_browser.gd")
const KENNEY_BROWSER_SCRIPT := preload("res://addons/visual_gasic/asset_browser/kenney_browser.gd")

# ─── Built-in Palettes ──────────────────────────────────────
const AGCK_PALETTES := {
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

# ─── Per-Sprite Shader FX ────────────────────────────────────
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

# ─── Sound Event Presets ─────────────────────────────────────
# Fallback list if no sound_editor reference is available
const SOUND_PRESETS: Array = [
	"(None)", "Jump", "Coin", "Hit", "Hero Death",
	"Enemy Death", "Shoot", "Powerup", "Game Over",
]

# ─── Data ────────────────────────────────────────────────────
var actors: Array = []
var selected_actor: int = 0

# Reference to tile library for actor sprite previews (set by agck_plugin.gd)
var tile_library = null
# Reference to sound editor for dynamic name list & preview (set by agck_plugin.gd)
var sound_editor = null

# ─── UI Refs ─────────────────────────────────────────────────
var _card_grid: GridContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_panel: VBoxContainer = null
var _card_buttons: Array = []

# Type picker popup
var _type_picker_popup: PopupPanel = null
var _type_picker_grid: GridContainer = null
var _type_picker_btn: Button = null
var _type_preview_textures: Dictionary = {}  # { "Player": ImageTexture, ... }

# Inline sprite editor popup
var _edit_popup: Window = null
var _edit_canvas: Control = null
var _edit_image: Image = null
var _edit_actor_id: int = -1
var _edit_color: Color = Color.WHITE
var _edit_erasing: bool = false
var _edit_pen_size: int = 1
var _edit_tool: int = 0  # 0=Pen, 1=Fill, 2=Line, 3=Rect
var _edit_mirror_h: bool = false
var _edit_line_start: Vector2i = Vector2i(-1, -1)
var _edit_tool_buttons: Array = []
var _edit_palette_btns: Array = []
var _edit_palette_colors: Array = []
var _edit_palette_row: HBoxContainer = null  # stored for Lospec rebuild
# Custom palette persistence (shared file with VG sprite editor)
const AGCK_CUSTOM_PALETTES_PATH := "user://vg_custom_palettes.json"
var _agck_custom_palettes: Dictionary = {}  ## name → Array of "#RRGGBB"
var _agck_palette_option: OptionButton = null
var _agck_palette_remove_btn: Button = null
# Lospec palette browser (AGCK)
var _agck_lospec_http: HTTPRequest = null
var _agck_lospec_dialog: AcceptDialog = null
var _agck_lospec_results_box: VBoxContainer = null
var _agck_lospec_search_edit: LineEdit = null
var _agck_lospec_sort_option: OptionButton = null
var _agck_lospec_page := 0
var _agck_lospec_palettes: Array = []
var _agck_lospec_total := 0
var _agck_lospec_selected_index := -1
var _agck_lospec_selected_row: PanelContainer = null
var _agck_lospec_page_label: Label = null
var _freesound_browser: RefCounted = null
var _opengameart_browser: RefCounted = null
var _kenney_browser: RefCounted = null
var _edit_sprite_undo: Array = []  # Array of Image snapshots
var _edit_sprite_redo: Array = []
var _edit_stroke_snap: Image = null
var _confirm_dialog: ConfirmationDialog = null
var _pending_confirm_action: Callable
var _sprite_import_dialog: FileDialog = null
# Frame animation editor
var _edit_frames: Array = []        # Array of Image — frames for CURRENT animation
var _edit_current_frame: int = 0    # Currently displayed frame index
var _edit_frame_label: Label = null # "Frame 1/4" display
var _edit_onion_skin: bool = false  # Show previous frame ghosted behind current
var _edit_preview_rect: TextureRect = null  # Animated preview
var _edit_frame_clipboard: Image = null   # Copied frame for paste
# Named animation editor
var _edit_anims: Dictionary = {}     # { "Idle": [Image,...], "Walk": [Image,...], ... }
var _edit_current_anim: String = ""  # Currently selected animation name
var _edit_anim_row: HBoxContainer = null  # Container for animation tabs
var _edit_anim_btns: Array = []      # Tab button references

# Preset animation colors for tabs
const ANIM_COLORS = {
	"Idle":    Color(0.30, 0.75, 0.95),
	"Walk":    Color(0.25, 0.70, 0.25),
	"Run":     Color(0.90, 0.75, 0.20),
	"Jump":    Color(0.65, 0.30, 0.85),
	"Fall":    Color(0.70, 0.40, 0.90),
	"Fly":     Color(0.90, 0.55, 0.15),
	"Hover":   Color(0.45, 0.80, 0.90),
	"Crouch":  Color(0.60, 0.50, 0.35),
	"Swim":    Color(0.20, 0.45, 0.85),
	"Attack":  Color(0.85, 0.20, 0.15),
	"Death":   Color(0.50, 0.50, 0.55),
	"Custom":  Color(0.80, 0.80, 0.80),
}
const ANIM_PRESETS = ["Idle", "Walk", "Run", "Jump", "Fall", "Fly", "Hover", "Crouch", "Swim", "Attack", "Death", "Custom"]


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
	_init_actors()
	_build_ui()


func _init_actors() -> void:
	actors.clear()
	actors.append(_make_actor("Hero", "Player"))
	actors.append(_make_actor("Enemy 1", "Drone"))
	actors.append(_make_actor("Bullet", "Missile"))
	while actors.size() < MAX_ACTORS:
		actors.append(_make_actor("Actor " + str(actors.size() + 1), "Drone"))


func _make_actor(aname: String, atype: String) -> Dictionary:
	return {
		"name": aname,
		"type": atype,
		"max_speed": 200,
		"collision_mode": "Bounce",
		"death_mode": "Respawn",
		"rebirth": 3.0,
		"entrance_mode": "Instant",
		"auto_shoot": false,
		"auto_shoot_interval": 1.0,
		"fx_spawn": "",
		"fx_death": "",
		"fx_hit": "",
		"anim_data": [{"name": "Idle", "speed": 8, "loop": true}],
		"max_hp": 100,
		"damage": 10,
		"score_value": 100,
		"gravity_scale": 1.0,
		"ai_behavior": "Chase",
		"ai_vision_range": 300,
		"ai_patrol_speed": 80,
		"shader_fx": "(None)",
		"shader_params": {},
		"jump_sound": "(None)",
		"hit_sound": "(None)",
		"death_sound": "(None)",
		"shoot_sound": "(None)",
		"pickup_sound": "(None)",
		"stomp_sound": "(None)",
	}


func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# ══════════════════════════════════════════════════════════
	# HEADER: Title + Add/Remove buttons
	# ══════════════════════════════════════════════════════════
	var header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = HEADER_BG
	h_style.content_margin_left = 10
	h_style.content_margin_right = 10
	h_style.content_margin_top = 6
	h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	header.add_child(hbox)

	var title = Label.new()
	title.text = "👾 Actor Gallery"
	title.label_settings = _ls(14, ACCENT)
	hbox.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var hint = Label.new()
	hint.text = "Click an actor card to edit it · " + str(MAX_ACTORS) + " slots"
	hint.label_settings = _ls(10, DIM)
	hbox.add_child(hint)

	# ══════════════════════════════════════════════════════════
	# MAIN: Card grid (top) + Detail panel (bottom)
	# ══════════════════════════════════════════════════════════
	var split = VSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	# Card grid scroll area
	var card_scroll = ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.custom_minimum_size.y = 120
	split.add_child(card_scroll)

	_card_grid = GridContainer.new()
	_card_grid.columns = 4
	_card_grid.add_theme_constant_override("h_separation", 6)
	_card_grid.add_theme_constant_override("v_separation", 6)
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(_card_grid)

	# Detail panel scroll area
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.custom_minimum_size.y = 200
	split.add_child(_detail_scroll)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 2)
	_detail_scroll.add_child(_detail_panel)

	_build_type_picker_popup()
	_rebuild_cards()
	_rebuild_detail()


# ─── Type Picker Popup ───────────────────────────────────────

func _build_type_picker_popup() -> void:
	_type_picker_popup = PopupPanel.new()
	var pp_sb = StyleBoxFlat.new()
	pp_sb.bg_color = Color(0.12, 0.12, 0.16)
	pp_sb.border_color = Color(0.35, 0.35, 0.45)
	pp_sb.set_border_width_all(1)
	pp_sb.set_corner_radius_all(6)
	pp_sb.content_margin_left = 8; pp_sb.content_margin_right = 8
	pp_sb.content_margin_top = 8; pp_sb.content_margin_bottom = 8
	_type_picker_popup.add_theme_stylebox_override("panel", pp_sb)
	add_child(_type_picker_popup)

	var picker_scroll = ScrollContainer.new()
	picker_scroll.custom_minimum_size = Vector2(520, 260)
	_type_picker_popup.add_child(picker_scroll)
	_apply_dark_scrollbar_theme(picker_scroll)

	_type_picker_grid = GridContainer.new()
	_type_picker_grid.columns = 4
	_type_picker_grid.add_theme_constant_override("h_separation", 6)
	_type_picker_grid.add_theme_constant_override("v_separation", 6)
	picker_scroll.add_child(_type_picker_grid)

	_rebuild_type_picker()


func _get_type_preview_texture(atype: String) -> ImageTexture:
	if _type_preview_textures.has(atype):
		return _type_preview_textures[atype]
	if tile_library:
		var color: Color = TYPE_COLORS.get(atype, DIM)
		var img: Image = tile_library._generate_character_sprite(atype, color)
		if img:
			var tex := ImageTexture.create_from_image(img)
			_type_preview_textures[atype] = tex
			return tex
	return null


func _rebuild_type_picker() -> void:
	if not is_instance_valid(_type_picker_grid):
		return
	for c in _type_picker_grid.get_children():
		c.queue_free()

	var current_type: String = ""
	if selected_actor >= 0 and selected_actor < actors.size():
		current_type = actors[selected_actor].get("type", "Drone")

	for atype in ACTOR_TYPES:
		var color: Color = TYPE_COLORS.get(atype, DIM)
		var is_sel: bool = (atype == current_type)
		var tex: ImageTexture = _get_type_preview_texture(atype)

		var card = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.26, 0.40) if is_sel else Color(0.16, 0.16, 0.20)
		style.set_corner_radius_all(6)
		style.border_width_left = 3
		style.border_color = color
		style.content_margin_left = 6; style.content_margin_right = 6
		style.content_margin_top = 6; style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(120, 100)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(vbox)

		# Sprite preview
		var center = CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(center)
		if tex:
			var tex_rect = TextureRect.new()
			tex_rect.texture = tex
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.custom_minimum_size = Vector2(48, 48)
			tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(tex_rect)
		else:
			var ph = ColorRect.new()
			ph.color = color.darkened(0.6)
			ph.custom_minimum_size = Vector2(48, 48)
			ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(ph)

		# Type name
		var name_lbl = Label.new()
		name_lbl.text = atype
		name_lbl.label_settings = _ls(11, color)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		# Selected checkmark
		if is_sel:
			var sel_lbl = Label.new()
			sel_lbl.text = "✓ Current"
			sel_lbl.label_settings = _ls(9, ACCENT)
			sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sel_lbl)

		# Click button overlay
		var btn = Button.new()
		btn.flat = true
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_type_card_clicked.bind(atype))
		var _s = style
		var _c = card
		var _at = atype
		btn.mouse_entered.connect(func():
			_s.bg_color = Color(0.28, 0.32, 0.48)
			_c.queue_redraw()
		)
		btn.mouse_exited.connect(func():
			var ct = ""
			if selected_actor >= 0 and selected_actor < actors.size():
				ct = actors[selected_actor].get("type", "")
			_s.bg_color = Color(0.22, 0.26, 0.40) if (_at == ct) else Color(0.16, 0.16, 0.20)
			_c.queue_redraw()
		)
		card.add_child(btn)

		_type_picker_grid.add_child(card)


func _on_type_picker_pressed() -> void:
	if is_instance_valid(_type_picker_popup) and is_instance_valid(_type_picker_btn):
		_rebuild_type_picker()
		var btn_rect = _type_picker_btn.get_global_rect()
		_type_picker_popup.popup(Rect2i(
			int(btn_rect.position.x), int(btn_rect.position.y + btn_rect.size.y + 2),
			540, 280
		))


func _on_type_card_clicked(type_name: String) -> void:
	_type_picker_popup.hide()
	var idx: int = ACTOR_TYPES.find(type_name)
	if idx < 0:
		return
	_on_type_changed(idx)


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
	for i in node.get_child_count(true):
		var child = node.get_child(i, true)
		if child is VScrollBar or child is HScrollBar:
			child.add_theme_stylebox_override("grabber", grab)
			child.add_theme_stylebox_override("grabber_highlight", grab_hl)
			child.add_theme_stylebox_override("grabber_pressed", grab_pr)
			child.add_theme_stylebox_override("scroll", track)
			child.custom_minimum_size = Vector2(12, 12)


# ─── Card Grid ───────────────────────────────────────────────

func _rebuild_cards() -> void:
	if not is_instance_valid(_card_grid):
		return
	for c in _card_grid.get_children():
		_card_grid.remove_child(c)
		c.queue_free()
	_card_buttons.clear()

	for i in range(actors.size()):
		var actor = actors[i]
		var atype = actor.get("type", "Drone")
		var color = TYPE_COLORS.get(atype, DIM)

		var card = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = CARD_SEL if i == selected_actor else CARD_BG
		style.set_corner_radius_all(6)
		style.border_width_left = 4
		style.border_color = color
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(160, 120)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Large centered sprite preview
		var sprite_center = CenterContainer.new()
		sprite_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(sprite_center)

		if tile_library:
			tile_library.ensure_actor_sprite(i, actor.get("name", "Actor"), atype)
			var actor_tex = tile_library.get_actor_texture(i)
			if actor_tex:
				var tex_rect = TextureRect.new()
				tex_rect.texture = actor_tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.custom_minimum_size = Vector2(64, 64)
				tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sprite_center.add_child(tex_rect)
			else:
				var placeholder = ColorRect.new()
				placeholder.color = Color(0.20, 0.20, 0.25)
				placeholder.custom_minimum_size = Vector2(64, 64)
				placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sprite_center.add_child(placeholder)
				var q_lbl = Label.new()
				q_lbl.text = "?"
				q_lbl.label_settings = _ls(24, DIM)
				q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				q_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				placeholder.add_child(q_lbl)
		else:
			var placeholder = ColorRect.new()
			placeholder.color = Color(0.20, 0.20, 0.25)
			placeholder.custom_minimum_size = Vector2(64, 64)
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sprite_center.add_child(placeholder)

		# Animation frame strip (show up to 6 small frames from first animation)
		if tile_library:
			var anims: Dictionary = tile_library.get_actor_anims(i)
			if anims.size() > 0:
				var first_anim_name: String = anims.keys()[0]
				var frames: Array = anims[first_anim_name]
				if frames.size() > 1:
					var strip_hbox = HBoxContainer.new()
					strip_hbox.add_theme_constant_override("separation", 2)
					strip_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
					vbox.add_child(strip_hbox)
					var show_count: int = mini(frames.size(), 6)
					for fi in range(show_count):
						var frame_img: Image = frames[fi]
						if frame_img:
							var ftex = ImageTexture.create_from_image(frame_img)
							var frect = TextureRect.new()
							frect.texture = ftex
							frect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
							frect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
							frect.custom_minimum_size = Vector2(18, 18)
							frect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
							frect.mouse_filter = Control.MOUSE_FILTER_IGNORE
							strip_hbox.add_child(frect)
					if frames.size() > 6:
						var more_lbl = Label.new()
						more_lbl.text = "+" + str(frames.size() - 6)
						more_lbl.label_settings = _ls(8, DIM)
						more_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
						strip_hbox.add_child(more_lbl)

		# Name label
		var name_lbl = Label.new()
		name_lbl.text = actor.get("name", "Actor")
		name_lbl.label_settings = _ls(11, WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		# Type label
		var type_lbl = Label.new()
		type_lbl.text = atype
		type_lbl.label_settings = _ls(9, color)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(type_lbl)

		# Animation info (compact)
		if tile_library:
			var anims2: Dictionary = tile_library.get_actor_anims(i)
			if anims2.size() > 0:
				var anim_parts: Array = []
				for anim_key in anims2.keys():
					anim_parts.append(str(anim_key) + "(" + str(anims2[anim_key].size()) + "f)")
				var anim_lbl = Label.new()
				anim_lbl.text = ", ".join(anim_parts)
				anim_lbl.label_settings = _ls(8, DIM)
				anim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				anim_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				anim_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				vbox.add_child(anim_lbl)

		# Click handler (invisible overlay)
		var btn = Button.new()
		btn.flat = true
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_card_clicked.bind(i))
		btn.gui_input.connect(_on_card_gui_input.bind(i))
		# Hover effect
		var _style_ref = style
		var _card_ref = card
		var _idx = i
		btn.mouse_entered.connect(func():
			_style_ref.bg_color = Color(0.25, 0.30, 0.45)
			_card_ref.queue_redraw()
		)
		btn.mouse_exited.connect(func():
			_style_ref.bg_color = CARD_SEL if (selected_actor == _idx) else CARD_BG
			_card_ref.queue_redraw()
		)
		card.add_child(btn)

		_card_grid.add_child(card)
		_card_buttons.append(card)


func _on_card_clicked(idx: int) -> void:
	selected_actor = idx
	_rebuild_cards()
	_rebuild_detail()
	actor_changed.emit(idx)


func _on_card_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_open_actor_sprite_editor(idx)


# ─── Detail Panel ────────────────────────────────────────────

func _rebuild_detail() -> void:
	if not is_instance_valid(_detail_panel):
		return
	for c in _detail_panel.get_children():
		c.queue_free()

	if selected_actor < 0 or selected_actor >= actors.size():
		return
	var actor = actors[selected_actor]
	var atype: String = actor.get("type", "Drone")
	var color = TYPE_COLORS.get(atype, DIM)

	# ── Header with name + type
	var h_panel = PanelContainer.new()
	var hs = StyleBoxFlat.new()
	hs.bg_color = HEADER_BG
	hs.set_corner_radius_all(4)
	hs.content_margin_left = 10
	hs.content_margin_right = 10
	hs.content_margin_top = 6
	hs.content_margin_bottom = 6
	h_panel.add_theme_stylebox_override("panel", hs)
	h_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(h_panel)

	var h_hbox = HBoxContainer.new()
	h_hbox.add_theme_constant_override("separation", 12)
	h_panel.add_child(h_hbox)

	# Sprite preview in detail header
	if tile_library:
		tile_library.ensure_actor_sprite(selected_actor, actor.get("name", "Actor"), atype)
		var actor_tex = tile_library.get_actor_texture(selected_actor)
		if actor_tex:
			var dtex = TextureRect.new()
			dtex.texture = actor_tex
			dtex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dtex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			dtex.custom_minimum_size = Vector2(48, 48)
			h_hbox.add_child(dtex)
	var name_edit = LineEdit.new()
	name_edit.text = actor.get("name", "")
	name_edit.add_theme_font_size_override("font_size", 13)
	name_edit.custom_minimum_size.x = 180
	name_edit.text_changed.connect(_on_prop_str.bind("name"))
	h_hbox.add_child(name_edit)

	_type_picker_btn = Button.new()
	_type_picker_btn.text = atype
	_type_picker_btn.tooltip_text = "Click to choose actor type visually"
	_type_picker_btn.add_theme_font_size_override("font_size", 12)
	var typb_s = StyleBoxFlat.new()
	typb_s.bg_color = color.darkened(0.5)
	typb_s.set_corner_radius_all(4)
	typb_s.content_margin_left = 10; typb_s.content_margin_right = 10
	typb_s.content_margin_top = 3;  typb_s.content_margin_bottom = 3
	_type_picker_btn.add_theme_stylebox_override("normal", typb_s)
	_type_picker_btn.add_theme_color_override("font_color", color)
	_type_picker_btn.add_theme_color_override("font_hover_color", WHITE)
	var type_tex = _get_type_preview_texture(atype)
	if type_tex:
		_type_picker_btn.icon = type_tex
		_type_picker_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_type_picker_btn.pressed.connect(_on_type_picker_pressed)
	h_hbox.add_child(_type_picker_btn)

	var edit_sprite_btn = Button.new()
	edit_sprite_btn.text = "Edit Sprite"
	edit_sprite_btn.add_theme_font_size_override("font_size", 11)
	var ebs = StyleBoxFlat.new()
	ebs.bg_color = Color(0.30, 0.50, 0.80)
	ebs.set_corner_radius_all(4)
	ebs.content_margin_left = 8
	ebs.content_margin_right = 8
	ebs.content_margin_top = 2
	ebs.content_margin_bottom = 2
	edit_sprite_btn.add_theme_stylebox_override("normal", ebs)
	edit_sprite_btn.add_theme_color_override("font_color", WHITE)
	edit_sprite_btn.pressed.connect(_open_actor_sprite_editor.bind(selected_actor))
	h_hbox.add_child(edit_sprite_btn)

	var dup_btn = Button.new()
	dup_btn.text = "⧉ Duplicate"
	dup_btn.tooltip_text = "Copy this actor into the next empty slot"
	dup_btn.add_theme_font_size_override("font_size", 11)
	var dbs = StyleBoxFlat.new()
	dbs.bg_color = Color(0.35, 0.45, 0.60)
	dbs.set_corner_radius_all(4)
	dbs.content_margin_left = 8; dbs.content_margin_right = 8
	dbs.content_margin_top = 2;  dbs.content_margin_bottom = 2
	dup_btn.add_theme_stylebox_override("normal", dbs)
	dup_btn.add_theme_color_override("font_color", WHITE)
	dup_btn.pressed.connect(_on_duplicate_actor)
	h_hbox.add_child(dup_btn)

	var import_spr_btn = Button.new()
	import_spr_btn.text = "📂 Import Sprite"
	import_spr_btn.tooltip_text = "Import sprite from PNG file (single frame or spritesheet)"
	import_spr_btn.add_theme_font_size_override("font_size", 11)
	var isb_s = StyleBoxFlat.new()
	isb_s.bg_color = Color(0.50, 0.40, 0.65)
	isb_s.set_corner_radius_all(4)
	isb_s.content_margin_left = 8; isb_s.content_margin_right = 8
	isb_s.content_margin_top = 2;  isb_s.content_margin_bottom = 2
	import_spr_btn.add_theme_stylebox_override("normal", isb_s)
	import_spr_btn.add_theme_color_override("font_color", WHITE)
	import_spr_btn.pressed.connect(_on_import_sprite_pressed.bind(selected_actor))
	h_hbox.add_child(import_spr_btn)

	# ── Sprite Preview Panel ─────────────────────────────────
	var preview_panel = PanelContainer.new()
	var pp_style = StyleBoxFlat.new()
	pp_style.bg_color = Color(0.10, 0.10, 0.14)
	pp_style.set_corner_radius_all(6)
	pp_style.border_width_bottom = 2
	pp_style.border_width_top = 2
	pp_style.border_width_left = 2
	pp_style.border_width_right = 2
	pp_style.border_color = color.darkened(0.4)
	pp_style.content_margin_left = 12
	pp_style.content_margin_right = 12
	pp_style.content_margin_top = 8
	pp_style.content_margin_bottom = 8
	preview_panel.add_theme_stylebox_override("panel", pp_style)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(preview_panel)

	var preview_hbox = HBoxContainer.new()
	preview_hbox.add_theme_constant_override("separation", 16)
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_panel.add_child(preview_hbox)

	# Large sprite preview (nearest-neighbor for pixel art)
	if tile_library:
		var preview_tex: Texture2D = tile_library.get_actor_texture(selected_actor)
		if preview_tex:
			var large_preview = TextureRect.new()
			large_preview.texture = preview_tex
			large_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			large_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			large_preview.custom_minimum_size = Vector2(96, 96)
			large_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			preview_hbox.add_child(large_preview)

	# Preview info labels
	var preview_info = VBoxContainer.new()
	preview_info.add_theme_constant_override("separation", 4)
	preview_hbox.add_child(preview_info)

	var pname_lbl = Label.new()
	pname_lbl.text = actor.get("name", "Actor")
	pname_lbl.label_settings = _ls(14, WHITE)
	preview_info.add_child(pname_lbl)

	var ptype_lbl = Label.new()
	ptype_lbl.text = atype
	ptype_lbl.label_settings = _ls(12, color)
	preview_info.add_child(ptype_lbl)

	# Show animation frame count if available
	if tile_library:
		var anim_names: Array = []
		var sprite_data: Dictionary = tile_library.actor_sprites.get(selected_actor, {})
		var anims: Dictionary = sprite_data.get("anims", {})
		for anim_key in anims.keys():
			var frames: Array = anims[anim_key]
			anim_names.append(str(anim_key) + " (" + str(frames.size()) + "f)")
		if anim_names.size() > 0:
			var panim_lbl = Label.new()
			panim_lbl.text = "Anims: " + ", ".join(anim_names)
			panim_lbl.label_settings = _ls(10, DIM)
			panim_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			preview_info.add_child(panim_lbl)

	# ── Property cards — 2-column grid layout
	var prop_grid = GridContainer.new()
	prop_grid.columns = 2
	prop_grid.add_theme_constant_override("h_separation", 8)
	prop_grid.add_theme_constant_override("v_separation", 4)
	prop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(prop_grid)

	# Movement card
	var move_card = _card("🏃 Movement")
	prop_grid.add_child(move_card)
	var mc_grid = _card_body(move_card)
	_add_slider_row(mc_grid, "Max Speed", "max_speed", actor, 0, 999, 1)
	_add_slider_row(mc_grid, "Gravity", "gravity_scale", actor, 0, 5, 0.1)
	_add_option_row(mc_grid, "Entrance", "entrance_mode", actor, ["Instant", "FadeIn", "SlideIn", "DropIn"])

	# Combat card
	var combat_card = _card("⚔️ Combat")
	prop_grid.add_child(combat_card)
	var cc_grid = _card_body(combat_card)
	_add_slider_row(cc_grid, "Max HP", "max_hp", actor, 1, 9999, 1)
	_add_slider_row(cc_grid, "Damage", "damage", actor, 0, 9999, 1)
	_add_slider_row(cc_grid, "Score", "score_value", actor, 0, 99999, 10)
	_add_option_row(cc_grid, "On Death", "death_mode", actor, ["Respawn", "Destroy", "GameOver"])
	_add_slider_row(cc_grid, "Rebirth(s)", "rebirth", actor, 0, 30, 0.5)

	# Collision card
	var coll_card = _card("💥 Collision")
	prop_grid.add_child(coll_card)
	var col_grid = _card_body(coll_card)
	_add_option_row(col_grid, "Mode", "collision_mode", actor, ["Bounce", "Slide", "Stop", "Pass"])

	# Sound card — assign sounds to game events
	var snd_card = _card("🔊 Sounds")
	prop_grid.add_child(snd_card)
	var snd_grid = _card_body(snd_card)
	# Get live sound names from sound editor (or fallback to presets)
	var snd_names: Array = _get_sound_options()
	match atype:
		"Player":
			_add_sound_row(snd_grid, "Jump", "jump_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Hit", "hit_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Death", "death_sound", actor, snd_names)
		"Computer":
			_add_sound_row(snd_grid, "Pickup", "pickup_sound", actor, snd_names)
		"Sentry":
			_add_sound_row(snd_grid, "Hit", "hit_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Death", "death_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Shoot", "shoot_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Stomp", "stomp_sound", actor, snd_names)
		"Drone", "Zombie", "Boss", "Bat", "Tank":
			_add_sound_row(snd_grid, "Hit", "hit_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Death", "death_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Stomp", "stomp_sound", actor, snd_names)
		_:
			_add_sound_row(snd_grid, "Hit", "hit_sound", actor, snd_names)
			_add_sound_row(snd_grid, "Death", "death_sound", actor, snd_names)
	# Edit Sounds button — navigate to Sound Editor
	snd_grid.add_child(_prop_label(""))
	var edit_snd_btn = Button.new()
	edit_snd_btn.text = "🎵 Edit Sounds →"
	edit_snd_btn.tooltip_text = "Open the Sound Editor to create and edit sounds"
	edit_snd_btn.add_theme_font_size_override("font_size", 11)
	var esb_s = StyleBoxFlat.new()
	esb_s.bg_color = Color(0.55, 0.40, 0.70)
	esb_s.set_corner_radius_all(4)
	esb_s.content_margin_left = 8; esb_s.content_margin_right = 8
	esb_s.content_margin_top = 2;  esb_s.content_margin_bottom = 2
	edit_snd_btn.add_theme_stylebox_override("normal", esb_s)
	edit_snd_btn.add_theme_color_override("font_color", WHITE)
	edit_snd_btn.pressed.connect(func(): switch_tab_requested.emit(2))
	snd_grid.add_child(edit_snd_btn)

	# AI card (only for non-Player)
	if atype != "Player":
		var ai_card = _card("🧠 AI Behavior")
		prop_grid.add_child(ai_card)
		var ai_grid = _card_body(ai_card)
		_add_option_row(ai_grid, "Behavior", "ai_behavior", actor, ["Chase", "Patrol", "Wander", "Guard", "Flee"])
		_add_slider_row(ai_grid, "Vision", "ai_vision_range", actor, 0, 999, 10)
		_add_slider_row(ai_grid, "Patrol Speed", "ai_patrol_speed", actor, 0, 500, 5)
		_add_toggle_row(ai_grid, "Auto Shoot", "auto_shoot", actor)
		if actor.get("auto_shoot", false):
			_add_slider_row(ai_grid, "Fire Rate(s)", "auto_shoot_interval", actor, 0.1, 10, 0.1)

	# Animation card
	var anim_card = _card("🎬 Animations")
	prop_grid.add_child(anim_card)
	var an_grid = _card_body(anim_card)
	# Show each animation name + frame count + speed
	var anim_data: Array = actor.get("anim_data", [{"name": "Idle", "speed": 8, "loop": true}])
	# Sync frame counts from tile library
	if tile_library:
		var anim_names = tile_library.get_actor_anim_names(selected_actor)
		# If tile library has animations the actor data doesn't, sync them
		if anim_names.size() > 0:
			var existing_names: Array = []
			for ad in anim_data:
				existing_names.append(ad.get("name", ""))
			for an in anim_names:
				if an not in existing_names:
					anim_data.append({"name": an, "speed": 8, "loop": true})
			actor["anim_data"] = anim_data
	for ad_idx in range(anim_data.size()):
		var ad: Dictionary = anim_data[ad_idx]
		var anim_name: String = ad.get("name", "Idle")
		var anim_speed: int = ad.get("speed", 8)
		var acolor: Color = ANIM_COLORS.get(anim_name, Color(0.6, 0.6, 0.6))
		# Animation name label with color dot
		var name_lbl = Label.new()
		name_lbl.text = "● " + anim_name
		name_lbl.label_settings = _ls(11, acolor)
		an_grid.add_child(name_lbl)
		# Frame count from tile library
		var fc: int = 0
		if tile_library:
			fc = tile_library.get_actor_anim_frames(selected_actor, anim_name).size()
		var info_lbl = Label.new()
		info_lbl.text = str(fc) + " frames, speed " + str(anim_speed)
		info_lbl.label_settings = _ls(10, DIM)
		an_grid.add_child(info_lbl)
	an_grid.add_child(_prop_label(" "))
	var hint_lbl = Label.new()
	hint_lbl.text = "Edit sprite to add/manage"
	hint_lbl.label_settings = _ls(10, DIM)
	an_grid.add_child(hint_lbl)

	# FX card
	var fx_card = _card("✨ Effects")
	prop_grid.add_child(fx_card)
	var fx_grid = _card_body(fx_card)
	_add_edit_row(fx_grid, "Spawn FX", "fx_spawn", actor)
	_add_edit_row(fx_grid, "Death FX", "fx_death", actor)
	_add_edit_row(fx_grid, "Hit FX", "fx_hit", actor)

	# Shader FX card
	var sfx_card = _card("🔮 Shader FX")
	prop_grid.add_child(sfx_card)
	var sfx_grid = _card_body(sfx_card)
	sfx_grid.add_child(_prop_label("Effect"))
	var sfx_opt = OptionButton.new()
	sfx_opt.add_theme_font_size_override("font_size", 11)
	var current_sfx: String = actor.get("shader_fx", "(None)")
	for i in range(SPRITE_FX_NAMES.size()):
		sfx_opt.add_item(SPRITE_FX_NAMES[i])
		if SPRITE_FX_NAMES[i] == current_sfx:
			sfx_opt.selected = i
	sfx_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_opt.item_selected.connect(func(idx):
		actors[selected_actor]["shader_fx"] = SPRITE_FX_NAMES[idx]
		if SPRITE_FX_NAMES[idx] == "(None)":
			actors[selected_actor]["shader_params"] = {}
		else:
			var defaults := {}
			for u in SPRITE_FX_UNIFORMS.get(SPRITE_FX_NAMES[idx], []):
				defaults[u["name"]] = u["default"]
			actors[selected_actor]["shader_params"] = defaults
		_rebuild_detail()
		actor_changed.emit(selected_actor))
	sfx_grid.add_child(sfx_opt)
	_style_option(sfx_opt)
	# Parameter sliders for the current shader effect
	if current_sfx != "(None)" and SPRITE_FX_UNIFORMS.has(current_sfx):
		var sparams: Dictionary = actor.get("shader_params", {})
		for u in SPRITE_FX_UNIFORMS[current_sfx]:
			sfx_grid.add_child(_prop_label(u["label"]))
			var sl = HSlider.new()
			sl.min_value = u["min"]
			sl.max_value = u["max"]
			sl.step = u["step"]
			sl.value = sparams.get(u["name"], u["default"])
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.custom_minimum_size.x = 100
			var uname: String = u["name"]
			sl.value_changed.connect(func(v):
				actors[selected_actor]["shader_params"][uname] = v
				actor_changed.emit(selected_actor))
			sfx_grid.add_child(sl)


# ─── Card Helpers ────────────────────────────────────────────

func _card(title: String) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", style)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)

	var hdr = Label.new()
	hdr.text = title
	hdr.label_settings = _ls(12, ACCENT)
	vbox.add_child(hdr)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	return pc


func _card_body(card: PanelContainer) -> GridContainer:
	var vbox = card.get_child(0) as VBoxContainer
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	return grid


func _prop_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.label_settings = _ls(11, DIM)
	l.custom_minimum_size.x = 80
	return l


func _add_slider_row(grid: GridContainer, label: String, key: String, actor: Dictionary, lo: float, hi: float, step: float) -> void:
	grid.add_child(_prop_label(label))
	var sl = HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = actor.get(key, lo)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size.x = 100
	sl.value_changed.connect(_on_prop_float.bind(key))
	grid.add_child(sl)


func _add_option_row(grid: GridContainer, label: String, key: String, actor: Dictionary, options: Array) -> void:
	grid.add_child(_prop_label(label))
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	for o in options:
		opt.add_item(o)
	var idx = options.find(actor.get(key, options[0]))
	opt.selected = idx if idx >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i): _on_prop_str.call(options[i], key))
	grid.add_child(opt)
	_style_option(opt)


func _add_toggle_row(grid: GridContainer, label: String, key: String, actor: Dictionary) -> void:
	grid.add_child(_prop_label(label))
	var chk = CheckButton.new()
	chk.button_pressed = actor.get(key, false)
	chk.toggled.connect(_on_prop_bool.bind(key))
	grid.add_child(chk)


func _add_edit_row(grid: GridContainer, label: String, key: String, actor: Dictionary) -> void:
	grid.add_child(_prop_label(label))
	var edit = LineEdit.new()
	edit.text = actor.get(key, "")
	edit.add_theme_font_size_override("font_size", 11)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_prop_str.bind(key))
	grid.add_child(edit)


## Get current sound names from the sound editor, or fall back to preset list.
func _get_sound_options() -> Array:
	if sound_editor and sound_editor.has_method("get_sound_names"):
		return sound_editor.get_sound_names(true)
	return SOUND_PRESETS.duplicate()


## Add a sound assignment row: dropdown + ▶ preview button.
func _add_sound_row(grid: GridContainer, label: String, key: String, actor: Dictionary, options: Array) -> void:
	grid.add_child(_prop_label(label))
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Dropdown
	var opt = OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	for o in options:
		opt.add_item(o)
	var current_val: String = actor.get(key, "(None)")
	var idx = options.find(current_val)
	# If the stored name isn't in the list, add it so nothing is lost
	if idx < 0 and current_val != "(None)" and current_val != "":
		opt.add_item(current_val)
		idx = opt.item_count - 1
	opt.selected = idx if idx >= 0 else 0
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i):
		var val: String = opt.get_item_text(i)
		_on_prop_str.call(val, key))
	_style_option(opt)
	hbox.add_child(opt)

	# ▶ Preview button
	var play_btn = Button.new()
	play_btn.text = "▶"
	play_btn.tooltip_text = "Preview this sound"
	play_btn.add_theme_font_size_override("font_size", 11)
	play_btn.custom_minimum_size = Vector2(28, 0)
	var pbs = StyleBoxFlat.new()
	pbs.bg_color = Color(0.25, 0.65, 0.35)
	pbs.set_corner_radius_all(4)
	pbs.content_margin_left = 4; pbs.content_margin_right = 4
	pbs.content_margin_top = 2;  pbs.content_margin_bottom = 2
	play_btn.add_theme_stylebox_override("normal", pbs)
	play_btn.add_theme_color_override("font_color", WHITE)
	play_btn.pressed.connect(func():
		var snd_name: String = opt.get_item_text(opt.selected)
		if snd_name != "(None)" and sound_editor and sound_editor.has_method("play_sound_by_name"):
			sound_editor.play_sound_by_name(snd_name))
	hbox.add_child(play_btn)
	grid.add_child(hbox)


# ─── Property Callbacks ─────────────────────────────────────

func _on_prop_str(val: String, key: String) -> void:
	if selected_actor >= 0 and selected_actor < actors.size():
		actors[selected_actor][key] = val
		if key == "name":
			_rebuild_cards()
		actor_changed.emit(selected_actor)


func _on_prop_float(val: float, key: String) -> void:
	if selected_actor >= 0 and selected_actor < actors.size():
		actors[selected_actor][key] = val
		actor_changed.emit(selected_actor)


func _on_prop_bool(val: bool, key: String) -> void:
	if selected_actor >= 0 and selected_actor < actors.size():
		actors[selected_actor][key] = val
		_rebuild_detail()
		actor_changed.emit(selected_actor)


func _on_type_changed(idx: int) -> void:
	if selected_actor >= 0 and selected_actor < actors.size():
		actors[selected_actor]["type"] = ACTOR_TYPES[idx]
		_rebuild_cards()
		_rebuild_detail()
		actor_changed.emit(selected_actor)


func _on_duplicate_actor() -> void:
	if selected_actor < 0 or selected_actor >= actors.size():
		return
	# Find next default/empty actor slot
	var target: int = -1
	for i in range(actors.size()):
		if i != selected_actor and actors[i].get("name", "").begins_with("Actor "):
			target = i
			break
	if target < 0:
		return  # all slots in use
	actors[target] = actors[selected_actor].duplicate(true)
	actors[target]["name"] = actors[selected_actor]["name"] + " (copy)"
	selected_actor = target
	_rebuild_cards()
	_rebuild_detail()
	actor_changed.emit(selected_actor)


# ─── Serialization ───────────────────────────────────────────

func get_data() -> Array:
	return actors.duplicate(true)

func set_data(data: Array) -> void:
	actors = data.duplicate(true)
	# Migrate legacy animation fields to anim_data
	for actor in actors:
		if not actor.has("anim_data"):
			var old_speed: int = actor.get("anim_speed", 8)
			actor["anim_data"] = [{"name": "Idle", "speed": old_speed, "loop": true}]
		# Migrate: add shader_fx field for older projects
		if not actor.has("shader_fx"):
			actor["shader_fx"] = "(None)"
			actor["shader_params"] = {}
		# Migrate: add sound event fields for older projects
		for snd_key in ["jump_sound", "hit_sound", "death_sound", "shoot_sound", "pickup_sound", "stomp_sound"]:
			if not actor.has(snd_key):
				actor[snd_key] = "(None)"
	while actors.size() < MAX_ACTORS:
		actors.append(_make_actor("Actor " + str(actors.size() + 1), "Drone"))
	selected_actor = 0
	_rebuild_cards()
	_rebuild_detail()


func refresh_all() -> void:
	_rebuild_cards()
	_rebuild_detail()


# ─── Inline Actor Sprite Editor ──────────────────────────────

func _open_actor_sprite_editor(actor_id: int) -> void:
	if not tile_library:
		return
	var aname = actors[actor_id].get("name", "Actor") if actor_id < actors.size() else "Actor"
	var atype = actors[actor_id].get("type", "Drone") if actor_id < actors.size() else "Drone"
	tile_library.ensure_actor_sprite(actor_id, aname, atype)

	_edit_actor_id = actor_id
	# Load ALL named animations from tile library
	var lib_anims: Dictionary = tile_library.get_actor_anims(actor_id)
	_edit_anims.clear()
	if lib_anims.size() == 0:
		var img = tile_library.get_actor_image(actor_id)
		if img:
			_edit_anims["Idle"] = [img.duplicate()]
		else:
			return
	else:
		for anim_name in lib_anims:
			var flist: Array = []
			for f in lib_anims[anim_name]:
				flist.append(f.duplicate())
			_edit_anims[anim_name] = flist
	# Select first animation
	_edit_current_anim = _edit_anims.keys()[0]
	_edit_frames = _edit_anims[_edit_current_anim]
	_edit_current_frame = 0
	_edit_image = _edit_frames[0]

	var base_color = TYPE_COLORS.get(atype, DIM)
	_edit_color = base_color.lightened(0.1)
	_edit_erasing = false
	_edit_onion_skin = false
	_edit_palette_colors = _build_actor_palette(atype)

	if _edit_popup and is_instance_valid(_edit_popup):
		_edit_popup.queue_free()
	_edit_popup = Window.new()
	_edit_popup.title = "Edit Actor Sprite: " + aname
	_edit_popup.size = Vector2i(520, 560)
	_edit_popup.unresizable = false
	_edit_popup.close_requested.connect(_on_actor_edit_close)
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

	# ── Top Toolbar: info + eraser + save/cancel ──
	var tool_row = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(tool_row)

	var info_lbl = Label.new()
	info_lbl.text = aname + " (" + atype + ") - 24x24 pixels"
	info_lbl.label_settings = _ls(11, LABEL_CLR)
	tool_row.add_child(info_lbl)

	var spc = Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_row.add_child(spc)

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

	var size_lbl = Label.new()
	size_lbl.text = "Size:"
	size_lbl.label_settings = _ls(10, DIM)
	tool_row.add_child(size_lbl)
	var size_spin = SpinBox.new()
	size_spin.min_value = 1
	size_spin.max_value = 6
	size_spin.step = 1
	size_spin.value = _edit_pen_size
	size_spin.custom_minimum_size = Vector2(60, 0)
	size_spin.add_theme_font_size_override("font_size", 11)
	size_spin.tooltip_text = "Brush size in pixels"
	size_spin.value_changed.connect(func(v): _edit_pen_size = int(v))
	tool_row.add_child(size_spin)

	# ── Drawing tool buttons ──
	var tool_row2 = HBoxContainer.new()
	tool_row2.add_theme_constant_override("separation", 3)
	main_vbox.add_child(tool_row2)
	var tool_defs = [[0, "✏️", "Pen"], [1, "🪣", "Fill"], [2, "📏", "Line"], [3, "▭", "Rect"]]
	_edit_tool_buttons.clear()
	for td in tool_defs:
		var tbtn = Button.new()
		tbtn.text = td[1]
		tbtn.tooltip_text = td[2]
		tbtn.toggle_mode = true
		tbtn.button_pressed = (td[0] == _edit_tool)
		tbtn.custom_minimum_size = Vector2(36, 28)
		tbtn.add_theme_font_size_override("font_size", 14)
		var t_n = StyleBoxFlat.new()
		t_n.bg_color = Color(0.22, 0.22, 0.28)
		t_n.set_corner_radius_all(4)
		t_n.set_content_margin_all(3)
		tbtn.add_theme_stylebox_override("normal", t_n)
		var t_p = t_n.duplicate()
		t_p.bg_color = Color(0.18, 0.28, 0.45)
		tbtn.add_theme_stylebox_override("pressed", t_p)
		tbtn.add_theme_color_override("font_color", WHITE)
		tbtn.add_theme_color_override("font_pressed_color", Color(0.7, 0.85, 1.0))
		var tid: int = td[0]
		tbtn.pressed.connect(func():
			_edit_tool = tid
			for i in range(_edit_tool_buttons.size()):
				if is_instance_valid(_edit_tool_buttons[i]):
					_edit_tool_buttons[i].button_pressed = (i == tid)
		)
		tool_row2.add_child(tbtn)
		_edit_tool_buttons.append(tbtn)

	var sep1 = VSeparator.new()
	sep1.custom_minimum_size = Vector2(2, 0)
	tool_row2.add_child(sep1)

	var mirror_btn = CheckButton.new()
	mirror_btn.text = "↔ Mirror"
	mirror_btn.button_pressed = _edit_mirror_h
	mirror_btn.add_theme_font_size_override("font_size", 10)
	mirror_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mirror_btn.toggled.connect(func(v): _edit_mirror_h = v)
	tool_row2.add_child(mirror_btn)

	var spc2 = Control.new()
	spc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_row2.add_child(spc2)

	var clear_btn = Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.tooltip_text = "Clear entire canvas"
	clear_btn.add_theme_font_size_override("font_size", 10)
	var cl_s = StyleBoxFlat.new()
	cl_s.bg_color = Color(0.55, 0.20, 0.20)
	cl_s.set_corner_radius_all(4)
	cl_s.set_content_margin_all(3)
	clear_btn.add_theme_stylebox_override("normal", cl_s)
	clear_btn.add_theme_color_override("font_color", WHITE)
	clear_btn.pressed.connect(func():
		if _edit_image:
			_edit_stroke_snap = _edit_image.duplicate()
			_edit_image.fill(Color.TRANSPARENT)
			_commit_sprite_stroke()
			_edit_canvas.queue_redraw()
	)
	tool_row2.add_child(clear_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(_on_actor_edit_save)
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
	cancel_btn.pressed.connect(_on_actor_edit_close)
	tool_row.add_child(cancel_btn)

	# ── Animation Tabs Row (color-coded named animations) ──
	_edit_anim_row = HBoxContainer.new()
	_edit_anim_row.add_theme_constant_override("separation", 3)
	main_vbox.add_child(_edit_anim_row)
	_rebuild_anim_tabs()

	# ── Frame Navigation Toolbar ──
	var frame_row = HBoxContainer.new()
	frame_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(frame_row)

	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.18, 0.20, 0.26)
	frame_style.set_corner_radius_all(4)
	frame_style.content_margin_left = 6
	frame_style.content_margin_right = 6
	frame_style.content_margin_top = 2
	frame_style.content_margin_bottom = 2

	var btn_prev = _frame_btn("◀", "Previous frame")
	btn_prev.pressed.connect(_on_frame_prev)
	frame_row.add_child(btn_prev)

	_edit_frame_label = Label.new()
	_edit_frame_label.label_settings = _ls(12, ACCENT)
	_edit_frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit_frame_label.custom_minimum_size.x = 80
	_update_frame_label()
	frame_row.add_child(_edit_frame_label)

	var btn_next = _frame_btn("▶", "Next frame")
	btn_next.pressed.connect(_on_frame_next)
	frame_row.add_child(btn_next)

	var sep_frame = VSeparator.new()
	sep_frame.add_theme_constant_override("separation", 8)
	frame_row.add_child(sep_frame)

	var btn_add = _frame_btn("+ Add", "Add new blank frame after current")
	btn_add.pressed.connect(_on_frame_add)
	frame_row.add_child(btn_add)

	var btn_dup = _frame_btn("⧉ Copy", "Copy current frame to clipboard")
	btn_dup.pressed.connect(_on_frame_copy)
	frame_row.add_child(btn_dup)

	var btn_paste = _frame_btn("📋 Paste", "Paste copied frame after current")
	btn_paste.pressed.connect(_on_frame_paste)
	frame_row.add_child(btn_paste)

	var btn_del = _frame_btn("✕ Del", "Delete current frame")
	btn_del.pressed.connect(_on_frame_delete)
	frame_row.add_child(btn_del)

	var sep2 = VSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	frame_row.add_child(sep2)

	var btn_onion = Button.new()
	btn_onion.text = "👻 Onion"
	btn_onion.toggle_mode = true
	btn_onion.tooltip_text = "Show previous frame as ghost overlay"
	btn_onion.add_theme_font_size_override("font_size", 11)
	var on_n = StyleBoxFlat.new()
	on_n.bg_color = Color(0.22, 0.22, 0.28)
	on_n.set_corner_radius_all(4)
	on_n.content_margin_left = 6
	on_n.content_margin_right = 6
	on_n.content_margin_top = 2
	on_n.content_margin_bottom = 2
	btn_onion.add_theme_stylebox_override("normal", on_n)
	var on_p = on_n.duplicate()
	on_p.bg_color = Color(0.40, 0.55, 0.75)
	btn_onion.add_theme_stylebox_override("pressed", on_p)
	btn_onion.add_theme_color_override("font_color", LABEL_CLR)
	btn_onion.add_theme_color_override("font_pressed_color", WHITE)
	btn_onion.toggled.connect(func(v):
		_edit_onion_skin = v
		if _edit_canvas and is_instance_valid(_edit_canvas):
			_edit_canvas.queue_redraw()
	)
	frame_row.add_child(btn_onion)

	var btn_import_frame = Button.new()
	btn_import_frame.text = "📂 Import"
	btn_import_frame.tooltip_text = "Import frame(s) from PNG into the current animation"
	btn_import_frame.add_theme_font_size_override("font_size", 11)
	var if_n = StyleBoxFlat.new()
	if_n.bg_color = Color(0.50, 0.40, 0.65)
	if_n.set_corner_radius_all(4)
	if_n.content_margin_left = 6; if_n.content_margin_right = 6
	if_n.content_margin_top = 2;  if_n.content_margin_bottom = 2
	btn_import_frame.add_theme_stylebox_override("normal", if_n)
	btn_import_frame.add_theme_color_override("font_color", WHITE)
	btn_import_frame.pressed.connect(_on_import_frame_pressed)
	frame_row.add_child(btn_import_frame)

	# Spacer to push preview to the right
	var frame_spc = Control.new()
	frame_spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_row.add_child(frame_spc)

	# Animated preview thumbnail
	var fps_lbl = Label.new()
	fps_lbl.text = "FPS:"
	fps_lbl.label_settings = _ls(10, DIM)
	frame_row.add_child(fps_lbl)

	var fps_spin = SpinBox.new()
	fps_spin.min_value = 1
	fps_spin.max_value = 30
	fps_spin.value = _edit_preview_fps
	fps_spin.step = 1
	fps_spin.custom_minimum_size = Vector2(60, 0)
	fps_spin.add_theme_font_size_override("font_size", 11)
	fps_spin.tooltip_text = "Animation preview frames per second"
	fps_spin.value_changed.connect(func(v):
		_edit_preview_fps = int(v)
		if _preview_timer and is_instance_valid(_preview_timer):
			_preview_timer.wait_time = 1.0 / maxf(_edit_preview_fps, 1)
	)
	frame_row.add_child(fps_spin)

	var prev_lbl = Label.new()
	prev_lbl.text = "Preview:"
	prev_lbl.label_settings = _ls(10, DIM)
	frame_row.add_child(prev_lbl)

	_edit_preview_rect = TextureRect.new()
	_edit_preview_rect.custom_minimum_size = Vector2(48, 48)
	_edit_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_edit_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_preview_frame()
	frame_row.add_child(_edit_preview_rect)

	# Color palette
	# Saved palettes dropdown
	_agck_load_custom_palettes()
	var saved_pal_row = HBoxContainer.new()
	saved_pal_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(saved_pal_row)
	var pal_lbl = Label.new()
	pal_lbl.text = "Palette:"
	pal_lbl.label_settings = _ls(10, DIM)
	saved_pal_row.add_child(pal_lbl)
	_agck_palette_option = OptionButton.new()
	_agck_palette_option.add_theme_font_size_override("font_size", 10)
	_agck_palette_option.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_agck_palette_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agck_palette_option.add_item("(Default)")
	for pname in AGCK_PALETTES:
		_agck_palette_option.add_item(pname)
	for cname in _agck_custom_palettes:
		_agck_palette_option.add_item("★ " + cname)
	_agck_palette_option.item_selected.connect(_on_agck_palette_selected)
	saved_pal_row.add_child(_agck_palette_option)
	_agck_palette_remove_btn = Button.new()
	_agck_palette_remove_btn.text = "🗑️"
	_agck_palette_remove_btn.tooltip_text = "Remove this custom palette"
	_agck_palette_remove_btn.add_theme_font_size_override("font_size", 11)
	_agck_palette_remove_btn.disabled = true
	_agck_palette_remove_btn.pressed.connect(_on_agck_remove_palette_pressed)
	saved_pal_row.add_child(_agck_palette_remove_btn)
	var lospec_row_btn = Button.new()
	lospec_row_btn.text = "🌐 Lospec"
	lospec_row_btn.tooltip_text = "Browse 4000+ palettes on Lospec.com"
	lospec_row_btn.add_theme_font_size_override("font_size", 10)
	lospec_row_btn.pressed.connect(_show_agck_lospec_browser)
	saved_pal_row.add_child(lospec_row_btn)

	# Asset browser buttons (kid mode)
	var asset_row := HBoxContainer.new()
	asset_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(asset_row)
	var btn_freesound := Button.new()
	btn_freesound.text = "🔊 Sounds"
	btn_freesound.tooltip_text = "Find free sounds!"
	btn_freesound.add_theme_font_size_override("font_size", 10)
	btn_freesound.pressed.connect(func():
		_freesound_browser = FREESOUND_BROWSER_SCRIPT.new()
		_freesound_browser.open(self, true)
	)
	asset_row.add_child(btn_freesound)
	var btn_oga := Button.new()
	btn_oga.text = "🎨 Art"
	btn_oga.tooltip_text = "Find free game art!"
	btn_oga.add_theme_font_size_override("font_size", 10)
	btn_oga.pressed.connect(func():
		_opengameart_browser = OPENGAMEART_BROWSER_SCRIPT.new()
		_opengameart_browser.open(self, true)
	)
	asset_row.add_child(btn_oga)
	var btn_kenney := Button.new()
	btn_kenney.text = "📦 Kenney"
	btn_kenney.tooltip_text = "Free game asset packs!"
	btn_kenney.add_theme_font_size_override("font_size", 10)
	btn_kenney.pressed.connect(func():
		_kenney_browser = KENNEY_BROWSER_SCRIPT.new()
		_kenney_browser.open(self, true)
	)
	asset_row.add_child(btn_kenney)

	var palette_row = HBoxContainer.new()
	palette_row.add_theme_constant_override("separation", 2)
	main_vbox.add_child(palette_row)
	_edit_palette_row = palette_row

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
		cbtn.pressed.connect(_on_actor_edit_color.bind(ci))
		palette_row.add_child(cbtn)
		_edit_palette_btns.append(cbtn)

	# Lospec browse button
	var lospec_btn = Button.new()
	lospec_btn.text = "🌐"
	lospec_btn.tooltip_text = "Browse Lospec palettes (4000+ online palettes)"
	lospec_btn.custom_minimum_size = Vector2(28, 18)
	lospec_btn.add_theme_font_size_override("font_size", 11)
	lospec_btn.pressed.connect(_show_agck_lospec_browser)
	palette_row.add_child(lospec_btn)

	# Big pixel canvas
	_edit_canvas = Control.new()
	_edit_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit_canvas.custom_minimum_size = Vector2(200, 200)
	_edit_canvas.draw.connect(_draw_actor_edit_canvas)
	_edit_canvas.gui_input.connect(_on_actor_edit_input)
	main_vbox.add_child(_edit_canvas)

	# Start animation preview timer
	_start_preview_timer()

	_edit_popup.popup_centered()


func _build_actor_palette(atype: String) -> Array:
	var base = TYPE_COLORS.get(atype, DIM)
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
	colors.append(Color(0.90, 0.65, 0.55))
	colors.append(Color(0.45, 0.30, 0.18))
	return colors


func _frame_btn(label_text: String, tooltip: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.tooltip_text = tooltip
	btn.add_theme_font_size_override("font_size", 11)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.24, 0.30)
	s.set_corner_radius_all(4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = Color(0.30, 0.35, 0.45)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", LABEL_CLR)
	btn.add_theme_color_override("font_hover_color", WHITE)
	return btn


# ─── Animation Tab Functions ────────────────────────────────

func _rebuild_anim_tabs() -> void:
	if not _edit_anim_row or not is_instance_valid(_edit_anim_row):
		return
	# Clear existing tabs
	for c in _edit_anim_row.get_children():
		c.queue_free()
	_edit_anim_btns.clear()

	var tab_lbl = Label.new()
	tab_lbl.text = "Anims:"
	tab_lbl.label_settings = _ls(10, DIM)
	_edit_anim_row.add_child(tab_lbl)

	# One tab per animation
	for anim_name in _edit_anims:
		var acolor: Color = ANIM_COLORS.get(anim_name, Color(0.6, 0.6, 0.6))
		var is_active: bool = (anim_name == _edit_current_anim)
		var tab_btn = Button.new()
		tab_btn.text = "● " + anim_name
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = is_active
		tab_btn.add_theme_font_size_override("font_size", 11)
		var ts = StyleBoxFlat.new()
		ts.bg_color = acolor.darkened(0.55) if not is_active else acolor.darkened(0.2)
		ts.set_corner_radius_all(6)
		ts.content_margin_left = 8
		ts.content_margin_right = 8
		ts.content_margin_top = 3
		ts.content_margin_bottom = 3
		if is_active:
			ts.border_width_bottom = 3
			ts.border_color = acolor
		tab_btn.add_theme_stylebox_override("normal", ts)
		var tp = ts.duplicate()
		tp.bg_color = acolor.darkened(0.2)
		tp.border_width_bottom = 3
		tp.border_color = acolor
		tab_btn.add_theme_stylebox_override("pressed", tp)
		tab_btn.add_theme_color_override("font_color", WHITE)
		tab_btn.add_theme_color_override("font_pressed_color", WHITE)
		var an: String = anim_name  # capture
		tab_btn.pressed.connect(_on_anim_tab_pressed.bind(an))
		_edit_anim_row.add_child(tab_btn)
		_edit_anim_btns.append(tab_btn)

	# Separator
	var sep = VSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	_edit_anim_row.add_child(sep)

	# + Add animation button (with popup menu of presets)
	var add_btn = Button.new()
	add_btn.text = "+ Add"
	add_btn.tooltip_text = "Add a new animation"
	add_btn.add_theme_font_size_override("font_size", 11)
	var as_ = StyleBoxFlat.new()
	as_.bg_color = Color(0.25, 0.55, 0.30)
	as_.set_corner_radius_all(4)
	as_.content_margin_left = 6
	as_.content_margin_right = 6
	as_.content_margin_top = 2
	as_.content_margin_bottom = 2
	add_btn.add_theme_stylebox_override("normal", as_)
	add_btn.add_theme_color_override("font_color", WHITE)
	add_btn.pressed.connect(_on_anim_add_pressed)
	_edit_anim_row.add_child(add_btn)

	# Rename button
	var ren_btn = Button.new()
	ren_btn.text = "✏ Rename"
	ren_btn.tooltip_text = "Rename the selected animation"
	ren_btn.add_theme_font_size_override("font_size", 11)
	var rs = StyleBoxFlat.new()
	rs.bg_color = Color(0.30, 0.35, 0.50)
	rs.set_corner_radius_all(4)
	rs.content_margin_left = 6
	rs.content_margin_right = 6
	rs.content_margin_top = 2
	rs.content_margin_bottom = 2
	ren_btn.add_theme_stylebox_override("normal", rs)
	ren_btn.add_theme_color_override("font_color", LABEL_CLR)
	ren_btn.pressed.connect(_on_anim_rename_pressed)
	_edit_anim_row.add_child(ren_btn)

	# Delete button (only if more than 1 animation)
	if _edit_anims.size() > 1:
		var del_btn = Button.new()
		del_btn.text = "✕"
		del_btn.tooltip_text = "Delete the selected animation"
		del_btn.add_theme_font_size_override("font_size", 11)
		var ds = StyleBoxFlat.new()
		ds.bg_color = Color(0.55, 0.20, 0.20)
		ds.set_corner_radius_all(4)
		ds.content_margin_left = 6
		ds.content_margin_right = 6
		ds.content_margin_top = 2
		ds.content_margin_bottom = 2
		del_btn.add_theme_stylebox_override("normal", ds)
		del_btn.add_theme_color_override("font_color", WHITE)
		del_btn.pressed.connect(_on_anim_delete_pressed)
		_edit_anim_row.add_child(del_btn)


func _on_anim_tab_pressed(anim_name: String) -> void:
	if anim_name == _edit_current_anim:
		# Already selected — update button state and return
		_rebuild_anim_tabs()
		return
	# Save current animation's frames
	if _edit_current_anim != "" and _edit_anims.has(_edit_current_anim):
		if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
			_edit_frames[_edit_current_frame] = _edit_image
		_edit_anims[_edit_current_anim] = _edit_frames
	# Switch to new animation
	_edit_current_anim = anim_name
	_edit_frames = _edit_anims[anim_name]
	_edit_current_frame = 0
	_edit_image = _edit_frames[0] if _edit_frames.size() > 0 else Image.create(24, 24, false, Image.FORMAT_RGBA8)
	_update_frame_label()
	if _edit_canvas and is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()
	_update_preview_frame()
	_rebuild_anim_tabs()


func _on_anim_add_pressed() -> void:
	# Show popup menu with preset animation names
	var popup = PopupMenu.new()
	popup.add_theme_font_size_override("font_size", 12)
	# Apply dark popup theme — see POPUP_THEME_FIX.md (Linux X11 fix)
	_apply_dark_popup(popup)
	var idx := 0
	for preset in ANIM_PRESETS:
		if not _edit_anims.has(preset):
			popup.add_item(preset, idx)
		idx += 1
	popup.id_pressed.connect(func(id):
		if id < 0 or id >= ANIM_PRESETS.size():
			return
		var name_to_add: String = ANIM_PRESETS[id]
		if _edit_anims.has(name_to_add):
			return
		# Save current frames
		if _edit_current_anim != "" and _edit_anims.has(_edit_current_anim):
			if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
				_edit_frames[_edit_current_frame] = _edit_image
			_edit_anims[_edit_current_anim] = _edit_frames
		# Create new animation with 1 blank frame
		var blank = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		blank.fill(Color.TRANSPARENT)
		_edit_anims[name_to_add] = [blank]
		# Switch to it
		_edit_current_anim = name_to_add
		_edit_frames = _edit_anims[name_to_add]
		_edit_current_frame = 0
		_edit_image = _edit_frames[0]
		_update_frame_label()
		if _edit_canvas and is_instance_valid(_edit_canvas):
			_edit_canvas.queue_redraw()
		_update_preview_frame()
		_rebuild_anim_tabs()
		popup.queue_free()
	)
	if _edit_anim_row and is_instance_valid(_edit_anim_row):
		_edit_anim_row.add_child(popup)
		# Re-apply after adding to tree (Linux X11 may reset on reparent)
		_apply_dark_popup(popup)
		popup.popup(Rect2i(Vector2i(_edit_anim_row.global_position) + Vector2i(0, 30), Vector2i(140, 200)))


func _on_anim_rename_pressed() -> void:
	if _edit_current_anim == "":
		return
	# Create a simple rename dialog
	var dlg = AcceptDialog.new()
	dlg.title = "Rename Animation"
	dlg.size = Vector2i(300, 100)
	var le = LineEdit.new()
	le.text = _edit_current_anim
	le.placeholder_text = "Enter new name"
	le.add_theme_font_size_override("font_size", 14)
	le.select_all()
	dlg.add_child(le)
	dlg.confirmed.connect(func():
		var new_name: String = le.text.strip_edges()
		if new_name == "" or new_name == _edit_current_anim:
			dlg.queue_free()
			return
		# Don't allow duplicate names
		if _edit_anims.has(new_name):
			dlg.queue_free()
			return
		# Save current frames
		if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
			_edit_frames[_edit_current_frame] = _edit_image
		# Rename: copy frames to new key, remove old
		var frames_copy: Array = _edit_anims[_edit_current_anim]
		# Build new dict preserving order
		var new_anims: Dictionary = {}
		for k in _edit_anims:
			if k == _edit_current_anim:
				new_anims[new_name] = frames_copy
			else:
				new_anims[k] = _edit_anims[k]
		_edit_anims = new_anims
		_edit_current_anim = new_name
		_edit_frames = _edit_anims[new_name]
		# Also update actor's anim_data if it exists
		if _edit_actor_id >= 0 and _edit_actor_id < actors.size():
			var anim_data: Array = actors[_edit_actor_id].get("anim_data", [])
			for ad in anim_data:
				if ad.get("name", "") == _edit_current_anim:
					ad["name"] = new_name
					break
		_rebuild_anim_tabs()
		_update_frame_label()
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	if _edit_popup and is_instance_valid(_edit_popup):
		_edit_popup.add_child(dlg)
		dlg.popup_centered()


func _on_anim_delete_pressed() -> void:
	if _edit_anims.size() <= 1:
		return  # Can't delete the last animation
	if _edit_current_anim == "":
		return
	# Save current frames before deletion check
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	# Remove current animation
	_edit_anims.erase(_edit_current_anim)
	# Switch to first remaining animation
	_edit_current_anim = _edit_anims.keys()[0]
	_edit_frames = _edit_anims[_edit_current_anim]
	_edit_current_frame = 0
	_edit_image = _edit_frames[0] if _edit_frames.size() > 0 else Image.create(24, 24, false, Image.FORMAT_RGBA8)
	_update_frame_label()
	if _edit_canvas and is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()
	_update_preview_frame()
	_rebuild_anim_tabs()


func _update_frame_label() -> void:
	if _edit_frame_label and is_instance_valid(_edit_frame_label):
		var prefix := _edit_current_anim + " - " if _edit_current_anim != "" else ""
		_edit_frame_label.text = prefix + "Frame " + str(_edit_current_frame + 1) + "/" + str(_edit_frames.size())


func _switch_to_frame(idx: int) -> void:
	if idx < 0 or idx >= _edit_frames.size():
		return
	# Save current edits back to frames array
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	_edit_current_frame = idx
	_edit_image = _edit_frames[idx]
	_update_frame_label()
	if _edit_canvas and is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()


func _on_frame_prev() -> void:
	if _edit_current_frame > 0:
		_switch_to_frame(_edit_current_frame - 1)


func _on_frame_next() -> void:
	if _edit_current_frame < _edit_frames.size() - 1:
		_switch_to_frame(_edit_current_frame + 1)


func _on_frame_add() -> void:
	if _edit_frames.size() >= 32:
		return  # Max 32 frames
	# Save current frame first
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	# Insert a blank frame after current
	var blank = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	_edit_frames.insert(_edit_current_frame + 1, blank)
	_switch_to_frame(_edit_current_frame + 1)


func _on_frame_copy() -> void:
	# Save current frame, then copy to clipboard
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	_edit_frame_clipboard = _edit_image.duplicate()
	print("AGCK: Frame copied to clipboard")


func _on_frame_paste() -> void:
	if _edit_frame_clipboard == null:
		print("AGCK: Nothing to paste — copy a frame first")
		return
	if _edit_frames.size() >= 32:
		return
	# Save current frame first
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	# Insert pasted frame after current
	var pasted = _edit_frame_clipboard.duplicate()
	_edit_frames.insert(_edit_current_frame + 1, pasted)
	_switch_to_frame(_edit_current_frame + 1)


func _on_frame_delete() -> void:
	if _edit_frames.size() <= 1:
		return  # Must keep at least 1 frame
	_edit_frames.remove_at(_edit_current_frame)
	if _edit_current_frame >= _edit_frames.size():
		_edit_current_frame = _edit_frames.size() - 1
	_edit_image = _edit_frames[_edit_current_frame]
	_update_frame_label()
	if _edit_canvas and is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()


func _update_preview_frame() -> void:
	if not _edit_preview_rect or not is_instance_valid(_edit_preview_rect):
		return
	if _edit_frames.size() == 0:
		return
	# Cycle through frames for animated preview
	var ms_per_frame = 1000.0 / maxf(_edit_preview_fps, 1)
	var preview_idx = int(Time.get_ticks_msec() / ms_per_frame) % _edit_frames.size()
	var fr = _edit_frames[preview_idx]
	var scaled = fr.duplicate()
	scaled.resize(48, 48, Image.INTERPOLATE_NEAREST)
	_edit_preview_rect.texture = ImageTexture.create_from_image(scaled)


var _preview_timer: Timer = null
var _edit_preview_fps: int = 8  # Adjustable preview frame rate

func _start_preview_timer() -> void:
	_stop_preview_timer()
	_preview_timer = Timer.new()
	_preview_timer.wait_time = 1.0 / maxf(_edit_preview_fps, 1)
	_preview_timer.autostart = true
	_preview_timer.timeout.connect(_update_preview_frame)
	add_child(_preview_timer)


func _stop_preview_timer() -> void:
	if _preview_timer and is_instance_valid(_preview_timer):
		_preview_timer.stop()
		_preview_timer.queue_free()
		_preview_timer = null


func _on_actor_edit_color(idx: int) -> void:
	_edit_color = _edit_palette_colors[idx]
	_edit_erasing = false
	for i in range(_edit_palette_btns.size()):
		_edit_palette_btns[i].button_pressed = (i == idx)


func _draw_actor_edit_canvas() -> void:
	if not _edit_image or not is_instance_valid(_edit_canvas):
		return
	var canvas_size = _edit_canvas.size
	var img_w = _edit_image.get_width()
	var img_h = _edit_image.get_height()

	var pixel_size = minf(canvas_size.x / float(img_w), canvas_size.y / float(img_h))
	var ox_val = (canvas_size.x - pixel_size * img_w) * 0.5
	var oy_val = (canvas_size.y - pixel_size * img_h) * 0.5

	_edit_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.12, 0.12, 0.14))

	# Onion skin: draw previous frame at low alpha
	var onion_img: Image = null
	if _edit_onion_skin and _edit_current_frame > 0 and _edit_current_frame < _edit_frames.size():
		onion_img = _edit_frames[_edit_current_frame - 1]

	for y in range(img_h):
		for x in range(img_w):
			var rect = Rect2(ox_val + x * pixel_size, oy_val + y * pixel_size, pixel_size, pixel_size)
			if (x + y) % 2 == 0:
				_edit_canvas.draw_rect(rect, Color(0.18, 0.18, 0.20))
			else:
				_edit_canvas.draw_rect(rect, Color(0.14, 0.14, 0.16))
			# Draw onion skin ghost pixel
			if onion_img:
				var oc = onion_img.get_pixel(x, y)
				if oc.a > 0.01:
					_edit_canvas.draw_rect(rect, Color(oc.r, oc.g, oc.b, 0.2))
			# Draw current frame pixel
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


func _on_actor_edit_input(event: InputEvent) -> void:
	if not _edit_image:
		return
	# Ctrl+Z = undo, Ctrl+Y / Ctrl+Shift+Z = redo
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
			_sprite_undo()
			return
		if event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
			_sprite_redo()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var px = _pos_to_pixel(event.position)
			if event.pressed:
				_edit_stroke_snap = _edit_image.duplicate()
				if _edit_tool == 1:  # Fill
					if px.x >= 0:
						_flood_fill(px.x, px.y)
						_commit_sprite_stroke()
				elif _edit_tool == 2 or _edit_tool == 3:  # Line / Rect
					_edit_line_start = px
				else:  # Pen
					_actor_edit_pixel(event.position)
			else:  # released
				if _edit_tool == 2 and _edit_line_start.x >= 0:  # Line
					_draw_line_tool(_edit_line_start, px)
					_edit_line_start = Vector2i(-1, -1)
					_commit_sprite_stroke()
				elif _edit_tool == 3 and _edit_line_start.x >= 0:  # Rect
					_draw_rect_tool(_edit_line_start, px)
					_edit_line_start = Vector2i(-1, -1)
					_commit_sprite_stroke()
				else:
					_commit_sprite_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_eyedropper_pick(event.position)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _edit_tool == 0:  # Pen only does drag-paint
				_actor_edit_pixel(event.position)


func _pos_to_pixel(pos: Vector2) -> Vector2i:
	if not _edit_image or not is_instance_valid(_edit_canvas):
		return Vector2i(-1, -1)
	var canvas_size = _edit_canvas.size
	var img_w = _edit_image.get_width()
	var img_h = _edit_image.get_height()
	var pixel_size = minf(canvas_size.x / float(img_w), canvas_size.y / float(img_h))
	var ox_val = (canvas_size.x - pixel_size * img_w) * 0.5
	var oy_val = (canvas_size.y - pixel_size * img_h) * 0.5
	var px = int((pos.x - ox_val) / pixel_size)
	var py = int((pos.y - oy_val) / pixel_size)
	if px >= 0 and px < img_w and py >= 0 and py < img_h:
		return Vector2i(px, py)
	return Vector2i(-1, -1)


func _actor_edit_pixel(pos: Vector2) -> void:
	if not _edit_image or not is_instance_valid(_edit_canvas):
		return
	var canvas_size = _edit_canvas.size
	var img_w = _edit_image.get_width()
	var img_h = _edit_image.get_height()
	var pixel_size = minf(canvas_size.x / float(img_w), canvas_size.y / float(img_h))
	var ox_val = (canvas_size.x - pixel_size * img_w) * 0.5
	var oy_val = (canvas_size.y - pixel_size * img_h) * 0.5

	var cx = int((pos.x - ox_val) / pixel_size)
	var cy = int((pos.y - oy_val) / pixel_size)
	var c = Color.TRANSPARENT if _edit_erasing else _edit_color
	var half = (_edit_pen_size - 1) / 2
	var painted := false
	for dy in range(-half, -half + _edit_pen_size):
		for dx in range(-half, -half + _edit_pen_size):
			var px = cx + dx
			var py = cy + dy
			if px >= 0 and px < img_w and py >= 0 and py < img_h:
				_set_pixel_safe(px, py, c)
				painted = true
	if painted:
		_edit_canvas.queue_redraw()


func _set_pixel_safe(px: int, py: int, c: Color) -> void:
	if not _edit_image:
		return
	var w = _edit_image.get_width()
	var h = _edit_image.get_height()
	if px >= 0 and px < w and py >= 0 and py < h:
		_edit_image.set_pixel(px, py, c)
		if _edit_mirror_h:
			var mx = w - 1 - px
			if mx >= 0 and mx < w:
				_edit_image.set_pixel(mx, py, c)


func _flood_fill(start_x: int, start_y: int) -> void:
	if not _edit_image:
		return
	var w = _edit_image.get_width()
	var h = _edit_image.get_height()
	var target_color = _edit_image.get_pixel(start_x, start_y)
	var fill_color = Color.TRANSPARENT if _edit_erasing else _edit_color
	if target_color.is_equal_approx(fill_color):
		return
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var visited := {}
	while stack.size() > 0:
		var p = stack.pop_back()
		var key = p.x * 10000 + p.y
		if key in visited:
			continue
		visited[key] = true
		if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h:
			continue
		if not _edit_image.get_pixel(p.x, p.y).is_equal_approx(target_color):
			continue
		_edit_image.set_pixel(p.x, p.y, fill_color)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	_edit_canvas.queue_redraw()


func _draw_line_tool(from: Vector2i, to: Vector2i) -> void:
	if not _edit_image:
		return
	var c = Color.TRANSPARENT if _edit_erasing else _edit_color
	# Bresenham
	var dx = absi(to.x - from.x)
	var dy = -absi(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx + dy
	var cx = from.x
	var cy = from.y
	while true:
		_set_pixel_safe(cx, cy, c)
		if cx == to.x and cy == to.y:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy
	_edit_canvas.queue_redraw()


func _draw_rect_tool(from: Vector2i, to: Vector2i) -> void:
	if not _edit_image:
		return
	var c = Color.TRANSPARENT if _edit_erasing else _edit_color
	var x0 = mini(from.x, to.x)
	var x1 = maxi(from.x, to.x)
	var y0 = mini(from.y, to.y)
	var y1 = maxi(from.y, to.y)
	for x in range(x0, x1 + 1):
		_set_pixel_safe(x, y0, c)
		_set_pixel_safe(x, y1, c)
	for y in range(y0 + 1, y1):
		_set_pixel_safe(x0, y, c)
		_set_pixel_safe(x1, y, c)
	_edit_canvas.queue_redraw()


## Eyedropper — right-click picks the color under the cursor.
func _eyedropper_pick(pos: Vector2) -> void:
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
		var c = _edit_image.get_pixel(px, py)
		if c.a > 0.01:
			_edit_color = c
			_edit_erasing = false
			# Deselect all palette buttons (custom picked color)
			for b in _edit_palette_btns:
				if is_instance_valid(b):
					b.button_pressed = false


## Commit a paint stroke to the undo stack.
func _commit_sprite_stroke() -> void:
	if _edit_stroke_snap == null:
		return
	# Only push if pixels actually changed
	if _edit_image.get_data() != _edit_stroke_snap.get_data():
		_edit_sprite_undo.append(_edit_stroke_snap)
		if _edit_sprite_undo.size() > 50:
			_edit_sprite_undo.pop_front()
		_edit_sprite_redo.clear()
	_edit_stroke_snap = null


func _sprite_undo() -> void:
	if _edit_sprite_undo.is_empty():
		return
	_edit_sprite_redo.append(_edit_image.duplicate())
	_edit_image = _edit_sprite_undo.pop_back()
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	if is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()


func _sprite_redo() -> void:
	if _edit_sprite_redo.is_empty():
		return
	_edit_sprite_undo.append(_edit_image.duplicate())
	_edit_image = _edit_sprite_redo.pop_back()
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	if is_instance_valid(_edit_canvas):
		_edit_canvas.queue_redraw()


# ─── Sprite Import ───────────────────────────────────────────

## Import from actor detail header — replaces all frames of first animation
func _on_import_sprite_pressed(actor_id: int) -> void:
	if _sprite_import_dialog and is_instance_valid(_sprite_import_dialog):
		_sprite_import_dialog.queue_free()
	_sprite_import_dialog = FileDialog.new()
	_sprite_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sprite_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sprite_import_dialog.title = "Import Sprite from PNG"
	_sprite_import_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	_sprite_import_dialog.size = Vector2i(700, 450)
	_sprite_import_dialog.file_selected.connect(_on_sprite_file_selected.bind(actor_id))
	add_child(_sprite_import_dialog)
	_sprite_import_dialog.popup_centered()


func _on_sprite_file_selected(path: String, actor_id: int) -> void:
	if not tile_library or actor_id < 0:
		return
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("AGCK: Could not load image: " + path)
		return
	var w := img.get_width()
	var h := img.get_height()
	# Get current anims or create default
	var spr = tile_library.actor_sprites.get(actor_id, {})
	var anims: Dictionary = spr.get("anims", {})
	var first_anim_name: String = "Idle"
	if anims.size() > 0:
		first_anim_name = anims.keys()[0]
	# Detect spritesheet: width is multiple of height
	var new_frames: Array = []
	if w > h and w % h == 0:
		var frame_count := w / h
		for i in range(mini(frame_count, 32)):
			var frame_img := img.get_region(Rect2i(i * h, 0, h, h))
			frame_img.resize(24, 24, Image.INTERPOLATE_NEAREST)
			new_frames.append(frame_img)
	else:
		# Single image
		img.resize(24, 24, Image.INTERPOLATE_NEAREST)
		new_frames.append(img)
	anims[first_anim_name] = new_frames
	tile_library.update_actor_anims(actor_id, anims)
	# Sync anim_data
	if actor_id < actors.size():
		var old_data: Array = actors[actor_id].get("anim_data", [])
		var found := false
		for od in old_data:
			if od.get("name", "") == first_anim_name:
				found = true
				break
		if not found:
			old_data.append({"name": first_anim_name, "speed": 8, "loop": true})
			actors[actor_id]["anim_data"] = old_data
		actor_changed.emit(actor_id)
	_rebuild_cards()
	_rebuild_detail()


## Import from inside sprite editor — adds frame(s) to current animation
func _on_import_frame_pressed() -> void:
	if _sprite_import_dialog and is_instance_valid(_sprite_import_dialog):
		_sprite_import_dialog.queue_free()
	_sprite_import_dialog = FileDialog.new()
	_sprite_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sprite_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sprite_import_dialog.title = "Import Frame(s) from PNG"
	_sprite_import_dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	_sprite_import_dialog.size = Vector2i(700, 450)
	_sprite_import_dialog.file_selected.connect(_on_frame_file_selected)
	if is_instance_valid(_edit_popup):
		_edit_popup.add_child(_sprite_import_dialog)
	else:
		add_child(_sprite_import_dialog)
	_sprite_import_dialog.popup_centered()


func _on_frame_file_selected(path: String) -> void:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("AGCK: Could not load image: " + path)
		return
	# Save current frame before modifying
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	var w := img.get_width()
	var h := img.get_height()
	if w > h and w % h == 0:
		# Spritesheet — split into frames
		var frame_count := w / h
		for i in range(mini(frame_count, 32 - _edit_frames.size())):
			var frame_img := img.get_region(Rect2i(i * h, 0, h, h))
			frame_img.resize(24, 24, Image.INTERPOLATE_NEAREST)
			_edit_frames.insert(_edit_current_frame + 1 + i, frame_img)
		_switch_to_frame(mini(_edit_current_frame + 1, _edit_frames.size() - 1))
	else:
		# Single image — replace current frame
		if _edit_frames.size() >= 32:
			return
		img.resize(24, 24, Image.INTERPOLATE_NEAREST)
		_edit_frames.insert(_edit_current_frame + 1, img)
		_switch_to_frame(_edit_current_frame + 1)


func _on_actor_edit_save() -> void:
	if tile_library and _edit_actor_id >= 0:
		# Save current frame back to array
		if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
			_edit_frames[_edit_current_frame] = _edit_image
		# Save current animation's frames back to the anims dict
		if _edit_current_anim != "" and _edit_anims.has(_edit_current_anim):
			_edit_anims[_edit_current_anim] = _edit_frames
		# Save all named animations to tile library
		tile_library.update_actor_anims(_edit_actor_id, _edit_anims)
		# Sync actor's anim_data to match the current animations
		if _edit_actor_id < actors.size():
			var old_data: Array = actors[_edit_actor_id].get("anim_data", [])
			var new_data: Array = []
			for anim_name in _edit_anims:
				# Preserve existing speed/loop settings if they exist
				var found := false
				for od in old_data:
					if od.get("name", "") == anim_name:
						new_data.append(od)
						found = true
						break
				if not found:
					new_data.append({"name": anim_name, "speed": 8, "loop": true})
			actors[_edit_actor_id]["anim_data"] = new_data
			actor_changed.emit(_edit_actor_id)
		_rebuild_cards()
		_rebuild_detail()
	_close_actor_edit()


func _on_actor_edit_close() -> void:
	_close_actor_edit()


func _close_actor_edit() -> void:
	_stop_preview_timer()
	if _edit_popup and is_instance_valid(_edit_popup):
		_edit_popup.queue_free()
		_edit_popup = null
	_edit_image = null
	_edit_frames.clear()
	_edit_anims.clear()
	_edit_current_anim = ""
	_edit_current_frame = 0
	_edit_frame_label = null
	_edit_preview_rect = null
	_edit_anim_row = null
	_edit_anim_btns.clear()
	_edit_sprite_undo.clear()
	_edit_sprite_redo.clear()
	_edit_stroke_snap = null


# ─────────────────────────────────────────────────────────────────────────────
# LOSPEC PALETTE BROWSER (AGCK Actor Editor)
# ─────────────────────────────────────────────────────────────────────────────
func _show_agck_lospec_browser() -> void:
	if _agck_lospec_dialog != null and is_instance_valid(_agck_lospec_dialog):
		_agck_lospec_dialog.queue_free()
		_agck_lospec_dialog = null
	_agck_lospec_dialog = AcceptDialog.new()
	_agck_lospec_dialog.title = "🌐 Browse Lospec Palettes"
	_agck_lospec_dialog.min_size = Vector2(780, 700)
	_agck_lospec_dialog.ok_button_text = "Close"
	_agck_lospec_dialog.exclusive = true
	_agck_lospec_dialog.popup_window = true
	_agck_lospec_dialog.confirmed.connect(func(): _agck_lospec_dialog.queue_free(); _agck_lospec_dialog = null; _agck_lospec_results_box = null; _agck_lospec_selected_row = null; _agck_lospec_page_label = null)
	_agck_lospec_dialog.canceled.connect(func(): _agck_lospec_dialog.queue_free(); _agck_lospec_dialog = null; _agck_lospec_results_box = null; _agck_lospec_selected_row = null; _agck_lospec_page_label = null)
	add_child(_agck_lospec_dialog)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_agck_lospec_dialog.add_child(vbox)
	var search_row = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	vbox.add_child(search_row)
	var lbl_search = Label.new()
	lbl_search.text = "Tag:"
	lbl_search.add_theme_font_size_override("font_size", 13)
	lbl_search.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	search_row.add_child(lbl_search)
	_agck_lospec_search_edit = LineEdit.new()
	_agck_lospec_search_edit.placeholder_text = "e.g. gameboy, retro, fantasy..."
	_agck_lospec_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agck_lospec_search_edit.add_theme_font_size_override("font_size", 13)
	search_row.add_child(_agck_lospec_search_edit)
	var lbl_sort = Label.new()
	lbl_sort.text = "Sort:"
	lbl_sort.add_theme_font_size_override("font_size", 13)
	lbl_sort.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	search_row.add_child(lbl_sort)
	_agck_lospec_sort_option = OptionButton.new()
	_agck_lospec_sort_option.add_theme_font_size_override("font_size", 13)
	_agck_lospec_sort_option.add_item("Popular", 0)
	_agck_lospec_sort_option.add_item("Newest", 1)
	_agck_lospec_sort_option.add_item("Default", 2)
	search_row.add_child(_agck_lospec_sort_option)
	var btn_search = Button.new()
	btn_search.text = "🔍 Search"
	btn_search.add_theme_font_size_override("font_size", 13)
	btn_search.pressed.connect(_agck_lospec_do_search.bind(0))
	search_row.add_child(btn_search)
	_agck_lospec_search_edit.text_submitted.connect(func(_t): _agck_lospec_do_search(0))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 480)
	vbox.add_child(scroll)
	var scroll_inner_panel = PanelContainer.new()
	scroll_inner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll_inner_bg = StyleBoxFlat.new()
	scroll_inner_bg.bg_color = Color(0.14, 0.14, 0.18, 1.0)
	scroll_inner_bg.set_corner_radius_all(4)
	scroll_inner_bg.set_content_margin_all(4)
	scroll_inner_panel.add_theme_stylebox_override("panel", scroll_inner_bg)
	scroll.add_child(scroll_inner_panel)
	_agck_lospec_results_box = VBoxContainer.new()
	_agck_lospec_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agck_lospec_results_box.add_theme_constant_override("separation", 4)
	scroll_inner_panel.add_child(_agck_lospec_results_box)

	# Page info label — outside scroll so always visible
	_agck_lospec_page_label = Label.new()
	_agck_lospec_page_label.text = ""
	_agck_lospec_page_label.add_theme_font_size_override("font_size", 13)
	_agck_lospec_page_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	_agck_lospec_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_agck_lospec_page_label)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom_row)
	var btn_prev = Button.new()
	btn_prev.text = "◀ Prev"
	btn_prev.add_theme_font_size_override("font_size", 13)
	btn_prev.pressed.connect(_agck_lospec_prev_page)
	bottom_row.add_child(btn_prev)
	var btn_next = Button.new()
	btn_next.text = "Next ▶"
	btn_next.add_theme_font_size_override("font_size", 13)
	btn_next.pressed.connect(_agck_lospec_next_page)
	bottom_row.add_child(btn_next)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)
	var btn_install = Button.new()
	btn_install.text = "✅ Install Selected Palette"
	btn_install.add_theme_font_size_override("font_size", 13)
	btn_install.pressed.connect(_on_agck_lospec_install)
	bottom_row.add_child(btn_install)
	var hint = Label.new()
	hint.text = "Click to select, double-click to install, right-click to open on lospec.com"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)
	_agck_lospec_dialog.popup_centered()
	_agck_lospec_do_search(0)


func _agck_lospec_clear_results() -> void:
	if _agck_lospec_results_box == null:
		return
	for child in _agck_lospec_results_box.get_children():
		child.queue_free()
	_agck_lospec_selected_index = -1
	_agck_lospec_selected_row = null


func _agck_lospec_add_message(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	_agck_lospec_results_box.add_child(lbl)


func _agck_lospec_do_search(page: int) -> void:
	_agck_lospec_page = page
	var sort_map = ["downloads", "newest", "default"]
	var sort_idx = _agck_lospec_sort_option.selected if _agck_lospec_sort_option else 0
	var sort_str: String = sort_map[sort_idx] if sort_idx < sort_map.size() else "downloads"
	var tag: String = _agck_lospec_search_edit.text.strip_edges() if _agck_lospec_search_edit else ""
	var url = "https://lospec.com/palette-list/load?page=%d&tag=%s&sortingType=%s&colorNumberFilterType=any" % [page, tag.uri_encode(), sort_str]
	_agck_lospec_clear_results()
	_agck_lospec_add_message("⏳ Loading palettes from Lospec...")
	if _agck_lospec_http != null and is_instance_valid(_agck_lospec_http):
		_agck_lospec_http.cancel_request()
		_agck_lospec_http.queue_free()
	_agck_lospec_http = HTTPRequest.new()
	_agck_lospec_http.request_completed.connect(_on_agck_lospec_response)
	add_child(_agck_lospec_http)
	var err = _agck_lospec_http.request(url)
	if err != OK:
		_agck_lospec_clear_results()
		_agck_lospec_add_message("❌ HTTP request failed (error %d). Check internet connection and try again." % err)


func _on_agck_lospec_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _agck_lospec_results_box == null or not is_instance_valid(_agck_lospec_results_box):
		return
	_agck_lospec_clear_results()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_agck_lospec_add_message("❌ Request failed (HTTP %d)" % response_code)
		return
	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_agck_lospec_add_message("❌ Failed to parse JSON response")
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	_agck_lospec_palettes = data.get("palettes", [])
	_agck_lospec_total = int(data.get("totalCount", data.get("totalPalettes", 0)))
	if _agck_lospec_palettes.is_empty():
		_agck_lospec_add_message("No palettes found. Try a different tag.")
		return
	for i in range(_agck_lospec_palettes.size()):
		var pal: Dictionary = _agck_lospec_palettes[i]
		var title: String = pal.get("title", "Untitled")
		var n_colors: int = int(pal.get("numberOfColors", 0))
		var downloads: String = str(pal.get("downloads", "0"))
		var colors_arr: Array = pal.get("colors", [])
		var panel = PanelContainer.new()
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.19, 0.20, 0.25, 1.0)
		style_normal.set_corner_radius_all(4)
		style_normal.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style_normal)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx = i
		panel.gui_input.connect(_agck_lospec_row_input.bind(idx, panel))
		_agck_lospec_results_box.add_child(panel)
		var row_vbox = VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 3)
		row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row_vbox)
		var info_lbl = Label.new()
		info_lbl.text = "%s  (%d colors)  ⬇%s" % [title, n_colors, downloads]
		info_lbl.add_theme_font_size_override("font_size", 13)
		info_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
		info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(info_lbl)
		var swatch_row = HBoxContainer.new()
		swatch_row.add_theme_constant_override("separation", 1)
		swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_vbox.add_child(swatch_row)
		var max_swatches = mini(colors_arr.size(), 24)
		for ci in range(max_swatches):
			var cr = ColorRect.new()
			cr.custom_minimum_size = Vector2(18, 18)
			cr.color = Color("#" + str(colors_arr[ci]).strip_edges())
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(cr)
		if colors_arr.size() > 24:
			var more_lbl = Label.new()
			more_lbl.text = "+%d" % (colors_arr.size() - 24)
			more_lbl.add_theme_font_size_override("font_size", 10)
			more_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			more_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(more_lbl)
	# Page info footer — update the label outside the scroll
	if _agck_lospec_page_label != null and is_instance_valid(_agck_lospec_page_label):
		_agck_lospec_page_label.text = "— Page %d  |  %d palettes total —" % [_agck_lospec_page + 1, _agck_lospec_total]


func _agck_lospec_row_input(event: InputEvent, index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if index >= 0 and index < _agck_lospec_palettes.size():
			var slug: String = _agck_lospec_palettes[index].get("slug", "")
			if slug != "":
				OS.shell_open("https://lospec.com/palette-list/" + slug)
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _agck_lospec_selected_row != null and is_instance_valid(_agck_lospec_selected_row):
			var old_style = StyleBoxFlat.new()
			old_style.bg_color = Color(0.19, 0.20, 0.25, 1.0)
			old_style.set_corner_radius_all(4)
			old_style.set_content_margin_all(6)
			_agck_lospec_selected_row.add_theme_stylebox_override("panel", old_style)
		_agck_lospec_selected_index = index
		_agck_lospec_selected_row = panel
		var sel_style = StyleBoxFlat.new()
		sel_style.bg_color = Color(0.22, 0.36, 0.56, 1.0)
		sel_style.set_corner_radius_all(4)
		sel_style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", sel_style)
		if event.double_click:
			_agck_lospec_install_index(index)


func _on_agck_lospec_install() -> void:
	if _agck_lospec_selected_index < 0:
		return
	_agck_lospec_install_index(_agck_lospec_selected_index)


func _agck_lospec_install_index(index: int) -> void:
	if index < 0 or index >= _agck_lospec_palettes.size():
		return
	var pal: Dictionary = _agck_lospec_palettes[index]
	var title: String = pal.get("title", "Lospec Palette")
	var colors_raw: Array = pal.get("colors", [])
	if colors_raw.is_empty():
		return
	var new_colors: Array = []
	for hex_str in colors_raw:
		var s: String = str(hex_str).strip_edges()
		if not s.begins_with("#"):
			s = "#" + s
		new_colors.append(Color(s))
	_edit_palette_colors = new_colors
	_edit_color = new_colors[0]
	_rebuild_agck_palette_row()
	# Save to custom palettes
	var hex_colors: Array = []
	for c in new_colors:
		hex_colors.append("#" + c.to_html(false))
	_agck_add_custom_palette(title, hex_colors)
	print("AGCK ActorEditor: Installed Lospec palette '%s' (%d colors)" % [title, new_colors.size()])


func _rebuild_agck_palette_row() -> void:
	if _edit_palette_row == null or not is_instance_valid(_edit_palette_row):
		return
	# Remove old palette buttons but keep first child (label) and last child (lospec btn)
	var children = _edit_palette_row.get_children()
	for i in range(children.size() - 1, 0, -1):
		if i == children.size() - 1:
			continue  # keep lospec button
		children[i].queue_free()
	_edit_palette_btns.clear()
	var lospec_btn_ref = children[children.size() - 1] if children.size() > 0 else null
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
		cbtn.pressed.connect(_on_actor_edit_color.bind(ci))
		_edit_palette_row.add_child(cbtn)
		_edit_palette_btns.append(cbtn)
	if lospec_btn_ref and is_instance_valid(lospec_btn_ref):
		_edit_palette_row.move_child(lospec_btn_ref, -1)


# ─────────────────────────────────────────────────────────────────────────────
# AGCK CUSTOM PALETTE PERSISTENCE
# ─────────────────────────────────────────────────────────────────────────────
func _agck_load_custom_palettes() -> void:
	_agck_custom_palettes.clear()
	if not FileAccess.file_exists(AGCK_CUSTOM_PALETTES_PATH):
		return
	var fa := FileAccess.open(AGCK_CUSTOM_PALETTES_PATH, FileAccess.READ)
	if fa == null:
		return
	var text := fa.get_as_text()
	fa.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if data is Dictionary:
		for key in data:
			if data[key] is Array:
				_agck_custom_palettes[str(key)] = data[key]


func _agck_save_custom_palettes() -> void:
	var fa := FileAccess.open(AGCK_CUSTOM_PALETTES_PATH, FileAccess.WRITE)
	if fa == null:
		return
	fa.store_string(JSON.stringify(_agck_custom_palettes, "\t"))
	fa.close()


func _agck_add_custom_palette(pname: String, colors: Array) -> void:
	_agck_custom_palettes[pname] = colors
	_agck_save_custom_palettes()
	if _agck_palette_option == null or not is_instance_valid(_agck_palette_option):
		return
	var display_name := "★ " + pname
	var found := false
	for i in range(_agck_palette_option.item_count):
		if _agck_palette_option.get_item_text(i) == display_name:
			_agck_palette_option.selected = i
			found = true
			break
	if not found:
		_agck_palette_option.add_item(display_name)
		_agck_palette_option.selected = _agck_palette_option.item_count - 1
	_agck_update_remove_btn_state()


func _on_agck_palette_selected(idx: int) -> void:
	if _agck_palette_option == null:
		return
	var display_name := _agck_palette_option.get_item_text(idx)
	if display_name == "(Default)":
		# Restore default palette
		_edit_palette_colors = _build_actor_palette("")
	elif display_name in AGCK_PALETTES:
		var hex_arr: Array = AGCK_PALETTES[display_name]
		var new_colors: Array = []
		for h in hex_arr:
			new_colors.append(Color(str(h)))
		_edit_palette_colors = new_colors
	elif display_name.begins_with("★ "):
		var cname := display_name.substr(2)
		if cname in _agck_custom_palettes:
			var hex_arr: Array = _agck_custom_palettes[cname]
			var new_colors: Array = []
			for h in hex_arr:
				new_colors.append(Color(str(h)))
			_edit_palette_colors = new_colors
	if _edit_palette_colors.size() > 0:
		_edit_color = _edit_palette_colors[0]
	_rebuild_agck_palette_row()
	_agck_update_remove_btn_state()


func _on_agck_remove_palette_pressed() -> void:
	if _agck_palette_option == null:
		return
	var sel := _agck_palette_option.selected
	if sel < 0:
		return
	var display_name := _agck_palette_option.get_item_text(sel)
	if not display_name.begins_with("★ "):
		return
	var cname := display_name.substr(2)
	var confirm := ConfirmationDialog.new()
	confirm.title = "Remove Palette"
	confirm.dialog_text = "Remove custom palette '%s'?\nThis cannot be undone." % cname
	confirm.ok_button_text = "Remove"
	confirm.confirmed.connect(func():
		_agck_custom_palettes.erase(cname)
		_agck_save_custom_palettes()
		_agck_palette_option.remove_item(sel)
		_agck_palette_option.selected = 0
		_on_agck_palette_selected(0)
		print("AGCK ActorEditor: Removed custom palette '%s'" % cname)
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	add_child(confirm)
	confirm.popup_centered()


func _agck_update_remove_btn_state() -> void:
	if _agck_palette_remove_btn == null or not is_instance_valid(_agck_palette_remove_btn):
		return
	if _agck_palette_option == null or _agck_palette_option.selected < 0:
		_agck_palette_remove_btn.disabled = true
		return
	var name := _agck_palette_option.get_item_text(_agck_palette_option.selected)
	_agck_palette_remove_btn.disabled = not name.begins_with("★ ")


func _agck_lospec_prev_page() -> void:
	if _agck_lospec_page > 0:
		_agck_lospec_do_search(_agck_lospec_page - 1)


func _agck_lospec_next_page() -> void:
	_agck_lospec_do_search(_agck_lospec_page + 1)