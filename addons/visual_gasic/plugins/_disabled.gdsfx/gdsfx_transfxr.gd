# GDSFX Transfxr — transition synth.
#
# Renders a sound that smoothly morphs between TWO Bfxr parameter sets
# (params_l → params_r) across its duration using a tween curve.
#
# Upstream bfxr2 ships Transfxr.js as an incomplete experiment with no
# generate_sound() implementation. This port supplies one: it renders both
# endpoint sounds independently via GDSFXSynth/GDSFXDSP, then crossfades
# them sample-by-sample using the chosen tween function.
#
# Licensing: original concept MIT (c) Stephen Lavelle. See NOTICE.md.
@tool
class_name GDSFXTransfxr
extends RefCounted

const GDSFXSynth_ := preload("res://addons/visual_gasic/plugins/gdsfx/gdsfx_synth.gd")
const GDSFXDSP_ := preload("res://addons/visual_gasic/plugins/gdsfx/gdsfx_dsp.gd")

const VERSION := "1.0.0"
const NAME := "Transfxr"

const TWEEN_NAMES := [
	"Linear",
	"Ease In",
	"Triangle",
	"Bounce",
	"Cosine",
	"Accelerating Sine",
	"Decelerating Sine",
]

var params_l: Dictionary = {}
var params_r: Dictionary = {}
var tween_name: String = "Linear"
var last_buffer: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	var synth := GDSFXSynth_.new()
	params_l = synth.default_params()
	params_r = synth.default_params()


# === Tween curve ===
static func tween(name: String, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match name:
		"Linear":
			return t
		"Ease In":
			return t * t
		"Triangle":
			return 1.0 - absf(t - 0.5) * 2.0
		"Bounce":
			if t < 0.5:
				var x := t * 2.0
				return 1.0 - x * x
			else:
				var x := t * 2.0 - 1.0
				return x * x + 1.0
		"Cosine":
			return 1.0 - (cos(t * PI * 2.0) + 1.0) / 2.0
		"Accelerating Sine":
			return sin(t * PI * 2.0) * t
		"Decelerating Sine":
			return sin(t * PI * 2.0) * (1.0 - t)
		_:
			return t


# === Render ===
func generate_sound() -> PackedFloat32Array:
	var synth_l := GDSFXSynth_.new()
	synth_l.params = params_l.duplicate()
	var buf_l := synth_l.generate_sound()

	var synth_r := GDSFXSynth_.new()
	synth_r.params = params_r.duplicate()
	var buf_r := synth_r.generate_sound()

	var n: int = max(buf_l.size(), buf_r.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(max(n - 1, 1))
		var w: float = tween(tween_name, t)
		var s_l: float = buf_l[i] if i < buf_l.size() else 0.0
		var s_r: float = buf_r[i] if i < buf_r.size() else 0.0
		out[i] = s_l * (1.0 - w) + s_r * w
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
	stream.mix_rate = GDSFXDSP_.SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func save_to_dictionary() -> Dictionary:
	return {
		"_synth": NAME,
		"_version": VERSION,
		"params_l": params_l.duplicate(),
		"params_r": params_r.duplicate(),
		"tween_name": tween_name,
	}


func load_from_dictionary(d: Dictionary) -> void:
	if d.has("params_l"):
		params_l = (d["params_l"] as Dictionary).duplicate()
	if d.has("params_r"):
		params_r = (d["params_r"] as Dictionary).duplicate()
	if d.has("tween_name"):
		tween_name = String(d["tween_name"])
