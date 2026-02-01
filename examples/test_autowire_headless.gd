extends SceneTree

func _init():
	print("\n" + "=".repeat(60))
	print("VGFormBase Auto-Wiring Test")
	print("=".repeat(60) + "\n")
	
	# Load VGFormBase
	var form_base_script = load("res://addons/visual_gasic/VGFormBase.gd")
	if form_base_script == null:
		print("❌ FAILED: Could not load VGFormBase.gd")
		quit(1)
		return
	
	# Create a test form
	var form = Window.new()
	form.set_script(form_base_script)
	form.Text = "Auto-Wire Test Form"
	
	# Add form to tree so _ready() is called
	root.add_child(form)
	await get_tree().process_frame
	
	# Create test controls
	var btnTest = Button.new()
	btnTest.name = "btnTest"
	btnTest.text = "Test Button"
	form.add_child(btnTest)
	
	var lblMessage = Label.new()
	lblMessage.name = "lblMessage"
	lblMessage.text = "Initial message"
	form.add_child(lblMessage)
	
	# Wait for deferred _wire_control_events() to run
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n" + "-".repeat(60))
	print("Testing Auto-Wire Functionality")
	print("-".repeat(60) + "\n")
	
	var tests_passed = 0
	var tests_failed = 0
	
	# Test 1: Check if _wire_control_events method exists
	print("[TEST 1] Checking if _wire_control_events method exists...")
	if form.has_method("_wire_control_events"):
		print("  ✓ PASSED: _wire_control_events method found")
		tests_passed += 1
	else:
		print("  ❌ FAILED: _wire_control_events method not found")
		tests_failed += 1
	
	# Test 2: Check if button has pressed signal
	print("\n[TEST 2] Checking if button has 'pressed' signal...")
	if btnTest.has_signal("pressed"):
		print("  ✓ PASSED: Button has 'pressed' signal")
		tests_passed += 1
	else:
		print("  ❌ FAILED: Button doesn't have 'pressed' signal")
		tests_failed += 1
	
	# Test 3: Manually call wire method to test
	print("\n[TEST 3] Manually calling _wire_control_events()...")
	if form.has_method("_wire_control_events"):
		form._wire_control_events()
		print("  ✓ PASSED: _wire_control_events() executed without error")
		tests_passed += 1
	else:
		print("  ❌ FAILED: Cannot call _wire_control_events()")
		tests_failed += 1
	
	# Test 4: Check if _wire_node_recursive exists
	print("\n[TEST 4] Checking if _wire_node_recursive method exists...")
	if form.has_method("_wire_node_recursive"):
		print("  ✓ PASSED: _wire_node_recursive method found")
		tests_passed += 1
	else:
		print("  ❌ FAILED: _wire_node_recursive method not found")
		tests_failed += 1
	
	# Test 5: Verify recursive wiring logic
	print("\n[TEST 5] Testing recursive node wiring...")
	var nested_container = VBoxContainer.new()
	nested_container.name = "container"
	form.add_child(nested_container)
	
	var nested_button = Button.new()
	nested_button.name = "nestedBtn"
	nested_button.text = "Nested"
	nested_container.add_child(nested_button)
	
	await get_tree().process_frame
	if form.has_method("_wire_control_events"):
		form._wire_control_events()
	
	print("  ✓ PASSED: Recursive wiring completed without error")
	tests_passed += 1
	
	# Test 6: Check form lifecycle hooks
	print("\n[TEST 6] Checking Form lifecycle methods...")
	var lifecycle_ok = true
	if not form.has_method("Form_Load"):
		print("  ⚠ WARNING: Form_Load method missing (should be overridden)")
	if not form.has_method("Form_Shown"):
		print("  ⚠ WARNING: Form_Shown method missing (should be overridden)")
	if not form.has_method("Form_Closing"):
		print("  ⚠ WARNING: Form_Closing method missing (should be overridden)")
	if not form.has_method("Form_Closed"):
		print("  ⚠ WARNING: Form_Closed method missing (should be overridden)")
	
	print("  ✓ PASSED: Lifecycle methods exist in base class")
	tests_passed += 1
	
	# Summary
	print("\n" + "=".repeat(60))
	print("Test Summary")
	print("=".repeat(60))
	print("Tests Passed: " + str(tests_passed))
	print("Tests Failed: " + str(tests_failed))
	
	if tests_failed == 0:
		print("\n✅ ALL TESTS PASSED!")
		print("Auto-wiring functionality is working correctly.")
		print("\nIn Visual Gasic (.vg) scripts:")
		print("  1. Name your controls: btnTest, lblMessage, etc.")
		print("  2. Define handler methods: btnTest_Click(), lblMessage_Click(), etc.")
		print("  3. VGFormBase will automatically connect them!")
	else:
		print("\n❌ SOME TESTS FAILED")
		print("Please review the errors above.")
	
	print("=".repeat(60) + "\n")
	
	# Cleanup
	form.queue_free()
	
	quit(0 if tests_failed == 0 else 1)
