extends SceneTree
# GDScript call() into a VG constant Return, and into a function that writes.

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)

func run() -> void:
	var n := Node.new()
	n.set_script(load("res://test_suite/test_ext_leaf.vg"))
	root.add_child(n)
	await process_frame
	for i in 4:
		n.call("Zero")
		n.call("Answer")
	check(int(n.call("Zero")) == 0, "external zero")
	check(int(n.call("Answer")) == 7, "external answer")
	# _Ready already called Bump once.
	check(int(n.call("Bump")) == 2, "external bump")
	check(int(n.call("Bump")) == 3, "external bump again")
	check(int(n.call("ReadBumps")) == 3, "external bumps")
	check(int(n.call("AddOne", 4)) == 5, "external argument")
	quit()
