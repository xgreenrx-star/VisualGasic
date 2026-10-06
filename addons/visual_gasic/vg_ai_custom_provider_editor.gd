@tool
extends VBoxContainer

const Providers = preload("res://addons/visual_gasic/vg_ai_providers.gd")
const Registry = preload("res://addons/visual_gasic/vg_ai_custom_providers.gd")

var _rows: Array[Dictionary] = []
var _list: VBoxContainer
var _status: Label
var _busy: bool = false

func setup(records: Array) -> void:
	var heading := Label.new()
	heading.text = "Custom AI providers"
	add_child(heading)
	var hint := Label.new()
	hint.text = "Use a compatible chat API, not an IDE subscription or agent executable.\nKeys stay in local Editor Settings (not encrypted). HTTP sends data unencrypted.\nTest sends only a short synthetic prompt and may incur an API charge."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	_list = VBoxContainer.new()
	add_child(_list)
	for record in records:
		_add_row(record, Providers.load_api_key(record.id))
	var add := Button.new()
	add.text = "Add custom provider"
	add.pressed.connect(func():
		_add_row({
			"id": "custom_" + Crypto.new().generate_random_bytes(8).hex_encode(),
			"name": "", "format": "openai",
			"endpoint": "http://localhost:1234/v1/chat/completions",
			"models": [], "default_model": "", "models_path": "",
			"requires_key": false, "native_tools": false, "vision": false,
		}, "")
	)
	add_child(add)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

func _field(parent: VBoxContainer, title: String, value: String, secret: bool = false) -> LineEdit:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.secret = secret
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(edit)
	return edit

func _toggle(parent: VBoxContainer, title: String, value: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = title
	box.button_pressed = value
	parent.add_child(box)
	return box

func _add_row(record: Dictionary, key: String) -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	_list.add_child(panel)
	panel.add_child(HSeparator.new())
	var row: Dictionary = {"id": record.id, "panel": panel}
	row["name"] = _field(panel, "Display name", record.name)
	var format := OptionButton.new()
	format.add_item("OpenAI-compatible")
	format.add_item("Anthropic-compatible")
	format.add_item("Ollama /api/generate")
	format.select(Registry.FORMATS.find(record.format))
	panel.add_child(format)
	row["format"] = format
	row["endpoint"] = _field(panel, "Full chat request endpoint", record.endpoint)
	row["models"] = _field(panel, "Model IDs (comma-separated; not display names)", ", ".join(record.models))
	row["default_model"] = _field(panel, "Default model ID", record.default_model)
	row["models_path"] = _field(panel, "Optional model discovery path (e.g. /v1/models or /api/tags)", record.models_path)
	row["key"] = _field(panel, "API key (optional unless required below)", key, true)
	row["requires_key"] = _toggle(panel, "Require an API key", record.requires_key)
	row["native_tools"] = _toggle(panel, "Model supports native tool calls (OpenAI / Anthropic only)", record.native_tools)
	var native_tools: CheckBox = row.native_tools
	native_tools.disabled = record.format == "ollama"
	if native_tools.disabled:
		native_tools.button_pressed = false
	format.item_selected.connect(func(index: int):
		native_tools.disabled = Registry.FORMATS[index] == "ollama"
		if native_tools.disabled:
			native_tools.button_pressed = false
	)
	row["vision"] = _toggle(panel, "Model supports PNG image input", record.vision)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	var test := Button.new()
	test.text = "Test connection"
	test.pressed.connect(func(): _test(row, test))
	buttons.add_child(test)
	var remove := Button.new()
	remove.text = "Remove provider"
	remove.pressed.connect(func():
		if _busy:
			_status.text = "Wait for the connection test to finish before removing a provider."
			return
		_rows.erase(row)
		panel.queue_free()
	)
	buttons.add_child(remove)
	_rows.append(row)

func _record(row: Dictionary) -> Dictionary:
	var models: Array = []
	for model in row.models.text.split(",", false):
		models.append(model.strip_edges())
	return {
		"id": row.id, "name": row.name.text, "format": Registry.FORMATS[row.format.selected],
		"endpoint": row.endpoint.text, "models": models, "default_model": row.default_model.text,
		"models_path": row.models_path.text, "requires_key": row.requires_key.button_pressed,
		"native_tools": row.native_tools.button_pressed, "vision": row.vision.button_pressed,
	}

func collect() -> Dictionary:
	if _busy:
		return {"ok": false, "error": "Wait for the connection test to finish before saving."}
	var records: Array = []
	var keys: Dictionary = {}
	for row in _rows:
		var checked := Registry.validate(_record(row))
		if not checked.ok:
			_status.text = checked.error
			return checked
		var key: String = row.key.text.strip_edges()
		if key.contains("\n") or key.contains("\r"):
			_status.text = "API keys must not contain line breaks."
			return {"ok": false, "error": _status.text}
		records.append(checked.record)
		keys[row.id] = key
	return {"ok": true, "records": records, "keys": keys}

func show_error(message: String) -> void:
	_status.text = message

func _test(row: Dictionary, button: Button) -> void:
	if _busy:
		return
	var checked := Registry.validate(_record(row))
	if not checked.ok:
		_status.text = checked.error
		return
	var p := Providers.custom_provider_info(checked.record)
	var req := Providers.build_custom_request(p, p.default_model, "Reply briefly.", [], "Reply with OK.", row.key.text.strip_edges())
	if req.has("error"):
		_status.text = req.error
		return
	var body: Dictionary = JSON.parse_string(req.body)
	body["stream"] = false
	if p.protocol == "openai" or p.protocol == "claude":
		body["max_tokens"] = 16
	if p.protocol == "ollama":
		body["options"]["num_predict"] = 16
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.body_size_limit = 1024 * 1024
	add_child(http)
	_busy = true
	button.disabled = true
	_status.text = "Testing " + p.display_name + "..."
	var err := http.request(Providers.request_url(p, req), PackedStringArray(req.headers), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_TIMEOUT:
			_status.text = "Connection test timed out after 20 seconds."
		elif response[0] != HTTPRequest.RESULT_SUCCESS:
			_status.text = "Connection test failed (transport result %d)." % response[0]
		elif response[1] < 200 or response[1] >= 300:
			_status.text = "Connection test returned HTTP %d. Check endpoint, key and model ID." % response[1]
		else:
			var raw: String = response[3].get_string_from_utf8()
			if not JSON.parse_string(raw) is Dictionary or Providers.extract_response_text(p.protocol, raw).strip_edges().is_empty():
				_status.text = "Endpoint responded, but returned no compatible assistant text."
			else:
				_status.text = "Connection test passed: " + p.display_name
	else:
		_status.text = "Connection test could not start: " + error_string(err)
	http.queue_free()
	button.disabled = false
	_busy = false
