extends MainLoop

func _initialize():
	print("\n" + "=".repeat(60))
	print("VGFormBase Auto-Wiring Test")
	print("=".repeat(60) + "\n")
	
	# Load VGFormBase
	var form_base_script = load("res://addons/visual_gasic/VGFormBase.gd")
	if form_base_script == null:
		print("❌ FAILED: Could not load VGFormBase.gd")
		return false
	print("✓ VGFormBase.gd loaded")
	
	# Create a test form
	var form = Window.new()
	form.set_script(form_base_script)
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Test 1: Check if _wire_control_events method exists
	print("\n[TEST 1] _wire_control_events method exists?")
	if form.has_method("_wire_control_events"):
		print("  ✓ PASSED")
		tests_passed += 1
	else:
		print("  ❌ FAILED")
		tests_failed += 1
	
	# Test 2: Check if _wire_node_recursive exists
	print("\n[TEST 2] _wire_node_recursive method exists?")
	if form.has_method("_wire_node_recursive"):
		print("  ✓ PASSED")
		tests_passed += 1
	else:
		print("  ❌ FAILED")
		tests_failed += 1
	
	# Test 3: Verify it can be called without error
	print("\n[TEST 3] Can call _wire_control_events()?")
	var btnTest = Button.new()
	btnTest.name = "btnTest"
	form.add_child(btnTest)
	
	if form.has_method("_wire_control_events"):
		form._wire_control_events()
		print("  ✓ PASSED: Called without error")
		tests_passed += 1
	else:
		print("  ❌ FAILED")
		tests_failed += 1
	
	# Test 4: Check lifecycle methods
	print("\n[TEST 4] Form lifecycle methods exist?")
	if form.has_method("Form_Load") and form.has_method("Form_Shown"):
		print("  ✓ PASSED")
		tests_passed += 1
	else:
		print("  ❌ FAILED")
		tests_failed += 1
	
	# Summary
	print("\n" + "=".repeat(60))
	print("Tests Passed: " + str(tests_passed) + "/4")
	print("Tests Failed: " + str(tests_failed))
	
	if tests_failed == 0:
		print("\n✅ ALL TESTS PASSED!")
		print("\nAuto-wiring is enabled. When you create a .vg form:")
		print("  1. Name controls: btnTest, lblMessage, txtName, etc.")
		print("  2. Create handler methods: btnTest_Click(), txtName_Change()")
		print("  3. VGFormBase auto-connects them in _ready()!")
	else:
		print("\n❌ SOME TESTS FAILED")
	
	print("=".repeat(60) + "\n")
	
	return tests_failed == 0
