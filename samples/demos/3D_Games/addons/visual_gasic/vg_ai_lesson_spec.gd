@tool
extends RefCounted
## Lesson-spec — Narcea can hand back a structured interactive lesson
## that the AI panel renders as a step-by-step checklist.  Turns the
## corpus into guided tutorials without leaving the chat.
##
## Schema (fenced as ```vg-lesson-spec):
##
##   {
##     "title": "Move a sprite with the arrow keys",
##     "goal":  "After this you'll understand Input.IsKeyDown and per-frame movement.",
##     "steps": [
##       "Create a new form (File > New Form) and add a PictureBox named picPlayer.",
##       "Add Sub Form_KeyDown(KeyCode As Integer) with the body shown below.",
##       "Run the form and press the arrow keys."
##     ],
##     "hints": [
##       "If the picture doesn't move, check picPlayer is the exact control name.",
##       "Use If KeyCode = vbKeyRight Then picPlayer.Left = picPlayer.Left + 4"
##     ],
##     "snippet": "Option Explicit\nSub Form_KeyDown(KeyCode As Integer)\n    If KeyCode = vbKeyRight Then picPlayer.Left = picPlayer.Left + 4\nEnd Sub\n"
##   }

const FENCE_RE := "```vg-lesson-spec\\s*([\\s\\S]*?)```"


func extract_spec(response_text: String) -> Dictionary:
	if response_text.is_empty():
		return {}
	var rx := RegEx.new()
	rx.compile(FENCE_RE)
	var m := rx.search(response_text)
	if m == null:
		return {}
	var parsed = JSON.parse_string(m.get_string(1).strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("title") and not parsed.has("steps"):
		return {}
	return parsed


func describe(spec: Dictionary) -> String:
	var n: int = (spec.get("steps", []) as Array).size()
	return "lesson: %s (%d step%s)" % [
		str(spec.get("title", "(untitled)")),
		n,
		"" if n == 1 else "s",
	]


## Render the lesson as bbcode for direct insertion into the AI panel
## output.  Caller decides how/where to display it (typically pushed
## into a RichTextLabel).
func render_bbcode(spec: Dictionary) -> String:
	if spec.is_empty():
		return ""
	var parts: Array[String] = []
	parts.append("[color=#88ccff]📘 LESSON:[/color] [b]%s[/b]" % str(spec.get("title", "(untitled)")))
	var goal := str(spec.get("goal", "")).strip_edges()
	if not goal.is_empty():
		parts.append("[color=#aaaaaa]Goal: %s[/color]" % goal)
	var steps: Array = spec.get("steps", [])
	if not steps.is_empty():
		parts.append("[color=#cccccc]Steps:[/color]")
		for i in steps.size():
			parts.append("  [color=#88ddaa]%d.[/color] %s" % [i + 1, str(steps[i])])
	var hints: Array = spec.get("hints", [])
	if not hints.is_empty():
		parts.append("[color=#cccccc]Hints:[/color]")
		for h in hints:
			parts.append("  [color=#ffcc66]•[/color] %s" % str(h))
	var snippet := str(spec.get("snippet", ""))
	if not snippet.is_empty():
		parts.append("[color=#cccccc]Code:[/color]")
		parts.append("[bgcolor=#1a1a22][code]%s[/code][/bgcolor]" % snippet)
	parts.append("")
	return "\n".join(parts)


## No file-system side effects \u2014 returns an empty plan because
## lessons are display-only.  Provided so the AI panel can treat lesson
## specs uniformly with the other spec types.
func plan(_spec: Dictionary, _safe_writer: Object) -> Array:
	return []


## Apply = print the lesson into the AI panel.  Returns a dict shaped
## like the other spec results so the panel reuses _print_apply_result.
func apply(spec: Dictionary, _safe_writer: Object, _strict: bool = false) -> Dictionary:
	return {
		"ok": not spec.is_empty(),
		"written": [],
		"skipped": [],
		"lint": [],
		"summary": describe(spec),
		"bbcode": render_bbcode(spec),
	}
