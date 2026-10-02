extends Node
## Runtime TTS for Vector Crypt — Overseer / loudspeaker lines.
##
## Autoloaded as VoiceOver in project.godot. Main.vg / intro code call:
##   VoiceOver.speak_overseer_wakeup(hero_name)
##   VoiceOver.speak("...")
## Prefers local Piper (natural voices); falls back to OS speech if missing.

signal speech_started
signal speech_finished

const PIPER_BIN := "piper"
const SPEED_SCALE := 0.94  # slightly slow, clinical

var is_speaking: bool = false

var _player: AudioStreamPlayer
var _piper_voice: String = ""
var _pid: int = -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	_piper_voice = _find_piper_voice()


func speak(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	stop()
	if not _speak_piper(text):
		_speak_system(text)


func speak_overseer_wakeup(hero_name: String) -> void:
	# Portal-style cadence: calm PA, pauses between phrases (ellipses for Piper/espeak).
	var who := hero_name.strip_edges()
	var line: String
	if who.is_empty():
		line = "Good morning. ... I'm glad you are finally awake. ... I need your help."
	else:
		line = "Good morning. ... %s? ... I'm glad you are finally awake. ... I need your help." % who
	speak(line)


func stop() -> void:
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
	if is_instance_valid(_player):
		_player.stop()
	if is_speaking:
		is_speaking = false
		speech_finished.emit()


func _on_player_finished() -> void:
	if is_speaking:
		is_speaking = false
		speech_finished.emit()


func _find_piper_voice() -> String:
	var home := OS.get_environment("HOME")
	var names: Array[String] = [
		"en_US-amy-medium.onnx",
		"en_US-amy-low.onnx",
		"en_US-lessac-medium.onnx",
		"en_GB-alba-medium.onnx",
	]
	var dirs: Array[String] = [
		home + "/.local/share/piper/voices",
		home + "/.local/share/piper",
		"/usr/share/piper/voices",
	]
	for d in dirs:
		for n in names:
			var p := d.path_join(n)
			if FileAccess.file_exists(p):
				return p
	return ""


func _speak_piper(text: String) -> bool:
	if _piper_voice.is_empty() or not _binary_exists(PIPER_BIN):
		return false
	var temp := OS.get_user_data_dir().path_join("vector_crypt_tts")
	DirAccess.make_dir_recursive_absolute(temp)
	var txt_path := temp.path_join("line.txt")
	var wav_path := temp.path_join("line.wav")
	var f := FileAccess.open(txt_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	var ls := clampf(1.0 / SPEED_SCALE, 0.5, 1.2)
	var cmd: String
	var args: PackedStringArray
	if OS.has_feature("windows"):
		cmd = "cmd"
		args = PackedStringArray(["/c", "type \"%s\" | \"%s\" --model \"%s\" --length-scale %.3f --output_file \"%s\"" % [
			txt_path, PIPER_BIN, _piper_voice, ls, wav_path]])
	else:
		cmd = "sh"
		args = PackedStringArray(["-c", "cat '%s' | '%s' --model '%s' --length-scale %.3f --output_file '%s'" % [
			txt_path, PIPER_BIN, _piper_voice, ls, wav_path]])
	var out: Array = []
	is_speaking = true
	speech_started.emit()
	var exit := OS.execute(cmd, args, out, true, false)
	if exit != 0 or not FileAccess.file_exists(wav_path):
		is_speaking = false
		speech_finished.emit()
		return false
	var bytes := FileAccess.get_file_as_bytes(wav_path)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	if bytes.size() > 44:
		stream.data = bytes.slice(44)
	_player.stream = stream
	_player.play()
	return true


func _speak_system(text: String) -> void:
	var wpm := int(clamp(168.0 * SPEED_SCALE, 90.0, 220.0))
	var cmd := ""
	var args: PackedStringArray = []
	if OS.has_feature("linux"):
		cmd = "espeak"
		args = PackedStringArray(["-v", "en+f3", "-s", str(wpm), text])
	elif OS.has_feature("macos"):
		cmd = "say"
		args = PackedStringArray(["-v", "Samantha", "-r", str(wpm), text])
	elif OS.has_feature("windows"):
		var ps_text := text.replace("'", "''")
		cmd = "powershell"
		args = PackedStringArray(["-NoProfile", "-Command",
			"Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::Female); $s.Rate = -1; $s.Speak('%s');" % ps_text])
	if cmd.is_empty() or not _binary_exists(cmd):
		is_speaking = false
		speech_finished.emit()
		return
	is_speaking = true
	speech_started.emit()
	_pid = OS.create_process(cmd, args)
	var delay := mini(20000, 900 + text.length() * 75)
	get_tree().create_timer(delay / 1000.0).timeout.connect(_on_system_done)


func _on_system_done() -> void:
	_pid = -1
	if is_speaking:
		is_speaking = false
		speech_finished.emit()


func _binary_exists(path: String) -> bool:
	if path.is_absolute_path() and FileAccess.file_exists(path):
		return true
	var which_cmd := "where" if OS.has_feature("windows") else "which"
	var out: Array = []
	return OS.execute(which_cmd, PackedStringArray([path]), out, false, false) == 0
