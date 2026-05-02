# GDSFX Footsteppr — physical-simulation footstep synth.
#
# Port of vendor/bfxr2/js/synths/Footsteppr.js (MIT (c) Stephen Lavelle,
# original concept by Obiwannabe).
#
# Generates footstep sounds by composing three step envelopes (heel, roll,
# ball) and feeding them through a terrain-specific PureData DSP graph.
@tool
class_name GDSFXFootsteppr
extends RefCounted

const GDSFXPD_ := preload("res://addons/visual_gasic/plugins/gdsfx/gdsfx_pd.gd")
const GDSFXPDCompile_ := preload("res://addons/visual_gasic/plugins/gdsfx/gdsfx_pd_compile.gd")
const GDSFXPDModules_ := preload("res://addons/gdsfx/gdsfx_pd_modules.gd")

const VERSION := "1.0.0"
const NAME := "Footsteppr"

const TERRAIN_NAMES := ["snow", "grass", "dirt", "gravel", "wood"]

# Param defaults match Footsteppr.js param_info (heel, roll, ball, swiftness 0.5; terrain 0).
const DEFAULTS := {
	"masterVolume": 0.5,
	"terrain": 0,
	"heel": 0.5,
	"roll": 0.5,
	"ball": 0.5,
	"swiftness": 0.5,
}

const PARAM_INFO := [
	{"name": "masterVolume", "display_name": "Sound Volume", "min": 0.0, "max": 1.0, "default": 0.5, "locked": true},
	{"name": "terrain",      "display_name": "Terrain",      "min": 0,   "max": 4,   "default": 0,   "is_enum": true, "values": TERRAIN_NAMES},
	{"name": "heel",         "display_name": "Heel",         "min": 0.0, "max": 1.0, "default": 0.5},
	{"name": "roll",         "display_name": "Roll",         "min": 0.0, "max": 1.0, "default": 0.5},
	{"name": "ball",         "display_name": "Ball",         "min": 0.0, "max": 1.0, "default": 0.5},
	{"name": "swiftness",    "display_name": "Swiftness",    "min": 0.0, "max": 1.0, "default": 0.5},
]

# Cached compiled programs by terrain name.
static var _compiled_terrain: Dictionary = {}

var params: Dictionary = {}
var locked_params: Dictionary = {"masterVolume": true}
var last_buffer: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	params = DEFAULTS.duplicate()


func default_params() -> Dictionary:
	return DEFAULTS.duplicate()


func get_param(name: String) -> float:
	return float(params.get(name, DEFAULTS.get(name, 0.0)))


func set_param(name: String, value) -> void:
	if locked_params.get(name, false):
		return
	params[name] = value


func _get_terrain_program(terrain_name: String) -> Callable:
	if _compiled_terrain.has(terrain_name):
		return _compiled_terrain[terrain_name]
	var modules: Dictionary = GDSFXPDModules_.MODULES
	if not modules.has(terrain_name):
		push_error("GDSFXFootsteppr: unknown terrain '%s'" % terrain_name)
		return Callable()
	var src: String = modules[terrain_name]
	var fn: Callable = GDSFXPDCompile_.compile(src)
	_compiled_terrain[terrain_name] = fn
	return fn


# === Sound synthesis ===
func generate_sound() -> PackedFloat32Array:
	var step_heel := get_param("heel")
	var step_roll := get_param("roll")
	var step_ball := get_param("ball")
	var step_speed := get_param("swiftness")
	var step_vol := get_param("masterVolume")

	# Speed maps [0..1] → step length seconds [0.8..0.1]
	var step_length: float = 0.1 + 0.7 * (1.0 - step_speed)
	GDSFXPD_.set_stream_length_seconds(step_length)

	var heel_env: Callable = GDSFXPD_.resize_fn(GDSFXPD_.make_step(step_heel), 0.0, 1.0, 0.0, 0.3333)
	var roll_env: Callable = GDSFXPD_.resize_fn(GDSFXPD_.make_step(step_roll), 0.0, 1.0, 0.125, 0.875)
	var ball_env: Callable = GDSFXPD_.resize_fn(GDSFXPD_.make_step(step_ball), 0.0, 1.0, 0.6667, 1.0)
	var step_env_0_1: Callable = GDSFXPD_.add_fns([heel_env, roll_env, ball_env])
	var step_env_resized: Callable = GDSFXPD_.resize_fn(step_env_0_1, 0.0, 1.0, 0.0, step_length)
	var envelope_signal: PackedFloat32Array = GDSFXPD_.pd_fn(step_env_resized)

	# Generate terrain texture
	var terrain_idx := int(get_param("terrain"))
	if terrain_idx < 0 or terrain_idx >= TERRAIN_NAMES.size():
		terrain_idx = 0
	var terrain_name: String = TERRAIN_NAMES[terrain_idx]
	var prog: Callable = _get_terrain_program(terrain_name)
	if not prog.is_valid():
		last_buffer = PackedFloat32Array()
		return last_buffer
	var sig_buf: PackedFloat32Array = prog.call(envelope_signal)

	# signal *= step_vol; clip to [-1,1]; *= 4.0
	var n: int = sig_buf.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var s: float = sig_buf[i] * step_vol
		s = clampf(s, -1.0, 1.0) * 4.0
		out[i] = clampf(s, -1.0, 1.0)
	last_buffer = out
	return out


func to_audio_stream_wav() -> AudioStreamWAV:
	var buf := generate_sound() if last_buffer.is_empty() else last_buffer
	var pcm := PackedByteArray()
	pcm.resize(buf.size() * 2)
	for i in range(buf.size()):
		var s: int = clampi(int(round(buf[i] * 32767.0)), -32768, 32767)
		if s < 0:
			s += 65536
		pcm[i * 2] = s & 0xFF
		pcm[i * 2 + 1] = (s >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = GDSFXPD_.SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func randomize_params() -> void:
	for info in PARAM_INFO:
		var name: String = info["name"]
		if locked_params.get(name, false):
			continue
		if info.get("is_enum", false):
			params[name] = randi_range(int(info["min"]), int(info["max"]))
		else:
			params[name] = randf_range(float(info["min"]), float(info["max"]))


func mutate_params() -> void:
	for info in PARAM_INFO:
		var name: String = info["name"]
		if locked_params.get(name, false):
			continue
		if info.get("is_enum", false):
			continue
		var lo: float = float(info["min"])
		var hi: float = float(info["max"])
		var range_: float = hi - lo
		var cur: float = float(params.get(name, info["default"]))
		params[name] = clampf(cur + (randf() * 2.0 - 1.0) * range_ * 0.1, lo, hi)


func save_to_dictionary() -> Dictionary:
	return {
		"_synth": NAME,
		"_version": VERSION,
		"params": params.duplicate(),
	}


func load_from_dictionary(d: Dictionary) -> void:
	if d.has("params"):
		params = (d["params"] as Dictionary).duplicate()
