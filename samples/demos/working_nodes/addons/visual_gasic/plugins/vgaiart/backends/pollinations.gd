@tool
## Pollinations.ai backend — anonymous, no key, free.
##
## Endpoint: GET https://image.pollinations.ai/prompt/{url-encoded prompt}
## Query params: width, height, seed, model, nologo, enhance.
## Returns a PNG (or sometimes JPEG) directly in the body.
extends "res://addons/visual_gasic/plugins/vgaiart/backends/backend_base.gd"

const _BASE_URL := "https://image.pollinations.ai/prompt/"

func get_id() -> String:
	return "pollinations"

func get_display_name() -> String:
	return "Pollinations (free, no key)"

func is_configured() -> bool:
	return true

func generate(host: Node, params: Dictionary) -> void:
	var prompt: String = String(params.get("prompt", "")).strip_edges()
	if prompt.is_empty():
		failed.emit("Prompt is empty.")
		return

	var width: int = int(params.get("width", 512))
	var height: int = int(params.get("height", 512))
	var seed_val: int = int(params.get("seed", -1))
	var model: String = String(params.get("model", "flux"))
	var negative: String = String(params.get("negative", ""))

	# Pollinations supports an "enhance" flag, but it changes results
	# unpredictably for pixel-art prompts, so we leave it off.
	var query := {
		"width": str(width),
		"height": str(height),
		"model": model,
		"nologo": "true",
	}
	if seed_val >= 0:
		query["seed"] = str(seed_val)
	if not negative.is_empty():
		# Not officially supported; some pollinations workers honor it.
		query["negative_prompt"] = negative

	var url := _BASE_URL + prompt.uri_encode()
	var qs := PackedStringArray()
	for k in query.keys():
		qs.append("%s=%s" % [k, String(query[k]).uri_encode()])
	if qs.size() > 0:
		url += "?" + "&".join(qs)

	var http := HTTPRequest.new()
	http.timeout = 120.0
	host.add_child(http)
	var err := http.request(url)
	if err != OK:
		failed.emit("HTTPRequest failed to start: %d" % err)
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body]
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Network error (code %d). Check your internet connection." % result_code)
		return
	if response_code < 200 or response_code >= 300:
		var msg: String = body.get_string_from_utf8() if body.size() < 4096 else ""
		failed.emit("Pollinations HTTP %d. %s" % [response_code, msg])
		return
	if body.is_empty():
		failed.emit("Empty response from Pollinations.")
		return

	var img := Image.new()
	var load_err := img.load_png_from_buffer(body)
	if load_err != OK:
		# Some Pollinations workers return JPEG.
		load_err = img.load_jpg_from_buffer(body)
	if load_err != OK:
		failed.emit("Could not decode image returned by Pollinations.")
		return

	image_ready.emit(img)
