extends SceneTree

func _init() -> void:
	var s = load("res://addons/visual_gasic/vg_formatter.gd")
	if s == null:
		push_error("load failed")
	else:
		print("ok ", s)
	quit()
