extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var src = "res://test_demo.bas"
	var script = load(src)
	if not script:
		print("Failed to load demo script: " + src)
		quit()
		return

	# Use GasicForm so auto-wire logic runs in _ready
	var form = GasicForm.new()
	form.set_name("DemoRunner")
	form.set_script(script)

	# Instantiate fake bridge/helper nodes and add them as children of the form
	var demo_id = ""
	var f = FileAccess.open("res://demo/.current_demo", FileAccess.READ)
	if f:
		demo_id = f.get_as_text().strip_edges()
		f.close()
	var s = demo_id if demo_id != "" else src

	if s.find("ballistic") >= 0:
		var bb = load("res://ballistic_fake.gd").new()
		bb.name = "BallisticBridge"
		form.add_child(bb)
	if s.find("fancy_styleboxes") >= 0:
		var pd = load("res://panel_demo_fake.gd").new()
		pd.name = "PanelDemo"
		form.add_child(pd)
	if s.find("horror_survival") >= 0:
		var hb = load("res://horror_fake.gd").new()
		hb.name = "HorrorBridge"
		form.add_child(hb)
	if s.find("laser3d") >= 0:
		var lb = load("res://laser_fake.gd").new()
		lb.name = "LaserBridge"
		form.add_child(lb)
	if s.find("procedural3d") >= 0:
		var pb = load("res://procedural_fake.gd").new()
		pb.name = "ProceduralBridge"
		form.add_child(pb)
	if s.find("psx_visuals") >= 0:
		var pv = load("res://psx_fake.gd").new()
		pv.name = "PSXVisuals"
		form.add_child(pv)

	# Add form to scene tree, which triggers _ready and auto-wiring
	get_root().add_child(form)

	# Allow the form to run its _ready and Form_Load handlers
	await create_timer(0.05).timeout

	print("DEMO_RUNNER_DONE:" + src)
	form.queue_free()
	quit()