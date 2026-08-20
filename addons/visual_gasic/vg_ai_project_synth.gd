@tool
extends RefCounted
## Local synthesis for hybrid menu-form + Node2D game projects when the LLM
## leaves TODO stubs or routes game logic onto a Window form.

const EMPTY_MARKERS := ["' todo:", "todo: implement", "todo: add", "' todo"]


static func prompt_is_pure_2d_game(prompt: String) -> bool:
	var low := prompt.to_lower()
	for t in [
		"2d game", "game will be 2d", "will be 2d", " clone", " remake",
		"joust", "pong", "breakout", "asteroids", "platformer", "shooter",
		"arcade game", "side scroller", "top-down", "flappy", "space invaders",
		"basic shapes", "drawrect", "canvas game", "node2d",
	]:
		if low.find(t) >= 0:
			return true
	if low.find("game") >= 0 and (low.find("2d") >= 0 or low.find("shape") >= 0):
		return true
	return false


static func prompt_is_hybrid_form_game(prompt: String) -> bool:
	var low := prompt.to_lower()
	var has_form := false
	for t in ["make a form", "form with", "create a form", "build a form", "with a button", "with button"]:
		if low.find(t) >= 0:
			has_form = true
			break
	if not has_form and (low.find("button") >= 0 and (low.find("start") >= 0 or low.find("exit") >= 0)):
		has_form = true
	var has_game := false
	for t in [
		"2d game", "tic tac toe", "tictactoe", "show a game", "play a game",
		"node2d", "_draw", "_process", "computer player", "arrow keys",
		"canvas game", "drawrect", "game scene", "mini-game", "minigame",
		"pong", "paddle", "score", "joust", " clone",
	]:
		if low.find(t) >= 0:
			has_game = true
			break
	if has_form and has_game:
		return true
	return has_game and low.find("start") >= 0 and low.find("button") >= 0


static func pure_2d_game_prompt_extra() -> String:
	const Narcea = preload("res://addons/visual_gasic/vg_ai_narcea.gd")
	return (
		" PURE 2D CANVAS GAME RULES: This is a Node2D game (not a Window form). "
		+ "Emit vg-project-spec with files[] containing a Node2D .tscn plus matching .vg. "
		+ "The .vg MUST use Sub _Ready(), Sub _Process(delta), and Sub _Draw() with "
		+ "DrawRect / DrawCircle / DrawLine for graphics when no image assets exist. "
		+ "Set main_scene to the game .tscn. Do NOT put game logic on a Window form. "
		+ "Keep ≤ 6 files under res://ai_projects/<name>/."
		+ Narcea.audit_comments_prompt_extra()
	)


static func hybrid_project_prompt_extra() -> String:
	const Narcea = preload("res://addons/visual_gasic/vg_ai_narcea.gd")
	return (
		" HYBRID MENU + 2D GAME RULES: If the description has a menu form (Start/Exit) "
		+ "that opens a separate canvas game, emit vg-project-spec (not form-only). "
		+ "Put the menu in forms[] and set main_scene to the menu .tscn. "
		+ "Put the game in files[] as a Node2D .tscn plus matching .vg — the game MUST "
		+ "use Sub _Ready(), Sub _Process(delta), and Sub _Draw() with DrawRect/DrawString. "
		+ "Window forms CANNOT call _Draw — never put game drawing on the form script. "
		+ "Menu handlers: Start -> ChangeScene \"res://ai_projects/<project>/Game.tscn\"; "
		+ "Exit -> End. Keep ≤ 6 files."
		+ Narcea.audit_comments_prompt_extra()
	)


static func find_menu_form_spec(spec: Dictionary) -> Dictionary:
	for f in spec.get("forms", []):
		if typeof(f) == TYPE_DICTIONARY:
			return f
	return {}


static func find_game_scene_path(spec: Dictionary, root: String) -> String:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	var menu_name := ""
	var menu_spec := find_menu_form_spec(spec)
	if not menu_spec.is_empty():
		menu_name = str(menu_spec.get("form_name", "")).to_lower()
	var main_file := str(spec.get("main_scene", "")).get_file().get_basename().to_lower()
	for entry in spec.get("files", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var raw_path := str(entry.get("path", ""))
		if not raw_path.to_lower().ends_with(".tscn"):
			continue
		var rebased: String = ps.rebase_path(raw_path, root, null)
		var base := rebased.get_file().get_basename().to_lower()
		if not menu_name.is_empty() and base == menu_name:
			continue
		var src := str(entry.get("source", entry.get("contents", "")))
		if not main_file.is_empty() and base == main_file:
			# Pure 2D games use main_scene as the game Node2D itself — don't skip.
			if src.find("type=\"Node2D\"") >= 0:
				return rebased
			continue
		if src.find("type=\"Node2D\"") >= 0:
			return rebased
		if src.find("type=\"Window\"") < 0:
			return rebased
	var main_scene := str(spec.get("main_scene", "")).strip_edges()
	if not main_scene.is_empty():
		return ps.rebase_path(main_scene, root, null)
	return root + "TicTacToe.tscn"


static func _vg_path_from_tscn_text(tscn_text: String, root: String) -> String:
	if tscn_text.is_empty():
		return ""
	var rx := RegEx.new()
	if rx.compile("path=\"(res://[^\"]+\\.vg)\"") != OK:
		return ""
	var m := rx.search(tscn_text)
	if m == null:
		return ""
	var raw := m.get_string(1)
	if raw.is_empty():
		return ""
	if raw.begins_with(root):
		return raw
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	return ProjectSpec.new().rebase_path(raw, root, null)


static func _tscn_source_for_scene(spec: Dictionary, root: String, game_scene: String) -> String:
	if FileAccess.file_exists(game_scene):
		return FileAccess.get_file_as_string(game_scene)
	var scene_file := game_scene.get_file()
	for entry in spec.get("files", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var raw_path := str(entry.get("path", ""))
		if raw_path.get_file().to_lower() != scene_file.to_lower():
			continue
		return str(entry.get("source", entry.get("contents", "")))
	return ""


static func find_game_vg_path(spec: Dictionary, root: String, game_scene: String) -> String:
	var ProjectSpec = load("res://addons/visual_gasic/vg_ai_project_spec.gd")
	var ps = ProjectSpec.new()
	# Trust the .tscn ext_resource — models often emit scene-only specs.
	var from_tscn := _vg_path_from_tscn_text(_tscn_source_for_scene(spec, root, game_scene), root)
	if not from_tscn.is_empty():
		return from_tscn
	var scene_base := game_scene.get_file().get_basename()
	for entry in spec.get("files", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var raw_path := str(entry.get("path", ""))
		if not raw_path.to_lower().ends_with(".vg"):
			continue
		var rebased: String = ps.rebase_path(raw_path, root, null)
		if rebased.get_file().get_basename().to_lower() == scene_base.to_lower():
			return rebased
	for entry in spec.get("files", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var raw_path := str(entry.get("path", ""))
		if not raw_path.to_lower().ends_with(".vg"):
			continue
		var rebased: String = ps.rebase_path(raw_path, root, null)
		var text := str(entry.get("source", entry.get("contents", ""))).to_lower()
		if text.find("sub _draw") >= 0 or text.find("sub _process") >= 0:
			return rebased
	return root + scene_base + ".vg"


static func menu_form_needs_synthesis(form_spec: Dictionary, vg_src: String, user_prompt: String) -> bool:
	if form_spec.is_empty():
		return false
	var low := user_prompt.to_lower()
	if low.find("start") < 0 and low.find("exit") < 0 and low.find("quit") < 0:
		return false
	var start_btn := _find_button(form_spec, ["start"])
	var exit_btn := _find_button(form_spec, ["exit", "quit"])
	if start_btn.is_empty() and exit_btn.is_empty():
		return false
	if vg_src.is_empty():
		return true
	if _source_has_todo(vg_src):
		return true
	if not exit_btn.is_empty() and not _sub_implements_exit(vg_src, exit_btn):
		return true
	if not start_btn.is_empty() and not _sub_implements_scene_change(vg_src, start_btn):
		return true
	return false


static func prompt_or_spec_is_tictactoe(user_prompt: String, spec: Dictionary) -> bool:
	var low := user_prompt.to_lower()
	if low.find("tic tac") >= 0 or low.find("tictactoe") >= 0:
		return true
	var pname := str(spec.get("project_name", "")).to_lower()
	if pname.find("tictac") >= 0 or pname.find("tic_tac") >= 0:
		return true
	var main := str(spec.get("main_scene", "")).to_lower()
	if main.find("tictac") >= 0:
		return true
	return false


static func game_needs_tictactoe_synthesis(vg_src: String, user_prompt: String, spec: Dictionary = {}) -> bool:
	if not prompt_or_spec_is_tictactoe(user_prompt, spec):
		return false
	if vg_src.is_empty():
		return true
	if _source_has_todo(vg_src):
		return true
	var lower := vg_src.to_lower()
	if lower.find("sub _draw") < 0:
		return true
	if lower.find("sub _process") < 0:
		return true
	return false


static func synthesize_menu_form(form_name: String, form_spec: Dictionary, game_scene: String, user_prompt: String) -> String:
	var start_btn := _find_button(form_spec, ["start"])
	var exit_btn := _find_button(form_spec, ["exit", "quit"])
	if start_btn.is_empty():
		for entry in form_spec.get("controls", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if str(entry.get("type", "")) in ["Button", "CommandButton"]:
				var nm := str(entry.get("name", ""))
				if nm.to_lower() != exit_btn.to_lower():
					start_btn = nm
					break
	var lines: Array[String] = []
	lines.append("' %s — menu\nOption Explicit\n" % form_name)
	lines.append("Sub Form_Load()\n\tPass\nEnd Sub\n")
	if not exit_btn.is_empty():
		lines.append("Sub %s_Click()\n\tEnd\nEnd Sub\n" % exit_btn)
	if not start_btn.is_empty():
		lines.append("Sub %s_Click()\n\tChangeScene \"%s\"\nEnd Sub\n" % [start_btn, game_scene])
	return "\n".join(lines)


static func synthesize_tictactoe_vg() -> String:
	return """' TicTacToe — Node2D canvas game (human O vs computer X)
Option Explicit

Const CELL As Integer = 80
Const MARGIN As Integer = 40
Const BOARD As Integer = 3

Dim board(8) As Integer
Dim selRow As Integer
Dim selCol As Integer
Dim gameOver As Boolean
Dim statusText As String

Sub _Ready()
\tInitBoard
\tstatusText = \"Arrow keys move. Enter/Space places O.\"
\tComputerMove
End Sub

Sub InitBoard()
\tDim i As Integer
\tFor i = 0 To 8
\t\tboard(i) = 0
\tNext
\tselRow = 1
\tselCol = 1
\tgameOver = False
\tstatusText = \"Your turn — place O\"
End Sub

Sub _Process(delta As Single)
\tIf gameOver Then
\t\tIf Input.IsActionJustPressed(\"ui_accept\") Then
\t\t\tInitBoard
\t\t\tComputerMove
\t\t\tQueueRedraw
\t\tEnd If
\t\tReturn
\tEnd If
\tDim moved As Boolean
\tmoved = False
\tIf Input.IsActionJustPressed(\"ui_up\") Then
\t\tselRow = selRow - 1
\t\tIf selRow < 0 Then selRow = 0
\t\tmoved = True
\tEnd If
\tIf Input.IsActionJustPressed(\"ui_down\") Then
\t\tselRow = selRow + 1
\t\tIf selRow > BOARD - 1 Then selRow = BOARD - 1
\t\tmoved = True
\tEnd If
\tIf Input.IsActionJustPressed(\"ui_left\") Then
\t\tselCol = selCol - 1
\t\tIf selCol < 0 Then selCol = 0
\t\tmoved = True
\tEnd If
\tIf Input.IsActionJustPressed(\"ui_right\") Then
\t\tselCol = selCol + 1
\t\tIf selCol > BOARD - 1 Then selCol = BOARD - 1
\t\tmoved = True
\tEnd If
\tIf moved Then QueueRedraw
\tIf Input.IsActionJustPressed(\"ui_accept\") Or Input.IsActionJustPressed(\"ui_select\") Then
\t\tPlayerMove
\tEnd If
End Sub

Function CellIndex(row As Integer, col As Integer) As Integer
\tCellIndex = row * BOARD + col
End Function

Sub PlayerMove()
\tDim idx As Integer
\tidx = CellIndex(selRow, selCol)
\tIf board(idx) <> 0 Then
\t\tstatusText = \"Square taken\"
\t\tQueueRedraw
\t\tReturn
\tEnd If
\tboard(idx) = 2
\tIf CheckWin(2) Then
\t\tgameOver = True
\t\tstatusText = \"You win! Enter to restart\"
\t\tQueueRedraw
\t\tReturn
\tEnd If
\tIf IsDraw() Then
\t\tgameOver = True
\t\tstatusText = \"Draw — Enter to restart\"
\t\tQueueRedraw
\t\tReturn
\tEnd If
\tComputerMove
End Sub

Sub ComputerMove()
\tDim empties(8) As Integer
\tDim count As Integer
\tDim i As Integer
\tcount = 0
\tFor i = 0 To 8
\t\tIf board(i) = 0 Then
\t\t\tempties(count) = i
\t\t\tcount = count + 1
\t\tEnd If
\tNext
\tIf count = 0 Then Return
\tDim pick As Integer
\tpick = Int(RandRange(0, count - 1))
\tboard(empties(pick)) = 1
\tIf CheckWin(1) Then
\t\tgameOver = True
\t\tstatusText = \"Computer wins — Enter to restart\"
\tElseIf IsDraw() Then
\t\tgameOver = True
\t\tstatusText = \"Draw — Enter to restart\"
\tElse
\t\tstatusText = \"Your turn — place O\"
\tEnd If
\tQueueRedraw
End Sub

Function CheckWin(mark As Integer) As Boolean
\tDim r As Integer
\tDim c As Integer
\tFor r = 0 To BOARD - 1
\t\tIf board(CellIndex(r, 0)) = mark And board(CellIndex(r, 1)) = mark And board(CellIndex(r, 2)) = mark Then
\t\t\tCheckWin = True
\t\t\tReturn
\t\tEnd If
\tNext
\tFor c = 0 To BOARD - 1
\t\tIf board(CellIndex(0, c)) = mark And board(CellIndex(1, c)) = mark And board(CellIndex(2, c)) = mark Then
\t\t\tCheckWin = True
\t\t\tReturn
\t\tEnd If
\tNext
\tIf board(0) = mark And board(4) = mark And board(8) = mark Then
\t\tCheckWin = True
\t\tReturn
\tEnd If
\tIf board(2) = mark And board(4) = mark And board(6) = mark Then
\t\tCheckWin = True
\t\tReturn
\tEnd If
\tCheckWin = False
End Function

Function IsDraw() As Boolean
\tDim i As Integer
\tFor i = 0 To 8
\t\tIf board(i) = 0 Then
\t\t\tIsDraw = False
\t\t\tReturn
\t\tEnd If
\tNext
\tIsDraw = True
End Function

Sub _Draw()
\tDim x0 As Integer
\tDim y0 As Integer
\tx0 = MARGIN
\ty0 = MARGIN
\tDrawRect 0, 0, 400, 400, Color.Black
\tDrawRect x0 - 4, y0 - 4, BOARD * CELL + 8, BOARD * CELL + 8, Color.DarkGray
\tDim r As Integer
\tDim c As Integer
\tFor r = 0 To BOARD - 1
\t\tFor c = 0 To BOARD - 1
\t\t\tDim px As Integer
\t\t\tDim py As Integer
\t\t\tpx = x0 + c * CELL
\t\t\tpy = y0 + r * CELL
\t\t\tDrawRect px, py, CELL - 4, CELL - 4, Color.Gray
\t\t\tDim idx As Integer
\t\t\tidx = CellIndex(r, c)
\t\t\tIf board(idx) = 1 Then
\t\t\t\tDrawString \"X\", px + 28, py + 52, Color.White
\t\t\tElseIf board(idx) = 2 Then
\t\t\t\tDrawString \"O\", px + 28, py + 52, Color.Cyan
\t\t\tEnd If
\t\t\tIf r = selRow And c = selCol And Not gameOver Then
\t\t\t\tDrawRect px + 2, py + 2, CELL - 8, CELL - 8, Color.Yellow
\t\t\tEnd If
\t\tNext
\tNext
\tDrawString statusText, 16, 370, Color.White
End Sub
"""


static func finalize_project(spec: Dictionary, root: String, user_prompt: String) -> Dictionary:
	var notes: Array[String] = []
	var menu_spec := find_menu_form_spec(spec)
	var game_scene := find_game_scene_path(spec, root)
	var menu_name := str(menu_spec.get("form_name", "Form1"))
	if menu_name.strip_edges().is_empty():
		menu_name = "Form1"
	var menu_vg := root + menu_name + ".vg"
	var game_vg := find_game_vg_path(spec, root, game_scene)

	if not menu_spec.is_empty():
		var menu_src := FileAccess.get_file_as_string(menu_vg) if FileAccess.file_exists(menu_vg) else ""
		if menu_form_needs_synthesis(menu_spec, menu_src, user_prompt):
			var synthesized := synthesize_menu_form(menu_name, menu_spec, game_scene, user_prompt)
			if _write_file(menu_vg, synthesized):
				notes.append("menu handlers synthesized")

	if game_needs_tictactoe_synthesis(
			FileAccess.get_file_as_string(game_vg) if FileAccess.file_exists(game_vg) else "",
			user_prompt, spec):
		if _write_file(game_vg, synthesize_tictactoe_vg()):
			notes.append("TicTacToe game synthesized")
		var tscn_path := game_scene
		if not FileAccess.file_exists(tscn_path):
			var stub := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]\n\n[node name=\"TicTacToe\" type=\"Node2D\"]\nscript = ExtResource(\"1_script\")\n" % game_vg
			if _write_file(tscn_path, stub):
				notes.append("game scene stub written")

	return {"notes": notes, "game_scene": game_scene, "menu_vg": menu_vg, "game_vg": game_vg}


static func _find_button(form_spec: Dictionary, labels: Array) -> String:
	for entry in form_spec.get("controls", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("type", "")) not in ["Button", "CommandButton"]:
			continue
		var cname := str(entry.get("name", "")).strip_edges()
		var label := str(entry.get("text", entry.get("caption", ""))).to_lower()
		var nm := cname.to_lower()
		for token in labels:
			if label.find(token) >= 0 or nm.find(token) >= 0:
				return cname
	return ""


static func _source_has_todo(src: String) -> bool:
	var low := src.to_lower()
	for m in EMPTY_MARKERS:
		if low.find(m) >= 0:
			return true
	return false


static func _sub_implements_exit(src: String, btn: String) -> bool:
	return _sub_body_contains(src, "%s_Click" % btn, ["end", "quit", "gettree"])


static func _sub_implements_scene_change(src: String, btn: String) -> bool:
	return _sub_body_contains(src, "%s_Click" % btn, ["changescene", "change_scene"])


static func _sub_body_contains(src: String, sub_name: String, tokens: Array) -> bool:
	var lower := src.to_lower()
	var needle := ("sub " + sub_name + "(").to_lower()
	var idx := lower.find(needle)
	if idx < 0:
		return false
	var after := lower.substr(idx)
	var end_idx := after.find("end sub")
	if end_idx < 0:
		return false
	var body := after.substr(0, end_idx)
	for t in tokens:
		if body.find(t) >= 0:
			return true
	return false


static func _write_file(path: String, contents: String) -> bool:
	var dir_abs := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(contents)
	f.close()
	return true
