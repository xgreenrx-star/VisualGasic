extends SceneTree

func _init():
	var ce := VGCodeEdit.new()
	ce.name = "TestCE"
	root.add_child.call_deferred(ce)
	# Wait 2 frames so _ready() and deferred calls complete
	call_deferred("_frame2", ce)

func _frame2(ce: VGCodeEdit) -> void:
	call_deferred("_check", ce)

func _check(ce: VGCodeEdit) -> void:
	print("=== VGCodeEdit gutter state after _ready ===")
	print("  gutter_count: %d" % ce.get_gutter_count())
	for i in range(ce.get_gutter_count()):
		print("  gutter %d: name='%s' type=%d width=%d draw=%s" % [
			i, ce.get_gutter_name(i), ce.get_gutter_type(i),
			ce.get_gutter_width(i), ce.is_gutter_drawn(i)])

	print("")
	print("  line_folding:           %s" % ce.is_line_folding_enabled())
	print("  draw_fold_gutter:       %s" % ce.is_drawing_fold_gutter())
	print("  draw_line_numbers:      %s" % ce.gutters_draw_line_numbers)
	print("  draw_breakpoints:       %s" % ce.gutters_draw_breakpoints_gutter)
	print("  indent_automatic:       %s" % ce.indent_automatic)
	print("  indent_size:            %d" % ce.indent_size)

	ce.text = "Private Sub Form_Load()\n\tDim x As Integer\n\tx = 1\nEnd Sub\n\nPublic Sub Main()\n\tMsgBox \"Hi\"\nEnd Sub"
	print("")
	print("=== can_fold_line for each line ===")
	for i in range(ce.get_line_count()):
		print("  Line %d: can_fold=%s  folded=%s  '%s'" % [
			i, ce.can_fold_line(i), ce.is_line_folded(i), ce.get_line(i)])

	print("")
	print("=== Fold then check ===")
	ce.fold_all_procedures()
	for i in range(ce.get_line_count()):
		if ce.is_line_folded(i):
			print("  Line %d is FOLDED: '%s'" % [i, ce.get_line(i)])

	quit()
