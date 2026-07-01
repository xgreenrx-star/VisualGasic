@tool
extends SceneTree

## Critical regression test: verify VGComboBox popup (_item_list / _popup_list)
## is actually populated — not just _data. The previous tests only checked
## item_count which reads _data.size(), missing the case where _item_list
## was null during add_item() calls.
##
## Also verifies that interactive signals (arrow button, popup item_clicked)
## are connected unconditionally — previously they were gated by
## `if not Engine.is_editor_hint():` which broke the Code Navigator in editor.

const PASS = "[PASS]"
const FAIL = "[FAIL]"

var _failures: int = 0

func _init():
	print("=== VGComboBox popup population test ===")
	print("  Engine.is_editor_hint() = ", Engine.is_editor_hint())

	var vg_script = load("res://addons/visual_gasic/vg_combo_box.gd")
	_assert("vg_combo_box.gd loads", vg_script != null)
	if vg_script == null:
		quit(1); return

	# Add to a real scene so _ready() fires
	var root_ctrl = Control.new()
	get_root().add_child(root_ctrl)
	var cb = vg_script.new()
	root_ctrl.add_child(cb)

	# In SceneTree -s mode, _ready() may be deferred. Force _build_ui directly
	# if it hasn't run yet (guard: _line_edit is null means not built).
	if cb._line_edit == null or not is_instance_valid(cb._line_edit):
		cb._build_ui()
		cb._apply_style()

	_assert("_line_edit created",  cb._line_edit != null)
	_assert("_arrow_btn created",  cb._arrow_btn != null)
	_assert("_popup_list created", cb._popup_list != null)

	# ---- 1. Basic add/clear syncs _popup_list ----
	print("\n--- Test 1: add_item syncs _popup_list ---")
	cb.clear()
	cb.add_item("Alpha")
	cb.add_item("Beta")
	cb.add_item("Gamma")
	print("  _data.size()       = ", cb.item_count)
	print("  _popup_list.count  = ", cb._popup_list.item_count)
	_assert("_data has 3 items",           cb.item_count == 3)
	_assert("_popup_list has 3 items",     cb._popup_list.item_count == 3)
	_assert("_popup_list[0] = Alpha",      cb._popup_list.get_item_text(0) == "Alpha")
	_assert("_popup_list[2] = Gamma",      cb._popup_list.get_item_text(2) == "Gamma")

	# ---- 2. Arrow button signal IS connected ----
	print("\n--- Test 2: arrow button signal connected (was broken by in_editor guard) ---")
	var arrow_conns: int = cb._arrow_btn.pressed.get_connections().size()
	print("  _arrow_btn.pressed connections = ", arrow_conns)
	_assert("_arrow_btn.pressed signal has connections (fixes editor mode bug)",
		arrow_conns > 0)

	# ---- 3. Popup item_clicked and item_activated signals ARE connected ----
	print("\n--- Test 3: popup signals connected ---")
	var clicked_conns: int = cb._popup_list.item_clicked.get_connections().size()
	var activated_conns: int = cb._popup_list.item_activated.get_connections().size()
	print("  item_clicked connections    = ", clicked_conns)
	print("  item_activated connections  = ", activated_conns)
	_assert("_popup_list.item_clicked connected",   clicked_conns > 0)
	_assert("_popup_list.item_activated connected", activated_conns > 0)

	# ---- 4. _commit_selection emits item_selected ----
	print("\n--- Test 4: _commit_selection emits item_selected ---")
	# Use array to capture result — GDScript lambdas capture local vars by value
	var result := [-99]
	cb.item_selected.connect(func(i: int) -> void: result[0] = i)
	cb._commit_selection(1)
	print("  result[0] = ", result[0])
	_assert("item_selected emitted with idx=1", result[0] == 1)

	# ---- 5. select() does NOT emit item_selected ----
	print("\n--- Test 5: programmatic select() does NOT emit ---")
	result[0] = -99
	cb.select(0)
	_assert("select(0) did NOT emit item_selected", result[0] == -99)

	# ---- 6. clear() empties both _data and _popup_list ----
	print("\n--- Test 6: clear empties _data and _popup_list ---")
	cb.clear()
	_assert("_data empty after clear",        cb.item_count == 0)
	_assert("_popup_list empty after clear",  cb._popup_list.item_count == 0)

	# ---- 7. metadata round-trips correctly ----
	print("\n--- Test 7: metadata round-trips ---")
	cb.clear()
	cb.add_item("(Declarations)")
	cb.set_item_metadata(0, {"type": "declarations"})
	cb.add_item("_Ready")
	cb.set_item_metadata(1, {"type": "procedure", "line": 17, "name": "_Ready"})
	_assert("item 0 metadata type = declarations",
		cb.get_item_metadata(0).get("type", "") == "declarations")
	_assert("item 1 metadata name = _Ready",
		cb.get_item_metadata(1).get("name", "") == "_Ready")
	_assert("_popup_list has 2 items after metadata setup",
		cb._popup_list.item_count == 2)

	# ---- Summary ----
	print("")
	if _failures == 0:
		print(PASS + " All tests passed.")
		quit(0)
	else:
		print(FAIL + " " + str(_failures) + " test(s) failed.")
		quit(1)


func _assert(label: String, condition: bool) -> void:
	if condition:
		print(PASS + " " + label)
	else:
		printerr(FAIL + " " + label)
		_failures += 1
