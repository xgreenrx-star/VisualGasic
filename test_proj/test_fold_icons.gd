extends SceneTree

func _init():
	var ce := VGCodeEdit.new()
	ce.name = "TestCE"
	root.add_child.call_deferred(ce)
	call_deferred("_frame2", ce)

func _frame2(ce: VGCodeEdit) -> void:
	call_deferred("_check", ce)

func _check(ce: VGCodeEdit) -> void:
	# Check what fold-related theme icons exist
	print("=== Fold theme icons ===")
	var icon_names := ["can_fold", "folded", "can_fold_code_region", "folded_code_region", "folded_eol_icon"]
	for n in icon_names:
		var has_it := ce.has_theme_icon(n)
		var has_override := ce.has_theme_icon_override(n)
		var icon = ce.get_theme_icon(n) if has_it else null
		print("  %s: has=%s override=%s icon=%s" % [n, has_it, has_override, icon])

	# Check fold theme colors
	print("")
	print("=== Fold theme colors ===")
	var color_names := ["code_folding_color", "folded_code_region_color"]
	for n in color_names:
		var has_it := ce.has_theme_color(n)
		var has_override := ce.has_theme_color_override(n)
		print("  %s: has=%s override=%s" % [n, has_it, has_override])
		if has_it:
			print("    value: %s" % ce.get_theme_color(n))

	# Check if any theme is assigned
	print("")
	print("  ce.theme: %s" % ce.theme)

	quit()
