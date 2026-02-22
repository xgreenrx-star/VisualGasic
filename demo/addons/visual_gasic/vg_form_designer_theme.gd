## Visual Gasic — Form Designer Theme Configuration
##
## Edit this file to customize all colors and fonts used by the Form Designer
## and IDE panels (Toolbox, Properties Inspector, Project Explorer).
##
## Colors are organized into sections:
##   1. Form Canvas          — the form background, grid, selection
##   2. Win32 System Colors  — classic Windows control palette (3D borders, faces)
##   3. IDE Panel Colors     — Toolbox, Properties, Project Explorer backgrounds
##   4. IDE Header Colors    — VB6-style panel title bars
##   5. Toolbar Colors       — alignment/preview toolbar buttons
##   6. Fonts                — font family and sizes
##
## After editing, restart Godot (or toggle the plugin) to see changes.
## ─────────────────────────────────────────────────────────────────────────────
class_name VGFormDesignerTheme


# ═════════════════════════════════════════════════════════════════════════════
# 1. FORM CANVAS — the designer canvas where controls are placed
# ═════════════════════════════════════════════════════════════════════════════

## Background color of the form client area (classic VB6 gray)
static var form_background := Color(0.753, 0.753, 0.753)

## Grid dot color (small dots showing the snap grid)
static var grid_dots := Color(0.0, 0.0, 0.0, 0.3)

## Selection border color (drawn around selected controls)
static var selection_border := Color(0.0, 0.0, 0.6)

## Selection handle color (small squares at corners/edges of selected controls)
static var selection_handle := Color(0.0, 0.0, 0.0)

## Rubber-band selection rectangle color
static var rubber_band := Color(0.0, 0.0, 0.6, 0.3)

## Form border outline
static var form_border := Color(0.4, 0.4, 0.4)


# ═════════════════════════════════════════════════════════════════════════════
# 2. WIN32 SYSTEM COLORS — used for drawing WYSIWYG controls
#    These mirror the classic Windows system color palette.
# ═════════════════════════════════════════════════════════════════════════════

## Button/control face background (SystemButtonFace / #D4D0C8)
static var sys_button_face := Color(0.831, 0.816, 0.784)

## 3D highlight — top/left edges of raised controls
static var sys_button_highlight := Color(1.0, 1.0, 1.0)

## 3D shadow — bottom/right inner edge of raised controls
static var sys_button_shadow := Color(0.51, 0.51, 0.51)

## 3D dark shadow — outermost bottom/right edge
static var sys_3d_dark_shadow := Color(0.25, 0.25, 0.25)

## 3D light — inner highlight (slightly warmer white)
static var sys_3d_light := Color(0.93, 0.93, 0.89)

## Window background (textbox, listbox, treeview interiors)
static var sys_window := Color(1.0, 1.0, 1.0)

## Window text color (text inside textboxes, lists, labels)
static var sys_window_text := Color(0.0, 0.0, 0.0)

## Active title bar background (form title bar)
static var sys_active_title := Color(0.0, 0.0, 0.5)

## Title bar text color
static var sys_title_text := Color(1.0, 1.0, 1.0)

## Scrollbar track background
static var sys_scrollbar := Color(0.87, 0.87, 0.87)

## Arrow/glyph color on buttons, scrollbars, spinboxes
static var sys_glyph := Color(0.0, 0.0, 0.0)

## Progress bar fill color
static var sys_progress_fill := Color(0.0, 0.5, 0.0)

## Design-time dashed outline for Label/container controls
static var design_time_outline := Color(0.0, 0.0, 0.0, 0.35)

## Timer / non-visual component background
static var nonvisual_bg := Color(0.9, 0.85, 0.72)

## Timer / non-visual component border
static var nonvisual_border := Color(0.6, 0.55, 0.45)

## Placeholder / icon color (picture cross-lines, tree connectors)
static var placeholder_color := Color(0.6, 0.6, 0.6)


# ═════════════════════════════════════════════════════════════════════════════
# 3. IDE PANEL COLORS — Toolbox, Properties Inspector, Project Explorer
# ═════════════════════════════════════════════════════════════════════════════

## Panel background (warm off-white)
static var panel_background := Color("#F0EDE8")

## Panel border color
static var panel_border := Color(0.72, 0.71, 0.68)

## Toolbox button background (normal state)
static var toolbox_btn_normal := Color("#F0EDE8")

## Toolbox button hover background
static var toolbox_btn_hover := Color(0.91, 0.95, 1.0)

## Toolbox button pressed/selected background
static var toolbox_btn_pressed := Color(0.26, 0.59, 0.98)

## Toolbox button hover border
static var toolbox_btn_hover_border := Color(0.55, 0.73, 0.95)

## Toolbox button text color
static var toolbox_text := Color.BLACK

## Toolbox button text color when pressed
static var toolbox_text_pressed := Color.WHITE

## Project Explorer tree text color
static var project_explorer_text := Color.BLACK


# ═════════════════════════════════════════════════════════════════════════════
# 4. IDE HEADER COLORS — VB6-style panel title bars
# ═════════════════════════════════════════════════════════════════════════════

## Panel header background (gray-blue like VB6 title bars)
static var header_background := Color(0.58, 0.58, 0.62)

## Panel header border
static var header_border := Color(0.4, 0.4, 0.4)

## Panel header text color
static var header_text := Color(1.0, 1.0, 1.0)

## Panel header font size
static var header_font_size := 12


# ═════════════════════════════════════════════════════════════════════════════
# 5. TOOLBAR COLORS — alignment, preview, color palette toolbars
# ═════════════════════════════════════════════════════════════════════════════

## "↩ Godot Editor" button text color
static var godot_button_text := Color(0.85, 0.85, 0.85)

## "↩ Godot Editor" button hover text color
static var godot_button_hover_text := Color(1.0, 1.0, 1.0)

## VG IDE toggle button text color (golden)
static var toggle_button_text := Color(0.95, 0.82, 0.2)

## VG IDE toggle button hover text
static var toggle_button_hover := Color(1.0, 0.9, 0.3)

## VG IDE toggle button pressed text
static var toggle_button_pressed := Color(1.0, 1.0, 0.5)


# ═════════════════════════════════════════════════════════════════════════════
# 6. FONTS — font family and sizes
# ═════════════════════════════════════════════════════════════════════════════

## Main IDE font family name (empty = use Godot's default)
## Set to a font file path like "res://addons/visual_gasic/fonts/segoeui.ttf"
static var font_family := ""

## Form designer control font size (labels, buttons, textboxes on the canvas)
static var designer_font_size := 0  ## 0 = use Godot theme default

## Properties inspector font size
static var properties_font_size := 0  ## 0 = use Godot theme default

## Code editor font size
static var code_font_size := 0  ## 0 = use Godot theme default


# ═════════════════════════════════════════════════════════════════════════════
# 7. WINDOW TITLE
# ═════════════════════════════════════════════════════════════════════════════

## Window title prefix when in Form Designer mode
## The project name is appended automatically.
static var window_title_prefix := "Visual Gasic"


# ═════════════════════════════════════════════════════════════════════════════
# HELPER — Convert all theme values to a Dictionary for passing to C++
# ═════════════════════════════════════════════════════════════════════════════

## Returns a Dictionary of all form canvas + system colors for the C++ designer.
static func get_designer_colors() -> Dictionary:
	return {
		# Form canvas
		"form_background": form_background,
		"grid_dots": grid_dots,
		"selection_border": selection_border,
		"selection_handle": selection_handle,
		"rubber_band": rubber_band,
		"form_border": form_border,
		# Win32 system colors
		"sys_button_face": sys_button_face,
		"sys_button_highlight": sys_button_highlight,
		"sys_button_shadow": sys_button_shadow,
		"sys_3d_dark_shadow": sys_3d_dark_shadow,
		"sys_3d_light": sys_3d_light,
		"sys_window": sys_window,
		"sys_window_text": sys_window_text,
		"sys_active_title": sys_active_title,
		"sys_title_text": sys_title_text,
		"sys_scrollbar": sys_scrollbar,
		"sys_glyph": sys_glyph,
		"sys_progress_fill": sys_progress_fill,
		"design_time_outline": design_time_outline,
		"nonvisual_bg": nonvisual_bg,
		"nonvisual_border": nonvisual_border,
		"placeholder_color": placeholder_color,
	}

## Returns ALL theme values as a Dictionary (used by the plugin loader).
## This is the only reliable way to read static vars from a loaded GDScript.
static func get_all() -> Dictionary:
	return {
		# Form canvas
		"form_background": form_background,
		"grid_dots": grid_dots,
		"selection_border": selection_border,
		"selection_handle": selection_handle,
		"rubber_band": rubber_band,
		"form_border": form_border,
		# Win32 system colors
		"sys_button_face": sys_button_face,
		"sys_button_highlight": sys_button_highlight,
		"sys_button_shadow": sys_button_shadow,
		"sys_3d_dark_shadow": sys_3d_dark_shadow,
		"sys_3d_light": sys_3d_light,
		"sys_window": sys_window,
		"sys_window_text": sys_window_text,
		"sys_active_title": sys_active_title,
		"sys_title_text": sys_title_text,
		"sys_scrollbar": sys_scrollbar,
		"sys_glyph": sys_glyph,
		"sys_progress_fill": sys_progress_fill,
		"design_time_outline": design_time_outline,
		"nonvisual_bg": nonvisual_bg,
		"nonvisual_border": nonvisual_border,
		"placeholder_color": placeholder_color,
		# IDE panels
		"panel_background": panel_background,
		"panel_border": panel_border,
		"toolbox_btn_normal": toolbox_btn_normal,
		"toolbox_btn_hover": toolbox_btn_hover,
		"toolbox_btn_pressed": toolbox_btn_pressed,
		"toolbox_btn_hover_border": toolbox_btn_hover_border,
		"toolbox_text": toolbox_text,
		"toolbox_text_pressed": toolbox_text_pressed,
		"project_explorer_text": project_explorer_text,
		# Headers
		"header_background": header_background,
		"header_border": header_border,
		"header_text": header_text,
		"header_font_size": header_font_size,
		# Toolbar buttons
		"godot_button_text": godot_button_text,
		"godot_button_hover_text": godot_button_hover_text,
		"toggle_button_text": toggle_button_text,
		"toggle_button_hover": toggle_button_hover,
		"toggle_button_pressed": toggle_button_pressed,
		# Fonts
		"font_family": font_family,
		"designer_font_size": designer_font_size,
		"properties_font_size": properties_font_size,
		"code_font_size": code_font_size,
		# Window title
		"window_title_prefix": window_title_prefix,
	}
