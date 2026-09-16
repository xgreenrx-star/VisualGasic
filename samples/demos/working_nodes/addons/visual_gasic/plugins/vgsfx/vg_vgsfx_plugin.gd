@tool
## VGSFX Plugin — VisualGasic IDE wrapper around the native GDScript bfxr2 port.
##
## Hosts the VGSFX dock (synthesizer UI) inside the VG IDE plugin strip so it
## appears alongside AGCK / VG3D / Web Publish / Working Nodes in the
## ⚙ Plugin Settings dialog.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

const VGSFXDock := preload("res://addons/visual_gasic/plugins/vgsfx/vgsfx_dock.gd")

# VB6 palette (matches VGFormDesignerTheme)
const BG_COLOR    = Color(0.941, 0.929, 0.910)  # panel_background #F0EDE8
const HEADER_BG   = Color(0.0, 0.0, 0.5)        # sys_active_title (navy)
const ACCENT      = Color(0.0, 0.0, 0.5)
const WHITE       = Color(1.0, 1.0, 1.0)        # sys_title_text
const DIM         = Color(0.85, 0.85, 0.85)     # subtitle on navy
const PANEL_BORDER= Color(0.72, 0.71, 0.68)

var _dock: VBoxContainer = null


# ─── Plugin Identity ─────────────────────────────────────────

func get_plugin_name() -> String:
	return "VGSFX"

func get_toolbar_icon() -> String:
	return "🎛"

func get_toolbar_color() -> Color:
	return Color(0.0, 0.0, 0.5)  # VB navy

func get_toolbar_tooltip() -> String:
	return "VGSFX — sound-effects generator (bfxr2 port)"


# ─── UI Construction ─────────────────────────────────────────

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = BG_COLOR
	root.add_theme_stylebox_override("panel", root_style)
	_view.add_child(root)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	root.add_child(main_vbox)

	# ── Header ──
	var header := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = HEADER_BG
	h_style.content_margin_left = 16
	h_style.content_margin_right = 16
	h_style.content_margin_top = 10
	h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎛  VGSFX"
	title_lbl.label_settings = _ls(16, WHITE)
	header_hbox.add_child(title_lbl)

	var subtitle := Label.new()
	subtitle.text = "— Sound Effects Generator (bfxr2 port)"
	subtitle.label_settings = _ls(11, DIM)
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "← Back to IDE"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(request_back_to_form)
	header_hbox.add_child(back_btn)

	# ── Dock ──
	# Wrap the dock in a PanelContainer (VB warm-gray) inside a
	# ScrollContainer so the parameter sliders and buttons sit on a
	# proper VB6-style background instead of the editor's dark theme.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var dock_panel := PanelContainer.new()
	dock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dock_panel_style := StyleBoxFlat.new()
	dock_panel_style.bg_color = Color(0.831, 0.816, 0.784)  # sys_button_face
	dock_panel_style.border_color = PANEL_BORDER
	dock_panel_style.set_border_width_all(1)
	dock_panel_style.content_margin_left = 8
	dock_panel_style.content_margin_right = 8
	dock_panel_style.content_margin_top = 6
	dock_panel_style.content_margin_bottom = 6
	dock_panel.add_theme_stylebox_override("panel", dock_panel_style)
	scroll.add_child(dock_panel)

	_dock = VGSFXDock.new()
	_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_panel.add_child(_dock)


# ─── Helpers ─────────────────────────────────────────────────

func _ls(size: int, color: Color) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	return ls
