@tool
extends RefCounted
## Narcea — VG-native context provider.
##
## Narcea is the only persona that *changes the prompt's content* (not just
## its style).  Other personas wrap a shared SYSTEM_PROMPT in a roleplay
## prefix; Narcea additionally injects:
##
##   1. A snapshot of what the user is doing right now (active panel, open
##      file path/kind, current selection if any).
##   2. VG-domain knowledge baked in — control catalog, AGCK actor types,
##      Working Nodes triggers, common gotchas.  These are facts the model
##      cannot reliably know without help.
##   3. An index of tutorials / examples / corpus filenames so the model
##      can cite the right one when the user asks "how do I X?".
##
## Loaded on demand from vg_ai_help.gd._get_active_system_prompt() when
## the active persona id == "narcea".  Cached for the lifetime of the
## panel; cheap to rebuild (~1 ms) but the tutorial walk only happens once.
##
## See /memories/repo/visualgasic_todo.md for the longer design note.

const TUTORIALS_DIR := "res://tutorials"
const CORPUS_DIR := "res://corpus"
const EXAMPLES_DIR := "res://examples"
const DEMOS_DIR := "res://demos"

# Built-in knowledge — kept terse on purpose so it doesn't blow up token
# budgets on smaller local models (Qwen 1.5B has ~8 k context).
const KNOWLEDGE := """
=== VG control catalog (Form Designer) ===
Common controls + their primary event in VB6/VG names:
  CommandButton (Click)         OptionButton (Click)
  TextBox       (Change)        ComboBox      (Click / Change)
  Label         (Click)         ListBox       (Click / DblClick)
  CheckBox      (Click)         Timer         (Timer)
  PictureBox    (Click)         Image         (Click)
  Frame, GroupBox               HScroll/VScroll (Change)
VG aliases for properties on every control:
  Caption  -> .text                Visible  -> .visible
  Left     -> .position.x          Top      -> .position.y
  Width    -> .size.x              Height   -> .size.y
  Enabled  -> .editable / .disabled (varies by node)
Event handlers auto-wire by name: Sub btnOK_Click(), Sub Timer1_Timer(),
Sub Form_Load(), Sub Form_KeyDown(KeyCode As Integer, Shift As Integer).
Manual wiring: ConnectSignal "signal_name", "HandlerName".

=== AGCK actor types ===
Each actor has a Movement card; Runner/Player also expose advanced physics.
  Player  - 4-directional or platformer; .jump_velocity (default -400)
  Runner  - auto-running rotator (Geometry-Dash style);
            .rotation_speed=9 rad/s, .snap_angle_deg=90, .jump_force literal
  Drone   - patrols waypoints; .speed, .turn_rate
  Pickup  - collectible; emits collected signal
  Hazard  - damages on contact
  Goal    - level completion trigger
  NPC     - dialog-driven; .dialog_lines[]
Templates: platformer (complete); top-down RPG, shmup, puzzle, arcade,
endless runner are planned (see TODO).
Hard-coded behaviours live in agck_builder_backend.gd around line 691
(atype dispatch); promote literals to actor data fields when extending.

=== Working Nodes triggers (GD-style) ===
  Event(Ready)        - fires once on scene start
  Event(Input)        - on key/mouse
  Move                - tween position over time, group-targeted
  ColorTrigger        - tween modulate over time
  Wait                - delay (TODO: Await SceneTree.create_timer().timeout)
  Spawn               - instantiate prefab (TODO: delay support)
  Animate             - run AnimationPlayer track (TODO: auto-attach AP child)
  Conditional         - branch on group/value
Every trigger has a 'group' int input — multiple targets share a group ID.

=== Common VG gotchas ===
  * Forms persist in user:// — re-import after editing the .frm file or
    the IDE keeps showing the old layout.
  * Working Nodes "Animate" needs an AnimationPlayer child; the runtime
    can't auto-attach one yet (open TODO in wn_runtime.vg).
  * VGComboBox != ComboBox — the VG-prefixed prototypes live under
    addons/visual_gasic/prototypes/ and have extra signals/methods.
  * String concat is &, not +.  + on strings will silently fail or
    coerce in surprising ways.
  * GetNode(\"name\") returns null if the node hasn't been added to the
    tree yet — guard with If Not GetNode(...) Is Nothing Then ... End If.
  * Sub btnFoo_Click runs on the editor's main thread.  Long work blocks
    the IDE; use a Task or Timer for anything > 50 ms.
  * Don't edit canonical addons/ files inside game_projects/ symlinks —
    they all point at addons/visual_gasic/.  scripts/sync_addons.sh
    check verifies this in CI.

=== Useful idioms ===
  ' On-screen debug
  MsgBox \"value=\" & x

  ' Defer work to next frame
  CallDeferred \"_apply_changes\"

  ' Scene-tree query
  Dim node As Node = GetTree.GetRoot.GetNode(\"path/to/node\")

  ' Persistent settings (per project)
  Dim cfg As ConfigFile = New ConfigFile()
  cfg.Load(\"user://settings.cfg\")

=== Form-spec output (Build-form button) ===
When the user asks you to design or lay out a form / dialog / UI, ALSO
emit a fenced block tagged `vg-form-spec` containing JSON that the IDE
can feed straight into the Form Designer.  Put it AFTER your normal
explanation so the prose still reads naturally; the IDE strips the spec
out before speaking the reply aloud.

Schema:
  {
    \"form_name\": \"<safe identifier>\",
    \"form_size\": [width, height],          // optional, integers
    \"controls\": [
      {
        \"type\":   \"<one of: Button, Label, LineEdit, TextEdit, CheckBox,
                     OptionButton, ItemList, Panel, PanelContainer,
                     ColorRect, TextureRect, ProgressBar, HSlider, VSlider,
                     SpinBox, Timer>\",
        \"name\":   \"<identifier, e.g. btnOK>\",
        \"left\":   <int>, \"top\": <int>,
        \"width\":  <int>, \"height\": <int>,
        \"text\":   \"<caption / button label>\",         // optional
        \"items\":  [\"row1\", \"row2\"]                   // ItemList / OptionButton
      }
    ]
  }

Example block (fenced exactly as below):

  ```vg-form-spec
  {
    \"form_name\": \"frmLogin\",
    \"form_size\": [280, 160],
    \"controls\": [
      {\"type\": \"Label\",    \"name\": \"lblUser\", \"left\": 10, \"top\": 12,
       \"width\": 70, \"height\": 20, \"text\": \"User:\"},
      {\"type\": \"LineEdit\", \"name\": \"txtUser\", \"left\": 90, \"top\": 10,
       \"width\": 170, \"height\": 24},
      {\"type\": \"Button\",   \"name\": \"btnOK\",   \"left\": 100, \"top\": 110,
       \"width\": 75, \"height\": 28, \"text\": \"OK\"}
    ]
  }
  ```

Rules:
  * Map VB6 control names to the Godot type list above (CommandButton -> Button,
    TextBox -> LineEdit / TextEdit, ComboBox -> OptionButton, ListBox -> ItemList).
  * Use VB6-style coordinates (Left/Top/Width/Height) in pixels, integers only.
  * Only include the `vg-form-spec` block when the user actually wants a form
    built; for code-only or general questions, skip it.
  * Keep the JSON valid \u2014 no trailing commas, no comments inside the block.
"""

# Cached state -------------------------------------------------------------
var _tutorial_index: Array = []  # [{path, title}]
var _indexed_once := false


# --- Public API ------------------------------------------------------------

## Build the Narcea-specific system-prompt block.
## `plugin` is the visual_gasic_plugin instance (may be null in headless tests).
func build_context_block(plugin: Object = null) -> String:
	var blocks: Array[String] = []
	var active := _active_context_block(plugin)
	if not active.is_empty():
		blocks.append(active)
	blocks.append(KNOWLEDGE)
	var tut := _tutorial_block()
	if not tut.is_empty():
		blocks.append(tut)
	# Closing nudge — what Narcea should DO with the context above.
	blocks.append("""
=== Narcea response policy ===
You are Narcea — a VG-native pair programmer.  Use the active-context
block above to tailor every reply.  When the user asks a 'how do I'
question, cite the matching tutorial filename inline (e.g. 'see
tutorials/tilemap_tutorial.vg').  Suggest the next obvious step
proactively but in ONE short closing sentence.  Never invent VG
syntax — if unsure, say so and recommend an example file from corpus/
or demos/.
""")
	return "\n".join(blocks)


# --- Active-context probe --------------------------------------------------

## What's the user looking at right now?  Returns a short block describing
## panel + open file + selection.  Empty string if nothing useful is
## reachable (e.g. Narcea opened in headless / test mode).
func _active_context_block(plugin: Object) -> String:
	var lines: Array[String] = []
	lines.append("=== ACTIVE CONTEXT (right now) ===")

	var panel := _detect_active_panel(plugin)
	if not panel.is_empty():
		lines.append("Active panel: %s" % panel)

	var open := _detect_open_file(plugin)
	if not open.is_empty():
		lines.append("Open file: %s" % open)

	var sel := _detect_selection(plugin)
	if not sel.is_empty():
		lines.append("Selection: %s" % sel)

	# Only emit the block if we found at least one signal beyond the header.
	if lines.size() <= 1:
		return ""
	return "\n".join(lines)


func _detect_active_panel(plugin: Object) -> String:
	if plugin == null or not is_instance_valid(plugin):
		return ""
	# The plugin tracks which IDE sub-panel was last shown.  Several
	# different vars expose this depending on which screen is active;
	# probe a few in priority order.  All are best-effort — if none
	# match we just return "".
	for prop in ["_active_panel", "_current_screen", "_last_focused_panel"]:
		if prop in plugin:
			var v = plugin.get(prop)
			if typeof(v) == TYPE_STRING and not v.is_empty():
				return v
	# Fall back to "are the big panels visible?"
	if "_form_designer" in plugin and plugin.get("_form_designer") != null \
			and is_instance_valid(plugin.get("_form_designer")) \
			and plugin.get("_form_designer").visible:
		return "Form Designer"
	if "_embedded_code_editor" in plugin and plugin.get("_embedded_code_editor") != null \
			and is_instance_valid(plugin.get("_embedded_code_editor")) \
			and plugin.get("_embedded_code_editor").visible:
		return "Code Editor"
	return ""


func _detect_open_file(plugin: Object) -> String:
	if plugin == null or not is_instance_valid(plugin):
		return ""
	# Most embedded editors expose `current_file` or `_current_path`.
	if "_embedded_code_editor" in plugin:
		var ece = plugin.get("_embedded_code_editor")
		if ece != null and is_instance_valid(ece):
			for prop in ["current_file", "_current_path", "current_path"]:
				if prop in ece:
					var v = ece.get(prop)
					if typeof(v) == TYPE_STRING and not v.is_empty():
						return _summarise_path(v)
	# Form designer's currently-edited form.
	if "_form_designer" in plugin:
		var fd = plugin.get("_form_designer")
		if fd != null and is_instance_valid(fd):
			for prop in ["current_form_path", "_form_path", "form_name"]:
				if prop in fd:
					var v = fd.get(prop)
					if typeof(v) == TYPE_STRING and not v.is_empty():
						return _summarise_path(v)
	return ""


func _detect_selection(plugin: Object) -> String:
	if plugin == null or not is_instance_valid(plugin):
		return ""
	# Form Designer selection.
	if "_form_designer" in plugin:
		var fd = plugin.get("_form_designer")
		if fd != null and is_instance_valid(fd) and fd.has_method("get_selected_controls"):
			var sel = fd.get_selected_controls()
			if typeof(sel) == TYPE_ARRAY and not sel.is_empty():
				var names: Array[String] = []
				for s in sel:
					if s != null and is_instance_valid(s):
						names.append("%s (%s)" % [s.name, s.get_class()])
				if not names.is_empty():
					return "Form Designer controls: " + ", ".join(names)
	return ""


func _summarise_path(p: String) -> String:
	# Keep paths short — strip res:// and any leading project-data prefixes.
	var s := p
	if s.begins_with("res://"):
		s = s.substr(6)
	# Best-effort file kind tag.
	var kind := ""
	var lower := s.to_lower()
	if lower.ends_with(".vg"):
		kind = " [VG module]"
	elif lower.ends_with(".frm"):
		kind = " [Form]"
	elif lower.ends_with(".agck"):
		kind = " [AGCK game definition]"
	elif lower.ends_with(".wnodes"):
		kind = " [Working Nodes graph]"
	elif lower.ends_with(".gd"):
		kind = " [GDScript]"
	return s + kind


# --- Tutorial / corpus index ----------------------------------------------

func _tutorial_block() -> String:
	if not _indexed_once:
		_index_tutorials()
		_indexed_once = true
	if _tutorial_index.is_empty():
		return ""
	var lines: Array[String] = ["=== Tutorials & examples available ==="]
	for entry in _tutorial_index:
		lines.append("  %s — %s" % [entry["path"], entry["title"]])
	lines.append("Cite the matching path inline when answering 'how do I' questions.")
	return "\n".join(lines)


func _index_tutorials() -> void:
	_tutorial_index.clear()
	# Tutorials are first-class — index ALL of them.
	_walk_for_index(TUTORIALS_DIR, _tutorial_index, 50)
	# Corpus / demos / examples are huge; only sample the top-level
	# directories so we don't blow the prompt budget.
	_index_top_level(CORPUS_DIR, _tutorial_index, 25)
	_index_top_level(DEMOS_DIR, _tutorial_index, 15)


func _walk_for_index(dir_path: String, into: Array, budget: int) -> void:
	if budget <= 0:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_walk_for_index(full, into, budget - into.size())
		elif name.ends_with(".vg") or name.ends_with(".md"):
			into.append({"path": full.replace("res://", ""), "title": _read_title_hint(full, name)})
			if into.size() >= budget:
				break
	d.list_dir_end()


func _index_top_level(dir_path: String, into: Array, budget: int) -> void:
	# Only include the immediate children (folders or .vg files) — gives
	# the model a hint without dumping every demo.
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var added := 0
	while added < budget:
		var name := d.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var full := dir_path.path_join(name)
		var label := name
		if d.current_is_dir():
			# Look for README.md inside for a one-line description.
			var readme := full.path_join("README.md")
			if FileAccess.file_exists(readme):
				label = name + " — " + _read_title_hint(readme, name)
			into.append({"path": full.replace("res://", "") + "/", "title": label})
			added += 1
		elif name.ends_with(".vg") or name.ends_with(".md"):
			into.append({"path": full.replace("res://", ""), "title": _read_title_hint(full, name)})
			added += 1
	d.list_dir_end()


func _read_title_hint(path: String, fallback: String) -> String:
	# Reads up to the first non-empty heading or comment line so we have
	# a one-line summary without parsing the whole file.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback
	var read_count := 0
	while not f.eof_reached() and read_count < 20:
		var line := f.get_line().strip_edges()
		read_count += 1
		if line.is_empty():
			continue
		# Markdown heading
		if line.begins_with("# "):
			f.close()
			return line.substr(2).strip_edges()
		# VG comment header
		if line.begins_with("'") or line.begins_with("' "):
			var s := line.lstrip("' ").strip_edges()
			if not s.is_empty():
				f.close()
				return s
		# Stop at first real code line if we found nothing useful
		if not line.begins_with("'") and not line.begins_with("#"):
			break
	f.close()
	return fallback
