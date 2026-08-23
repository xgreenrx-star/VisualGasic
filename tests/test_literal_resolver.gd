@tool
extends SceneTree
## Headless tests for vg_literal_resolver.gd

const Resolver := preload("res://addons/visual_gasic/vg_literal_resolver.gd")

var _failed := 0
var _passed := 0


func _init() -> void:
	print("=== literal_resolver headless tests ===")
	print("")
	_test_decimal_at_caret()
	_test_hex_vb()
	_test_hex_c()
	_test_octal()
	_test_binary_vb()
	_test_conversions_binary_source()
	_test_date_literal()
	_test_no_string_false_positive()
	_test_true_literal()
	_test_conversions_decimal_10()
	_test_conversions_hex_a()
	_finish()


func _test_decimal_at_caret() -> void:
	print("-- decimal literal --")
	var line := "Dim score As Integer = 10"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 27)
	_check("resolves", not lit.is_empty())
	_check("kind integer", lit.get("kind") == "integer")
	_check("value 10", int(lit.get("value_i64", -1)) == 10)
	_check("source text", lit.get("source_text") == "10")
	_check("radix decimal", lit.get("source_radix") == "decimal")


func _test_hex_vb() -> void:
	print("-- hex vb6 literal --")
	var line := "flags = flags Or &H10"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 20)
	_check("resolves &H10", not lit.is_empty())
	_check("value 16", int(lit.get("value_i64", -1)) == 16)
	_check("radix hex_vb", lit.get("source_radix") == "hex_vb")


func _test_hex_c() -> void:
	print("-- 0x literal --")
	var line := "Dim mask = 0xFF"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 14)
	_check("resolves 0xFF", not lit.is_empty())
	_check("value 255", int(lit.get("value_i64", -1)) == 255)
	_check("radix hex_c", lit.get("source_radix") == "hex_c")


func _test_octal() -> void:
	print("-- octal literal --")
	var line := "Dim x = &O12"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 11)
	_check("resolves &O12", not lit.is_empty())
	_check("value 10", int(lit.get("value_i64", -1)) == 10)
	_check("radix octal", lit.get("source_radix") == "octal")


func _test_binary_vb() -> void:
	print("-- binary literal --")
	var line := "Dim mask = &B1010"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 14)
	_check("resolves &B1010", not lit.is_empty())
	_check("value 10", int(lit.get("value_i64", -1)) == 10)
	_check("radix binary", lit.get("source_radix") == "binary")


func _test_conversions_binary_source() -> void:
	print("-- conversions for &B1010 --")
	var lit := {"kind": "integer", "value_i64": 10, "source_radix": "binary"}
	var rows: Array = Resolver.format_conversions(lit)
	var current := rows.filter(func(r): return r.get("is_current", false))
	_check("one current row", current.size() == 1)
	_check("current is binary", current[0].get("radix_id") == "binary")
	_check("binary text copyable", str(current[0].get("text", "")) == "&B1010")


func _test_date_literal() -> void:
	print("-- date literal --")
	var line := "Dim started = #1/15/2026#"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 18)
	_check("resolves date", not lit.is_empty())
	_check("kind date", lit.get("kind") == "date")
	_check("date body", lit.get("value_str") == "1/15/2026")


func _test_no_string_false_positive() -> void:
	print("-- string false positive --")
	var line := "Open \"10\" For Input As #1"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 7)
	_check("numeric in string ignored", lit.is_empty() or lit.get("kind") == "string")
	if not lit.is_empty() and lit.get("kind") == "string":
		_check("string kind at quote", int(lit.get("start", -1)) == 5)


func _test_true_literal() -> void:
	print("-- boolean literal --")
	var line := "Dim active = True"
	var lit := Resolver.resolve_at_caret(line + "\n", 0, 16)
	_check("resolves True", not lit.is_empty())
	_check("kind boolean", lit.get("kind") == "boolean")
	_check("value true", bool(lit.get("value_bool", false)) == true)


func _test_conversions_decimal_10() -> void:
	print("-- conversions for 10 --")
	var lit := {"kind": "integer", "value_i64": 10, "source_radix": "decimal"}
	var rows: Array = Resolver.format_conversions(lit)
	_check("has rows", rows.size() >= 5)
	var by_label := {}
	for r in rows:
		by_label[r.get("label", "")] = r
	_check("hex vb6 &HA", str(by_label.get("Hex (VB6)", {}).get("text", "")) == "&HA")
	_check("octal &O12", str(by_label.get("Octal", {}).get("text", "")) == "&O12")
	_check("binary &B1010", str(by_label.get("Binary", {}).get("text", "")) == "&B1010")
	_check("decimal current", bool(by_label.get("Decimal", {}).get("is_current", false)))


func _test_conversions_hex_a() -> void:
	print("-- conversions for &HA --")
	var lit := {"kind": "integer", "value_i64": 10, "source_radix": "hex_vb"}
	var rows: Array = Resolver.format_conversions(lit)
	var current := rows.filter(func(r): return r.get("is_current", false))
	_check("one current row", current.size() == 1)
	_check("current is hex vb6", current[0].get("radix_id") == "hex_vb")


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  OK  ", label)
	else:
		_failed += 1
		print("  FAIL", label)


func _finish() -> void:
	print("")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
