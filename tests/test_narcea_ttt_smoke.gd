extends SceneTree
## Smoke test — hybrid menu + TicTacToe intent routing and local synthesis.

const AIHelp := preload("res://addons/visual_gasic/vg_ai_help.gd")
const ProjectSynth := preload("res://addons/visual_gasic/vg_ai_project_synth.gd")

const USER_PROMPT := "make a form with a button labled \"Start\" and a button labled \"Exit\" when the exit button is pressed exit the program. When the Start button is pressed show a 2d tic tac toe game with a computer player and a human player. The computer will place an X in a random square. The player will use the arrow keys to select a square to place the O."

var _failed := 0
var _passed := 0


func _initialize() -> void:
	print("=== Narcea TTT Hybrid Smoke ===")
	var panel: Node = AIHelp.new()
	var intent: String = panel._detect_build_intent(USER_PROMPT)
	_expect("hybrid prompt routes to project", intent == "project", "got %s" % intent)
	panel.free()

	var spec := {
		"project_name": "ttt_smoke",
		"subdir": "ai_projects",
		"main_scene": "MenuForm.tscn",
		"forms": [{
			"form_name": "MenuForm",
			"form_size": [320, 120],
			"auto_events": true,
			"controls": [
				{"type": "Button", "name": "btnStart", "text": "Start", "left": 16, "top": 16, "width": 120, "height": 32},
				{"type": "Button", "name": "btnExit", "text": "Exit", "left": 160, "top": 16, "width": 120, "height": 32},
			],
		}],
		"files": [],
	}
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var root: String = ps.project_root(spec)
	_cleanup(root)
	var fin: Dictionary = ProjectSynth.finalize_project(spec, root, USER_PROMPT)
	var notes: Array = fin.get("notes", [])
	_expect("finalize wrote menu and game", notes.size() >= 2, str(notes))
	var menu_vg := FileAccess.get_file_as_string(fin.get("menu_vg", ""))
	_expect("menu Exit uses End", menu_vg.find("\n\tEnd\n") >= 0 or menu_vg.ends_with("\tEnd\n"))
	_expect("menu Start uses ChangeScene", menu_vg.to_lower().find("changescene") >= 0)
	var game_vg := FileAccess.get_file_as_string(fin.get("game_vg", ""))
	_expect("game has _Draw", game_vg.to_lower().find("sub _draw") >= 0)
	_expect("game has _Process", game_vg.to_lower().find("sub _process") >= 0)
	_expect("game scene exists", FileAccess.file_exists(fin.get("game_scene", "")))
	_cleanup(root)

	# Pure 2D tic-tac-toe: main_scene IS the game (no menu form).
	var pure_spec := {
		"project_name": "ttt_pure",
		"subdir": "ai_projects",
		"main_scene": "res://ai_projects/ttt_pure/Main.tscn",
		"forms": [],
		"files": [{
			"path": "res://ai_projects/ttt_pure/Main.tscn",
			"source": "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://ai_projects/ttt_pure/Main.vg\" id=\"1_script\"]\n\n[node name=\"Main\" type=\"Node2D\"]\nscript = ExtResource(\"1_script\")\n",
		}],
	}
	root = ps.project_root(pure_spec)
	_cleanup(root)
	fin = ProjectSynth.finalize_project(pure_spec, root, "make a 2d tic tac toe game")
	game_vg = FileAccess.get_file_as_string(fin.get("game_vg", ""))
	_expect("pure main writes Main.vg", fin.get("game_vg", "").ends_with("Main.vg"))
	_expect("pure main game vg exists", FileAccess.file_exists(fin.get("game_vg", "")))
	_expect("pure main game has _Draw", game_vg.to_lower().find("sub _draw") >= 0)
	_cleanup(root)
	_finish()


func _cleanup(root: String) -> void:
	if root.is_empty():
		return
	var abs := ProjectSettings.globalize_path(root)
	if DirAccess.dir_exists_absolute(abs):
		_remove_tree(abs)


func _remove_tree(abs_path: String) -> void:
	var da := DirAccess.open(abs_path)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := abs_path.path_join(name)
			if da.current_is_dir():
				_remove_tree(full)
			else:
				DirAccess.remove_absolute(full)
		name = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func _expect(label: String, cond: bool, reason: String = "") -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s: %s" % [label, reason if not reason.is_empty() else "assertion failed"])


func _finish() -> void:
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
