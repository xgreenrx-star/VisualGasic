@tool
extends SceneTree

## GDAI unit tests.
## Run from project root:
##   cd /home/Commodore/Documents/VisualGasic && ./Godot_v4.6.1-stable_linux.x86_64 --headless --path . --script res://tests/test_gdai.gd
##
## Or copy this file into test_proj/ and run:
##   cd test_proj && ../Godot_v4.6.1-stable_linux.x86_64 --headless --script res://test_gdai.gd

var GDAI = null
var _failed := 0
var _passed := 0

func _initialize() -> void:
	print("=== GDAI Tests ===")
	GDAI = load("res://addons/visual_gasic/gdai.gd")
	if GDAI == null:
		_fail("GDAI.load", "Could not load res://addons/visual_gasic/gdai.gd")
		quit(1)
	_test_validate_config_ok()
	_test_validate_config_missing_endpoint()
	_test_validate_config_missing_api_key()
	_test_register_provider_custom_provider()
	_test_initialize_with_invalid_provider_script()
	_test_initialize_from_project_settings()
	print("=== Done: %d passed, %d failed ===" % [_passed, _failed])
	print("RESULTS: %d/%d passed, %d failed" % [_passed, _passed + _failed, _failed])
	quit(1 if _failed > 0 else 0)

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

func _test_validate_config_ok() -> void:
	var config := {
		"enabled": true,
		"provider": "openai",
		"api_key": "sk-test",
		"endpoint": "https://api.openai.com/v1",
		"model": "gpt-4.1-mini",
	}
	var validation = GDAI.validate_config(config)
	_expect("GDAI.validate_config accepts valid OpenAI config",
		validation.get("valid", false),
		"validation=%s" % str(validation))

func _test_validate_config_missing_endpoint() -> void:
	var config := {
		"enabled": true,
		"provider": "openai",
		"api_key": "sk-test",
		"endpoint": "",
		"model": "gpt-4.1-mini",
	}
	var validation = GDAI.validate_config(config)
	_expect("GDAI.validate_config rejects empty endpoint",
		not validation.get("valid", false) and validation.get("error", "").find("Endpoint") >= 0,
		"validation=%s" % str(validation))

func _test_validate_config_missing_api_key() -> void:
	var config := {
		"enabled": true,
		"provider": "openai",
		"endpoint": "https://api.openai.com/v1",
		"model": "gpt-4.1-mini",
	}
	var validation = GDAI.validate_config(config)
	_expect("GDAI.validate_config rejects missing API key for OpenAI",
		not validation.get("valid", false) and validation.get("error", "").find("API key") >= 0,
		"validation=%s" % str(validation))

func _test_register_provider_custom_provider() -> void:
	var provider_id = "__test_local_provider"
	GDAI.register_provider(provider_id, "res://addons/visual_gasic/gdai_provider.gd", {
		"display_name": "Test Local Provider",
		"description": "Local provider for test coverage.",
		"requires_api_key": false,
		"default_endpoint": "http://127.0.0.1:8000/v1",
		"default_model": "test-model",
	})
	var info = GDAI.get_provider_info(provider_id)
	_expect("GDAI.register_provider stores provider metadata",
		info.size() > 0 and info.get("display_name", "") == "Test Local Provider" and info.get("requires_api_key", true) == false,
		"info=%s" % str(info))

	var config := {
		"enabled": true,
		"provider": provider_id,
		"endpoint": "http://127.0.0.1:8000/v1",
		"model": "test-model",
	}
	GDAI.initialize(config)
	_expect("GDAI.initialize creates provider instance from registered script",
		GDAI.is_enabled() and GDAI.get_config().get("provider", "") == provider_id,
		"error=%s" % GDAI.get_last_error())
	GDAI._provider_map.erase(provider_id)

func _test_initialize_with_invalid_provider_script() -> void:
	var provider_id = "__test_invalid_provider"
	GDAI.register_provider(provider_id, "res://addons/visual_gasic/missing_provider.gd", {
		"display_name": "Invalid Provider",
		"description": "Provider with a missing script path.",
		"requires_api_key": false,
		"default_endpoint": "http://127.0.0.1:8000/v1",
		"default_model": "test-model",
	})
	var config := {
		"enabled": true,
		"provider": provider_id,
		"endpoint": "http://127.0.0.1:8000/v1",
		"model": "test-model",
	}
	GDAI.initialize(config)
	_expect("GDAI.initialize fails for invalid provider script path",
		not GDAI.is_enabled() and GDAI.get_last_error().find("Failed to load provider script") >= 0,
		"error=%s" % GDAI.get_last_error())
	GDAI._provider_map.erase(provider_id)

func _test_initialize_from_project_settings() -> void:
	var keys = ["enabled", "provider", "api_key", "endpoint", "model", "embedding_model", "temperature", "max_tokens", "top_p", "n", "timeout_ms"]
	var original_values = {}
	for key in keys:
		var path = "vg/gdai/" + key
		if ProjectSettings.has_setting(path):
			original_values[key] = ProjectSettings.get_setting(path)
		else:
			original_values[key] = null
	ProjectSettings.set_setting("vg/gdai/enabled", true)
	ProjectSettings.set_setting("vg/gdai/provider", "openai")
	ProjectSettings.set_setting("vg/gdai/api_key", "sk-test")
	ProjectSettings.set_setting("vg/gdai/endpoint", "https://api.openai.com/v1")
	ProjectSettings.set_setting("vg/gdai/model", "gpt-4.1-mini")
	ProjectSettings.set_setting("vg/gdai/embedding_model", "text-embedding-3-large")
	ProjectSettings.set_setting("vg/gdai/temperature", 0.7)
	ProjectSettings.set_setting("vg/gdai/max_tokens", 256)
	ProjectSettings.set_setting("vg/gdai/top_p", 1.0)
	ProjectSettings.set_setting("vg/gdai/n", 1)
	ProjectSettings.set_setting("vg/gdai/timeout_ms", 15000)
	GDAI.initialize_from_project_settings()
	var config = GDAI.get_config()
	_expect("GDAI.initialize_from_project_settings loads project settings",
		config.get("provider", "") == "openai" and GDAI.is_enabled(),
		"config=%s" % str(config))
	for key in keys:
		var path = "vg/gdai/" + key
		if original_values[key] != null:
			ProjectSettings.set_setting(path, original_values[key])
