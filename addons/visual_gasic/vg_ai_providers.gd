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
	gemini.models = ["gemini-2.5-flash", "gemini-2.5-pro"]
	gemini.default_model = "gemini-2.5-flash"
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

	return providers

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


# ─── Request Body Builders ──────────────────────────────────────────────────
# Each cloud provider has a different JSON format.

## Build the JSON request body for the given provider.
## Returns the body string and the required HTTP headers.
static func build_request(provider_id: String, model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String) -> Dictionary:
	match provider_id:
		"ollama":
			return _build_ollama(model, system_prompt, conversation_history, user_prompt)
		"openai", "deepseek", "qwen", "codeium", "amazonq":
			return _build_openai(model, system_prompt, conversation_history, user_prompt, api_key)
		"claude":
			return _build_claude(model, system_prompt, conversation_history, user_prompt, api_key)
		"gemini":
			return _build_gemini(model, system_prompt, conversation_history, user_prompt, api_key)
	return {"body": "", "headers": [], "path": ""}


static func _build_ollama(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String) -> Dictionary:
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
	return {
		"body": JSON.stringify(body),
		"headers": ["Content-Type: application/json", "Accept: */*"],
		"path": "/api/generate",
	}


static func _build_openai(model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String) -> Dictionary:
	var messages: Array = [{"role": "system", "content": system_prompt}]
	for entry in conversation_history:
		messages.append({"role": entry["role"], "content": entry["content"]})
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
		conversation_history: Array, user_prompt: String, api_key: String) -> Dictionary:
	var messages: Array = []
	for entry in conversation_history:
		messages.append({"role": entry["role"], "content": entry["content"]})
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
		conversation_history: Array, user_prompt: String, api_key: String) -> Dictionary:
	var contents: Array = []
	# Gemini uses "parts" format
	for entry in conversation_history:
		var role: String = "user" if entry["role"] == "user" else "model"
		contents.append({"role": role, "parts": [{"text": entry["content"]}]})
	contents.append({"role": "user", "parts": [{"text": user_prompt}]})

	var body := {
		"contents": contents,
		"systemInstruction": {"parts": [{"text": system_prompt}]},
		"generationConfig": {
			"temperature": 0.3,
			"maxOutputTokens": 2048,
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
	var content: Dictionary = candidates[0].get("content", {})
	var parts: Array = content.get("parts", [])
	if parts.is_empty():
		return {"token": "", "done": false}
	var token: String = parts[0].get("text", "")
	var finish: String = candidates[0].get("finishReason", "")
	return {"token": token, "done": finish == "STOP"}
