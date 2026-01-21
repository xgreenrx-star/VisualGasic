#!/usr/bin/env gd
# Tokenizer unit tests
extends Node

var tokenizer = VisualGasicTokenizer.new()
var tests_passed = 0
var tests_failed = 0

func _ready():
	print("=" * 60)
	print("VisualGasic Tokenizer Tests")
	print("=" * 60)
	
	test_keywords()
	test_literals()
	test_operators()
	test_strings()
	test_comments()
	test_complex_expressions()
	
	print("\n" + "=" * 60)
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("=" * 60)
	
	quit()

func test_keywords():
	print("\n[TEST] Keywords")
	var code = "Sub Function If Then Else While For Next"
	var tokens = tokenizer.tokenize(code)
	
	assert_token_type(tokens[0], "Keyword", "Sub")
	assert_token_type(tokens[1], "Keyword", "Function")
	assert_token_type(tokens[2], "Keyword", "If")

func test_literals():
	print("\n[TEST] Literals")
	var code = '123 45.67 "hello"'
	var tokens = tokenizer.tokenize(code)
	
	assert_token_type(tokens[0], "Integer", "123")
	assert_token_type(tokens[1], "Float", "45.67")
	assert_token_type(tokens[2], "String", '"hello"')

func test_operators():
	print("\n[TEST] Operators")
	var code = "+ - * / = < > <= >= <>"
	var tokens = tokenizer.tokenize(code)
	
	assert_token_count(tokens, 9, "operators")

func test_strings():
	print("\n[TEST] Strings")
	var code = '"simple string" "with spaces" "with\nnewline"'
	var tokens = tokenizer.tokenize(code)
	
	assert_token_type(tokens[0], "String", '"simple string"')

func test_comments():
	print("\n[TEST] Comments")
	var code = "Dim x ' This is a comment"
	var tokens = tokenizer.tokenize(code)
	
	# Should contain keyword and comment, not the comment text
	assert_token_count_at_most(tokens, 3, "with comment")

func test_complex_expressions():
	print("\n[TEST] Complex Expressions")
	var code = "x = y + z * 2"
	var tokens = tokenizer.tokenize(code)
	
	assert_token_count(tokens, 7, "in expression")

func assert_token_type(token, expected_type: String, expected_value: String = ""):
	var type_name = token.get("type", "Unknown")
	if type_name != expected_type:
		tests_failed += 1
		print("  FAIL: Expected type %s, got %s" % [expected_type, type_name])
		return
	
	if expected_value != "" and token.get("value") != expected_value:
		tests_failed += 1
		print("  FAIL: Expected value '%s', got '%s'" % [expected_value, token.get("value")])
		return
	
	tests_passed += 1
	print("  PASS: %s token '%s'" % [expected_type, expected_value if expected_value else token.get("value")])

func assert_token_count(tokens: Array, expected: int, description: String):
	if tokens.size() != expected:
		tests_failed += 1
		print("  FAIL: Expected %d tokens for %s, got %d" % [expected, description, tokens.size()])
		return
	
	tests_passed += 1
	print("  PASS: Got %d tokens for %s" % [expected, description])

func assert_token_count_at_most(tokens: Array, max_count: int, description: String):
	if tokens.size() > max_count:
		tests_failed += 1
		print("  FAIL: Expected at most %d tokens for %s, got %d" % [max_count, description, tokens.size()])
		return
	
	tests_passed += 1
	print("  PASS: Got %d tokens for %s (max %d)" % [tokens.size(), description, max_count])
