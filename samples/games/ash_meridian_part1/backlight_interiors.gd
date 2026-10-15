extends RefCounted

func build(city: Node) -> void:
	if city.place == "lift":
		_cabin(city)
		return
	var underground: bool = city.place == "floor"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(city.floor_code) if underground else city.building_index * 971 + 11
	var length := 56.0 if underground else 25.0
	var ink: Color = city.INK
	var shell: Color = city.SHELL
	var cyan: Color = city.ICE
	var gold: Color = city.GOLD
	city._box(Vector3(-22, -0.3, 0), Vector3(44, 0.3, length), shell * 0.6)
	_wall(city, Rect2(-22, 0, 0.4, length), shell)
	_wall(city, Rect2(21.6, 0, 0.4, length), shell)
	_wall(city, Rect2(-22, length - 0.4, 44, 0.4), shell)
	_wall(city, Rect2(-22, 0, 20, 0.3), shell)
	_wall(city, Rect2(2, 0, 20, 0.3), shell)
	city._box(Vector3(-22, 6, 0), Vector3(44, 0.25, length), ink)
	for x in [-2.8, 2.8]:
		city._box(Vector3(x, 0.014, 1), Vector3(0.07, 0.03, length - 2), cyan * 0.65, true)
	for z in range(5, int(length), 8):
		city._box(Vector3(-2.5, 5.95, z), Vector3(5, 0.04, 0.5), cyan * 0.7, true)
	if underground or city.building_index == 7:
		_lift(city, underground)
	var signature := ""
	if underground:
		for row in (3 if city.floor_code == city.FEB_CODE else 4):
			var z := 9.0 + row * 10
			for side in [-1.0, 1.0]:
				var width := rng.randi_range(7, 15)
				var depth := rng.randi_range(5, 8)
				var x := -3.5 - width if side < 0 else 3.5
				signature += "%d:%d;" % [width, depth]
				_wall(city, Rect2(x, z, width, 0.25), shell * 0.7)
				_wall(city, Rect2(x, z + depth, width, 0.25), shell * 0.7)
				var facing := -3.6 if side < 0 else 3.35
				_wall(city, Rect2(facing, z, 0.25, 1.2), shell)
				_wall(city, Rect2(facing, z + 4, 0.25, depth - 4), shell)
				var back := x if side < 0 else x + width - 0.25
				_wall(city, Rect2(back, z, 0.25, depth), shell)
				for i in rng.randi_range(1, 3):
					var prop_x := x + 1.5 + i * 2.0 if side > 0 else x + width - 1.5 - i * 2.0
					city._box(Vector3(prop_x, 0, z + depth - 1.8), Vector3(0.9, 1.0 + rng.randf(), 1),
						ink)
					city.interior_solids.append(Rect2(prop_x, z + depth - 1.8, 0.9, 1))
				# Sparse filled geometry and narrow luminous ribs mix the two treatments.
				for y in [0.5, 3.0, 5.2]:
					city._bar(Vector3(back + 0.1, y, z), Vector3(back + 0.1, y, z + depth),
						0.025, cyan * (0.55 if int(city.floor_code) % 2 else 0.9), true)
		city._box(Vector3(-1.2, 0, 26), Vector3(2.4, 1.0, 1.2), ink)
		city.interior_solids.append(Rect2(-1.2, 26, 2.4, 1.2))
		city._box(Vector3(-0.9, 1.01, 26.2), Vector3(1.8, 0.03, 0.7), cyan * 0.4, true)
	else:
		for side in [-1.0, 1.0]:
			for z in [7.0, 17.0]:
				city._box(Vector3(side * 12 - 1.5, 0, z), Vector3(3, 1.4, 2), ink)
				city.interior_solids.append(Rect2(side * 12 - 1.5, z, 3, 2))
				city._box(Vector3(side * 12 - 1.2, 1.41, z + 0.2), Vector3(2.4, 0.03, 0.3), cyan * 0.22, true)
		if city.building_index != 7:
			city._box(Vector3(-1.8, 0, 14), Vector3(3.6, 1.0, 1.4), shell)
			city.interior_solids.append(Rect2(-1.8, 14, 3.6, 1.4))
			var item: bool = (city.building_index == 5 and not city.inventory.has("regulator")) or (city.building_index == 6 and not city.inventory.has("ignition"))
			if item:
				city._cylinder(Vector3(0, 1.4, 14.5), 0.35, 0.7, gold, 1, true)
			elif city.building_index < 5:
				city._box(Vector3(-0.8, 1.02, 14.2), Vector3(1.6, 0.03, 0.9), gold * 0.7, true)
		else:
			city._box(Vector3(2.4, 0, 21), Vector3(0.5, 2.6, 1.2), ink)
			for y in [0.6, 1.2, 1.8]:
				city._box(Vector3(2.35, y, 21.1), Vector3(0.03, 0.25, 0.8), gold, true)
	city.floor_signature = signature
	city.room_mesh = city._finish("InteriorShell")
	city.room_mesh.reparent(city.interior)
	if underground and city.floor_code == city.FEB_CODE:
		_pod(city)
	city.interior.visible = true

func _wall(city: Node, rect: Rect2, color: Color) -> void:
	city._box(Vector3(rect.position.x, 0, rect.position.y), Vector3(rect.size.x, 6, rect.size.y), color)
	city.interior_solids.append(rect)

func _lift(city: Node, underground: bool) -> void:
	var z := 0.4 if underground else 22.5
	for side in [-1.0, 1.0]:
		city._box(Vector3(side * 2.1 - 0.15, 0, z), Vector3(0.3, 4.5, 0.4), city.SHELL)
		city._box(Vector3(side * 1.8 - 0.04, 0.1, z - 0.03), Vector3(0.08, 4.1, 0.05), city.GOLD, true)
	city._box(Vector3(-2.2, 4.3, z), Vector3(4.4, 0.25, 0.4), city.SHELL)
	for side in [-1.0, 1.0]:
		var x := -1.7 if side < 0 else 0.0
		city._box(Vector3(x, 0, z), Vector3(1.7, 4.2, 0.18), city.SHELL * 0.7)
		city._box(Vector3(x + 0.15, 0.3, z - 0.02), Vector3(1.4, 3.4, 0.02), city.INK)
		var door: MeshInstance3D = city._finish("LiftDoor")
		door.reparent(city.interior)
		city.lift_doors.append(door)

func _pod(city: Node) -> void:
	var pink := Color(1.0, 0.22, 0.7)
	var cyan: Color = city.ICE
	var center := Vector3(0, 0, 49)
	city._cylinder(center + Vector3(0, 0.4, 0), 2.0, 0.8, city.SHELL)
	city._cylinder(center + Vector3(0, 5.2, 0), 1.9, 0.55, city.SHELL)
	for y in [0.12, 0.65, 0.85, 4.95, 5.3, 5.6]:
		city._annulus(center + Vector3(0, y, 0), 1.95 if y < 1 else 1.85, 0.08, pink)
	for y in [1.0, 4.8]:
		city._annulus(center + Vector3(0, y, 0), 1.55, 0.06, cyan)
	for angle in [0.0, PI, PI * 0.25, PI * 0.75]:
		var offset := Vector3(cos(angle) * 1.8, 0, sin(angle) * 1.8)
		city._bar(center + offset + Vector3.UP * 0.85, center + offset + Vector3.UP * 4.95, 0.1, city.SHELL)
		city._bar(center + offset + Vector3.UP, center + offset + Vector3.UP * 4.8, 0.035, cyan, true)
	for y in [1.3, 1.65, 2.0, 3.7, 4.1, 4.45]:
		city._box(center + Vector3(-1.1, y, 1.5), Vector3(2.2, 0.07, 0.04), cyan * 0.5, true)
	city.interior_solids.append(Rect2(-2, 47.7, 4, 3.3))
	city._box(Vector3(2.6, 0, 47), Vector3(1.5, 1.2, 1.2), city.INK)
	city.interior_solids.append(Rect2(2.6, 47, 1.5, 1.2))
	var pod: MeshInstance3D = city._finish("StasisCrownAndCradle")
	pod.reparent(city.interior)
	_figure(city, Vector3.ZERO)
	city.pod_figure = city._finish("FEB")
	city.pod_figure.reparent(city.interior)
	city.pod_figure.position = center
	city._cylinder(Vector3(3.35, 1.6, 47.5), 0.3, 0.7, city.GOLD, 1, true)
	city.repair_part = city._finish("ReflectorCoupler")
	city.repair_part.reparent(city.interior)
	city.repair_part.visible = not city.inventory.has("coupler")
	var glass := MeshInstance3D.new()
	var panel := CylinderMesh.new()
	panel.top_radius = 1.65
	panel.bottom_radius = 1.65
	panel.height = 3.8
	panel.radial_segments = 48
	glass.mesh = panel
	glass.position = center + Vector3.UP * 2.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.1, 0.65, 0.8, 0.055)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = material
	city.interior.add_child(glass)
	var fog := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 38)
	fog.mesh = plane
	fog.position = Vector3(0, 0.7, 37)
	var mist_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float alarm_time = 0.0;
void fragment() {
	float wave = sin(UV.x * 26.0 + alarm_time * 0.4) * sin(UV.y * 18.0 - alarm_time * 0.2);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0 - UV.x);
	ALBEDO = vec3(0.16, 0.35, 0.4);
	ALPHA = (0.12 + wave * 0.05) * edge;
}
"""
	mist_material.shader = shader
	fog.material_override = mist_material
	city.interior.add_child(fog)
	city.mist = fog

func _figure(city: Node, p: Vector3) -> void:
	var body: Color = city.SHELL * 0.6
	var light: Color = city.ICE
	city._prism(PackedVector2Array([Vector2(-0.3, 2.25), Vector2(0.3, 2.25),
		Vector2(0.65, 3.5), Vector2(0.36, 3.85), Vector2(-0.36, 3.85), Vector2(-0.65, 3.5)]),
		0.42, body, Transform3D(Basis.IDENTITY, p + Vector3(0, 0, -0.21)))
	city._cylinder(p + Vector3(0, 4.18, 0), 0.3, 0.57, body)
	for side in [-1.0, 1.0]:
		var shoulder := p + Vector3(side * 0.65, 3.48, 0)
		var elbow := p + Vector3(side * 0.85, 2.78, -0.06)
		var wrist := p + Vector3(side * 0.88, 2.1, -0.12)
		var hip := p + Vector3(side * 0.26, 2.3, 0)
		var knee := p + Vector3(side * 0.32, 1.52, 0)
		var ankle := p + Vector3(side * 0.34, 0.96, 0)
		for pair in [[shoulder, elbow], [elbow, wrist], [hip, knee], [knee, ankle]]:
			city._bar(pair[0], pair[1], 0.18, body)
			city._bar(pair[0] + Vector3(0, 0, -0.12), pair[1] + Vector3(0, 0, -0.12), 0.035, light, true)
		for joint in [shoulder, elbow, knee]:
			city._cylinder(joint, 0.17, 0.20, light, 0, true)
		city._box(ankle + Vector3(-0.14, -0.1, -0.28), Vector3(0.28, 0.16, 0.45), body)
		city._box(p + Vector3(side * 0.15 - 0.09, 4.18, -0.305), Vector3(0.18, 0.06, 0.03), Color(1, 0.2, 0.7), true)
	for y in [2.65, 2.9, 3.15, 3.4]:
		var width: float = (y - 2.2) * 0.42
		var rib: Array[Vector3] = [p + Vector3(-width, y + 0.1, -0.24), p + Vector3(0, y, -0.27),
			p + Vector3(width, y + 0.1, -0.24)]
		city._trace(rib, 0.035, light)
	city._bar(p + Vector3(0, 2.3, -0.26), p + Vector3(0, 3.85, -0.26), 0.035, light, true)

func _cabin(city: Node) -> void:
	city._box(Vector3(-3, -0.2, 0), Vector3(6, 0.2, 7), city.SHELL)
	city._box(Vector3(-3, 4.5, 0), Vector3(6, 0.2, 7), city.INK)
	for x in [-3.0, 2.8]:
		_wall(city, Rect2(x, 0, 0.2, 7), city.SHELL)
		for y in [0.6, 3.7]:
			city._box(Vector3(x + 0.21, y, 0.2), Vector3(0.03, 0.06, 6.6), city.ICE, true)
	_wall(city, Rect2(-3, 0, 6, 0.2), city.SHELL)
	for x in [-3.0, 1.7]:
		_wall(city, Rect2(x, 6.7, 1.3, 0.2), city.SHELL)
	city.room_mesh = city._finish("TransitCabin")
	city.room_mesh.reparent(city.interior)
	for side in [-1.0, 1.0]:
		city._box(Vector3(-1.7 if side < 0 else 0.0, 0, 6.7), Vector3(1.7, 4.3, 0.15), city.SHELL * 0.8)
		var door: MeshInstance3D = city._finish("CabinDoor")
		door.reparent(city.interior)
		city.lift_doors.append(door)
