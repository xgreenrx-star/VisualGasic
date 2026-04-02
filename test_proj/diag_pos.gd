@tool
extends EditorScript

## Quick diagnostic — run from Script Editor > File > Run (Ctrl-Shift-X)
## Prints the column→pixel mapping for a CodeEdit with tab-indented text.

func _run():
	var ce := CodeEdit.new()
	ce.indent_use_spaces = false
	ce.indent_size = 4
	ce.size = Vector2(800, 400)
	EditorInterface.get_base_control().add_child(ce)
	
	ce.text = "\ta = (12 * (22 - 1 + (2) - 1) + 2)\n\t\ta = a + 2\nno_tab_line a = 1"
	
	# Wait for layout
	await ce.get_tree().process_frame
	await ce.get_tree().process_frame
	
	print("=== DIAGNOSTIC: get_pos_at_line_column mapping ===")
	for line_idx in range(ce.get_line_count()):
		var line_text := ce.get_line(line_idx)
		print("\n--- Line %d: '%s' ---" % [line_idx, line_text.c_escape()])
		for col in range(mini(line_text.length() + 1, 20)):
			var pos := ce.get_pos_at_line_column(line_idx, col)
			var rect := ce.get_rect_at_line_column(line_idx, col)
			var ch := ""
			if col < line_text.length():
				ch = line_text[col]
				if ch == "\t":
					ch = "TAB"
			else:
				ch = "EOL"
			print("  col=%2d '%s'  pos=(%4d,%4d)  rect=(%4d,%4d,%4d,%4d)" % [
				col, ch, pos.x, pos.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y
			])
	
	ce.queue_free()
	print("\n=== END DIAGNOSTIC ===")
