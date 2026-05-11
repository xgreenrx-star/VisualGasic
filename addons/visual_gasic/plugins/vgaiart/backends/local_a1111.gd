@tool
## Local AUTOMATIC1111 / SD.Next backend.
##
## Talks to a Stable Diffusion WebUI running locally with --api enabled.
## Default endpoint: http://127.0.0.1:7860
##
## Why this matters: this is the only "free forever" backend that can
## produce character-consistent walk/run/jump cycles, because (a) the
## user can fix a seed across frames and (b) if they install the
## ControlNet extension we send OpenPose skeletons through the
## alwayson_scripts API to lock pose per-frame.
##
## Setup:
##   bash scripts/install_a1111.sh         # one-time, downloads ~6 GB
##   ~/stable-diffusion-webui/webui.sh --api --listen=127.0.0.1
##
## See README.md in this plugin folder for more.
extends "res://addons/visual_gasic/plugins/vgaiart/backends/backend_base.gd"

const _DEFAULT_URL := "http://127.0.0.1:7860"
const _SDAPI_TXT2IMG := "/sdapi/v1/txt2img"
const _SDAPI_PING := "/sdapi/v1/sd-models"

var base_url: String = _DEFAULT_URL
var steps: int = 24
var sampler: String = "Euler a"
var cfg_scale: float = 7.0

# Optional HTTP Basic auth for remote servers behind a reverse proxy
# (RunPod proxy, Cloudflare tunnel, ngrok with auth, etc). Empty = no auth.
var auth_user: String = ""
var auth_pass: String = ""

# Returns Authorization header line, or "" when no auth configured.
func _auth_header() -> String:
	if auth_user.is_empty():
		return ""
	var creds := auth_user + ":" + auth_pass
	return "Authorization: Basic " + Marshalls.utf8_to_base64(creds)

# Cached reachability so is_configured() is cheap. _refresh_reachable() is
# called explicitly by the plugin's "Refresh status" button.
var _reachable: bool = false
var _last_check_msg: String = ""

func get_id() -> String:
	return "local_a1111"

func get_display_name() -> String:
	return "Local Stable Diffusion (A1111)"

func is_configured() -> bool:
	return _reachable

func get_setup_hint() -> String:
	if _last_check_msg.is_empty():
		return "Local SD WebUI not detected at %s. Click ⚙ → Refresh, or run scripts/install_a1111.sh." % base_url
	return _last_check_msg

## Synchronously-style check via HTTPRequest (fire-and-forget). Caller
## must await the returned signal callable on its own; we just kick a
## ping and update _reachable when it returns. Safe to call repeatedly.
func refresh_reachable(host: Node) -> void:
	var http := HTTPRequest.new()
	http.timeout = 4.0
	host.add_child(http)
	var ping_headers := PackedStringArray()
	var ah := _auth_header()
	if not ah.is_empty():
		ping_headers.append(ah)
	var err := http.request(base_url + _SDAPI_PING, ping_headers)
	if err != OK:
		_reachable = false
		_last_check_msg = "Could not start ping (HTTPRequest err %d)." % err
		http.queue_free()
		return
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	if result_code == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		_reachable = true
		_last_check_msg = "Reachable at %s" % base_url
	else:
		_reachable = false
		_last_check_msg = "No response from %s (network %d, HTTP %d). Start webui.sh --api." % [
			base_url, result_code, response_code
		]

func generate(host: Node, params: Dictionary) -> void:
	var prompt: String = String(params.get("prompt", "")).strip_edges()
	if prompt.is_empty():
		failed.emit("Prompt is empty.")
		return

	var width: int = int(params.get("width", 512))
	var height: int = int(params.get("height", 512))
	var seed_val: int = int(params.get("seed", -1))
	var negative: String = String(params.get("negative", ""))

	var body := {
		"prompt": prompt,
		"negative_prompt": negative,
		"width": width,
		"height": height,
		"steps": steps,
		"sampler_name": sampler,
		"cfg_scale": cfg_scale,
		"seed": seed_val,
		"batch_size": 1,
		"n_iter": 1,
		"send_images": true,
		"save_images": false,
	}

	# Optional ControlNet OpenPose hook. If the caller supplies a base64
	# skeleton PNG via params["controlnet_pose_b64"], wire it through the
	# alwayson_scripts API. Requires the sd-webui-controlnet extension and
	# an OpenPose model installed in models/ControlNet/.
	var pose_b64: String = String(params.get("controlnet_pose_b64", ""))
	if not pose_b64.is_empty():
		body["alwayson_scripts"] = {
			"controlnet": {
				"args": [
					{
						"input_image": pose_b64,
						"module": "none",  # we already pass a pre-rendered skeleton
						"model": String(params.get("controlnet_model", "control_v11p_sd15_openpose [cab727d4]")),
						"weight": float(params.get("controlnet_weight", 1.0)),
						"resize_mode": "Crop and Resize",
						"control_mode": "Balanced",
						"pixel_perfect": true,
						"enabled": true,
					}
				]
			}
		}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var ah := _auth_header()
	if not ah.is_empty():
		headers.append(ah)

	var http := HTTPRequest.new()
	# 0 = no timeout. SD on CPU with ControlNet can take 8-15 min per 512x512
	# frame; a finite timeout (we used to set 300s) caused RESULT_TIMEOUT
	# (code 13) mid-frame. The API is synchronous so we just have to wait.
	http.timeout = 0.0
	host.add_child(http)
	var err := http.request(base_url + _SDAPI_TXT2IMG, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		failed.emit("HTTPRequest failed to start: %d (is webui.sh --api running at %s?)" % [err, base_url])
		http.queue_free()
		return

	var result: Array = await http.request_completed
	http.queue_free()

	var result_code: int = result[0]
	var response_code: int = result[1]
	var resp_body: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		failed.emit("Network error contacting %s (code %d). Is webui running with --api?" % [base_url, result_code])
		_reachable = false
		return

	if response_code < 200 or response_code >= 300:
		var msg := resp_body.get_string_from_utf8()
		failed.emit("A1111 HTTP %d: %s" % [response_code, msg.substr(0, 400)])
		return

	var parsed = JSON.parse_string(resp_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("images"):
		failed.emit("Unexpected response shape from A1111 (no 'images' field).")
		return

	var images: Array = parsed["images"]
	if images.is_empty():
		failed.emit("A1111 returned an empty image list.")
		return

	# images[0] is base64-encoded PNG (sometimes with a "data:image/png;base64," prefix).
	var b64_str: String = String(images[0])
	var comma := b64_str.find(",")
	if b64_str.begins_with("data:") and comma > 0:
		b64_str = b64_str.substr(comma + 1)

	var bytes := Marshalls.base64_to_raw(b64_str)
	if bytes.is_empty():
		failed.emit("Could not decode base64 image from A1111.")
		return

	var img := Image.new()
	var load_err := img.load_png_from_buffer(bytes)
	if load_err != OK:
		load_err = img.load_jpg_from_buffer(bytes)
	if load_err != OK:
		failed.emit("Could not decode image returned by A1111.")
		return

	image_ready.emit(img)


## Run the input image through sd-webui-rembg's /rembg endpoint and return
## the result. If the extension isn't installed (404) or anything else goes
## wrong, returns the original image unchanged so generation never breaks
## just because background removal couldn't run.
##
## `host` is a Node we can attach an HTTPRequest to (use `_view`).
## `model` defaults to "u2net" (best general-purpose). Other options
## supported by sd-webui-rembg: "u2netp", "u2net_human_seg", "isnet-general-use",
## "isnet-anime", "silueta".
func remove_background_async(host: Node, img: Image, model: String = "u2net") -> Image:
	if img == null or img.is_empty():
		return img
	var png_bytes := img.save_png_to_buffer()
	if png_bytes.is_empty():
		return img
	var b64 := Marshalls.raw_to_base64(png_bytes)
	var body := {
		"input_image": b64,
		"model": model,
		"return_mask": false,
		"alpha_matting": false,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var ah := _auth_header()
	if not ah.is_empty():
		headers.append(ah)
	var http := HTTPRequest.new()
	http.timeout = 0.0  # rembg on CPU can take 5-15 s for a 512x512
	host.add_child(http)
	var err := http.request(base_url + "/rembg", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		push_warning("[VG AI Art] rembg request failed to start (err %d). Skipping cleanup." % err)
		return img
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	var resp_body: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		# Most common case: 404 because sd-webui-rembg isn't installed.
		# We log it once but don't bother the user — generation still works.
		push_warning("[VG AI Art] rembg HTTP %d (network code %d). Is sd-webui-rembg installed? Returning original image." % [response_code, result_code])
		return img
	var parsed = JSON.parse_string(resp_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("image"):
		push_warning("[VG AI Art] rembg response missing 'image'. Returning original.")
		return img
	var out_b64 := String(parsed["image"])
	var comma := out_b64.find(",")
	if out_b64.begins_with("data:") and comma > 0:
		out_b64 = out_b64.substr(comma + 1)
	var out_bytes := Marshalls.base64_to_raw(out_b64)
	if out_bytes.is_empty():
		return img
	var out_img := Image.new()
	if out_img.load_png_from_buffer(out_bytes) != OK:
		return img
	return out_img
