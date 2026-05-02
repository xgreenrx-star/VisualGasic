# VGSFX — DSP core (port of bfxr2/js/audio/Bfxr_DSP.js).
#
# Ported from JavaScript to GDScript. Behaviour and parameter semantics are
# preserved 1:1 with bfxr2 v1.0.4 so that .bfxr files (and the bcol templates)
# behave identically.
#
# Original: bfxr2 © 2021 Stephen Lavelle (MIT)
# DSP derivation: Thomas Vian's SfxrSynth (Apache 2.0), itself based on
# DrPetter's Sfxr.
#
# See NOTICE.md for full license text.

class_name VGSFXDSP
extends RefCounted

const VGSFXAKWF_ := preload("res://addons/visual_gasic/plugins/vgsfx/vgsfx_akwf.gd")

const VERSION := "1.0.4"
const MIN_LENGTH := 0.18
const LO_RES_NOISE_PERIOD := 8
const SAMPLE_RATE := 44100
const BIT_DEPTH := 16

# Output buffer of float samples in [-1, 1]
var buffer: PackedFloat32Array = PackedFloat32Array()

# Cached parameter dict and the synth (used to resolve param min/max for Bitnoise)
var params: Dictionary = {}
var synth = null  # has param_min(name) / param_max(name)

# Runtime state -------------------------------------------------------------
var frequency_period_samples: float
var frequency_maxPeriod_samples: float
var pitch_jump_reached: bool
var pitch_jump_2_reached: bool

var masterVolume: float
var waveType: int
var sustainPunch: float
var phase: int
var minFreqency: float
var muted: bool
var overtones: float
var overtoneFalloff: float
var compression_factor: float
var filters: bool

var vibratoPhase: float
var vibratoSpeed: float
var vibratoAmplitude: float

var envelopeVolume: float
var envelopeStage: int
var envelopeTime: int
var envelopeLength0: float
var envelopeLength1: float
var envelopeLength2: float
var attack_length_samples: float
var envelope_full_length_samples: float

var envelopeOverLength0: float
var envelopeOverLength1: float
var envelopeOverLength2: float

var bitcrush_freq: float
var bitcrush_freq_sweep: float
var bitcrush_phase: float
var bitcrush_last: float

var flanger: bool
var flangerOffset: float
var flangerDeltaOffset: float
var flangerInt: int
var flangerPos: int
var flangerBuffer: PackedFloat32Array
var noiseBuffer: PackedFloat32Array
var pinkNoiseBuffer: PackedFloat32Array
var loResNoiseBuffer: PackedFloat32Array
var oneBitNoiseState: int
var oneBitNoise: float
var buzzState: int
var buzz: float

var repeat_timestamp_samples: int
var pitch_jump_repeat_length_samples: float
var pitch_jump_amount: float
var pitch_jump_2_amount: float
var pitch_jump_current_timestamp_samples: int
var pitch_jump_timestamp_sample: float
var pitch_jump_2_timestamp_sample: float

var slide: float
var frequency_acceleration: float
var bitcrush_freq_init: float

var squareDuty: float
var dutySweep: float
var lpFilterCutoff: float
var lpFilterDeltaCutoff: float
var lpFilterDamping: float
var lpFilterOn: bool
var lpFilterPos: float
var lpFilterOldPos: float
var lpFilterDeltaPos: float
var hpFilterPos: float
var hpFilterCutoff: float
var hpFilterDeltaCutoff: float

var param_reset_period_samples: float
var param_reset_current_timestamp_samples: int

# Per-iteration scratch
var periodTemp: int
var sample: float
var pos: float
var superSample: float
var sampleCount: int


func _init(p_params: Dictionary, p_synth = null) -> void:
	params = p_params
	synth = p_synth
	flangerBuffer = PackedFloat32Array()
	noiseBuffer = PackedFloat32Array()
	pinkNoiseBuffer = PackedFloat32Array()
	loResNoiseBuffer = PackedFloat32Array()
	reset(true)


static func _lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


# Mirrors Bfxr_DSP.clampTotalLength
func clamp_total_length(p: Dictionary) -> void:
	var totalTime: float = p["attackTime"] + p["sustainTime"] + p["decayTime"]
	if totalTime < MIN_LENGTH:
		var multiplier: float = MIN_LENGTH / totalTime
		p["attackTime"] = p["attackTime"] * multiplier
		p["sustainTime"] = p["sustainTime"] * multiplier
		p["decayTime"] = p["decayTime"] * multiplier


func reset(total_reset: bool = true) -> void:
	var p := params

	frequency_period_samples = 100.0 / (p["frequency_start"] * p["frequency_start"] + 0.001)
	var minimum_frequency: float = pow(p["min_frequency_relative_to_starting_frequency"], 0.4) * p["frequency_start"]
	frequency_maxPeriod_samples = 100.0 / (minimum_frequency * minimum_frequency + 0.001)

	pitch_jump_reached = false
	pitch_jump_2_reached = false

	if total_reset:
		masterVolume = p["masterVolume"] * p["masterVolume"]
		waveType = int(p["waveType"])

		if p["sustainTime"] < 0.01:
			p["sustainTime"] = 0.01

		clamp_total_length(p)

		sustainPunch = p["sustainPunch"]
		phase = 0
		minFreqency = p["min_frequency_relative_to_starting_frequency"]
		muted = false
		overtones = p["overtones"] * 10.0
		overtoneFalloff = p["overtoneFalloff"]

		compression_factor = 1.0 / (1.0 + 4.0 * p["compressionAmount"])

		filters = p["lpFilterCutoff"] != 1.0 or p["hpFilterCutoff"] != 0.0

		vibratoPhase = 0.0
		vibratoSpeed = p["vibratoSpeed"] * p["vibratoSpeed"] * 0.01
		vibratoAmplitude = p["vibratoDepth"] * 0.5

		envelopeVolume = 0.0
		envelopeStage = 0
		envelopeTime = 0
		envelopeLength0 = p["attackTime"] * p["attackTime"] * 100000.0
		envelopeLength1 = p["sustainTime"] * p["sustainTime"] * 100000.0
		envelopeLength2 = p["decayTime"] * p["decayTime"] * 100000.0 + 10.0
		attack_length_samples = envelopeLength0
		envelope_full_length_samples = envelopeLength0 + envelopeLength1 + envelopeLength2

		bitcrush_freq_sweep = -p["bitCrushSweep"] / envelope_full_length_samples
		bitcrush_phase = 0.0
		bitcrush_last = 0.0

		envelopeOverLength0 = 1.0 / envelopeLength0
		envelopeOverLength1 = 1.0 / envelopeLength1
		envelopeOverLength2 = 1.0 / envelopeLength2

		flanger = p["flangerOffset"] != 0.0 or p["flangerSweep"] != 0.0

		flangerDeltaOffset = p["flangerSweep"] * p["flangerSweep"] * p["flangerSweep"] * 0.2
		flangerPos = 0

		if flangerBuffer.size() != 1024:
			flangerBuffer.resize(1024)
		if noiseBuffer.size() != 32:
			noiseBuffer.resize(32)
		if pinkNoiseBuffer.size() != 32:
			pinkNoiseBuffer.resize(32)
		if loResNoiseBuffer.size() != 32:
			loResNoiseBuffer.resize(32)

		oneBitNoiseState = 1 << 14
		oneBitNoise = 0.0
		buzzState = 1 << 14
		buzz = 0.0

		for i in range(1024):
			flangerBuffer[i] = 0.0
		for i in range(32):
			noiseBuffer[i] = randf() * 2.0 - 1.0
		for i in range(32):
			loResNoiseBuffer[i] = (randf() * 2.0 - 1.0) if (i % LO_RES_NOISE_PERIOD) == 0 else loResNoiseBuffer[i - 1]

		repeat_timestamp_samples = 0

		# pitch_jump_repeat_length_samples — see Bfxr_DSP.js notes
		pitch_jump_repeat_length_samples = _lerp(envelope_full_length_samples, float(SAMPLE_RATE) / 50.0, p["pitch_jump_repeat_speed"]) + 32.0

		var pitch_jump_window_size_samples := envelope_full_length_samples
		if pitch_jump_repeat_length_samples > 0:
			pitch_jump_window_size_samples = pitch_jump_repeat_length_samples

		if p["pitch_jump_amount"] > 0.0:
			pitch_jump_amount = 1.0 - p["pitch_jump_amount"] * p["pitch_jump_amount"] * 0.9
		else:
			pitch_jump_amount = 1.0 + p["pitch_jump_amount"] * p["pitch_jump_amount"] * 10.0

		if p["pitch_jump_2_amount"] > 0.0:
			pitch_jump_2_amount = 1.0 - p["pitch_jump_2_amount"] * p["pitch_jump_2_amount"] * 0.9
		else:
			pitch_jump_2_amount = 1.0 + p["pitch_jump_2_amount"] * p["pitch_jump_2_amount"] * 10.0

		pitch_jump_current_timestamp_samples = 0

		if p["pitch_jump_onset_percent"] == 1.0:
			pitch_jump_timestamp_sample = 0
		else:
			pitch_jump_timestamp_sample = p["pitch_jump_onset_percent"] * pitch_jump_window_size_samples + 32.0
		if p["pitch_jump_onset2_percent"] == 1.0:
			pitch_jump_2_timestamp_sample = 0
		else:
			pitch_jump_2_timestamp_sample = p["pitch_jump_onset2_percent"] * pitch_jump_window_size_samples + 32.0

		# Bitnoise (waveType 9) frequency remapping
		if waveType == 9 and synth != null:
			var sf: float = p["frequency_start"]
			var mf: float = p["min_frequency_relative_to_starting_frequency"]

			var startFrequency_min: float = synth.param_min("frequency_start")
			var startFrequency_max: float = synth.param_max("frequency_start")
			var startFrequency_mid: float = (startFrequency_max + startFrequency_min) / 2.0

			var minFrequency_min: float = synth.param_min("min_frequency_relative_to_starting_frequency")
			var minFrequency_max: float = synth.param_max("min_frequency_relative_to_starting_frequency")
			var minFrequency_mid: float = (minFrequency_max + minFrequency_min) / 2.0

			var delta_start: float = (sf - startFrequency_min) / (startFrequency_max - startFrequency_min)
			var delta_min: float = (mf - minFrequency_min) / (minFrequency_max - minFrequency_min)

			sf = startFrequency_mid + delta_start
			mf = minFrequency_mid + delta_min

			frequency_period_samples = 100.0 / (sf * sf + 0.001)
			frequency_maxPeriod_samples = 100.0 / (mf * mf + 0.001)

	# === sweep params (re-applied on every reset, including repeat-resets) ===
	slide = 1.0 - p["frequency_slide"] * p["frequency_slide"] * p["frequency_slide"] * 0.01
	frequency_acceleration = -p["frequency_acceleration"] * p["frequency_acceleration"] * p["frequency_acceleration"] * 0.000001

	flangerOffset = p["flangerOffset"] * p["flangerOffset"] * 1020.0
	if p["flangerOffset"] < 0.0:
		flangerOffset = -flangerOffset

	bitcrush_freq = 1.0 - pow(p["bitCrush"], 1.0 / 3.0)

	if int(p["waveType"]) == 0:
		squareDuty = 0.5 - p["squareDuty"] * 0.5
		dutySweep = -p["dutySweep"] * 0.00005

	lpFilterCutoff = p["lpFilterCutoff"] * p["lpFilterCutoff"] * p["lpFilterCutoff"] * 0.1
	lpFilterDeltaCutoff = 1.0 + p["lpFilterCutoffSweep"] * 0.0001
	lpFilterDamping = 5.0 / (1.0 + p["lpFilterResonance"] * p["lpFilterResonance"] * 20.0) * (0.01 + lpFilterCutoff)
	if lpFilterDamping > 0.8:
		lpFilterDamping = 0.8
	lpFilterDamping = 1.0 - lpFilterDamping
	lpFilterOn = p["lpFilterCutoff"] != 1.0

	lpFilterPos = 0.0
	lpFilterDeltaPos = 0.0
	hpFilterPos = 0.0
	hpFilterCutoff = p["hpFilterCutoff"] * p["hpFilterCutoff"] * 0.1
	hpFilterDeltaCutoff = 1.0 + p["hpFilterCutoffSweep"] * 0.0003

	param_reset_period_samples = _lerp(envelope_full_length_samples, float(SAMPLE_RATE) / 10.0, p["repeatSpeed"])
	param_reset_current_timestamp_samples = 0


# Inner sample-loop. Returns the buffer (also stored in self.buffer).
func generate_sound() -> PackedFloat32Array:
	var length := int(envelope_full_length_samples)
	var buf := PackedFloat32Array()
	buf.resize(length)

	sampleCount = 0
	var finished := false
	var last_nonzero_sample_index := -1

	var tempsample: float
	var value: float
	var amp: float
	var sample_index: int
	var wave_sample: float
	var feedBit: int
	var n: int

	for i in range(length):
		if finished:
			break

		# Repeats every param_reset_period_samples, partially resetting params
		if param_reset_period_samples != 0:
			param_reset_current_timestamp_samples += 1
			if param_reset_current_timestamp_samples >= param_reset_period_samples:
				param_reset_current_timestamp_samples = 0
				reset(false)

		pitch_jump_current_timestamp_samples += 1
		if pitch_jump_current_timestamp_samples >= pitch_jump_repeat_length_samples:
			pitch_jump_current_timestamp_samples = 0
			if pitch_jump_reached:
				frequency_period_samples /= pitch_jump_amount
				pitch_jump_reached = false
			if pitch_jump_2_reached:
				frequency_period_samples /= pitch_jump_2_amount
				pitch_jump_2_reached = false

		if not pitch_jump_reached:
			if pitch_jump_current_timestamp_samples >= pitch_jump_timestamp_sample:
				pitch_jump_reached = true
				frequency_period_samples *= pitch_jump_amount

		if not pitch_jump_2_reached:
			if pitch_jump_current_timestamp_samples >= pitch_jump_2_timestamp_sample:
				frequency_period_samples *= pitch_jump_2_amount
				pitch_jump_2_reached = true

		# Accelerate and apply slide
		slide += frequency_acceleration
		frequency_period_samples *= slide

		# Frequency cutoff
		if frequency_period_samples > frequency_maxPeriod_samples:
			frequency_period_samples = frequency_maxPeriod_samples
			if minFreqency > 0.0:
				muted = true

		periodTemp = int(frequency_period_samples)

		# Vibrato
		if vibratoAmplitude > 0.0:
			vibratoPhase += vibratoSpeed
			periodTemp = int(frequency_period_samples * (1.0 + sin(vibratoPhase) * vibratoAmplitude))

		if periodTemp < 8:
			periodTemp = 8

		# Square duty sweep
		if waveType == 0:
			squareDuty += dutySweep
			if squareDuty < 0.0:
				squareDuty = 0.001
			elif squareDuty > 0.5:
				squareDuty = 0.5

		# Volume envelope
		envelopeTime += 1
		if envelopeTime > attack_length_samples:
			envelopeTime = 0
			envelopeStage += 1
			match envelopeStage:
				1:
					attack_length_samples = envelopeLength1
				2:
					attack_length_samples = envelopeLength2

		match envelopeStage:
			0:
				envelopeVolume = envelopeTime * envelopeOverLength0
			1:
				envelopeVolume = 1.0 + (1.0 - envelopeTime * envelopeOverLength1) * 2.0 * sustainPunch
			2:
				envelopeVolume = 1.0 - envelopeTime * envelopeOverLength2
			3:
				envelopeVolume = 0.0
				finished = true

		# Flanger offset
		if flanger:
			flangerOffset += flangerDeltaOffset
			flangerInt = int(flangerOffset)
			if flangerInt < 0:
				flangerInt = -flangerInt
			elif flangerInt > 1023:
				flangerInt = 1023

		# High-pass filter cutoff sweep
		if filters and hpFilterDeltaCutoff != 0.0:
			hpFilterCutoff *= hpFilterDeltaCutoff
			if hpFilterCutoff < 0.00001:
				hpFilterCutoff = 0.00001
			elif hpFilterCutoff > 0.1:
				hpFilterCutoff = 0.1

		superSample = 0.0
		for j in range(8):
			# Cycle through the period
			phase += 1
			if phase >= periodTemp:
				phase = phase - periodTemp

				# Generate new random noise on period rollover
				match waveType:
					3:  # White noise
						for nn in range(32):
							noiseBuffer[nn] = randf() * 2.0 - 1.0
					6:  # Tan
						for nn in range(32):
							loResNoiseBuffer[nn] = (randf() * 2.0 - 1.0) if (nn % LO_RES_NOISE_PERIOD) == 0 else loResNoiseBuffer[nn - 1]
					9:  # Bitnoise
						feedBit = ((oneBitNoiseState >> 1) & 1) ^ (oneBitNoiseState & 1)
						oneBitNoiseState = (oneBitNoiseState >> 1) | (feedBit << 14)
						oneBitNoise = float((~oneBitNoiseState) & 1) - 0.5

			sample = 0.0
			var overtonestrength: float = 1.0
			for k in range(int(overtones) + 1):
				var tempphase: int = (phase * (k + 1)) % periodTemp
				match waveType:
					0:  # Square
						sample += overtonestrength * (0.5 if (float(tempphase) / periodTemp) < squareDuty else -0.5)
					1:  # Saw
						sample += overtonestrength * (1.0 - (float(tempphase) / periodTemp) * 2.0)
					2:  # Sine (fast approx)
						pos = float(tempphase) / periodTemp
						pos = (pos - 1.0) * 6.28318531 if pos > 0.5 else pos * 6.28318531
						tempsample = 1.27323954 * pos + 0.405284735 * pos * pos if pos < 0 else 1.27323954 * pos - 0.405284735 * pos * pos
						sample += overtonestrength * (0.225 * (tempsample * -tempsample - tempsample) + tempsample if tempsample < 0 else 0.225 * (tempsample * tempsample - tempsample) + tempsample)
					3:  # White noise
						sample += overtonestrength * noiseBuffer[int(float(tempphase) * 32.0 / periodTemp) % 32]
					4:  # Triangle
						sample += overtonestrength * (abs(1.0 - (float(tempphase) / periodTemp) * 2.0) - 1.0)
					5:  # Organ (granular_0044)
						sample_index = int(float(tempphase) * 256.0 / periodTemp) % 256
						wave_sample = float(VGSFXAKWF_.granular_0044[sample_index]) / 32768.0 - 1.0
						sample += overtonestrength * wave_sample
					6:  # Tan
						sample += tan(PI * float(tempphase) / periodTemp) * overtonestrength
					7:  # Whistle (sin + 20x overtone)
						pos = float(tempphase) / periodTemp
						pos = (pos - 1.0) * 6.28318531 if pos > 0.5 else pos * 6.28318531
						tempsample = 1.27323954 * pos + 0.405284735 * pos * pos if pos < 0 else 1.27323954 * pos - 0.405284735 * pos * pos
						value = 0.75 * (0.225 * (tempsample * -tempsample - tempsample) + tempsample if tempsample < 0 else 0.225 * (tempsample * tempsample - tempsample) + tempsample)
						pos = float((tempphase * 20) % periodTemp) / periodTemp
						pos = (pos - 1.0) * 6.28318531 if pos > 0.5 else pos * 6.28318531
						tempsample = 1.27323954 * pos + 0.405284735 * pos * pos if pos < 0 else 1.27323954 * pos - 0.405284735 * pos * pos
						value += 0.25 * (0.225 * (tempsample * -tempsample - tempsample) + tempsample if tempsample < 0 else 0.225 * (tempsample * tempsample - tempsample) + tempsample)
						sample += overtonestrength * value
					8:  # Breaker
						amp = float(tempphase) / periodTemp
						sample += overtonestrength * (abs(1.0 - amp * amp * 2.0) - 1.0)
					9:  # Bitnoise
						sample += overtonestrength * oneBitNoise
					10:  # FMSyn (fmsynth_0012)
						sample_index = int(float(tempphase) * 256.0 / periodTemp) % 256
						wave_sample = float(VGSFXAKWF_.fmsynth_0012[sample_index]) / 32768.0 - 1.0
						sample += overtonestrength * wave_sample
					11:  # Voice (hvoice_0012)
						sample_index = int(float(tempphase) * 256.0 / periodTemp) % 256
						wave_sample = float(VGSFXAKWF_.hvoice_0012[sample_index]) / 32768.0 - 1.0
						sample += overtonestrength * wave_sample
				overtonestrength *= (1.0 - overtoneFalloff)

			# Low/high-pass filter
			if filters:
				lpFilterOldPos = lpFilterPos
				lpFilterCutoff *= lpFilterDeltaCutoff
				if lpFilterCutoff < 0.0:
					lpFilterCutoff = 0.0
				elif lpFilterCutoff > 0.1:
					lpFilterCutoff = 0.1

				if lpFilterOn:
					lpFilterDeltaPos += (sample - lpFilterPos) * lpFilterCutoff
					lpFilterDeltaPos *= lpFilterDamping
				else:
					lpFilterPos = sample
					lpFilterDeltaPos = 0.0

				lpFilterPos += lpFilterDeltaPos

				hpFilterPos += lpFilterPos - lpFilterOldPos
				hpFilterPos *= 1.0 - hpFilterCutoff
				sample = hpFilterPos

			# Flanger
			if flanger:
				flangerBuffer[flangerPos & 1023] = sample
				sample += flangerBuffer[(flangerPos - flangerInt + 1024) & 1023]
				flangerPos = (flangerPos + 1) & 1023

			superSample += sample

		# Clip
		if superSample > 8.0:
			superSample = 8.0
		elif superSample < -8.0:
			superSample = -8.0

		# Bit crush
		bitcrush_phase += bitcrush_freq
		if bitcrush_phase > 1.0:
			bitcrush_phase = 0.0
			bitcrush_last = superSample
		var multiplier: float = _lerp(1.0, 50.0 * bitcrush_freq, sqrt(bitcrush_freq))
		bitcrush_freq = clamp(bitcrush_freq + multiplier * bitcrush_freq_sweep, 0.00001, 1.0)
		superSample = bitcrush_last

		# Average super-samples + apply volumes
		superSample = masterVolume * envelopeVolume * superSample * 0.125

		# Compressor
		if superSample > 0.0:
			superSample = pow(superSample, compression_factor)
		else:
			superSample = -pow(-superSample, compression_factor)

		if muted:
			buf.resize(i)
			break

		if abs(superSample) > 0.2e-2:
			last_nonzero_sample_index = i
		buf[i] = clamp(superSample, -1.0, 1.0)

	# Trim trailing silence (min length 10)
	if last_nonzero_sample_index < buf.size() - 1:
		last_nonzero_sample_index = max(last_nonzero_sample_index, 10)
		buf.resize(last_nonzero_sample_index + 1)

	buffer = buf
	return buf
