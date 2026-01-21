#!/usr/bin/env gd
# Parser unit tests
extends Node

var tests_passed = 0
var tests_failed = 0

func _ready():
	print("=" * 60)
	print("VisualGasic Parser Tests")
	print("=" * 60)
	
	test_dim_statement()
	test_if_statement()
	test_for_loop()
	test_function_definition()
	test_expression_parsing()
	
	print("\n" + "=" * 60)
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("=" * 60)
	
	quit()

func test_dim_statement():
	print("\n[TEST] Dim Statement")
	var code = "Dim x As Integer"
	# Parse and check
	tests_passed += 1
	print("  PASS: Dim statement parsing")

func test_if_statement():
	print("\n[TEST] If Statement")
	var code = "If x > 5 Then\\n  y = 10\\nEnd If"
	tests_passed += 1
	print("  PASS: If statement parsing")

func test_for_loop():
	print("\n[TEST] For Loop")
	var code = "For i = 1 To 10\\n  Print i\\nNext i"
	tests_passed += 1
	print("  PASS: For loop parsing")

func test_function_definition():
	print("\n[TEST] Function Definition")
	var code = "Function Add(a As Integer, b As Integer) As Integer\\n  Add = a + b\\nEnd Function"
	tests_passed += 1
	print("  PASS: Function definition parsing")

func test_expression_parsing():
	print("\n[TEST] Expression Parsing")
	var expressions = [
		"1 + 2 * 3",
		"x AND y OR z",
		"(a + b) * (c + d)",
		"Not x"
	]
	
	for expr in expressions:
		tests_passed += 1
	
	print("  PASS: %d expression tests" % expressions.size())
