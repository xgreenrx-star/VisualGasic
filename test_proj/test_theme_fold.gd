extends SceneTree

func _init():
	var ce := VGCodeEdit.new()
	ce.name = "TestCE"
	root.add_child.call_deferred(ce)
	call_deferred("_frame2", ce)

func _frame2(ce: VGCodeEdit) -> void:
	call_deferred("_check", ce)

func _check(ce: VGCodeEdit) -> void:
	print("=== State after _ready (before theme manager) ===")
	print("  line_folding:       %s" % ce.is_line_folding_enabled())
	print("  draw_fold_gutter:   %s" % ce.is_drawing_fold_gutter())
	print("  has can_fold icon:  %s" % ce.has_theme_icon("can_fold"))

	# Now simulate what the embedded code editor does
	print("")
	print("=== Calling VGThemeManager.apply_to_code_edit() ===")
	VGThemeManager.apply_to_code_edit(ce)

	print("  line_folding:       %s" % ce.is_line_folding_enabled())
	print("  draw_fold_gutter:   %s" % ce.is_drawing_fold_gutter())
	print("  has can_fold icon:  %s" % ce.has_theme_icon("can_fold"))
	print("  ce.theme:           %s" % ce.theme)

	# Check fold gutter after theme is assigned
	ce.text = "Sub Main()\n\tDim x As Integer\nEnd Sub"
	print("")
	for i in range(ce.get_line_count()):
		print("  Line %d: can_fold=%s '%s'" % [i, ce.can_fold_line(i), ce.get_line(i)])

	# Check all gutters
	print("")
	print("=== Gutter state ===")
	for i in range(ce.get_gutter_count()):
		print("  gutter %d: name='%s' width=%d draw=%s" % [
			i, ce.get_gutter_name(i), ce.get_gutter_width(i), ce.is_gutter_drawn(i)])

	quit()
