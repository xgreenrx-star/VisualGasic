@tool
extends RefCounted

const SETTING := "visual_gasic/ai/custom_providers"
const FORMATS := ["openai", "claude", "ollama"]

static func validate(record: Dictionary) -> Dictionary:
	var id := str(record.get("id", ""))
	var id_regex := RegEx.new()
	id_regex.compile("^custom_[a-z0-9_]+$")
	if id_regex.search(id) == null:
		return {"ok": false, "error": "Custom provider ID must start with custom_ and contain lowercase letters, digits or underscores."}
	var name := str(record.get("name", "")).strip_edges()
	if name.is_empty() or name.contains("\n") or name.contains("\r"):
		return {"ok": false, "error": "Enter a single-line provider name."}
	var protocol := str(record.get("format", ""))
	if not protocol in FORMATS:
		return {"ok": false, "error": "Choose OpenAI-compatible, Anthropic-compatible or Ollama."}
	for field in ["requires_key", "native_tools", "vision"]:
		if record.has(field) and not record[field] is bool:
			return {"ok": false, "error": field + " must be true or false."}
	var endpoint := str(record.get("endpoint", "")).strip_edges()
	var url_regex := RegEx.new()
	url_regex.compile("^(https?)://(\\[[0-9A-Fa-f:]+\\]|[A-Za-z0-9][A-Za-z0-9._-]*)(?::([0-9]+))?(/[^\\s?#]*)$")
	var url := url_regex.search(endpoint)
	if url == null:
		return {"ok": false, "error": "Enter a full http:// or https:// request endpoint, including its path; no credentials, query or fragment."}
	var tls := url.get_string(1) == "https"
	var port := int(url.get_string(3)) if not url.get_string(3).is_empty() else (443 if tls else 80)
	if port < 1 or port > 65535:
		return {"ok": false, "error": "Endpoint port must be between 1 and 65535."}
	var models: Array = []
	var raw_models: Variant = record.get("models", [])
	if not raw_models is Array:
		return {"ok": false, "error": "Model IDs must be an array."}
	for value in raw_models:
		if not value is String or value.strip_edges().is_empty() or value.contains("\n") or value.contains("\r"):
			return {"ok": false, "error": "Enter nonempty, single-line model IDs."}
		var model: String = value.strip_edges()
		if not models.has(model):
			models.append(model)
	var default_model := str(record.get("default_model", "")).strip_edges()
	if models.is_empty() or not models.has(default_model):
		return {"ok": false, "error": "Enter at least one model ID and choose a default from that list."}
	var models_path := str(record.get("models_path", "")).strip_edges()
	var path_regex := RegEx.new()
	path_regex.compile("^/[^\\s?#]*$")
	if not models_path.is_empty() and path_regex.search(models_path) == null:
		return {"ok": false, "error": "Model discovery path must start with / and have no query, fragment or whitespace; leave empty to disable."}
	return {"ok": true, "record": {
		"id": id, "name": name, "format": protocol, "endpoint": endpoint,
		"models": models, "default_model": default_model, "models_path": models_path,
		"requires_key": bool(record.get("requires_key", protocol == "claude")),
		"native_tools": bool(record.get("native_tools", false)),
		"vision": bool(record.get("vision", false)),
	}, "host": url.get_string(2), "port": port, "path": url.get_string(4), "tls": tls}

static func load_records(settings: Object) -> Array:
	if settings == null or not settings.has_setting(SETTING):
		return []
	var raw: Variant = settings.get_setting(SETTING)
	if raw == "":
		return []
	if not raw is String:
		push_error("Custom AI provider settings must contain a JSON array.")
		return []
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Array:
		push_error("Custom AI provider settings contain invalid JSON or are not an array.")
		return []
	var records: Array = []
	var ids: Dictionary = {}
	for record in parsed:
		if not record is Dictionary:
			push_error("Custom AI provider entry must be an object.")
			continue
		var checked := validate(record)
		if not checked.ok:
			push_error("Invalid custom AI provider: " + checked.error)
			continue
		if ids.has(checked.record.id):
			push_error("Duplicate custom AI provider ID: " + checked.record.id)
			continue
		ids[checked.record.id] = true
		records.append(checked.record)
	return records

static func save_records(settings: Object, records: Array) -> Dictionary:
	if settings == null:
		return {"ok": false, "error": "Custom providers can only be saved in the Godot editor."}
	var normalized: Array = []
	var ids: Dictionary = {}
	for record in records:
		if not record is Dictionary:
			return {"ok": false, "error": "Custom provider entry must be an object."}
		var checked := validate(record)
		if not checked.ok:
			return checked
		if ids.has(checked.record.id):
			return {"ok": false, "error": "Duplicate custom provider ID: " + checked.record.id}
		ids[checked.record.id] = true
		normalized.append(checked.record)
	settings.set_setting(SETTING, JSON.stringify(normalized))
	return {"ok": true}
