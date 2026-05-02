# VGSFX — Bfxr synth (port of bfxr2/js/synths/Bfxr.js + SynthBase.js).
#
# Holds parameter metadata, default values, randomizer presets, mutate/rectify
# logic, and drives the DSP to produce a sample buffer.
#
# Original: bfxr2 © 2021 Stephen Lavelle (MIT). See NOTICE.md.

class_name VGSFXSynth
extends RefCounted

const VGSFXDSP_ := preload("res://addons/visual_gasic/plugins/vgsfx/vgsfx_dsp.gd")

const VERSION := "1.0.4"
const NAME := "Bfxr"

# Wave-type indices match bfxr2 1:1
const WAVE_NAMES := {
	"Triangle": 4,
	"Sin": 2,
	"Square": 0,
	"Saw": 1,
	"Breaker": 8,
	"Tan": 6,
	"Whistle": 7,
	"White": 3,
	"Voice": 11,
	"Bitnoise": 9,
	"Rasp": 5,
	"FMSyn": 10,
}

# Display order for the wave-type buttons (matches Bfxr.js param_info[1].values order)
const WAVE_DISPLAY_ORDER := [4, 2, 0, 1, 8, 6, 7, 3, 11, 9, 5, 10]

const RANDOMIZATION_POWER := {
	"attackTime": 4,
	"sustainTime": 2,
	"sustainPunch": 2,
	"overtones": 3,
	"overtoneFalloff": 2,
	"vibratoDepth": 3,
	"dutySweep": 3,
	"flangerOffset": 3,
	"flangerSweep": 3,
	"lpFilterCutoff": 3,
	"lpFilterSweep": 3,
	"hpFilterCutoff": 5,
	"hpFilterSweep": 5,
	"bitCrush": 4,
	"bitCrushSweep": 5,
	"slide": 4,
	"frequency_acceleration": 7,
	"frequency_start": 4,
}

# Param info: {name, display, tooltip, default, min, max, kind}
# kind = "RANGE" | "BUTTONSELECT"
# This list mirrors Bfxr.js param_info exactly (same names, defaults, ranges).
const PARAM_INFO := [
	{"name": "masterVolume", "display": "Sound Volume", "tooltip": "Overall volume of the current sound.", "default": 0.5, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "waveType", "display": "Wave Type", "tooltip": "", "default": 0, "min": 0, "max": 12, "kind": "BUTTONSELECT"},
	{"name": "attackTime", "display": "Attack Time", "tooltip": "Length of the volume envelope attack.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "sustainTime", "display": "Sustain Time", "tooltip": "Length of the volume envelope sustain.", "default": 0.3, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "sustainPunch", "display": "Punch", "tooltip": "Tilts the sustain envelope for more 'pop'.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "decayTime", "display": "Decay Time", "tooltip": "Length of the volume envelope decay (yes, it's also called release).", "default": 0.4, "min": 0.03, "max": 1.0, "kind": "RANGE"},
	{"name": "compressionAmount", "display": "Compression", "tooltip": "Pushes amplitudes together into a narrower range.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "frequency_start", "display": "Frequency", "tooltip": "Base note of the sound.", "default": 0.3, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "frequency_slide", "display": "Frequency Slide", "tooltip": "Slides the frequency up or down.", "default": 0.0, "min": -0.5, "max": 0.5, "kind": "RANGE"},
	{"name": "frequency_acceleration", "display": "Delta Slide", "tooltip": "Accelerates the frequency.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "min_frequency_relative_to_starting_frequency", "display": "Frequency Cutoff", "tooltip": "Stops the sound when frequency drops below this fraction of the starting frequency.", "default": 0.0, "min": 0.0, "max": 0.99, "kind": "RANGE"},
	{"name": "vibratoDepth", "display": "Vibrato Depth", "tooltip": "Strength of the vibrato effect.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "vibratoSpeed", "display": "Vibrato Speed", "tooltip": "Speed of the vibrato effect.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "pitch_jump_repeat_speed", "display": "Pitch Jump Repeat Speed", "tooltip": "How often the pitch-jump pattern repeats.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "pitch_jump_amount", "display": "Pitch Jump Amount 1", "tooltip": "First jump in pitch.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "pitch_jump_onset_percent", "display": "Pitch Jump Onset 1", "tooltip": "When the first pitch-jump happens.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "pitch_jump_2_amount", "display": "Pitch Jump Amount 2", "tooltip": "Second jump in pitch.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "pitch_jump_onset2_percent", "display": "Pitch Jump Onset 2", "tooltip": "When the second pitch-jump happens.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "overtones", "display": "Harmonics", "tooltip": "Overlays scaled copies of the waveform (CPU heavy).", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "overtoneFalloff", "display": "Harmonics Falloff", "tooltip": "Rate at which higher overtones decay.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "squareDuty", "display": "Square Duty", "tooltip": "Square only — duty cycle.", "default": 0.0, "min": 0.0, "max": 0.99, "kind": "RANGE"},
	{"name": "dutySweep", "display": "Duty Sweep", "tooltip": "Square only — sweeps duty.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "repeatSpeed", "display": "Repeat Speed", "tooltip": "Speed at which sweeps reset.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "flangerOffset", "display": "Flanger Offset", "tooltip": "Phase offset for a second copy of the wave.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "flangerSweep", "display": "Flanger Sweep", "tooltip": "Sweeps the flanger phase.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "lpFilterCutoff", "display": "Low-pass Filter Cutoff", "tooltip": "Frequency at which the low-pass starts attenuating.", "default": 1.0, "min": 0.01, "max": 1.0, "kind": "RANGE"},
	{"name": "lpFilterCutoffSweep", "display": "Low-pass Filter Cutoff Sweep", "tooltip": "Sweeps the low-pass cutoff.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "lpFilterResonance", "display": "Low-pass Filter Resonance", "tooltip": "Low-pass attenuation rate.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "hpFilterCutoff", "display": "High-pass Filter Cutoff", "tooltip": "Frequency at which the high-pass starts attenuating lower frequencies.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "hpFilterCutoffSweep", "display": "High-pass Filter Cutoff Sweep", "tooltip": "Sweeps the high-pass cutoff.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
	{"name": "bitCrush", "display": "Bit Crush", "tooltip": "Resamples at a lower frequency.", "default": 0.0, "min": 0.0, "max": 1.0, "kind": "RANGE"},
	{"name": "bitCrushSweep", "display": "Bit Crush Sweep", "tooltip": "Sweeps the bit-crush amount.", "default": 0.0, "min": -1.0, "max": 1.0, "kind": "RANGE"},
]

const PERMALOCKED := ["masterVolume"]

# Generator presets: [display_name, method_name]
const TEMPLATES := [
	["Pickup/Coin", "generate_pickup_coin"],
	["Laser/Shoot", "generate_laser_shoot"],
	["Explosion", "generate_explosion"],
	["Powerup", "generate_powerup"],
	["Hit/Hurt", "generate_hit_hurt"],
	["Jump", "generate_jump"],
	["Blip/Select", "generate_blip_select"],
	["Randomize", "randomize_params"],
	["Mutate", "mutate_params"],
]

var params: Dictionary = {}
var locked_params: Dictionary = {}
var last_buffer: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	params = default_params()
	for k in params.keys():
		locked_params[k] = false
	for k in PERMALOCKED:
		locked_params[k] = true


func default_params() -> Dictionary:
	var d := {}
	for info in PARAM_INFO:
		d[info["name"]] = info["default"]
	return d


func reset_params(check_locked: bool = false) -> void:
	var d := default_params()
	for k in d.keys():
		if check_locked and locked_param(k):
			continue
		params[k] = d[k]


func locked_param(name: String) -> bool:
	if name in PERMALOCKED:
		return true
	return locked_params.get(name, false)


func set_locked_param(name: String, value: bool) -> void:
	if name in PERMALOCKED:
		locked_params[name] = true
		return
	locked_params[name] = value


# Param info helpers
func get_param_info(name: String) -> Dictionary:
	for info in PARAM_INFO:
		if info["name"] == name:
			return info
	return {}


func param_min(name: String) -> float:
	var i := get_param_info(name)
	return float(i.get("min", 0.0))


func param_max(name: String) -> float:
	var i := get_param_info(name)
	return float(i.get("max", 1.0))


func param_default(name: String) -> float:
	var i := get_param_info(name)
	return float(i.get("default", 0.0))


func get_param(name: String) -> float:
	return float(params.get(name, 0.0))


func set_param(name: String, value, check_locked: bool = false) -> void:
	if not params.has(name):
		push_error("VGSFX: unknown param: " + name)
		return
	if check_locked and locked_param(name):
		return
	var info := get_param_info(name)
	var lo: float = float(info.get("min", 0.0))
	var hi: float = float(info.get("max", 1.0))
	var v := float(value)
	if info.get("kind", "RANGE") == "BUTTONSELECT":
		v = float(int(v))
		if v >= hi:
			v = hi - 1.0
	params[name] = clamp(v, lo, hi)


# === Bfxr-specific randomization helpers ===
func _select_random_wave_type(names: Array) -> int:
	var pick = names[randi() % names.size()]
	return WAVE_NAMES[pick]


func _generate_random_centered_around_x(lo: float, hi: float, centre: float) -> float:
	var r: float = randf()
	r = pow(r, 2)
	if randf() < 0.5:
		return centre + r * (hi - centre)
	return centre - r * (centre - lo)


# === Templates (1:1 with Bfxr.js) ===
func generate_pickup_coin() -> void:
	reset_params(true)
	set_param("frequency_start", 0.4 + randf() * 0.5, true)
	set_param("sustainTime", randf() * 0.1, true)
	set_param("decayTime", 0.1 + randf() * 0.4, true)
	set_param("sustainPunch", 0.3 + randf() * 0.3, true)
	if randf() < 0.5:
		var cnum := (randi() % 7) + 1
		var cden := (randi() % 7) + cnum + 2
		set_param("pitch_jump_amount", float(cnum) / float(cden), true)


func generate_laser_shoot() -> void:
	reset_params(true)
	set_param("waveType", randi() % 3, true)
	if int(get_param("waveType")) == 2 and randf() < 0.5:
		set_param("waveType", randi() % 2, true)

	if randf() < 0.33:
		set_param("frequency_start", 0.1 + randf() * 0.5, true)
		set_param("min_frequency_relative_to_starting_frequency", randf() * 0.1, true)
		set_param("frequency_slide", -0.35 - randf() * 0.3, true)
	else:
		set_param("frequency_start", 0.5 + randf() * 0.5, true)
		set_param("min_frequency_relative_to_starting_frequency", get_param("frequency_start") - 0.2 - randf() * 0.6, true)
		if get_param("min_frequency_relative_to_starting_frequency") < 0.2:
			set_param("min_frequency_relative_to_starting_frequency", 0.2, true)
		set_param("frequency_slide", -0.15 - randf() * 0.2, true)

	if get_param("frequency_start") < 0.15:
		set_param("min_frequency_relative_to_starting_frequency", 0.0, true)
		set_param("frequency_slide", -0.1 - randf() * 0.1, true)

	if randf() < 0.5:
		set_param("squareDuty", randf() * 0.5, true)
		set_param("dutySweep", randf() * 0.2, true)
	else:
		set_param("squareDuty", 0.4 + randf() * 0.5, true)
		set_param("dutySweep", -randf() * 0.7, true)

	set_param("sustainTime", 0.1 + randf() * 0.2, true)
	set_param("decayTime", randf() * 0.4, true)
	if randf() < 0.5:
		set_param("sustainPunch", randf() * 0.3, true)

	if randf() < 0.33:
		set_param("flangerOffset", randf() * 0.2, true)
		set_param("flangerSweep", -randf() * 0.2, true)

	if randf() < 0.5:
		set_param("hpFilterCutoff", randf() * 0.3, true)


func generate_explosion() -> void:
	reset_params(true)
	if randf() < 0.5:
		set_param("waveType", 3, true)  # White
	else:
		set_param("waveType", 9, true)  # Bitnoise

	if randf() < 0.5:
		set_param("frequency_start", 0.1 + randf() * 0.4, true)
		set_param("frequency_slide", -0.1 + randf() * 0.4, true)
	else:
		set_param("frequency_start", 0.2 + randf() * 0.7, true)
		set_param("frequency_slide", -0.2 - randf() * 0.2, true)

	set_param("frequency_start", get_param("frequency_start") * get_param("frequency_start"), true)

	if randf() < 0.2:
		set_param("frequency_slide", 0.0, true)
	if randf() < 0.33:
		set_param("repeatSpeed", 0.3 + randf() * 0.5, true)

	set_param("sustainTime", 0.1 + randf() * 0.3, true)
	set_param("decayTime", randf() * 0.5, true)
	set_param("sustainPunch", 0.2 + randf() * 0.6, true)

	if randf() < 0.5:
		set_param("flangerOffset", -0.3 + randf() * 0.9, true)
		set_param("flangerSweep", -randf() * 0.3, true)

	if randf() < 0.33:
		set_param("pitch_jump_amount", 0.8 - randf() * 1.6, true)


func generate_powerup() -> void:
	reset_params(true)
	if randf() < 0.5:
		set_param("waveType", 1, true)  # Saw
	else:
		set_param("squareDuty", randf() * 0.6, true)

	if randf() < 0.5:
		set_param("frequency_start", 0.2 + randf() * 0.3, true)
		set_param("frequency_slide", 0.1 + randf() * 0.4, true)
		set_param("repeatSpeed", 0.4 + randf() * 0.4, true)
	else:
		set_param("frequency_start", 0.2 + randf() * 0.3, true)
		set_param("frequency_slide", 0.05 + randf() * 0.2, true)
		if randf() < 0.5:
			set_param("vibratoDepth", randf() * 0.7, true)
			set_param("vibratoSpeed", randf() * 0.6, true)

	set_param("sustainTime", randf() * 0.4, true)
	set_param("decayTime", 0.1 + randf() * 0.4, true)


func generate_hit_hurt() -> void:
	reset_params(true)
	set_param("waveType", _select_random_wave_type(["White", "Bitnoise", "Saw", "Square", "Voice"]), true)
	if int(get_param("waveType")) == 0:
		set_param("squareDuty", randf() * 0.6, true)
	set_param("frequency_start", 0.2 + randf() * 0.6, true)
	set_param("frequency_slide", -0.3 - randf() * 0.4, true)
	set_param("sustainTime", randf() * 0.1, true)
	set_param("decayTime", 0.1 + randf() * 0.2, true)
	if randf() < 0.5:
		set_param("hpFilterCutoff", randf() * 0.3, true)


func generate_jump() -> void:
	reset_params(true)
	set_param("waveType", _select_random_wave_type(["Square", "Saw", "FMSyn"]), true)
	set_param("squareDuty", randf() * 0.6, true)
	set_param("frequency_start", 0.3 + randf() * 0.3, true)
	set_param("frequency_slide", 0.1 + randf() * 0.2, true)
	set_param("sustainTime", 0.1 + randf() * 0.3, true)
	set_param("decayTime", 0.1 + randf() * 0.2, true)
	if randf() < 0.5:
		set_param("hpFilterCutoff", randf() * 0.3, true)
	if randf() < 0.5:
		set_param("lpFilterCutoff", 1.0 - randf() * 0.6, true)


func generate_blip_select() -> void:
	reset_params(true)
	set_param("waveType", _select_random_wave_type(["Square", "Saw", "FMSyn", "Whistle"]), true)
	if int(get_param("waveType")) == 0:
		set_param("squareDuty", randf() * 0.6, true)
	set_param("frequency_start", 0.2 + randf() * 0.4, true)
	set_param("sustainTime", 0.1 + randf() * 0.1, true)
	set_param("decayTime", randf() * 0.2, true)
	set_param("hpFilterCutoff", 0.1, true)


func randomize_params() -> void:
	for name in params.keys():
		if locked_params.get(name, false):
			continue
		var lo := param_min(name)
		var hi := param_max(name)
		var dv := param_default(name)
		var r: float = randf()
		if RANDOMIZATION_POWER.has(name):
			r = pow(r, RANDOMIZATION_POWER[name])
		var above: bool = randf() < 0.5
		if lo == dv:
			above = true
		if hi == dv:
			above = false
		if above:
			params[name] = dv + (hi - dv) * r
		else:
			params[name] = dv - (dv - lo) * r

	if not locked_params.get("waveType", false):
		# Uniform across all 12 waves (matches WaveTypeWeights all-1)
		set_param("waveType", randi() % WAVE_NAMES.size(), true)

	if randf() < 0.5:
		set_param("repeatSpeed", 0.0, true)

	set_param("min_frequency_relative_to_starting_frequency", 0.0, true)
	set_param("compressionAmount", 0.0, true)

	rectify_params()


func mutate_params() -> void:
	# Small chance to mutate the wave-type
	if randf() < 0.1:
		var count := WAVE_NAMES.size()
		var random_offset := randi() % (count - 1)
		var new_idx := (int(get_param("waveType")) + random_offset) % count
		set_param("waveType", new_idx, true)
		return

	for info in PARAM_INFO:
		if randf() < 0.5:
			continue
		if info["kind"] != "RANGE":
			continue
		var name: String = info["name"]
		if locked_param(name):
			continue
		var lo: float = info["min"]
		var hi: float = info["max"]
		var range: float = hi - lo
		var diff: float = (randf() - 0.5) * 0.1 * range
		set_param(name, params[name] + diff, true)

	rectify_params()


func rectify_params() -> void:
	var freq_default := param_default("frequency_start")
	if int(get_param("waveType")) == 11:
		freq_default = 0.22
	set_param("frequency_start", _generate_random_centered_around_x(0.0, 0.6, freq_default), true)

	if not locked_params.get("sustainTime", false) and not locked_params.get("decayTime", false):
		if get_param("attackTime") + get_param("sustainTime") + get_param("decayTime") < 0.2:
			set_param("sustainTime", 0.2 + randf() * 0.3)
			set_param("decayTime", 0.2 + randf() * 0.3)

	var r: float = randf() * randf()
	set_param("sustainPunch", r * r, true)

	if (get_param("frequency_start") > 0.7 and get_param("frequency_slide") > 0.2) \
		or (get_param("frequency_start") < 0.2 and get_param("frequency_slide") < -0.05):
		set_param("frequency_slide", -get_param("frequency_slide"), true)

	if get_param("lpFilterCutoff") < 0.1 and get_param("lpFilterCutoffSweep") < 0:
		set_param("lpFilterCutoffSweep", -get_param("lpFilterCutoffSweep") + 0.2, true)

	if int(get_param("waveType")) != 0:
		set_param("squareDuty", param_default("squareDuty"), true)
		set_param("dutySweep", param_default("dutySweep"), true)
	else:
		var duty := get_param("squareDuty")
		var rp := randf()
		if duty > 0.7 and rp < 0.5:
			set_param("dutySweep", -randf() * 0.5, true)


func param_is_disabled(name: String) -> bool:
	if int(get_param("waveType")) != 0:
		if name == "squareDuty" or name == "dutySweep":
			return true
	if name == "min_frequency_relative_to_starting_frequency":
		if get_param("frequency_slide") >= 0 and get_param("frequency_acceleration") >= 0:
			return true
	return false


# === DSP driver ===
func generate_sound() -> PackedFloat32Array:
	var dsp = VGSFXDSP_.new(params.duplicate(), self)
	last_buffer = dsp.generate_sound()
	return last_buffer


# === WAV export ===
func to_audio_stream_wav() -> AudioStreamWAV:
	# Always regenerate — params may have changed since the last call
	# (e.g. via a preset generator or slider drag). Reusing a stale buffer
	# would silently play the previous sound after a Pickup/Laser/Mutate.
	generate_sound()
	var n := last_buffer.size()
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in range(n):
		var s: float = clamp(last_buffer[i], -1.0, 1.0)
		var v: int = int(round(s * 32767.0))
		# little-endian 16-bit signed
		pcm[i * 2] = v & 0xFF
		pcm[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = VGSFXDSP_.SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


# === Save / Load .bfxr (JSON of params) ===
func save_to_dictionary() -> Dictionary:
	return {"version": VERSION, "name": NAME, "params": params.duplicate()}


func load_from_dictionary(d: Dictionary) -> void:
	if not d.has("params"):
		return
	var defaults := default_params()
	for k in defaults.keys():
		if d["params"].has(k):
			set_param(k, d["params"][k], false)
		else:
			params[k] = defaults[k]
