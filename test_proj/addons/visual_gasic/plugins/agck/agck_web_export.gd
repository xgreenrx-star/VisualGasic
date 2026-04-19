@tool
## AGCK Web Export — REDIRECT STUB
##
## The web export backend has moved to the standalone Web Publish plugin:
##   res://addons/visual_gasic/plugins/web_publish/vg_web_export.gd
##
## This file exists for backward compatibility — it re-exports the
## WebConfig class and publish_to_web() from the new location.
extends RefCounted

const _RealExport = preload("res://addons/visual_gasic/plugins/web_publish/vg_web_export.gd")

## Re-exported WebConfig for backward compatibility.
## Use the Web Publish plugin directly for new code.
class WebConfig:
	var game_title: String = "My Game"
	var bg_color: Color = Color(0.05, 0.05, 0.08)
	var loading_style: String = "Bar"
	var loading_color: Color = Color(1.0, 0.82, 0.35)
	var quality: String = "High"
	var scale_mode: String = "Fit"
	var fullscreen_button: bool = true
	var right_click_menu: bool = true
	var show_watermark: bool = true
	var canvas_width: int = 640
	var canvas_height: int = 384
	var embed_ready: bool = true
	var splash_enabled: bool = true
	var splash_duration: float = 1.5
	var icon_path: String = ""
	var description: String = ""


## Redirect to the real implementation in the Web Publish plugin.
static func publish_to_web(config, output_dir: String,
		run_export: bool = false, log_fn: Callable = Callable()) -> Dictionary:
	return _RealExport.publish_to_web(config, output_dir, run_export, log_fn)

static func ensure_web_export_preset() -> bool:
	return _RealExport.ensure_web_export_preset()

static func generate_wrapper_html(config, wasm_filename: String = "") -> String:
	return _RealExport.generate_wrapper_html(config, wasm_filename)

static func generate_embed_code(config, hosted_url: String = "") -> String:
	return _RealExport.generate_embed_code(config, hosted_url)

static func generate_portal_page(config, game_html_filename: String) -> String:
	return _RealExport.generate_portal_page(config, game_html_filename)
