extends SceneTree

func _init():
	var ce := CodeEdit.new()
	root.add_child.call_deferred(ce)
	call_deferred("_check", ce)

func _check(ce: CodeEdit) -> void:
	ce.set("line_folding", true)
	ce.set("gutters_draw_fold_gutter", true)

	print("=== BEFORE add_gutter(0) ===")
	print("  gutter_count: %d" % ce.get_gutter_count())
	for i in range(ce.get_gutter_count()):
		print("  gutter %d: name='%s' type=%d width=%d draw=%s" % [
			i, ce.get_gutter_name(i), ce.get_gutter_type(i),
			ce.get_gutter_width(i), ce.is_gutter_drawn(i)])

	# Now add a custom gutter at index 0 — this is what VGCodeEdit does
	ce.add_gutter(0)
	ce.set_gutter_type(0, TextEdit.GUTTER_TYPE_CUSTOM)
	ce.set_gutter_width(0, 4)
	ce.set_gutter_draw(0, true)
	ce.set_gutter_name(0, "change_tracking")

	print("")
	print("=== AFTER add_gutter(0) ===")
	print("  gutter_count: %d" % ce.get_gutter_count())
	for i in range(ce.get_gutter_count()):
		print("  gutter %d: name='%s' type=%d width=%d draw=%s" % [
			i, ce.get_gutter_name(i), ce.get_gutter_type(i),
			ce.get_gutter_width(i), ce.is_gutter_drawn(i)])

	print("")
	print("  line_folding: %s" % ce.is_line_folding_enabled())
	print("  gutters_draw_fold_gutter: %s" % ce.is_drawing_fold_gutter())

	# Check fold still works
	ce.text = "Sub Main()\n\tDim x As Integer\n\tx = 1\nEnd Sub"
	print("")
	print("  can_fold_line(0): %s" % ce.can_fold_line(0))

	quit()
