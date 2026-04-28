@tool
extends SceneTree
##
## Tests for VGAssetBus, VGContextBroker, VGPluginRegistry.
##
## Run from project root:
##   cd test_proj && ../Godot_v4.6.1-stable_linux.x86_64 --headless --script \
##       res://addons/visual_gasic/../../tests/test_vg_routing.gd
##
## Or simpler — copy this file into test_proj/ and:
##   cd test_proj && ../Godot_v4.6.1-stable_linux.x86_64 --headless --script \
##       res://test_vg_routing.gd
##
## Each test prints "[PASS] name" or "[FAIL] name: reason" and the script
## exits with code 0 on full pass, 1 on any failure.

const _AssetBus := preload("res://addons/visual_gasic/vg_asset_bus.gd")
const _ContextBroker := preload("res://addons/visual_gasic/vg_context_broker.gd")
const _Registry := preload("res://addons/visual_gasic/vg_plugin_registry.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	print("=== VG Routing Tests ===")
	_test_assetbus_emit_and_subscribe()
	_test_assetbus_renamed_signature()
	_test_contextbroker_dedup()
	_test_contextbroker_selection_always_emits()
	_test_registry_register_and_find()
	_test_registry_priority_ordering()
	_test_registry_default_override()
	_test_registry_extension_routing()
	_test_registry_disabled_excluded()
	_test_registry_open_asset_calls_provider()
	_test_open_asset_routes_by_extension_among_competitors()
	_test_open_asset_user_default_overrides_priority()
	_test_open_asset_unknown_extension_returns_false()
	print("=== Done: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ─── Helpers ────────────────────────────────────────────────

func _ok(label: String) -> void:
	_passed += 1
	print("[PASS] " + label)


func _fail(label: String, reason: String) -> void:
	_failed += 1
	print("[FAIL] %s: %s" % [label, reason])


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, reason)


# ─── Bus tests ──────────────────────────────────────────────

func _test_assetbus_emit_and_subscribe() -> void:
	var bus = _AssetBus.get_instance()
	var captured := {"saw": false, "path": "", "by": ""}
	var cb := func(p: String, by: String):
		captured.saw = true
		captured.path = p
		captured.by = by
	bus.asset_saved.connect(cb)
	bus.emit_saved("res://foo.vg", "tester")
	bus.asset_saved.disconnect(cb)
	_expect("assetbus.emit_saved → subscriber",
		captured.saw and captured.path == "res://foo.vg" and captured.by == "tester",
		"captured=%s" % str(captured))


func _test_assetbus_renamed_signature() -> void:
	var bus = _AssetBus.get_instance()
	var captured := [false, "", "", ""]
	var cb := func(o: String, n: String, by: String):
		captured[0] = true
		captured[1] = o
		captured[2] = n
		captured[3] = by
	bus.asset_renamed.connect(cb)
	bus.emit_renamed("res://a.vg", "res://b.vg", "tester")
	bus.asset_renamed.disconnect(cb)
	_expect("assetbus.emit_renamed has 3-arg signature",
		captured[0] and captured[1] == "res://a.vg" and captured[2] == "res://b.vg" and captured[3] == "tester",
		"captured=%s" % str(captured))


# ─── Broker tests ───────────────────────────────────────────

func _test_contextbroker_dedup() -> void:
	var broker = _ContextBroker.get_instance()
	var emit_count := [0]
	var cb := func(_kind: String, _value):
		emit_count[0] += 1
	broker.context_changed.connect(cb)
	# Reset to a known value first.
	broker.set_current_asset("res://x.vg", "tester")
	emit_count[0] = 0
	# Same value twice — should dedup to a single (or zero) emission.
	broker.set_current_asset("res://x.vg", "tester")
	broker.set_current_asset("res://x.vg", "tester")
	# Now a real change.
	broker.set_current_asset("res://y.vg", "tester")
	broker.context_changed.disconnect(cb)
	_expect("contextbroker.set_current_asset dedupes on equal value",
		emit_count[0] == 1,
		"emit_count=%d (expected 1: only the y.vg change)" % emit_count[0])


func _test_contextbroker_selection_always_emits() -> void:
	var broker = _ContextBroker.get_instance()
	var emit_count := [0]
	var cb := func(kind: String, _v):
		if kind == "selection":
			emit_count[0] += 1
	broker.context_changed.connect(cb)
	broker.set_selection(["a", "b"], "tester")
	broker.set_selection(["a", "b"], "tester")  # logically equal
	broker.context_changed.disconnect(cb)
	_expect("contextbroker.selection always emits (arrays mutate)",
		emit_count[0] == 2,
		"emit_count=%d (expected 2)" % emit_count[0])


# ─── Registry tests ─────────────────────────────────────────

func _make_meta(provides: Array, exts: Array, prio: int, enabled: bool = true) -> Dictionary:
	return {
		"name": "Test " + str(provides),
		"provides": provides,
		"handles_extensions": exts,
		"priority": prio,
		"enabled": enabled,
	}


func _test_registry_register_and_find() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_a")
	reg.register_provider("__t_a", _make_meta(["asset_editor.test"], ["t"], 50))
	var found := reg.find_providers("asset_editor.test")
	_expect("registry.register_provider + find_providers",
		"__t_a" in found,
		"found=%s" % str(found))
	reg.unregister_provider("__t_a")


func _test_registry_priority_ordering() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_low")
	reg.unregister_provider("__t_high")
	reg.register_provider("__t_low", _make_meta(["asset_editor.test"], ["t"], 5))
	reg.register_provider("__t_high", _make_meta(["asset_editor.test"], ["t"], 50))
	var found := reg.find_providers("asset_editor.test")
	_expect("registry.find_providers sorts priority desc",
		found.size() >= 2 and found[0] == "__t_high" and "__t_low" in found,
		"found=%s" % str(found))
	reg.unregister_provider("__t_low")
	reg.unregister_provider("__t_high")


func _test_registry_default_override() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_low")
	reg.unregister_provider("__t_high")
	reg.register_provider("__t_low", _make_meta(["asset_editor.test"], ["t"], 5))
	reg.register_provider("__t_high", _make_meta(["asset_editor.test"], ["t"], 50))
	# Without a default, get_default_for returns the highest priority.
	_expect("registry.get_default_for falls back to highest priority",
		reg.get_default_for("asset_editor.test") == "__t_high",
		"got=%s" % reg.get_default_for("asset_editor.test"))
	# User override pins low-priority provider.
	reg.set_default_for("asset_editor.test", "__t_low")
	_expect("registry.set_default_for pins user choice over priority",
		reg.get_default_for("asset_editor.test") == "__t_low",
		"got=%s" % reg.get_default_for("asset_editor.test"))
	reg.set_default_for("asset_editor.test", "")  # cleanup
	reg.unregister_provider("__t_low")
	reg.unregister_provider("__t_high")


func _test_registry_extension_routing() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_ext")
	reg.register_provider("__t_ext", _make_meta(["asset_editor.test"], ["zztest"], 50))
	var found := reg.find_providers_for_path("res://foo/bar.zztest")
	_expect("registry.find_providers_for_path matches extension",
		"__t_ext" in found,
		"found=%s" % str(found))
	# No match for a different extension.
	var none := reg.find_providers_for_path("res://foo/bar.txt")
	_expect("registry.find_providers_for_path rejects mismatched ext",
		not ("__t_ext" in none),
		"found=%s" % str(none))
	reg.unregister_provider("__t_ext")


func _test_registry_disabled_excluded() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_d")
	reg.register_provider("__t_d", _make_meta(["asset_editor.test"], ["t"], 50))
	reg.set_enabled("__t_d", false)
	var found := reg.find_providers("asset_editor.test")
	_expect("registry.find_providers excludes disabled providers",
		not ("__t_d" in found),
		"found=%s" % str(found))
	reg.unregister_provider("__t_d")


class _StubProvider extends RefCounted:
	var opened_path := ""
	var open_called := false
	func open_asset(path: String) -> bool:
		open_called = true
		opened_path = path
		return true


func _test_registry_open_asset_calls_provider() -> void:
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_stub")
	var stub := _StubProvider.new()
	reg.register_provider("__t_stub", _make_meta(["asset_editor.test"], ["stubtest"], 50), stub)
	var ok: bool = reg.open_asset("res://foo.stubtest")
	_expect("registry.open_asset invokes provider.open_asset and returns true",
		ok and stub.open_called and stub.opened_path == "res://foo.stubtest",
		"ok=%s called=%s path=%s" % [str(ok), str(stub.open_called), stub.opened_path])
	reg.unregister_provider("__t_stub")


func _test_open_asset_routes_by_extension_among_competitors() -> void:
	# Two providers claim the same capability and both list ".zzrt" but
	# one has higher priority. open_asset(path) must route to the higher.
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_rt_lo")
	reg.unregister_provider("__t_rt_hi")
	var lo := _StubProvider.new()
	var hi := _StubProvider.new()
	reg.register_provider("__t_rt_lo", _make_meta(["asset_editor.test"], ["zzrt"], 5), lo)
	reg.register_provider("__t_rt_hi", _make_meta(["asset_editor.test"], ["zzrt"], 50), hi)
	var ok: bool = reg.open_asset("res://thing.zzrt")
	_expect("open_asset routes to highest-priority provider for the extension",
		ok and hi.open_called and not lo.open_called and hi.opened_path == "res://thing.zzrt",
		"ok=%s hi=%s lo=%s" % [str(ok), str(hi.open_called), str(lo.open_called)])
	reg.unregister_provider("__t_rt_lo")
	reg.unregister_provider("__t_rt_hi")


func _test_open_asset_user_default_overrides_priority() -> void:
	# With both providers registered, pinning the lower-priority one as
	# default for the capability must redirect open_asset to it.
	var reg = _Registry.get_instance()
	reg.unregister_provider("__t_pin_lo")
	reg.unregister_provider("__t_pin_hi")
	var lo := _StubProvider.new()
	var hi := _StubProvider.new()
	reg.register_provider("__t_pin_lo", _make_meta(["asset_editor.test"], ["zzpin"], 5), lo)
	reg.register_provider("__t_pin_hi", _make_meta(["asset_editor.test"], ["zzpin"], 50), hi)
	reg.set_default_for("asset_editor.test", "__t_pin_lo")
	var ok: bool = reg.open_asset("res://thing.zzpin")
	_expect("open_asset honors user-pinned default over priority",
		ok and lo.open_called and not hi.open_called,
		"ok=%s lo=%s hi=%s" % [str(ok), str(lo.open_called), str(hi.open_called)])
	reg.set_default_for("asset_editor.test", "")  # cleanup
	reg.unregister_provider("__t_pin_lo")
	reg.unregister_provider("__t_pin_hi")


func _test_open_asset_unknown_extension_returns_false() -> void:
	var reg = _Registry.get_instance()
	# No provider claims this extension — open_asset must return false
	# without crashing or invoking anything.
	var ok: bool = reg.open_asset("res://nothing.zzunhandled_xyz_nope")
	_expect("open_asset returns false when no provider matches the extension",
		not ok,
		"ok=%s (expected false)" % str(ok))

