extends SceneTree
## Headless unit test: VGNarceaLiveSession ring buffer + purge.

const SessionScript := preload("res://addons/visual_gasic/vg_narcea_live_session.gd")


func _init() -> void:
	var session = SessionScript.new()
	session.configure(2)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.RED)
	session.add_entry(img, {"file": "res://Main.vg", "line": 10})
	session.add_entry(img, {"file": "res://Main.vg", "line": 11})
	session.add_entry(img, {"file": "res://Main.vg", "line": 12})
	if session.entry_count() != 2:
		push_error("expected ring size 2, got %d" % session.entry_count())
		quit(1)
		return
	var summaries: Array = session.list_summaries()
	if summaries.size() != 2 or int(summaries[0].get("line", 0)) != 11:
		push_error("ring eviction order wrong")
		quit(1)
		return
	session.purge_all()
	if session.entry_count() != 0:
		push_error("purge_all failed")
		quit(1)
		return
	print("test_vg_narcea_live_session: OK")
	quit(0)
