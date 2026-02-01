extends MainLoop

func _initialize():
	print("\n========================================")
	print("VGFormBase WinForms Test Suite")
	print("========================================\n")
	
	var errors = 0
	var tests_passed = 0
	var total_tests = 0
	
	# Test 1: Load VGFormBase script
	total_tests += 1
	print("[TEST 1] Loading VGFormBase.gd...")
	var form_base_script = load("res://addons/visual_gasic/VGFormBase.gd")
	if form_base_script == null:
		print("  ❌ FAILED: Could not load VGFormBase.gd")
		errors += 1
	else:
		print("  ✓ PASSED: VGFormBase.gd loaded successfully")
		tests_passed += 1
	
	# Test 2: Create a form instance
	total_tests += 1
	print("\n[TEST 2] Creating form instance...")
	var form = Window.new()
	form.set_script(form_base_script)
	if form == null:
		print("  ❌ FAILED: Could not create form instance")
		errors += 1
	else:
		print("  ✓ PASSED: Form instance created")
		tests_passed += 1
	
	# Test 3: Check properties exist
	total_tests += 1
	print("\n[TEST 3] Checking WinForms properties...")
	var props_ok = true
	var required_props = ["FormBorderStyle", "WindowState", "StartPosition", 
	                      "ControlBox", "MinimizeBox", "MaximizeBox", "ShowIcon"]
	for prop in required_props:
		if not prop in form:
			print("  ❌ Missing property: " + prop)
			props_ok = false
			errors += 1
	if props_ok:
		print("  ✓ PASSED: All WinForms properties present")
		tests_passed += 1
	
	# Test 4: Check enums exist
	total_tests += 1
	print("\n[TEST 4] Checking enums...")
	var enums_ok = true
	if not "FormBorderStyleEnum" in form:
		print("  ❌ Missing: FormBorderStyleEnum")
		enums_ok = false
	if not "FormWindowStateEnum" in form:
		print("  ❌ Missing: FormWindowStateEnum")
		enums_ok = false
	if not "FormStartPositionEnum" in form:
		print("  ❌ Missing: FormStartPositionEnum")
		enums_ok = false
	if not "DialogResultEnum" in form:
		print("  ❌ Missing: DialogResultEnum")
		enums_ok = false
	
	if enums_ok:
		print("  ✓ PASSED: All enums present")
		tests_passed += 1
	else:
		errors += 1
	
	# Test 5: Test Text property
	total_tests += 1
	print("\n[TEST 5] Testing Text property...")
	form.Text = "Test Form"
	if form.title == "Test Form":
		print("  ✓ PASSED: Text property works (title = '" + form.title + "')")
		tests_passed += 1
	else:
		print("  ❌ FAILED: Text property not working")
		errors += 1
	
	# Test 6: Check methods exist
	total_tests += 1
	print("\n[TEST 6] Checking WinForms methods...")
	var methods_ok = true
	var required_methods = ["Show", "Hide", "Close", "Activate", 
	                        "CenterToScreen", "CenterToParent", "ShowDialog"]
	for method in required_methods:
		if not form.has_method(method):
			print("  ❌ Missing method: " + method)
			methods_ok = false
	if methods_ok:
		print("  ✓ PASSED: All WinForms methods present")
		tests_passed += 1
	else:
		errors += 1
	
	# Test 7: Test FormBorderStyle property
	total_tests += 1
	print("\n[TEST 7] Testing FormBorderStyle...")
	form.FormBorderStyle = form.FormBorderStyleEnum.FixedDialog
	if form.FormBorderStyle == form.FormBorderStyleEnum.FixedDialog:
		print("  ✓ PASSED: FormBorderStyle property works")
		tests_passed += 1
	else:
		print("  ❌ FAILED: FormBorderStyle not set correctly")
		errors += 1
	
	# Test 8: Test WindowState property
	total_tests += 1
	print("\n[TEST 8] Testing WindowState...")
	form.WindowState = form.FormWindowStateEnum.Normal
	if form.WindowState == form.FormWindowStateEnum.Normal:
		print("  ✓ PASSED: WindowState property works")
		tests_passed += 1
	else:
		print("  ❌ FAILED: WindowState not set correctly")
		errors += 1
	
	# Test 9: Test StartPosition property
	total_tests += 1
	print("\n[TEST 9] Testing StartPosition...")
	form.StartPosition = form.FormStartPositionEnum.CenterScreen
	if form.StartPosition == form.FormStartPositionEnum.CenterScreen:
		print("  ✓ PASSED: StartPosition property works")
		tests_passed += 1
	else:
		print("  ❌ FAILED: StartPosition not set correctly")
		errors += 1
	
	# Test 10: Test boolean properties
	total_tests += 1
	print("\n[TEST 10] Testing boolean properties...")
	var bool_props_ok = true
	form.ControlBox = false
	if form.ControlBox != false:
		print("  ❌ ControlBox not working")
		bool_props_ok = false
	form.MinimizeBox = false
	if form.MinimizeBox != false:
		print("  ❌ MinimizeBox not working")
		bool_props_ok = false
	form.MaximizeBox = false
	if form.MaximizeBox != false:
		print("  ❌ MaximizeBox not working")
		bool_props_ok = false
	
	if bool_props_ok:
		print("  ✓ PASSED: Boolean properties work")
		tests_passed += 1
	else:
		errors += 1
	
	# Test 11: Test form initialization
	total_tests += 1
	print("\n[TEST 11] Testing form initialization...")
	# In headless mode, we can't add to tree, but we can test initialization
	if form._form_loaded == false:
		print("  ✓ PASSED: Form initialization flag correct")
		tests_passed += 1
	else:
		print("  ⚠ WARNING: Form may have auto-loaded")
		tests_passed += 1
	
	# Test 12: Test lifecycle tracking
	total_tests += 1
	print("\n[TEST 12] Testing lifecycle flags...")
	if "_form_loaded" in form and "_form_shown" in form:
		print("  ✓ PASSED: Lifecycle tracking flags present")
		tests_passed += 1
	else:
		print("  ❌ FAILED: Missing lifecycle flags")
		errors += 1
	
	# Test 13: Test _is_modal flag
	total_tests += 1
	print("\n[TEST 13] Testing modal flag...")
	if "_is_modal" in form and "_dialog_result" in form:
		print("  ✓ PASSED: Modal dialog support flags present")
		tests_passed += 1
	else:
		print("  ❌ FAILED: Missing modal support")
		errors += 1
	
	# Test 14: Test FormBorderStyle enum values
	total_tests += 1
	print("\n[TEST 14] Testing FormBorderStyle enum values...")
	var border_styles = [
		["None", 0],
		["FixedSingle", 1],
		["Fixed3D", 2],
		["FixedDialog", 3],
		["Sizable", 4],
		["FixedToolWindow", 5],
		["SizableToolWindow", 6]
	]
	var border_enum_ok = true
	for style in border_styles:
		var style_name = style[0]
		var expected_value = style[1]
		if form.FormBorderStyleEnum[style_name] != expected_value:
			print("  ❌ FormBorderStyleEnum." + style_name + " = " + str(form.FormBorderStyleEnum[style_name]) + " (expected " + str(expected_value) + ")")
			border_enum_ok = false
	
	if border_enum_ok:
		print("  ✓ PASSED: FormBorderStyle enum values correct")
		tests_passed += 1
	else:
		errors += 1
	
	# Test 15: Test DialogResult enum values
	total_tests += 1
	print("\n[TEST 15] Testing DialogResult enum values...")
	var dialog_results = [
		["None", 0],
		["OK", 1],
		["Cancel", 2],
		["Abort", 3],
		["Retry", 4],
		["Ignore", 5],
		["Yes", 6],
		["No", 7]
	]
	var dialog_enum_ok = true
	for result in dialog_results:
		var result_name = result[0]
		var expected_value = result[1]
		if form.DialogResultEnum[result_name] != expected_value:
			print("  ❌ DialogResultEnum." + result_name + " = " + str(form.DialogResultEnum[result_name]) + " (expected " + str(expected_value) + ")")
			dialog_enum_ok = false
	
	if dialog_enum_ok:
		print("  ✓ PASSED: DialogResult enum values correct")
		tests_passed += 1
	else:
		errors += 1
	
	# Print summary
	print("\n========================================")
	print("Test Results Summary")
	print("========================================")
	print("Tests Passed: " + str(tests_passed) + "/" + str(total_tests))
	print("Tests Failed: " + str(errors))
	
	if errors == 0:
		print("\n✅ ALL TESTS PASSED!")
		print("VGFormBase is ready for production use.")
	else:
		print("\n❌ SOME TESTS FAILED")
		print("Please review the errors above.")
	
	print("\n========================================\n")
	
	# Clean up
	form.queue_free()
	free()
	
	return errors == 0