@tool
extends ConfirmationDialog
## Diff preview — shows the per-file plan from a code-spec or project-spec
## before anything is written.  The user can ✅ Apply or ❌ Cancel.
##
## Usage (from vg_ai_help):
##   var dlg := preload(\"vg_ai_diff_dialog.gd\").new()
##   EditorInterface.popup_dialog_centered(dlg, Vector2i(720, 540))
##   dlg.set_plan(plan_array)            # see vg_ai_code_spec.plan()
##   dlg.confirmed.connect(func(): apply())
##
## The plan is an Array of Dictionaries each containing:
##   path:        String
##   action:      "create" | "update" | "unchanged"
##   old, new:    String        # full file contents
##   lint:        Array         # per-issue dicts with severity/message/line
##   safe:        bool
##   safe_reason: String
##
## Render strategy: a tree of files on the left, a RichTextLabel on the
## right showing a coloured line diff for the selected file.  Keeps the
## widget tree small so the dialog is cheap to spawn per spec.

const COL_ADD := "#aaffaa"
const COL_DEL := "#ff8888"
const COL_CTX := "#aaaaaa"
const COL_HDR := "#88bbff"
const COL_WARN:= "#ffcc66"

var _plan: Array = []
var _split: HSplitContainer
var _list: ItemList
var _body: RichTextLabel


func _init() -> void:
	title = "Apply spec — review changes"
	get_ok_button().text = "✅ Apply"
	get_cancel_button().text = "❌ Cancel"
	min_size = Vector2(720, 480)
	_build_ui()


func _build_ui() -> void:
	_split = HSplitContainer.new()
	_split.split_offset = 220
	_split.anchor_right = 1.0
	_split.anchor_bottom = 1.0
	add_child(_split)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	_split.add_child(_list)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.selection_enabled = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_body)


## Populate the dialog with a plan.  Disables the Apply button if every
## entry is unsafe or unchanged.
func set_plan(plan: Array) -> void:
	_plan = plan
	_list.clear()
	var any_apply := false
	for i in plan.size():
		var entry: Dictionary = plan[i]
		var icon := _action_icon(entry)
		var path := str(entry.get("path", "<unnamed>"))
		var label := "%s %s" % [icon, path]
		_list.add_item(label)
		if not bool(entry.get("safe", true)):
			_list.set_item_custom_fg_color(i, Color(0.95, 0.4, 0.4))
		elif entry.get("action") == "unchanged":
			_list.set_item_custom_fg_color(i, Color(0.6, 0.6, 0.6))
		else:
			any_apply = true
	get_ok_button().disabled = not any_apply
	if plan.size() > 0:
		_list.select(0)
		_render_entry(0)
	else:
		_body.clear()
		_body.append_text("[i]No changes to apply.[/i]")


# --- rendering -------------------------------------------------------------


func _action_icon(entry: Dictionary) -> String:
	if not bool(entry.get("safe", true)):
		return "🚫"
	match str(entry.get("action", "")):
		"create":     return "+"
		"update":     return "~"
		"unchanged":  return "="
		_:            return "?"


func _on_item_selected(idx: int) -> void:
	_render_entry(idx)


func _render_entry(idx: int) -> void:
	if idx < 0 or idx >= _plan.size():
		return
	var entry: Dictionary = _plan[idx]
	_body.clear()
	var path := str(entry.get("path", ""))
	var action := str(entry.get("action", "?"))
	_body.append_text("[color=%s][b]%s[/b][/color]\n" % [COL_HDR, path])
	_body.append_text("[color=%s]Action: %s[/color]\n" % [COL_CTX, action])
	if not bool(entry.get("safe", true)):
		_body.append_text("[color=%s]\u26a0 BLOCKED: %s[/color]\n" % [
			COL_DEL, str(entry.get("safe_reason", ""))])
	# Lint summary
	var lint: Array = entry.get("lint", [])
	if not lint.is_empty():
		_body.append_text("\n[color=%s]Lint findings:[/color]\n" % COL_WARN)
		for issue in lint:
			if typeof(issue) != TYPE_DICTIONARY:
				continue
			_body.append_text("  [color=%s]%s[/color] line %d: %s\n" % [
				COL_WARN,
				str(issue.get("severity", "")),
				int(issue.get("line", 0)),
				str(issue.get("message", "")),
			])
	_body.append_text("\n")
	# Diff body
	var old := str(entry.get("old", ""))
	var new_text := str(entry.get("new", ""))
	if action == "create":
		_render_full(new_text, COL_ADD, "+")
	elif action == "update":
		_render_diff(old, new_text)
	else:
		_render_full(new_text.substr(0, min(new_text.length(), 4000)), COL_CTX, " ")


func _render_full(text: String, color: String, prefix: String) -> void:
	for line in text.split("\n"):
		_body.append_text("[color=%s]%s %s[/color]\n" % [color, prefix, _esc(line)])


## Tiny line-level LCS-free diff: any line not in the other side is
## treated as +/-.  Cheap and good-enough for AI-emitted files which
## tend to be either tiny edits or full rewrites.
func _render_diff(old: String, new_text: String) -> void:
	var old_lines := old.split("\n")
	var new_lines := new_text.split("\n")
	var old_set := {}
	for l in old_lines:
		old_set[l] = true
	var new_set := {}
	for l in new_lines:
		new_set[l] = true
	# Walk new_lines emitting +/context, then trail with deleted lines
	# from old that don't appear in new.  This is intentionally simple
	# (no alignment), but the result is readable for typical spec diffs.
	for line in new_lines:
		if old_set.has(line):
			_body.append_text("[color=%s]  %s[/color]\n" % [COL_CTX, _esc(line)])
		else:
			_body.append_text("[color=%s]+ %s[/color]\n" % [COL_ADD, _esc(line)])
	var removed := 0
	for line in old_lines:
		if not new_set.has(line):
			_body.append_text("[color=%s]- %s[/color]\n" % [COL_DEL, _esc(line)])
			removed += 1
			if removed > 200:
				_body.append_text("[color=%s]  ... (%d more removed lines suppressed)[/color]\n" % [
					COL_CTX, old_lines.size() - removed])
				break


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")
