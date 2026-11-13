extends SceneTree

var checks := 0
var failures := 0
var yard: Node3D
var deep: Object

class VoiceSettings extends Node:
	var opt_orac_voice := true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func floor_brightness(image: Image) -> float:
	var total := 0.0
	for y in range(72, 92, 2):
		for x in range(35, 65, 2):
			total += image.get_pixel(image.get_width() * x / 100, image.get_height() * y / 100).get_luminance()
	return total / 150.0

func _initialize() -> void:
	_run.call_deferred()

func go_floor(code: String) -> void:
	yard.set("place", "floor")
	yard.set("floor_code", code)
	yard.set("position_xz", Vector2(0, 2.4))
	deep.call("arrive", yard, false)
	deep.call("ensure_layout", yard)
	yard.set("pending_room", true)
	yard.call("_sync_room")

func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Club regression timed out")
		quit(1)
	)
	yard = Node3D.new()
	yard.set_script(load("res://backlight_exploration.vg"))
	yard.call("EnsureInit")
	yard.call("reset")
	yard.call("_materials")
	root.add_child(yard)
	var listener := AudioListener3D.new()
	root.add_child(listener)
	listener.make_current()
	var audio_camera := Camera3D.new()
	root.add_child(audio_camera)
	audio_camera.current = true
	listener.position = Vector3(0, 1.7, 10)
	audio_camera.position = listener.position
	deep = yard.get("deep")
	go_floor("88216")
	var state: Dictionary = yard.get("stratum")
	state["powered"] = true
	deep.set("grid_power", true)
	var refuges := [26.0, 42.0, 58.0, 74.0, 90.0, 98.0, 114.0, 130.0]
	for z: float in refuges:
		for x: float in [99.0, 100.0, 101.0, 102.0, 103.0]:
			check(not deep.call("blocked", yard, Vector2(x, z), 0.3), "refuge reachable %s/%s" % [x, z])
		check(deep.call("blocked", yard, Vector2(104.5, z), 0.3), "refuge has back wall %s" % z)
		var clear := true
		yard.set("shield", 100)
		yard.set("position_xz", Vector2(102, z))
		for seconds in range(0, 100, 2):
			deep.set("clock", float(seconds))
			for train: Dictionary in deep.get("trains"):
				var hit: Array = deep.call("_train_hit", train, Vector2(102, z))
				clear = clear and float(hit[0]) > 1.9
			deep.call("_city_physics", yard, 0.05)
		check(clear, "train clearance through full timetable %s" % z)
		check(yard.get("shield") == 100, "no train damage inside refuge %s" % z)
	var first_train: Dictionary = deep.get("trains")[0]
	var train_pos: Array = deep.call("_poly_at", first_train["pts"], deep.call("train_s", first_train))
	yard.set("position_xz", train_pos[0])
	yard.set("damage_cooldown", 0.0)
	deep.call("_city_physics", yard, 0.05)
	check(yard.get("shield") < 100, "live trains still damage player on track")
	var anchor: Array = deep.get("anchors")["club_door"]
	check(anchor[0].x > 101.0, "return anchor off track")
	state["powered"] = false
	go_floor("77124")
	var fx: Object = deep.call("club_module")
	var interior: Node3D = yard.get("interior")
	var rig: Node = interior.get_node("ClubRig")
	check(fx.get("beam_pivots").size() == 8, "eight moving beams")
	check(fx.get("moving_lights").size() == 4, "four real spotlights")
	if fx.get("floor_mat") == null:
		yard.free()
		quit(1)
		return
	check(fx.get("floor_mat").get_shader_parameter("power") == 0.0, "floor dark before playback")
	check(not fx.get("playing"), "club stays off without city power")
	state["powered"] = true
	fx.call("set_strobe", "Off")
	fx.call("tick", yard, 0.1)
	check(not fx.get("playing"), "city power alone does not bypass DJ switch")
	for selected in range(4):
		fx.call("cycle_track", yard)
		check(not fx.get("playing"), "selecting music cannot bypass DJ start switch")
	yard.set("position_xz", Vector2(0, 12.2))
	check(deep.call("prompt", yard).contains("START LIGHTS AND MUSIC"), "booth has explicit activation prompt")
	check(deep.call("use", yard), "F at booth handled")
	check(fx.get("playing"), "DJ switch starts lights and music")
	check(deep.call("ground_sound", yard) == "tile", "club ground is tile")
	var audio := Node.new()
	audio.set_script(load("res://game_audio.vg"))
	check(audio.call("surface_for", yard) == "tile", "club uses non-metal footsteps")
	check(audio.call("music_for", yard) == "", "club does not play unrelated background score")
	audio.free()
	var pad := false
	for portal: Dictionary in deep.get("portals"):
		if portal["dest"] == "77125":
			pad = true
	check(pad, "telepad links to launch dock")
	var orb: Node3D = fx.get("orb_node")
	var initial := orb.rotation
	if fx.call("track_loaded"):
		await create_timer(1.4).timeout
	fx.call("tick", yard, 1.0)
	check(orb.rotation.distance_to(initial) > 0.1, "orb physically rotates")
	check(fx.call("strobe") == 0.0, "Off suppresses strobe")
	var probe := RefCounted.new()
	probe.set_script(load("res://club_fx.vg"))
	probe.call("EnsureInit")
	probe.set("playing", true)
	for mode: String in ["Off", "Low", "Full"]:
		probe.call("set_strobe", mode)
		probe.set("last_flash", -10.0)
		probe.set("last_onset", -1.0)
		probe.set("last_bass", 0.0)
		var flashes := 0
		var previous_flash := false
		var last_flash_time := -10.0
		for frame in range(3600):
			var seconds := frame / 60.0
			probe.set("t", seconds)
			probe.call("_note_onset", 0.8 if frame % 23 == 0 else 0.01)
			probe.call("_audio_strobe")
			var value: float = probe.call("strobe")
			var flashing := value > 0.0
			if flashing and not previous_flash:
				check(seconds - last_flash_time >= (1.79 if mode == "Full" else 2.99), mode + " limits flash rate")
				last_flash_time = seconds
				flashes += 1
				check(is_equal_approx(value, 1.0 if mode == "Full" else 0.35), mode + " flash intensity")
			previous_flash = flashing
		check(flashes == 0 if mode == "Off" else flashes > 10, mode + " audio-onset strobe works across full minute")
	fx.call("set_strobe", "Full")
	var live_flash := false
	for frame in range(480):
		await create_timer(1.0 / 60.0).timeout
		fx.call("tick", yard, 1.0 / 60.0)
		if fx.call("strobe") > 0.0:
			live_flash = true
			check(fx.get("floor_mat").get_shader_parameter("strobe") > 0.0, "real-audio flash reaches floor shader")
			check(fx.get("moving_lights")[0].light_energy > 5.0, "real-audio flash brightens moving lights")
			break
	check(live_flash, "installed track produces a visible strobe pulse")
	fx.call("set_strobe", "Off")
	yard.set("position_xz", Vector2(-3.2, 12.4))
	check(deep.call("prompt", yard).contains("THE MEMBRANE REMEMBERS"), "selector displays current track name")
	for selected in range(1, 5):
		var expected := selected % 4
		check(deep.call("use", yard), "F cycles DJ recording")
		check(fx.get("track_index") == expected and state.get("club_track") == expected, "track choice stored")
		check(fx.get("player").stream.resource_path == fx.get("track_paths")[expected], "selected recording loaded into booth")
		check(fx.get("player").stream.loop and fx.get("player").playing, "selected recording loops and plays")
		check(deep.call("prompt", yard).contains(fx.call("track_name")), "selector prompt updates to chosen title")
	fx.call("cycle_track", yard)
	go_floor("88216")
	fx.call("hint", yard, true, 0.1)
	check(fx.get("door_player").stream.resource_path.ends_with("club_lullaby.ogg"), "tunnel leak uses selected recording")
	go_floor("77124")
	check(fx.get("track_index") == 1, "selected track survives leaving and returning")
	check(fx.get("player").stream.resource_path.ends_with("club_lullaby.ogg"), "re-entry restores selected music")
	for selected in range(3):
		fx.call("cycle_track", yard)
	rig = yard.get("interior").get_node("ClubRig")
	orb = fx.get("orb_node")
	check(fx.get("floor_mat").get_shader_parameter("power") == 1.0, "floor powers on")
	fx.call("tick", yard, 0.1)
	check(fx.get("wall_mat").get_shader_parameter("time") >= 0.0, "video wall animation clock resets on track change")
	check(fx.get("reflection_mat").get_shader_parameter("power") == 1.0, "reflected spots powered")
	state["powered"] = false
	fx.call("tick", yard, 0.1)
	check(not fx.get("playing"), "power loss stops club")
	check(fx.get("floor_mat").get_shader_parameter("power") == 0.0, "power loss darkens floor")
	fx.call("cycle_track", yard)
	check(fx.get("track_index") == 0, "track selector cannot change music without power")
	state["powered"] = true
	fx.call("tick", yard, 0.1)
	check(rig.get_child_count() < 50, "bounded effects rig")
	var old_rig_id := rig.get_instance_id()
	go_floor("88216")
	fx.call("hint", yard, true, 0.1)
	go_floor("77124")
	interior = yard.get("interior")
	check(interior.get_node("ClubRig").get_instance_id() != old_rig_id, "rig rebuilt after return")
	fx.call("tick", yard, 0.1)
	check(fx.get("playing"), "playback restored after return")
	for z in range(12, 23):
		check(not deep.call("blocked", yard, Vector2(6.2, z), 0.3), "side passage and pad approach clear %s" % z)
	check(deep.call("blocked", yard, Vector2(0, 16), 0.3), "meeting room has solid partition")
	check(not deep.call("blocked", yard, Vector2(-3.2, 20.8), 0.3), "hologram approach clear")
	var alien: Node3D = interior.get_node("ClubAlien")
	check(alien.has_node("HumanHologram") and alien.has_node("HumanHologramWire"), "existing human design rendered as two batched meshes")
	check(alien.get("face_materials").size() == 2, "hologram has bounded render surfaces")
	yard.set("position_xz", Vector2(6.2, 21))
	check(deep.call("prompt", yard).contains("ASK ALIEN"), "offline pad directs player to Alien")
	check(fx.get("pad_mat").get_shader_parameter("link_power") == 0.0, "unactivated pad is visibly dormant")
	check(deep.call("use", yard) and yard.get("floor_code") == "77124", "pad blocks outbound travel before Alien activates it")
	var hair_mesh: Mesh = alien.get_node("HumanHologramWire").mesh
	var hair_vertices: PackedVector3Array = hair_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var side_wisps := 0
	var crown_wisps := 0
	for vertex in hair_vertices:
		if absf(vertex.x) > 0.85 and vertex.y > 0.0:
			side_wisps += 1
		if vertex.y > 1.3:
			crown_wisps += 1
	check(side_wisps > 1800 and crown_wisps > 1200, "full disheveled hair covers temples and crown")
	check(hair_mesh.get_surface_count() == 1, "hair shares existing tracked wire surface")
	var lines: Dictionary = alien.get("dialogue")
	check(lines["intro"][2]["speech"] == "He's speaking Narcean. I'll send him an English language sample. Jason. Human. English.",
		"Orac recognizes Narcean without claiming an ancient dialect")
	var provenance: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/club/alien/voices.json"))
	check(provenance.size() == 21, "every encounter voice has neural bake provenance")
	var voice_profiles := {"JASON": 5, "ORAC": 9, "ALIEN": 10}
	for recording: Dictionary in provenance:
		check(recording["backend"] == "kokoro" and recording["sid"] == voice_profiles[recording["speaker"]],
			"neural speaker profile matches game cast: " + recording["audio"])
		check(is_equal_approx(recording["speed"], 0.94 if recording["speaker"] == "ALIEN" else (0.92 if recording["speaker"] == "ORAC" else 1.08)),
			"speaker uses intended neural delivery: " + recording["audio"])
		var found := false
		for section: String in lines:
			for line: Dictionary in lines[section]:
				if line["speech"] == recording["text"] and line["speaker"] == recording["speaker"]:
					found = true
		check(found, "baked speech matches current dialogue text: " + recording["audio"])
	for section: String in lines:
		for i in lines[section].size():
			var voice: AudioStream = load("res://assets/audio/club/alien/%s_%s.ogg" % [section, i])
			check(voice != null and voice.get_length() > 1.0, "bundled voice %s/%s" % [section, i])
			check(not str(lines[section][i]["caption"]).contains("Rob"), "encounter keeps future identity private %s/%s" % [section, i])
	for target in [Vector2(4, 20.8), Vector2(-9, 20.8)]:
		yard.set("position_xz", target)
		alien.call("tick", 0.0)
		var initial_yaw: float = alien.get("head_yaw")
		alien.call("tick", 0.05)
		check(absf(float(alien.get("head_yaw")) - initial_yaw) < 0.65, "head turns smoothly rather than snapping")
		for frame in range(120):
			alien.call("tick", 1.0 / 60.0)
		var forward: Vector3 = -alien.get("faces")[0].basis.z
		var target_direction := Vector3(target.x + 3.2, -1.0, target.y - 22.8).normalized()
		check(forward.dot(target_direction) > 0.99, "human face aims at player on either side")
		check(absf(float(alien.get("head_yaw"))) > 0.5, "tracking exceeds old 29 degree limit")
		check(alien.get("faces")[0].rotation.is_equal_approx(alien.get("faces")[1].rotation), "wire and shaded face track together")
	yard.set("position_xz", Vector2(6.2, 14))
	for frame in range(120):
		alien.call("tick", 1.0 / 60.0)
	check(absf(float(alien.get("head_yaw"))) < 0.01 and absf(float(alien.get("head_pitch"))) < 0.01, "head settles to neutral after player leaves")
	yard.set("position_xz", Vector2(-3.2, 20.8))
	state["powered"] = false
	deep.set("grid_power", false)
	deep.call("physics", yard, 0.016)
	check(alien.get("index") == 0, "emergency-powered resident greets in Narcean")
	check(yard.get("message").contains("untranslated Narcean"), "first greeting is untranslated")
	check(alien.get("player").playing, "Narcean greeting has audio")
	check(deep.call("prompt", yard).contains("CONVERSATION"), "resident interaction discoverable")
	yard.set("campaign_mode", true)
	check(not deep.call("interface_lexicon_ready", yard), "campaign cannot translate before Alien")
	check(not fx.call("track_prompt", yard).contains(fx.call("track_name")), "song title hidden before language transfer")
	state["powered"] = true
	fx.call("cycle_track", yard)
	check(yard.get("message").contains("UNTRANSLATED") and not yard.get("message").contains(fx.call("track_name")),
		"cycling songs does not leak their titles before transfer")
	state["powered"] = false
	for turn in range(1, 15):
		check(deep.call("use", yard), "conversation turn %s" % turn)
		check(alien.get("index") == turn, "conversation advances once %s" % turn)
		check(state.get("club_pad_activated", false) == (turn >= 13), "pad activates only when Alien restores link")
		check(deep.call("interface_lexicon_ready", yard) == (turn >= 10), "Narcean knowledge acquired separately after English")
	check(state.get("alien_english", false), "English learned from Jason and Orac")
	check(fx.call("track_prompt", yard).begins_with("ORAC TRANSLATION:"), "translated song title attributed to Orac")
	check(fx.call("track_prompt", yard).contains(fx.call("track_name")), "song title visible after transfer")
	state.erase("narcean_lexicon")
	alien.set("index", -1)
	alien.call("advance")
	check(alien.get("index") == 5 and not state.get("narcean_lexicon", false),
		"older English-only encounter resumes trust conversation without inventing Narcean")
	for turn in range(6, 11):
		alien.call("advance")
	check(state.get("narcean_lexicon", false), "English-only saves can receive missing lexicon from Alien")
	yard.set("campaign_mode", false)
	check(alien.get("section") == "intro", "first exchange completes without skipping")
	var voice_settings := VoiceSettings.new()
	root.add_child(voice_settings)
	yard.reparent(voice_settings)
	voice_settings.opt_orac_voice = false
	deep.call("use", yard)
	check(not alien.get("player").playing and not yard.get("message").is_empty(), "speech-off retains subtitles")
	voice_settings.opt_orac_voice = true
	deep.call("use", yard)
	check(alien.get("player").playing, "speech option can re-enable encounter voice")
	yard.reparent(root)
	voice_settings.free()
	yard.set("position_xz", Vector2(6.2, 14))
	alien.call("tick", 0.1)
	check(not alien.get("player").playing, "leaving meeting room stops conversation audio")
	yard.set("position_xz", Vector2(6.2, 21))
	state["powered"] = true
	deep.set("grid_power", true)
	fx.call("tick", yard, 0.1)
	check(fx.get("pad_mat").get_shader_parameter("link_power") == 1.0, "Alien activation lights powered pad")
	check(fx.get("player").bus == "ClubDoor", "backroom music is muffled")
	check(deep.call("prompt", yard).contains("SURFACE LAUNCH DOCK"), "outbound pad prompt")
	deep.set("portal_armed", true)
	deep.call("physics", yard, 0.016)
	check(yard.get("floor_code") == "77124", "pad waits for F rather than auto-teleporting")
	check(deep.call("use", yard), "outbound telepad interaction")
	check(yard.get("floor_code") == "77125", "arrives on surface dock")
	check(state.get("club_dock_visited", false), "dock visit recorded for resident conversation")
	yard.call("_sync_room")
	check(not deep.call("blocked", yard, yard.get("position_xz"), 0.3), "dock arrival clear")
	check(deep.get("consoles").size() == 4, "four dock evidence records")
	var evidence := ""
	for console: Dictionary in deep.get("consoles"):
		evidence += console["text"]
		var approach: Vector2 = console["p"] + Vector2(0, -1.5)
		check(not deep.call("blocked", yard, approach, 0.3), "evidence console approachable")
		yard.set("position_xz", approach)
		check(deep.call("use", yard), "evidence console readable")
		check(yard.get("message") == console["text"], "evidence console presents its record")
	check(evidence.contains("MJH") and evidence.contains("He's gone"), "records support Jason's apparent-loss conclusion")
	check(not evidence.contains("Rob") and not evidence.contains("escaped"), "dock does not reveal later twist")
	var dock: Node3D = yard.get("interior")
	check(dock.has_node("LaunchBlastScorch"), "blast damage overlay")
	check(dock.has_node("LaunchOpenSky"), "surface has open sky")
	check(not dock.has_node("LiftCar"), "surface dock does not spawn a lift")
	for z in range(10, 70):
		check(not deep.call("blocked", yard, Vector2(0, z), 0.3), "central dock path clear %s" % z)
	yard.set("position_xz", Vector2(0, 6))
	check(deep.call("prompt", yard).contains("RETURN TO UNDERGROUND CLUB"), "return pad prompt")
	check(deep.call("use", yard), "return pad interaction")
	check(yard.get("floor_code") == "77124", "telepad returns to club")
	yard.call("_sync_room")
	check(not deep.call("blocked", yard, yard.get("position_xz"), 0.3), "club return clear")
	alien = yard.get("interior").get_node("ClubAlien")
	yard.set("position_xz", Vector2(-3.2, 20.8))
	alien.call("tick", 0.1)
	check(alien.get("index") == -1, "English acquisition persists without replaying greeting")
	deep.call("use", yard)
	check(alien.get("section") == "returned", "resident responds to dock visit")
	check(not yard.get("message").contains("untranslated"), "return conversation remains English")
	for turn in range(3):
		deep.call("use", yard)
	check(state.get("alien_dock_discussed", false), "dock reaction recorded without repetitive grief loop")
	deep.call("use", yard)
	check(alien.get("section") == "repeat", "subsequent talk returns to optional room dialogue")
	yard.set("position_xz", Vector2(6.2, 21))
	state["powered"] = false
	deep.call("use", yard)
	check(yard.get("floor_code") == "77124", "telepad cannot travel without city power")
	state["powered"] = true
	fx.call("tick", yard, 0.016)
	if fx.call("track_loaded"):
		check(fx.get("player").stream.get_length() >= 80.0, "full alien track loaded")
		check(fx.get("player").stream.loop, "alien track loops")
	check(state.get("club_pad_activated", false), "pad activation persists after return")
	check(deep.call("use", yard) and yard.get("floor_code") == "77125", "activated pad needs no repeat conversation")
	yard.call("_sync_room")
	yard.set("position_xz", Vector2(0, 6))
	deep.call("use", yard)
	yard.call("_sync_room")
	state["alien_english"] = true
	alien = yard.get("interior").get_node("ClubAlien")
	yard.set("position_xz", Vector2(6.2, 21))
	deep.call("use", yard)
	yard.call("_sync_room")
	state.erase("club_pad_activated")
	yard.set("position_xz", Vector2(0, 6))
	check(deep.call("use", yard) and yard.get("floor_code") == "77124", "dock return never requires Alien activation flag")
	yard.call("_sync_room")
	alien = yard.get("interior").get_node("ClubAlien")
	yard.set("position_xz", Vector2(-3.2, 20.8))
	deep.call("use", yard)
	deep.call("use", yard)
	check(state.get("club_pad_activated", false), "older English-learned states can ask Alien to restore pad")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		yard.set_process(false)
		yard.set_physics_process(false)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 2.3, 1.4)
		camera.look_at(Vector3(0, 2.7, 11))
		camera.current = true
		root.size = Vector2i(1280, 720)
		fx.call("seek", 97.0)
		if fx.call("track_loaded"):
			fx.get("player").seek(97.0)
			await create_timer(0.1).timeout
		fx.call("set_strobe", "Low")
		fx.call("tick", yard, 0.016)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var image_a := root.get_texture().get_image()
		check(image_a.save_png("user://club-revision-a.png") == OK, "save first club frame")
		fx.call("tick", yard, 1.25)
		if fx.call("track_loaded"):
			fx.get("player").seek(98.25)
			await create_timer(0.1).timeout
			fx.call("tick", yard, 0.016)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var image_b := root.get_texture().get_image()
		check(image_b.save_png("user://club-revision-b.png") == OK, "save second club frame")
		check(image_a.get_data() != image_b.get_data(), "rendered animation changes pixels")
		fx.call("set_strobe", "Off")
		fx.call("_push")
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var unlit_flash := floor_brightness(root.get_texture().get_image())
		fx.call("set_strobe", "Full")
		fx.set("last_onset", fx.get("t"))
		fx.set("last_flash", -10.0)
		fx.call("_audio_strobe")
		fx.call("_push")
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var flash_image := root.get_texture().get_image()
		check(floor_brightness(flash_image) > unlit_flash + 0.03, "strobe visibly brightens rendered dance-floor pixels")
		check(flash_image.save_png("user://club-strobe-flash.png") == OK, "save visible strobe preview")
		fx.call("set_strobe", "Off")
		fx.call("_push")
		print("CAPTURES: ", ProjectSettings.globalize_path("user://club-revision-a.png"))
		yard.set("position_xz", Vector2(-3.2, 20.8))
		camera.position = Vector3(2.5, 2.4, 17.3)
		camera.look_at(Vector3(-2, 2.2, 22.8))
		for frame in range(8):
			alien.call("tick", 0.016)
			await process_frame
		await RenderingServer.frame_post_draw
		for part in yard.get("room_mesh").get_children():
			if part is MeshInstance3D:
				for surface in part.mesh.get_surface_count():
					check(part.mesh.surface_get_material(surface) != null, "meeting room surfaces have game materials")
		check(root.get_texture().get_image().save_png("user://club-alien-backroom.png") == OK, "save resident and meeting room preview")
		go_floor("77125")
		camera.position = Vector3(22, 10, 7)
		camera.look_at(Vector3(0, 1, 41))
		camera.far = 260
		camera.current = true
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("user://club-launch-dock.png") == OK, "save ruined dock preview")
		go_floor("88216")
		yard.set("position_xz", Vector2(102, 74))
		camera.position = Vector3(102, 1.7, 74)
		camera.look_at(Vector3(97, 1.7, 84))
		camera.current = true
		var torch := OmniLight3D.new()
		torch.position = camera.position
		torch.omni_range = 20.0
		torch.light_energy = 2.0
		root.add_child(torch)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("user://club-tunnel-refuge.png") == OK, "save carved tunnel refuge")
	yard.free()
	print("CLUB_VISUAL=", checks - failures, "/", checks)
	quit(1 if failures else 0)
