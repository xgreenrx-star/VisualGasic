extends SceneTree
func _init():
	var packed = ResourceLoader.load("res://Form4.tscn", "PackedScene")
	var instance = packed.instantiate()
	root.add_child(instance)

	# Check if _FormBackground has our script
	var fb = instance.get_node_or_null("_FormBackground")
	print("_FormBackground exists: ", fb != null)
	print("_FormBackground type: ", fb.get_class() if fb else "N/A")
	print("_FormBackground script: ", fb.get_script() if fb else "N/A")
	if fb and fb.get_script():
		print("Script path: ", fb.get_script().resource_path)

	# Check parent from _FormBackground's perspective
	if fb:
		var parent = fb.get_parent()
		print("Parent class: ", parent.get_class() if parent else "null")
		print("Parent is Window: ", parent is Window)
		print("Parent theme: ", parent.theme)

	# Check if the static function exists
	if fb and fb.has_method("_build_vb6_classic_theme"):
		print("Has _build_vb6_classic_theme: YES")
	else:
		print("Has _build_vb6_classic_theme: NO")

	# Try applying directly
	print("\n--- Applying theme manually ---")
	var t = Theme.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1)
	t.set_stylebox("normal", "LineEdit", sb)
	instance.theme = t
	print("After manual apply, theme: ", instance.theme)
	print("Has LineEdit/normal: ", instance.theme.has_stylebox("normal", "LineEdit"))

	instance.queue_free()
	quit()
