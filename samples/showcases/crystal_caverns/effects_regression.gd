extends SceneTree

var checks := 0
var failures := 0
var graphical := false
var capture_dir := OS.get_environment("CRYSTAL_FX_CAPTURE")

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func snapshot(game: Node) -> Dictionary:
	var state := {}
	for field in ["board", "falling", "playerX", "playerY", "crystals", "health",
			"secondsLeft", "ticks", "gameState", "exitOpen", "paused", "levelIndex",
			"gemChanges", "exitSignals", "defeatSignals", "warningSignals", "visualEpoch"]:
		var value: Variant = game.get(field)
		state[field] = value.duplicate() if value is Array else value
	return state

func advance(fx: Node, seconds: float) -> void:
	while seconds > 0.0:
		var step := minf(0.1, seconds)
		fx.update_visuals(step)
		seconds -= step

func frame(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not capture_dir.is_empty():
		check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "save " + name)
	return image

func difference(a: Image, b: Image, area: Rect2i) -> float:
	var total := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := a.get_pixel(x, y)
			var d := b.get_pixel(x, y)
			total += absf(c.r - d.r) + absf(c.g - d.g) + absf(c.b - d.b)
	return total / (area.size.x * area.size.y * 3)

func color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)

func _run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null, "Scene must load")
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	var fx: Node = game.get_node("VisualEffects")
	fx.set_process(false)
	await process_frame
	check(game.get_script().resource_path.ends_with(".vg") and fx.get_script().resource_path.ends_with(".vg"),
		"gameplay and effects controllers are both VG scripts")
	check(fx.ready_to_draw, "deferred renderer ready after DATA textures load")
	check(game.get("effectsRenderer") == fx, "VG routes drawing to effects child")
	check(fx.tiles.size() == 240 and fx.fragments.size() == 64, "bounded tile and pixel pools")
	check(fx.world.clip_contents and fx.world.size == Vector2(640, 384), "effects clipped to cave, not HUD")
	check(fx.phase == "entrance" and fx.phase_time == 0.0, "entrance starts at zero")
	check(fx.miner.material.get_shader_parameter("reveal") == 0.0, "miner starts fully swirled away")
	var initial := snapshot(game)
	advance(fx, 0.4)
	check(is_equal_approx(fx.miner.material.get_shader_parameter("reveal"), 0.5), "entrance half revealed after 0.4s")
	var entrance: Image
	if graphical:
		entrance = await frame("entrance")
	advance(fx, 0.5)
	check(fx.phase == "playing" and fx.miner.material.get_shader_parameter("reveal") == 1.0, "entrance completes at 0.8s")
	check(snapshot(game) == initial, "entrance never mutates simulation or Whenever counters")
	check(not fx.portal.visible, "locked exit has no vortex")
	for index in 240:
		var kind := int(game.get("board")[index])
		check(fx.tiles[index].texture == game.get("art")[kind], "tile %d uses cached DATA texture" % index)
	game.set("paused", true)
	fx.update_visuals(0.0)
	var frozen: Array = [fx.clock, fx.phase_time, fx.pickup_time, fx.move_time]
	advance(fx, 1.0)
	check(frozen == [fx.clock, fx.phase_time, fx.pickup_time, fx.move_time], "pause freezes every visual timer")
	game.set("paused", false)
	game.set("playerX", int(game.get("playerX")) + 1)
	fx.update_visuals(0.0)
	check(fx.move_time == 0.16 and fx.miner.material.get_shader_parameter("moving") == 1.0, "walking lights the miner")
	advance(fx, 0.2)
	check(fx.move_time == 0.0, "walking pulse ends")
	game.set("crystals", 1)
	fx.update_visuals(0.0)
	check(fx.pickup.visible and fx.pickup_time == 0.0, "pickup starts glow ring")
	check(fx.post.material.get_shader_parameter("glitch") == 0.25, "glitch is a small pickup event, not permanent")
	var pickup_start: Image
	if graphical:
		pickup_start = await frame("pickup")
	advance(fx, 0.6)
	check(not fx.pickup.visible and fx.post.material.get_shader_parameter("glitch") == 0.0, "pickup and glitch expire")
	game.set("exitOpen", true)
	fx.update_visuals(0.0)
	check(fx.portal.visible, "unlock reveals exit vortex")
	var portal_start: Image
	if graphical:
		portal_start = await frame("portal")
	advance(fx, 0.4)
	var portal_later: Image
	if graphical:
		portal_later = await frame("portal-later")
		check(difference(portal_start, portal_later, Rect2i(592, 400, 64, 80)) > 0.001, "GPU vortex visibly rotates")
	game.set("gameState", "won")
	fx.update_visuals(0.0)
	advance(fx, 0.55)
	check(fx.phase == "victory" and fx.post.material.get_shader_parameter("wave") > 0.99, "completion first reaches full wave")
	check(fx.post.material.get_shader_parameter("sink") == 0.0, "no sink during wave")
	if graphical:
		await frame("victory-wave")
	advance(fx, 1.0)
	check(fx.post.material.get_shader_parameter("wave") < 0.00001, "wave ends before sink")
	check(is_equal_approx(fx.post.material.get_shader_parameter("sink"), 0.5), "swirl sink halfway at 1.55s")
	if graphical:
		await frame("victory-sink")
	advance(fx, 0.6)
	check(fx.post.material.get_shader_parameter("sink") == 1.0, "sink ends at 2s")
	if graphical:
		var sunk := await frame("victory-finished")
		check(color_distance(sunk.get_pixel(350, 250), Color(0.025, 0.035, 0.065, 1)) < 0.015, "GPU sink finishes on dark cave")
	game.call("RestartCave")
	fx.update_visuals(0.0)
	check(fx.phase == "entrance" and not fx.portal.visible and fx.phase_time == 0.0, "same-cave restart resets entrance and unlock effects")
	advance(fx, 1.0)
	game.call("FinishDefeat", "Effect regression")
	fx.update_visuals(0.0)
	check(fx.phase == "death" and not fx.miner.visible, "defeat hides miner and starts explosion")
	var miner_pixels: Image = fx.burst_texture.get_image()
	var visible_fragments := 0
	var matching_colors := true
	var matching_velocities := true
	for index in 64:
		var fragment: Sprite2D = fx.fragments[index]
		matching_colors = matching_colors and fragment.modulate == miner_pixels.get_pixel(index % 8, index / 8)
		var offset := Vector2(index % 8, index / 8) * 4.0 - Vector2(14, 14)
		var expected := (offset.normalized() * (38.0 + fmod(index * 17.0, 38.0)) + Vector2(0, -24)) * 0.25
		var velocity: Variant = fragment.material.get_shader_parameter("velocity")
		matching_velocities = matching_velocities and velocity is Vector2 and velocity.is_equal_approx(expected)
		if fragment.visible:
			visible_fragments += 1
	check(matching_colors, "explosion copies exact DATA palette and transparency")
	check(matching_velocities, "all 64 fragment uniforms contain correct radial Vector2 velocities")
	check(visible_fragments > 0 and visible_fragments < 64, "transparent DATA pixels emit no fragments")
	var death_start: Image
	if graphical:
		death_start = await frame("death-start")
	advance(fx, 0.4)
	if graphical:
		var death_later := await frame("death-burst")
		var burst_center: Vector2 = fx.burst_origin + fx.world.position
		check(difference(death_start, death_later, Rect2i(Vector2i(burst_center) - Vector2i(48, 48), Vector2i(96, 96))) > 0.0005,
			"GPU DATA pixels visibly disperse near miner, not distant crystal shimmer")
	advance(fx, 0.8)
	check(not fx.fragments.any(func(fragment: Sprite2D): return fragment.visible), "explosion expires after 1.15s")
	game.call("RestartCave")
	fx.update_visuals(0.0)
	advance(fx, 1.0)
	fx.set_effects_enabled(false)
	check(not fx.post.visible and not fx.portal.visible and not fx.pickup.visible, "plain mode hides overlays")
	check(fx.miner.material.get_shader_parameter("reveal") == 1.0 and fx.miner.material.get_shader_parameter("moving") == 0.0, "plain mode keeps miner visible without animation")
	check(fx.tiles.all(func(tile: Sprite2D): return tile.material == null), "plain tiles have no shader motion")
	var plain: Image
	if graphical:
		plain = await frame("plain")
		var rock_index: int = game.get("board").find(3)
		var rock_image: Image = game.get("art")[3].get_image()
		var rock_matches := true
		for y in 8:
			for x in 8:
				var pixel := rock_image.get_pixel(x, y)
				if pixel.a > 0:
					var screen := Vector2i(32 + rock_index % 20 * 32 + x * 4 + 2, 96 + rock_index / 20 * 32 + y * 4 + 2)
					rock_matches = rock_matches and color_distance(plain.get_pixelv(screen), pixel) < 0.015
		check(rock_matches, "plain GPU rock matches every opaque DATA pixel")
	fx.toggle.button_pressed = true
	check(fx.effects_enabled, "Effects checkbox reenables shaders")
	var before_toggle := snapshot(game)
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	fx._unhandled_key_input(key)
	check(not fx.effects_enabled and not fx.toggle.button_pressed, "F8 disables effects and synchronizes checkbox")
	key.echo = true
	fx._unhandled_key_input(key)
	check(not fx.effects_enabled, "held F8 does not toggle repeatedly")
	check(snapshot(game) == before_toggle, "toggle leaves gameplay and watcher state untouched")
	key.echo = false
	root.push_input(key, true)
	check(fx.effects_enabled and fx.toggle.button_pressed, "actual unhandled F8 input reaches VG effects callback")
	fx.set_effects_enabled(true)
	if graphical:
		var treated := await frame("crt")
		check(difference(plain, treated, Rect2i(32, 96, 640, 384)) > 0.005, "GPU CRT and shimmer affect cave")
		check(difference(plain, treated, Rect2i(0, 0, 704, 70)) == 0.0, "shader leaves title and HUD unchanged")
		check(difference(plain, treated, Rect2i(0, 480, 704, 120)) == 0.0, "shader leaves messages and buttons unchanged")
		check(difference(entrance, treated, Rect2i(64, 128, 32, 32)) > 0.001, "GPU entrance visibly changes miner")
		check(difference(pickup_start, treated, Rect2i(64, 112, 64, 64)) > 0.001, "GPU pickup glow changes pixels")
		game.call("ToggleFullscreen")
		await process_frame
		var fullscreen := await frame("fullscreen")
		var wall_point: Vector2 = root.get_stretch_transform() * fx.world.get_global_transform_with_canvas() * Vector2(8, 8)
		check(fullscreen.get_pixelv(Vector2i(wall_point)).r > 0.2, "screen shader maps wall correctly in fullscreen")
		game.call("ToggleFullscreen")
		var deadline := Time.get_ticks_msec() + 2000
		while root.mode != Window.MODE_WINDOWED and Time.get_ticks_msec() < deadline:
			await process_frame
		check(root.mode == Window.MODE_WINDOWED, "effects fullscreen test restores window")
		root.size = Vector2i(1056, 900)
		await process_frame
		var resized := await frame("resized")
		check(resized.get_pixel(60, 156).r > 0.2, "screen shader maps wall correctly at 1.5x window size")
		root.size = Vector2i(704, 600)
		await process_frame
	check(await preload("res://regression_lifecycle.gd").release_scene(self, game),
		"effects scene destruction releases audio resources")
	print("EFFECTS RESULTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
