@tool
extends EditorExportPlugin
## Prevents VG Tweak Overlay files and tweak-bag JSON from shipping in
## release exports, and warns the developer loudly if they would have.

const _TWEAK_PATHS := [
	"addons/visual_gasic/vg_tweak/",
]
const _TWEAK_FILENAME := ".vg_tweaks.json"

var _warned := false

func _get_name() -> String:
	return "VGTweakExportGuard"

func _export_begin(features: PackedStringArray, is_debug: bool,
		path: String, _flags: int) -> void:
	_warned = false
	if not is_debug:
		# Check whether the preset's exclude_filter already covers the tweak
		# folder.  We still skip files below, but the warning lets the dev
		# know they should add it to their preset so it shows in the editor UI.
		var preset := get_export_preset()
		var excl: String = preset.get_exclude_filter() if preset else ""
		var covered := "vg_tweak" in excl and ".vg_tweaks.json" in excl
		if not covered:
			push_warning(
				"[VisualGasic] Release export: the Tweak Overlay files are NOT " +
				"listed in your export preset's Exclude filter. " +
				"VGTweakExportGuard will strip them automatically, but add " +
				"'addons/visual_gasic/vg_tweak/*,.vg_tweaks.json,*.vg_tweaks.json' " +
				"to your preset's Exclude filter to silence this warning. " +
				"See docs/guides/TWEAK_OVERLAY.md — Shipping a release build."
			)
			_warned = true

func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	# Always strip tweak files — never let them land in a PCK regardless of
	# debug/release, so the guard is effective even during debug exports where
	# the user just wants to test without the overlay.
	var is_release := not ("debug" in features)

	# Skip the tweak-system scripts.
	for prefix in _TWEAK_PATHS:
		if path.begins_with("res://" + prefix):
			if is_release:
				skip()
			return

	# Skip any .vg_tweaks.json file anywhere in the tree.
	if path.ends_with(_TWEAK_FILENAME):
		if is_release:
			skip()
