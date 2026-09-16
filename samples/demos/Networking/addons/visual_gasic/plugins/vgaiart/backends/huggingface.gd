@tool
## Hugging Face Inference API backend.
##
## Endpoint: POST https://api-inference.huggingface.co/models/{model_id}
## Auth: "Authorization: Bearer <HF_TOKEN>"
## Body: JSON {"inputs": prompt, "parameters": {...}}
## Returns: image/png bytes (or JSON error on failure).
##
## Default model is Flux Schnell (Apache 2.0, commercial-safe). The user can
## override the model id from the settings panel.
extends "res://addons/visual_gasic/plugins/vgaiart/backends/backend_base.gd"

const _DEFAULT_MODEL := "black-forest-labs/FLUX.1-schnell"
const _ENDPOINT := "https://api-inference.huggingface.co/models/"

var token: String = ""
var default_model: String = _DEFAULT_MODEL

func get_id() -> String:
	return "huggingface"

func get_display_name() -> String:
	return "Hugging Face (API key)"

func is_configured() -> bool:
	return not token.strip_edges().is_empty()

func get_setup_hint() -> String:
	return "Paste a Hugging Face access token in plugin settings (Settings → AI Art)."

func generate(host: Node, params: Dictionary) -> void:
	if not is_configured():
		failed.emit(get_setup_hint())
		return

	var prompt: String = String(params.get("prompt", "")).strip_edges()
	if prompt.is_empty():
		failed.emit("Prompt is empty.")
		return

	var model: String = String(params.get("model", default_model)).strip_edges()
	if model.is_empty():
		model = _DEFAULT_MODEL

	var width: int = int(params.get("width", 512))
	var height: int = int(params.get("height", 512))
	var seed_val: int = int(params.get("seed", -1))
	var negative: String = String(params.get("negative", ""))

	var parameters := {
		"width": width,
		"height": height,
	}
	if seed_val >= 0:
		parameters["seed"] = seed_val
	if not negative.is_empty():
		parameters["negative_prompt"] = negative

	var body := {
		"inputs": prompt,
		"parameters": parameters,
		# wait_for_model: HF cold-starts can be 20-40s; this is more polite
		# than retrying on 503.
		"options": {"wait_for_model": true},
	}
	var body_str := JSON.stringify(body)

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: image/png",
		"Authorization: Bearer " + token.strip_edges(),
	])

	var http := HTTPRequest.new()
	http.timeout = 180.0
	host.add_child(http)
	var err := http.request(_ENDPOINT + model, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		failed.emit("HTTPRequest failed to start: %d" % err)
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()

	var result_code: int = result[0]
	var response_code: int = result[1]
	var resp_headers: PackedStringArray = result[2]
	var resp_body: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Network error (code %d). Check your internet connection." % result_code)
		return

	# Detect JSON error vs. image bytes via Content-Type.
	var content_type := ""
	for h in resp_headers:
		var lh := String(h).to_lower()
		if lh.begins_with("content-type:"):
			content_type = lh.substr("content-type:".length()).strip_edges()
			break

	if response_code < 200 or response_code >= 300 or content_type.begins_with("application/json"):
		var msg := resp_body.get_string_from_utf8()
		# Try to extract { "error": "..." }.
		var parsed = JSON.parse_string(msg)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			msg = String(parsed["error"])
		failed.emit("Hugging Face HTTP %d: %s" % [response_code, msg])
		return

	if resp_body.is_empty():
		failed.emit("Empty response from Hugging Face.")
		return

	var img := Image.new()
	var load_err := img.load_png_from_buffer(resp_body)
	if load_err != OK:
		load_err = img.load_jpg_from_buffer(resp_body)
	if load_err != OK:
		failed.emit("Could not decode image returned by Hugging Face.")
		return

	image_ready.emit(img)
