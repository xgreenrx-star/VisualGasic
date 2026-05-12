@tool
extends VBoxContainer

const TYPE_EVENT  := "event"
const TYPE_ACTION := "action"
const TYPE_MATH   := "math"

# ─── Trigger / action node kinds ────────────────────────────────────────────
# Each is a dedicated node with typed ports (execution + per-parameter value).
const TYPE_ON_START     := "on_start"
const TYPE_MOVE         := "move"
const TYPE_ROTATE       := "rotate"
const TYPE_SCALE        := "scale"
const TYPE_ALPHA        := "alpha"
const TYPE_COLOR_TRIG   := "color_trigger"
const TYPE_PULSE        := "pulse"
const TYPE_SPAWN        := "spawn"
const TYPE_STOP         := "stop"
const TYPE_TOGGLE       := "toggle"
const TYPE_FOLLOW       := "follow"
const TYPE_SHAKE        := "shake"
const TYPE_PLAY_SFX     := "play_sfx"
const TYPE_ANIMATE      := "animate"
# ─── GD-equivalent extended node types ───────────────────────────────────────
const TYPE_ON_FRAME     := "on_frame"
const TYPE_ON_INPUT     := "on_input"
const TYPE_ON_COLLISION := "on_collision"
const TYPE_COUNTER      := "counter"
const TYPE_RANDOM_TRIG  := "random_trig"
const TYPE_BRANCH       := "branch"
const TYPE_CMP_TRIG     := "cmp_trig"
const TYPE_TIMER        := "timer"
const TYPE_SEQUENCE     := "sequence"
const TYPE_ZOOM         := "zoom"
const TYPE_CAMERA_MOVE  := "camera_move"
const TYPE_GET_PROP     := "get_prop"
const TYPE_SET_PROP     := "set_prop"
const TYPE_INPUT_POLL   := "input_poll"
const TYPE_EXPR         := "expr"
const TYPE_DELTA_VAR    := "delta_var"

# Port-type indices (shared between editor and overlay)
const PORT_EXEC  := 0   # execution-flow port  — green
const PORT_VALUE := 1   # data / value port    — orange-yellow

# Port colors used when building trigger node slots
const EXEC_PORT_COLOR  := Color(0.30, 1.00, 0.50)
const VALUE_PORT_COLOR := Color(1.00, 0.80, 0.25)

# ─── Data-driven trigger node definitions ────────────────────────────────────
# Each entry: { title, icon, color_hex, exec_in, exec_out, params: [[label, default], …] }
const _GD_TRIGGERS: Dictionary = {
	"on_start": {
		"title": "On Start",  "icon": "▶",
		"color_hex": "30e870", "exec_in": false, "exec_out": true,
		"params": []
	},
	"move": {
		"title": "Move",      "icon": "↔",
		"color_hex": "4a90e0", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["X","0"],["Y","0"],["Duration","0.5"],["Easing","0"]]
	},
	"rotate": {
		"title": "Rotate",    "icon": "↻",
		"color_hex": "5bc8e8", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Degrees","90"],["Duration","0.5"],["Lock Rot","0"]]
	},
	"scale": {
		"title": "Scale",     "icon": "⤡",
		"color_hex": "8060e0", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Scale X","1"],["Scale Y","1"],["Duration","0.5"]]
	},
	"alpha": {
		"title": "Alpha",     "icon": "◑",
		"color_hex": "c8a030", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Alpha","1.0"],["Duration","0.5"]]
	},
	"color_trigger": {
		"title": "Color",     "icon": "🎨",
		"color_hex": "e07850", "exec_in": true,  "exec_out": true,
		"params": [["Channel","1"],["R","255"],["G","255"],["B","255"],["Duration","0.5"]]
	},
	"pulse": {
		"title": "Pulse",     "icon": "💢",
		"color_hex": "e050b0", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["R","255"],["G","100"],["B","100"],
		           ["Fade In","0.2"],["Hold","0.5"],["Fade Out","0.2"]]
	},
	"spawn": {
		"title": "Spawn",     "icon": "✦",
		"color_hex": "50c870", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Delay","0"]]
	},
	"stop": {
		"title": "Stop",      "icon": "◼",
		"color_hex": "e05050", "exec_in": true,  "exec_out": false,
		"params": [["Group ID","1"]]
	},
	"toggle": {
		"title": "Toggle",    "icon": "👁",
		"color_hex": "b0b020", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Active","1"]]
	},
	"follow": {
		"title": "Follow",    "icon": "⟿",
		"color_hex": "70c8b8", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Target Group","2"],
		           ["X Mod","1"],["Y Mod","1"],["Duration","1.0"]]
	},
	"shake": {
		"title": "Shake",     "icon": "⚡",
		"color_hex": "e0c030", "exec_in": true,  "exec_out": true,
		"params": [["Strength","1"],["Interval","0.1"],["Duration","0.5"]]
	},
	"play_sfx": {
		"title": "Play SFX",  "icon": "♪",
		"color_hex": "9060d0", "exec_in": true,  "exec_out": true,
		"params": [["Sound",""],["Volume","1"],["Pitch","1"]]
	},
	"animate": {
		"title": "Animate",   "icon": "▷",
		"color_hex": "60a880", "exec_in": true,  "exec_out": true,
		"params": [["Group ID","1"],["Animation","0"],["Speed","1"]]
	},
	# ── Entry / Event nodes ──────────────────────────────────────────────────
	"on_frame": {
		"title": "On Frame",     "icon": "⏱",
		"color_hex": "20d060", "exec_in": false, "exec_out": true,
		"params": []
	},
	"on_input": {
		"title": "On Input",     "icon": "🎮",
		"color_hex": "e06090", "exec_in": false, "exec_out": true,
		"params": [["Key","space"],["Mode","pressed"]]
	},
	"on_collision": {
		"title": "On Collision", "icon": "💥",
		"color_hex": "e07830", "exec_in": false, "exec_out": true,
		"params": [["Group ID","1"],["Target Group","2"]]
	},
	# ── Data / Variable nodes ─────────────────────────────────────────────────
	"counter": {
		"title": "Counter",      "icon": "🔢",
		"color_hex": "4878c8", "exec_in": true,  "exec_out": true,
		"params": [["Name","score"],["Op","+="],["Value","1"]]
	},
	"random_trig": {
		"title": "Random",       "icon": "🎲",
		"color_hex": "30b8b8", "exec_in": true,  "exec_out": true,
		"params": [["Min","0"],["Max","100"],["Store To","score"]]
	},
	# ── Flow / Logic nodes ───────────────────────────────────────────────────
	"branch": {
		"title": "Branch",       "icon": "⎇",
		"color_hex": "c8a020", "exec_in": true,  "exec_out": true,  "else_out": true,
		"params": [["Counter","score"],["Op",">="],["Value","0"]]
	},
	"cmp_trig": {
		"title": "Compare",      "icon": "≤",
		"color_hex": "c87020", "exec_in": true,  "exec_out": true,  "else_out": true,
		"params": [["A","score"],["Op",">"],["B","0"]]
	},
	"timer": {
		"title": "Timer",        "icon": "⏳",
		"color_hex": "9050d0", "exec_in": true,  "exec_out": true,
		"params": [["Delay","1.0"],["Repeat","0"]]
	},
	"sequence": {
		"title": "Sequence",     "icon": "⏩",
		"color_hex": "b050c8", "exec_in": true,  "exec_out": true,
		"params": [["Interval","0.0"],["Repeat","0"]]
	},
	# ── Camera nodes ─────────────────────────────────────────────────────────
	"zoom": {
		"title": "Zoom",         "icon": "🔍",
		"color_hex": "6090b0", "exec_in": true,  "exec_out": true,
		"params": [["Zoom","1.0"],["Duration","0.5"]]
	},
	"camera_move": {
		"title": "Camera Move",  "icon": "🎥",
		"color_hex": "5080a0", "exec_in": true,  "exec_out": true,
		"params": [["Target Group","1"],["Duration","1.0"],["X Offset","0"],["Y Offset","0"]]
	},
	"get_prop": {
		"title": "Get Property", "icon": "📥",
		"color_hex": "409060", "exec_in": true,  "exec_out": true,
		"params": [["Node Path","Player"],["Property","position.x"],["Store To","posX"]]
	},
	"set_prop": {
		"title": "Set Property", "icon": "📤",
		"color_hex": "207040", "exec_in": true,  "exec_out": true,
		"params": [["Node Path","Player"],["Property","position.x"],["Value","0"]]
	},
	"input_poll": {
		"title": "Input Poll",   "icon": "🕹",
		"color_hex": "d04090", "exec_in": true,  "exec_out": true,  "else_out": true,
		"params": [["Action","move_right"],["Mode","pressed"]]
	},
	"expr": {
		"title": "Expression",   "icon": "ƒ",
		"color_hex": "3080c0", "exec_in": true,  "exec_out": true,
		"params": [["Store To","result"],["Expression","value + 10"]]
	},
	"delta_var": {
		"title": "Delta Var",    "icon": "Δ",
		"color_hex": "c06020", "exec_in": true,  "exec_out": true,
		"params": [["Var","velY"],["Op","+="],["Rate","980"]]
	},
}

signal export_vg_requested(data: Dictionary)
signal export_scene_2d_requested(data: Dictionary)
signal export_scene_3d_requested(data: Dictionary)
signal run_graph_requested(data: Dictionary, is_3d: bool)

var _graph: GraphEdit
var _overlay: Control

var _show_all_wires: CheckButton
var _smart_routing: CheckButton
var _group_filter: OptionButton
var _group_selector: ItemList
var _node_color_picker: ColorPickerButton

var _save_dialog: FileDialog
var _load_dialog: FileDialog

var _nodes: Dictionary = {}
var _connections: Array = [] # {from, from_port, to, to_port, color, group}
var _groups: Dictionary = {} # int -> {name, color}
var _next_node_id: int = 1
var _next_group_id: int = 1
var _last_path: String = "res://working_nodes_project.wnodes"
var _initialized: bool = false

# Right-mouse panning state
var _panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_scroll: Vector2 = Vector2.ZERO
var _rclick_press_pos: Vector2 = Vector2.ZERO

# Canvas right-click context menu
var _canvas_context_menu: PopupMenu = null

# ─ Live VG preview ───────────────────────────────────────────────
var _preview_panel: PanelContainer = null
var _preview_code: CodeEdit = null
var _preview_visible: bool = false

# ─ Shift+A node palette ───────────────────────────────────────
var _palette_popup: Window = null
var _palette_search: LineEdit = null
var _palette_list: ItemList = null
var _palette_pos: Vector2 = Vector2.ZERO

# ─ Copy / paste clipboard ─────────────────────────────────────
var _clipboard_data: String = ""

# ─ Snippets ───────────────────────────────────────────────────────
var _snippets: Dictionary = {}  # name -> {nodes, connections}
var _snippets_path: String = "user://wn_snippets.json"
var _snippet_popup: Window = null
var _snippet_name_edit: LineEdit = null

# ─ Breakpoints ──────────────────────────────────────────────────
var _breakpoints: Dictionary = {}  # node_name -> bool
var _node_context_menu: PopupMenu = null
var _ctx_target_node: GraphNode = null

# ─ Validator ────────────────────────────────────────────────────
var _validator_popup: AcceptDialog = null

func _ready() -> void:
	_ensure_initialized()

func _enter_tree() -> void:
	_ensure_initialized()


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	name = "WorkingNodesEditor"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_new_graph()

func _build_ui() -> void:
	var top_banner := PanelContainer.new()
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.14, 0.19, 0.30, 0.95)
	banner_style.set_corner_radius_all(4)
	top_banner.add_theme_stylebox_override("panel", banner_style)
	var banner_row := HBoxContainer.new()
	var banner_label := Label.new()
	banner_label.text = "Working Nodes"
	banner_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	banner_label.add_theme_font_size_override("font_size", 14)
	banner_row.add_child(banner_label)
	top_banner.add_child(banner_row)
	add_child(top_banner)

	# ─ Toolbar row 1: File + Export + Add nodes ──────────────────────────
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)

	var btn_new := Button.new()
	btn_new.text = "New"
	btn_new.tooltip_text = "Clear the canvas and start a fresh graph"
	btn_new.pressed.connect(_new_graph)
	toolbar.add_child(btn_new)

	var btn_save := Button.new()
	btn_save.text = "Save"
	btn_save.tooltip_text = "Save the graph to its current .wnodes file"
	btn_save.pressed.connect(_save_current)
	toolbar.add_child(btn_save)

	var btn_save_as := Button.new()
	btn_save_as.text = "Save As"
	btn_save_as.tooltip_text = "Save the graph to a new .wnodes file"
	btn_save_as.pressed.connect(_show_save_dialog)
	toolbar.add_child(btn_save_as)

	var btn_load := Button.new()
	btn_load.text = "Load"
	btn_load.tooltip_text = "Open an existing .wnodes graph"
	btn_load.pressed.connect(_show_load_dialog)
	toolbar.add_child(btn_load)

	toolbar.add_child(VSeparator.new())

	var btn_export_vg := Button.new()
	btn_export_vg.text = "▶ Export VG"
	btn_export_vg.tooltip_text = "Generate VG code from this graph and save as a .vg file"
	btn_export_vg.pressed.connect(_on_export_vg_pressed)
	toolbar.add_child(btn_export_vg)

	var btn_export_2d := Button.new()
	btn_export_2d.text = "⬡ 2D Scene"
	btn_export_2d.tooltip_text = "Generate a Godot 2D .tscn scene + companion .vg script"
	btn_export_2d.pressed.connect(_on_export_scene_2d_pressed)
	toolbar.add_child(btn_export_2d)

	var btn_export_3d := Button.new()
	btn_export_3d.text = "◈ 3D Scene"
	btn_export_3d.tooltip_text = "Generate a Godot 3D .tscn scene + companion .vg script"
	btn_export_3d.pressed.connect(_on_export_scene_3d_pressed)
	toolbar.add_child(btn_export_3d)

	var btn_run_2d := Button.new()
	btn_run_2d.text = "▶ Run 2D"
	btn_run_2d.tooltip_text = "Generate 2D scene + VG + copy runtime, then launch"
	btn_run_2d.pressed.connect(_on_run_graph_2d_pressed)
	toolbar.add_child(btn_run_2d)

	var btn_run_3d := Button.new()
	btn_run_3d.text = "▶ Run 3D"
	btn_run_3d.tooltip_text = "Generate 3D scene + VG + copy runtime, then launch"
	btn_run_3d.pressed.connect(_on_run_graph_3d_pressed)
	toolbar.add_child(btn_run_3d)

	toolbar.add_child(VSeparator.new())

	var btn_event := Button.new()
	btn_event.text = "+ Event"
	btn_event.tooltip_text = "Add an Event node (graph entry point, e.g. Ready / Input / Timer)"
	btn_event.pressed.connect(func(): _add_node(TYPE_EVENT))
	toolbar.add_child(btn_event)

	var btn_action := Button.new()
	btn_action.text = "+ Action"
	btn_action.tooltip_text = "Add an Action node (do something — print, set property, call sub, etc.)"
	btn_action.pressed.connect(func(): _add_node(TYPE_ACTION))
	toolbar.add_child(btn_action)

	var btn_math := Button.new()
	btn_math.text = "+ Math"
	btn_math.tooltip_text = "Add a Math node (arithmetic / comparison feeding other nodes)"
	btn_math.pressed.connect(func(): _add_node(TYPE_MATH))
	toolbar.add_child(btn_math)

	# ─ Toolbar row 1b: Trigger node shortcuts ───────────────────────────────────
	var toolbar_gd := HBoxContainer.new()
	toolbar_gd.add_theme_constant_override("separation", 4)
	add_child(toolbar_gd)
	var gd_lbl := Label.new()
	gd_lbl.text = "Triggers:"
	gd_lbl.add_theme_color_override("font_color", Color(0.50, 0.90, 0.50))
	toolbar_gd.add_child(gd_lbl)
	for _gd_k: String in ["on_start", "move", "rotate", "scale", "alpha",
	              "color_trigger", "spawn", "stop", "toggle", "play_sfx",
	              "follow", "shake", "pulse", "animate"]:
		var _d: Dictionary = _GD_TRIGGERS.get(_gd_k, {})
		var _gbtn := Button.new()
		_gbtn.text = "%s %s" % [_d.get("icon", "\u2699"), _d.get("title", _gd_k)]
		_gbtn.tooltip_text = "Add %s node  (also in Shift+A palette)" % _d.get("title", _gd_k)
		var _capture: String = _gd_k
		_gbtn.pressed.connect(func(): _add_node(_capture))
		toolbar_gd.add_child(_gbtn)

	# ─ Toolbar row 2: Groups + View controls ─────────────────────────────
	var toolbar_mid := HBoxContainer.new()
	toolbar_mid.add_theme_constant_override("separation", 6)
	add_child(toolbar_mid)

	var btn_connect := Button.new()
	btn_connect.text = "Connect"
	btn_connect.tooltip_text = "Connect selected nodes left-to-right"
	btn_connect.pressed.connect(_smart_connect_selected)
	toolbar_mid.add_child(btn_connect)

	toolbar_mid.add_child(VSeparator.new())

	var btn_group := Button.new()
	btn_group.text = "+ Group"
	btn_group.tooltip_text = "Create a new Group from the currently selected nodes"
	btn_group.pressed.connect(_create_group_from_selection)
	toolbar_mid.add_child(btn_group)

	var btn_assign := Button.new()
	btn_assign.text = "Assign Group"
	btn_assign.tooltip_text = "Add the selected nodes to the currently active Group(s)"
	btn_assign.pressed.connect(_assign_selected_nodes_to_active_groups)
	toolbar_mid.add_child(btn_assign)

	toolbar_mid.add_child(VSeparator.new())

	_show_all_wires = CheckButton.new()
	_show_all_wires.text = "All wires"
	_show_all_wires.toggled.connect(func(_v): _queue_wire_redraw())
	toolbar_mid.add_child(_show_all_wires)

	_smart_routing = CheckButton.new()
	_smart_routing.text = "Smart wiring"
	_smart_routing.button_pressed = true
	_smart_routing.toggled.connect(func(_v): _queue_wire_redraw())
	toolbar_mid.add_child(_smart_routing)

	toolbar_mid.add_child(VSeparator.new())

	var wire_label := Label.new()
	wire_label.text = "Wire Group:"
	toolbar_mid.add_child(wire_label)

	_group_filter = OptionButton.new()
	_group_filter.custom_minimum_size = Vector2(140, 0)
	_group_filter.item_selected.connect(func(_i): _queue_wire_redraw())
	toolbar_mid.add_child(_group_filter)

	toolbar_mid.add_child(VSeparator.new())

	var color_label := Label.new()
	color_label.text = "Node Color:"
	toolbar_mid.add_child(color_label)

	_node_color_picker = ColorPickerButton.new()
	_node_color_picker.custom_minimum_size = Vector2(32, 0)
	_node_color_picker.color_changed.connect(_on_node_color_changed)
	toolbar_mid.add_child(_node_color_picker)

	# ─ Toolbar row 3: editor utilities ────────────────────────────────
	var toolbar2 := HBoxContainer.new()
	toolbar2.add_theme_constant_override("separation", 4)
	add_child(toolbar2)

	var btn_preview := Button.new()
	btn_preview.text = "◐ Preview"
	btn_preview.toggle_mode = true
	btn_preview.tooltip_text = "Toggle live VG code preview  (auto-updates on graph changes)"
	btn_preview.toggled.connect(_on_preview_toggled)
	toolbar2.add_child(btn_preview)

	var btn_validate := Button.new()
	btn_validate.text = "✓ Validate"
	btn_validate.tooltip_text = "Scan graph for issues before export"
	btn_validate.pressed.connect(_validate_graph)
	toolbar2.add_child(btn_validate)

	var btn_joints := Button.new()
	btn_joints.text = "✚ Joints"
	btn_joints.toggle_mode = true
	btn_joints.tooltip_text = "Wire-joint edit mode — click a wire to add a joint, drag to reposition, right-click to remove"
	btn_joints.toggled.connect(_on_joint_mode_toggled)
	toolbar2.add_child(btn_joints)

	toolbar2.add_child(VSeparator.new())

	var btn_del := Button.new()
	btn_del.text = "🗑 Del"
	btn_del.tooltip_text = "Delete selected nodes  (Delete key)"
	btn_del.pressed.connect(_delete_selected_nodes)
	toolbar2.add_child(btn_del)

	toolbar2.add_child(VSeparator.new())

	var btn_copy := Button.new()
	btn_copy.text = "⧉ Copy"
	btn_copy.tooltip_text = "Copy selected nodes to clipboard  (Ctrl+C)"
	btn_copy.pressed.connect(_copy_selection)
	toolbar2.add_child(btn_copy)

	var btn_paste := Button.new()
	btn_paste.text = "⬡ Paste"
	btn_paste.tooltip_text = "Paste nodes from clipboard  (Ctrl+V)"
	btn_paste.pressed.connect(_paste_selection)
	toolbar2.add_child(btn_paste)

	toolbar2.add_child(VSeparator.new())

	var btn_save_snip := Button.new()
	btn_save_snip.text = "📌 Snippet"
	btn_save_snip.tooltip_text = "Save selected nodes as a reusable snippet"
	btn_save_snip.pressed.connect(_save_snippet)
	toolbar2.add_child(btn_save_snip)

	var btn_load_snip := Button.new()
	btn_load_snip.text = "📋 Snippets…"
	btn_load_snip.tooltip_text = "Insert a saved snippet into the graph"
	btn_load_snip.pressed.connect(_open_snippet_popup)
	toolbar2.add_child(btn_load_snip)

	toolbar2.add_child(VSeparator.new())

	var palette_hint := Label.new()
	palette_hint.text = "Shift+A → palette"
	palette_hint.add_theme_color_override("font_color", Color(0.60, 0.75, 0.50))
	toolbar2.add_child(palette_hint)

	toolbar2.add_child(VSeparator.new())

	var btn_help := Button.new()
	btn_help.text = "📖 Help"
	btn_help.tooltip_text = "Open the Working Nodes manual"
	btn_help.pressed.connect(_open_manual)
	toolbar2.add_child(btn_help)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(220, 200)
	side.add_theme_constant_override("separation", 4)
	body.add_child(side)

	var groups_label := Label.new()
	groups_label.text = "Selected Groups"
	side.add_child(groups_label)

	_group_selector = ItemList.new()
	_group_selector.select_mode = ItemList.SELECT_MULTI
	_group_selector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_group_selector.item_selected.connect(func(_idx): _queue_wire_redraw())
	_group_selector.multi_selected.connect(func(_idx, _selected): _queue_wire_redraw())
	side.add_child(_group_selector)

	var help := RichTextLabel.new()
	help.fit_content = true
	help.bbcode_enabled = true
	help.scroll_active = false
	help.text = "[b]Working Nodes[/b]\n• Trigger/group workflow\n• Math operator nodes\n• Smart wire routing and group filtering"
	side.add_child(help)

	_graph = GraphEdit.new()
	_graph.show_zoom_label = true
	_graph.right_disconnects = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.node_selected.connect(_on_graph_node_selected)
	_graph.delete_nodes_request.connect(_delete_nodes_by_name)

	var right_split := VSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	body.add_child(right_split)
	right_split.add_child(_graph)

	# Live VG preview panel (hidden until toggled)
	_preview_panel = PanelContainer.new()
	_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_panel.custom_minimum_size = Vector2(0, 200)
	_preview_panel.visible = false
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = Color(0.07, 0.08, 0.11)
	_preview_panel.add_theme_stylebox_override("panel", prev_style)
	var prev_v := VBoxContainer.new()
	_preview_panel.add_child(prev_v)
	var prev_hdr := Label.new()
	prev_hdr.text = "  VG Code Preview (live — read-only)"
	prev_hdr.add_theme_color_override("font_color", Color(0.7, 0.9, 0.45))
	prev_v.add_child(prev_hdr)
	_preview_code = CodeEdit.new()
	_preview_code.editable = false
	_preview_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_code.add_theme_font_size_override("font_size", 12)
	_preview_code.scroll_smooth = true
	prev_v.add_child(_preview_code)
	right_split.add_child(_preview_panel)

	# Canvas right-click context menu
	_canvas_context_menu = PopupMenu.new()
	_canvas_context_menu.add_item("▶  On Start",   0)
	_canvas_context_menu.add_item("↔  Move",       1)
	_canvas_context_menu.add_item("↻  Rotate",     2)
	_canvas_context_menu.add_item("⤡  Scale",      3)
	_canvas_context_menu.add_item("◑  Alpha",      4)
	_canvas_context_menu.add_item("🎨  Color",     5)
	_canvas_context_menu.add_item("✦  Spawn",      6)
	_canvas_context_menu.add_item("◼  Stop",       7)
	_canvas_context_menu.add_item("👁  Toggle",    8)
	_canvas_context_menu.add_item("♪  Play SFX",  9)
	_canvas_context_menu.add_item("⟿  Follow",   10)
	_canvas_context_menu.add_item("⚡  Shake",     11)
	_canvas_context_menu.add_item("💢  Pulse",     12)
	_canvas_context_menu.add_item("▷  Animate",   13)
	_canvas_context_menu.add_separator()
	_canvas_context_menu.add_item("⏱  On Frame",     40)
	_canvas_context_menu.add_item("🎮  On Input",     41)
	_canvas_context_menu.add_item("💥  On Collision", 42)
	_canvas_context_menu.add_separator()
	_canvas_context_menu.add_item("🔢  Counter",      43)
	_canvas_context_menu.add_item("🎲  Random",       44)
	_canvas_context_menu.add_item("⎇  Branch",       45)
	_canvas_context_menu.add_item("≤  Compare",      46)
	_canvas_context_menu.add_item("⏳  Timer",        47)
	_canvas_context_menu.add_item("⏩  Sequence",     48)
	_canvas_context_menu.add_item("🔍  Zoom",         49)
	_canvas_context_menu.add_item("🎥  Camera Move",  50)
	_canvas_context_menu.add_separator()
	_canvas_context_menu.add_item("📥  Get Property", 51)
	_canvas_context_menu.add_item("📤  Set Property", 52)
	_canvas_context_menu.add_item("🕹  Input Poll",   53)
	_canvas_context_menu.add_item("ƒ  Expression",    54)
	_canvas_context_menu.add_item("Δ  Delta Var",     55)
	_canvas_context_menu.add_separator()
	_canvas_context_menu.add_item("+ Event",       20)
	_canvas_context_menu.add_item("+ Action",      21)
	_canvas_context_menu.add_item("+ Math",        22)
	_canvas_context_menu.add_separator()
	_canvas_context_menu.add_item("Select All",    30)
	_canvas_context_menu.add_item("Clear Graph",   31)
	_canvas_context_menu.id_pressed.connect(_on_canvas_context_menu_id)
	add_child(_canvas_context_menu)

	# Node right-click context menu
	_node_context_menu = PopupMenu.new()
	_node_context_menu.add_item("Rename",           0)
	_node_context_menu.add_item("Duplicate",        1)
	_node_context_menu.add_separator()
	_node_context_menu.add_item("🔴 Toggle Breakpoint", 2)
	_node_context_menu.add_separator()
	_node_context_menu.add_item("🗑 Delete",          3)
	_node_context_menu.id_pressed.connect(_on_node_context_menu_id)
	add_child(_node_context_menu)

	var overlay_script := load("res://addons/visual_gasic/plugins/working_nodes/working_nodes_wire_overlay.gd")
	_overlay = overlay_script.new()
	_overlay.editor = self
	_graph.add_child(_overlay)
	_graph.scroll_offset_changed.connect(func(_o): _queue_wire_redraw())

	# Dialogs are created on-demand in _show_save_dialog / _show_load_dialog

func _new_graph() -> void:
	for c in _graph.get_children():
		if c is GraphNode:
			c.queue_free()
	_nodes.clear()
	_connections.clear()
	_groups.clear()
	_next_node_id = 1
	_next_group_id = 1
	_make_default_group()
	_add_node(TYPE_ON_START)
	_add_node(TYPE_MOVE)
	_layout_seed_nodes()
	_refresh_group_ui()
	_queue_wire_redraw()

func _save_current() -> void:
	if _last_path == "":
		_save_dialog.popup_centered_ratio()
		return
	_save_to_path(_last_path)

func _show_save_dialog() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.wnodes ; Working Nodes Project"])
	dlg.current_dir = ProjectSettings.globalize_path("res://")
	dlg.min_size = Vector2(640, 480)
	get_tree().root.add_child(dlg)
	dlg.file_selected.connect(func(path): _on_save_path_selected(path); dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered_ratio(0.6)

func _show_load_dialog() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.wnodes ; Working Nodes Project"])
	dlg.current_dir = ProjectSettings.globalize_path("res://")
	dlg.min_size = Vector2(640, 480)
	get_tree().root.add_child(dlg)
	dlg.file_selected.connect(func(path): _on_load_path_selected(path); dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered_ratio(0.6)

func _on_save_path_selected(path: String) -> void:
	if not path.ends_with(".wnodes"):
		path += ".wnodes"
	_last_path = path
	_save_to_path(path)

func _on_load_path_selected(path: String) -> void:
	_last_path = path
	_load_from_path(path)

func _save_to_path(path: String) -> void:
	var data := {
		"version": 1,
		"next_node_id": _next_node_id,
		"next_group_id": _next_group_id,
		"groups": _serialize_groups(),
		"nodes": _serialize_nodes(),
		"connections": _connections,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Working Nodes: failed to save " + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _load_from_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Working Nodes: file not found " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_warning("Working Nodes: invalid project file")
		return
	_apply_loaded_data(parsed)

func _apply_loaded_data(data: Dictionary) -> void:
	for c in _graph.get_children():
		if c is GraphNode:
			c.queue_free()
	_nodes.clear()
	_connections.clear()
	_groups.clear()

	_next_node_id = int(data.get("next_node_id", 1))
	_next_group_id = int(data.get("next_group_id", 1))

	var groups_raw: Array = data.get("groups", [])
	for g in groups_raw:
		var gid := int(g.get("id", 0))
		if gid <= 0:
			continue
		_groups[gid] = {
			"name": str(g.get("name", "Group %d" % gid)),
			"color": Color.from_string(str(g.get("color", "#88AAFF")), Color(0.55, 0.65, 0.95)),
		}

	if _groups.is_empty():
		_make_default_group()

	var nodes_raw: Array = data.get("nodes", [])
	for nd in nodes_raw:
		_rebuild_node_from_dict(nd)

	_connections = data.get("connections", [])
	for c in _connections:
		var fn := str(c.get("from", ""))
		var tn := str(c.get("to", ""))
		var fp := int(c.get("from_port", 0))
		var tp := int(c.get("to_port", 0))
		if _nodes.has(fn) and _nodes.has(tn):
			_graph.connect_node(fn, fp, tn, tp)
	_refresh_group_ui()
	_queue_wire_redraw()

func _serialize_groups() -> Array:
	var out: Array = []
	var keys := _groups.keys()
	keys.sort()
	for gid in keys:
		var g: Dictionary = _groups[gid]
		out.append({
			"id": gid,
			"name": g.get("name", "Group %d" % gid),
			"color": (g.get("color", Color.WHITE) as Color).to_html(true),
		})
	return out

func _serialize_nodes() -> Array:
	var out: Array = []
	var keys := _nodes.keys()
	keys.sort()
	for node_name in keys:
		var n: GraphNode = _nodes[node_name]
		if n == null or not is_instance_valid(n):
			continue
		out.append({
			"name":     n.name,
			"title":    n.title,
			"type":     n.get_meta("wn_type", TYPE_ACTION),
			"group":    int(n.get_meta("wn_group", 1)),
			"color":    (n.get_meta("wn_color", Color.WHITE) as Color).to_html(true),
			"position": [n.position_offset.x, n.position_offset.y],
			"params":   _get_node_params(n),
		})
	return out

func _rebuild_node_from_dict(nd: Dictionary) -> void:
	var node_type := str(nd.get("type", TYPE_ACTION))
	var n := _create_node_ui(node_type)
	n.name = str(nd.get("name", "WN_%d" % _next_node_id))
	n.title = str(nd.get("title", _node_title_for_type(node_type, _next_node_id)))
	var p: Array = nd.get("position", [180, 120])
	if p.size() >= 2:
		n.position_offset = Vector2(float(p[0]), float(p[1]))
	var gid := int(nd.get("group", 1))
	n.set_meta("wn_group", gid)
	n.set_meta("wn_color", Color.from_string(str(nd.get("color", "#88AAFF")), _color_for_type(node_type)))
	_graph.add_child(n)
	_nodes[n.name] = n
	_apply_node_params(n, nd.get("params", {}))
	_update_group_label(n, gid)
	_apply_node_color(n)

func _make_default_group() -> void:
	_groups[_next_group_id] = {
		"name": "Group %d" % _next_group_id,
		"color": Color.from_hsv(0.55, 0.65, 0.95)
	}
	_next_group_id += 1

func _create_group_from_selection() -> void:
	_groups[_next_group_id] = {
		"name": "Group %d" % _next_group_id,
		"color": Color.from_hsv(fmod(float(_next_group_id) * 0.17, 1.0), 0.65, 0.95)
	}
	_next_group_id += 1
	_refresh_group_ui()
	_assign_selected_nodes_to_active_groups()

func _refresh_group_ui() -> void:
	if _group_filter == null or _group_selector == null:
		return
	var previously_selected: Dictionary = {}
	for i in range(_group_selector.item_count):
		if _group_selector.is_selected(i):
			previously_selected[_group_selector.get_item_metadata(i)] = true

	_group_filter.clear()
	_group_filter.add_item("All Groups")
	_group_filter.set_item_metadata(0, -1)

	_group_selector.clear()
	var keys: Array = _groups.keys()
	keys.sort()
	for gid in keys:
		var g: Dictionary = _groups[gid]
		var name: String = g.get("name", "Group")
		_group_filter.add_item(name)
		_group_filter.set_item_metadata(_group_filter.item_count - 1, gid)
		_group_selector.add_item(name)
		var idx := _group_selector.item_count - 1
		_group_selector.set_item_metadata(idx, gid)
		if previously_selected.has(gid):
			_group_selector.select(idx, false)

	if _group_selector.item_count > 0 and _group_selector.get_selected_items().is_empty():
		_group_selector.select(0, false)

	_queue_wire_redraw()

func _add_node(node_type: String) -> void:
	var n := _create_node_ui(node_type)
	n.name = "WN_%d" % _next_node_id
	n.title = _node_title_for_type(node_type, _next_node_id)
	n.position_offset = Vector2(200 + (_next_node_id * 48), 120 + (_next_node_id * 30))
	_graph.add_child(n)
	_nodes[n.name] = n
	_next_node_id += 1
	_apply_node_color(n)
	_queue_wire_redraw()
	_update_vg_preview()

func _create_node_ui(node_type: String) -> GraphNode:
	var n := GraphNode.new()
	n.resizable = true
	n.selected = false
	n.set_meta("wn_type", node_type)
	n.set_meta("wn_group", 1)
	n.set_meta("wn_color", _color_for_type(node_type))
	n.set_meta("wn_breakpoint", false)
	n.gui_input.connect(_on_graph_node_gui_input.bind(n))

	# ── Dedicated trigger nodes — multi-port data-driven layout ─────────
	if _GD_TRIGGERS.has(node_type):
		_build_trigger_node(n, _GD_TRIGGERS[node_type])
		return n

	# ── Legacy single-port nodes (event / action / math) ─────────────────
	n.custom_minimum_size = Vector2(220, 120)
	n.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.add_child(root)

	var type_label := Label.new()
	type_label.text = "%s %s" % [_node_icon(node_type), node_type.capitalize()]
	type_label.add_theme_color_override("font_color", _color_for_type(node_type).lightened(0.4))
	root.add_child(type_label)

	if node_type == TYPE_EVENT:
		var event_option := OptionButton.new()
		event_option.add_item("On Start")
		event_option.add_item("On Touch")
		event_option.add_item("On Timer")
		event_option.add_item("On Signal")
		root.add_child(event_option)
	elif node_type == TYPE_ACTION:
		var action_option := OptionButton.new()
		action_option.add_item("Move")
		action_option.add_item("Rotate")
		action_option.add_item("Scale")
		action_option.add_item("Play SFX")
		action_option.add_item("Set Variable")
		root.add_child(action_option)
	else:
		var math_option := OptionButton.new()
		math_option.add_item("Add")
		math_option.add_item("Subtract")
		math_option.add_item("Multiply")
		math_option.add_item("Divide")
		math_option.add_item("Clamp")
		math_option.add_item("Map Range")
		math_option.add_item("Sine")
		math_option.add_item("Cosine")
		root.add_child(math_option)

		var value_row := HBoxContainer.new()
		var a := LineEdit.new()
		a.placeholder_text = "A"
		var b := LineEdit.new()
		b.placeholder_text = "B"
		value_row.add_child(a)
		value_row.add_child(b)
		root.add_child(value_row)

	var group_label := Label.new()
	group_label.text = "Group: 1"
	group_label.name = "GroupLabel"
	root.add_child(group_label)
	return n


# ══════════════════════════════════════════════════════════════════════════════
# Trigger node builder (data-driven)
# ══════════════════════════════════════════════════════════════════════════════

## Build a multi-port trigger node from a _GD_TRIGGERS definition dict.
## Slot 0  = execution-flow row   (exec in/out, type PORT_EXEC).
## Slots 1…N = parameter rows    (value in only, type PORT_VALUE).
## Last slot  = group-label row  (no ports).
func _build_trigger_node(n: GraphNode, def: Dictionary) -> void:
	var exec_in:  bool  = def.get("exec_in",  true)
	var exec_out: bool  = def.get("exec_out", true)
	var else_out: bool  = def.get("else_out", false)
	var params:   Array = def.get("params",   [])
	var col: Color = Color.from_string("#" + def.get("color_hex", "888888"), Color.WHITE)

	n.custom_minimum_size = Vector2(260, max(96, 74 + params.size() * 30 + (26 if else_out else 0)))

	# ── Slot 0: execution-flow header (True / main exec output) ──────────
	var exec_row := HBoxContainer.new()
	exec_row.add_theme_constant_override("separation", 4)
	var exec_lbl := Label.new()
	exec_lbl.text = "%s  %s" % [def.get("icon", "⚙"), def.get("title", "Trigger")]
	exec_lbl.add_theme_color_override("font_color", col.lightened(0.45))
	exec_lbl.add_theme_font_size_override("font_size", 13)
	exec_row.add_child(exec_lbl)
	n.add_child(exec_row)
	n.set_slot(0, exec_in, PORT_EXEC, EXEC_PORT_COLOR, exec_out, PORT_EXEC, EXEC_PORT_COLOR)

	# ── Slot 1 (optional): Else / False execution output ─────────────────
	var slot_offset := 1
	if else_out:
		var else_row := HBoxContainer.new()
		else_row.add_theme_constant_override("separation", 4)
		var else_lbl := Label.new()
		else_lbl.text = "Else →"
		else_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.50))
		else_lbl.add_theme_font_size_override("font_size", 11)
		else_row.add_child(else_lbl)
		n.add_child(else_row)
		n.set_slot(1, false, 0, Color.WHITE, true, PORT_EXEC, Color(1.0, 0.45, 0.35))
		slot_offset = 2

	# ── Slots slot_offset..N: parameter rows ─────────────────────────────
	for i in params.size():
		var p: Array = params[i]
		var row := _make_param_row(str(p[0]), str(p[1]) if p.size() > 1 else "")
		n.add_child(row)
		n.set_slot(slot_offset + i, true, PORT_VALUE, VALUE_PORT_COLOR, false, 0, Color.WHITE)

	# ── Last slot: group-membership label (no ports) ─────────────────────
	var gl := Label.new()
	gl.name = "GroupLabel"
	gl.text = "Group: 1"
	gl.add_theme_color_override("font_color", Color(0.52, 0.52, 0.52))
	gl.add_theme_font_size_override("font_size", 10)
	n.add_child(gl)
	n.set_slot(slot_offset + params.size(), false, 0, Color.WHITE, false, 0, Color.WHITE)


## Create a parameter row: [Label "name:"]  [LineEdit value]
## The LineEdit's node name is the label text with spaces replaced by underscores
## (used as a key in the params dict during serialisation).
func _make_param_row(label_text: String, default_val: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	row.add_child(lbl)
	var le := LineEdit.new()
	le.name = label_text.replace(" ", "_")
	le.text = default_val
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(54, 0)
	le.add_theme_font_size_override("font_size", 11)
	row.add_child(le)
	return row


## Collect all LineEdit values (keyed by node name) from a trigger node's children.
func _get_node_params(node: GraphNode) -> Dictionary:
	var out := {}
	for child in node.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is LineEdit and sub.name != "":
					out[sub.name] = sub.text
	return out


## Restore LineEdit values from a saved params dict.
func _apply_node_params(node: GraphNode, params: Dictionary) -> void:
	if params.is_empty():
		return
	for child in node.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is LineEdit and params.has(sub.name):
					sub.text = str(params[sub.name])

func _layout_seed_nodes() -> void:
	if _nodes.has("WN_1"):
		(_nodes["WN_1"] as GraphNode).position_offset = Vector2(120, 130)
	if _nodes.has("WN_2"):
		(_nodes["WN_2"] as GraphNode).position_offset = Vector2(480, 160)

func _node_title_for_type(node_type: String, _index: int) -> String:
	if _GD_TRIGGERS.has(node_type):
		return _GD_TRIGGERS[node_type].get("title", node_type.capitalize())
	match node_type:
		TYPE_EVENT:  return "Event"
		TYPE_ACTION: return "Action"
		TYPE_MATH:   return "Math"
		_:           return "Node"

func _color_for_type(node_type: String) -> Color:
	if _GD_TRIGGERS.has(node_type):
		return Color.from_string("#" + _GD_TRIGGERS[node_type].get("color_hex", "888888"), Color.WHITE)
	match node_type:
		TYPE_EVENT:  return Color(0.35, 0.62, 1.0, 1.0)
		TYPE_ACTION: return Color(0.58, 0.90, 0.48, 1.0)
		TYPE_MATH:   return Color(0.96, 0.74, 0.35, 1.0)
		_:           return Color(0.8,  0.8,  0.8,  1.0)

func _apply_node_color(node: GraphNode) -> void:
	if node == null or not is_instance_valid(node):
		return
	var col: Color = node.get_meta("wn_color", Color.WHITE)

	# ── Title bar (normal) ────────────────────────────────────────────────
	var tb := StyleBoxFlat.new()
	tb.bg_color = col.darkened(0.30)
	tb.border_width_left = 1
	tb.border_width_top = 1
	tb.border_width_right = 1
	tb.border_width_bottom = 0
	tb.border_color = col.lightened(0.30)
	tb.corner_radius_top_left = 6
	tb.corner_radius_top_right = 6
	tb.content_margin_left = 8
	tb.content_margin_right = 8
	tb.content_margin_top = 4
	tb.content_margin_bottom = 4
	node.add_theme_stylebox_override("titlebar", tb)

	# ── Title bar (selected) ──────────────────────────────────────────────
	var tb_sel := StyleBoxFlat.new()
	tb_sel.bg_color = col.darkened(0.10)
	tb_sel.border_width_left = 2
	tb_sel.border_width_top = 2
	tb_sel.border_width_right = 2
	tb_sel.border_width_bottom = 0
	tb_sel.border_color = col.lightened(0.55)
	tb_sel.corner_radius_top_left = 6
	tb_sel.corner_radius_top_right = 6
	tb_sel.content_margin_left = 8
	tb_sel.content_margin_right = 8
	tb_sel.content_margin_top = 4
	tb_sel.content_margin_bottom = 4
	node.add_theme_stylebox_override("titlebar_selected", tb_sel)

	# ── Title text: always white for readability ──────────────────────────
	node.add_theme_color_override("title_color", Color.WHITE)

	# ── Body panel ────────────────────────────────────────────────────────
	var box := StyleBoxFlat.new()
	box.bg_color = col.darkened(0.72)
	box.border_width_left = 1
	box.border_width_top = 0
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = col.lightened(0.25)
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	node.add_theme_stylebox_override("panel", box)

func _on_graph_node_selected(_node: Node) -> void:
	var selected := _selected_graph_nodes()
	if selected.size() == 1:
		var n: GraphNode = selected[0]
		_node_color_picker.color = n.get_meta("wn_color", Color.WHITE)
	_queue_wire_redraw()

func _on_node_color_changed(c: Color) -> void:
	for n in _selected_graph_nodes():
		n.set_meta("wn_color", c)
		_apply_node_color(n)
	for i in range(_connections.size()):
		var conn: Dictionary = _connections[i]
		var from_n := _nodes.get(conn.get("from", ""), null)
		if from_n != null and is_instance_valid(from_n):
			conn["color"] = from_n.get_meta("wn_color", Color(0.8, 0.8, 0.9))
			_connections[i] = conn
	_queue_wire_redraw()

func _selected_graph_nodes() -> Array:
	var out: Array = []
	for child in _graph.get_children():
		if child is GraphNode and child.selected:
			out.append(child)
	return out

func _assign_selected_nodes_to_active_groups() -> void:
	var selected_groups := _active_group_ids()
	if selected_groups.is_empty():
		return
	var gid: int = selected_groups[0]
	for n in _selected_graph_nodes():
		n.set_meta("wn_group", gid)
		_update_group_label(n, gid)
	for i in range(_connections.size()):
		var conn: Dictionary = _connections[i]
		var from_n := _nodes.get(conn.get("from", ""), null)
		if from_n != null and is_instance_valid(from_n):
			conn["group"] = int(from_n.get_meta("wn_group", 1))
			_connections[i] = conn
	_queue_wire_redraw()

func _update_group_label(node: GraphNode, gid: int) -> void:
	var lbl: Label = node.find_child("GroupLabel", true, false)
	if lbl == null:
		return
	var gname: String = _groups.get(gid, {}).get("name", "Group %d" % gid)
	lbl.text = "Group: %s" % gname

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node:
		return
	if not _nodes.has(String(from_node)) or not _nodes.has(String(to_node)):
		return
	for c in _connections:
		if c.get("from", "") == String(from_node) and c.get("to", "") == String(to_node) and c.get("from_port", -1) == from_port and c.get("to_port", -1) == to_port:
			return
	_graph.connect_node(from_node, from_port, to_node, to_port)
	var from_n: GraphNode = _nodes[String(from_node)]
	var gid := int(from_n.get_meta("wn_group", 1))
	_connections.append({
		"from":       String(from_node),
		"from_port":  from_port,
		"to":         String(to_node),
		"to_port":    to_port,
		"group":      gid,
		"color":      from_n.get_meta("wn_color", Color(0.8, 0.8, 0.9)),
		"joints":     [],
	})
	_queue_wire_redraw()
	_update_vg_preview()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.disconnect_node(from_node, from_port, to_node, to_port)
	for i in range(_connections.size() - 1, -1, -1):
		var c: Dictionary = _connections[i]
		if c.get("from", "") == String(from_node) and c.get("to", "") == String(to_node) and c.get("from_port", -1) == from_port and c.get("to_port", -1) == to_port:
			_connections.remove_at(i)
	_queue_wire_redraw()
	_update_vg_preview()

func _smart_connect_selected() -> void:
	var selected := _selected_graph_nodes()
	if selected.size() < 2:
		return
	selected.sort_custom(func(a: GraphNode, b: GraphNode): return a.position_offset.x < b.position_offset.x)
	for i in range(selected.size() - 1):
		_on_connection_request(StringName(selected[i].name), 0, StringName(selected[i + 1].name), 0)

func _queue_wire_redraw() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _on_graph_gui_input(_event: InputEvent) -> void:
	pass


# Right-mouse drag-to-pan via _input (fires before GraphEdit consumes events).
# When the click is ON a GraphNode we bail out immediately so the node's
# gui_input handler can show its context menu instead.
func _input(event: InputEvent) -> void:
	if _graph == null or not is_instance_valid(_graph):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			var graph_rect := _graph.get_global_rect()
			if not graph_rect.has_point(mb.global_position):
				if not mb.pressed and _panning:
					_panning = false
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				return
			if mb.pressed:
				# If clicking directly on a GraphNode, let its gui_input handle it.
				for child in _graph.get_children():
					if child is GraphNode and child.get_global_rect().has_point(mb.global_position):
						return
				_rclick_press_pos = mb.global_position
				_panning = true
				_pan_start_mouse = mb.global_position
				_pan_start_scroll = _graph.scroll_offset
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
				get_viewport().set_input_as_handled()
			else:
				if _panning:
					_panning = false
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
					# Short click (no significant drag) → show canvas context menu
					if mb.global_position.distance_to(_rclick_press_pos) < 6.0:
						if _canvas_context_menu != null and is_instance_valid(_canvas_context_menu):
							_canvas_context_menu.popup(Rect2(mb.global_position, Vector2.ZERO))
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _panning:
			_graph.scroll_offset = _pan_start_scroll - (event.global_position - _pan_start_mouse)
			get_viewport().set_input_as_handled()

func _active_group_ids() -> Array:
	var selected_groups: Array = []
	for idx in _group_selector.get_selected_items():
		selected_groups.append(_group_selector.get_item_metadata(idx))
	selected_groups.sort()
	return selected_groups

func _passes_group_filter(conn: Dictionary) -> bool:
	if _group_filter == null or _group_filter.item_count == 0:
		return true
	var gid := conn.get("group", 1)
	var chosen := _group_filter.get_item_metadata(_group_filter.selected)
	if int(chosen) == -1:
		return true
	return int(chosen) == int(gid)

func _passes_selection_visibility(conn: Dictionary) -> bool:
	if _show_all_wires and _show_all_wires.button_pressed:
		return true
	var from_n: GraphNode = _nodes.get(conn.get("from", ""), null)
	var to_n: GraphNode = _nodes.get(conn.get("to", ""), null)
	if from_n == null or to_n == null:
		return false
	if from_n.selected or to_n.selected:
		return true
	var selected_groups := _active_group_ids()
	if selected_groups.is_empty():
		return false
	return int(conn.get("group", -999)) in selected_groups

func _node_port_pos(node_name: String, is_output: bool, port: int) -> Vector2:
	var n: GraphNode = _nodes.get(node_name, null)
	if n == null or not is_instance_valid(n):
		return Vector2.ZERO
	var base := n.position_offset - _graph.scroll_offset
	if is_output:
		return base + n.get_output_port_position(port)
	else:
		return base + n.get_input_port_position(port)

func _node_center_in_overlay(node_name: String) -> Vector2:
	var n: GraphNode = _nodes.get(node_name, null)
	if n == null or not is_instance_valid(n):
		return Vector2.ZERO
	var pos := n.position_offset - _graph.scroll_offset
	return pos + n.size * 0.5

func _smart_path(start: Vector2, fin: Vector2, lane_index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if _smart_routing == null or not _smart_routing.button_pressed:
		points.push_back(start)
		points.push_back(fin)
		return points
	var lane_offset := float((lane_index % 7) - 3) * 20.0
	var mid_x := (start.x + fin.x) * 0.5 + lane_offset
	var bend := 26.0
	points.push_back(start)
	points.push_back(Vector2(mid_x - bend, start.y))
	points.push_back(Vector2(mid_x, start.y + sign(fin.y - start.y) * 4.0))
	points.push_back(Vector2(mid_x, fin.y - sign(fin.y - start.y) * 4.0))
	points.push_back(Vector2(mid_x + bend, fin.y))
	points.push_back(fin)
	return points

func _get_visible_connections_for_overlay() -> Array:
	var out: Array = []
	var lane_counter: Dictionary = {}
	var conn_idx := 0
	for conn in _connections:
		if not _passes_group_filter(conn):
			conn_idx += 1
			continue
		if not _passes_selection_visibility(conn):
			conn_idx += 1
			continue
		var start := _node_port_pos(conn.get("from", ""), true,  int(conn.get("from_port", 0)))
		var fin   := _node_port_pos(conn.get("to",   ""), false, int(conn.get("to_port",   0)))

		# Build waypoints: start → manual joints (screen space) → end
		var waypoints := PackedVector2Array()
		waypoints.push_back(start)
		var joints_raw: Array = conn.get("joints", [])
		var joints_screen: Array = []
		for jv in joints_raw:
			if jv is Array and jv.size() >= 2:
				var j_screen := Vector2(float(jv[0]), float(jv[1])) - _graph.scroll_offset
				waypoints.push_back(j_screen)
				joints_screen.append(j_screen)
		waypoints.push_back(fin)

		# Smart lane routing only applies when no manual joints are defined
		if joints_raw.is_empty() and _smart_routing != null and _smart_routing.button_pressed:
			var lane_key := "%s_%s" % [str(conn.get("group", 0)), str(round((start.x + fin.x) / 120.0))]
			if not lane_counter.has(lane_key):
				lane_counter[lane_key] = 0
			var lane_index: int = lane_counter[lane_key]
			lane_counter[lane_key] = lane_index + 1
			var lane_offset := float((lane_index % 7) - 3) * 20.0
			var mid_x := (start.x + fin.x) * 0.5 + lane_offset
			# Replace start/end with the smart-routed intermediate points
			waypoints.clear()
			waypoints.push_back(start)
			waypoints.push_back(fin)  # overlay draws bezier — leave start/end only

		out.append({
			"waypoints":     waypoints,
			"joints_screen": joints_screen,
			"color":         conn.get("color", Color(0.8, 0.8, 0.9, 0.95)),
			"width":         2.2,
			"label":         _wire_label_for(conn),
			"conn_idx":      conn_idx,
		})
		conn_idx += 1
	return out


# ── Export / Code generation ──────────────────────────────────────────────────

func get_export_stem() -> String:
	if _last_path != "" and _last_path != "res://working_nodes_project.wnodes":
		return _last_path.get_basename().get_file()
	return "working_nodes_export"

func _collect_graph_data() -> Dictionary:
	return {
		"version": 1,
		"next_node_id": _next_node_id,
		"next_group_id": _next_group_id,
		"groups": _serialize_groups(),
		"nodes": _serialize_nodes(),
		"connections": _connections,
	}

func _on_export_vg_pressed() -> void:
	export_vg_requested.emit(_collect_graph_data())

func _on_export_scene_2d_pressed() -> void:
	export_scene_2d_requested.emit(_collect_graph_data())

func _on_export_scene_3d_pressed() -> void:
	export_scene_3d_requested.emit(_collect_graph_data())

func _on_run_graph_2d_pressed() -> void:
	run_graph_requested.emit(_collect_graph_data(), false)

func _on_run_graph_3d_pressed() -> void:
	run_graph_requested.emit(_collect_graph_data(), true)


# ══════════════════════════════════════════════════════════════════════════════
# Node icon helper
# ══════════════════════════════════════════════════════════════════════════════

func _node_icon(node_type: String) -> String:
	if _GD_TRIGGERS.has(node_type):
		return _GD_TRIGGERS[node_type].get("icon", "⚙")
	match node_type:
		TYPE_EVENT:  return "⚡"
		TYPE_ACTION: return "⚙"
		TYPE_MATH:   return "∑"
		_:           return "◆"


# ══════════════════════════════════════════════════════════════════════════════
# Wire label: show the from-node's title when it is short (e.g. a variable name)
# ══════════════════════════════════════════════════════════════════════════════

func _wire_label_for(conn: Dictionary) -> String:
	var from_n: GraphNode = _nodes.get(conn.get("from", ""), null)
	if from_n == null or not is_instance_valid(from_n):
		return ""
	# Only annotate wires whose source node type is a Variable-like node
	if from_n.get_meta("wn_type", "") != "variable":
		return ""
	# Use the node title as the wire label (keep it short)
	var title := from_n.title
	return title if title.length() <= 24 else (title.left(21) + "…")


# ══════════════════════════════════════════════════════════════════════════════
# Live VG preview
# ══════════════════════════════════════════════════════════════════════════════

func _on_preview_toggled(pressed: bool) -> void:
	_preview_visible = pressed
	if _preview_panel != null and is_instance_valid(_preview_panel):
		_preview_panel.visible = pressed
		if pressed:
			_update_vg_preview()

func _update_vg_preview() -> void:
	if not _preview_visible:
		return
	if _preview_code == null or not is_instance_valid(_preview_code):
		return
	var code := working_nodes_codegen.generate_vg_code(_collect_graph_data())
	_preview_code.text = code


# ══════════════════════════════════════════════════════════════════════════════
# Graph validator
# ══════════════════════════════════════════════════════════════════════════════

func _validate_graph() -> void:
	var issues: Array = []
	var has_event := false
	var connected_names: Dictionary = {}
	for c in _connections:
		connected_names[str(c.get("to", ""))] = true

	for node_name in _nodes:
		var n: GraphNode = _nodes[node_name]
		if not is_instance_valid(n): continue
		var ntype := n.get_meta("wn_type", "")
		if ntype in [TYPE_EVENT, TYPE_ON_START, TYPE_ON_FRAME, TYPE_ON_INPUT, TYPE_ON_COLLISION]:
			has_event = true
		elif ntype == TYPE_ACTION and not connected_names.has(node_name):
			issues.append("Action node '%s' has no incoming connection (may be unreachable)." % n.title)

	if not has_event:
		issues.append("No Event node found — nothing will fire on execution.")

	# Check for trivial cycles (self-connections)
	for c in _connections:
		if str(c.get("from", "")) == str(c.get("to", "")):
			issues.append("Self-connection on node '%s'." % str(c.get("from", "")))

	if _validator_popup == null or not is_instance_valid(_validator_popup):
		_validator_popup = AcceptDialog.new()
		_validator_popup.title = "Working Nodes — Validator"
		_validator_popup.min_size = Vector2(460, 280)
		add_child(_validator_popup)

	if issues.is_empty():
		_validator_popup.dialog_text = "✔  No issues found. Graph looks good!"
	else:
		_validator_popup.dialog_text = "Found %d issue(s):\n\n• " % issues.size() + \
			"\n• ".join(issues)
	_validator_popup.popup_centered()


# ══════════════════════════════════════════════════════════════════════════════
# Shift+A — node palette popup
# ══════════════════════════════════════════════════════════════════════════════

const _ALL_NODE_KINDS: Array = [
	# ── Dedicated trigger nodes ─────────────────────────────────────────────
	["▶ On Start",     "on_start"],
	["↔ Move",         "move"],
	["↻ Rotate",       "rotate"],
	["⤡ Scale",        "scale"],
	["◑ Alpha",        "alpha"],
	["🎨 Color",       "color_trigger"],
	["💢 Pulse",       "pulse"],
	["✦ Spawn",        "spawn"],
	["◼ Stop",         "stop"],
	["👁 Toggle",      "toggle"],
	["⟿ Follow",       "follow"],
	["⚡ Shake",       "shake"],
	["♪ Play SFX",     "play_sfx"],
	["▷ Animate",      "animate"],
	# ── Generic / legacy nodes ────────────────────────────────────────────────
	["⚡ Event",        "event"],
	["⚙ Action",       "action"],
	["∑ Math",          "math"],
	["⎇ Condition",    "condition"],
	["📦 Variable",    "variable"],
	["📝 Note",         "note"],
	["⊞ Group",         "group"],
	["↺ Loop",          "loop"],
	["⏩ Sequence",     "sequence"],
	["ƒ Function",      "function"],
	["⟿ VectorMath",   "vectormath"],
	["↔ MapRange",      "maprange"],
	["∧ BoolMath",      "boolmath"],
	["⇌ Switch",        "switch"],
	["≤ Compare",       "compare"],
	["🎲 Random",       "randomvalue"],
	# ── GD-equivalent: event / flow / data ─────────────────────────────────
	["⏱ On Frame",       "on_frame"],
	["🎮 On Input",       "on_input"],
	["💥 On Collision",   "on_collision"],
	["🔢 Counter",        "counter"],
	["🎲 Random Trig",    "random_trig"],
	["⎇ Branch",          "branch"],
	["≤ Compare Trig",    "cmp_trig"],
	["⏳ Timer",           "timer"],
	["🔍 Zoom",            "zoom"],
	["🎥 Camera Move",     "camera_move"],
	["📥 Get Property",    "get_prop"],
	["📤 Set Property",    "set_prop"],
	["🕹 Input Poll",      "input_poll"],
	["ƒ Expression",       "expr"],
	["Δ Delta Var",        "delta_var"],
]

func _open_node_palette() -> void:
	_palette_pos = _graph.get_local_mouse_position() + _graph.scroll_offset
	if _palette_popup == null or not is_instance_valid(_palette_popup):
		_build_palette_popup()
	_palette_search.text = ""
	_palette_list.clear()
	for entry in _ALL_NODE_KINDS:
		_palette_list.add_item(entry[0])
		_palette_list.set_item_metadata(_palette_list.item_count - 1, entry[1])
	_palette_popup.popup_centered(Vector2(320, 440))
	_palette_search.grab_focus()

func _build_palette_popup() -> void:
	_palette_popup = Window.new()
	_palette_popup.title = "Add Node  (Shift+A)"
	_palette_popup.min_size = Vector2(320, 420)
	_palette_popup.unresizable = false
	var vb := VBoxContainer.new()
	_palette_popup.add_child(vb)
	_palette_search = LineEdit.new()
	_palette_search.placeholder_text = "Search…"
	_palette_search.text_changed.connect(_on_palette_search_changed)
	vb.add_child(_palette_search)
	_palette_list = ItemList.new()
	_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_list.item_activated.connect(_on_palette_item_activated)
	vb.add_child(_palette_list)
	add_child(_palette_popup)

func _on_palette_search_changed(text: String) -> void:
	if _palette_list == null: return
	_palette_list.clear()
	var q := text.to_lower()
	for entry in _ALL_NODE_KINDS:
		if q.is_empty() or q in entry[0].to_lower() or q in entry[1].to_lower():
			_palette_list.add_item(entry[0])
			_palette_list.set_item_metadata(_palette_list.item_count - 1, entry[1])

func _on_palette_item_activated(index: int) -> void:
	if _palette_list == null: return
	var kind: String = _palette_list.get_item_metadata(index)
	_palette_popup.hide()
	# Trigger nodes and legacy base types handled uniformly
	if _GD_TRIGGERS.has(kind):
		_add_node_at(kind, _palette_pos)
		return
	match kind:
		"event":  _add_node_at(TYPE_EVENT,  _palette_pos)
		"action": _add_node_at(TYPE_ACTION, _palette_pos)
		"math":   _add_node_at(TYPE_MATH,   _palette_pos)
		_:
			# Extended kinds: create a generic Action node tagged with the kind
			var n := _add_node_at(TYPE_ACTION, _palette_pos)
			if n != null:
				n.title = kind.capitalize() + " %d" % (_next_node_id - 1)
				n.set_meta("wn_kind", kind)

func _add_node_at(node_type: String, at_pos: Vector2) -> GraphNode:
	var n := _create_node_ui(node_type)
	n.name = "WN_%d" % _next_node_id
	n.title = _node_title_for_type(node_type, _next_node_id)
	n.position_offset = at_pos
	_graph.add_child(n)
	_nodes[n.name] = n
	_next_node_id += 1
	_apply_node_color(n)
	_queue_wire_redraw()
	_update_vg_preview()
	return n


# ══════════════════════════════════════════════════════════════════════════════
# Double-click rename + right-click context menu (node gui_input)
# ══════════════════════════════════════════════════════════════════════════════

func _on_graph_node_gui_input(event: InputEvent, node: GraphNode) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			_rename_node_inline(node)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_ctx_target_node = node
			if _node_context_menu != null and is_instance_valid(_node_context_menu):
				# Update breakpoint menu item label
				var has_bp := node.get_meta("wn_breakpoint", false)
				_node_context_menu.set_item_text(2,
					"🔴 Remove Breakpoint" if has_bp else "🔴 Set Breakpoint")
				_node_context_menu.popup(Rect2(mb.global_position, Vector2.ZERO))
			get_viewport().set_input_as_handled()

func _on_node_context_menu_id(id: int) -> void:
	if _ctx_target_node == null or not is_instance_valid(_ctx_target_node):
		return
	match id:
		0:  # Rename
			_rename_node_inline(_ctx_target_node)
		1:  # Duplicate
			var dup := _create_node_ui(_ctx_target_node.get_meta("wn_type", TYPE_ACTION))
			dup.name = "WN_%d" % _next_node_id
			dup.title = _ctx_target_node.title + " (copy)"
			dup.position_offset = _ctx_target_node.position_offset + Vector2(40, 40)
			_graph.add_child(dup)
			_nodes[dup.name] = dup
			_next_node_id += 1
			_apply_node_color(dup)
			_queue_wire_redraw()
			_update_vg_preview()
		2:  # Toggle breakpoint
			var cur := _ctx_target_node.get_meta("wn_breakpoint", false)
			_ctx_target_node.set_meta("wn_breakpoint", not cur)
			_apply_breakpoint_style(_ctx_target_node)
			_update_vg_preview()
		3:  # Delete
			_delete_nodes_by_name([StringName(_ctx_target_node.name)])

func _on_canvas_context_menu_id(id: int) -> void:
	# Trigger nodes (0–13)
	const _CANVAS_MENU_KINDS: Array = [
		"on_start", "move", "rotate", "scale", "alpha", "color_trigger",
		"spawn", "stop", "toggle", "play_sfx", "follow", "shake", "pulse", "animate"
	]
	if id < _CANVAS_MENU_KINDS.size():
		_add_node(_CANVAS_MENU_KINDS[id])
		return
	match id:
		20: _add_node(TYPE_EVENT)
		21: _add_node(TYPE_ACTION)
		22: _add_node(TYPE_MATH)
		30:  # Select All
			for child in _graph.get_children():
				if child is GraphNode:
					child.selected = true
		31:  # Clear Graph
			_new_graph()
		40: _add_node(TYPE_ON_FRAME)
		41: _add_node(TYPE_ON_INPUT)
		42: _add_node(TYPE_ON_COLLISION)
		43: _add_node(TYPE_COUNTER)
		44: _add_node(TYPE_RANDOM_TRIG)
		45: _add_node(TYPE_BRANCH)
		46: _add_node(TYPE_CMP_TRIG)
		47: _add_node(TYPE_TIMER)
		48: _add_node(TYPE_SEQUENCE)
		49: _add_node(TYPE_ZOOM)
		50: _add_node(TYPE_CAMERA_MOVE)
		51: _add_node(TYPE_GET_PROP)
		52: _add_node(TYPE_SET_PROP)
		53: _add_node(TYPE_INPUT_POLL)
		54: _add_node(TYPE_EXPR)
		55: _add_node(TYPE_DELTA_VAR)

func _delete_selected_nodes() -> void:
	var names: Array[StringName] = []
	for child in _graph.get_children():
		if child is GraphNode and child.selected:
			names.append(StringName(child.name))
	_delete_nodes_by_name(names)

func _delete_nodes_by_name(node_names: Array[StringName]) -> void:
	if node_names.is_empty():
		return
	var name_set: Dictionary = {}
	for nm in node_names:
		name_set[String(nm)] = true
	# Remove connections involving deleted nodes
	_connections = _connections.filter(func(c: Dictionary) -> bool:
		return not (name_set.has(c.get("from", "")) or name_set.has(c.get("to", "")))
	)
	# Disconnect all ports in GraphEdit and free nodes
	for nm in node_names:
		var key := String(nm)
		if _nodes.has(key):
			var n: GraphNode = _nodes[key]
			_graph.clear_connections()
			_nodes.erase(key)
			if is_instance_valid(n):
				n.queue_free()
	# Re-add remaining connections to GraphEdit
	for c in _connections:
		_graph.connect_node(c["from"], c["from_port"], c["to"], c["to_port"])
	_queue_wire_redraw()
	_update_vg_preview()

func _rename_node_inline(node: GraphNode) -> void:
	var d := AcceptDialog.new()
	d.title = "Rename Node"
	var vb := VBoxContainer.new()
	d.add_child(vb)
	var le := LineEdit.new()
	le.text = node.title
	le.select_all()
	vb.add_child(le)
	add_child(d)
	d.popup_centered(Vector2(320, 100))
	le.grab_focus()
	d.confirmed.connect(func():
		if le.text.strip_edges() != "":
			node.title = le.text.strip_edges()
			_update_vg_preview()
		d.queue_free()
	)
	d.canceled.connect(func(): d.queue_free())

func _apply_breakpoint_style(node: GraphNode) -> void:
	if node.get_meta("wn_breakpoint", false):
		var box := StyleBoxFlat.new()
		var col: Color = node.get_meta("wn_color", Color.WHITE)
		box.bg_color = col.darkened(0.72)
		box.border_width_left = 3; box.border_width_top = 3
		box.border_width_right = 3; box.border_width_bottom = 3
		box.border_color = Color(1.0, 0.2, 0.2)
		box.set_corner_radius_all(6)
		node.add_theme_stylebox_override("panel", box)
	else:
		_apply_node_color(node)


# ══════════════════════════════════════════════════════════════════════════════
# Copy / Paste (Ctrl+C / Ctrl+V) — serialises selected nodes + their wires
# ══════════════════════════════════════════════════════════════════════════════

func _copy_selection() -> void:
	var selected := _selected_graph_nodes()
	if selected.is_empty():
		return
	var sel_names: Dictionary = {}
	for n in selected:
		sel_names[n.name] = true
	var nodes_arr: Array = []
	for n in selected:
		nodes_arr.append({
			"name": n.name, "title": n.title,
			"type": n.get_meta("wn_type", TYPE_ACTION),
			"group": int(n.get_meta("wn_group", 1)),
			"color": (n.get_meta("wn_color", Color.WHITE) as Color).to_html(true),
			"position": [n.position_offset.x, n.position_offset.y],
			"params": _get_node_params(n),
		})
	var conns_arr: Array = []
	for c in _connections:
		if sel_names.has(c.get("from", "")) and sel_names.has(c.get("to", "")):
			conns_arr.append(c)
	var payload := JSON.stringify({"wn_clipboard": true, "nodes": nodes_arr, "connections": conns_arr})
	_clipboard_data = payload
	DisplayServer.clipboard_set(payload)

func _paste_selection() -> void:
	var raw := DisplayServer.clipboard_get()
	if raw.is_empty():
		raw = _clipboard_data
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary) or not parsed.get("wn_clipboard", false):
		return
	# Remap node names to avoid collisions
	var remap: Dictionary = {}
	for nd in parsed.get("nodes", []):
		var new_name := "WN_%d" % _next_node_id
		remap[str(nd.get("name", ""))] = new_name
		var n := _create_node_ui(str(nd.get("type", TYPE_ACTION)))
		n.name = new_name
		n.title = str(nd.get("title", "Pasted"))
		var pos_a: Array = nd.get("position", [200, 200])
		n.position_offset = Vector2(float(pos_a[0]) + 30, float(pos_a[1]) + 30)
		n.set_meta("wn_color", Color.from_string(str(nd.get("color", "#FFFFFF")), Color.WHITE))
		_graph.add_child(n)
		_nodes[new_name] = n
		_next_node_id += 1
		_apply_node_params(n, nd.get("params", {}))
		_apply_node_color(n)
	for c in parsed.get("connections", []):
		var fn := remap.get(str(c.get("from", "")), "")
		var tn := remap.get(str(c.get("to", "")), "")
		if fn != "" and tn != "":
			_connections.append({
				"from": fn, "from_port": c.get("from_port", 0),
				"to": tn,   "to_port":   c.get("to_port", 0),
				"group": 1, "color": Color(0.8, 0.8, 0.9), "joints": [],
			})
	_queue_wire_redraw()
	_update_vg_preview()


# ══════════════════════════════════════════════════════════════════════════════
# Snippets — save / load named subgraphs
# ══════════════════════════════════════════════════════════════════════════════

func _load_snippets_from_disk() -> void:
	if FileAccess.file_exists(_snippets_path):
		var f := FileAccess.open(_snippets_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				_snippets = parsed

func _save_snippets_to_disk() -> void:
	var f := FileAccess.open(_snippets_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_snippets, "\t"))
		f.close()

func _save_snippet() -> void:
	var selected := _selected_graph_nodes()
	if selected.is_empty():
		push_warning("Working Nodes: select nodes first to save a snippet.")
		return
	_load_snippets_from_disk()
	var d := AcceptDialog.new()
	d.title = "Save Snippet"
	var vb := VBoxContainer.new(); d.add_child(vb)
	var lbl := Label.new(); lbl.text = "Snippet name:"
	vb.add_child(lbl)
	var le := LineEdit.new()
	le.text = "my_snippet"
	le.select_all()
	vb.add_child(le)
	add_child(d)
	d.popup_centered(Vector2(320, 110))
	le.grab_focus()
	d.confirmed.connect(func():
		var sname := le.text.strip_edges()
		if sname.is_empty(): d.queue_free(); return
		var sel_names: Dictionary = {}
		for n in selected: sel_names[n.name] = true
		var nodes_arr: Array = []
		for n in selected:
			nodes_arr.append({
				"name": n.name, "title": n.title,
				"type": n.get_meta("wn_type", TYPE_ACTION),
				"color": (n.get_meta("wn_color", Color.WHITE) as Color).to_html(true),
				"position": [n.position_offset.x, n.position_offset.y],
				"params": _get_node_params(n),
			})
		var conns_arr: Array = []
		for c in _connections:
			if sel_names.has(c.get("from", "")) and sel_names.has(c.get("to", "")):
				conns_arr.append(c)
		_snippets[sname] = {"nodes": nodes_arr, "connections": conns_arr}
		_save_snippets_to_disk()
		d.queue_free()
	)
	d.canceled.connect(func(): d.queue_free())

func _open_snippet_popup() -> void:
	_load_snippets_from_disk()
	if _snippet_popup == null or not is_instance_valid(_snippet_popup):
		_snippet_popup = Window.new()
		_snippet_popup.title = "Insert Snippet"
		_snippet_popup.min_size = Vector2(300, 360)
		var vb := VBoxContainer.new()
		_snippet_popup.add_child(vb)
		_snippet_name_edit = LineEdit.new()
		_snippet_name_edit.editable = false
		_snippet_name_edit.placeholder_text = "Select a snippet to insert…"
		vb.add_child(_snippet_name_edit)
		var il := ItemList.new()
		il.size_flags_vertical = Control.SIZE_EXPAND_FILL
		il.item_activated.connect(func(idx):
			var sname: String = il.get_item_text(idx)
			_insert_snippet(sname)
			_snippet_popup.hide()
		)
		il.item_selected.connect(func(idx): _snippet_name_edit.text = il.get_item_text(idx))
		for k in _snippets.keys():
			il.add_item(k)
		vb.add_child(il)
		add_child(_snippet_popup)
	_snippet_popup.popup_centered()

func _insert_snippet(sname: String) -> void:
	var snip: Dictionary = _snippets.get(sname, {})
	if snip.is_empty(): return
	var remap: Dictionary = {}
	for nd in snip.get("nodes", []):
		var new_name := "WN_%d" % _next_node_id
		remap[str(nd.get("name", ""))] = new_name
		var n := _create_node_ui(str(nd.get("type", TYPE_ACTION)))
		n.name = new_name
		n.title = str(nd.get("title", sname))
		var pos_a: Array = nd.get("position", [300, 300])
		n.position_offset = Vector2(float(pos_a[0]) + 60, float(pos_a[1]) + 60)
		n.set_meta("wn_color", Color.from_string(str(nd.get("color", "#FFFFFF")), Color.WHITE))
		_graph.add_child(n)
		_nodes[new_name] = n
		_next_node_id += 1
		_apply_node_params(n, nd.get("params", {}))
		_apply_node_color(n)
	for c in snip.get("connections", []):
		var fn := remap.get(str(c.get("from", "")), "")
		var tn := remap.get(str(c.get("to", "")), "")
		if fn != "" and tn != "":
			_connections.append({"from": fn, "from_port": 0, "to": tn, "to_port": 0, "group": 1, "color": Color(0.8,0.8,0.9), "joints": []})
	_queue_wire_redraw()
	_update_vg_preview()


# ══════════════════════════════════════════════════════════════════════════════
# Execution-order animated highlight
# ══════════════════════════════════════════════════════════════════════════════

func _highlight_exec_order_animated() -> void:
	# First clear old badges
	for n in _nodes.values():
		if n is GraphNode and is_instance_valid(n):
			var b: Node = n.get_node_or_null("_exec_badge")
			if b: b.queue_free()
	# BFS from each event node
	var order: Dictionary = {}
	var queue: Array = []
	for node_name in _nodes:
		var n: GraphNode = _nodes[node_name]
		if is_instance_valid(n) and n.get_meta("wn_type", "") == TYPE_EVENT:
			queue.append(node_name)
	var visited: Dictionary = {}
	var counter := 1
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if visited.has(cur): continue
		visited[cur] = true
		order[cur] = counter
		counter += 1
		for c in _connections:
			if str(c.get("from", "")) == cur:
				queue.push_back(str(c.get("to", "")))
	# Add badges and animate them in sequence
	for nname in order:
		var nd: GraphNode = _nodes.get(nname, null)
		if nd == null or not is_instance_valid(nd): continue
		var badge := Label.new()
		badge.name = "_exec_badge"
		badge.text = "⓪%d" % order[nname]
		badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		badge.modulate = Color(1, 1, 1, 0)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-34, -22)
		nd.add_child(badge)
		# Staggered fade-in tween
		var tw := badge.create_tween()
		tw.tween_interval(float(order[nname] - 1) * 0.12)
		tw.tween_property(badge, "modulate", Color(1, 1, 1, 1), 0.15)
		tw.tween_interval(1.8)
		tw.tween_property(badge, "modulate", Color(1, 1, 1, 0), 0.3)
		tw.tween_callback(badge.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# _serialize_nodes override — include breakpoint flag
# ══════════════════════════════════════════════════════════════════════════════
# (Overrides the base method to add wn_breakpoint to saved data)

func _serialize_nodes_with_bp() -> Array:
	var out: Array = []
	var keys := _nodes.keys()
	keys.sort()
	for node_name in keys:
		var n: GraphNode = _nodes[node_name]
		if n == null or not is_instance_valid(n): continue
		out.append({
			"name": n.name,
			"title": n.title,
			"type": n.get_meta("wn_type", TYPE_ACTION),
			"group": int(n.get_meta("wn_group", 1)),
			"color": (n.get_meta("wn_color", Color.WHITE) as Color).to_html(true),
			"position": [n.position_offset.x, n.position_offset.y],
			"_breakpoint": n.get_meta("wn_breakpoint", false),
		})
	return out


# ══════════════════════════════════════════════════════════════════════════════
# Keyboard shortcuts (added to existing _input)
# ══════════════════════════════════════════════════════════════════════════════
# NOTE: _input is already defined above for RMB pan — we EXTEND it here via
# a helper so both parts can coexist cleanly without overwriting each other.

func _open_manual() -> void:
	var res_path := "res://addons/visual_gasic/plugins/working_nodes/WORKING_NODES_MANUAL.md"
	OS.shell_open(ProjectSettings.globalize_path(res_path))


# ══════════════════════════════════════════════════════════════════════════════
# Wire Joint management  (called by the overlay and the joint-mode toggle)
# ══════════════════════════════════════════════════════════════════════════════

## Expose the current graph scroll for the overlay's coordinate conversion.
func get_scroll_offset() -> Vector2:
	return _graph.scroll_offset if _graph != null else Vector2.ZERO


## Toggle joint-edit mode on the overlay.
func _on_joint_mode_toggled(pressed: bool) -> void:
	if _overlay != null and is_instance_valid(_overlay) and _overlay.has_method("set_joint_mode"):
		_overlay.set_joint_mode(pressed)


## Move an existing joint to a new graph-space position.
func update_joint(conn_idx: int, joint_idx: int, graph_pos: Vector2) -> void:
	if conn_idx < 0 or conn_idx >= _connections.size():
		return
	var conn: Dictionary = _connections[conn_idx]
	var joints: Array = conn.get("joints", []).duplicate()
	while joints.size() <= joint_idx:
		joints.append([0.0, 0.0])
	joints[joint_idx] = [graph_pos.x, graph_pos.y]
	conn["joints"] = joints
	_connections[conn_idx] = conn
	_queue_wire_redraw()


## Insert a new joint at graph_pos into conn's joint list, after insert_at.
func add_joint(conn_idx: int, graph_pos: Vector2, insert_at: int) -> void:
	if conn_idx < 0 or conn_idx >= _connections.size():
		return
	var conn: Dictionary = _connections[conn_idx]
	var joints: Array = conn.get("joints", []).duplicate()
	joints.insert(insert_at, [graph_pos.x, graph_pos.y])
	conn["joints"] = joints
	_connections[conn_idx] = conn
	_queue_wire_redraw()


## Remove a joint from a connection.
func remove_joint(conn_idx: int, joint_idx: int) -> void:
	if conn_idx < 0 or conn_idx >= _connections.size():
		return
	var conn: Dictionary = _connections[conn_idx]
	var joints: Array = conn.get("joints", []).duplicate()
	if joint_idx >= 0 and joint_idx < joints.size():
		joints.remove_at(joint_idx)
	conn["joints"] = joints
	_connections[conn_idx] = conn
	_queue_wire_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if _graph == null or not is_instance_valid(_graph): return
	if not _graph.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	if event is InputEventKey and event.pressed:
		var ke := event as InputEventKey
		if ke.keycode == KEY_A and ke.shift_pressed and not ke.ctrl_pressed:
			_palette_pos = _graph.get_local_mouse_position() + _graph.scroll_offset
			_open_node_palette()
			get_viewport().set_input_as_handled()
		elif ke.ctrl_pressed and ke.keycode == KEY_C:
			_copy_selection()
			get_viewport().set_input_as_handled()
		elif ke.ctrl_pressed and ke.keycode == KEY_V:
			_paste_selection()
			get_viewport().set_input_as_handled()

