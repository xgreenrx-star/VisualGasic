## Shared theming utilities for VisualGasic editor UI.
## Provides light VB6-style popup / context-menu theming that can be
## preloaded from any GDScript file:
##     const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")
##     VGTheme.style_popup(my_popup)
extends RefCounted

const _VGGodotCompat = preload("res://addons/visual_gasic/vg_godot_compat.gd")

# ── Core: theme a PopupMenu (+ all child sub-menus) ──────────────────────

## Apply the VB6-light theme to a PopupMenu and every child PopupMenu.
## Safe to call repeatedly — uses a meta-tag to avoid reconnecting signals.
static func style_popup(menu: PopupMenu) -> void:
	if not menu:
		return
	_apply_popup_overrides(menu)
	# Immediately theme any existing child submenus (e.g. "Text Writing Direction")
	for c in menu.get_children():
		if c is PopupMenu:
			_apply_popup_overrides(c)
	# Also catch submenus that Godot creates lazily (first popup show)
	if not menu.has_meta("_vg_popup_themed"):
		menu.set_meta("_vg_popup_themed", true)
		menu.about_to_popup.connect(func():
			for c2 in menu.get_children():
				if c2 is PopupMenu:
					_apply_popup_overrides(c2)
		)

static func _apply_popup_overrides(menu: PopupMenu) -> void:
	# Font colours
	menu.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	menu.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	menu.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	menu.add_theme_color_override("font_separator_color", Color(0.4, 0.4, 0.4))
	menu.add_theme_color_override("font_accelerator_color", Color(0.45, 0.45, 0.45))
	# Panel background
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.96, 0.95, 0.93)
	panel_sb.border_width_top = 1; panel_sb.border_width_bottom = 1
	panel_sb.border_width_left = 1; panel_sb.border_width_right = 1
	panel_sb.border_color = Color(0.55, 0.54, 0.52)
	panel_sb.content_margin_left = 4; panel_sb.content_margin_right = 4
	panel_sb.content_margin_top = 4; panel_sb.content_margin_bottom = 4
	menu.add_theme_stylebox_override("panel", panel_sb)
	# Hover highlight
	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.0, 0.47, 0.84)
	hover_sb.corner_radius_top_left = 2; hover_sb.corner_radius_top_right = 2
	hover_sb.corner_radius_bottom_left = 2; hover_sb.corner_radius_bottom_right = 2
	menu.add_theme_stylebox_override("hover", hover_sb)
	# Separator
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color(0.78, 0.77, 0.75)
	sep_sb.content_margin_top = 4; sep_sb.content_margin_bottom = 4
	menu.add_theme_stylebox_override("separator", sep_sb)

# ── Convenience: hook a LineEdit's right-click context menu ──────────────

## Call once after creating a LineEdit. Its context menu will be themed
## the first time the widget enters the scene tree.
static func hook_line_edit(le: LineEdit) -> void:
	if not le:
		return
	le.context_menu_enabled = true
	if not le.has_meta("_vg_ctx_hooked"):
		le.set_meta("_vg_ctx_hooked", true)
		le.tree_entered.connect(func(): style_popup(le.get_menu()))

## Same for TextEdit / CodeEdit (both inherit TextEdit.get_menu()).
static func hook_text_edit(te: TextEdit) -> void:
	if not te:
		return
	# VGCodeEdit supplies its own right-click menu (file paths, comment blocks, …).
	if te.has_method("wrap_comment_block"):
		return
	te.context_menu_enabled = true
	if not te.has_meta("_vg_ctx_hooked"):
		te.set_meta("_vg_ctx_hooked", true)
		te.tree_entered.connect(func(): style_popup(te.get_menu()))

## Dark text on cream toolbars (Find:, Cols:, status labels, …).
static func style_light_toolbar_label(lbl: Label) -> void:
	if not lbl:
		return
	lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))


## MenuButton on cream toolbars (Open, Bookmarks, …) + themed dropdown.
static func style_menu_button(mb: MenuButton) -> void:
	if not mb:
		return
	style_toolbar_button(mb)
	var popup := mb.get_popup()
	if popup:
		style_popup(popup)
	if not mb.has_meta("_vg_menu_btn_hooked"):
		mb.set_meta("_vg_menu_btn_hooked", true)
		_VGGodotCompat.connect_popup_preshow(mb, func():
			if is_instance_valid(mb):
				style_menu_button(mb)
		)


## Recursively style Buttons, MenuButtons, OptionButtons, and Labels for cream panels.
static func style_light_toolbar_tree(root: Node) -> void:
	if root == null:
		return
	if root is MenuButton:
		style_menu_button(root as MenuButton)
	elif root is Button:
		style_toolbar_button(root as Button)
	elif root is OptionButton:
		hook_option_button(root as OptionButton)
	elif root is Label:
		style_light_toolbar_label(root as Label)
	for child in root.get_children():
		style_light_toolbar_tree(child)


## Cream toolbar toggle/button so it matches the Object and Procedure dropdowns.
static func style_toolbar_button(btn: Button) -> void:
	if not btn:
		return
	var text := Color(0.08, 0.08, 0.10)
	btn.add_theme_color_override("font_color", text)
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.45))
	btn.add_theme_color_override("font_pressed_color", text)
	btn.add_theme_color_override("font_hover_pressed_color", text)
	btn.add_theme_color_override("font_focus_color", text)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.65, 0.64, 0.62, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.97, 0.98, 1.0, 1.0)
	hover.border_color = Color(0.35, 0.45, 0.70, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.86, 0.91, 0.98, 1.0)
	pressed.border_color = Color(0.30, 0.50, 0.80, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal.duplicate())

# ── OptionButton: light chrome + dropdown (Godot editor theme is dark) ─

## Style the closed control and its PopupMenu for cream/light toolbars.
static func style_option_button(ob: OptionButton) -> void:
	if not ob:
		return
	var text := Color(0.08, 0.08, 0.10)
	ob.add_theme_color_override("font_color", text)
	ob.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.45))
	ob.add_theme_color_override("font_pressed_color", text)
	ob.add_theme_color_override("font_focus_color", text)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	normal.border_color = Color(0.65, 0.64, 0.62, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	ob.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.97, 0.98, 1.0, 1.0)
	hover.border_color = Color(0.35, 0.45, 0.70, 1.0)
	ob.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	pressed.border_color = Color(0.30, 0.50, 0.80, 1.0)
	ob.add_theme_stylebox_override("pressed", pressed)
	ob.add_theme_stylebox_override("focus", normal.duplicate())
	var popup := ob.get_popup()
	if popup:
		style_popup(popup)

# ── Convenience: theme an OptionButton's dropdown popup ──────────────────

## Call once after creating an OptionButton. Applies light styling to the
## control and dropdown; re-applies when the editor theme resets on popup.
static func hook_option_button(ob: OptionButton) -> void:
	if not ob:
		return
	style_option_button(ob)
	if not ob.has_meta("_vg_ob_hooked"):
		ob.set_meta("_vg_ob_hooked", true)
		ob.tree_entered.connect(func():
			if is_instance_valid(ob):
				style_option_button(ob)
		)
		_VGGodotCompat.connect_popup_preshow(ob, func():
			if is_instance_valid(ob):
				style_option_button(ob)
		)
		var popup := ob.get_popup()
		if popup:
			popup.popup_hide.connect(func():
				if is_instance_valid(ob):
					style_option_button(ob)
			)

# ── Tooltips (VB6 Data Tips: cream panel, black text) ─────────────────────

const TOOLTIP_BG := Color(1.0, 1.0, 0.88)
const TOOLTIP_BORDER := Color(0.15, 0.15, 0.12)
const TOOLTIP_TEXT := Color(0.08, 0.08, 0.10)

static func tooltip_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TOOLTIP_BG
	sb.border_color = TOOLTIP_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 1)
	return sb

## Build a Control Godot can use as `_make_custom_tooltip` (not the dark TooltipPanel).
static func make_tooltip_control(for_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", tooltip_stylebox())
	var label := Label.new()
	label.text = for_text
	label.add_theme_color_override("font_color", TOOLTIP_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	return panel

static func style_tooltip_label(label: Label) -> void:
	if not label:
		return
	label.add_theme_color_override("font_color", TOOLTIP_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_font_size_override("font_size", 12)
