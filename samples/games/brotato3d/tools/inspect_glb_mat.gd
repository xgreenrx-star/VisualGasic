extends SceneTree

func _initialize() -> void:
	var scene = load("res://assets/models/kenney_blocky/glb/character-a.glb")
	var inst = scene.instantiate()
	_print_mats(inst, 0)
	quit()

func _print_mats(n: Node, d: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var m = mi.get_active_material(i)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				var tex_name := "<null>"
				if sm.albedo_texture:
					tex_name = sm.albedo_texture.resource_path
				print("  ".repeat(d), mi.name, " surf", i, " albedo=", sm.albedo_color, " tex=", tex_name)
	for c in n.get_children():
		_print_mats(c, d + 1)
