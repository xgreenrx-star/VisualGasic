@tool
extends RefCounted
## AI Provider abstraction layer — unified interface for Ollama, OpenAI, Claude, Gemini,
## DeepSeek, Qwen (DashScope), Codeium (Windsurf), and Amazon Q Developer.
## Each provider converts VisualGasic's system prompt + conversation history into the
## appropriate API format and streams responses token-by-token.

# ─── Provider Registry ──────────────────────────────────────────────────────
# Each provider entry describes how to connect and authenticate.

class ProviderInfo:
	var id: String             # "ollama", "openai", "claude", "gemini"
	var display_name: String   # "Ollama (Local)", "OpenAI", etc.
	var is_local: bool         # true for Ollama (no API key needed)
	var api_host: String       # hostname
	var api_port: int          # port (443 for HTTPS)
	var api_path: String       # endpoint path
	var use_tls: bool          # true for cloud providers
	var models: Array          # available model names
	var default_model: String  # default selection

static func get_providers() -> Array:
	var providers: Array = []

	# ── Ollama (Local) ──
	var ollama := ProviderInfo.new()
	ollama.id = "ollama"
	ollama.display_name = "🏠 Ollama (Local)"
	ollama.is_local = true
	ollama.api_host = "127.0.0.1"
	ollama.api_port = 11434
	ollama.api_path = "/api/generate"
	ollama.use_tls = false
	ollama.models = ["qwen2.5-coder:7b", "deepseek-coder-v2:16b", "codellama:7b", "phi3:mini", "llama3.1:8b", "gemma2:9b"]
	ollama.default_model = "qwen2.5-coder:7b"
	providers.append(ollama)

	# ── OpenAI ──
	var openai := ProviderInfo.new()
	openai.id = "openai"
	openai.display_name = "🟢 OpenAI"
	openai.is_local = false
	openai.api_host = "api.openai.com"
	openai.api_port = 443
	openai.api_path = "/v1/chat/completions"
	openai.use_tls = true
	openai.models = ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
	openai.default_model = "gpt-4o-mini"
	providers.append(openai)

	# ── Anthropic Claude ──
	var claude := ProviderInfo.new()
	claude.id = "claude"
	claude.display_name = "🟣 Claude"
	claude.is_local = false
	claude.api_host = "api.anthropic.com"
	claude.api_port = 443
	claude.api_path = "/v1/messages"
	claude.use_tls = true
	claude.models = ["claude-sonnet-4-5", "claude-haiku-4-5", "claude-opus-4-5"]
	claude.default_model = "claude-sonnet-4-5"
	providers.append(claude)

	# ── Google Gemini ──
	var gemini := ProviderInfo.new()
	gemini.id = "gemini"
	gemini.display_name = "🔵 Gemini"
	gemini.is_local = false
	gemini.api_host = "generativelanguage.googleapis.com"
	gemini.api_port = 443
	gemini.api_path = "/v1beta/models/{model}:streamGenerateContent"
	gemini.use_tls = true
	gemini.models = ["gemini-3.6-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro"]
	gemini.default_model = "gemini-3.6-flash"
	providers.append(gemini)

	# ── DeepSeek ──
	# DeepSeek Chat API is OpenAI-compatible — reuses the "openai" code path
	# in build_request / parse_stream_line / function-calling adapter.
	# Models: deepseek-chat (V2 flagship), deepseek-coder (coding-optimised).
	var deepseek := ProviderInfo.new()
	deepseek.id = "deepseek"
	deepseek.display_name = "🔴 DeepSeek"
	deepseek.is_local = false
	deepseek.api_host = "api.deepseek.com"
	deepseek.api_port = 443
	deepseek.api_path = "/v1/chat/completions"
	deepseek.use_tls = true
	deepseek.models = ["deepseek-chat", "deepseek-coder"]
	deepseek.default_model = "deepseek-chat"
	providers.append(deepseek)

	# ── Qwen (Alibaba Cloud DashScope) ──
	# Qwen models via DashScope API, using the OpenAI-compatible endpoint at
	# /compatible-mode/v1/chat/completions. Also available locally via Ollama.
	# Coding-optimised models are listed first (32B, 14B, 7B), then general.
	var qwen := ProviderInfo.new()
	qwen.id = "qwen"
	qwen.display_name = "🟠 Qwen (DashScope)"
	qwen.is_local = false
	qwen.api_host = "dashscope.aliyuncs.com"
	qwen.api_port = 443
	qwen.api_path = "/compatible-mode/v1/chat/completions"
	qwen.use_tls = true
	qwen.models = ["qwen2.5-coder-32b-instruct", "qwen2.5-coder-14b-instruct", "qwen2.5-coder-7b-instruct", "qwen-max", "qwen-plus", "qwen-turbo"]
	qwen.default_model = "qwen2.5-coder-32b-instruct"
	providers.append(qwen)

	# ── Codeium (Windsurf) ──
	# Codeium chat completions API — OpenAI-compatible format.
	# Free tier available; enterprise keys from codeium.com/profile.
	var codeium := ProviderInfo.new()
	codeium.id = "codeium"
	codeium.display_name = "🌊 Codeium (Windsurf)"
	codeium.is_local = false
	codeium.api_host = "generativelanguage.codeium.com"
	codeium.api_port = 443
	codeium.api_path = "/v1/chat/completions"
	codeium.use_tls = true
	codeium.models = ["windsurf-claude-3.5-sonnet", "windsurf-gpt-4o", "windsurf-gemini-pro"]
	codeium.default_model = "windsurf-claude-3.5-sonnet"
	providers.append(codeium)

	# ── Amazon Q Developer ──
	# Amazon Q Developer via Bedrock Access Gateway (OpenAI-compatible proxy).
	# Users configure their own gateway host/port in EditorSettings.
	# Default: localhost:8080 for a local bedrock-access-gateway instance.
	# Models: Amazon Bedrock models (Claude, Nova Lite, Nova Pro).
	var amazonq := ProviderInfo.new()
	amazonq.id = "amazonq"
	amazonq.display_name = "🟧 Amazon Q Developer"
	amazonq.is_local = false
	amazonq.api_host = "localhost"
	amazonq.api_port = 8080
	amazonq.api_path = "/v1/chat/completions"
	amazonq.use_tls = false
	amazonq.models = ["anthropic.claude-3-5-sonnet-20241022-v2:0", "amazon.nova-pro-v1:0", "amazon.nova-lite-v1:0"]
	amazonq.default_model = "anthropic.claude-3-5-sonnet-20241022-v2:0"
	providers.append(amazonq)

	# ── Cursor (Composer via SDK) ──
	# Optional Tier 2 — spawns cursor-sdk subprocess; requires CURSOR_API_KEY + pip install cursor-sdk.
	var cursor := ProviderInfo.new()
	cursor.id = "cursor"
	cursor.display_name = "⬡ Cursor (Composer)"
	cursor.is_local = false
	cursor.api_host = ""
	cursor.api_port = 0
	cursor.api_path = ""
	cursor.use_tls = false
	cursor.models = ["composer-2.5", "composer-2.5-fast"]
	cursor.default_model = "composer-2.5"
	providers.append(cursor)

	# Apply cached model overrides from EditorSettings (if any)
	var es := _editor_settings()
	if es != null:
		for p in providers:
			var cached := _load_cached_models(es, p.id)
			if not cached.is_empty():
				p.models = filter_provider_model_list(p.id, cached)
				if p.models.find(p.default_model) < 0:
					p.default_model = pick_default_model(p.id, p.models)

	return providers

## Drop stale cached model ids from EditorSettings (safe to call once at startup).
static func prune_cached_model_lists() -> void:
	var es := _editor_settings()
	if es == null:
		return
	for pid in ["gemini", "openai", "claude", "deepseek", "qwen", "codeium", "amazonq", "cursor", "ollama"]:
		var cached := _load_cached_models(es, pid)
		if cached.is_empty():
			continue
		var filtered := filter_provider_model_list(pid, cached)
		if filtered.size() != cached.size():
			_save_cached_models(es, pid, filtered)

static func is_cursor_provider(provider_id: String) -> bool:
	return provider_id == "cursor"


static func find_provider(provider_id: String) -> ProviderInfo:
	for p in get_providers():
		if p.id == provider_id:
			return p
	return null

## Return the effective ProviderInfo for a given provider ID, applying any
## user-configured overrides from EditorSettings (e.g. Amazon Q host/port).
static func get_effective_provider(provider_id: String) -> ProviderInfo:
	var p := find_provider(provider_id)
	if p == null:
		return null
	# Amazon Q uses configurable host/port from EditorSettings.
	if provider_id == "amazonq":
		var es := _editor_settings()
		if es != null:
			var host_val = es.get_setting("visual_gasic/ai/amazonq_host")
			if host_val != null:
				p.api_host = str(host_val)
			var port_val = es.get_setting("visual_gasic/ai/amazonq_port")
			if port_val != null:
				p.api_port = int(port_val)
			var tls_val = es.get_setting("visual_gasic/ai/amazonq_use_tls")
			if tls_val != null:
				p.use_tls = bool(tls_val)
	return p


# ─── API Key Management ─────────────────────────────────────────────────────
# Keys are stored in Godot's EditorSettings under visual_gasic/ai/* so they
# appear in Editor > Editor Settings > Visual Gasic / AI and are shared
# across all projects without any custom config files.
#
# EditorSettings path map:
#   visual_gasic/ai/openai_key         — OpenAI API key
#   visual_gasic/ai/claude_key         — Anthropic Claude API key
#   visual_gasic/ai/gemini_key         — Google Gemini API key
#   visual_gasic/ai/deepseek_key       — DeepSeek API key
#   visual_gasic/ai/qwen_key           — Qwen (DashScope) API key
#   visual_gasic/ai/codeium_key      — Codeium (Windsurf) API key
#   visual_gasic/ai/amazonq_key      — Amazon Q Developer API key
#   visual_gasic/ai/amazonq_host     — Amazon Q Bedrock Access Gateway host
#   visual_gasic/ai/amazonq_port     — Amazon Q Bedrock Access Gateway port
#   visual_gasic/ai/amazonq_use_tls  — Amazon Q TLS flag
#   visual_gasic/ai/cursor_key       — Cursor API key (Composer via SDK)
#   visual_gasic/ai/preferred_provider — last-used provider id
#
# Registration: visual_gasic_plugin.gd _enter_tree() calls
# _register_editor_setting() for all paths with defaults and hints.
#
# One-time migration: on first key access after an upgrade, any values found
# in the old per-user ai_keys.cfg (or user://vg_ai_keys.cfg) are copied into
# EditorSettings. The old file is left in place (non-destructive).

const _LEGACY_KEYS_PATH := "user://vg_ai_keys.cfg"

## Return the EditorSettings singleton, or null when running outside the editor.
static func _editor_settings() -> Object:
	if not Engine.is_editor_hint():
		return null
	return EditorInterface.get_editor_settings()

## Compute the OS-specific path used by the old central ConfigFile (migration only).
static func _legacy_central_path() -> String:
	var dir := ""
	match OS.get_name():
		"Windows", "UWP":
			var appdata := OS.get_environment("APPDATA")
			if not appdata.is_empty():
				dir = appdata + "/VisualGasic"
		"macOS":
			var home_mac := OS.get_environment("HOME")
			if not home_mac.is_empty():
				dir = home_mac + "/Library/Application Support/VisualGasic"
		_:
			var xdg := OS.get_environment("XDG_CONFIG_HOME")
			if xdg.is_empty():
				var home := OS.get_environment("HOME")
				if not home.is_empty():
					xdg = home + "/.config"
			if not xdg.is_empty():
				dir = xdg + "/visual_gasic"
	if dir.is_empty():
		return _LEGACY_KEYS_PATH
	return dir + "/ai_keys.cfg"

## One-time migration from the old per-user ai_keys.cfg into EditorSettings.
## Skipped after first run via the migrated_to_editor_settings sentinel.
static func _migrate_legacy_to_editor_settings_if_needed(es: Object) -> void:
	if es.get_setting("visual_gasic/ai/migrated_to_editor_settings"):
		return
	var cfg := ConfigFile.new()
	var loaded := cfg.load(_legacy_central_path()) == OK or cfg.load(_LEGACY_KEYS_PATH) == OK
	if loaded:
		for pid in ["openai", "claude", "gemini"]:
			var val: String = cfg.get_value("api_keys", pid, "")
			if not val.is_empty():
				var current: String = es.get_setting("visual_gasic/ai/" + pid + "_key")
				if current.is_empty():
					es.set_setting("visual_gasic/ai/" + pid + "_key", val)
		var pref: String = cfg.get_value("preferences", "provider", "")
		if not pref.is_empty():
			var current_pref: String = es.get_setting("visual_gasic/ai/preferred_provider")
			if current_pref == "ollama":
				es.set_setting("visual_gasic/ai/preferred_provider", pref)
	es.set_setting("visual_gasic/ai/migrated_to_editor_settings", true)

static func load_api_key(provider_id: String) -> String:
	var es := _editor_settings()
	if es == null:
		return ""
	_migrate_legacy_to_editor_settings_if_needed(es)
	return es.get_setting("visual_gasic/ai/" + provider_id + "_key")

static func save_api_key(provider_id: String, key: String) -> void:
	var es := _editor_settings()
	if es == null:
		return
	es.set_setting("visual_gasic/ai/" + provider_id + "_key", key)

static func load_preferred_provider() -> String:
	var es := _editor_settings()
	if es == null:
		return "ollama"
	_migrate_legacy_to_editor_settings_if_needed(es)
	return es.get_setting("visual_gasic/ai/preferred_provider")

static func save_preferred_provider(provider_id: String) -> void:
	var es := _editor_settings()
	if es == null:
		return
	es.set_setting("visual_gasic/ai/preferred_provider", provider_id)


# ─── Model Cache Management ──────────────────────────────────────────────────
# Cached model lists live in EditorSettings as JSON arrays so the user's
# model selection survives restarts without re-fetching.
#
# EditorSettings path map:
#   visual_gasic/ai/<id>_cached_models    — JSON array of model name strings
#   visual_gasic/ai/<id>_models_timestamp — Unix timestamp of last refresh

## Load cached model names for a provider from EditorSettings.
## Returns an empty array if nothing is cached.
static func _load_cached_models(es: Object, provider_id: String) -> Array:
	var raw: Variant = es.get_setting('visual_gasic/ai/' + provider_id + '_cached_models')
	if raw == null or typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return []
	var parsed = JSON.parse_string(String(raw))
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed

## Save a model list to EditorSettings cache.
static func _save_cached_models(es: Object, provider_id: String, models: Array) -> void:
	es.set_setting('visual_gasic/ai/' + provider_id + '_cached_models', JSON.stringify(models))
	es.set_setting('visual_gasic/ai/' + provider_id + '_models_timestamp', str(Time.get_unix_time_from_system()))

## Strip the "models/" prefix Gemini returns in list responses.
static func _normalize_gemini_model_name(raw_name: String) -> String:
	var name := raw_name.strip_edges()
	if name.begins_with("models/"):
		name = name.substr(7)
	return name

## True when a Gemini catalog entry can chat (ignores legacy/experimental pruning).
static func _gemini_catalog_chat_model(model_name: String, supported_methods: Array) -> bool:
	var name := _normalize_gemini_model_name(model_name)
	if name.is_empty():
		return false
	if not supported_methods.is_empty():
		var can_chat := false
		for method in supported_methods:
			var ms := str(method)
			if ms == "generateContent" or ms == "streamGenerateContent":
				can_chat = true
				break
		if not can_chat:
			return false
	var lower := name.to_lower()
	if not lower.begins_with("gemini-"):
		return false
	if lower.contains("embed") or lower.contains("imagen") or lower.contains("aqa"):
		return false
	return true

## True when a Gemini model entry supports chat generation (not embed/image-only).
static func is_gemini_chat_model(model_name: String, supported_methods: Array = []) -> bool:
	if not _gemini_catalog_chat_model(model_name, supported_methods):
		return false
	return not is_gemini_legacy_or_experimental(model_name)

## Drop retired Gemini 1.x, unversioned legacy names, and -exp/-preview builds.
static func is_gemini_legacy_or_experimental(model_name: String) -> bool:
	var lower := _normalize_gemini_model_name(model_name).to_lower()
	if lower.is_empty():
		return true
	if lower.contains("-exp") or lower.contains("-preview") or lower.contains("-experimental"):
		return true
	if lower.begins_with("gemini-1."):
		return true
	if lower in ["gemini-pro", "gemini-pro-vision", "gemini-ultra", "gemini-1.0-pro"]:
		return true
	# Only list Gemini 2.x / 3.x chat models in the picker.
	if not (lower.begins_with("gemini-2.") or lower.begins_with("gemini-3.")):
		return true
	return false

## Apply provider-specific cleanup to a cached or live model list.
static func filter_provider_model_list(provider_id: String, models: Array) -> Array:
	if provider_id != "gemini":
		return models.duplicate()
	var out: Array = []
	for m in models:
		var name := str(m)
		if is_gemini_chat_model(name, ["streamGenerateContent"]):
			out.append(name)
	return out

## Clear cached model list for one provider (forces built-in defaults until next refresh).
static func clear_cached_models(provider_id: String) -> void:
	var es := _editor_settings()
	if es == null:
		return
	es.set_setting('visual_gasic/ai/' + provider_id + '_cached_models', "")
	es.set_setting('visual_gasic/ai/' + provider_id + '_models_timestamp', "")

## Synchronous HTTP helper used by refresh / model probes.
static func _http_request_sync(host: String, port: int, use_tls: bool, method: int, path: String,
		headers: PackedStringArray, body: String = "",
		connect_polls: int = 40, body_polls: int = 40) -> Dictionary:
	var http := HTTPClient.new()
	var tls_options = TLSOptions.client(null) if use_tls else null
	var err := http.connect_to_host(host, port, tls_options)
	if err != OK:
		return {'ok': false, 'error': 'Connection failed: ' + error_string(err)}
	for _i in connect_polls:
		http.poll()
		var status := http.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
			http.close()
			return {'ok': false, 'error': 'Could not connect to ' + host + ':' + str(port)}
		OS.delay_msec(100)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return {'ok': false, 'error': 'Timed out connecting to ' + host + ':' + str(port)}
	var req_err := http.request(method, path, headers, body)
	if req_err != OK:
		http.close()
		return {'ok': false, 'error': 'Request failed: ' + error_string(req_err)}
	for _i in body_polls:
		http.poll()
		var status := http.get_status()
		if status == HTTPClient.STATUS_BODY or status == HTTPClient.STATUS_DISCONNECTED:
			break
		OS.delay_msec(100)
	var code := http.get_response_code()
	var body_bytes := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			body_bytes.append_array(chunk)
		else:
			OS.delay_msec(10)
	http.close()
	return {'ok': true, 'code': code, 'body': body_bytes.get_string_from_utf8()}

## Probe whether Gemini will accept generateContent for this model id.
static func probe_gemini_model(model: String, api_key: String) -> bool:
	if api_key.is_empty() or model.is_empty():
		return false
	var path := "/v1beta/models/" + model + ":generateContent?key=" + api_key
	var payload := JSON.stringify({
		"contents": [{"parts": [{"text": "ping"}]}],
		"generationConfig": {"maxOutputTokens": 1},
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var resp: Dictionary = _http_request_sync(
		"generativelanguage.googleapis.com", 443, true,
		HTTPClient.METHOD_POST, path, headers, payload, 30, 30)
	if not resp.get("ok", false):
		return false
	var code: int = int(resp.get("code", 0))
	return code >= 200 and code < 300

## Keep only Gemini models that respond to a minimal generateContent call.
static func validate_gemini_models(candidates: Array, api_key: String) -> Dictionary:
	var valid: Array = []
	var rejected: Array = []
	var sorted: Array = candidates.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var pa := _gemini_validation_priority(str(a))
		var pb := _gemini_validation_priority(str(b))
		if pa == pb:
			return str(a) < str(b)
		return pa < pb)
	for model in sorted:
		var name := str(model)
		if probe_gemini_model(name, api_key):
			valid.append(name)
		else:
			rejected.append(name)
	valid.sort()
	rejected.sort()
	return {'valid': valid, 'rejected': rejected}

static func _gemini_validation_priority(model_name: String) -> int:
	var lower := model_name.to_lower()
	if lower.ends_with("-flash"):
		return 0
	if lower.contains("flash-lite"):
		return 1
	if lower.contains("-pro"):
		return 2
	return 3

## Pick the best default model from a live list (prefers fast chat models).
static func pick_default_model(provider_id: String, models: Array) -> String:
	if models.is_empty():
		return ""
	if provider_id == "gemini":
		var prefs := [
			"gemini-2.0-flash",
			"gemini-2.5-flash-lite",
			"gemini-2.0-flash-lite",
			"gemini-2.5-pro",
			"gemini-2.0-pro",
			"gemini-3.6-flash",
			"gemini-3.5-flash-lite",
		]
		for pref in prefs:
			if models.has(pref):
				return pref
		for m in models:
			var ms := str(m).to_lower()
			if ms.contains("flash") and not ms.contains("preview"):
				return str(m)
		return str(models[0])
	return str(models[0])

## Models present in old_list but absent from new_list (after a refresh).
static func diff_removed_models(old_list: Array, new_list: Array) -> Array:
	var removed: Array = []
	for m in old_list:
		if not new_list.has(m):
			removed.append(m)
	return removed

## Fetch live models from a provider's API and cache the result.
##
## Provider         │ Endpoint                       │ Auth
## ─────────────────┼────────────────────────────────┼─────────────────
## ollama           │ GET /api/tags                  │ none (local)
## openai           │ GET /v1/models                 │ Bearer <key>
## claude           │ GET /v1/models                 │ x-api-key <key>
## gemini           │ GET /v1beta/models             │ ?key=<key> query
## deepseek         │ GET /v1/models                 │ Bearer <key>
## qwen             │ GET /compatible-mode/v1/models │ Bearer <key>
## codeium          │ GET /v1/models                 │ Bearer <key>
## amazonq          │ GET /v1/models                 │ Bearer <key>
##
## Returns {ok: true, models: [...]} on success, or {ok: false, error: "..."}.
static func refresh_models(provider_id: String) -> Dictionary:
	var p := find_provider(provider_id)
	if p == null:
		return {'ok': false, 'error': 'Unknown provider: ' + provider_id}
	if provider_id == "cursor":
		return {'ok': true, 'models': p.models.duplicate(), 'removed': [], 'rejected': []}

	var es := _editor_settings()
	if es == null:
		# Not in editor — can not make HTTP requests (no EditorInterface).
		return {'ok': false, 'error': 'Not running in editor'}

	# Determine endpoint, auth header, and response parser based on provider
	var host := p.api_host
	var port := p.api_port
	var use_tls := p.use_tls
	var path := '/v1/models'
	var headers := PackedStringArray()
	var api_key := load_api_key(provider_id)

	match provider_id:
		'ollama':
			path = '/api/tags'
			host = '127.0.0.1'
			port = 11434
			use_tls = false
			# No auth needed
		'gemini':
			# Gemini uses a key query parameter on the models endpoint
			if api_key.is_empty():
				return {'ok': false, 'error': 'Gemini API key not configured'}
			path = '/v1beta/models?key=' + api_key
		'claude':
			path = '/v1/models'
			if api_key.is_empty():
				return {'ok': false, 'error': 'Claude API key not configured'}
			headers = PackedStringArray(['x-api-key: ' + api_key, 'anthropic-version: 2023-06-01'])
		'amazonq':
			# Amazon Q uses the effective host/port (may be overridden)
			# and has no auth header for local gateway
			pass
		_:
			# openai, deepseek, qwen, codeium — all OpenAI-compatible
			if api_key.is_empty():
				return {'ok': false, 'error': 'API key not configured for ' + provider_id}
			headers = PackedStringArray(['Authorization: Bearer ' + api_key])

	# Make HTTP request
	var http := HTTPClient.new()
	var tls_options = null
	if use_tls:
		tls_options = TLSOptions.client(null)
	var err := http.connect_to_host(host, port, tls_options)
	if err != OK:
		return {'ok': false, 'error': 'Connection failed: ' + error_string(err)}

	# Poll until connected or timeout
	for _attempt in 50:
		http.poll()
		var status := http.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CONNECTION_ERROR:
			http.close()
			return {'ok': false, 'error': 'Could not connect to ' + host + ':' + str(port)}
		OS.delay_msec(100)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return {'ok': false, 'error': 'Timed out connecting to ' + host + ':' + str(port)}

	var req_err := http.request(HTTPClient.METHOD_GET, path, headers)
	if req_err != OK:
		http.close()
		return {'ok': false, 'error': 'Request failed: ' + error_string(req_err)}

	# Poll for response
	for _attempt in 100:
		http.poll()
		var status := http.get_status()
		if status == HTTPClient.STATUS_BODY:
			break
		if status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR:
			http.close()
			return {'ok': false, 'error': 'Connection lost during request'}
		OS.delay_msec(100)

	if http.get_status() != HTTPClient.STATUS_BODY:
		http.close()
		return {'ok': false, 'error': 'Timed out waiting for response'}

	var code := http.get_response_code()
	if code != 200:
		http.close()
		return {'ok': false, 'error': 'API returned HTTP ' + str(code)}

	# Read response body
	var body_bytes := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			body_bytes.append_array(chunk)
		else:
			OS.delay_msec(10)
	http.close()

	var body_str := body_bytes.get_string_from_utf8()
	if body_str.is_empty():
		return {'ok': false, 'error': 'Empty response'}

	var json = JSON.parse_string(body_str)
	if json == null:
		return {'ok': false, 'error': 'Failed to parse JSON response'}

	var old_models := _load_cached_models(es, provider_id)

	# Extract model names — each provider returns a different shape
	var model_names: Array = []
	var rejected: Array = []
	match provider_id:
		'ollama':
			# { models: [{ name: "...", ... }] }
			var models_arr: Array = json.get('models', [])
			for m in models_arr:
				var name = m.get('name', '')
				if not String(name).is_empty():
					model_names.append(name)
		'gemini':
			# { models: [{ name: "models/gemini-...", supportedGenerationMethods: [...] }] }
			var models_arr: Array = json.get('models', [])
			for m in models_arr:
				var name := _normalize_gemini_model_name(String(m.get('name', '')))
				var methods: Array = m.get('supportedGenerationMethods', [])
				if not _gemini_catalog_chat_model(name, methods):
					continue
				if is_gemini_legacy_or_experimental(name):
					rejected.append(name)
				else:
					model_names.append(name)
		'claude':
			# { data: [{ id: "claude-sonnet-4-5", ... }] }
			var data_arr: Array = json.get('data', [])
			for m in data_arr:
				var name = m.get('id', '')
				if not String(name).is_empty():
					model_names.append(name)
		_:
			# OpenAI-compatible: { data: [{ id: "gpt-4o", ... }] }
			var data_arr: Array = json.get('data', [])
			for m in data_arr:
				var name = m.get('id', '')
				if not String(name).is_empty():
					model_names.append(name)

	if model_names.is_empty():
		return {'ok': false, 'error': 'No usable models returned (check API key / provider status)'}

	if provider_id == "gemini":
		var validation: Dictionary = validate_gemini_models(model_names, api_key)
		rejected.append_array(validation.get("rejected", []))
		model_names = validation.get("valid", [])
		if model_names.is_empty():
			return {'ok': false, 'error': 'No Gemini models passed availability probe (API key tier may block all models)'}

	# Sort, replace cache entirely (drops models no longer returned by the API).
	model_names.sort()
	rejected.sort()
	var removed := diff_removed_models(old_models, model_names)
	_save_cached_models(es, provider_id, model_names)

	return {'ok': true, 'models': model_names, 'removed': removed, 'rejected': rejected}


# ────────────────────────────────────────────────────────────────────────────
# Each cloud provider has a different JSON format.

## Build the JSON request body for the given provider.
## Returns the body string and the required HTTP headers.
static func build_request(provider_id: String, model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String, image_b64: String = "") -> Dictionary:
	match provider_id:
		"ollama":
			return _build_ollama(model, system_prompt, conversation_history, user_prompt, image_b64)
		"openai", "deepseek", "qwen", "codeium", "amazonq":
			return _build_openai(model, system_prompt, conversation_history, user_prompt, api_key, image_b64)
		"claude":
			return _build_claude(model, system_prompt, conversation_history, user_prompt, api_key, image_b64)
		"gemini":
			return _build_gemini(model, system_prompt, conversation_history, user_prompt, api_key, image_b64)
	return {"body": "", "headers": [], "path": ""}


static func _build_ollama(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, image_b64: String = "") -> Dictionary:
	# Build context-aware prompt
	var full_prompt := ""
	if conversation_history.size() > 0:
		full_prompt += "Previous conversation:\n"
		for entry in conversation_history:
			if entry["role"] == "user":
				full_prompt += "User: " + entry["content"] + "\n"
			else:
				full_prompt += "Assistant: " + entry["content"] + "\n"
		full_prompt += "\nCurrent question:\n"
	full_prompt += user_prompt

	var body := {
		"model": model,
		"prompt": full_prompt,
		"system": system_prompt,
		"stream": true,
		"options": {"temperature": 0.3, "num_predict": 2048},
	}
	if not image_b64.is_empty():
		body["images"] = [image_b64]
	return {
		"body": JSON.stringify(body),
		"headers": ["Content-Type: application/json", "Accept: */*"],
		"path": "/api/generate",
	}


static func _build_openai(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String, image_b64: String = "") -> Dictionary:
	var messages: Array = [{"role": "system", "content": system_prompt}]
	for entry in conversation_history:
		messages.append({"role": entry["role"], "content": entry["content"]})
	if not image_b64.is_empty():
		messages.append({"role": "user", "content": [
			{"type": "text", "text": user_prompt},
			{"type": "image_url", "image_url": {"url": "data:image/png;base64," + image_b64}},
		]})
	else:
		messages.append({"role": "user", "content": user_prompt})

	var body := {
		"model": model,
		"messages": messages,
		"stream": true,
		"temperature": 0.3,
		"max_tokens": 8192,
	}
	return {
		"body": JSON.stringify(body),
		"headers": [
			"Content-Type: application/json",
			"Authorization: Bearer " + api_key,
			"Accept: text/event-stream",
		],
		"path": "/v1/chat/completions",
	}


static func _build_claude(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String, image_b64: String = "") -> Dictionary:
	var messages: Array = []
	for entry in conversation_history:
		messages.append({"role": entry["role"], "content": entry["content"]})
	if not image_b64.is_empty():
		messages.append({"role": "user", "content": [
			{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": image_b64}},
			{"type": "text", "text": user_prompt},
		]})
	else:
		messages.append({"role": "user", "content": user_prompt})

	var body := {
		"model": model,
		"system": system_prompt,
		"messages": messages,
		"stream": true,
		"temperature": 0.3,
		"max_tokens": 8192,
	}
	return {
		"body": JSON.stringify(body),
		"headers": [
			"Content-Type: application/json",
			"x-api-key: " + api_key,
			"anthropic-version: 2023-06-01",
			"Accept: text/event-stream",
		],
		"path": "/v1/messages",
	}


static func _build_gemini(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String, image_b64: String = "") -> Dictionary:
	var contents: Array = []
	# Gemini uses "parts" format
	for entry in conversation_history:
		var role: String = "user" if entry["role"] == "user" else "model"
		contents.append({"role": role, "parts": [{"text": entry["content"]}]})
	if not image_b64.is_empty():
		contents.append({"role": "user", "parts": [
			{"text": user_prompt},
			{"inlineData": {"mimeType": "image/png", "data": image_b64}},
		]})
	else:
		contents.append({"role": "user", "parts": [{"text": user_prompt}]})

	var body := {
		"contents": contents,
		"systemInstruction": {"parts": [{"text": system_prompt}]},
		"generationConfig": {
			"temperature": 0.3,
			"maxOutputTokens": 8192,
		},
	}
	var path := "/v1beta/models/" + model + ":streamGenerateContent?alt=sse&key=" + api_key
	return {
		"body": JSON.stringify(body),
		"headers": ["Content-Type: application/json"],
		"path": path,
	}


# ─── Response Token Parsers ─────────────────────────────────────────────────
# Each provider streams tokens in a different format.

## Parse a single JSON line from a streaming response.
## Returns {"token": "text", "done": bool} or null if the line is not parseable.
static func parse_stream_line(provider_id: String, line: String) -> Dictionary:
	match provider_id:
		"ollama":
			return _parse_ollama_line(line)
		"openai", "deepseek", "qwen", "codeium", "amazonq":
			return _parse_openai_line(line)
		"claude":
			return _parse_claude_line(line)
		"gemini":
			return _parse_gemini_line(line)
	return {"token": "", "done": true}


static func _parse_ollama_line(line: String) -> Dictionary:
	if line.is_empty() or line[0] != "{":
		return {"token": "", "done": false}
	var json = JSON.parse_string(line)
	if json == null:
		return {"token": "", "done": false}
	var token: String = json.get("response", "")
	var done: bool = json.get("done", false)
	return {"token": token, "done": done}


static func _parse_openai_line(line: String) -> Dictionary:
	# OpenAI SSE format: data: {"choices":[{"delta":{"content":"token"}}]}
	if line.begins_with("data: [DONE]"):
		return {"token": "", "done": true}
	if not line.begins_with("data: "):
		return {"token": "", "done": false}
	var json_str := line.substr(6).strip_edges()
	if json_str.is_empty():
		return {"token": "", "done": false}
	var json = JSON.parse_string(json_str)
	if json == null:
		return {"token": "", "done": false}
	var choices: Array = json.get("choices", [])
	if choices.is_empty():
		return {"token": "", "done": false}
	var delta: Dictionary = choices[0].get("delta", {})
	var token: String = ""
	if delta.get("content") != null:
		token = str(delta.get("content", ""))
	var finish_raw = choices[0].get("finish_reason")
	var finish: String = "" if finish_raw == null else str(finish_raw)
	return {"token": token, "done": finish == "stop"}


static func _parse_claude_line(line: String) -> Dictionary:
	# Claude SSE: event: content_block_delta / data: {"delta":{"text":"token"}}
	if not line.begins_with("data: "):
		return {"token": "", "done": false}
	var json_str := line.substr(6).strip_edges()
	if json_str.is_empty():
		return {"token": "", "done": false}
	var json = JSON.parse_string(json_str)
	if json == null:
		return {"token": "", "done": false}
	var event_type: String = json.get("type", "")
	if event_type == "content_block_delta":
		var delta: Dictionary = json.get("delta", {})
		return {"token": delta.get("text", ""), "done": false}
	elif event_type == "message_stop":
		return {"token": "", "done": true}
	elif event_type == "message_delta":
		var delta: Dictionary = json.get("delta", {})
		if delta.get("stop_reason", "") == "end_turn":
			return {"token": "", "done": true}
	return {"token": "", "done": false}


static func _parse_gemini_line(line: String) -> Dictionary:
	# Gemini SSE: data: {"candidates":[{"content":{"parts":[{"text":"token"}]}}]}
	if not line.begins_with("data: "):
		return {"token": "", "done": false}
	var json_str := line.substr(6).strip_edges()
	if json_str.is_empty():
		return {"token": "", "done": false}
	var json = JSON.parse_string(json_str)
	if json == null:
		return {"token": "", "done": false}
	var candidates: Array = json.get("candidates", [])
	if candidates.is_empty():
		return {"token": "", "done": false}
	var cand: Dictionary = candidates[0]
	var finish: String = str(cand.get("finishReason", ""))
	var done := finish in ["STOP", "MAX_TOKENS", "SAFETY", "RECITATION", "OTHER"]
	var token := ""
	var content: Dictionary = cand.get("content", {})
	var parts: Array = content.get("parts", [])
	if not parts.is_empty():
		token = str(parts[0].get("text", ""))
	return {"token": token, "done": done}


## Non-streaming request for automated live tests (Ollama / OpenAI-shaped / Claude / Gemini).
static func build_request_nostream(provider_id: String, model: String, system_prompt: String,
		user_prompt: String, api_key: String) -> Dictionary:
	var req: Dictionary = build_request(provider_id, model, system_prompt, [], user_prompt, api_key)
	var body_text: String = str(req.get("body", ""))
	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		match provider_id:
			"ollama", "openai", "deepseek", "qwen", "codeium", "amazonq", "claude":
				parsed["stream"] = false
		req["body"] = JSON.stringify(parsed)
	if provider_id == "gemini":
		var path: String = str(req.get("path", ""))
		path = path.replace(":streamGenerateContent?alt=sse&", ":generateContent?")
		req["path"] = path
	return req


## Extract assistant text from a complete (non-SSE) HTTP response body.
static func extract_response_text(provider_id: String, raw_body: String) -> String:
	var parsed = JSON.parse_string(raw_body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return raw_body.strip_edges()
	match provider_id:
		"ollama":
			return str(parsed.get("response", ""))
		"openai", "deepseek", "qwen", "codeium", "amazonq":
			var choices: Array = parsed.get("choices", [])
			if choices.is_empty():
				return ""
			return str(choices[0].get("message", {}).get("content", ""))
		"claude":
			var content: Array = parsed.get("content", [])
			var out := ""
			for block in content:
				if typeof(block) == TYPE_DICTIONARY and str(block.get("type", "")) == "text":
					out += str(block.get("text", ""))
			return out
		"gemini":
			var candidates: Array = parsed.get("candidates", [])
			if candidates.is_empty():
				return ""
			var parts: Array = candidates[0].get("content", {}).get("parts", [])
			var text := ""
			for p in parts:
				if typeof(p) == TYPE_DICTIONARY:
					text += str(p.get("text", ""))
			return text
	return raw_body.strip_edges()


## Resolve API URL for a provider request dict.
static func request_url(provider_info: ProviderInfo, req: Dictionary) -> String:
	var scheme := "https" if provider_info.use_tls else "http"
	return scheme + "://" + provider_info.api_host + str(req.get("path", ""))
