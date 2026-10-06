extends SceneTree

const Registry = preload("res://addons/visual_gasic/vg_ai_custom_providers.gd")
const Providers = preload("res://addons/visual_gasic/vg_ai_providers.gd")
const EditorUI = preload("res://addons/visual_gasic/vg_ai_custom_provider_editor.gd")
const FunctionCalling = preload("res://addons/visual_gasic/vg_ai_function_calling.gd")

class SettingsStub extends RefCounted:
	var values: Dictionary = {}
	func has_setting(key: String) -> bool:
		return values.has(key)
	func get_setting(key: String) -> Variant:
		return values.get(key)
	func set_setting(key: String, value: Variant) -> void:
		values[key] = value

var _failed := 0
var _passed := 0
var _server := TCPServer.new()
var _peer: StreamPeerTCP
var _request := ""
var _requests: Array[String] = []
var _port := 0
var _reply_code := 200
var _reply_body := '{"choices":[{"message":{"content":"OK"}}]}'
var _hold_response := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + label)
	else:
		_failed += 1
		push_error("FAIL: " + label)

func _record(protocol: String = "openai") -> Dictionary:
	return {
		"id": "custom_offline_test", "name": "Offline test", "format": protocol,
		"endpoint": "https://example.invalid:8443/proxy/chat",
		"models": ["new-model", "second-model"], "default_model": "new-model",
		"models_path": "/proxy/models", "requires_key": false,
		"native_tools": false, "vision": false,
	}

func _run() -> void:
	if "--persistence-write" in OS.get_cmdline_user_args() or "--persistence-read" in OS.get_cmdline_user_args():
		_check(Engine.is_editor_hint() and OS.get_environment("VG_CUSTOM_PROVIDER_TEST_SETTINGS") == "isolated", "restart tests explicitly isolated editor")
		if _failed == 0:
			if "--persistence-write" in OS.get_cmdline_user_args():
				var es := EditorInterface.get_editor_settings()
				es.set_setting("visual_gasic/ai/migrated_to_editor_settings", true)
				es.set_setting("visual_gasic/ai/preferred_provider", "ollama")
				_check(Providers.save_custom_providers([_record()], {"custom_offline_test": "dummy-offline-key"}).ok, "save restart fixture")
				Providers.save_preferred_provider("custom_offline_test")
			else:
				var p := Providers.find_provider("custom_offline_test")
				_check(p != null and p.default_model == "new-model" and p.api_port == 8443, "custom provider survives editor restart")
				_check(Providers.load_api_key("custom_offline_test") == "dummy-offline-key", "custom key survives editor restart")
				_check(Providers.load_preferred_provider() == "custom_offline_test", "preferred custom provider survives editor restart")
				Providers.save_custom_providers([], {})
		await _finish()
		return
	if Engine.is_editor_hint():
		_test_editor_registry()
	var base := _record()
	var parsed := Registry.validate(base)
	_check(parsed.ok and parsed.port == 8443 and parsed.path == "/proxy/chat" and parsed.tls, "HTTPS endpoint with nondefault port")
	var ipv6 := base.duplicate(true)
	ipv6.endpoint = "http://[::1]:11434/api/generate"
	var v6 := Registry.validate(ipv6)
	_check(v6.ok and v6.host == "[::1]" and v6.port == 11434 and not v6.tls, "IPv6 loopback endpoint")
	var v6_info := Providers.custom_provider_info(ipv6)
	_check(v6_info.api_host == "::1" and Providers.request_url(v6_info, {"path": "/api/generate"}) == ipv6.endpoint, "IPv6 HTTPClient host and request URL")
	for invalid in [
		{"id": "openai"}, {"name": ""}, {"format": "unknown"},
		{"endpoint": "file:///tmp/test"}, {"endpoint": "https://user:key@example.invalid/chat"},
		{"endpoint": "https://example.invalid/chat?key=secret"},
		{"endpoint": "https://example.invalid/chat#fragment"},
		{"endpoint": "http://localhost:65536/chat"}, {"endpoint": "http://localhost:0/chat"},
		{"endpoint": "http://localhost/chat\ninjected"},
		{"models": []}, {"models": [""]}, {"models": [3]},
		{"default_model": "missing"}, {"models_path": "https://elsewhere.invalid/models"},
		{"models_path": "/models?key=secret"},
		{"native_tools": "false"},
	]:
		var entry := base.duplicate(true)
		entry.merge(invalid, true)
		_check(not Registry.validate(entry).ok, "reject invalid setting " + str(invalid.keys()[0]) + " " + str(invalid.values()[0]))
	var settings := SettingsStub.new()
	_check(Registry.save_records(settings, [base]).ok, "save custom registry")
	var reloaded := Registry.load_records(settings)
	_check(reloaded.size() == 1 and reloaded[0] == base, "registry reload preserves stable ID and configuration")
	var saved: String = settings.values[Registry.SETTING]
	_check(not Registry.save_records(settings, [base, base]).ok and settings.values[Registry.SETTING] == saved, "duplicate IDs rejected atomically")
	_check(not Registry.save_records(null, [base]).ok, "noneditor save returns explicit error")
	_check(Registry.save_records(settings, []).ok and Registry.load_records(settings).is_empty(), "remove custom provider")
	for protocol in Registry.FORMATS:
		var record := _record(protocol)
		var p := Providers.custom_provider_info(record)
		var req := Providers.build_custom_request(p, "new-model", "system", [], "prompt", "")
		_check(req.path == "/proxy/chat" and JSON.parse_string(req.body).model == "new-model", "custom " + protocol + " request path and model")
		_check(not str(req.headers).contains("Authorization") and not str(req.headers).contains("x-api-key"), "optional key omitted for " + protocol)
		_check(Providers.request_url(p, req) == "https://example.invalid:8443/proxy/chat", "request URL preserves HTTPS port " + protocol)
		var with_key := Providers.build_custom_request(p, "new-model", "", [], "prompt", "dummy-offline-key")
		_check(str(with_key.headers).contains("dummy-offline-key"), "authentication adapter " + protocol)
		p.requires_key = true
		_check(Providers.build_custom_request(p, "new-model", "", [], "prompt", "").has("error"), "missing required key " + protocol)
		_check(Providers.build_custom_request(p, "new-model", "", [], "prompt", "bad\r\nheader").has("error"), "reject header injection " + protocol)
		var catalog := '{"models":[{"name":"model-b"},{"name":"model-a"}]}' if protocol == "ollama" else '{"data":[{"id":"model-b"},{"id":"model-a"}]}'
		var discovered := Providers.parse_custom_models(protocol, catalog)
		_check(discovered.ok and discovered.models == ["model-a", "model-b"], "discovery adapter " + protocol)
	_check(not Providers.parse_custom_models("openai", "{}").ok, "missing discovery array")
	_check(not Providers.parse_custom_models("openai", '{"data":[]}').ok, "empty discovery array")
	_check(not Providers.parse_custom_models("openai", '{"data":[{"id":2}]}').ok, "invalid discovery ID")
	_check(Providers.parse_stream_line("openai", 'data: {"choices":[{"delta":{"content":"hello"}}]}').token == "hello", "existing OpenAI stream adapter")
	_check(Providers.parse_stream_line("claude", 'data: {"type":"content_block_delta","delta":{"text":"hello"}}').token == "hello", "existing Anthropic stream adapter")
	_check(Providers.parse_stream_line("ollama", '{"response":"hello","done":false}').token == "hello", "existing Ollama stream adapter")
	_check(Providers.extract_response_text("openai", _reply_body) == "OK", "nonstream OpenAI extraction")
	_check(Providers.extract_response_text("claude", '{"content":[{"type":"text","text":"OK"}]}') == "OK", "nonstream Anthropic extraction")
	_check(Providers.extract_response_text("ollama", '{"response":"OK"}') == "OK", "nonstream Ollama extraction")
	_check(FunctionCalling.supports_native_fc("openai") and not FunctionCalling.supports_native_fc("ollama"), "existing native tools gating")
	var tool_body: Dictionary = {}
	FunctionCalling.inject_tools_into_body("claude", tool_body)
	_check(tool_body.has("tools"), "existing native tools schema")
	for port in range(38521, 38541):
		if _server.listen(port, "127.0.0.1") == OK:
			_port = port
			break
	_check(_port != 0, "bind owned loopback test server")
	if _port != 0:
		await _test_ui()
		await _test_discovery()
		_server.stop()
	await _finish()

func _finish() -> void:
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		var deadline := Time.get_ticks_msec() + 30000
		await create_timer(0.2).timeout
		while filesystem.is_scanning() and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
	await process_frame
	print("CUSTOM_AI_PROVIDER_TESTS_COMPLETED passed=%d failures=%d" % [_passed, _failed])
	quit(1 if _failed else 0)

func _test_editor_registry() -> void:
	var es := EditorInterface.get_editor_settings()
	# Run this mode only with isolated XDG_CONFIG_HOME/XDG_DATA_HOME.
	_check(OS.get_environment("VG_CUSTOM_PROVIDER_TEST_SETTINGS") == "isolated", "editor tests explicitly isolated")
	if OS.get_environment("VG_CUSTOM_PROVIDER_TEST_SETTINGS") != "isolated":
		return
	es.set_setting("visual_gasic/ai/migrated_to_editor_settings", true)
	es.set_setting("visual_gasic/ai/preferred_provider", "ollama")
	var original_count := Providers.get_providers().size()
	for protocol in Registry.FORMATS:
		var record := _record(protocol)
		record.native_tools = true
		record.vision = true
		_check(Providers.save_custom_providers([record], {record.id: "dummy-offline-key"}).ok, "editor save " + protocol)
		var p := Providers.find_provider(record.id)
		_check(p != null and p.is_custom and p.protocol == protocol and Providers.get_providers().size() == original_count + 1, "registry custom entry " + protocol)
		_check(Providers.load_api_key(record.id) == "dummy-offline-key", "editor-local key storage " + protocol)
		_check(not es.get_setting(Registry.SETTING).contains("dummy-offline-key"), "registry excludes key " + protocol)
		var req := Providers.build_request(record.id, "new-model", "system", [], "prompt", "dummy-offline-key")
		_check(req.path == "/proxy/chat", "ID request routing " + protocol)
		var nonstream := Providers.build_request_nostream(record.id, "new-model", "", "prompt", "dummy-offline-key")
		_check(JSON.parse_string(nonstream.body).stream == false, "ID nonstream routing " + protocol)
		var line := 'data: {"choices":[{"delta":{"content":"hello"}}]}' if protocol == "openai" else ('data: {"type":"content_block_delta","delta":{"text":"hello"}}' if protocol == "claude" else '{"response":"hello","done":false}')
		_check(Providers.parse_stream_line(record.id, line).token == "hello", "ID stream routing " + protocol)
		var response := '{"choices":[{"message":{"content":"OK"}}]}' if protocol == "openai" else ('{"content":[{"type":"text","text":"OK"}]}' if protocol == "claude" else '{"response":"OK"}')
		_check(Providers.extract_response_text(record.id, response) == "OK", "ID response routing " + protocol)
		_check(FunctionCalling.supports_native_fc(record.id) == (protocol != "ollama"), "custom native tools capability " + protocol)
		_check(Providers.provider_supports_vision(record.id, "new-model"), "custom vision capability " + protocol)
		if protocol != "ollama":
			var body: Dictionary = {}
			FunctionCalling.inject_tools_into_body(record.id, body)
			_check(body.has("tools"), "custom native tools routing " + protocol)
			var fc_line := 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call1","function":{"name":"read_file","arguments":"{}"}}]}}]}' if protocol == "openai" else 'data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"call1","name":"read_file"}}'
			var fragment: Variant = FunctionCalling.parse_stream_line_for_fc(record.id, fc_line)
			_check(fragment is Dictionary and fragment.name == "read_file", "custom native tool stream routing " + protocol)
		Providers._save_cached_models(es, record.id, ["discovered-model"])
		p = Providers.find_provider(record.id)
		_check(p.models == ["new-model", "second-model", "discovered-model"], "manual models retained alongside discovered models " + protocol)
		Providers.save_custom_providers([record], {record.id: "dummy-offline-key"})
		_check(Providers.find_provider(record.id).models.has("discovered-model"), "unchanged settings preserve discovery cache " + protocol)
		Providers.save_preferred_provider(record.id)
	_check(Providers.save_custom_providers([], {}).ok, "editor remove")
	_check(Providers.load_preferred_provider() == "ollama" and Providers.find_provider("custom_offline_test") == null, "remove resets stale preference")
	_check(not es.has_setting("visual_gasic/ai/custom_offline_test_key"), "remove erases key")
	var dialog_script = load("res://addons/visual_gasic/vg_ai_api_keys_dialog.gd")
	var dialog = dialog_script.new()
	dialog.setup(Providers)
	_check(dialog._custom_editor != null and not dialog.dialog_hide_on_ok, "settings dialog wires editor and keeps validation errors visible")
	var dialog_record := _record()
	dialog_record.default_model = "second-model"
	dialog._custom_editor._add_row(dialog_record, "dummy-offline-key")
	_check(dialog.save_provider_settings().ok and Providers.find_provider("custom_offline_test") != null, "settings dialog saves custom definition and key")
	var help_script = load("res://addons/visual_gasic/vg_ai_help.gd")
	var help = help_script.new()
	help.AIProviders = Providers
	help._provider_dropdown = OptionButton.new()
	help._model_dropdown = OptionButton.new()
	help.add_child(help._provider_dropdown)
	help.add_child(help._model_dropdown)
	help._provider_id = "custom_offline_test"
	help._current_model = "second-model"
	help._conversation_history = [{"role": "user", "content": "synthetic"}]
	help._reload_provider_dropdown()
	_check(help._provider_dropdown.get_item_text(help._provider_dropdown.selected) == "Offline test (Custom)" and help._current_model == "second-model", "Narcea reload selects custom provider and retains model")
	_check(help._conversation_history.size() == 1, "saving unchanged provider preserves conversation")
	help._current_model = ""
	help._update_model_dropdown()
	_check(help._current_model == "second-model", "custom default model honored when not first in list")
	help.free()
	dialog.free()
	Providers.save_custom_providers([], {})

func _process(_delta: float) -> bool:
	if _server.is_connection_available() and _peer == null:
		_peer = _server.take_connection()
		_request = ""
	if _peer != null:
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peer = null
			return false
		var available := _peer.get_available_bytes()
		if available:
			_request += _peer.get_utf8_string(available)
		var boundary := _request.find("\r\n\r\n")
		if boundary >= 0:
			var length := 0
			for line in _request.substr(0, boundary).split("\r\n"):
				if line.to_lower().begins_with("content-length:"):
					length = int(line.substr(line.find(":") + 1).strip_edges())
			if _request.substr(boundary + 4).to_utf8_buffer().size() >= length:
				_requests.append(_request)
				if _hold_response:
					_request = ""
					return false
				var reply := "HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [_reply_code, _reply_body.to_utf8_buffer().size(), _reply_body]
				_peer.put_data(reply.to_utf8_buffer())
				_peer = null
	return false

func _test_ui() -> void:
	var record := _record()
	record.endpoint = "http://127.0.0.1:%d/custom/chat" % _port
	var ui := EditorUI.new()
	root.add_child(ui)
	ui.setup([])
	ui._add_row(record, "")
	_check(ui.collect().ok and ui.collect().records[0] == record, "UI collects custom configuration")
	var row: Dictionary = ui._rows[0]
	row.name.text = ""
	_check(not ui.collect().ok, "UI refuses invalid configuration")
	row.name.text = record.name
	var button := Button.new()
	ui.add_child(button)
	await ui._test(row, button)
	_check(ui._status.text.begins_with("Connection test passed"), "connection test validates assistant response")
	_check(_requests.size() == 1 and _requests[0].begins_with("POST /custom/chat ") and not _requests[0].contains("Authorization:"), "connection test uses custom path and optional key")
	var request_body: Dictionary = JSON.parse_string(_requests[0].split("\r\n\r\n")[1])
	_check(request_body.stream == false and request_body.max_tokens == 16 and request_body.messages[-1].content == "Reply with OK.", "connection test bounded synthetic payload")
	_reply_code = 401
	await ui._test(row, button)
	_check(ui._status.text.contains("HTTP 401"), "connection test reports HTTP error")
	_reply_code = 200
	_reply_body = '{"error":"not an assistant response"}'
	await ui._test(row, button)
	_check(ui._status.text.contains("no compatible assistant text"), "connection test rejects success-shaped malformed response")
	_hold_response = true
	ui._test(row, button)
	_check(ui._busy and button.disabled and not ui.collect().ok, "connection test prevents saving incomplete request")
	while ui._busy:
		await process_frame
	_check(ui._status.text.contains("timed out") and not button.disabled, "connection timeout is explicit and restores controls")
	_hold_response = false
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	row.format.select(2)
	row.format.item_selected.emit(2)
	_check(row.native_tools.disabled and not row.native_tools.button_pressed, "Ollama UI disables unsupported native tools")
	row.format.select(0)
	row.format.item_selected.emit(0)
	_check(not row.native_tools.disabled and ui.collect().records[0].id == record.id, "editing API format keeps stable provider ID")
	var buttons: HBoxContainer = row.panel.get_child(row.panel.get_child_count() - 1)
	buttons.get_child(1).pressed.emit()
	_check(ui.collect().records.is_empty(), "remove provider clears staged UI entry")
	ui.queue_free()

func _test_discovery() -> void:
	_reply_code = 200
	_reply_body = '{"data":[{"id":"future-model"}]}'
	var record := _record()
	record.endpoint = "http://127.0.0.1:%d/custom/chat" % _port
	var p := Providers.custom_provider_info(record)
	var worker := Thread.new()
	worker.start(func(): return Providers.discover_custom_models(p, ""))
	while worker.is_alive():
		await process_frame
	var result: Dictionary = worker.wait_to_finish()
	_check(result.ok and result.models == ["future-model"], "live discovery parses owned mock response")
	_check(_requests[-1].begins_with("GET /proxy/models "), "discovery uses configurable path")
	p.models_path = ""
	_check(not Providers.discover_custom_models(p, "").ok, "disabled discovery returns explicit error")
	p.models_path = "/proxy/models"
	_reply_code = 403
	worker = Thread.new()
	worker.start(func(): return Providers.discover_custom_models(p, ""))
	while worker.is_alive():
		await process_frame
	result = worker.wait_to_finish()
	_check(not result.ok and result.error.contains("HTTP 403"), "discovery surfaces HTTP errors")
