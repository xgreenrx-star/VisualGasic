@tool
extends Node
## Voice I/O controller for the AI Help panel — Tier 2.5a.
##
## Provides push-to-talk speech input (STT) and spoken AI replies (TTS).
## Mirrors the local-first, cloud-fallback design of vg_ai_providers.gd:
##
##   STT backends: "openai"  → /v1/audio/transcriptions (multipart upload)
##                 "whisper" → local `whisper.cpp` binary on PATH
##                 "off"     → disabled
##
##   TTS backends: "openai"  → /v1/audio/speech (returns mp3)
##                 "piper"   → local `piper` binary on PATH (returns wav)
##                 "system"  → OS-native (espeak / SAPI / `say`)  — last resort
##                 "off"     → disabled
##
## The controller owns the AudioServer bus + AudioStreamPlayer + capture effect
## so callers don't have to manage audio plumbing.  Recording is fixed-duration
## by default (max_record_seconds) but can be stopped early with stop_recording().
##
## Settings are persisted in user://vg_ai_voice.cfg.

const AIProviders := preload("res://addons/visual_gasic/vg_ai_providers.gd")

const CFG_PATH := "user://vg_ai_voice.cfg"
const RECORD_BUS_NAME := "VGRecord"
const SAMPLE_RATE := 16000        # Whisper expects 16 kHz mono; we'll downmix on save
const MAX_RECORD_SECONDS := 30.0  # Hard cap so a runaway PTT can't exhaust RAM

# OpenAI endpoints
const OPENAI_STT_URL := "https://api.openai.com/v1/audio/transcriptions"
const OPENAI_TTS_URL := "https://api.openai.com/v1/audio/speech"
const OPENAI_STT_MODEL := "whisper-1"
const OPENAI_TTS_MODEL := "tts-1"
const OPENAI_TTS_DEFAULT_VOICE := "alloy"

# ─── Signals ────────────────────────────────────────────────────────────────
signal recording_started()
signal recording_finished(duration_sec: float)
signal recording_failed(reason: String)

signal transcription_started()
signal transcribed(text: String)
signal transcription_failed(reason: String)

signal speech_started()
signal speech_finished()
signal speech_failed(reason: String)

# ─── State ──────────────────────────────────────────────────────────────────
var _record_bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _record_frames: PackedVector2Array = PackedVector2Array()
var _record_start_ms: int = 0
var _record_timer: Timer = null
var _is_recording: bool = false

var _stt_http: HTTPRequest = null
var _tts_http: HTTPRequest = null
var _tts_player: AudioStreamPlayer = null
var _is_transcribing: bool = false
var _is_speaking: bool = false
# PID of the most recent external TTS subprocess (system espeak / SAPI), or
# -1 when none is alive.  Tracked so stop_speaking() can actually interrupt
# Narcea mid-sentence — fire-and-forget OS.create_process gave us no way to
# silence her until this was added (May 3 2026 user request).
var _tts_pid: int = -1

# Settings (loaded from CFG_PATH)
var stt_backend: String = "openai"        # "openai" | "whisper" | "off"
var tts_backend: String = "openai"        # "openai" | "piper" | "system" | "off"
var tts_voice: String = OPENAI_TTS_DEFAULT_VOICE
var auto_speak_replies: bool = true
# Default to "whisper-cli" (the actual binary name shipped by
# whisper.cpp's modern build).  Older installs used a wrapper called
# "whisper" — autodetect handles both.  Override via voice settings.
var whisper_cpp_path: String = "whisper-cli"  # binary on PATH or absolute
var whisper_cpp_model: String = ""        # e.g. "/usr/share/whisper/ggml-tiny.en.bin"
var piper_path: String = "piper"
var piper_voice_path: String = ""         # e.g. "/usr/share/piper/en_US-amy-low.onnx"

# Per-persona override: filename like "en_GB-alan-medium.onnx".  Resolved
# relative to the directory of `piper_voice_path` so users only need to
# configure the voices folder once.  Empty = use piper_voice_path as-is.
var piper_voice_override: String = ""

# Speech rate scale.  1.0 = normal; >1 = faster; <1 = slower.  Forwarded to
# every backend that supports it: OpenAI `speed` (clamped 0.25..4.0),
# Piper `--length-scale` (inverse \u2014 length-scale 1/scale), espeak `-s WPM`
# (175 * scale), macOS `say -r WPM`, SAPI `$s.Rate` (-10..10 mapped from
# log2 of scale).  The AI panel sets this from the active persona so
# Skippy can sound manic and HAL can sound serene.
var tts_speed_scale: float = 1.0

# ─── Lifecycle ──────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_settings()
	_setup_audio()
	_setup_http()

func _exit_tree() -> void:
	if _is_recording:
		_force_stop_recording()
	_teardown_audio()

# ─── Audio bus + mic init ───────────────────────────────────────────────────
func _setup_audio() -> void:
	# Idempotent: if a previous instance left the bus around, reuse it.
	_record_bus_idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
	if _record_bus_idx == -1:
		AudioServer.add_bus()
		_record_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_record_bus_idx, RECORD_BUS_NAME)
		AudioServer.set_bus_mute(_record_bus_idx, true)  # don't echo mic to speakers

	# Find or attach the capture effect.
	var effect_count := AudioServer.get_bus_effect_count(_record_bus_idx)
	for i in effect_count:
		var e := AudioServer.get_bus_effect(_record_bus_idx, i)
		if e is AudioEffectCapture:
			_capture_effect = e
			break
	if _capture_effect == null:
		_capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(_record_bus_idx, _capture_effect)

	# AudioStreamPlayer feeding from the microphone.
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS_NAME
	add_child(_mic_player)

	# TTS playback player.
	_tts_player = AudioStreamPlayer.new()
	_tts_player.bus = "Master"
	_tts_player.finished.connect(_on_tts_finished)
	add_child(_tts_player)

	_record_timer = Timer.new()
	_record_timer.wait_time = 0.05  # 20 Hz capture-drain
	_record_timer.one_shot = false
	_record_timer.timeout.connect(_on_record_tick)
	add_child(_record_timer)

func _teardown_audio() -> void:
	# Don't remove the bus — Godot complains if other nodes still reference it.
	# Just stop the player; the bus persists harmlessly until editor exit.
	if is_instance_valid(_mic_player):
		_mic_player.stop()

func _setup_http() -> void:
	_stt_http = HTTPRequest.new()
	_stt_http.timeout = 60.0
	_stt_http.use_threads = true
	add_child(_stt_http)
	_stt_http.request_completed.connect(_on_stt_response)

	_tts_http = HTTPRequest.new()
	_tts_http.timeout = 60.0
	_tts_http.use_threads = true
	add_child(_tts_http)
	_tts_http.request_completed.connect(_on_tts_response)

# ─── Settings persistence ───────────────────────────────────────────────────
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var had_cfg := cfg.load(CFG_PATH) == OK
	if had_cfg:
		stt_backend = cfg.get_value("voice", "stt_backend", stt_backend)
		tts_backend = cfg.get_value("voice", "tts_backend", tts_backend)
		tts_voice = cfg.get_value("voice", "tts_voice", tts_voice)
		auto_speak_replies = cfg.get_value("voice", "auto_speak_replies", auto_speak_replies)
		whisper_cpp_path = cfg.get_value("voice", "whisper_cpp_path", whisper_cpp_path)
		whisper_cpp_model = cfg.get_value("voice", "whisper_cpp_model", whisper_cpp_model)
		piper_path = cfg.get_value("voice", "piper_path", piper_path)
		piper_voice_path = cfg.get_value("voice", "piper_voice_path", piper_voice_path)
	# Autodetect a working local whisper.cpp install.  This runs on every
	# load so users who install whisper after first-run still pick it up,
	# but it never overwrites a user choice: we only fill in unset paths
	# and only switch the backend away from "openai" if no OpenAI key is
	# configured (i.e. the cloud path would fail anyway).
	_autodetect_whisper(had_cfg)
	_autodetect_piper(had_cfg)

func _autodetect_whisper(had_cfg: bool) -> void:
	# Resolve binary if the configured one is missing.
	if not _binary_exists(whisper_cpp_path):
		var found_bin := _find_whisper_binary()
		if not found_bin.is_empty():
			whisper_cpp_path = found_bin
	# Resolve model if unset and binary is now usable.
	if whisper_cpp_model.is_empty() and _binary_exists(whisper_cpp_path):
		var found_model := _find_whisper_model()
		if not found_model.is_empty():
			whisper_cpp_model = found_model
	# Auto-switch backend on first run when local whisper is reachable but
	# no OpenAI key is set — avoids the "requires an OpenAI API key" error
	# screen for users who already have whisper.cpp installed locally.
	var local_ready := _binary_exists(whisper_cpp_path) and not whisper_cpp_model.is_empty()
	var has_openai_key := not AIProviders.load_api_key("openai").is_empty()
	if not had_cfg and local_ready and not has_openai_key and stt_backend == "openai":
		stt_backend = "whisper"

func _find_whisper_binary() -> String:
	# Try common binary names on PATH first.
	for name in ["whisper-cli", "whisper", "whisper.cpp"]:
		if _binary_exists(name):
			return name
	# Then try absolute paths in standard install locations.
	var home := OS.get_environment("HOME")
	var candidates: Array[String] = []
	if OS.has_feature("windows"):
		candidates.append_array([
			"C:/Program Files/whisper.cpp/whisper-cli.exe",
			"C:/whisper.cpp/whisper-cli.exe",
		])
	else:
		candidates.append_array([
			home + "/.local/share/whisper/whisper.cpp/build/bin/whisper-cli",
			home + "/.local/share/whisper/whisper.cpp/main",
			home + "/whisper.cpp/build/bin/whisper-cli",
			home + "/whisper.cpp/main",
			"/opt/whisper.cpp/build/bin/whisper-cli",
			"/opt/whisper.cpp/main",
			"/usr/local/bin/whisper-cli",
			"/usr/local/bin/whisper",
		])
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

func _find_whisper_model() -> String:
	var home := OS.get_environment("HOME")
	# Search dirs ordered by typical preference (smaller/faster models first).
	var dirs: Array[String] = []
	if OS.has_feature("windows"):
		dirs.append_array([
			"C:/Program Files/whisper.cpp/models",
			"C:/whisper.cpp/models",
		])
	else:
		dirs.append_array([
			home + "/.local/share/whisper",
			home + "/.local/share/whisper/whisper.cpp/models",
			home + "/whisper.cpp/models",
			"/opt/whisper.cpp/models",
			"/usr/share/whisper",
		])
	# Preferred filenames in preference order — base.en gives noticeably
	# better accuracy than tiny.en and is still fast on a modern CPU, so
	# we prefer it when both are present.  small.en is preferred over
	# tiny.en for the same reason.
	var preferred: Array[String] = [
		"ggml-base.en.bin", "ggml-base.bin",
		"ggml-small.en.bin", "ggml-small.bin",
		"ggml-tiny.en.bin", "ggml-tiny.bin",
	]
	for d in dirs:
		for m in preferred:
			var p: String = d + "/" + m
			if FileAccess.file_exists(p):
				return p
	# Fall back to any *.bin in the search dirs.
	for d in dirs:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var f := dir.get_next()
			if f == "":
				break
			if f.ends_with(".bin") and f.begins_with("ggml-"):
				dir.list_dir_end()
				return d + "/" + f
		dir.list_dir_end()
	return ""

func _autodetect_piper(had_cfg: bool) -> void:
	# Resolve piper binary if the configured one is missing.
	if not _binary_exists(piper_path):
		var found_bin := _find_piper_binary()
		if not found_bin.is_empty():
			piper_path = found_bin
	# Resolve voice if unset and binary is now usable.
	if piper_voice_path.is_empty() and _binary_exists(piper_path):
		var found_voice := _find_piper_voice()
		if not found_voice.is_empty():
			piper_voice_path = found_voice
	# Auto-switch TTS backend on first run when local piper is reachable
	# but no OpenAI key is set.  Piper-medium voices sound markedly
	# better than OpenAI tts-1 anyway, so we prefer it when present.
	var local_ready := _binary_exists(piper_path) and not piper_voice_path.is_empty()
	var has_openai_key := not AIProviders.load_api_key("openai").is_empty()
	if not had_cfg and local_ready and not has_openai_key and tts_backend == "openai":
		tts_backend = "piper"

func _find_piper_binary() -> String:
	if _binary_exists("piper"):
		return "piper"
	var home := OS.get_environment("HOME")
	var candidates: Array[String] = []
	if OS.has_feature("windows"):
		candidates.append_array([
			"C:/Program Files/piper/piper.exe",
			"C:/piper/piper.exe",
			home + "/AppData/Local/piper/piper.exe",
		])
	else:
		candidates.append_array([
			home + "/.local/share/piper/piper/piper",
			home + "/.local/share/piper/piper",
			home + "/piper/piper",
			"/opt/piper/piper",
			"/usr/local/bin/piper",
		])
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""

func _find_piper_voice() -> String:
	var home := OS.get_environment("HOME")
	var dirs: Array[String] = []
	if OS.has_feature("windows"):
		dirs.append_array([
			"C:/Program Files/piper/voices",
			"C:/piper/voices",
			home + "/AppData/Local/piper/voices",
		])
	else:
		dirs.append_array([
			home + "/.local/share/piper",
			home + "/.local/share/piper/voices",
			home + "/.local/share/piper/piper",
			home + "/piper/voices",
			"/opt/piper/voices",
			"/usr/share/piper",
		])
	# Preference order — pleasant US English female-medium first.
	var preferred: Array[String] = [
		"en_US-amy-medium.onnx",
		"en_US-lessac-medium.onnx",
		"en_US-hfc_female-medium.onnx",
		"en_US-ryan-medium.onnx",
		"en_GB-alan-medium.onnx",
		"en_GB-northern_english_male-medium.onnx",
	]
	for d in dirs:
		for v in preferred:
			var p: String = d + "/" + v
			if FileAccess.file_exists(p):
				return p
	# Fall back to any *-medium.onnx in the search dirs.
	for d in dirs:
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		while true:
			var f := dir.get_next()
			if f == "":
				break
			if f.ends_with("-medium.onnx") or f.ends_with(".onnx"):
				dir.list_dir_end()
				return d + "/" + f
		dir.list_dir_end()
	return ""

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # ok if missing
	cfg.set_value("voice", "stt_backend", stt_backend)
	cfg.set_value("voice", "tts_backend", tts_backend)
	cfg.set_value("voice", "tts_voice", tts_voice)
	cfg.set_value("voice", "auto_speak_replies", auto_speak_replies)
	cfg.set_value("voice", "whisper_cpp_path", whisper_cpp_path)
	cfg.set_value("voice", "whisper_cpp_model", whisper_cpp_model)
	cfg.set_value("voice", "piper_path", piper_path)
	cfg.set_value("voice", "piper_voice_path", piper_voice_path)
	cfg.save(CFG_PATH)

# ─── Public API: status ─────────────────────────────────────────────────────
func is_recording() -> bool:
	return _is_recording

func is_transcribing() -> bool:
	return _is_transcribing

func is_speaking() -> bool:
	return _is_speaking

func is_busy() -> bool:
	return _is_recording or _is_transcribing or _is_speaking

## Returns "" if mic input is enabled and a backend is reachable, or a
## human-readable message describing what's wrong otherwise.
func diagnose() -> String:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return "Audio input is disabled in Project Settings.  Enable [b]audio/driver/enable_input[/b] and restart Godot to use voice mode."
	if stt_backend == "off":
		return "Speech-to-text is disabled — choose a backend in Voice Settings."
	if stt_backend == "openai" and AIProviders.load_api_key("openai").is_empty():
		return "OpenAI Whisper requires an OpenAI API key.  Open the AI Help panel ⚙️ button to set one."
	if stt_backend == "whisper" and not _binary_exists(whisper_cpp_path):
		return "whisper.cpp not found at [b]%s[/b].  Install it or update the path in Voice Settings." % whisper_cpp_path
	return ""

# ─── Public API: recording ──────────────────────────────────────────────────
func start_recording() -> bool:
	if _is_recording:
		return false
	var problem := diagnose()
	if not problem.is_empty():
		recording_failed.emit(problem)
		return false
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		# Enable for next session and tell the caller — can't init mid-session.
		ProjectSettings.set_setting("audio/driver/enable_input", true)
		ProjectSettings.save()
		recording_failed.emit("Microphone input was just enabled in Project Settings — please restart Godot once and try again.")
		return false

	_record_frames.clear()
	# Drain any stale frames the capture effect held from a previous session.
	if _capture_effect:
		_capture_effect.clear_buffer()

	_record_start_ms = Time.get_ticks_msec()
	_is_recording = true
	_mic_player.play()
	_record_timer.start()
	recording_started.emit()
	return true

func stop_recording() -> void:
	if not _is_recording:
		return
	_force_stop_recording()
	var dur_sec: float = (Time.get_ticks_msec() - _record_start_ms) / 1000.0
	recording_finished.emit(dur_sec)
	# Auto-transcribe; the panel will set up listeners before calling.
	_transcribe_recorded()

func _force_stop_recording() -> void:
	_is_recording = false
	if is_instance_valid(_record_timer):
		_record_timer.stop()
	if is_instance_valid(_mic_player) and _mic_player.playing:
		_mic_player.stop()

func _on_record_tick() -> void:
	if not _is_recording or _capture_effect == null:
		return
	var available := _capture_effect.get_frames_available()
	if available > 0:
		var chunk := _capture_effect.get_buffer(available)
		_record_frames.append_array(chunk)
	# Hard cap.
	var elapsed: float = (Time.get_ticks_msec() - _record_start_ms) / 1000.0
	if elapsed >= MAX_RECORD_SECONDS:
		stop_recording()

# ─── Public API: speak ──────────────────────────────────────────────────────
func speak(text: String) -> void:
	if tts_backend == "off" or text.strip_edges().is_empty():
		return
	if _is_speaking:
		stop_speaking()
	# Effective backend: if OpenAI is selected (default) but no key is
	# configured, silently fall back to system TTS (espeak / say / SAPI)
	# so voice mode works out of the box for users who haven't bought an
	# OpenAI key yet. Same fallback if `piper` is selected but the binary
	# is missing.
	var effective: String = tts_backend
	if effective == "openai":
		var key: String = AIProviders.load_api_key("openai") if AIProviders else ""
		if key.is_empty():
			effective = "system"
	elif effective == "piper":
		if not _binary_exists(piper_path):
			effective = "system"
	match effective:
		"openai":
			_speak_openai(text)
		"piper":
			_speak_piper(text)
		"system":
			_speak_system(text)
		_:
			speech_failed.emit("Unknown TTS backend: %s" % tts_backend)

func stop_speaking() -> void:
	# 1. Stop any AudioStreamPlayer-driven playback (OpenAI / Piper produce a
	#    WAV that we play in-process).
	if is_instance_valid(_tts_player):
		_tts_player.stop()
	# 2. Kill the external TTS subprocess if one is running (system backend
	#    on Linux/macOS/Windows — espeak / say / powershell SAPI).  Without
	#    this Narcea kept talking after the user clicked Stop because the
	#    OS process owns its own audio path.
	if _tts_pid > 0:
		OS.kill(_tts_pid)
		_tts_pid = -1
	if _is_speaking:
		_is_speaking = false
		speech_finished.emit()

# ─── Transcription dispatch ─────────────────────────────────────────────────
func _transcribe_recorded() -> void:
	if _record_frames.is_empty():
		transcription_failed.emit("No audio captured — was the microphone connected?")
		return
	transcription_started.emit()
	_is_transcribing = true
	var wav_bytes := _frames_to_wav_bytes(_record_frames, AudioServer.get_mix_rate())
	match stt_backend:
		"openai":
			_stt_openai(wav_bytes)
		"whisper":
			_stt_whisper_cpp(wav_bytes)
		_:
			_is_transcribing = false
			transcription_failed.emit("STT backend disabled.")

# ─── WAV encoding (16-bit PCM mono) ─────────────────────────────────────────
##
## Converts a stereo Float32 capture buffer into a 16-bit mono PCM WAV at
## SAMPLE_RATE Hz (downsampling by linear interpolation).  Whisper API and
## whisper.cpp both accept this format directly.
func _frames_to_wav_bytes(frames: PackedVector2Array, source_rate: float) -> PackedByteArray:
	# Step 1: downmix to mono.
	var mono_in := PackedFloat32Array()
	mono_in.resize(frames.size())
	for i in frames.size():
		var f: Vector2 = frames[i]
		mono_in[i] = (f.x + f.y) * 0.5

	# Step 2: linearly resample to SAMPLE_RATE.
	var ratio: float = source_rate / float(SAMPLE_RATE)
	var out_count: int = int(floor(mono_in.size() / ratio))
	var mono_out := PackedFloat32Array()
	mono_out.resize(out_count)
	for j in out_count:
		var src_idx_f: float = j * ratio
		var src_idx: int = int(src_idx_f)
		var frac: float = src_idx_f - src_idx
		var a: float = mono_in[src_idx] if src_idx < mono_in.size() else 0.0
		var b: float = mono_in[src_idx + 1] if src_idx + 1 < mono_in.size() else a
		mono_out[j] = a + (b - a) * frac

	# Step 3: float → s16le.
	var pcm := PackedByteArray()
	pcm.resize(mono_out.size() * 2)
	for k in mono_out.size():
		var clamped: float = clamp(mono_out[k], -1.0, 1.0)
		var s: int = int(clamped * 32767.0)
		pcm.encode_s16(k * 2, s)

	# Step 4: prepend RIFF header.  WAV layout (44 bytes for std PCM):
	#   0  "RIFF"     |  4  ChunkSize u32 |  8  "WAVE"
	#  12  "fmt "     | 16  Subchunk1Size u32=16
	#  20  Format u16=1 (PCM) | 22  Channels u16=1
	#  24  SampleRate u32     | 28  ByteRate u32
	#  32  BlockAlign u16=2   | 34  BitsPerSample u16=16
	#  36  "data"     | 40  Subchunk2Size u32 = data_size
	#  44  <pcm payload>
	var data_size: int = pcm.size()
	var hdr := PackedByteArray()
	hdr.resize(44)
	# ASCII tags as raw bytes (R=0x52 I=0x49 F=0x46  W=0x57 A=0x41 V=0x56 E=0x45  d=0x64 a=0x61 t=0x74).
	hdr[0]=0x52; hdr[1]=0x49; hdr[2]=0x46; hdr[3]=0x46           # "RIFF"
	hdr.encode_u32(4, 36 + data_size)
	hdr[8]=0x57; hdr[9]=0x41; hdr[10]=0x56; hdr[11]=0x45          # "WAVE"
	hdr[12]=0x66; hdr[13]=0x6D; hdr[14]=0x74; hdr[15]=0x20        # "fmt "
	hdr.encode_u32(16, 16)
	hdr.encode_u16(20, 1)
	hdr.encode_u16(22, 1)
	hdr.encode_u32(24, SAMPLE_RATE)
	hdr.encode_u32(28, SAMPLE_RATE * 2)
	hdr.encode_u16(32, 2)
	hdr.encode_u16(34, 16)
	hdr[36]=0x64; hdr[37]=0x61; hdr[38]=0x74; hdr[39]=0x61        # "data"
	hdr.encode_u32(40, data_size)
	hdr.append_array(pcm)
	return hdr

# ─── STT: OpenAI Whisper API ────────────────────────────────────────────────
func _stt_openai(wav_bytes: PackedByteArray) -> void:
	var key: String = AIProviders.load_api_key("openai")
	if key.is_empty():
		_is_transcribing = false
		transcription_failed.emit("No OpenAI API key configured.")
		return

	# Build multipart body.
	var boundary := "----vgaiboundary%d" % Time.get_ticks_msec()
	var body := PackedByteArray()
	var nl := "\r\n"

	# field: model
	body.append_array(("--%s%s" % [boundary, nl]).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"model\"%s%s" % [nl, nl]).to_utf8_buffer())
	body.append_array((OPENAI_STT_MODEL + nl).to_utf8_buffer())

	# field: response_format = json
	body.append_array(("--%s%s" % [boundary, nl]).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"response_format\"%s%s" % [nl, nl]).to_utf8_buffer())
	body.append_array(("json" + nl).to_utf8_buffer())

	# field: file
	body.append_array(("--%s%s" % [boundary, nl]).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"clip.wav\"%s" % nl).to_utf8_buffer())
	body.append_array(("Content-Type: audio/wav%s%s" % [nl, nl]).to_utf8_buffer())
	body.append_array(wav_bytes)
	body.append_array(nl.to_utf8_buffer())

	# closing boundary
	body.append_array(("--%s--%s" % [boundary, nl]).to_utf8_buffer())

	var headers := PackedStringArray([
		"Authorization: Bearer " + key,
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
	])
	var err := _stt_http.request_raw(OPENAI_STT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_transcribing = false
		transcription_failed.emit("Failed to send STT request: " + error_string(err))

func _on_stt_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_transcribing = false
	if result != HTTPRequest.RESULT_SUCCESS:
		transcription_failed.emit("Transcription HTTP error: " + error_string(result))
		return
	if code != 200:
		var msg := body.get_string_from_utf8()
		if msg.length() > 240:
			msg = msg.substr(0, 240) + "…"
		transcription_failed.emit("Transcription HTTP %d: %s" % [code, msg])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		transcription_failed.emit("Could not parse transcription response.")
		return
	var text: String = String(parsed.get("text", "")).strip_edges()
	if text.is_empty():
		transcription_failed.emit("Transcription was empty.")
		return
	transcribed.emit(text)

# ─── STT: local whisper.cpp ─────────────────────────────────────────────────
func _stt_whisper_cpp(wav_bytes: PackedByteArray) -> void:
	if not _binary_exists(whisper_cpp_path):
		_is_transcribing = false
		transcription_failed.emit("whisper.cpp not on PATH (%s)." % whisper_cpp_path)
		return
	if whisper_cpp_model.is_empty() or not FileAccess.file_exists(whisper_cpp_model):
		_is_transcribing = false
		transcription_failed.emit("whisper.cpp model not found: %s" % whisper_cpp_model)
		return

	var temp_dir := OS.get_user_data_dir().path_join("vg_voice_tmp")
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var wav_path := temp_dir.path_join("rec.wav")
	var f := FileAccess.open(wav_path, FileAccess.WRITE)
	if f == null:
		_is_transcribing = false
		transcription_failed.emit("Cannot write temp WAV: %s" % wav_path)
		return
	f.store_buffer(wav_bytes)
	f.close()

	# whisper.cpp -m <model> -f <wav> -otxt -of <prefix>
	var prefix := temp_dir.path_join("rec")
	var args := PackedStringArray([
		"-m", whisper_cpp_model,
		"-f", wav_path,
		"-otxt",
		"-of", prefix,
		"-nt",          # no timestamps
		"-l", "auto",
	])
	var output: Array = []
	var exit := OS.execute(whisper_cpp_path, args, output, true, false)
	_is_transcribing = false
	if exit != 0:
		var stderr_text := "\n".join(output) if output.size() > 0 else ""
		transcription_failed.emit("whisper.cpp exited %d: %s" % [exit, stderr_text])
		return
	var txt_path := prefix + ".txt"
	if not FileAccess.file_exists(txt_path):
		transcription_failed.emit("whisper.cpp produced no output file.")
		return
	var rf := FileAccess.open(txt_path, FileAccess.READ)
	var text := rf.get_as_text().strip_edges() if rf else ""
	if rf:
		rf.close()
	if text.is_empty():
		transcription_failed.emit("Local transcription was empty.")
		return
	transcribed.emit(text)

# ─── TTS: OpenAI ────────────────────────────────────────────────────────────
func _speak_openai(text: String) -> void:
	var key: String = AIProviders.load_api_key("openai")
	if key.is_empty():
		speech_failed.emit("OpenAI TTS requires an API key (⚙️ in AI Help panel).")
		return
	var body := JSON.stringify({
		"model": OPENAI_TTS_MODEL,
		"input": text,
		"voice": tts_voice,
		# Persona-driven speed; OpenAI accepts 0.25..4.0.
		"speed": clampf(tts_speed_scale, 0.25, 4.0),
		"response_format": "mp3",
	})
	var headers := PackedStringArray([
		"Authorization: Bearer " + key,
		"Content-Type: application/json",
		"Accept: audio/mpeg",
	])
	_is_speaking = true
	speech_started.emit()
	var err := _tts_http.request(OPENAI_TTS_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_speaking = false
		speech_failed.emit("Failed to send TTS request: " + error_string(err))

func _on_tts_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_is_speaking = false
		var snippet := body.get_string_from_utf8().substr(0, 240)
		speech_failed.emit("TTS HTTP %d: %s" % [code, snippet])
		return
	# Save to temp + load as AudioStreamMP3.
	var temp := OS.get_user_data_dir().path_join("vg_voice_tmp")
	DirAccess.make_dir_recursive_absolute(temp)
	var mp3_path := temp.path_join("reply.mp3")
	var f := FileAccess.open(mp3_path, FileAccess.WRITE)
	if f == null:
		_is_speaking = false
		speech_failed.emit("Cannot write temp MP3.")
		return
	f.store_buffer(body)
	f.close()
	var stream := AudioStreamMP3.new()
	# Re-read as bytes — AudioStreamMP3.data takes a PackedByteArray.
	stream.data = body
	_tts_player.stream = stream
	_tts_player.play()

func _on_tts_finished() -> void:
	_is_speaking = false
	speech_finished.emit()

# ─── TTS: local piper ───────────────────────────────────────────────────────
func _speak_piper(text: String) -> void:
	if not _binary_exists(piper_path):
		speech_failed.emit("piper not on PATH (%s)." % piper_path)
		return
	# Resolve the active voice model: persona override (just a filename)
	# is looked up in the same directory as the configured piper_voice_path.
	var voice_path: String = piper_voice_path
	if not piper_voice_override.is_empty() and not piper_voice_path.is_empty():
		var dir: String = piper_voice_path.get_base_dir()
		var candidate: String = dir.path_join(piper_voice_override)
		if FileAccess.file_exists(candidate):
			voice_path = candidate
	if voice_path.is_empty() or not FileAccess.file_exists(voice_path):
		speech_failed.emit("piper voice model not found: %s" % voice_path)
		return
	var temp := OS.get_user_data_dir().path_join("vg_voice_tmp")
	DirAccess.make_dir_recursive_absolute(temp)
	var txt_path := temp.path_join("reply.txt")
	var wav_path := temp.path_join("reply.wav")
	var f := FileAccess.open(txt_path, FileAccess.WRITE)
	if f == null:
		speech_failed.emit("Cannot write temp TTS input.")
		return
	f.store_string(text)
	f.close()

	# piper --model <onnx> --output_file <wav> < text
	# OS.execute can't do stdin redirection directly; use a wrapper shell.
	# Honour the persona-driven speed scale: piper's `--length-scale` is
	# inverse to perceived speed (length 1/scale gives the right feel).
	var ls: float = clampf(1.0 / maxf(tts_speed_scale, 0.1), 0.25, 4.0)
	var ls_arg := " --length-scale %.3f" % ls
	var cmd: String
	var args: PackedStringArray
	if OS.has_feature("windows"):
		cmd = "cmd"
		args = PackedStringArray(["/c", "type \"%s\" | \"%s\" --model \"%s\"%s --output_file \"%s\"" % [
			txt_path, piper_path, voice_path, ls_arg, wav_path]])
	else:
		cmd = "sh"
		args = PackedStringArray(["-c", "cat '%s' | '%s' --model '%s'%s --output_file '%s'" % [
			txt_path, piper_path, voice_path, ls_arg, wav_path]])
	var output: Array = []
	_is_speaking = true
	speech_started.emit()
	var exit := OS.execute(cmd, args, output, true, false)
	if exit != 0 or not FileAccess.file_exists(wav_path):
		_is_speaking = false
		speech_failed.emit("piper exited %d: %s" % [exit, "\n".join(output)])
		return
	var bytes := FileAccess.get_file_as_bytes(wav_path)
	var stream := AudioStreamWAV.new()
	# Parse WAV header to set the right format.  Quick + dirty: assume s16le mono
	# 22050 Hz which matches piper's default low-quality voices.  For other
	# voices we'd need to read the header — defer until needed.
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes.slice(44)  # strip RIFF header (44 bytes for standard WAV)
	_tts_player.stream = stream
	_tts_player.play()

# ─── TTS: system fallback (espeak / SAPI / say) ─────────────────────────────
func _speak_system(text: String) -> void:
	var cmd: String = ""
	var args: PackedStringArray
	# Map persona speed-scale onto each engine's native rate units.
	var wpm := int(clamp(175.0 * tts_speed_scale, 80.0, 450.0))   # espeak / say
	# SAPI rate is roughly log2-spaced; clamp to its -10..10 range.
	var sapi_rate := int(clamp(round(log(tts_speed_scale) / log(2.0) * 10.0), -10.0, 10.0))
	if OS.has_feature("linux"):
		cmd = "espeak"
		args = PackedStringArray(["-s", str(wpm), text])
	elif OS.has_feature("macos"):
		cmd = "say"
		args = PackedStringArray(["-r", str(wpm), text])
	elif OS.has_feature("windows"):
		# PowerShell SAPI one-liner.
		var ps_text := text.replace("'", "''")
		cmd = "powershell"
		args = PackedStringArray(["-NoProfile", "-Command",
			"Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.Rate = %d; $s.Speak('%s')" % [sapi_rate, ps_text]])
	if cmd.is_empty() or not _binary_exists(cmd):
		speech_failed.emit("System TTS unavailable on this platform.")
		return
	# Fire-and-forget; system TTS plays through its own audio path.
	_is_speaking = true
	speech_started.emit()
	_tts_pid = OS.create_process(cmd, args)
	# We can't observe completion of an external process synchronously without
	# blocking; emit speech_finished after a short estimated delay so the panel
	# can re-enable the mic button.  Rough heuristic: 70ms / character.
	var delay := mini(15000, int((700 + text.length() * 70) / maxf(tts_speed_scale, 0.1)))
	get_tree().create_timer(delay / 1000.0).timeout.connect(_on_system_tts_estimated_done)

func _on_system_tts_estimated_done() -> void:
	_tts_pid = -1
	if _is_speaking:
		_is_speaking = false
		speech_finished.emit()

# ─── Helpers ────────────────────────────────────────────────────────────────
func _binary_exists(path: String) -> bool:
	if path.is_absolute_path():
		return FileAccess.file_exists(path)
	# Fall back to which / where.
	var args: PackedStringArray
	var cmd: String
	if OS.has_feature("windows"):
		cmd = "where"
		args = PackedStringArray([path])
	else:
		cmd = "which"
		args = PackedStringArray([path])
	var out: Array = []
	var exit := OS.execute(cmd, args, out, false, false)
	return exit == 0
