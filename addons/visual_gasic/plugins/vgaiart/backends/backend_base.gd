@tool
## Common interface for VG AI Art backends.
##
## A backend is a thin async wrapper around an HTTPS image-gen API. It must
## emit either `image_ready(image)` on success or `failed(error_message)` on
## failure. Implementations should never block the main thread for long —
## use HTTPRequest and `await request_completed`.
extends RefCounted

signal image_ready(image: Image)
signal failed(error: String)

## Human-readable backend id (e.g. "pollinations", "huggingface").
func get_id() -> String:
	return "base"

## Human-readable display name shown in the settings dropdown.
func get_display_name() -> String:
	return "Base"

## Returns true when this backend is configured and ready to generate.
## Backends that need API keys etc. should return false until set up.
func is_configured() -> bool:
	return true

## A short hint shown when not configured (e.g. "Paste HF token in settings").
func get_setup_hint() -> String:
	return ""

## Kick off a generation. Implementations MUST emit either `image_ready`
## or `failed` exactly once. `params` keys (all optional unless noted):
##   prompt:        String (required)
##   negative:      String
##   width, height: int (default 512)
##   seed:          int (-1 = random)
##   model:         String (backend-specific)
func generate(_host: Node, _params: Dictionary) -> void:
	failed.emit("Backend has no generate() implementation")
