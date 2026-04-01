extends SceneTree

func _init():
	var ce := CodeEdit.new()
	root.add_child.call_deferred(ce)
	call_deferred("_check", ce)

func _check(ce: CodeEdit) -> void:
	# List all folding-related properties
	print("=== Fold-related properties on CodeEdit ===")
	for p in ce.get_property_list():
		var n: String = p["name"]
		if n.containsn("fold") or n.containsn("folding"):
			print("  %s = %s  (type %d)" % [n, str(ce.get(n)), p["type"]])

	# Check which setter methods exist
	print("")
	print("=== Method checks ===")
	print("  has set_line_folding_enabled: %s" % ce.has_method("set_line_folding_enabled"))
	print("  has is_line_folding_enabled:  %s" % ce.has_method("is_line_folding_enabled"))
	print("  has set_draw_fold_gutter:     %s" % ce.has_method("set_draw_fold_gutter"))
	print("  has is_drawing_fold_gutter:   %s" % ce.has_method("is_drawing_fold_gutter"))

	# Current state before any set() call
	if ce.has_method("is_line_folding_enabled"):
		print("")
		print("  DEFAULT is_line_folding_enabled() = %s" % ce.is_line_folding_enabled())

	# Try the property names used in our code
	print("")
	print("=== Testing set() calls ===")
	ce.set("line_folding_enabled", true)
	if ce.has_method("is_line_folding_enabled"):
		print("  After set('line_folding_enabled', true): %s" % ce.is_line_folding_enabled())

	ce.set("line_folding", true)
	if ce.has_method("is_line_folding_enabled"):
		print("  After set('line_folding', true):         %s" % ce.is_line_folding_enabled())

	# Now test can_fold_line with indented text
	ce.text = "Sub Main()\n\tDim x As Integer\n\tx = 1\nEnd Sub"
	print("")
	print("=== can_fold_line test (tabs, folding enabled) ===")
	for i in range(ce.get_line_count()):
		print("  Line %d: can_fold=%s  '%s'" % [i, ce.can_fold_line(i), ce.get_line(i)])

	# Try with spaces too
	ce.text = "Sub Main()\n    Dim x As Integer\n    x = 1\nEnd Sub"
	print("")
	print("=== can_fold_line test (4 spaces, folding enabled) ===")
	for i in range(ce.get_line_count()):
		print("  Line %d: can_fold=%s  '%s'" % [i, ce.can_fold_line(i), ce.get_line(i)])

	# Try disabling and re-enabling
	if ce.has_method("set_line_folding_enabled"):
		ce.set_line_folding_enabled(false)
		print("")
		print("=== After set_line_folding_enabled(false) ===")
		print("  Line 0 can_fold: %s" % ce.can_fold_line(0))
		ce.set_line_folding_enabled(true)
		print("  Re-enabled, Line 0 can_fold: %s" % ce.can_fold_line(0))

	quit()
