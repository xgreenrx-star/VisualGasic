@tool
## Form Designer plugin — proper sub-plugin wrapper for the built-in VB6-style
## visual Form Designer.
##
## Previously the Form Designer was registered as an inline "builtin" pseudo-
## plugin in vg_plugin_manager.gd.  Moving it here gives it:
##   • A standard plugin.cfg manifest discoverable by any tooling.
##   • handles_extensions = ["frm", "vgform"] so it appears in the strip and
##     is auto-enabled when the project contains legacy form files.
##   • A proper plugin ID ("form_designer") instead of __builtin_form_designer__.
##
## Activation: clicking the toolbar button calls _show_form_view() on the host
## IDE plugin exactly as the old builtin button did.  No UI is built in this
## script — the actual form canvas lives in visual_gasic_plugin.gd and is
## managed by the VisualGasicFormDesigner C++ node.
extends "res://addons/visual_gasic/vg_plugin_base.gd"

func get_plugin_name() -> String:
	return "Form Designer"

func get_toolbar_icon() -> String:
	return "🎨"

func get_toolbar_color() -> Color:
	return Color(0.42, 0.32, 0.55)  # muted purple — matches old builtin button

func get_toolbar_tooltip() -> String:
	return "Switch to the visual Form Designer (VB6 mode)"

func _build_ui() -> void:
	# The Form Designer canvas is owned by the host IDE plugin, not by this
	# sub-plugin.  _build_ui() is called once when the plugin is first
	# activated via the toolbar button.  We immediately delegate to the host's
	# _show_form_view(), which performs the full view-switch including tearing
	# down any active code/3D/2D editor and showing the form canvas.
	if _host_plugin and _host_plugin.has_method("_show_form_view"):
		_host_plugin._show_form_view()

func activate() -> void:
	# Override activate so clicking the toolbar button always calls
	# _show_form_view() regardless of whether _build_ui() was invoked before.
	_is_active = true
	if _host_plugin and _host_plugin.has_method("_show_form_view"):
		_host_plugin._show_form_view()
