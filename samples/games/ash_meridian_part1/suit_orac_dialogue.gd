extends Node

const LINES := {
	"syntax": [
		"The computer requires a valid instruction. Your intentions are not part of its command set.",
		"That is not a command. It is an arrangement of characters with ambitions.",
		"Correct the syntax. Repetition will not make it valid."
	],
	"missing_file": [
		"The directory lists what exists. Your preferred spelling does not add files to it.",
		"A filename is an identifier, not an invitation to improvise. LOAD \"$\",8 then LIST."
	],
	"not_loaded": [
		"SYS 49152 starts the loaded utility. You have omitted the loading. An economical but ineffective approach.",
		"Load Fast Hack'em first. The entry address is not a substitute for the program."
	],
	"basic_error": [
		"The error identifies the defect. I suggest correcting it before conducting the same experiment again.",
		"The machine has rejected the instruction. This is diagnostic information, not a difference of opinion."
	],
	"execution_limit": [
		"Your program has exhausted its execution allowance. An infinite loop is not evidence of sustained thought.",
		"Execution stopped at the limit. The loop needs an exit, not further encouragement."
	],
	"directory": [
		"A directory. It tells you what is on the disk. We have now established the purpose of directories.",
		"Fast Hack'em is listed. That reduces the remaining uncertainty to your typing."
	],
	"colour": [
		"The display is now a different colour. The security system remains entirely unimpressed.",
		"A successful alteration of the palette. Do not confuse it with access to the target."
	],
	"program": [
		"Your program is executing. I shall endeavour not to compete with it for intellectual distinction.",
		"BASIC is quite literal. For once, this should simplify our conversation."
	],
	"dead_trace": [
		"That trace terminates at the stop bar. You have connected to an absence of connection.",
		"A stopped line does not become a route because you prefer it to be one."
	],
	"join": [
		"Both neighbouring inputs must remain live. Two pulses on the same input are still one input.",
		"A join requires two distinct live inputs. The distinction is rather the point."
	],
	"repeater": [
		"The repeater will continue transmitting. It preserves the signal, not your ownership.",
		"That path is repeating. Whether it remains useful depends on where it leads."
	],
	"win": [
		"Ownership accepted. Your method was less efficient than my analysis. It was, however, sufficient.",
		"The target has accepted the transfer. I see no technical requirement for a celebration.",
		"Access obtained. You may stop attacking the system you now control."
	],
	"loss": [
		"The defender retained control. More enthusiasm would not have repaired the routing.",
		"Transfer rejected. Examine the paths before committing the next set of connectors.",
		"You have demonstrated that a connection and a useful connection are not equivalent."
	],
	"tie": [
		"Equal sector counts. A precise balance of effort and no transfer whatsoever.",
		"A tie. Neither side has acquired control. Calling it nearly successful would be inaccurate."
	]
}

var counts: Dictionary = {}
var cooldown := 0.0
var subtitle_left := 0.0
var last_line := ""
var last_event := ""
var awaiting_line := ""
var active_subtitle := false
var speech_error_seen := ""
var cached_playback := ""
var cached_stream: AudioStream
var registered_recordings: Dictionary = {}

func cache_path(line: String, speech: Object) -> String:
	var signature := "suit-orac-v1|" + str(speech.get("backend")) + "|" + str(speech.get("command"))
	signature += "|" + str(speech.call("BackendVoice", "ORAC"))
	signature += "|" + str(speech.call("DeliverySpeed", "ORAC", 0)) + "|" + str(speech.call("DeliverySilence", "ORAC", 0))
	return "user://suit-orac-voice/" + (signature + "|" + line).sha256_text() + ".res"

func register_cached_line(line: String, speech: Object) -> void:
	if speech != null and not speech.get("capture_only"):
		var path := cache_path(line, speech)
		var recordings: Dictionary = speech.get("recordings")
		var key: String = speech.call("RecordingKey", "ORAC", line)
		if registered_recordings.has(key) and registered_recordings[key].path != path:
			if recordings.get(key) == registered_recordings[key].stream:
				recordings.erase(key)
			registered_recordings.erase(key)
		if ResourceLoader.exists(path):
			var recording := load(path) as AudioStream
			if recording != null:
				recordings[key] = recording
				registered_recordings[key] = {"path": path, "stream": recording}
			else:
				push_error("Cannot load cached suit Orac voice: " + path)

func queue_line(line: String) -> void:
	var game := get_parent().get_parent()
	register_cached_line(line, game.get("speech"))
	game.call("OracSpeak", line)

func instruction(line: String) -> void:
	awaiting_line = ""
	last_line = ""
	active_subtitle = false
	get_parent().set("orac_message", line)
	if line != "":
		get_parent().get_parent().call("OracStop")
		queue_line(line)

func reset_dialogue() -> void:
	cooldown = 0
	subtitle_left = 0
	last_line = ""
	last_event = ""
	awaiting_line = ""
	active_subtitle = false
	speech_error_seen = ""

func advance(delta: float) -> void:
	cooldown = maxf(0, cooldown - maxf(delta, 0))
	subtitle_left = maxf(0, subtitle_left - maxf(delta, 0))
	var ring := get_parent()
	var game := ring.get_parent()
	var speech: Object = game.get("speech")
	var speaking := false
	if speech != null:
		speaking = str(speech.get("playing_speaker")).to_upper() == "ORAC"
		if not speech.get("capture_only") and speech.get("backend") != "native":
			speaking = speaking and speech.get("player").playing
		elif speech.get("backend") == "native":
			speaking = speaking and DisplayServer.tts_is_speaking()
		if speaking:
			var spoken := str(speech.get("playing_text"))
			if not speech.get("capture_only") and speech.get("backend") != "native" and (cached_playback != spoken or cached_stream != speech.get("player").stream):
				var path := cache_path(spoken, speech)
				if not ResourceLoader.exists(path):
					var error := DirAccess.make_dir_recursive_absolute("user://suit-orac-voice")
					if error == OK:
						error = ResourceSaver.save(speech.get("player").stream, path)
					if error != OK:
						push_error("Cannot cache suit Orac voice: " + error_string(error))
				cached_playback = spoken
				cached_stream = speech.get("player").stream
			if awaiting_line != "" and spoken == awaiting_line:
				ring.set("orac_message", awaiting_line)
				awaiting_line = ""
				active_subtitle = true
				subtitle_left = 12
		if awaiting_line != "" and (not game.get("opt_orac_voice") or not speech.call("busy")):
			# Keep information accessible when speech is disabled or synthesis fails.
			ring.set("orac_message", awaiting_line)
			awaiting_line = ""
			active_subtitle = true
			subtitle_left = 12
		var error_text := str(speech.get("last_error"))
		if error_text != "" and error_text != speech_error_seen:
			speech_error_seen = error_text
			push_warning("Suit Orac speech: " + error_text)
	if subtitle_left == 0 and active_subtitle and not speaking and last_line != "" and ring.get("orac_message") == last_line:
		ring.set("orac_message", "")
		last_line = ""
		active_subtitle = false

func remark(event_name: String, result: bool = false) -> bool:
	if not LINES.has(event_name):
		push_error("Unknown suit Orac dialogue event: " + event_name)
		return false
	var ring := get_parent()
	if not result and cooldown > 0:
		return false
	var game := ring.get_parent()
	var speech: Object = game.get("speech")
	# Optional commentary must not queue behind instructions or interrupt them.
	if not result and speech != null and speech.call("busy"):
		return false
	var index: int = counts.get(event_name, 0)
	var options: Array = LINES[event_name]
	last_line = options[index % options.size()]
	counts[event_name] = index + 1
	last_event = event_name
	var voiced: bool = game.get("opt_orac_voice") and speech != null
	if voiced:
		voiced = speech.get("enabled") and speech.get("backend") != ""
	awaiting_line = last_line if voiced else ""
	ring.set("orac_message", "" if voiced else last_line)
	active_subtitle = not voiced
	cooldown = 14
	subtitle_left = 12
	if result:
		game.call("OracStop")
	queue_line(last_line)
	return true

func command_error(message: String) -> void:
	if message.contains("SYNTAX"):
		remark("syntax")
	elif message.contains("FILE NOT FOUND"):
		remark("missing_file")
	elif message.contains("PROGRAM NOT LOADED"):
		remark("not_loaded")
	elif message.contains("EXECUTION LIMIT"):
		remark("execution_limit")
	else:
		remark("basic_error")
