extends RefCounted
class_name GDAI

static var _enabled: bool = false
static var _config: Dictionary = {}
static var _provider = null
static var _last_error: String = ""
static var _provider_map: Dictionary = {
	"openai": {
		"script": "res://addons/visual_gasic/gdai_openai_provider.gd",
		"display_name": "OpenAI",
		"description": "OpenAI-compatible hosted API endpoint. Requires an API key.",
		"requires_api_key": true,
		"default_endpoint": "https://api.openai.com/v1",
		"default_model": "gpt-4.1-mini",
		"help_url": "https://platform.openai.com/docs/api-reference",
	},
	"local": {
		"script": "res://addons/visual_gasic/gdai_local_provider.gd",
		"display_name": "Local LLM",
		"description": "Local OpenAI-compatible endpoint. API key is optional for local deployments.",
		"requires_api_key": false,
		"default_endpoint": "http://127.0.0.1:8000/v1",
		"default_model": "gpt-4o-mini",
		"help_url": "",
	},
}

const PROJECT_SETTINGS_PREFIX: String = "vg/gdai/"
const PROJECT_SETTINGS_DEFAULTS: Dictionary = {
	"enabled": true,
	"provider": "openai",
	"api_key": "",
	"endpoint": "https://api.openai.com/v1",
	"model": "gpt-4.1-mini",
	"embedding_model": "text-embedding-3-large",
	"temperature": 0.7,
	"max_tokens": 256,
	"top_p": 1.0,
	"n": 1,
	"timeout_ms": 15000,
}

static func initialize(config: Dictionary) -> void:
	var normalized = config.duplicate(true)
	normalized["provider"] = String(normalized.get("provider", "openai")).to_lower()

	var provider_info = get_provider_info(normalized["provider"])
	if provider_info.size() == 0:
		_enabled = false
		_set_last_error("GDAI: Unknown provider '%s'" % normalized["provider"])
		return

	for key in ["endpoint", "model", "embedding_model"]:
		if not normalized.has(key) or String(normalized[key]).strip_edges() == "":
			normalized[key] = provider_info.get("default_%s" % key, normalized.get(key, ""))

	_config = normalized.duplicate(true)
	_enabled = bool(_config.get("enabled", true))

	if not _enabled:
		_provider = null
		_set_last_error("")
		return

	var validation = validate_config(_config)
	if not validation.get("valid", false):
		_enabled = false
		_provider = null
		_set_last_error(validation.get("error", "Invalid GDAI configuration"))
		return

	var provider_id = String(_config.get("provider", "openai")).to_lower()
	_provider = _create_provider(provider_id)
	if _provider == null:
		_enabled = false
		if _last_error == "":
			_set_last_error("GDAI: No provider registered for '%s'" % provider_id)
		return

	_provider.initialize(_config)
	_set_last_error("")

static func validate_config(config: Dictionary) -> Dictionary:
	var provider_id = String(config.get("provider", "openai")).to_lower()
	var provider_info = get_provider_info(provider_id)
	if provider_info.size() == 0:
		return {"valid": false, "error": "Unknown provider '%s'" % provider_id}

	var endpoint = String(config.get("endpoint", provider_info.get("default_endpoint", ""))).strip_edges()
	if endpoint == "":
		return {"valid": false, "error": "Endpoint cannot be empty."}

	if bool(provider_info.get("requires_api_key", true)):
		var api_key = String(config.get("api_key", "")).strip_edges()
		if api_key == "":
			return {"valid": false, "error": "API key is required for %s." % provider_info.get("display_name", provider_id)}

	return {"valid": true}

static func load_project_settings() -> Dictionary:
	var config := {}
	for key in PROJECT_SETTINGS_DEFAULTS.keys():
		var path := PROJECT_SETTINGS_PREFIX + String(key)
		if ProjectSettings.has_setting(path):
			config[key] = ProjectSettings.get_setting(path, PROJECT_SETTINGS_DEFAULTS[key])
		else:
			config[key] = PROJECT_SETTINGS_DEFAULTS[key]
			ProjectSettings.set_initial_value(path, PROJECT_SETTINGS_DEFAULTS[key])
	return config

static func initialize_from_project_settings() -> void:
	initialize(load_project_settings())

static func save_project_settings(config: Dictionary) -> void:
	for key in PROJECT_SETTINGS_DEFAULTS.keys():
		if config.has(key):
			ProjectSettings.set_setting(PROJECT_SETTINGS_PREFIX + String(key), config[key])
	ProjectSettings.save()

static func get_last_error() -> String:
	return _last_error

static func has_error() -> bool:
	return _last_error != ""

static func is_enabled() -> bool:
	return _enabled and _provider != null

static func complete(prompt: String, options: Dictionary = {}) -> String:
	if not is_enabled():
		return ""
	var result = await _provider.complete(prompt, options)
	return _unwrap_response(result, "")

static func chat(messages: Array, options: Dictionary = {}) -> String:
	if not is_enabled():
		return ""
	var result = await _provider.chat(messages, options)
	return _unwrap_response(result, "")

static func embed(text: String, options: Dictionary = {}) -> Array:
	if not is_enabled():
		return []
	var result = await _provider.embed(text, options)
	return _unwrap_response(result, [])

static func generate_image(prompt: String, options: Dictionary = {}) -> Dictionary:
	if not is_enabled():
		return {}
	var result = await _provider.generate_image(prompt, options)
	return _unwrap_response(result, {})

static func get_config() -> Dictionary:
	return _config.duplicate(true)

static func set_config(config: Dictionary) -> void:
	initialize(config)

static func register_provider(provider_id: String, script_path: String, metadata: Dictionary = {}) -> void:
	var id = provider_id.to_lower()
	var entry: Dictionary = {
		"script": script_path,
		"display_name": String(metadata.get("display_name", provider_id)).strip_edges(),
		"description": String(metadata.get("description", "")).strip_edges(),
		"requires_api_key": bool(metadata.get("requires_api_key", true)),
		"default_endpoint": String(metadata.get("default_endpoint", "")),
		"default_model": String(metadata.get("default_model", "")),
		"help_url": String(metadata.get("help_url", "")),
	}
	_provider_map[id] = entry

static func supported_providers() -> Array:
	var keys = _provider_map.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	return keys

static func get_provider_info(provider_id: String) -> Dictionary:
	var id = provider_id.to_lower()
	if not _provider_map.has(id):
		return {}
	return _provider_map[id].duplicate(true)

static func _unwrap_response(result: Variant, default_value: Variant) -> Variant:
	if result is Dictionary and result.has("error"):
		_set_last_error(String(result.get("error", "Unknown provider error")))
		return default_value
	_set_last_error("")
	return result

static func _create_provider(provider_id: String):
	var info = get_provider_info(provider_id)
	if info.size() == 0:
		return null
	var path = String(info.get("script", ""))
	if path == "":
		push_warning("GDAI: Provider '%s' has no script path." % provider_id)
		return null
	var script = load(path)
	if script == null:
		_set_last_error("GDAI: Failed to load provider script '%s'" % path)
		push_warning("GDAI: Failed to load provider script '%s'" % path)
		return null
	return script.new()

static func _set_last_error(message: String) -> void:
	_last_error = message
