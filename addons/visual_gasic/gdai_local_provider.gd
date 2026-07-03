extends "res://addons/visual_gasic/gdai_provider.gd"
class_name GDAILocalProvider

var _config: Dictionary = {}

func initialize(config: Dictionary) -> void:
	_config = config.duplicate(true)

func complete(prompt: String, options: Dictionary = {}) -> String:
	var endpoint = _get_endpoint() + "/completions"
	var body: Dictionary = {
		"model": _get_model(),
		"prompt": prompt,
	}
	if options.has("max_tokens"):
		body["max_tokens"] = int(options["max_tokens"])
	if options.has("temperature"):
		body["temperature"] = float(options["temperature"])
	if options.has("top_p"):
		body["top_p"] = float(options["top_p"])
	if options.has("n"):
		body["n"] = int(options["n"])

	var result = await _send_json_request(endpoint, _build_headers(), body)
	if result.has("error"):
		return result
	var choices = result.get("choices", [])
	if choices.size() == 0:
		return {"error": "no_choices"}
	return String(choices[0].get("text", ""))

func chat(messages: Array, options: Dictionary = {}) -> String:
	var endpoint = _get_endpoint() + "/chat/completions"
	var body: Dictionary = {
		"model": _get_model(),
		"messages": messages,
	}
	if options.has("max_tokens"):
		body["max_tokens"] = int(options["max_tokens"])
	if options.has("temperature"):
		body["temperature"] = float(options["temperature"])
	if options.has("top_p"):
		body["top_p"] = float(options["top_p"])
	if options.has("n"):
		body["n"] = int(options["n"])

	var result = await _send_json_request(endpoint, _build_headers(), body)
	if result.has("error"):
		return result
	var choices = result.get("choices", [])
	if choices.size() == 0:
		return {"error": "no_choices"}
	var message = choices[0].get("message", {})
	return String(message.get("content", ""))

func embed(text: String, options: Dictionary = {}) -> Array:
	var endpoint = _get_endpoint() + "/embeddings"
	var body: Dictionary = {
		"model": _config.get("embedding_model", "text-embedding-3-large"),
		"input": text,
	}
	if options.has("model"):
		body["model"] = options["model"]

	var result = await _send_json_request(endpoint, _build_headers(), body)
	if result.has("error"):
		return result
	var data = result.get("data", [])
	if data.size() == 0:
		return {"error": "no_embedding_data"}
	return data[0].get("embedding", [])

func generate_image(prompt: String, options: Dictionary = {}) -> Dictionary:
	return {"error": "unsupported_operation", "details": "Image generation is not supported by the generic local provider."}

func _get_endpoint() -> String:
	var endpoint = String(_config.get("endpoint", "http://127.0.0.1:8000/v1"))
	return endpoint.strip_suffix("/")

func _get_model() -> String:
	return String(_config.get("model", "gpt-4o-mini"))

func _build_headers() -> Array:
	var headers: Array = [
		"Content-Type: application/json",
	]
	var api_key = String(_config.get("api_key", "")).strip_edges()
	if api_key != "":
		headers.append("Authorization: Bearer %s" % api_key)
	return headers

func _send_json_request(url: String, headers: Array, body: Dictionary) -> Dictionary:
	var json_body = JSON.stringify(body)
	var http = HTTPRequest.new()
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		var root = tree.get_root()
		root.add_child(http)
	else:
		push_warning("GDAI: Unable to create HTTPRequest, no SceneTree available.")
		return {"error": "no_scene_tree"}

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json_body.to_utf8())
	if err != OK:
		http.queue_free()
		return {"error": "request_failed", "details": err}

	var response = await http.request_completed
	http.queue_free()
	if response.size() < 4:
		return {"error": "invalid_response"}

	var result_code = int(response[1])
	var body_bytes = response[3]
	var response_text = String(body_bytes)
	if result_code < 200 or result_code >= 300:
		return {"error": "http_error", "status": result_code, "body": response_text}

	var parse = JSON.parse_string(response_text)
	if parse.error != OK:
		return {"error": "json_parse", "details": parse.error_string}

	return parse.result
