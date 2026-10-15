extends "res://backlight_city.gd"

const Overlay = preload("res://backlight_exploration_hud.gd")
const Interiors = preload("res://backlight_interiors.gd")
const FEB_CODE := "14242"
const CITY_BOUNDS := Rect2(-118, -12, 236, 432)
const SHIP := Vector2(0, -5)
const CLUES := [
	"Dispatch archive: the first descent symbol is preserved here.",
	"Pressure office: the second symbol marks sealed pressure.",
	"Transit records: the third symbol marks a transfer.",
	"Service archive: the fourth symbol repeats sealed pressure.",
	"Quarantine office: the fifth symbol repeats a transfer."
]

var buildings: Array[Dictionary] = []
var turrets: Array[Node3D] = []
var turret_flashes: Array[float] = []
var turret_beams: Array[MeshInstance3D] = []
var surface_solids: Array[Rect2] = []
var interior_solids: Array[Rect2] = []
var interior: Node3D
var room_mesh: MeshInstance3D
var pod_figure: MeshInstance3D
var repair_part: MeshInstance3D
var mist: MeshInstance3D
var lift_doors: Array[MeshInstance3D] = []
var hud: Node2D
var hud_view: SubViewport
var audio: AudioStreamPlayer
var alarm_stream: AudioStreamWAV
var place := "surface"
var building_index := -1
var surface_position := Vector2.ZERO
var surface_heading := 0.0
var discovered: Dictionary = {}
var inventory: Dictionary = {}
var visited: Dictionary = {}
var keypad := false
var sequence := ""
var floor_code := ""
var floor_signature := ""
var transit_left := 0.0
var transit_total := 4.0
var lift_target := ""
var awakening := false
var countdown := 255.0
var alarm_elapsed := 0.0
var alarm_pulse := 0.0
var damage_cooldown := 0.0
var shield := 100
var message := ""
var message_left := 0.0
var completed := false
var failed := false
var visual_time := 0.0
var ship_model: MeshInstance3D
var launch_elapsed := 0.0
var pending_room := true
var interior_builder := Interiors.new()

func reset() -> void:
	super.reset()
	place = "surface"
	building_index = -1
	discovered.clear()
	inventory.clear()
	visited.clear()
	keypad = false
	sequence = ""
	floor_code = ""
	transit_left = 0
	awakening = false
	countdown = 255
	alarm_elapsed = 0
	damage_cooldown = 0
	shield = 100
	completed = false
	launch_elapsed = 0
	if ship_model != null:
		ship_model.position.y = 0
	failed = false
	pending_room = true
	if audio != null:
		audio.stop()
	if atmosphere != null:
		atmosphere.fog_enabled = false
	notify("ZEN OFFLINE. Find a pressure regulator, ignition cell, and reflector coupler.")

func notify(text: String) -> void:
	message = text
	message_left = 7

func _building(p: Vector3, size: Vector3, side: float, index: int) -> void:
	super._building(p, size, side, index)
	var id := buildings.size()
	buildings.append({"door": Vector2(p.x + size.x * 0.5, p.z + 1.0),
		"label": "ARCHIVE %02d" % (id + 1) if id < 5 else (
			"PRESSURE WORKSHOP" if id == 5 else ("IGNITION STORE" if id == 6 else (
				"DEEP TRANSIT / ELEVATOR" if id == 7 else "ABANDONED BLOCK %02d" % (id + 1))))})
	_box(p + Vector3(size.x * 0.5 - 1.3, 4.2, -0.06), Vector3(2.6, 0.35, 0.06),
		GOLD if id == 7 else ICE, true)

func _courier() -> void:
	_box(Vector3(-0.72, 0.42, -1.75), Vector3(1.44, 0.21, 3.5), SHELL)
	_box(Vector3(-0.68, 0.66, -1.5), Vector3(1.36, 0.35, 0.7), INK)
	for side in [-1.0, 1.0]:
		var path: Array[Vector3] = [Vector3(side * 0.8, 0.65, -1.65),
			Vector3(side * 0.68, 1.85, -0.65), Vector3(side * 0.7, 1.85, 0.65),
			Vector3(side * 0.8, 0.65, 1.7)]
		for i in 3:
			_bar(path[i], path[i + 1], 0.075, SHELL)
			_bar(path[i] + Vector3(0, 0.015, 0), path[i + 1] + Vector3(0, 0.015, 0), 0.025, ICE, true)
		_bar(path[0], path[3], 0.09, SHELL)
		_bar(path[0], path[2], 0.05, SHELL)
		for z in [-1.35, 1.4]:
			_bar(Vector3(side * 0.4, 0.9, z * 0.8), Vector3(side * 1.1, 0.55, z), 0.075, SHELL)
			for coil in 7:
				_cylinder(Vector3(side * (0.58 + coil * 0.05), 0.82 - coil * 0.035, z), 0.13, 0.045, ICE, 1, true)
		_box(Vector3(side * 0.4 - 0.19, 0.65, -0.35), Vector3(0.38, 0.58, 0.55), SHELL * 0.65)
		_box(Vector3(side * 0.5 - 0.18, 0.83, 1.72), Vector3(0.36, 0.14, 0.07), ICE, true)
	for z in [-0.65, 0.65]:
		_bar(Vector3(-0.68, 1.85, z), Vector3(0.68, 1.85, z), 0.075, SHELL)
	_cylinder(Vector3(0, 1.15, -1.12), 0.27, 1.1, SHELL, 0)
	for x in [-0.48, 0.48]:
		_cylinder(Vector3(x, 1.15, -1.12), 0.28, 0.075, ICE, 0, true)
	_box(Vector3(-0.65, 1.05, 0.7), Vector3(1.3, 0.2, 0.25), INK)
	_bar(Vector3(-0.78, 0.47, 1.86), Vector3(0.78, 0.47, 1.86), 0.12, SHELL)

func _bar(a: Vector3, b: Vector3, width: float, color: Color, lit := false) -> void:
	var direction := b - a
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
	var right := up.cross(direction).normalized()
	var basis := Basis(right, direction.normalized(), right.cross(direction).normalized())
	_box(Vector3(-width / 2, 0, -width / 2), Vector3(width, direction.length(), width), color, lit, Transform3D(basis, a))

func build(view: Node) -> void:
	super.build(view)
	var warning_shader := Shader.new()
	warning_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float warning_flash = 0.0;
void fragment() {
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.07, 0.22), warning_flash * 0.65);
}
"""
	light_material.shader = warning_shader
	_box(Vector3(-118, -0.52, 162), Vector3(236, 0.5, 258), Color(0.07, 0.13, 0.18))
	for x in [-118.0, 62.0]:
		_box(Vector3(x, -0.52, -12), Vector3(56, 0.5, 174), Color(0.07, 0.13, 0.18))
	for x in [-66.0, 0.0, 66.0]:
		for side in [-1.0, 1.0]:
			_box(Vector3(x + side * 6.5, 0.015, 162 if x == 0 else -12),
				Vector3(0.16, 0.025, 258 if x == 0 else 432), ICE * 0.8, true)
	for z in [185.0, 255.0, 325.0, 395.0]:
		_gate(z)
		for side in [-1.0, 1.0]:
			var x := -52.0 if side < 0 else 24.0
			_building(Vector3(x, 0, z + 8), Vector3(28, 18 + fmod(z, 14), 23), side, 1)
	for z in [18.0, 108.0, 220.0, 330.0]:
		for side in [-1.0, 1.0]:
			_building(Vector3(-112 if side < 0 else 84, 0, z), Vector3(26, 22, 24), side, 2)
	for z in [170.0, 240.0, 310.0, 380.0]:
		for side in [-1.0, 1.0]:
			_box(Vector3(-114, 0.016, z + side * 4), Vector3(228, 0.02, 0.12), ICE * 0.6, true)
	var extension := _finish("ExpandedDistrict")
	extension.reparent(world)
	for z in [64.0, 205.0, 340.0]:
		for side in [-1.0, 1.0]:
			_turret(Vector2(side * 19, z))
	_ship()
	ship_model = _finish("StrandedAsh")
	ship_model.position = Vector3(SHIP.x, 0, SHIP.y)
	surface_solids = solids.duplicate()
	hud_view = SubViewport.new()
	hud_view.size = Vector2i(960, 540)
	hud_view.transparent_bg = true
	hud_view.disable_3d = true
	hud_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.add_child(hud_view)
	hud = Overlay.new()
	hud.city = self
	hud_view.add_child(hud)
	_create_audio()

func _ship() -> void:
	_prism(PackedVector2Array([Vector2(-5, 0.7), Vector2(5, 0.7), Vector2(3.2, 2.2),
		Vector2(1.8, 3.8), Vector2(-1.8, 3.8), Vector2(-3.2, 2.2)]), 7, SHELL,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -3.5)))
	_box(Vector3(-1.5, 2.3, 3.52), Vector3(3, 0.7, 0.05), INK)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 3.3 - 0.6, 0, -2), Vector3(1.2, 1.0, 4), SHELL)
		_box(Vector3(side * 3.0 - 0.2, 1.2, 3.55), Vector3(0.4, 0.4, 0.03), GOLD, true)

func _turret(point: Vector2) -> void:
	_cylinder(Vector3(0, 0.5, 0), 1.5, 1, SHELL)
	_cylinder(Vector3(0, 1.5, 0), 0.65, 1.5, INK)
	var base := _finish("TurretPlinth")
	base.position = Vector3(point.x, 0, point.y)
	_box(Vector3(-1.2, 2.1, -0.7), Vector3(2.4, 0.8, 1.5), SHELL)
	for x in [-0.7, 0.7]:
		_box(Vector3(x - 0.16, 2.3, 0.8), Vector3(0.32, 0.32, 2.3), INK)
		_box(Vector3(x - 0.11, 2.34, 3.11), Vector3(0.22, 0.22, 0.04), GOLD, true)
	var gun := _finish("SweepingTurret")
	gun.position = base.position
	_bar(Vector3(0, 2.45, 3.2), Vector3(0, 2.45, 30), 0.035, GOLD, true)
	var flash := _finish("TurretPulse")
	flash.reparent(gun)
	flash.position = Vector3.ZERO
	flash.visible = false
	turret_beams.append(flash)
	turrets.append(gun)
	turret_flashes.append(0)
	solids.append(Rect2(point.x - 1.5, point.y - 1.5, 3, 3))

func _create_audio() -> void:
	audio = AudioStreamPlayer.new()
	audio.volume_db = -20
	add_child(audio)
	alarm_stream = AudioStreamWAV.new()
	alarm_stream.format = AudioStreamWAV.FORMAT_16_BITS
	alarm_stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(11025 * 2)
	for i in 11025:
		var t := float(i) / 22050
		var envelope := minf(t * 30, 1) * minf((0.5 - t) * 20, 1)
		var value := int(sin(TAU * (360 * t + 180 * t * t)) * envelope * 12000)
		samples.encode_s16(i * 2, value)
	alarm_stream.data = samples
	audio.stream = alarm_stream

func blocked(point: Vector2, radius: float) -> bool:
	var bounds := CITY_BOUNDS if place == "surface" else Rect2(-22, 0, 44, 58)
	if not bounds.grow(-radius).has_point(point):
		return true
	var obstacles := surface_solids if place == "surface" else interior_solids
	for rect in obstacles:
		if rect.grow(radius).has_point(point):
			return true
	return false

func nearest_building(max_distance := 3.5) -> int:
	var nearest := -1
	var best := max_distance
	for i in buildings.size():
		var door: Vector2 = buildings[i].door
		var distance := position_xz.distance_to(door)
		if distance < best:
			best = distance
			nearest = i
	return nearest

func enter_building(index: int) -> void:
	if driving or place != "surface" or index < 0 or index >= buildings.size():
		return
	surface_position = buildings[index].door + Vector2(0, -2)
	surface_heading = heading
	building_index = index
	place = "building"
	position_xz = Vector2(0, 3)
	heading = 0
	inspection = 0
	visited[index] = true
	pending_room = true
	notify(str(buildings[index].label) + " / E examines objects; E at the entry returns outside.")

func leave_building() -> void:
	place = "surface"
	position_xz = surface_position
	heading = PI
	keypad = false
	pending_room = true
	notify("Back outside. The buggy is where you parked it.")

func use_object() -> void:
	if completed or failed or transit_left > 0:
		return
	if place == "surface":
		if position_xz.distance_to(SHIP) < 7:
			if inventory.has("regulator") and inventory.has("ignition") and inventory.has("coupler"):
				completed = true
				awakening = false
				audio.stop()
				notify("ZEN: Coupler seated. Engines live. We are leaving!")
			else:
				notify("ASH: NEED PRESSURE REGULATOR / IGNITION CELL / REFLECTOR COUPLER.")
			return
		var index := nearest_building()
		if index >= 0:
			if driving:
				notify("Park and leave the buggy with F before entering a building.")
			else:
				enter_building(index)
			return
		collect_bottle()
	elif position_xz.distance_to(Vector2(0, 2)) < 3:
		if place == "building":
			leave_building()
		else:
			start_lift("surface")
	elif place == "building":
		if building_index == 7 and position_xz.distance_to(Vector2(0, 21)) < 3.2:
			if awakening:
				notify("ZEN: No time for another descent. Get to the ship!")
			else:
				keypad = true
				sequence = ""
		elif position_xz.distance_to(Vector2(0, 14)) < 3:
			if building_index < 5:
				discovered[building_index] = FEB_CODE.substr(building_index, 1)
				notify(CLUES[building_index] + " Copied to the five-slot journal.")
			elif building_index == 5 or building_index == 6:
				var item := "regulator" if building_index == 5 else "ignition"
				if inventory.has(item):
					notify("Already salvaged. No compatible parts remain in this workshop.")
				else:
					inventory[item] = true
					notify("Recovered ship " + item + ". Other containers here are empty.")
					pending_room = true
			else:
				notify("Empty storage. Cracked ceramics, dead cable, and obsolete fittings. Nothing compatible.")
	elif floor_code == FEB_CODE and position_xz.distance_to(Vector2(3.4, 47)) < 3:
		take_coupler()
	elif position_xz.distance_to(Vector2(0, 26)) < 3:
		notify("Dead monitoring console. This floor contains no compatible ship parts.")

func enter_symbol(symbol: String) -> void:
	if not keypad or sequence.length() >= 5 or not symbol.is_valid_int() or symbol.length() != 1:
		return
	sequence += symbol

func submit_sequence() -> void:
	if not keypad:
		return
	if sequence.length() != 5:
		notify("The destination requires exactly five symbols.")
		return
	keypad = false
	start_lift(sequence)

func start_lift(target: String) -> void:
	lift_target = target
	transit_total = 4.0 if target != "surface" else 3.0
	transit_left = transit_total
	inspection = 0
	keypad = false
	position_xz = Vector2(0, 2)
	heading = 0
	place = "lift"
	pending_room = true
	notify("ZEN OFFLINE / Lift descending." if target != "surface" else "Emergency ascent / returning to the surface lobby.")

func finish_lift() -> void:
	if lift_target == "surface":
		place = "building"
		floor_code = ""
		position_xz = Vector2(0, 19)
		heading = PI
		notify("Surface lobby. Exit behind the entry marker and return to the Ash." if awakening else "Surface lobby. E at the entry returns outside.")
	else:
		place = "floor"
		floor_code = lift_target
		position_xz = Vector2(0, 3)
		heading = 0
		notify("Stratum reached. The lift behind you can return to the surface.")
	pending_room = true

func take_coupler() -> void:
	if inventory.has("coupler"):
		return
	inventory["coupler"] = true
	awakening = true
	countdown = 255
	alarm_elapsed = 0
	alarm_pulse = 0
	if repair_part != null:
		repair_part.visible = false
	notify("ZEN: RUN!")
	if audio != null:
		audio.play()

func retry_escape() -> void:
	failed = false
	shield = 100
	damage_cooldown = 0
	inventory.erase("coupler")
	awakening = false
	countdown = 255
	alarm_elapsed = 0
	place = "floor"
	floor_code = FEB_CODE
	building_index = 7
	surface_position = buildings[7].door + Vector2(0, -2)
	position_xz = Vector2(0, 43)
	heading = 0
	driving = false
	keypad = false
	transit_left = 0
	pending_room = true
	notify("Chamber checkpoint restored. Recover the coupler, then return to the lift.")

func tick(delta: float, view: Node) -> void:
	message_left = maxf(0, message_left - delta)
	if completed or failed:
		if completed:
			launch_elapsed += delta
		if view.menu_tap(KEY_ENTER):
			if failed:
				retry_escape()
			else:
				reset()
		return
	if awakening:
		countdown = maxf(0, countdown - delta)
		alarm_elapsed += delta
		alarm_pulse -= delta
		if alarm_pulse <= 0:
			alarm_pulse = 2
			audio.play()
		if countdown <= 0:
			failed = true
			audio.stop()
			notify("PURGE COMPLETE. Enter retries from the chamber checkpoint.")
			return
	damage_cooldown = maxf(0, damage_cooldown - delta)
	if transit_left > 0:
		transit_left = maxf(0, transit_left - delta)
		if transit_left <= 0:
			finish_lift()
		return
	if keypad:
		for digit in 10:
			if view.menu_tap(KEY_0 + digit) or view.menu_tap(KEY_KP_0 + digit):
				enter_symbol(str(digit))
		if view.menu_tap(KEY_BACKSPACE):
			sequence = sequence.left(maxi(0, sequence.length() - 1))
		if view.menu_tap(KEY_ENTER):
			submit_sequence()
		if view.menu_tap(KEY_F):
			keypad = false
		return
	if view.menu_tap(KEY_E):
		use_object()
	if place == "surface":
		super.tick(delta, view)
	else:
		view.menu_tap(KEY_F)
		view.menu_tap(KEY_V)
		var turn := float(Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		turn -= float(Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		var throttle := float(Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		throttle -= float(Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		heading += turn * delta * 1.7
		move_distance(throttle * 5.5 * delta)
	_tick_turrets(delta)

func _tick_turrets(delta: float) -> void:
	for i in turrets.size():
		var turret := turrets[i]
		turret_flashes[i] = maxf(0, turret_flashes[i] - delta)
		var point := Vector2(turret.position.x, turret.position.z)
		var offset := position_xz - point
		if awakening and place == "surface":
			turret.rotation.y = rotate_toward(turret.rotation.y, atan2(offset.x, offset.y), delta * 0.8)
			if offset.length() < 34 and damage_cooldown <= 0 and absf(angle_difference(turret.rotation.y, atan2(offset.x, offset.y))) < 0.12 and _line_clear(point, position_xz):
				shield = maxi(0, shield - 12)
				damage_cooldown = 2
				turret_flashes[i] = 0.2
				velocity *= 0.55
				notify("ZEN: Turrets are live! Stay behind the buildings!")
				if shield == 0:
					failed = true
					audio.stop()
					notify("SUIT BREACHED. Enter retries the chamber checkpoint.")
		else:
			turret.rotation.y = sin(visual_time * 0.35 + i) * 0.9

func _line_clear(a: Vector2, b: Vector2) -> bool:
	var length := a.distance_to(b)
	for step in range(4, ceili(length / 0.5)):
		var point := a.lerp(b, step * 0.5 / maxf(length, 0.01))
		for rect in surface_solids:
			if rect.has_point(point):
				return false
	return true

func _sync_room() -> void:
	if not pending_room:
		return
	pending_room = false
	if interior != null:
		interior.free()
	interior = Node3D.new()
	interior.name = "SeparateInterior"
	add_child(interior)
	lift_doors.clear()
	interior_solids.clear()
	pod_figure = null
	repair_part = null
	mist = null
	if place != "surface":
		interior_builder.build(self)

func render_style(view: Node, time: float, distance: float, detail: int) -> Texture2D:
	if not initialized:
		build(view)
	visual_time = time
	light_material.set_shader_parameter("warning_flash", 1.0 if awakening and fmod(alarm_elapsed, 1.0) < 0.15 else 0.0)
	_sync_room()
	# The base renderer still owns the cached optical pipeline and camera.
	var result := super.render_style(view, time, distance, detail)
	var outdoors := place == "surface"
	world.visible = outdoors
	carrier.visible = outdoors
	vehicle.visible = outdoors and (not driving or inspection != 0)
	for child in get_children():
		if child is MeshInstance3D and child != world and child != vehicle and not wheels.has(child):
			child.visible = outdoors
	for bottle in bottles:
		var index := bottles.find(bottle)
		bottle.visible = outdoors and not inventory.has("cell_%d" % index)
	for turret in turrets:
		turret.visible = outdoors
	for i in turret_beams.size():
		turret_beams[i].visible = outdoors and turret_flashes[i] > 0
	interior.visible = not outdoors
	atmosphere.fog_enabled = awakening and not outdoors
	atmosphere.fog_light_color = Color(0.12, 0.22, 0.28)
	atmosphere.fog_density = 0.012 if awakening else 0
	if not outdoors:
		view.present(position_xz.x, 1.8, position_xz.y, heading,
			0.09 if place == "floor" and floor_code == FEB_CODE else -0.03, 90)
	if inspection == 1 and outdoors:
		view.present(106, 96, -30, -0.29, -0.28, 520)
	if completed:
		ship_model.position.y = minf(launch_elapsed * launch_elapsed * 0.6, 80)
		view.present(13, 7, -18, -0.78, 0.12, 180)
	if pod_figure != null:
		pod_figure.rotation.y = sin(alarm_elapsed * 0.8) * minf(alarm_elapsed / 60, 0.18) if awakening else 0
		pod_figure.position.y = minf(alarm_elapsed / 120, 0.15) if awakening else 0
	if mist != null:
		mist.visible = awakening
		mist.material_override.set_shader_parameter("alarm_time", alarm_elapsed)
	for i in lift_doors.size():
		var opening := 1.0
		if transit_left > 0:
			var elapsed := transit_total - transit_left
			opening = maxf(1 - elapsed * 2, 1 - transit_left * 2)
		lift_doors[i].position.x = (-1 if i == 0 else 1) * clampf(opening, 0, 1) * 1.5
	hud.queue_redraw()
	hud_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	return result

func collect_bottle() -> void:
	if driving:
		return
	for i in bottles.size():
		var point: Vector3 = CELLS[i]
		if not inventory.has("cell_%d" % i) and position_xz.distance_to(Vector2(point.x, point.z)) < 2.4:
			inventory["cell_%d" % i] = true
			bottles[i].visible = false
			collected += 1
			notify("Recovered an auxiliary charge cell. Ship repair components are inside buildings.")
			return

func prompt() -> String:
	if completed:
		return "SHIP REPAIRED / Enter: restart prototype"
	if failed:
		return "ESCAPE FAILED / Enter: chamber checkpoint"
	if transit_left > 0:
		return "LIFT IN TRANSIT / Doors locked"
	if keypad:
		return "0-9 SELECT GLYPH / BACKSPACE ERASE / ENTER TRAVEL / F CANCEL"
	if place == "surface":
		if position_xz.distance_to(SHIP) < 7:
			return "E: install recovered parts and launch the Ash"
		var index := nearest_building(15)
		if index >= 0:
			return str(buildings[index].label) + (" / F: park first" if driving else " / E at the door: enter")
		return "W/S MOVE  A/D TURN  F BUGGY  E INTERACT  V INSPECT"
	if position_xz.distance_to(Vector2(0, 2)) < 4:
		return "E: return outside" if place == "building" else "E: call emergency ascent"
	if place == "building":
		if building_index == 7:
			return "E at rear panel: five-symbol destination / journal at left"
		return "E at the rear workbench: search / entry behind you"
	if floor_code == FEB_CODE:
		return "Coupler recovered. Return to the lift behind you!" if inventory.has("coupler") else "E at the amber service socket: take reflector coupler / lift behind you"
	return "Explore this floor / E at entry: return to the surface"

func deactivate() -> void:
	super.deactivate()
	if hud_view != null:
		hud_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
