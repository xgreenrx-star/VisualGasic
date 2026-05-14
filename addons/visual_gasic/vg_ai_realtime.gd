@tool
extends Node
## Tier 2.5d — Full-duplex AI voice via WebSocket.
##
## Replaces the three-hop PTT→STT→LLM→TTS pipeline with a single persistent
## WebSocket connection that handles audio in, audio out, and text transcripts
## server-side.  Perceived latency drops from 3–8 s to ~300–500 ms.
##
## Supported backends:
##   "openai_realtime" — wss://api.openai.com/v1/realtime  (GPT-4o Realtime)
##   "gemini_live"     — wss://generativelanguage.googleapis.com/ws/...  (Gemini 2.0 Flash Live)
##   "off"             — disabled (default)
##
## Flow:
##   1. start_session()  → opens WebSocket, waits for server handshake
##   2. Mic audio captured → resampled → base64 PCM16 → sent as chunks
##   3. AI audio received → base64 PCM16 → pushed to AudioStreamGenerator
##   4. Text transcripts and reply deltas emitted as signals for the panel
##   5. stop_session()   → graceful WebSocket close

const AIProviders := preload("res://addons/visual_gasic/vg_ai_providers.gd")
const CFG_PATH := "user://vg_ai_realtime.cfg"

# ── Audio bus name (separate from the PTT bus in vg_ai_voice.gd) ────────────
const RECORD_BUS_NAME := "VGRealtimeRecord"

# ── OpenAI Realtime ──────────────────────────────────────────────────────────
const OPENAI_RT_URL     := "wss://api.openai.com/v1/realtime"
const OPENAI_RT_MODEL   := "gpt-4o-realtime-preview-2024-12-17"
const OPENAI_RATE       := 24000   # PCM16 24 kHz in + out

# ── Gemini Live ──────────────────────────────────────────────────────────────
const GEMINI_LIVE_URL   := "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent"
const GEMINI_LIVE_MODEL := "models/gemini-2.0-flash-live-001"
const GEMINI_INPUT_RATE  := 16000  # Gemini expects 16 kHz input
const GEMINI_OUTPUT_RATE := 24000  # Gemini returns 24 kHz output

# ── Signals ──────────────────────────────────────────────────────────────────
## Emitted once the server confirms the session is ready to accept audio.
signal session_started()
## Emitted after stop_session() completes cleanly.
signal session_stopped()
## Emitted when a non-recoverable error occurs; session is closed automatically.
signal session_failed(reason: String)
## Server-side VAD detected user started speaking.
signal listening_started()
## Server-side VAD detected user stopped speaking (end of turn).
signal listening_stopped()
## Incremental transcript of what the *user* said (from input transcription).
signal transcript_delta(text: String)
## Incremental text of what the *AI* is saying alongside its audio.
signal reply_delta(text: String)
## Full AI reply text once the response is complete.
signal reply_done(full_text: String)
## AI audio playback started.
signal reply_audio_started()
## AI audio playback finished.
signal reply_audio_done()

# ── Settings (persisted in CFG_PATH) ─────────────────────────────────────────
var realtime_backend: String = "off"         # "off" | "openai_realtime" | "gemini_live"
var openai_model: String = OPENAI_RT_MODEL
var gemini_model: String = GEMINI_LIVE_MODEL
## OpenAI voice name — applied in session.update.  Persona-driven.
var openai_voice: String = "alloy"
## System instructions injected by the AI help panel at session start.
var system_instructions: String = ""

# ── Runtime state ────────────────────────────────────────────────────────────
var _ws := WebSocketPeer.new()
var _session_active: bool = false
var _ws_state_prev: int = WebSocketPeer.STATE_CLOSED

var _poll_timer: Timer = null

# Mic capture
var _record_bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _capture_timer: Timer = null
var _mic_active: bool = false
# Float mono samples accumulated between 20ms drain ticks
var _capture_buf: PackedFloat32Array = PackedFloat32Array()

# AI audio output via streaming generator
var _gen_stream: AudioStreamGenerator = null
var _gen_player: AudioStreamPlayer = null
var _gen_playback: AudioStreamGeneratorPlayback = null
var _is_ai_speaking: bool = false

# Text accumulation for reply_done
var _reply_buf: String = ""

# Gemini: session is only ready after server sends setupComplete
var _gemini_setup_done: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_settings()
	_setup_audio()
	_setup_poll_timer()

func _exit_tree() -> void:
	stop_session()
	_teardown_audio()

# ── Audio setup ───────────────────────────────────────────────────────────────
func _setup_audio() -> void:
	# Capture bus (separate from vg_ai_voice.gd's "VGRecord" bus).
	_record_bus_idx = AudioServer.get_bus_index(RECORD_BUS_NAME)
	if _record_bus_idx == -1:
		AudioServer.add_bus()
		_record_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_record_bus_idx, RECORD_BUS_NAME)
		AudioServer.set_bus_mute(_record_bus_idx, true)

	# Reuse existing capture effect if one is already present on the bus.
	for i in AudioServer.get_bus_effect_count(_record_bus_idx):
		var e := AudioServer.get_bus_effect(_record_bus_idx, i)
		if e is AudioEffectCapture:
			_capture_effect = e
			break
	if _capture_effect == null:
		_capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(_record_bus_idx, _capture_effect)

	# AudioStreamPlayer driving the microphone into the capture bus.
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS_NAME
	add_child(_mic_player)

	# AudioStreamGenerator for low-latency AI audio playback.
	# mix_rate is updated per-backend when the session starts.
	_gen_stream = AudioStreamGenerator.new()
	_gen_stream.mix_rate = float(OPENAI_RATE)
	_gen_stream.buffer_length = 0.1  # 100 ms pre-buffer
	_gen_player = AudioStreamPlayer.new()
	_gen_player.stream = _gen_stream
	_gen_player.bus = "Master"
	add_child(_gen_player)

	# 20 Hz capture drain timer.
	_capture_timer = Timer.new()
	_capture_timer.wait_time = 0.05
	_capture_timer.one_shot = false
	_capture_timer.timeout.connect(_on_capture_tick)
	add_child(_capture_timer)

func _teardown_audio() -> void:
	if is_instance_valid(_mic_player):
		_mic_player.stop()
	if is_instance_valid(_gen_player):
		_gen_player.stop()

# ── WebSocket poll timer ───────────────────────────────────────────────────────
func _setup_poll_timer() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.02   # 50 Hz
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_ws_poll)
	add_child(_poll_timer)

# ── Public API ────────────────────────────────────────────────────────────────
## Returns true when a session is open and audio is flowing.
func is_session_active() -> bool:
	return _session_active

## Returns "" if the chosen backend can be used, or a human-readable problem.
func diagnose() -> String:
	if realtime_backend == "off":
		return "Realtime voice is disabled — pick a backend in Voice Settings."
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return "Audio input is disabled in Project Settings.  Enable audio/driver/enable_input and restart Godot."
	match realtime_backend:
		"openai_realtime":
			if AIProviders.load_api_key("openai").is_empty():
				return "OpenAI Realtime requires an OpenAI API key (⚙️ in AI Help panel)."
		"gemini_live":
			if AIProviders.load_api_key("gemini").is_empty():
				return "Gemini Live requires a Gemini API key (⚙️ in AI Help panel)."
	return ""

## Open a new realtime session.  Returns false and emits session_failed if the
## backend is not configured or the connection attempt fails.
func start_session() -> bool:
	if _session_active:
		return true
	var problem := diagnose()
	if not problem.is_empty():
		session_failed.emit(problem)
		return false
	_reply_buf = ""
	_is_ai_speaking = false
	_ws_state_prev = WebSocketPeer.STATE_CLOSED
	# Re-create the WebSocketPeer so headers from a previous session don't linger.
	_ws = WebSocketPeer.new()
	match realtime_backend:
		"openai_realtime":
			return _connect_openai()
		"gemini_live":
			return _connect_gemini()
	session_failed.emit("Unknown realtime backend: %s" % realtime_backend)
	return false

## Close the session gracefully.  Safe to call even when already closed.
func stop_session() -> void:
	_stop_mic()
	var ws_state := _ws.get_ready_state()
	if ws_state == WebSocketPeer.STATE_OPEN or ws_state == WebSocketPeer.STATE_CONNECTING:
		_ws.close(1000, "User ended session")
	_session_active = false
	_gemini_setup_done = false
	if is_instance_valid(_poll_timer) and _poll_timer.is_inside_tree():
		_poll_timer.stop()
	if is_instance_valid(_gen_player):
		_gen_player.stop()
	_gen_playback = null
	_is_ai_speaking = false
	_reply_buf = ""
	session_stopped.emit()

# ── Mic control ───────────────────────────────────────────────────────────────
func _start_mic() -> void:
	if _mic_active:
		return
	_capture_buf.clear()
	if _capture_effect:
		_capture_effect.clear_buffer()
	_mic_active = true
	_mic_player.play()
	_capture_timer.start()

func _stop_mic() -> void:
	if not _mic_active:
		return
	_mic_active = false
	if is_instance_valid(_capture_timer) and _capture_timer.is_inside_tree():
		_capture_timer.stop()
	if is_instance_valid(_mic_player) and _mic_player.playing:
		_mic_player.stop()

# ── Capture drain tick ────────────────────────────────────────────────────────
func _on_capture_tick() -> void:
	if not _mic_active or _capture_effect == null or not _session_active:
		return
	var available := _capture_effect.get_frames_available()
	if available <= 0:
		return
	# Downmix stereo float → mono float.
	var chunk := _capture_effect.get_buffer(available)
	for v: Vector2 in chunk:
		_capture_buf.append((v.x + v.y) * 0.5)

	# Only encode and send once we have at least 20 ms at the target rate.
	var target_rate: int = GEMINI_INPUT_RATE if realtime_backend == "gemini_live" else OPENAI_RATE
	var source_rate := float(AudioServer.get_mix_rate())
	var ratio := source_rate / float(target_rate)
	var available_at_target := int(_capture_buf.size() / ratio)
	if available_at_target < int(target_rate * 0.02):
		return

	# Linearly resample to target_rate.
	var out_count := int(_capture_buf.size() / ratio)
	var pcm := PackedByteArray()
	pcm.resize(out_count * 2)
	for j in out_count:
		var src_f := j * ratio
		var src_i := int(src_f)
		var frac := src_f - float(src_i)
		var a: float = _capture_buf[src_i] if src_i < _capture_buf.size() else 0.0
		var b: float = _capture_buf[src_i + 1] if src_i + 1 < _capture_buf.size() else a
		var s := int(clamp(a + (b - a) * frac, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(j * 2, s)
	_capture_buf.clear()

	# Base64-encode and dispatch.
	var b64 := Marshalls.raw_to_base64(pcm)
	match realtime_backend:
		"openai_realtime":
			_ws_send(JSON.stringify({"type": "input_audio_buffer.append", "audio": b64}))
		"gemini_live":
			_ws_send(JSON.stringify({
				"realtimeInput": {
					"mediaChunks": [{"mimeType": "audio/pcm;rate=%d" % GEMINI_INPUT_RATE, "data": b64}]
				}
			}))

# ── OpenAI Realtime ───────────────────────────────────────────────────────────
func _connect_openai() -> bool:
	var key: String = AIProviders.load_api_key("openai")
	_ws.handshake_headers = PackedStringArray([
		"Authorization: Bearer " + key,
		"OpenAI-Beta: realtime=v1",
	])
	_ws.supported_protocols = PackedStringArray(["realtime"])
	var url := "%s?model=%s" % [OPENAI_RT_URL, openai_model]
	var err := _ws.connect_to_url(url)
	if err != OK:
		session_failed.emit("WebSocket connect failed: " + error_string(err))
		return false
	_poll_timer.start()
	return true

func _openai_send_session_update() -> void:
	# Configure session: server-side VAD, audio in/out, voice, transcription.
	var cfg := {
		"modalities": ["text", "audio"],
		"instructions": system_instructions,
		"voice": openai_voice,
		"input_audio_format": "pcm16",
		"output_audio_format": "pcm16",
		"input_audio_transcription": {"model": "whisper-1"},
		"turn_detection": {
			"type": "server_vad",
			"threshold": 0.5,
			"prefix_padding_ms": 300,
			"silence_duration_ms": 600,
		},
	}
	_ws_send(JSON.stringify({"type": "session.update", "session": cfg}))

func _handle_openai_event(ev: Dictionary) -> void:
	var t: String = ev.get("type", "")
	match t:
		"session.created":
			# Server is ready → configure and open the mic.
			_openai_send_session_update()
			_session_active = true
			_start_mic()
			session_started.emit()

		"session.updated":
			pass  # acknowledgment, nothing to do

		"input_audio_buffer.speech_started":
			listening_started.emit()
			# Barge-in: stop AI audio immediately so it can hear the user.
			if _is_ai_speaking:
				_gen_player.stop()
				_gen_playback = null
				_is_ai_speaking = false
				reply_audio_done.emit()

		"input_audio_buffer.speech_stopped":
			listening_stopped.emit()

		"conversation.item.input_audio_transcription.delta":
			var delta: String = ev.get("delta", "")
			if not delta.is_empty():
				transcript_delta.emit(delta)

		"conversation.item.input_audio_transcription.completed":
			# Full transcript available; also emit as a delta for completeness.
			var text: String = ev.get("transcript", "")
			if not text.is_empty():
				transcript_delta.emit(text)

		"response.audio.delta":
			var audio_b64: String = ev.get("delta", "")
			if not audio_b64.is_empty():
				if not _is_ai_speaking:
					_is_ai_speaking = true
					_ensure_gen_playing(OPENAI_RATE)
					reply_audio_started.emit()
				_push_audio_to_generator(audio_b64)

		"response.audio.done":
			_is_ai_speaking = false
			reply_audio_done.emit()

		"response.audio_transcript.delta":
			var delta: String = ev.get("delta", "")
			if not delta.is_empty():
				_reply_buf += delta
				reply_delta.emit(delta)

		"response.audio_transcript.done":
			var full: String = ev.get("transcript", _reply_buf)
			reply_done.emit(full)
			_reply_buf = ""

		"response.done":
			pass  # all sub-events already handled above

		"error":
			var emsg: String = ev.get("error", {}).get("message", "Unknown error")
			session_failed.emit("OpenAI Realtime error: " + emsg)
			# Close cleanly; _on_ws_state_changed will emit session_stopped.
			_ws.close(1011, emsg)

# ── Gemini Live ───────────────────────────────────────────────────────────────
func _connect_gemini() -> bool:
	var key: String = AIProviders.load_api_key("gemini")
	# Gemini Live uses the API key as a URL parameter (required by the API).
	var url := "%s?key=%s" % [GEMINI_LIVE_URL, key]
	var err := _ws.connect_to_url(url)
	if err != OK:
		session_failed.emit("WebSocket connect failed: " + error_string(err))
		return false
	_gemini_setup_done = false
	_poll_timer.start()
	return true

func _gemini_send_setup() -> void:
	var msg := {
		"setup": {
			"model": gemini_model,
			"generationConfig": {
				"responseModalities": ["AUDIO"],
				"speechConfig": {
					"voiceConfig": {
						"prebuiltVoiceConfig": {"voiceName": "Puck"}
					}
				},
			},
			"systemInstruction": {
				"parts": [{"text": system_instructions}]
			}
		}
	}
	_ws_send(JSON.stringify(msg))

func _handle_gemini_event(ev: Dictionary) -> void:
	if ev.has("setupComplete"):
		_gemini_setup_done = true
		_session_active = true
		_start_mic()
		session_started.emit()
		return

	if ev.has("serverContent"):
		var sc: Dictionary = ev["serverContent"]
		var parts = sc.get("modelTurn", {}).get("parts", [])
		for part: Dictionary in parts:
			if part.has("inlineData"):
				var inline: Dictionary = part["inlineData"]
				var b64: String = inline.get("data", "")
				if not b64.is_empty():
					if not _is_ai_speaking:
						_is_ai_speaking = true
						_ensure_gen_playing(GEMINI_OUTPUT_RATE)
						reply_audio_started.emit()
					_push_audio_to_generator(b64)
			elif part.has("text"):
				var t: String = part["text"]
				if not t.is_empty():
					_reply_buf += t
					reply_delta.emit(t)

		if sc.get("turnComplete", false):
			if _is_ai_speaking:
				_is_ai_speaking = false
				reply_audio_done.emit()
			reply_done.emit(_reply_buf)
			_reply_buf = ""

	if ev.has("error"):
		var emsg := str(ev.get("error", "Unknown Gemini error"))
		session_failed.emit("Gemini Live error: " + emsg)
		_ws.close(1011, emsg)

# ── Audio generator ───────────────────────────────────────────────────────────
## Make sure the generator player is running at the given sample_rate.
## If it's already playing at the correct rate, this is a no-op.
func _ensure_gen_playing(sample_rate: int) -> void:
	if _gen_stream.mix_rate != float(sample_rate):
		_gen_stream.mix_rate = float(sample_rate)
		_gen_player.stop()
	if not _gen_player.playing:
		_gen_player.play()
		_gen_playback = null
	if _gen_playback == null:
		_gen_playback = _gen_player.get_stream_playback() as AudioStreamGeneratorPlayback

## Decode a base64 PCM16 chunk and push each sample into the generator.
func _push_audio_to_generator(b64: String) -> void:
	var raw := Marshalls.base64_to_raw(b64)
	if raw.is_empty():
		return
	if _gen_playback == null:
		if not _gen_player.playing:
			_gen_player.play()
		_gen_playback = _gen_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _gen_playback == null:
		return
	var num_samples := raw.size() / 2
	for i in num_samples:
		var s16: int = raw.decode_s16(i * 2)
		var f: float = float(s16) / 32768.0
		_gen_playback.push_frame(Vector2(f, f))

## Stop AI audio immediately (barge-in / user-requested stop).
func stop_ai_audio() -> void:
	if is_instance_valid(_gen_player):
		_gen_player.stop()
	_gen_playback = null
	if _is_ai_speaking:
		_is_ai_speaking = false
		reply_audio_done.emit()

# ── WebSocket polling ─────────────────────────────────────────────────────────
func _ws_poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state != _ws_state_prev:
		_on_ws_state_changed(state)
		_ws_state_prev = state
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			_on_ws_packet(pkt.get_string_from_utf8())

func _on_ws_state_changed(state: int) -> void:
	match state:
		WebSocketPeer.STATE_OPEN:
			# For Gemini, we send the setup message on connection.
			# For OpenAI, the server sends session.created and we respond.
			if realtime_backend == "gemini_live":
				_gemini_send_setup()

		WebSocketPeer.STATE_CLOSED:
			var was_active := _session_active
			_session_active = false
			_stop_mic()
			if is_instance_valid(_gen_player):
				_gen_player.stop()
			_gen_playback = null
			if is_instance_valid(_poll_timer) and _poll_timer.is_inside_tree():
				_poll_timer.stop()
			var code := _ws.get_close_code()
			var reason := _ws.get_close_reason()
			if was_active and code != 1000 and code != -1:
				session_failed.emit("Connection closed unexpectedly: %d %s" % [code, reason])
			elif was_active:
				session_stopped.emit()

func _on_ws_packet(text: String) -> void:
	if text.is_empty():
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	match realtime_backend:
		"openai_realtime":
			_handle_openai_event(parsed)
		"gemini_live":
			_handle_gemini_event(parsed)

func _ws_send(text: String) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(text)

# ── Settings persistence ──────────────────────────────────────────────────────
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		realtime_backend = cfg.get_value("realtime", "backend", realtime_backend)
		openai_model = cfg.get_value("realtime", "openai_model", openai_model)
		gemini_model = cfg.get_value("realtime", "gemini_model", gemini_model)
		openai_voice = cfg.get_value("realtime", "openai_voice", openai_voice)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # ok if missing — partial update
	cfg.set_value("realtime", "backend", realtime_backend)
	cfg.set_value("realtime", "openai_model", openai_model)
	cfg.set_value("realtime", "gemini_model", gemini_model)
	cfg.set_value("realtime", "openai_voice", openai_voice)
	cfg.save(CFG_PATH)
