extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var tool: Script = load("res://repair_generated_build.gd")
	var glitch := "shader_type canvas_item;\nvoid fragment() {\n\tif (glitch_intensity < 0.001) { COLOR = texture(screen_texture, SCREEN_UV); return; }\n\tCOLOR = vec4(1.0);\n}\n"
	var repaired: Dictionary = tool.repair_fragment(glitch, "shader_glitch")
	check(repaired["ok"] and repaired["changed"], "repair legacy glitch processor")
	check(not repaired["code"].contains("return;"), "glitch processor no longer returns")
	var again: Dictionary = tool.repair_fragment(repaired["code"], "shader_glitch")
	check(again["ok"] and not again["changed"] and again["code"] == repaired["code"], "glitch repair is idempotent")
	var shatter := "shader_type canvas_item;\nfloat helper() { return 1.0; }\nvoid fragment() {\n\tif (shatter_progress < 0.001) { COLOR = texture(screen_texture, SCREEN_UV); return; }\n\tif (src.x < cmin.x) {\n\t\tCOLOR = vec4(0.0);\n\t\treturn;\n\t}\n\tCOLOR = vec4(texture(screen_texture, clamp(src, cmin, cmax)).rgb * max(0.0, 1.0 - t * 0.55), 1.0);\n}\n"
	repaired = tool.repair_fragment(shatter, "shader_shatter")
	check(repaired["ok"] and repaired["changed"], "repair both shatter return branches")
	check(repaired["code"].contains("return 1.0;"), "preserve shader helper return")
	check(not repaired["code"].contains("return;"), "shatter processor no longer returns")
	var unsupported: Dictionary = tool.repair_fragment("void fragment() { return; }\n", "shader_glitch")
	check(not unsupported["ok"] and not str(unsupported["error"]).is_empty(), "unsupported return pattern is rejected explicitly")
	var helper := "float after_fragment() { return 2.0; }\n"
	repaired = tool.repair_fragment(glitch + helper, "shader_glitch")
	check(repaired["ok"] and repaired["code"].ends_with(helper), "preserve helper after fragment processor")
	again = tool.repair_fragment(repaired["code"], "shader_glitch")
	check(again["ok"] and not again["changed"], "helper after fragment does not trigger another repair")
	unsupported = tool.repair_fragment("void fragment() { return ; }\n", "shader_glitch")
	check(not unsupported["ok"], "reject unrecognized spaced processor return")
	var directory := "user://vg-generated-repair-%s" % OS.get_process_id()
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "create isolated repair fixture")
	tool.write_text(directory.path_join("Main.tscn"), '[gd_scene format=3]\n\n[sub_resource type="Shader" id="shader_glitch"]\ncode = ' + JSON.stringify(glitch) + '\n\n[node name="Main" type="Node"]\n')
	tool.write_text(directory.path_join("Main.vg"), "Sub StopAllMusic()\nEnd Sub\n")
	tool.write_text(directory.path_join("InfectionBar.tscn"), '[node name="InfectionBar" type="TextureProgressBar" parent="HUD"]\npercent_visible = false\nunder_texture = ExtResource(1)\nprogress_texture = ExtResource(2)\n')
	check(tool.repair(directory), "repair generated scene, music hook and widget")
	var paths := ["Main.tscn", "Main.vg", "InfectionBar.tscn"]
	var first: Array[String] = []
	for name in paths:
		first.append(FileAccess.get_file_as_string(directory.path_join(name)))
	check(first[0].contains("else") and not first[0].contains("return;"), "persist repaired shader code")
	check(first[1].contains("Sub _ExitTree()\n\tStopAllMusic()"), "persist music teardown hook")
	check(first[2].begins_with("[gd_scene ") and first[2].contains('type="ProgressBar"') and not first[2].contains("ExtResource"), "persist standalone widget scene")
	check(tool.repair(directory), "repeat complete repair")
	for i in range(paths.size()):
		check(FileAccess.get_file_as_string(directory.path_join(paths[i])) == first[i], "complete repair is idempotent: " + paths[i])
	var backend = load("res://addons/visual_gasic/plugins/agck/agck_builder_backend.gd").new()
	var controller_path := directory.path_join("controller.vg")
	var level_indices: Array[int] = [0]
	for action in [3.0, "End Game"]:
		backend._generate_main_vg(controller_path, {}, [], 1, level_indices, directory + "/", [], [{"death_action": action}])
		check(FileAccess.get_file_as_string(controller_path).contains("DeathActions = Array(3)"), "generate numeric/string death action: " + str(action))
	paths.append("controller.vg")
	for name in paths:
		check(DirAccess.remove_absolute(directory.path_join(name)) == OK, "remove temporary fixture: " + name)
	check(DirAccess.remove_absolute(directory) == OK, "remove isolated fixture directory")
	print("VG_GENERATED_REPAIR_TESTS_COMPLETED failures=", failures)
	quit(1 if failures else 0)
