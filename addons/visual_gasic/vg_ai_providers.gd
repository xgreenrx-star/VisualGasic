@tool
extends RefCounted
## AI Provider abstraction layer — unified interface for Ollama, OpenAI, Claude, Gemini.
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

	return providers

static func find_provider(provider_id: String) -> ProviderInfo:
	for p in get_providers():
		if p.id == provider_id:
			return p
	return null


# ─── API Key Management ─────────────────────────────────────────────────────
# Keys are stored centrally per-user (NOT per-project) so AI access carries
# over to every VisualGasic project the user opens or creates.
#   Linux:   $XDG_CONFIG_HOME/visual_gasic/ai_keys.cfg  (default ~/.config/visual_gasic)
#   Windows: %APPDATA%/VisualGasic/ai_keys.cfg
#   macOS:   ~/Library/Application Support/VisualGasic/ai_keys.cfg
# A legacy per-project file (user://vg_ai_keys.cfg) is migrated on first read.

const _LEGACY_KEYS_PATH := "user://vg_ai_keys.cfg"
const _KEYS_FILENAME := "ai_keys.cfg"

static func _central_keys_path() -> String:
	var dir := ""
	match OS.get_name():
		"Windows", "UWP":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				return _LEGACY_KEYS_PATH
			dir = appdata + "/VisualGasic"
		"macOS":
			var home_mac := OS.get_environment("HOME")
			if home_mac.is_empty():
				return _LEGACY_KEYS_PATH
			dir = home_mac + "/Library/Application Support/VisualGasic"
		_:
			var xdg := OS.get_environment("XDG_CONFIG_HOME")
			if xdg.is_empty():
				var home := OS.get_environment("HOME")
				if home.is_empty():
					return _LEGACY_KEYS_PATH
				xdg = home + "/.config"
			dir = xdg + "/visual_gasic"
	DirAccess.make_dir_recursive_absolute(dir)
	return dir + "/" + _KEYS_FILENAME

## Migrate per-project legacy keys into the central store. Runs every load
## (cheap) and *merges* — any non-empty value in the legacy file fills in
## a missing or empty value in the central file. This handles the case
## where a brand-new project's empty user://vg_ai_keys.cfg was the first
## one ever loaded and seeded the central file with blanks, leaving the
## user's real keys stranded in some other project's user data dir.
static func _migrate_legacy_if_needed(central: String) -> void:
	if central == _LEGACY_KEYS_PATH:
		return  # central path resolution failed; nothing to migrate to
	if not FileAccess.file_exists(_LEGACY_KEYS_PATH):
		return
	var legacy := ConfigFile.new()
	if legacy.load(_LEGACY_KEYS_PATH) != OK:
		return
	var central_cfg := ConfigFile.new()
	central_cfg.load(central)  # OK if missing
	var changed := false
	# Merge api_keys section: only fill in keys that are empty or absent
	# centrally. Never overwrite a populated central value with a legacy one.
	for provider_id in ["openai", "claude", "gemini"]:
		var legacy_val: String = legacy.get_value("api_keys", provider_id, "")
		if legacy_val.is_empty():
			continue
		var central_val: String = central_cfg.get_value("api_keys", provider_id, "")
		if central_val.is_empty():
			central_cfg.set_value("api_keys", provider_id, legacy_val)
			changed = true
	# Preferred provider: copy if central has none.
	if not central_cfg.has_section_key("preferences", "provider"):
		var pref: String = legacy.get_value("preferences", "provider", "")
		if not pref.is_empty():
			central_cfg.set_value("preferences", "provider", pref)
			changed = true
	if changed or not FileAccess.file_exists(central):
		central_cfg.save(central)

static func load_api_key(provider_id: String) -> String:
	var path := _central_keys_path()
	_migrate_legacy_if_needed(path)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		# Fall back to legacy per-project location if central path unreadable.
		if cfg.load(_LEGACY_KEYS_PATH) != OK:
			return ""
	return cfg.get_value("api_keys", provider_id, "")

static func save_api_key(provider_id: String, key: String) -> void:
	var path := _central_keys_path()
	_migrate_legacy_if_needed(path)
	var cfg := ConfigFile.new()
	cfg.load(path)  # OK if file doesn't exist yet
	cfg.set_value("api_keys", provider_id, key)
	cfg.save(path)

static func load_preferred_provider() -> String:
	var path := _central_keys_path()
	_migrate_legacy_if_needed(path)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		if cfg.load(_LEGACY_KEYS_PATH) != OK:
			return "ollama"
	return cfg.get_value("preferences", "provider", "ollama")

static func save_preferred_provider(provider_id: String) -> void:
	var path := _central_keys_path()
	_migrate_legacy_if_needed(path)
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("preferences", "provider", provider_id)
	cfg.save(path)


# ─── Request Body Builders ──────────────────────────────────────────────────
# Each cloud provider has a different JSON format.

## Build the JSON request body for the given provider.
## Returns the body string and the required HTTP headers.
static func build_request(provider_id: String, model: String, system_prompt: String,
		conversation_history: Array, user_prompt: String, api_key: String) -> Dictionary:
	match provider_id:
		"ollama":
			return _build_ollama(model, system_prompt, conversation_history, user_prompt)
		"openai":
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
		"openai":
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
	var token: String = delta.get("content", "")
	var finish: String = choices[0].get("finish_reason", "")
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
