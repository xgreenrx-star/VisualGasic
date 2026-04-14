@tool
## AGCK Actor Editor — visual card gallery
##
## Actors displayed as a scrollable card grid instead of list + form.
## Click a card to expand its property panel. Color-coded by type.
extends VBoxContainer

signal actor_changed(actor_id: int)

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

# ─── Data ────────────────────────────────────────────────────
var actors: Array = []
var selected_actor: int = 0

# Reference to tile library for actor sprite previews (set by agck_plugin.gd)
var tile_library = null

# ─── UI Refs ─────────────────────────────────────────────────
var _card_grid: GridContainer = null
var _detail_scroll: ScrollContainer = null
var _detail_panel: VBoxContainer = null
var _card_buttons: Array = []

# Inline sprite editor popup
var _edit_popup: Window = null
var _edit_canvas: Control = null
var _edit_image: Image = null
var _edit_actor_id: int = -1
var _edit_color: Color = Color.WHITE
var _edit_erasing: bool = false
var _edit_palette_btns: Array = []
var _edit_palette_colors: Array = []
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

	_rebuild_cards()
	_rebuild_detail()


# ─── Card Grid ───────────────────────────────────────────────

func _rebuild_cards() -> void:
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
		card.custom_minimum_size = Vector2(140, 56)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)

		# Sprite preview row (thumbnail + name/type)
		var top_row = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 6)
		vbox.add_child(top_row)

		# Actor sprite thumbnail from tile library
		if tile_library:
			tile_library.ensure_actor_sprite(i, actor.get("name", "Actor"), atype)
			var actor_tex = tile_library.get_actor_texture(i)
			if actor_tex:
				var tex_rect = TextureRect.new()
				tex_rect.texture = actor_tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.custom_minimum_size = Vector2(36, 36)
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				top_row.add_child(tex_rect)

		var info_vbox = VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 1)
		top_row.add_child(info_vbox)

		var name_lbl = Label.new()
		name_lbl.text = actor.get("name", "Actor")
		name_lbl.label_settings = _ls(12, WHITE)
		info_vbox.add_child(name_lbl)

		var type_lbl = Label.new()
		type_lbl.text = atype
		type_lbl.label_settings = _ls(10, color)
		info_vbox.add_child(type_lbl)

		# Click handler
		var btn = Button.new()
		btn.flat = true
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.pressed.connect(_on_card_clicked.bind(i))
		btn.gui_input.connect(_on_card_gui_input.bind(i))
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

	var type_opt = OptionButton.new()
	type_opt.add_theme_font_size_override("font_size", 12)
	for t in ACTOR_TYPES:
		type_opt.add_item(t)
	type_opt.selected = ACTOR_TYPES.find(atype)
	if type_opt.selected < 0:
		type_opt.selected = 0
	type_opt.item_selected.connect(_on_type_changed)
	h_hbox.add_child(type_opt)
	_style_option(type_opt)

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

	var sep1 = VSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	frame_row.add_child(sep1)

	var btn_add = _frame_btn("+ Add", "Add new blank frame after current")
	btn_add.pressed.connect(_on_frame_add)
	frame_row.add_child(btn_add)

	var btn_dup = _frame_btn("⧉ Copy", "Duplicate current frame")
	btn_dup.pressed.connect(_on_frame_duplicate)
	frame_row.add_child(btn_dup)

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
		cbtn.pressed.connect(_on_actor_edit_color.bind(ci))
		palette_row.add_child(cbtn)
		_edit_palette_btns.append(cbtn)

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


func _on_frame_duplicate() -> void:
	if _edit_frames.size() >= 32:
		return
	# Save current frame first
	if _edit_current_frame >= 0 and _edit_current_frame < _edit_frames.size():
		_edit_frames[_edit_current_frame] = _edit_image
	# Duplicate current frame and insert after
	var dup = _edit_image.duplicate()
	_edit_frames.insert(_edit_current_frame + 1, dup)
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
	var preview_idx = int(Time.get_ticks_msec() / 150) % _edit_frames.size()
	var fr = _edit_frames[preview_idx]
	var scaled = fr.duplicate()
	scaled.resize(48, 48, Image.INTERPOLATE_NEAREST)
	_edit_preview_rect.texture = ImageTexture.create_from_image(scaled)


var _preview_timer: Timer = null

func _start_preview_timer() -> void:
	_stop_preview_timer()
	_preview_timer = Timer.new()
	_preview_timer.wait_time = 0.15
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
			if event.pressed:
				_edit_stroke_snap = _edit_image.duplicate()
				_actor_edit_pixel(event.position)
			else:
				_commit_sprite_stroke()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Eyedropper — pick the color under cursor
			_eyedropper_pick(event.position)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_actor_edit_pixel(event.position)


func _actor_edit_pixel(pos: Vector2) -> void:
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
