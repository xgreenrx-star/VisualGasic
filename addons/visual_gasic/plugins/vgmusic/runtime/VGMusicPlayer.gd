## VGMusicPlayer — runtime music player for songs created in Bosca Ceoil Blue.
##
## USAGE
## ─────
## 1. In Bosca Ceoil (the "Bosca Ceoil" panel in the VG IDE):
##      File menu → Export → SiON MML → save as  res://music/mysong.mml
##
## 2. In your game scene, add a VGMusicPlayer node (or attach this script
##    to a plain Node).
##
## 3. Set the `mml_file` export property to the .mml path, e.g.
##      "res://music/mysong.mml"
##
## 4. Call  $VGMusicPlayer.play()  to start playback.
##
## ⚠ REQUIREMENTS
## ──────────────
##   • GDSiON GDExtension binaries must be present in the exported game.
##     Copy  addons/visual_gasic/plugins/vgmusic/bin/  and
##           addons/visual_gasic/plugins/vgmusic/libgdsion.gdextension
##     into your game project before exporting.
##   • Playback runs on the CPU synthesiser — keep this in mind for mobile.
##   • Audio does NOT go through Godot's AudioServer bus chain.
##
## For static audio (recommended for most games) export your song as WAV or
## OGG from the toolbar and use a standard AudioStreamPlayer instead.

class_name VGMusicPlayer extends Node

## Path to the .mml file exported from Bosca Ceoil (e.g. "res://music/song.mml").
@export_file("*.mml") var mml_file: String = ""

## Loop the song indefinitely.
@export var loop: bool = true

## Start playing as soon as the node enters the scene tree.
@export var auto_play: bool = false

## SiON buffer size in samples.  Larger = less chance of audio glitches,
## higher latency.  2048 is a safe default for most targets.
@export_range(512, 8192, 512) var buffer_size: int = 2048

# Internal state.
var _driver: SiONDriver = null
var _mml_data: String = ""
var _playing: bool = false


func _ready() -> void:
	_driver = SiONDriver.create(buffer_size)
	add_child(_driver)

	if mml_file != "":
		_load_mml(mml_file)

	if auto_play and _mml_data != "":
		play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop()
		if is_instance_valid(_driver) and _driver.get_parent() == self:
			remove_child(_driver)
			_driver.free()
			_driver = null


# ─── Public API ──────────────────────────────────────────────────

## Load (or reload) a .mml file.  Call play() afterwards to start playback.
func load_song(path: String) -> bool:
	return _load_mml(path)


## Start (or restart) playback of the currently loaded song.
func play() -> void:
	if not is_instance_valid(_driver):
		push_error("VGMusicPlayer: driver not initialized.")
		return
	if _mml_data.is_empty():
		push_warning("VGMusicPlayer: no MML data loaded.  Set mml_file or call load_song() first.")
		return
	_driver.play(_mml_data, loop)
	_playing = true


## Stop playback and reset the playhead to the beginning.
func stop() -> void:
	if is_instance_valid(_driver):
		_driver.stop()
	_playing = false


## Pause playback (resume with play()).
func pause() -> void:
	if is_instance_valid(_driver) and _playing:
		_driver.pause()
		_playing = false


## Resume after pause().
func resume() -> void:
	if is_instance_valid(_driver) and not _playing:
		_driver.resume()
		_playing = true


## True while the song is actively playing.
func is_playing() -> bool:
	return _playing


## Change the tempo at runtime (BPM).
func set_bpm(bpm: float) -> void:
	if is_instance_valid(_driver):
		_driver.set_bpm(bpm)


# ─── Internals ───────────────────────────────────────────────────

func _load_mml(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("VGMusicPlayer: MML file not found: %s" % path)
		return false
	_mml_data = FileAccess.get_file_as_string(path)
	if _mml_data.is_empty():
		push_error("VGMusicPlayer: MML file is empty: %s" % path)
		return false
	mml_file = path
	return true
