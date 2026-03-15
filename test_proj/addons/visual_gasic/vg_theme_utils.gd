## Shared theming utilities for VisualGasic editor UI.
## Provides light VB6-style popup / context-menu theming that can be
## preloaded from any GDScript file:
##     const VGTheme = preload("res://addons/visual_gasic/vg_theme_utils.gd")
##     VGTheme.style_popup(my_popup)
extends RefCounted

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
	te.context_menu_enabled = true
	if not te.has_meta("_vg_ctx_hooked"):
		te.set_meta("_vg_ctx_hooked", true)
		te.tree_entered.connect(func(): style_popup(te.get_menu()))

# ── Convenience: theme an OptionButton's dropdown popup ──────────────────

## Call once after creating an OptionButton. The dropdown will be themed
## the first time the widget enters the scene tree.
static func hook_option_button(ob: OptionButton) -> void:
	if not ob:
		return
	if not ob.has_meta("_vg_ob_hooked"):
		ob.set_meta("_vg_ob_hooked", true)
		ob.tree_entered.connect(func(): style_popup(ob.get_popup()))
