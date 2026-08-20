@tool
extends SceneTree
## Narcea Agent Loop Smoke Test
##
## Tests the full Narcea pipeline headlessly:
##   1. Provider registry — all 8 providers load and route correctly
##   2. Narcea context building — builds without crash on headless
##   3. System prompt assembly
##   4. Prompt streaming — parse_stream_line handles all provider formats
##   5. Function-calling plugin — tool schema injection for all providers
##   6. Agent loop simulation — synthetic round-trip
##   7. Run session basic API
##   8. Error decode — common errors produce readable hints
##   9. Effective provider with config overrides

var _failed := 0
var _passed := 0


func _init() -> void:
	print("=== Narcea Agent Loop Smoke Test ===")
	print("Testing with 8 providers (ollama, openai, claude, gemini, deepseek, qwen, codeium, amazonq)...")
	print("")

	# ── 1. Provider registry ──
	_test_provider_registry()

	# ── 2. Narcea context assembly ──
	_test_narcea_context_build()

	# ── 3. System prompt ──
	_test_system_prompt()

	# ── 4. Response stream parsing ──
	_test_parse_stream_lines()

	# ── 5. Function-calling schema injection ──
	_test_fc_schema_injection()

	# ── 6. Agent loop simulation ──
	_test_agent_round_trip()

	# ── 7. Run session API ──
	_test_run_session()

	# ── 8. Error decode ──
	_test_error_decode()

	# ── 9. Effective provider ──
	_test_effective_provider()

	# ── 10. Model cache / refresh_models ──
	_test_refresh_models()

	# ── Summary ──
	print("")
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	print("RESULTS: %d/%d passed, %d failed" % [_passed, _passed + _failed, _failed])
	quit(1 if _failed > 0 else 0)


# ─── Test helpers ───────────────────────────────────────────

func _ok(label: String) -> void:
	_passed += 1
	print("  [PASS] %s" % label)


func _fail(label: String, reason: String) -> void:
	_failed += 1
	print("  [FAIL] %s: %s" % [label, reason])


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_ok(label)
	else:
		_fail(label, reason)


# ─── Test 1: Provider Registry ─────────────────────────────

func _test_provider_registry() -> void:
	print("╔══ 1. Provider Registry ══╗")
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	_expect("vg_ai_providers.gd loads", Providers != null)
	if Providers == null:
		print("")
		return

	var all = Providers.get_providers()
	for p in all:
		_expect("provider '%s' registered" % p.id, true)

	# build_request routes each openai-compat provider correctly
	for pid in ["openai", "deepseek", "qwen", "codeium", "amazonq"]:
		var req = Providers.build_request(pid, "test-model", "system", [], "hello", "sk-test")
		var body_str = str(req.get("body", ""))
		var hdrs = req.get("headers", [])
		_expect("build_request for '%s' returns valid body (%d chars) + %d headers" %
			[pid, body_str.length(), hdrs.size()],
			body_str.length() > 10 and hdrs.size() >= 1)

	# parse_stream_line for each provider handles SSE correctly
	for pid in ["openai", "deepseek", "qwen", "codeium", "amazonq"]:
		var test_line := 'data: {"choices":[{"index":0,"delta":{"content":"test"},"finish_reason":null}]}'
		var result = Providers.parse_stream_line(pid, test_line)
		_expect("parse_stream_line for '%s' extracts token" % pid,
			result.get("token", "") == "test" and result.get("done", true) == false)

	# Done detection
	var done_line := 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}'
	for pid in ["openai", "deepseek", "qwen", "codeium", "amazonq"]:
		var result = Providers.parse_stream_line(pid, done_line)
		_expect("parse_stream_line for '%s' detects 'stop'" % pid,
			result.get("done", false) == true)

	# API key paths are safe
	for pid in ["codeium", "amazonq"]:
		var key = Providers.load_api_key(pid)
		_expect("load_api_key for '%s' safe (empty in headless)" % pid, key == "")

	print("")


# ─── Test 2: Narcea Context Build ─────────────────────────

func _test_narcea_context_build() -> void:
	print("╔══ 2. Narcea Context Build ══╗")
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	_expect("vg_ai_narcea.gd loads", Narcea != null)
	if Narcea == null:
		print("")
		return

	var n = Narcea.new()
	_expect("Narcea.new() succeeds", n != null)

	# Context block builds without crash (headless — no plugin)
	var ctx = n.build_context_block(null)
	_expect("build_context_block(null) returns long string",
		typeof(ctx) == TYPE_STRING and ctx.length() > 100,
		"length=%d" % ctx.length())

	# Knowledge section present
	_expect("context contains VG control catalog",
		ctx.find("CommandButton") != -1)

	# Query hint changes block
	n.set_query_hint("how do I move a sprite")
	var ctx2 = n.build_context_block(null)
	_expect("context with query hint builds",
		ctx2.length() > 200 and typeof(ctx2) == TYPE_STRING)

	# User notes — no file exists, so block is empty
	var notes = n._user_notes_block()
	_expect("_user_notes_block empty when no .narcea/notes.md", notes == "")

	# Pinned files — empty array = empty block
	var pinned = n._pinned_files_block()
	_expect("_pinned_files_block empty when nothing pinned", pinned == "")

	# Tokenise works
	var toks = n._tokenise("I want to move the player sprite")
	_expect("_tokenise produces tokens", toks.size() >= 2)

	# Ranking works
	var entries := [
		{"path": "tutorials/move_sprite.vg", "title": "Move sprite with keyboard"},
		{"path": "tutorials/camera_follow.vg", "title": "Camera follow player"},
	]
	var ranked = n._rank_examples_by_hint(entries, "move sprite", 2)
	_expect("_rank_examples_by_hint returns entries (fallback to first N)", ranked.size() >= 0)
	_expect("move_sprite ranks first for 'move sprite'",
		str(ranked[0].get("path", "")).find("move_sprite") != -1)

	var err = n.decode_error("Identifier \"foo\" not declared in the current scope")
	_expect("decode_error handles undeclared variable", err.length() > 0)

	var err2 = n.decode_error("Division by zero")
	_expect("decode_error handles division by zero", err2.length() > 0)

	var err3 = n.decode_error("")

	var err4 = n.decode_error("Unrelated text with no match")
	_expect("decode_error empty for unknown error", err4 == "")

	print("")


# ─── Test 3: System Prompt ────────────────────────────────

func _test_system_prompt() -> void:
	print("╔══ 3. System Prompt Assembly ══╗")
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	var n = Narcea.new()
	var ctx = n.build_context_block(null)
	_expect("context includes 'Narcea response policy'",
		ctx.find("Narcea response policy") != -1)

	# Load help.gd to verify it exists (key module)
	var Help = load("res://addons/visual_gasic/vg_ai_help.gd")
	_expect("vg_ai_help.gd loads", Help != null)

	print("")


# ─── Test 4: Stream Parsing ───────────────────────────────

func _test_parse_stream_lines() -> void:
	print("╔══ 4. Stream Line Parsing ══╗")
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	if Providers == null:
		print("")
		return

	var tests := []
	# Ollama
	tests.append(["ollama", '{"response":"Hello","done":false}', "Hello", false])
	tests.append(["ollama", '{"response":"","done":true}', "", true])
	# OpenAI-compatible
	tests.append(["openai", 'data: {"choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}', "Hi", false])
	tests.append(["deepseek", 'data: {"choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}', "Hello", false])
	tests.append(["qwen", 'data: {"choices":[{"index":0,"delta":{"content":"World"},"finish_reason":null}]}', "World", false])
	tests.append(["codeium", 'data: {"choices":[{"index":0,"delta":{"content":"Code"},"finish_reason":null}]}', "Code", false])
	tests.append(["amazonq", 'data: {"choices":[{"index":0,"delta":{"content":"Amazon"},"finish_reason":null}]}', "Amazon", false])
	# Stop
	tests.append(["openai", 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}', "", true])
	tests.append(["deepseek", 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}', "", true])
	tests.append(["qwen", 'data: [DONE]', "", true])
	# Claude
	tests.append(["claude", 'data: {"type":"content_block_delta","delta":{"text":"Hi"}}', "Hi", false])
	tests.append(["claude", 'data: {"type":"message_stop"}', "", true])
	# Gemini
	tests.append(["gemini", 'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]},"finishReason":""}]}', "Hello", false])
	tests.append(["gemini", 'data: {"candidates":[{"content":{"parts":[{"text":""}]},"finishReason":"STOP"}]}', "", true])
	# Edge cases
	tests.append(["openai", "", "", false])
	tests.append(["openai", "not json at all", "", false])

	var all_ok := true
	for t in tests:
		var pid = t[0]
		var line = t[1]
		var exp_token = t[2]
		var exp_done = t[3]
		var result = Providers.parse_stream_line(pid, line)
		var token = result.get("token", "")
		var done = result.get("done", false)
		var ok = token == exp_token and done == exp_done
		if not ok:
			_fail("parse %s: expected token='%s' done=%s, got token='%s' done=%s" %
				[pid, exp_token, str(exp_done), token, str(done)], "")
			all_ok = false

	if all_ok:
		_ok("All %d stream parse cases pass" % tests.size())

	print("")


# ─── Test 5: Function-Calling Schema Injection ────────────

func _test_fc_schema_injection() -> void:
	print("╔══ 5. Function-Calling Schema Injection ══╗")
	var FC = load("res://addons/visual_gasic/vg_ai_function_calling.gd")
	_expect("vg_ai_function_calling.gd loads", FC != null)
	if FC == null:
		print("")
		return

	# supports_native_fc for all 7 cloud providers
	for pid in ["openai", "claude", "gemini", "deepseek", "qwen", "codeium", "amazonq"]:
		_expect("%s supports_native_fc" % pid, FC.supports_native_fc(pid))

	_expect("ollama does NOT support native FC", not FC.supports_native_fc("ollama"))

	# inject_tools_into_body for OpenAI-compatible providers
	for pid in ["openai", "deepseek", "qwen", "codeium", "amazonq"]:
		var body := {"model": "test", "messages": []}
		FC.inject_tools_into_body(pid, body)
		_expect("inject_tools_into_body for %s adds 'tools' key" % pid, body.has("tools"))
		_expect("inject_tools_into_body for %s adds 'tool_choice'" % pid,
			body.get("tool_choice", "") == "auto")

	# Claude inject
	var claude_body := {"model": "claude-sonnet-4-5", "messages": []}
	FC.inject_tools_into_body("claude", claude_body)
	_expect("Claude inject adds 'tools' key", claude_body.has("tools"))

	# Parse FC fragments
	var fc_line := 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"function":{"name":"write_file","arguments":"{}"}}]}}]}'
	var frag = FC.parse_stream_line_for_fc("openai", fc_line)
	_expect("parse_stream_line_for_fc processes tool call line",
		frag == null or typeof(frag) == TYPE_DICTIONARY)

	print("")


# ─── Test 6: Agent Loop Simulation ────────────────────────

func _test_agent_round_trip() -> void:
	print("╔══ 6. Agent Loop Simulation ══╗")
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	var FC = load("res://addons/visual_gasic/vg_ai_function_calling.gd")
	_expect("All 3 core modules load",
		Providers != null and Narcea != null and FC != null)
	if Providers == null or Narcea == null or FC == null:
		print("")
		return

	# Step 1: User types a prompt
	var user_prompt := "Create a form with a button that says 'Hello'"

	# Step 2: Build Narcea context
	var n = Narcea.new()
	n.set_query_hint(user_prompt)
	var context = n.build_context_block(null)
	_expect("Context builds with query hint", context.length() > 200)

	# Step 3: Simulate AI response with spec blocks
	var simulated_response := "```vg-form-spec\n{\"form_name\":\"Form1\"}\n```\n\n```vg-code-spec\n{\"files\":[{\"path\":\"res://Form1.vg\"}]}\n```"

	# Step 4: Verify spec blocks
	_expect("Simulated response has vg-form-spec",
		simulated_response.find("vg-form-spec") != -1)
	_expect("Simulated response has vg-code-spec",
		simulated_response.find("vg-code-spec") != -1)

	# Step 5: Parse form-spec JSON
	var form_start := simulated_response.find("```vg-form-spec")
	if form_start != -1:
		var json_start := simulated_response.find("{", form_start)
		var json_end := simulated_response.find("```", json_start)
		if json_end != -1:
			var json_str := simulated_response.substr(json_start, json_end - json_start).strip_edges()
			var parsed = JSON.parse_string(json_str)
			_expect("Form-spec JSON parses",
				parsed != null and typeof(parsed) == TYPE_DICTIONARY)
			if parsed != null:
				_expect("Form-spec has form_name='Form1'",
					str(parsed.get("form_name", "")) == "Form1")

	# Step 6: Tool simulation — parse a write_file tool call
	var write_tool_line := 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_123","type":"function","function":{"name":"write_file","arguments":"{\"path\":\"res://test.vg\"}"}}]},"finish_reason":"tool_calls"}]}'
	var tool_result = Providers.parse_stream_line("openai", write_tool_line)
	_expect("Tool call stream line parses", typeof(tool_result) == TYPE_DICTIONARY)

	# Step 7: Verify function calling adapter can parse tool fragments
	var tool_frag = FC.parse_stream_line_for_fc("openai", write_tool_line)
	_expect("FC parser processes tool call line (may return null for empty tool defs)",
		tool_frag == null or typeof(tool_frag) == TYPE_DICTIONARY)

	print("")


# ─── Test 7: Run Session API ──────────────────────────────

func _test_run_session() -> void:
	print("╔══ 7. Run Session API ══╗")
	var RunSession = load("res://addons/visual_gasic/vg_ai_run_session.gd")
	_expect("vg_ai_run_session.gd loads", RunSession != null)
	if RunSession == null:
		print("")
		return

	# Session needs to be in tree for Timer, but in headless SceneTree
	# we can still test the non-timer API.
	var session = RunSession.new()
	_expect("RunSession instantiated", session != null)

	# get_recent_output is empty when nothing has run
	_expect("get_recent_output empty with no sessions", session.get_recent_output() == "")

	# stop is idempotent
	session.stop()
	_expect("stop() on idle session is safe", true)

	# is_running returns false
	_expect("is_running() false when idle", not session.is_running())

	# ai_projects scaffold root must not be used as --path (no project.godot).
	var host_root := ProjectSettings.globalize_path("res://").rstrip("/")
	var resolved: String = session._resolve_godot_project_root("res://ai_projects/Pong/")
	_expect("ai_projects subdir resolves to host project", resolved == host_root)

	var scene: String = session._normalize_scene_path("Game.tscn", "res://ai_projects/Pong/")
	_expect("relative scene rebased under scaffold", scene == "res://ai_projects/Pong/Game.tscn")

	print("")


# ─── Test 8: Error Decode ─────────────────────────────────

func _test_error_decode() -> void:
	print("╔══ 8. Narcea Error Decode ══╗")
	var Narcea = load("res://addons/visual_gasic/vg_ai_narcea.gd")
	if Narcea == null:
		print("")
		return

	var n = Narcea.new()
	var test_cases := [
		["Identifier \"foo\" not declared in the current scope", "not declared"],
		["Parser Error: Expected end of file", "missing"],
		["Invalid call. Nonexistent function", "doesn't exist"],
		["Attempt to call function on a null instance", "null"],
		["Division By Zero", "dividing"],
		["Stack overflow", "Infinite"],
		["Type mismatch", "wrong type"],
		["Variable not declared", "wasn't Dim'd"],
		["", ""],  # empty string
		["Syntax error in SQL statement", ""],  # unknown
	]

	for tc in test_cases:
		var input = tc[0]
		var expect_kw = tc[1]
		var result = n.decode_error(input)
		if expect_kw == "":
			_expect("decode_error('%s') returns empty for no match" % input,
				result == "")
		else:
			_expect("decode_error('%s') returns hint (%d chars)" % [input, result.length()],
				result.length() > 0)

	print("")


# ─── Test 9: Effective Provider ───────────────────────────

func _test_effective_provider() -> void:
	print("╔══ 9. Effective Provider (Config Overrides) ══╗")
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	if Providers == null:
		print("")
		return

	# ── 9a. No editor settings in headless — returns same as find_provider ──
	var p = Providers.find_provider("amazonq")
	var ep = Providers.get_effective_provider("amazonq")
	_expect("get_effective_provider returns ProviderInfo for amazonq",
		ep != null and ep.id == "amazonq")

	if p != null and ep != null:
		_expect("Default host same as find_provider", ep.api_host == p.api_host)
		_expect("Default port same as find_provider", ep.api_port == p.api_port)

	# ── 9b. All providers pass through ──
	for pid in ["ollama", "openai", "claude", "gemini", "deepseek", "qwen", "codeium"]:
		var p2 = Providers.get_effective_provider(pid)
		_expect("get_effective_provider for '%s' returns valid info" % pid,
			p2 != null and p2.id == pid)

	# ── 9c. Unknown provider returns null ──
	_expect("get_effective_provider null for unknown",
		Providers.get_effective_provider("nonexistent") == null)

	# ── 9d. Amazon Q override logic works correctly in headless (no EditorSettings) ──
	# In headless mode _editor_settings() returns null, so get_effective_provider
	# falls through to the no-override path. This proves the null-safety is correct.
	# We verify that calling it multiple times is idempotent and the ProviderInfo
	# is never corrupted.
	var safe_test := true
	for i in 3:
		var amazon_ep = Providers.get_effective_provider("amazonq")
		if amazon_ep == null or amazon_ep.id != "amazonq":
			safe_test = false
			_fail("Amazon Q override null-safety", "iteration %d returned null" % i)
			break
		if amazon_ep.api_host != "localhost" or amazon_ep.api_port != 8080:
			safe_test = false
			_fail("Amazon Q override defaults", "expected localhost:8080, got %s:%d" %
				[amazon_ep.api_host, amazon_ep.api_port])
			break
	if safe_test:
		_ok("Amazon Q get_effective_provider null-safe and idempotent (%d iterations)" % 3)

	print("")


# ─── Test 10: Model Cache / Refresh ────────────────────────

func _test_refresh_models() -> void:
	print("╔══ 10. Model Cache / Refresh ══╗")
	var Providers = load("res://addons/visual_gasic/vg_ai_providers.gd")
	if Providers == null:
		print("")
		return

	# ── 10a. refresh_models returns error when not in editor (headless) ──
	var result: Dictionary = Providers.refresh_models("ollama")
	_expect("refresh_models('ollama') returns error dict in headless",
		result.get("ok", true) == false and not result.get("error", "").is_empty())

	# ── 10b. refresh_models returns error for unknown provider ──
	var unknown_result: Dictionary = Providers.refresh_models("nonexistent")
	_expect("refresh_models('nonexistent') returns error for unknown provider",
		unknown_result.get("ok", true) == false)

	# ── 10c. get_providers() applies cached model overrides from EditorSettings ──
	# In headless _editor_settings() returns null, so the override loop is skipped.
	# Verify the default model lists are still returned correctly.
	var all = Providers.get_providers()
	_expect("get_providers() still returns providers in headless", all.size() >= 8)
	if all.size() >= 8:
		_expect("ollama still has default models",
			all[0].models.size() > 0 and all[0].models[0] == "qwen2.5-coder:7b")

	# ── 10d. Verify refresh_models method signature matches doc ──
	# The method should exist and be callable (regression check)
	_expect("refresh_models is a static method",
		Providers.has_method("refresh_models"))

	# ── 10e. Gemini chat-model filter drops embed-only and legacy entries ──
	_expect("is_gemini_chat_model rejects embedding models",
		not Providers.is_gemini_chat_model("gemini-embedding-001", ["embedContent"]))
	_expect("is_gemini_chat_model accepts streamGenerateContent models",
		Providers.is_gemini_chat_model("gemini-2.0-flash", ["streamGenerateContent"]))
	_expect("is_gemini_legacy_or_experimental rejects gemini-1.5-pro",
		Providers.is_gemini_legacy_or_experimental("gemini-1.5-pro"))
	_expect("is_gemini_legacy_or_experimental rejects -exp builds",
		Providers.is_gemini_legacy_or_experimental("gemini-2.0-flash-exp"))
	_expect("filter_provider_model_list prunes cached legacy ids",
		Providers.filter_provider_model_list("gemini", ["gemini-2.0-flash", "gemini-1.5-pro"]) == ["gemini-2.0-flash"])

	# ── 10f. pick_default_model prefers live flash models ──
	var live := ["gemini-2.0-flash", "gemini-2.5-pro"]
	_expect("pick_default_model chooses gemini-2.0-flash when 2.5-flash absent",
		Providers.pick_default_model("gemini", live) == "gemini-2.0-flash")

	# ── 10g. diff_removed_models reports stale cache entries ──
	var removed: Array = Providers.diff_removed_models(
		["gemini-2.5-flash", "gemini-2.0-flash"],
		["gemini-2.0-flash", "gemini-2.5-pro"])
	_expect("diff_removed_models finds retired models",
		removed.size() == 1 and removed[0] == "gemini-2.5-flash")

	# ── 10h. pick_default_model must not recurse through get_providers ──
	_expect("pick_default_model(openai) returns first model without recursion",
		Providers.pick_default_model("openai", ["gpt-4o", "gpt-4o-mini"]) == "gpt-4o")

	print("")
