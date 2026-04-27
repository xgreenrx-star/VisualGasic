@tool
extends Window
## VG Hex Editor — fully editable hex + ASCII + text editor

# =============================================================================
# INNER: SyntaxHighlighter that dims text beyond the hex-visible range
# =============================================================================

class _HexTextHighlighter extends SyntaxHighlighter:
	var vis_len : int = 0
	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		if vis_len <= 0:
			return {}
		return {
			0:       {"color": Color(0.0,  0.0,  0.0)},
			vis_len: {"color": Color(0.55, 0.55, 0.55)},
		}
##
## Interaction model:
##   • Click hex/ASCII cell to position cursor (Tab switches panels)
##   • Left-drag to select a range of bytes
##   • Type two hex digits to overwrite byte (hex panel)
##   • Type printable ASCII character to overwrite byte (ASCII panel)
##   • Arrow / Home / End / PgUp / PgDn navigate; Shift extends selection
##   • Ctrl+A select all; Ctrl+C copy as hex; Ctrl+V paste hex
##   • Right-click → context menu (Copy Hex / C Array / Python / Paste / Fill / Bookmark / Go to)
##   • Insert toggles Insert / Overwrite mode
##   • Ctrl+S save; Ctrl+Z undo; Ctrl+Y redo
##   • Ctrl+F find bar; Find & Replace row below; F3 / Shift+F3 cycle results
##   • Ctrl+G go to offset; Ctrl+O open; Ctrl+B add bookmark; Escape close
##   • F2 / Shift+F2 cycle forward/backward through bookmarks
##   • Column width selector: 8 / 16 / 32 bytes per row
##   • Data Inspector (status bar row 2) — LE/BE toggle button
##   • Selection size shown in status bar when bytes are selected
##   • ⇔ Compare toolbar button — diff highlights bytes that differ from a second file
##   • # Hash toolbar button — CRC-32 / MD5 / SHA-1 / SHA-256 of file or selection
##   • 🎨 Highlight toolbar button — color-code user-defined byte patterns
##   • 🔖 Bookmarks toolbar menu — named offsets; F2/Shift+F2 to cycle
##   • Recent files in 📂 Open button dropdown

# =============================================================================
# CONSTANTS
# =============================================================================

const MAX_FILE_BYTES : int    = 256 * 1024 * 1024
const MAX_RECENT     : int    = 10
const RECENT_FILE    : String = "user://vg_hex_recent.txt"

# ── VB6 classic Windows IDE colour palette ──────────────────────────────────
const C_BG           := Color("#F8F8F8")   # Win32 window background
const C_ADDR         := Color("#000080")   # navy — address / offset column
const C_HDR          := Color("#606060")   # gray  — column-header text
const C_NORMAL       := Color("#000000")   # black — normal bytes
const C_NULL         := Color("#888888")   # gray   — null bytes
const C_ASCII_RNG    := Color("#000080")   # navy  — printable ASCII range (hex)
const C_HIGH         := Color("#800000")   # maroon — high bytes (0x80–0xFF)
const C_ASCII_PRINT  := Color("#000080")   # navy  — printable ASCII chars
const C_ASCII_DOT    := Color("#999999")   # gray  — non-printable dots
const C_CURSOR_HEX   := Color("#000080")   # navy cursor bg
const C_CURSOR_ASCII := Color("#000080")   # navy cursor bg
const C_CURSOR_TXT   := Color("#FFFFFF")   # white text on cursor
const C_SEL_BG       := Color("#000080")   # classic Windows blue selection
const C_HIT_BG       := Color("#CC6600")   # orange-brown search highlight
const C_HIT_TXT      := Color("#FFFFFF")   # white on search hit
const C_DIRTY        := Color("#CC0000")   # red — modified / unsaved bytes
const C_GRID         := Color("#C8C8C8")   # light gray grid lines
const C_CURSOR_LINE  := Color("#DDE8FB")   # very-light-blue cursor row
const C_CMP_DIFF     := Color("#8B0000")   # dark red — compare diff
const C_BOOKMARK     := Color("#DAA520")   # goldenrod bookmark tick
const C_VB_HEADER    := Color(0.58, 0.58, 0.62)  # VB6 panel title-bar gray

# =============================================================================
# LAYOUT STATE
# =============================================================================

var _bytes_per_row : int   = 16
var _char_w        : float = 8.0
var _char_h        : float = 16.0
var _addr_x        : float = 4.0
var _hex_x         : float = 80.0
var _asc_x         : float = 0.0
var _cell_w        : float = 24.0
var _rows_visible  : int   = 32

# =============================================================================
# FILE STATE
# =============================================================================

var _file_path    : String          = ""
var _file_data    : PackedByteArray = PackedByteArray()
var _dirty_set    : Dictionary      = {}
var _undo_stack   : Array           = []
var _redo_stack   : Array           = []
var _modified     : bool            = false
var _recent_files : Array           = []   # Array of String

# =============================================================================
# VIEW / EDIT STATE
# =============================================================================

var _scroll_row  : int  = 0
var _cursor      : int  = 0
var _cursor_nib  : int  = 0
var _in_ascii    : bool = false
var _sel_start   : int  = -1
var _sel_end     : int  = -1
var _sel_anchor  : int  = -1
var _insert_mode : bool = false
var _pending_nib : int  = -1

var _search_offsets : Array[int] = []
var _search_len     : int        = 0
var _cur_result     : int        = -1
var _dragging       : bool       = false

# ── Feature: Endianness toggle ────────────────────────────────────────────────
var _be_mode        : bool       = false

# ── Feature: File compare ─────────────────────────────────────────────────────
var _cmp_data       : PackedByteArray = PackedByteArray()
var _cmp_path       : String          = ""

# ── Feature: Bookmarks ────────────────────────────────────────────────────────
var _bookmarks      : Array           = []   # Array of {off, name}

# ── Feature: Highlight patterns ───────────────────────────────────────────────
# Each entry: {pattern: PackedByteArray, color: Color, label: String}
var _hl_patterns    : Array           = []

# =============================================================================
# UI NODES
# =============================================================================

var _canvas        : Control
var _vscroll       : VScrollBar
var _path_label    : Label
var _mode_label    : Label
var _dirty_label   : Label
var _status_label  : Label
var _interp_label  : Label
var _search_edit   : LineEdit
var _search_mode   : OptionButton
var _find_prev_btn : Button
var _find_next_btn : Button
var _result_label  : Label
var _open_menu_btn    : MenuButton
var _col_btn          : OptionButton
var _context_menu     : PopupMenu
var _file_dialog      : FileDialog
var _save_dialog      : FileDialog
var _cmp_dialog       : FileDialog
var _font             : Font
var _font_size        : int    = 13
var _be_btn           : Button
var _hash_btn         : Button
var _bookmark_menu    : MenuButton
var _replace_edit     : LineEdit
var _replace_btn      : Button
var _replace_all_btn  : Button

# ── Text panel (alongside hex view) ──────────────────────────────────────────
var _text_panel            : TextEdit
var _text_updating         : bool = false
var _text_mouse_selecting  : bool = false   # true while mouse drag-select active
var _text_drag_vis_start   : int  = 0       # vis_start snapshot when drag began
var _text_vscroll          : VScrollBar
var _text_highlighter      : _HexTextHighlighter
var _h_split               : HSplitContainer
var _v_split               : VSplitContainer   # vertical split inside text side
var _tv_vb                 : VBoxContainer     # text-panel VBox (top of _v_split)

# =============================================================================
# INIT
# =============================================================================

func _init() -> void:
	title         = "VG Hex Editor"
	min_size      = Vector2i(900, 580)
	size          = Vector2i(1100, 720)
	wrap_controls = true
	close_requested.connect(hide)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	vbox.add_child(_make_toolbar())
	vbox.add_child(_make_search_bar())

	# ── Main content: HSplitContainer (hex left | text right) ────────────────
	_h_split = HSplitContainer.new()
	_h_split.size_flags_vertical        = Control.SIZE_EXPAND_FILL
	_h_split.add_theme_constant_override("separation", 5)
	# Give the hex side most of the space by default; user can drag
	_h_split.split_offset = 0   # will be set once laid out

	# Left side: hex canvas + scrollbar
	var hex_hbox := HBoxContainer.new()
	hex_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hex_hbox.add_theme_constant_override("separation", 0)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_canvas.focus_mode            = Control.FOCUS_ALL
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_on_canvas_resized)
	hex_hbox.add_child(_canvas)

	_vscroll = VScrollBar.new()
	_vscroll.step = 1
	_vscroll.value_changed.connect(_on_scroll)
	hex_hbox.add_child(_vscroll)

	_h_split.add_child(hex_hbox)

	# Right side: VSplitContainer — text panel (top) + future area (bottom)
	_v_split = VSplitContainer.new()
	_v_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_v_split.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_v_split.add_theme_constant_override("separation", 5)

	_tv_vb = VBoxContainer.new()
	_tv_vb.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	_tv_vb.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	_tv_vb.add_theme_constant_override("separation", 0)
	_tv_vb.custom_minimum_size      = Vector2(160, 80)

	var tv_hdr := PanelContainer.new()
	tv_hdr.custom_minimum_size.y = 22
	var tv_hdr_sb := StyleBoxFlat.new()
	tv_hdr_sb.bg_color = C_VB_HEADER
	tv_hdr.add_theme_stylebox_override("panel", tv_hdr_sb)
	var tv_hdr_lbl := Label.new()
	tv_hdr_lbl.text = "  Text View"
	tv_hdr_lbl.add_theme_color_override("font_color", Color.WHITE)
	tv_hdr_lbl.add_theme_font_size_override("font_size", 11)
	tv_hdr.add_child(tv_hdr_lbl)
	_tv_vb.add_child(tv_hdr)

	# Text panel + its own scrollbar in an HBox
	var tv_body := HBoxContainer.new()
	tv_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv_body.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	tv_body.add_theme_constant_override("separation", 0)

	_text_panel = TextEdit.new()
	_text_panel.size_flags_horizontal      = Control.SIZE_EXPAND_FILL
	_text_panel.size_flags_vertical        = Control.SIZE_EXPAND_FILL
	_text_panel.editable                   = true    # must be true for caret to render
	_text_panel.wrap_mode                  = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_panel.scroll_fit_content_height  = false
	_text_panel.context_menu_enabled       = false
	_text_panel.shortcut_keys_enabled      = false
	_text_panel.selecting_enabled          = true   # allow mouse selection
	# Disable TextEdit's own built-in scrollbars — we provide our own
	_text_panel.scroll_past_end_of_file    = false
	_text_panel.gui_input.connect(_on_text_panel_input)
	_text_panel.caret_changed.connect(_on_text_panel_caret_changed)
	tv_body.add_child(_text_panel)

	_text_vscroll = VScrollBar.new()
	_text_vscroll.step = 1
	_text_vscroll.value_changed.connect(_on_scroll)
	tv_body.add_child(_text_vscroll)

	_tv_vb.add_child(tv_body)
	_v_split.add_child(_tv_vb)

	# Bottom panel: placeholder area for future panels below the text view.
	# No minimum height — starts collapsed; user drags divider down to reveal it.
	var tv_bottom := PanelContainer.new()
	var tv_bottom_sb := StyleBoxFlat.new()
	tv_bottom_sb.bg_color = Color("#F0F0F0")
	tv_bottom.add_theme_stylebox_override("panel", tv_bottom_sb)
	_v_split.add_child(tv_bottom)

	_h_split.add_child(_v_split)

	vbox.add_child(_h_split)
	vbox.add_child(_make_status_bar())

	# ── Context menu ──────────────────────────────────────────────────────────
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Select All\tCtrl+A",      10)
	_context_menu.add_separator()
	_context_menu.add_item("Copy as Hex\tCtrl+C",     11)
	_context_menu.add_item("Paste Hex\tCtrl+V",       12)
	_context_menu.add_separator()
	_context_menu.add_item("Fill Selection...",        20)
	_context_menu.add_separator()
	_context_menu.add_item("Go to Offset...\tCtrl+G", 30)
	_context_menu.id_pressed.connect(_on_context_menu_id)
	add_child(_context_menu)

	# ── File dialogs ──────────────────────────────────────────────────────────
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access    = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title     = "Open File — VG Hex Editor"
	_file_dialog.file_selected.connect(open_file)
	add_child(_file_dialog)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access    = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.title     = "Save As — VG Hex Editor"
	_save_dialog.file_selected.connect(_save_to_path)
	add_child(_save_dialog)

	_cmp_dialog = FileDialog.new()
	_cmp_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_cmp_dialog.access    = FileDialog.ACCESS_FILESYSTEM
	_cmp_dialog.title     = "Open File to Compare — VG Hex Editor"
	_cmp_dialog.file_selected.connect(_load_compare_file)
	add_child(_cmp_dialog)


func _make_toolbar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 28

	# Open as MenuButton so we can show recent files
	_open_menu_btn = MenuButton.new()
	_open_menu_btn.text         = "📂 Open"
	_open_menu_btn.tooltip_text = "Open file (Ctrl+O) — click arrow for recent files"
	_open_menu_btn.flat         = true
	_open_menu_btn.get_popup().id_pressed.connect(_on_open_menu_id)
	_open_menu_btn.about_to_popup.connect(_populate_open_menu)
	bar.add_child(_open_menu_btn)

	var save_btn := Button.new()
	save_btn.text         = "💾 Save"
	save_btn.tooltip_text = "Save changes (Ctrl+S)"
	save_btn.flat         = true
	save_btn.pressed.connect(_save_file)
	bar.add_child(save_btn)

	var saveas_btn := Button.new()
	saveas_btn.text = "Save As..."
	saveas_btn.flat = true
	saveas_btn.pressed.connect(_show_save_as_dialog)
	bar.add_child(saveas_btn)

	bar.add_child(VSeparator.new())

	var undo_btn := Button.new()
	undo_btn.text         = "↩ Undo"
	undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	undo_btn.flat         = true
	undo_btn.pressed.connect(_do_undo)
	bar.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text         = "↪ Redo"
	redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	redo_btn.flat         = true
	redo_btn.pressed.connect(_do_redo)
	bar.add_child(redo_btn)

	bar.add_child(VSeparator.new())

	var goto_btn := Button.new()
	goto_btn.text         = "Go To..."
	goto_btn.tooltip_text = "Jump to offset (Ctrl+G)"
	goto_btn.flat         = true
	goto_btn.pressed.connect(_show_goto_dialog)
	bar.add_child(goto_btn)

	bar.add_child(VSeparator.new())

	# Column width selector
	var col_lbl := Label.new()
	col_lbl.text = " Cols:"
	bar.add_child(col_lbl)

	_col_btn = OptionButton.new()
	_col_btn.add_item("8",  8)
	_col_btn.add_item("16", 16)
	_col_btn.add_item("32", 32)
	_col_btn.select(1)   # 16 is default
	_col_btn.custom_minimum_size.x = 56
	_col_btn.item_selected.connect(_on_col_width_selected)
	bar.add_child(_col_btn)

	bar.add_child(VSeparator.new())

	# Compare button
	var cmp_btn := Button.new()
	cmp_btn.text         = "⇔ Compare"
	cmp_btn.tooltip_text = "Compare with another file — differing bytes highlighted red"
	cmp_btn.flat         = true
	cmp_btn.pressed.connect(_show_compare_dialog)
	bar.add_child(cmp_btn)

	var cmp_clear_btn := Button.new()
	cmp_clear_btn.text         = "✕ Diff"
	cmp_clear_btn.tooltip_text = "Clear file comparison"
	cmp_clear_btn.flat         = true
	cmp_clear_btn.pressed.connect(_clear_compare)
	bar.add_child(cmp_clear_btn)

	bar.add_child(VSeparator.new())

	# Hash / checksum button
	_hash_btn = Button.new()
	_hash_btn.text         = "# Hash"
	_hash_btn.tooltip_text = "Show CRC32 / MD5 / SHA-256 of file or selection"
	_hash_btn.flat         = true
	_hash_btn.pressed.connect(_show_hash_dialog)
	bar.add_child(_hash_btn)

	bar.add_child(VSeparator.new())

	# Highlight patterns button
	var hl_btn := Button.new()
	hl_btn.text         = "🎨 Highlight"
	hl_btn.tooltip_text = "Add/remove byte-pattern highlights"
	hl_btn.flat         = true
	hl_btn.pressed.connect(_show_highlight_dialog)
	bar.add_child(hl_btn)

	bar.add_child(VSeparator.new())

	# Bookmarks menu
	_bookmark_menu = MenuButton.new()
	_bookmark_menu.text         = "🔖 Bookmarks"
	_bookmark_menu.tooltip_text = "Bookmarks (Ctrl+B to add, F2/Shift+F2 to cycle)"
	_bookmark_menu.flat         = true
	_bookmark_menu.get_popup().id_pressed.connect(_on_bookmark_menu_id)
	_bookmark_menu.about_to_popup.connect(_populate_bookmark_menu)
	bar.add_child(_bookmark_menu)

	bar.add_child(VSeparator.new())

	_path_label = Label.new()
	_path_label.text                    = "(no file)"
	_path_label.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	_path_label.clip_text               = true
	bar.add_child(_path_label)

	_dirty_label = Label.new()
	_dirty_label.text                      = ""
	_dirty_label.add_theme_color_override("font_color", Color("#FF6B6B"))
	_dirty_label.custom_minimum_size.x     = 80
	_dirty_label.horizontal_alignment      = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_dirty_label)

	return bar


func _make_search_bar() -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)

	# ── Find row ──────────────────────────────────────────────────────────────
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 26

	var lbl := Label.new()
	lbl.text = "Find:"
	bar.add_child(lbl)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text      = 'hex: "FF D8 FF"  or  ASCII text'
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.clear_button_enabled  = true
	_search_edit.text_submitted.connect(func(_t): _run_search())
	bar.add_child(_search_edit)

	_search_mode = OptionButton.new()
	_search_mode.add_item("Hex")
	_search_mode.add_item("ASCII")
	_search_mode.custom_minimum_size.x = 74
	bar.add_child(_search_mode)

	var go_btn := Button.new()
	go_btn.text = "Search"
	go_btn.flat = true
	go_btn.pressed.connect(_run_search)
	bar.add_child(go_btn)

	_find_prev_btn = Button.new()
	_find_prev_btn.text         = "◀"
	_find_prev_btn.tooltip_text = "Previous match (Shift+F3)"
	_find_prev_btn.flat         = true
	_find_prev_btn.disabled     = true
	_find_prev_btn.pressed.connect(_prev_result)
	bar.add_child(_find_prev_btn)

	_find_next_btn = Button.new()
	_find_next_btn.text         = "▶"
	_find_next_btn.tooltip_text = "Next match (F3)"
	_find_next_btn.flat         = true
	_find_next_btn.disabled     = true
	_find_next_btn.pressed.connect(_next_result)
	bar.add_child(_find_next_btn)

	_result_label = Label.new()
	_result_label.text                 = ""
	_result_label.custom_minimum_size.x = 100
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_result_label)

	outer.add_child(bar)

	# ── Replace row ───────────────────────────────────────────────────────────
	var rep_bar := HBoxContainer.new()
	rep_bar.custom_minimum_size.y = 24

	var rep_lbl := Label.new()
	rep_lbl.text                  = "Replace:"
	rep_lbl.custom_minimum_size.x = 46
	rep_bar.add_child(rep_lbl)

	_replace_edit = LineEdit.new()
	_replace_edit.placeholder_text      = "hex bytes to replace with"
	_replace_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replace_edit.clear_button_enabled  = true
	_replace_edit.text_submitted.connect(func(_t): _replace_next())
	rep_bar.add_child(_replace_edit)

	_replace_btn = Button.new()
	_replace_btn.text         = "Replace"
	_replace_btn.tooltip_text = "Replace current match"
	_replace_btn.flat         = true
	_replace_btn.disabled     = true
	_replace_btn.pressed.connect(_replace_next)
	rep_bar.add_child(_replace_btn)

	_replace_all_btn = Button.new()
	_replace_all_btn.text         = "Replace All"
	_replace_all_btn.tooltip_text = "Replace all matches"
	_replace_all_btn.flat         = true
	_replace_all_btn.disabled     = true
	_replace_all_btn.pressed.connect(_replace_all)
	rep_bar.add_child(_replace_all_btn)

	outer.add_child(rep_bar)

	return outer


func _make_status_bar() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)

	# Row 1 — offset / value / size / selection count / mode
	var row1 := HBoxContainer.new()
	row1.custom_minimum_size.y = 20

	_status_label = Label.new()
	_status_label.text                    = "Offset: —   Value: —"
	_status_label.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 11)
	row1.add_child(_status_label)

	_mode_label = Label.new()
	_mode_label.text                    = "OVR"
	_mode_label.custom_minimum_size.x   = 40
	_mode_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 11)
	row1.add_child(_mode_label)

	# Endianness toggle button
	_be_btn = Button.new()
	_be_btn.text                  = "LE"
	_be_btn.tooltip_text          = "Toggle Data Inspector endianness (Little-Endian / Big-Endian)"
	_be_btn.flat                  = true
	_be_btn.custom_minimum_size.x = 32
	_be_btn.add_theme_font_size_override("font_size", 10)
	_be_btn.pressed.connect(_toggle_endian)
	row1.add_child(_be_btn)

	vb.add_child(row1)

	# Row 2 — data type interpretation
	var row2 := HBoxContainer.new()
	row2.custom_minimum_size.y = 18

	_interp_label = Label.new()
	_interp_label.text                  = ""
	_interp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interp_label.add_theme_font_size_override("font_size", 10)
	_interp_label.add_theme_color_override("font_color", Color("#9A9A9A"))
	_interp_label.clip_text             = true
	row2.add_child(_interp_label)

	vb.add_child(row2)

	return vb


func _ready() -> void:
	_font = get_theme_font("source", "EditorFonts")
	if not _font:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Courier New", "Courier", "Liberation Mono", "monospace"])
		_font = sf

	# ── Syntax highlighter: normal text black, beyond-visible range gray ──────
	_text_highlighter = _HexTextHighlighter.new()
	_text_panel.syntax_highlighter = _text_highlighter

	# Hide TextEdit's own built-in scrollbars — we drive it via _text_vscroll
	_text_panel.add_theme_constant_override("v_scroll_speed", 0)
	_text_panel.scroll_vertical = 0

	# ── Text panel: override Godot editor dark theme with VB6 white/black ────
	var te_sb := StyleBoxFlat.new()
	te_sb.bg_color              = Color("#FFFFFF")
	te_sb.border_width_left     = 1
	te_sb.border_width_top      = 1
	te_sb.border_width_right    = 1
	te_sb.border_width_bottom   = 1
	te_sb.border_color          = Color("#A0A0A0")
	te_sb.content_margin_left   = 4.0
	te_sb.content_margin_top    = 2.0
	te_sb.content_margin_right  = 4.0
	te_sb.content_margin_bottom = 2.0
	_text_panel.add_theme_stylebox_override("normal",    te_sb)
	_text_panel.add_theme_stylebox_override("focus",     te_sb)
	_text_panel.add_theme_stylebox_override("read_only", te_sb)
	_text_panel.add_theme_color_override("font_color",            Color("#000000"))
	_text_panel.add_theme_color_override("font_readonly_color",   Color("#000000"))
	_text_panel.add_theme_color_override("background_color",      Color("#FFFFFF"))
	_text_panel.add_theme_color_override("caret_color",           Color("#000080"))
	_text_panel.add_theme_color_override("selection_color",       Color("#000080"))
	_text_panel.add_theme_color_override("font_selected_color",   Color("#FFFFFF"))
	if _font:
		_text_panel.add_theme_font_override("font",           _font)
		_text_panel.add_theme_font_size_override("font_size", _font_size)

	# ── Find / Replace LineEdits: override Godot editor dark theme ────────────
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color              = Color("#FFFFFF")
	le_sb.border_width_left     = 1
	le_sb.border_width_top      = 1
	le_sb.border_width_right    = 1
	le_sb.border_width_bottom   = 1
	le_sb.border_color          = Color("#808080")
	le_sb.content_margin_left   = 4.0
	le_sb.content_margin_top    = 2.0
	le_sb.content_margin_right  = 4.0
	le_sb.content_margin_bottom = 2.0
	var le_focus_sb := StyleBoxFlat.new()
	le_focus_sb.bg_color              = Color("#FFFFFF")
	le_focus_sb.border_width_left     = 1
	le_focus_sb.border_width_top      = 1
	le_focus_sb.border_width_right    = 1
	le_focus_sb.border_width_bottom   = 1
	le_focus_sb.border_color          = Color("#000080")
	le_focus_sb.content_margin_left   = 4.0
	le_focus_sb.content_margin_top    = 2.0
	le_focus_sb.content_margin_right  = 4.0
	le_focus_sb.content_margin_bottom = 2.0
	for le : LineEdit in [_search_edit, _replace_edit]:
		le.add_theme_stylebox_override("normal",    le_sb)
		le.add_theme_stylebox_override("focus",     le_focus_sb)
		le.add_theme_stylebox_override("read_only", le_sb)
		le.add_theme_color_override("font_color",             Color("#000000"))
		le.add_theme_color_override("font_placeholder_color", Color("#707070"))
		le.add_theme_color_override("caret_color",            Color("#000080"))
		le.add_theme_color_override("selection_color",        Color("#000080"))

	_recalc_metrics()
	_update_scrollbar()
	_load_recent_files()
	# Set default split: text panel gets ~260 px, hex gets the rest
	call_deferred("_set_default_split")
	call_deferred("_sync_text_panel")


func _set_default_split() -> void:
	# split_offset is measured from left edge; negative = from right edge
	# Give the text panel a starting width of ~260, rest goes to hex
	if _h_split and _h_split.size.x > 0:
		_h_split.split_offset = int(_h_split.size.x) - 265
	# Collapse the bottom placeholder — use a very large offset so Godot clamps to max
	if _v_split:
		_v_split.split_offset = 99999


func _recalc_metrics() -> void:
	if not _font:
		return
	_char_w = _font.get_char_size(0x4D, _font_size).x   # 'M'
	_char_h = _font.get_height(_font_size) + 2.0
	_addr_x = 4.0
	_hex_x  = _addr_x + _char_w * 10.0
	_cell_w = _char_w * 3.0
	_asc_x  = _hex_x + _char_w * (_bytes_per_row * 3 + 2)
	_recalc_rows_visible()


func _recalc_rows_visible() -> void:
	if _canvas.size.y <= 0:
		return
	_rows_visible = max(1, int((_canvas.size.y - _char_h) / _char_h))


func _on_canvas_resized() -> void:
	_recalc_rows_visible()
	_update_scrollbar()
	_canvas.queue_redraw()
	_sync_text_panel()

# =============================================================================
# COLUMN WIDTH
# =============================================================================

func _on_col_width_selected(idx: int) -> void:
	_bytes_per_row = _col_btn.get_item_id(idx)
	_cursor        = clamp(_cursor, 0, max(0, _file_data.size() - 1))
	_scroll_row    = _cursor / _bytes_per_row if _bytes_per_row > 0 else 0
	_recalc_metrics()
	_update_scrollbar()
	_canvas.queue_redraw()
	_sync_text_panel()

# =============================================================================
# PUBLIC API
# =============================================================================

func open_file(path: String) -> void:
	var abs := path
	if path.begins_with("res://"):
		abs = ProjectSettings.globalize_path(path)

	var fa := FileAccess.open(abs, FileAccess.READ)
	if not fa:
		_path_label.text = "⚠ Cannot open: " + path.get_file()
		push_warning("VGHexEditor: cannot open '%s'" % abs)
		return

	var sz := fa.get_length()
	if sz > MAX_FILE_BYTES:
		fa.close()
		_path_label.text = "⚠ File too large (> 256 MB)"
		return

	_file_data = fa.get_buffer(sz)
	fa.close()

	_file_path = path
	_dirty_set.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_modified        = false
	_cursor          = 0
	_cursor_nib      = 0
	_in_ascii        = false
	_sel_start       = -1
	_sel_end         = -1
	_sel_anchor      = -1
	_scroll_row      = 0
	_pending_nib     = -1
	_search_offsets.clear()
	_search_len      = 0
	_cur_result      = -1
	_result_label.text      = ""
	_find_prev_btn.disabled = true
	_find_next_btn.disabled = true
	_replace_btn.disabled     = true
	_replace_all_btn.disabled = true

	# Clear compare diff on new file load
	_cmp_data.clear()
	_cmp_path = ""

	title = "VG Hex Editor — " + path.get_file()
	_path_label.text  = path
	_dirty_label.text = ""
	_add_recent_file(path)
	_update_status()
	_update_scrollbar()
	_canvas.queue_redraw()
	_sync_text_panel()


func open_with_dialog() -> void:
	_show_open_dialog()

# =============================================================================
# DRAWING
# =============================================================================

func _on_canvas_draw() -> void:
	if not _font:
		return

	var cw  : float = _canvas.size.x
	var ch  : float = _canvas.size.y
	var mid : int   = _bytes_per_row / 2

	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), C_BG)

	if _file_data.is_empty():
		_canvas.draw_string(_font, Vector2(_hex_x, _char_h),
			"(no file — use 📂 Open)", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, C_HDR)
		return

	var total_rows : int = int(ceil(float(_file_data.size()) / _bytes_per_row))

	# Build search-hit set for the visible range
	var vis_start : int = _scroll_row * _bytes_per_row
	var vis_end   : int = mini(vis_start + (_rows_visible + 1) * _bytes_per_row, _file_data.size())
	var hit_set   : Dictionary = {}
	for off_h : int in _search_offsets:
		if off_h + _search_len > vis_start and off_h < vis_end:
			for k : int in range(_search_len):
				var bo : int = off_h + k
				if bo >= vis_start and bo < vis_end:
					hit_set[bo] = true

	# Build highlight-pattern color map {offset: Color}
	var hl_map : Dictionary = {}
	for pat_entry in _hl_patterns:
		var pat    : PackedByteArray = pat_entry["pattern"]
		var pcol   : Color           = pat_entry["color"]
		var plen   : int             = pat.size()
		if plen == 0:
			continue
		var file_hex : String = _file_data.hex_encode()
		var pat_hex  : String = pat.hex_encode()
		var pos      : int    = 0
		while true:
			var found : int = file_hex.find(pat_hex, pos)
			if found < 0:
				break
			if found % 2 == 0:
				var start_off : int = found / 2
				for k2 in range(plen):
					hl_map[start_off + k2] = pcol
			pos = found + 2

	# Build compare-diff set
	var cmp_set : Dictionary = {}
	if not _cmp_data.is_empty():
		for ci in range(mini(_file_data.size(), _cmp_data.size())):
			if _file_data[ci] != _cmp_data[ci]:
				cmp_set[ci] = true
		# bytes beyond the shorter file are all "different"
		for ci in range(_cmp_data.size(), _file_data.size()):
			cmp_set[ci] = true

	# Build bookmark set for quick lookup
	var bm_set : Dictionary = {}
	for bm in _bookmarks:
		bm_set[bm["off"]] = true

	# Header row
	var hy : float = _char_h - 2.0
	_canvas.draw_string(_font, Vector2(_addr_x, hy),
		"  Offset  ", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, C_HDR)
	for col in range(_bytes_per_row):
		var xh : float = _hex_x + col * _cell_w + (1.0 if col >= mid else 0.0) * _char_w
		_canvas.draw_string(_font, Vector2(xh, hy), "%02X " % col,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, C_HDR)
		_canvas.draw_string(_font, Vector2(_asc_x + col * _char_w, hy),
			"%X" % (col % 16), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, C_HDR)
	_canvas.draw_line(Vector2(0.0, _char_h), Vector2(cw, _char_h), C_GRID, 1.0)

	# Data rows
	var cursor_row : int = _cursor / _bytes_per_row
	for r in range(_rows_visible + 1):
		var row : int = _scroll_row + r
		if row >= total_rows:
			break
		var y       : float = _char_h + r * _char_h + _char_h - 2.0
		var row_off : int   = row * _bytes_per_row

		if row == cursor_row:
			_canvas.draw_rect(Rect2(0.0, _char_h + r * _char_h, cw, _char_h), C_CURSOR_LINE)

		_canvas.draw_string(_font, Vector2(_addr_x, y), "%08X" % row_off,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, C_ADDR)

		# Bookmark gutter tick — small gold bar on left edge
		for col_bm in range(_bytes_per_row):
			var off_bm : int = row_off + col_bm
			if bm_set.has(off_bm):
				var bm_x : float = _hex_x + col_bm * _cell_w + (1.0 if col_bm >= mid else 0.0) * _char_w
				_canvas.draw_rect(Rect2(bm_x - 1.0, _char_h + r * _char_h, 3.0, _char_h), C_BOOKMARK)

		for col in range(_bytes_per_row):
			var off : int   = row_off + col
			if off >= _file_data.size():
				break
			var b   : int   = _file_data[off]
			var xh  : float = _hex_x + col * _cell_w + (1.0 if col >= mid else 0.0) * _char_w
			var xa  : float = _asc_x + col * _char_w
			var ry  : float = _char_h + r * _char_h

			var is_cursor  : bool  = off == _cursor
			var in_sel     : bool  = _sel_start >= 0 and off >= _sel_start and off <= _sel_end
			var in_hit     : bool  = hit_set.has(off)
			var is_dirty_b : bool  = _dirty_set.has(off)
			var in_cmp     : bool  = cmp_set.has(off)
			var hl_color   : Color = hl_map.get(off, Color.TRANSPARENT)
			var has_hl     : bool  = hl_color.a > 0.0

			# ── Hex cell background ──
			if is_cursor and not _in_ascii:
				_canvas.draw_rect(Rect2(xh - 1.0, ry, _cell_w, _char_h), C_CURSOR_HEX)
			elif in_sel:
				_canvas.draw_rect(Rect2(xh - 1.0, ry, _cell_w, _char_h), C_SEL_BG)
			elif in_hit:
				_canvas.draw_rect(Rect2(xh - 1.0, ry, _cell_w, _char_h), C_HIT_BG)
			elif has_hl:
				_canvas.draw_rect(Rect2(xh - 1.0, ry, _cell_w, _char_h), hl_color.darkened(0.4))
			elif in_cmp:
				_canvas.draw_rect(Rect2(xh - 1.0, ry, _cell_w, _char_h), C_CMP_DIFF)

			# ── Hex cell text ──
			var tc_hex : Color
			if is_cursor and not _in_ascii:
				tc_hex = C_CURSOR_TXT
			elif in_sel or in_hit:
				tc_hex = C_HIT_TXT
			elif is_dirty_b:
				tc_hex = C_DIRTY
			elif has_hl:
				tc_hex = hl_color
			elif in_cmp:
				tc_hex = Color("#FF8080")
			else:
				tc_hex = _byte_color(b)
			_canvas.draw_string(_font, Vector2(xh, y), "%02X" % b,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, tc_hex)

			# Pending nibble indicator
			if is_cursor and not _in_ascii and _pending_nib >= 0:
				_canvas.draw_string(_font, Vector2(xh, y), "%X_" % _pending_nib,
					HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, Color("#FFCC00"))

			# ── ASCII cell background ──
			if is_cursor and _in_ascii:
				_canvas.draw_rect(Rect2(xa, ry, _char_w, _char_h), C_CURSOR_ASCII)
			elif in_sel:
				_canvas.draw_rect(Rect2(xa, ry, _char_w, _char_h), C_SEL_BG)
			elif in_hit:
				_canvas.draw_rect(Rect2(xa, ry, _char_w, _char_h), C_HIT_BG)
			elif has_hl:
				_canvas.draw_rect(Rect2(xa, ry, _char_w, _char_h), hl_color.darkened(0.4))
			elif in_cmp:
				_canvas.draw_rect(Rect2(xa, ry, _char_w, _char_h), C_CMP_DIFF)

			# ── ASCII cell text ──
			var achar  : String
			var tc_asc : Color
			if b >= 0x20 and b <= 0x7E:
				achar = char(b)
				if is_cursor and _in_ascii:
					tc_asc = C_CURSOR_TXT
				elif in_sel or in_hit:
					tc_asc = C_HIT_TXT
				elif is_dirty_b:
					tc_asc = C_DIRTY
				elif has_hl:
					tc_asc = hl_color
				elif in_cmp:
					tc_asc = Color("#FF8080")
				else:
					tc_asc = C_ASCII_PRINT
			else:
				achar  = "."
				tc_asc = C_CURSOR_TXT if (is_cursor and _in_ascii) else C_ASCII_DOT
			_canvas.draw_string(_font, Vector2(xa, y), achar,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, tc_asc)

	# Separators: left border of ASCII panel, right border of ASCII panel
	var sx         : float = _asc_x - _char_w * 0.5
	var sx_right   : float = _asc_x + _bytes_per_row * _char_w + _char_w * 0.5
	_canvas.draw_line(Vector2(sx,       _char_h), Vector2(sx,       ch), C_GRID, 1.0)
	_canvas.draw_line(Vector2(sx_right, _char_h), Vector2(sx_right, ch), C_GRID, 1.0)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _on_canvas_input(event: InputEvent) -> void:
	if _file_data.is_empty():
		return

	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var hit : int = _hit_test(mm.position)
		if hit >= 0:
			_cursor    = hit
			_sel_start = mini(_sel_anchor, hit)
			_sel_end   = maxi(_sel_anchor, hit)
			_in_ascii  = _is_ascii_hit(mm.position)
			_update_status()
			_canvas.queue_redraw()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if not me.pressed:
			if me.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
			return
		match me.button_index:
			MOUSE_BUTTON_LEFT:
				_canvas.grab_focus()
				var hit : int = _hit_test(me.position)
				if hit >= 0:
					if me.shift_pressed and _sel_anchor >= 0:
						_sel_start = mini(_sel_anchor, hit)
						_sel_end   = maxi(_sel_anchor, hit)
					else:
						_sel_anchor = hit
						_sel_start  = -1
						_sel_end    = -1
						_dragging   = true
					_cursor      = hit
					_cursor_nib  = 0
					_pending_nib = -1
					_in_ascii    = _is_ascii_hit(me.position)
					_update_status()
					_canvas.queue_redraw()

			MOUSE_BUTTON_RIGHT:
				_canvas.grab_focus()
				var hit : int = _hit_test(me.position)
				if hit >= 0 and (_sel_start < 0 or hit < _sel_start or hit > _sel_end):
					_cursor      = hit
					_sel_start   = -1
					_sel_end     = -1
					_sel_anchor  = -1
					_pending_nib = -1
				_show_context_menu(me.global_position)
				_canvas.queue_redraw()

			MOUSE_BUTTON_WHEEL_UP:
				_scroll_row    = maxi(0, _scroll_row - 3)
				_vscroll.value = _scroll_row
				_canvas.queue_redraw()
				get_viewport().set_input_as_handled()

			MOUSE_BUTTON_WHEEL_DOWN:
				var total_rows : int = int(ceil(float(_file_data.size()) / _bytes_per_row))
				_scroll_row    = mini(total_rows - 1, _scroll_row + 3)
				_vscroll.value = _scroll_row
				_canvas.queue_redraw()
				get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var ke := event as InputEventKey

	if _handle_navigation(ke):
		_canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _handle_edit(ke):
		_canvas.queue_redraw()
		get_viewport().set_input_as_handled()


func _hit_test(pos: Vector2) -> int:
	if _file_data.is_empty() or pos.y < _char_h:
		return -1
	var row : int = _scroll_row + int((pos.y - _char_h) / _char_h)
	var col : int = -1
	var mid : int = _bytes_per_row / 2
	if pos.x >= _hex_x and pos.x < _asc_x - _char_w * 0.5:
		var rx      : float = pos.x - _hex_x
		var raw_col : int   = int(rx / _cell_w)
		if raw_col >= mid:
			rx      -= _char_w
			raw_col  = int(rx / _cell_w)
		col = clamp(raw_col, 0, _bytes_per_row - 1)
	elif pos.x >= _asc_x:
		col = clamp(int((pos.x - _asc_x) / _char_w), 0, _bytes_per_row - 1)
	if col < 0:
		return -1
	var off : int = row * _bytes_per_row + col
	if off < 0 or off >= _file_data.size():
		return -1
	return off


func _is_ascii_hit(pos: Vector2) -> bool:
	return pos.x >= _asc_x


func _handle_navigation(ke: InputEventKey) -> bool:
	var sz : int = _file_data.size()
	if sz == 0:
		return false
	var old : int = _cursor
	match ke.keycode:
		KEY_LEFT:
			if _cursor > 0: _cursor -= 1
			_cursor_nib = 0; _pending_nib = -1
		KEY_RIGHT:
			if _cursor < sz - 1: _cursor += 1
			_cursor_nib = 0; _pending_nib = -1
		KEY_UP:
			if _cursor >= _bytes_per_row: _cursor -= _bytes_per_row
			_cursor_nib = 0; _pending_nib = -1
		KEY_DOWN:
			if _cursor + _bytes_per_row < sz: _cursor += _bytes_per_row
			_cursor_nib = 0; _pending_nib = -1
		KEY_HOME:
			_cursor = 0 if ke.ctrl_pressed else (_cursor / _bytes_per_row) * _bytes_per_row
			_cursor_nib = 0; _pending_nib = -1
		KEY_END:
			if ke.ctrl_pressed:
				_cursor = sz - 1
			else:
				_cursor = mini((_cursor / _bytes_per_row) * _bytes_per_row + _bytes_per_row - 1, sz - 1)
			_cursor_nib = 0; _pending_nib = -1
		KEY_PAGEUP:
			_cursor = maxi(0, _cursor - _rows_visible * _bytes_per_row)
			_cursor_nib = 0; _pending_nib = -1
		KEY_PAGEDOWN:
			_cursor = mini(sz - 1, _cursor + _rows_visible * _bytes_per_row)
			_cursor_nib = 0; _pending_nib = -1
		KEY_TAB:
			_in_ascii   = not _in_ascii
			_cursor_nib = 0; _pending_nib = -1
		_:
			return false

	var arrow_keys : Array = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
							  KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN]
	if ke.shift_pressed and ke.keycode in arrow_keys:
		if _sel_anchor < 0: _sel_anchor = old
		_sel_start = mini(_sel_anchor, _cursor)
		_sel_end   = maxi(_sel_anchor, _cursor)
	elif ke.keycode != KEY_TAB:
		_sel_start  = -1
		_sel_end    = -1
		_sel_anchor = -1

	_scroll_to_cursor()
	_update_status()
	return true


func _handle_edit(ke: InputEventKey) -> bool:
	if ke.ctrl_pressed:
		match ke.keycode:
			KEY_S: _save_file();            return true
			KEY_Z: _do_undo();              return true
			KEY_Y: _do_redo();              return true
			KEY_A:
				_sel_anchor = 0
				_sel_start  = 0
				_sel_end    = _file_data.size() - 1
				return true
			KEY_C: _copy_selection();       return true
			KEY_V: _paste_from_clipboard(); return true
			KEY_F:
				_search_edit.grab_focus()
				_search_edit.select_all()
				return true
			KEY_G: _show_goto_dialog();     return true
			KEY_O: _show_open_dialog();     return true
			KEY_B: _add_bookmark(_cursor);  return true
		return false

	match ke.keycode:
		KEY_ESCAPE: hide(); return true
		KEY_INSERT:
			_insert_mode     = not _insert_mode
			_mode_label.text = "INS" if _insert_mode else "OVR"
			return true
		KEY_DELETE:
			if _insert_mode and _cursor < _file_data.size():
				_delete_byte_at(_cursor); return true
			return false
		KEY_BACKSPACE:
			if _insert_mode and _cursor > 0:
				_cursor -= 1; _delete_byte_at(_cursor); return true
			return false
		KEY_F2:
			if ke.shift_pressed:
				_cycle_bookmark(-1)
			else:
				_cycle_bookmark(1)
			return true
		KEY_F3:
			if ke.shift_pressed:
				_prev_result()
			else:
				_next_result()
			return true

	if not _in_ascii:
		var nib : int = _keycode_to_hex(ke)
		if nib >= 0:
			_type_hex_nibble(nib)
			return true

	if _in_ascii:
		var uch : int = ke.unicode
		if uch >= 0x20 and uch <= 0x7E:
			_write_byte(_cursor, uch)
			if _cursor + 1 < _file_data.size(): _cursor += 1
			_scroll_to_cursor()
			return true

	return false


func _keycode_to_hex(ke: InputEventKey) -> int:
	var kc : int = ke.keycode
	if kc >= KEY_0  and kc <= KEY_9:   return kc - KEY_0
	if kc >= KEY_A  and kc <= KEY_F:   return 10 + (kc - KEY_A)
	if kc >= KEY_KP_0 and kc <= KEY_KP_9: return kc - KEY_KP_0
	return -1


func _type_hex_nibble(nib: int) -> void:
	if _pending_nib < 0:
		_pending_nib = nib
	else:
		_write_byte(_cursor, (_pending_nib << 4) | nib)
		_pending_nib = -1
		if _cursor + 1 < _file_data.size(): _cursor += 1
		_scroll_to_cursor()
	_update_status()

# =============================================================================
# CONTEXT MENU
# =============================================================================

func _show_context_menu(screen_pos: Vector2) -> void:
	var has_sel : bool = _sel_start >= 0 and _sel_end >= _sel_start
	var fill_idx : int = _context_menu.get_item_index(20)
	_context_menu.set_item_disabled(fill_idx, not has_sel)
	_context_menu.set_item_disabled(_context_menu.get_item_index(11), _file_data.is_empty())
	_context_menu.set_item_disabled(_context_menu.get_item_index(13), _file_data.is_empty())
	_context_menu.set_item_disabled(_context_menu.get_item_index(14), _file_data.is_empty())
	_context_menu.popup(Rect2i(int(screen_pos.x), int(screen_pos.y), 0, 0))


func _on_context_menu_id(id: int) -> void:
	match id:
		10:   # Select All
			_sel_anchor = 0
			_sel_start  = 0
			_sel_end    = _file_data.size() - 1
			_canvas.queue_redraw()
		11:   # Copy as Hex
			_copy_selection()
		12:   # Paste Hex
			_paste_from_clipboard()
		13:   # Copy as C array
			_copy_as_c_array()
		14:   # Copy as Python bytes
			_copy_as_python_bytes()
		20:   # Fill Selection
			_show_fill_dialog()
		30:   # Go to Offset
			_show_goto_dialog()
		40:   # Add Bookmark
			_add_bookmark(_cursor)

# =============================================================================
# FILL SELECTION
# =============================================================================

func _show_fill_dialog() -> void:
	if _sel_start < 0 or _sel_end < _sel_start:
		return
	var dlg  := ConfirmationDialog.new()
	dlg.title = "Fill Selection"
	var vb   := VBoxContainer.new()
	var lbl  := Label.new()
	lbl.text = "Fill %d byte(s) with value (hex, e.g. 00 or FF):" % (_sel_end - _sel_start + 1)
	vb.add_child(lbl)
	var edit := LineEdit.new()
	edit.text       = "00"
	edit.max_length = 2
	edit.custom_minimum_size.x = 60
	vb.add_child(edit)
	dlg.add_child(vb)
	add_child(dlg)
	dlg.confirmed.connect(func():
		var txt : String = edit.text.strip_edges().to_lower()
		if txt.length() == 0: txt = "00"
		if txt.length() == 1: txt = "0" + txt
		var fill_val : int = txt.hex_to_int() & 0xFF
		for i in range(_sel_start, _sel_end + 1):
			_write_byte(i, fill_val)
		_canvas.queue_redraw()
	)
	dlg.popup_centered()

# =============================================================================
# EDIT OPERATIONS
# =============================================================================

func _write_byte(off: int, val: int) -> void:
	if off < 0 or off >= _file_data.size():
		return
	var old_val : int = _file_data[off]
	if old_val == val:
		return
	_undo_stack.append({"op": "write", "off": off, "old": old_val, "new": val})
	_redo_stack.clear()
	_file_data[off]   = val
	_dirty_set[off]   = true
	_modified         = true
	_dirty_label.text = "● Modified"
	_update_status()
	_sync_text_panel()


func _insert_byte_at(off: int) -> void:
	_undo_stack.append({"op": "insert", "off": off})
	_redo_stack.clear()
	var arr : PackedByteArray = PackedByteArray()
	arr.resize(_file_data.size() + 1)
	for i in range(off):
		arr[i] = _file_data[i]
	arr[off] = 0
	for i in range(off, _file_data.size()):
		arr[i + 1] = _file_data[i]
	_file_data        = arr
	_modified         = true
	_dirty_label.text = "● Modified"
	_update_scrollbar()


func _delete_byte_at(off: int) -> void:
	if _file_data.is_empty():
		return
	_undo_stack.append({"op": "delete", "off": off, "val": int(_file_data[off])})
	_redo_stack.clear()
	var arr : PackedByteArray = PackedByteArray()
	arr.resize(_file_data.size() - 1)
	for i in range(off):
		arr[i] = _file_data[i]
	for i in range(off + 1, _file_data.size()):
		arr[i - 1] = _file_data[i]
	_file_data        = arr
	_modified         = true
	_dirty_label.text = "● Modified"
	_update_scrollbar()
	_sync_text_panel()


func _do_undo() -> void:
	if _undo_stack.is_empty():
		return
	var op : Dictionary = _undo_stack.pop_back()
	_redo_stack.append(op)
	match op["op"]:
		"write":
			_file_data[op["off"]] = op["old"]
			_dirty_set.erase(op["off"])
		"insert":
			_delete_byte_at_no_record(op["off"])
		"delete":
			_insert_byte_at_no_record(op["off"], op["val"])
	_modified         = not _undo_stack.is_empty()
	_dirty_label.text = "● Modified" if _modified else ""
	_update_status()
	_canvas.queue_redraw()
	_sync_text_panel()


func _do_redo() -> void:
	if _redo_stack.is_empty():
		return
	var op : Dictionary = _redo_stack.pop_back()
	_undo_stack.append(op)
	match op["op"]:
		"write":
			_file_data[op["off"]] = op["new"]
			_dirty_set[op["off"]] = true
		"insert":
			_insert_byte_at_no_record(op["off"], 0)
		"delete":
			_delete_byte_at_no_record(op["off"])
	_modified         = true
	_dirty_label.text = "● Modified"
	_update_status()
	_canvas.queue_redraw()
	_sync_text_panel()


func _delete_byte_at_no_record(off: int) -> void:
	var arr : PackedByteArray = PackedByteArray()
	arr.resize(_file_data.size() - 1)
	for i in range(off):
		arr[i] = _file_data[i]
	for i in range(off + 1, _file_data.size()):
		arr[i - 1] = _file_data[i]
	_file_data = arr
	_update_scrollbar()


func _insert_byte_at_no_record(off: int, val: int) -> void:
	var arr : PackedByteArray = PackedByteArray()
	arr.resize(_file_data.size() + 1)
	for i in range(off):
		arr[i] = _file_data[i]
	arr[off] = val
	for i in range(off, _file_data.size()):
		arr[i + 1] = _file_data[i]
	_file_data = arr
	_update_scrollbar()

# =============================================================================
# CLIPBOARD
# =============================================================================

func _copy_selection() -> void:
	if _file_data.is_empty():
		return
	var s : int = _sel_start if _sel_start >= 0 else _cursor
	var e : int = _sel_end   if _sel_end   >= 0 else _cursor
	s = clamp(s, 0, _file_data.size() - 1)
	e = clamp(e, 0, _file_data.size() - 1)
	var parts : PackedStringArray = PackedStringArray()
	for i in range(s, e + 1):
		parts.append("%02X" % _file_data[i])
	DisplayServer.clipboard_set(" ".join(parts))


func _paste_from_clipboard() -> void:
	var clip : String = DisplayServer.clipboard_get().strip_edges()
	clip = clip.replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "").to_lower()
	if clip.is_empty() or clip.length() % 2 != 0:
		return
	for ch in clip:
		if ch not in "0123456789abcdef":
			return
	var write_pos : int = _cursor
	for i in range(0, clip.length(), 2):
		var byte_val : int = clip.substr(i, 2).hex_to_int()
		if write_pos < _file_data.size():
			_write_byte(write_pos, byte_val)
		elif _insert_mode:
			_insert_byte_at(write_pos)
			_write_byte(write_pos, byte_val)
		else:
			break
		write_pos += 1
	_cursor = mini(write_pos, _file_data.size() - 1)
	_scroll_to_cursor()
	_update_status()
	_canvas.queue_redraw()

# =============================================================================
# SAVE
# =============================================================================

func _save_file() -> void:
	if _file_path.is_empty():
		_show_save_as_dialog()
		return
	var abs : String = _file_path
	if _file_path.begins_with("res://"):
		abs = ProjectSettings.globalize_path(_file_path)
	_save_to_path(abs)


func _save_to_path(abs_path: String) -> void:
	var fa := FileAccess.open(abs_path, FileAccess.WRITE)
	if not fa:
		push_warning("VGHexEditor: cannot write '%s'" % abs_path)
		return
	fa.store_buffer(_file_data)
	fa.close()
	_modified         = false
	_dirty_set.clear()
	_dirty_label.text = ""
	if abs_path != _file_path:
		_file_path       = abs_path
		_path_label.text = abs_path
	title = "VG Hex Editor — " + abs_path.get_file()
	_canvas.queue_redraw()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()


func _show_save_as_dialog() -> void:
	if not _file_path.is_empty():
		var abs : String = _file_path
		if _file_path.begins_with("res://"):
			abs = ProjectSettings.globalize_path(_file_path)
		_save_dialog.current_path = abs
	_save_dialog.popup_centered_ratio(0.7)

# =============================================================================
# RECENT FILES
# =============================================================================

func _load_recent_files() -> void:
	_recent_files.clear()
	var fa := FileAccess.open(RECENT_FILE, FileAccess.READ)
	if not fa:
		return
	while not fa.eof_reached():
		var line : String = fa.get_line().strip_edges()
		if line.length() > 0:
			_recent_files.append(line)
	fa.close()


func _save_recent_files() -> void:
	var fa := FileAccess.open(RECENT_FILE, FileAccess.WRITE)
	if not fa:
		return
	for p in _recent_files:
		fa.store_line(p)
	fa.close()


func _add_recent_file(path: String) -> void:
	_recent_files.erase(path)
	_recent_files.insert(0, path)
	while _recent_files.size() > MAX_RECENT:
		_recent_files.pop_back()
	_save_recent_files()


func _populate_open_menu() -> void:
	var popup : PopupMenu = _open_menu_btn.get_popup()
	popup.clear()
	popup.add_item("Browse...", 0)
	if _recent_files.size() > 0:
		popup.add_separator("Recent Files")
		for i in range(_recent_files.size()):
			var display : String = _recent_files[i].get_file()
			popup.add_item(display, 100 + i)
			popup.set_item_tooltip(popup.get_item_count() - 1, _recent_files[i])


func _on_open_menu_id(id: int) -> void:
	if id == 0:
		_show_open_dialog()
		return
	var idx : int = id - 100
	if idx >= 0 and idx < _recent_files.size():
		open_file(_recent_files[idx])

# =============================================================================
# SCROLLBAR & NAVIGATION
# =============================================================================

func _update_scrollbar() -> void:
	if _file_data.is_empty():
		_vscroll.max_value      = 1
		_vscroll.value          = 0
		_text_vscroll.max_value = 1
		_text_vscroll.value     = 0
		return
	var total_rows : int = int(ceil(float(_file_data.size()) / _bytes_per_row))
	_vscroll.max_value      = max(total_rows, _rows_visible)
	_vscroll.page           = _rows_visible
	_vscroll.value          = _scroll_row
	_text_vscroll.max_value = _vscroll.max_value
	_text_vscroll.page      = _rows_visible
	_text_vscroll.value     = _scroll_row


func _on_scroll(val: float) -> void:
	_scroll_row = int(val)
	# Keep both scrollbars in sync (setting same value won't re-fire if unchanged)
	if _vscroll.value != val:
		_vscroll.value = val
	if _text_vscroll.value != val:
		_text_vscroll.value = val
	_canvas.queue_redraw()
	# Never rebuild the text panel mid-drag — that replaces the text content
	# which clears TextEdit's active selection and causes jitter.
	if not _text_mouse_selecting:
		_sync_text_panel()


func _scroll_to_cursor() -> void:
	var row : int = _cursor / _bytes_per_row
	if row < _scroll_row:
		_scroll_row    = row
		_vscroll.value = _scroll_row
	elif row >= _scroll_row + _rows_visible:
		_scroll_row    = row - _rows_visible + 1
		_vscroll.value = _scroll_row
	_canvas.queue_redraw()
	_sync_text_panel()

# =============================================================================
# SEARCH
# =============================================================================

func _run_search() -> void:
	var q : String = _search_edit.text.strip_edges()
	_search_offsets.clear()
	_cur_result = -1

	if q.is_empty() or _file_data.is_empty():
		_result_label.text      = ""
		_find_prev_btn.disabled = true
		_find_next_btn.disabled = true
		_canvas.queue_redraw()
		return

	var pattern_hex : String
	if _search_mode.selected == 1:   # ASCII
		pattern_hex = q.to_utf8_buffer().hex_encode()
	else:
		pattern_hex = q.replace(" ", "").replace("\t", "").to_lower()
		if pattern_hex.length() % 2 != 0:
			_result_label.text = "⚠ Odd length"
			return
		for ch in pattern_hex:
			if ch not in "0123456789abcdef":
				_result_label.text = "⚠ Bad hex"
				return

	_search_len = pattern_hex.length() / 2
	if _search_len == 0:
		return

	var file_hex : String = _file_data.hex_encode()
	var pos      : int    = 0
	while true:
		var found : int = file_hex.find(pattern_hex, pos)
		if found < 0: break
		if found % 2 == 0:
			_search_offsets.append(found / 2)
		pos = found + 2

	if _search_offsets.is_empty():
		_result_label.text      = "Not found"
		_find_prev_btn.disabled = true
		_find_next_btn.disabled = true
		_replace_btn.disabled     = true
		_replace_all_btn.disabled = true
		_canvas.queue_redraw()
	else:
		_find_prev_btn.disabled   = false
		_find_next_btn.disabled   = false
		_replace_btn.disabled     = false
		_replace_all_btn.disabled = false
		_jump_to_result(0)


func _next_result() -> void:
	if _search_offsets.is_empty(): return
	_jump_to_result((_cur_result + 1) % _search_offsets.size())


func _prev_result() -> void:
	if _search_offsets.is_empty(): return
	_jump_to_result((_cur_result - 1 + _search_offsets.size()) % _search_offsets.size())


func _jump_to_result(idx: int) -> void:
	_cur_result        = idx
	var off : int      = _search_offsets[idx]
	_cursor            = off
	_result_label.text = "%d / %d" % [idx + 1, _search_offsets.size()]
	_scroll_to_cursor()
	_update_status()
	_canvas.queue_redraw()

# =============================================================================
# GO TO OFFSET DIALOG
# =============================================================================

func _show_goto_dialog() -> void:
	if _file_data.is_empty(): return
	var dlg  := ConfirmationDialog.new()
	dlg.title = "Go to Offset"
	var vb   := VBoxContainer.new()
	var lbl  := Label.new()
	lbl.text = "Enter offset (decimal or 0x hex):"
	vb.add_child(lbl)
	var edit := LineEdit.new()
	edit.placeholder_text      = "e.g.  1024  or  0x400"
	edit.custom_minimum_size.x = 220
	vb.add_child(edit)
	dlg.add_child(vb)
	add_child(dlg)
	dlg.confirmed.connect(func():
		var txt : String = edit.text.strip_edges().to_lower()
		var off2 : int   = 0
		if txt.begins_with("0x"):
			off2 = txt.substr(2).hex_to_int()
		else:
			off2 = txt.to_int()
		_cursor = clamp(off2, 0, _file_data.size() - 1)
		_scroll_to_cursor()
		_update_status()
		_canvas.grab_focus()
	)
	dlg.popup_centered()

# =============================================================================
# STATUS BAR
# =============================================================================

func _update_status() -> void:
	if _file_data.is_empty():
		_status_label.text = "No file loaded"
		_interp_label.text = ""
		return
	var sz  : int = _file_data.size()
	var off : int = _cursor
	var val : int = _file_data[off] if off < sz else 0
	var sel_str : String = ""
	if _sel_start >= 0 and _sel_end >= _sel_start:
		var sel_count : int = _sel_end - _sel_start + 1
		sel_str = "   Sel: %d byte%s (0x%X–0x%X)" % [
			sel_count,
			"s" if sel_count != 1 else "",
			_sel_start, _sel_end
		]
	_status_label.text = (
		"Offset: 0x%08X (%d)   Value: 0x%02X   Dec: %d   Oct: %03o   Char: %s   Size: %s (%d bytes)%s" % [
			off, off, val, val, val,
			(char(val) if val >= 0x20 and val <= 0x7E else "."),
			_fmt_size(sz), sz, sel_str
		]
	)
	_interp_label.text = _data_interp(off)


## Build a data-type interpretation string for the bytes starting at offset.
func _data_interp(off: int) -> String:
	var sz     : int    = _file_data.size()
	var result : String = ""
	var mode   : String = "BE" if _be_mode else "LE"

	# ── int8 / uint8 ──────────────────────────────────────────────────────────
	var u8 : int = _file_data[off]
	var i8 : int = u8 if u8 < 128 else u8 - 256
	result += "int8: %d   uint8: %d" % [i8, u8]

	# ── int16 / uint16 ────────────────────────────────────────────────────────
	if off + 1 < sz:
		var u16 : int
		if _be_mode:
			u16 = (_file_data[off] << 8) | _file_data[off + 1]
		else:
			u16 = _file_data[off] | (_file_data[off + 1] << 8)
		var i16 : int = u16 if u16 < 32768 else u16 - 65536
		result += "   int16%s: %d   uint16%s: %d" % [mode, i16, mode, u16]

	# ── int32 / uint32 / float32 ──────────────────────────────────────────────
	if off + 3 < sz:
		var u32 : int
		if _be_mode:
			u32 = ((_file_data[off] << 24) | (_file_data[off + 1] << 16) |
				   (_file_data[off + 2] << 8) | _file_data[off + 3])
		else:
			u32 = (_file_data[off] | (_file_data[off + 1] << 8) |
				   (_file_data[off + 2] << 16) | (_file_data[off + 3] << 24))
		var i32 : int = u32 if u32 < 2147483648 else u32 - 4294967296
		# float32 — always use LE buffer then swap for BE
		var buf4 : PackedByteArray = _file_data.slice(off, off + 4)
		if _be_mode:
			var tmp : PackedByteArray = PackedByteArray([buf4[3], buf4[2], buf4[1], buf4[0]])
			buf4 = tmp
		var f32a : PackedFloat32Array = buf4.to_float32_array()
		var f32  : float = f32a[0] if f32a.size() > 0 else 0.0
		result += "   int32%s: %d   uint32%s: %d   float32%s: %g" % [mode, i32, mode, u32, mode, f32]

	# ── float64 ───────────────────────────────────────────────────────────────
	if off + 7 < sz:
		var buf8 : PackedByteArray = _file_data.slice(off, off + 8)
		if _be_mode:
			var tmp8 : PackedByteArray = PackedByteArray([
				buf8[7], buf8[6], buf8[5], buf8[4], buf8[3], buf8[2], buf8[1], buf8[0]])
			buf8 = tmp8
		var f64a : PackedFloat64Array = buf8.to_float64_array()
		var f64  : float = f64a[0] if f64a.size() > 0 else 0.0
		result += "   float64%s: %g" % [mode, f64]

	return result

# =============================================================================
# HELPERS
# =============================================================================

func _byte_color(b: int) -> Color:
	if b == 0:                    return C_NULL
	if b >= 0x20 and b <= 0x7E:   return C_ASCII_RNG
	if b >= 0x80:                 return C_HIGH
	return C_NORMAL


func _fmt_size(n: int) -> String:
	if n < 1024:               return "%d B"    % n
	if n < 1024 * 1024:        return "%.1f KB" % (float(n) / 1024.0)
	if n < 1024 * 1024 * 1024: return "%.2f MB" % (float(n) / (1024.0 * 1024.0))
	return                            "%.2f GB" % (float(n) / (1024.0 * 1024.0 * 1024.0))


func _show_open_dialog() -> void:
	if is_inside_tree():
		var abs : String = ProjectSettings.globalize_path("res://")
		if DirAccess.dir_exists_absolute(abs):
			_file_dialog.current_dir = abs
	_file_dialog.popup_centered_ratio(0.7)

# =============================================================================
# FEATURE 1 — ENDIANNESS TOGGLE
# =============================================================================

func _toggle_endian() -> void:
	_be_mode       = not _be_mode
	_be_btn.text   = "BE" if _be_mode else "LE"
	_update_status()

# =============================================================================
# FEATURE 2 — FILE COMPARE
# =============================================================================

func _show_compare_dialog() -> void:
	_cmp_dialog.popup_centered_ratio(0.7)


func _load_compare_file(path: String) -> void:
	var abs : String = path
	if path.begins_with("res://"):
		abs = ProjectSettings.globalize_path(path)
	var fa := FileAccess.open(abs, FileAccess.READ)
	if not fa:
		push_warning("VGHexEditor: cannot open compare file '%s'" % abs)
		return
	_cmp_data = fa.get_buffer(fa.get_length())
	fa.close()
	_cmp_path = path
	_canvas.queue_redraw()


func _clear_compare() -> void:
	_cmp_data.clear()
	_cmp_path = ""
	_canvas.queue_redraw()

# =============================================================================
# FEATURE 3 — CHECKSUM / HASH
# =============================================================================

func _show_hash_dialog() -> void:
	if _file_data.is_empty():
		return
	var s   : int = _sel_start if _sel_start >= 0 else 0
	var e   : int = _sel_end   if _sel_end   >= 0 else _file_data.size() - 1
	s = clamp(s, 0, _file_data.size() - 1)
	e = clamp(e, 0, _file_data.size() - 1)
	var buf : PackedByteArray = _file_data.slice(s, e + 1)
	var scope : String = ("selection [0x%X–0x%X, %d bytes]" % [s, e, e - s + 1]) \
		if _sel_start >= 0 else ("whole file (%d bytes)" % _file_data.size())

	var ctx := HashingContext.new()

	ctx.start(HashingContext.HASH_MD5)
	ctx.update(buf)
	var md5 : String = ctx.finish().hex_encode()

	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(buf)
	var sha1 : String = ctx.finish().hex_encode()

	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf)
	var sha256 : String = ctx.finish().hex_encode()

	var crc32 : int = _calc_crc32(buf)

	var dlg    := AcceptDialog.new()
	dlg.title   = "Hash / Checksum"
	var vb     := VBoxContainer.new()

	var scope_lbl := Label.new()
	scope_lbl.text = "Scope: " + scope
	scope_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(scope_lbl)
	vb.add_child(HSeparator.new())

	for row_data in [
		["CRC-32",  "%08X" % crc32],
		["MD5",     md5],
		["SHA-1",   sha1],
		["SHA-256", sha256],
	]:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text                  = row_data[0] + ":"
		name_lbl.custom_minimum_size.x = 70
		row.add_child(name_lbl)
		var val_edit := LineEdit.new()
		val_edit.text                    = row_data[1]
		val_edit.editable                = false
		val_edit.select_all_on_focus     = true
		val_edit.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		val_edit.add_theme_font_size_override("font_size", 11)
		row.add_child(val_edit)
		var copy_btn := Button.new()
		copy_btn.text = "Copy"
		copy_btn.flat = true
		var val_capture : String = row_data[1]
		copy_btn.pressed.connect(func(): DisplayServer.clipboard_set(val_capture))
		row.add_child(copy_btn)
		vb.add_child(row)

	dlg.add_child(vb)
	add_child(dlg)
	dlg.popup_centered()


func _calc_crc32(data: PackedByteArray) -> int:
	var crc : int = 0xFFFFFFFF
	for byte_val in data:
		crc = crc ^ byte_val
		for _i in range(8):
			if crc & 1:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc = crc >> 1
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF

# =============================================================================
# FEATURE 4 — COPY FORMATS
# =============================================================================

func _copy_as_c_array() -> void:
	if _file_data.is_empty():
		return
	var s : int = _sel_start if _sel_start >= 0 else _cursor
	var e : int = _sel_end   if _sel_end   >= 0 else _cursor
	s = clamp(s, 0, _file_data.size() - 1)
	e = clamp(e, 0, _file_data.size() - 1)
	var parts : PackedStringArray = PackedStringArray()
	for i in range(s, e + 1):
		parts.append("0x%02X" % _file_data[i])
	var result : String = "{ " + ", ".join(parts) + " }"
	DisplayServer.clipboard_set(result)


func _copy_as_python_bytes() -> void:
	if _file_data.is_empty():
		return
	var s : int = _sel_start if _sel_start >= 0 else _cursor
	var e : int = _sel_end   if _sel_end   >= 0 else _cursor
	s = clamp(s, 0, _file_data.size() - 1)
	e = clamp(e, 0, _file_data.size() - 1)
	var parts : PackedStringArray = PackedStringArray()
	for i in range(s, e + 1):
		parts.append("\\x%02x" % _file_data[i])
	var result : String = 'b"' + "".join(parts) + '"'
	DisplayServer.clipboard_set(result)

# =============================================================================
# FEATURE 5 — BOOKMARKS
# =============================================================================

func _add_bookmark(off: int) -> void:
	if _file_data.is_empty():
		return
	# Check if already bookmarked at this offset
	for bm in _bookmarks:
		if bm["off"] == off:
			return
	var dlg  := ConfirmationDialog.new()
	dlg.title = "Add Bookmark"
	var vb   := VBoxContainer.new()
	var lbl  := Label.new()
	lbl.text = "Bookmark name for 0x%08X:" % off
	vb.add_child(lbl)
	var edit := LineEdit.new()
	edit.text                    = "0x%08X" % off
	edit.select_all_on_focus     = true
	edit.custom_minimum_size.x   = 220
	vb.add_child(edit)
	dlg.add_child(vb)
	add_child(dlg)
	dlg.confirmed.connect(func():
		var name : String = edit.text.strip_edges()
		if name.is_empty():
			name = "0x%08X" % off
		_bookmarks.append({"off": off, "name": name})
		_bookmarks.sort_custom(func(a, b): return a["off"] < b["off"])
		_canvas.queue_redraw()
	)
	dlg.popup_centered()


func _cycle_bookmark(dir: int) -> void:
	if _bookmarks.is_empty():
		return
	var best_idx : int = -1
	if dir > 0:
		# Next bookmark after cursor
		for i in range(_bookmarks.size()):
			if _bookmarks[i]["off"] > _cursor:
				best_idx = i
				break
		if best_idx < 0:
			best_idx = 0   # wrap around
	else:
		# Previous bookmark before cursor
		for i in range(_bookmarks.size() - 1, -1, -1):
			if _bookmarks[i]["off"] < _cursor:
				best_idx = i
				break
		if best_idx < 0:
			best_idx = _bookmarks.size() - 1   # wrap around
	_cursor = _bookmarks[best_idx]["off"]
	_scroll_to_cursor()
	_update_status()
	_canvas.queue_redraw()


func _populate_bookmark_menu() -> void:
	var popup : PopupMenu = _bookmark_menu.get_popup()
	popup.clear()
	popup.add_item("Add Bookmark Here\tCtrl+B", 0)
	if not _bookmarks.is_empty():
		popup.add_separator()
		for i in range(_bookmarks.size()):
			var bm : Dictionary = _bookmarks[i]
			popup.add_item("%s  (0x%08X)" % [bm["name"], bm["off"]], 100 + i)
		popup.add_separator()
		popup.add_item("Clear All Bookmarks", 200)


func _on_bookmark_menu_id(id: int) -> void:
	if id == 0:
		_add_bookmark(_cursor)
	elif id == 200:
		_bookmarks.clear()
		_canvas.queue_redraw()
	elif id >= 100:
		var idx : int = id - 100
		if idx < _bookmarks.size():
			_cursor = _bookmarks[idx]["off"]
			_scroll_to_cursor()
			_update_status()
			_canvas.queue_redraw()

# =============================================================================
# FEATURE 6 — FIND & REPLACE
# =============================================================================

func _parse_replace_pattern() -> PackedByteArray:
	var q : String = _replace_edit.text.strip_edges().replace(" ", "").replace("\t", "").to_lower()
	var out : PackedByteArray = PackedByteArray()
	if q.is_empty() or q.length() % 2 != 0:
		return out
	for ch in q:
		if ch not in "0123456789abcdef":
			return PackedByteArray()
	for i in range(0, q.length(), 2):
		out.append(q.substr(i, 2).hex_to_int())
	return out


func _replace_next() -> void:
	if _search_offsets.is_empty() or _cur_result < 0:
		return
	var rep : PackedByteArray = _parse_replace_pattern()
	if rep.is_empty():
		return
	var off : int = _search_offsets[_cur_result]
	for i in range(mini(rep.size(), _search_len)):
		_write_byte(off + i, rep[i])
	# Re-run search to refresh offsets, stay at same index if possible
	var old_idx : int = _cur_result
	_run_search()
	if not _search_offsets.is_empty():
		_jump_to_result(mini(old_idx, _search_offsets.size() - 1))
	_canvas.queue_redraw()


func _replace_all() -> void:
	if _search_offsets.is_empty():
		return
	var rep : PackedByteArray = _parse_replace_pattern()
	if rep.is_empty():
		return
	# Iterate snapshot (search will be rerun after)
	var offs_snapshot : Array[int] = _search_offsets.duplicate()
	for off in offs_snapshot:
		for i in range(mini(rep.size(), _search_len)):
			_write_byte(off + i, rep[i])
	_run_search()
	_canvas.queue_redraw()

# =============================================================================
# FEATURE 7 — HIGHLIGHT PATTERNS
# =============================================================================

func _show_highlight_dialog() -> void:
	var dlg  := Window.new()
	dlg.title = "Highlight Patterns"
	dlg.size  = Vector2i(500, 340)
	dlg.wrap_controls = true

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	dlg.add_child(vb)

	var info := Label.new()
	info.text = "Add hex byte patterns to highlight in the editor.\nEach pattern is colored independently."
	info.add_theme_font_size_override("font_size", 11)
	vb.add_child(info)

	# List container
	var list_vb := VBoxContainer.new()
	list_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(list_vb)

	var _refresh_list : Callable   # forward declaration

	var _refresh_list_impl := func():
		for ch in list_vb.get_children():
			ch.queue_free()
		for i in range(_hl_patterns.size()):
			var entry : Dictionary = _hl_patterns[i]
			var row := HBoxContainer.new()

			var color_rect := ColorRect.new()
			color_rect.color               = entry["color"]
			color_rect.custom_minimum_size = Vector2(24, 20)
			row.add_child(color_rect)

			var lbl2 := Label.new()
			lbl2.text                  = entry["label"] if entry["label"] != "" else entry["pattern"].hex_encode().to_upper()
			lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl2)

			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.flat = true
			var capture_i := i
			del_btn.pressed.connect(func():
				_hl_patterns.remove_at(capture_i)
				_refresh_list.call()
				_canvas.queue_redraw()
			)
			row.add_child(del_btn)
			list_vb.add_child(row)

	_refresh_list = _refresh_list_impl
	_refresh_list.call()

	# Add-new row
	var add_row := HBoxContainer.new()

	var pat_edit := LineEdit.new()
	pat_edit.placeholder_text      = "hex pattern  e.g. FF D8 FF"
	pat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(pat_edit)

	var cpicker := ColorPickerButton.new()
	cpicker.color                = Color("#FF8C00")
	cpicker.custom_minimum_size  = Vector2(60, 0)
	cpicker.tooltip_text         = "Pick highlight color"
	add_row.add_child(cpicker)

	var label_edit := LineEdit.new()
	label_edit.placeholder_text      = "label (optional)"
	label_edit.custom_minimum_size.x = 100
	add_row.add_child(label_edit)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.flat = true
	add_btn.pressed.connect(func():
		var raw : String = pat_edit.text.strip_edges().replace(" ", "").replace("\t", "").to_lower()
		if raw.is_empty() or raw.length() % 2 != 0:
			return
		var ok : bool = true
		for ch2 in raw:
			if ch2 not in "0123456789abcdef":
				ok = false
				break
		if not ok:
			return
		var buf : PackedByteArray = PackedByteArray()
		for i2 in range(0, raw.length(), 2):
			buf.append(raw.substr(i2, 2).hex_to_int())
		_hl_patterns.append({"pattern": buf, "color": cpicker.color, "label": label_edit.text.strip_edges()})
		pat_edit.text   = ""
		label_edit.text = ""
		_refresh_list.call()
		_canvas.queue_redraw()
	)
	add_row.add_child(add_btn)
	vb.add_child(add_row)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(dlg.queue_free)
	vb.add_child(close_btn)

	dlg.close_requested.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()

# =============================================================================
# TEXT PANEL — sync, input, caret
# =============================================================================

func _sync_text_panel() -> void:
	if not _text_panel:
		return
	_text_updating = true

	if _file_data.is_empty():
		_text_panel.text = ""
		if _text_highlighter:
			_text_highlighter.vis_len = 0
		_text_updating = false
		return

	# Visible range — matches what the hex canvas is showing
	var vis_start : int = _scroll_row * _bytes_per_row
	var vis_end   : int = mini(vis_start + _rows_visible * _bytes_per_row, _file_data.size())

	# Extended range — up to 2× visible rows beyond the hex view, shown dimmed
	var ext_end   : int = mini(vis_start + _rows_visible * 3 * _bytes_per_row, _file_data.size())

	# Build flat string: visible bytes + extra bytes
	var flat : String = ""
	for off in range(vis_start, ext_end):
		var b : int = _file_data[off]
		flat += char(b) if (b >= 0x20 and b <= 0x7E) else "?"

	_text_panel.text = flat

	# Tell the highlighter where the "normal" (hex-visible) portion ends
	if _text_highlighter:
		_text_highlighter.vis_len = vis_end - vis_start
		_text_panel.queue_redraw()

	# Caret: column = offset of hex cursor within the flat string
	var caret_col : int = clamp(_cursor - vis_start, 0, maxi(0, flat.length() - 1))
	_text_panel.set_caret_line(0)
	_text_panel.set_caret_column(caret_col)

	# Mirror hex selection into the text panel
	if _sel_start >= 0 and _sel_end >= 0:
		var sel_from : int = clamp(_sel_start - vis_start, 0, flat.length())
		var sel_to   : int = clamp(_sel_end   - vis_start + 1, 0, flat.length())
		if sel_from < sel_to:
			_text_panel.select(0, sel_from, 0, sel_to)
		else:
			_text_panel.deselect()
	else:
		_text_panel.deselect()

	_text_updating = false


func _on_text_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		match me.button_index:
			MOUSE_BUTTON_LEFT:
				# Snapshot vis_start when drag begins so column-to-byte mapping stays
				# stable even if the hex view scrolls live during the drag.
				if me.pressed:
					_text_mouse_selecting = true
					_text_drag_vis_start  = _scroll_row * _bytes_per_row
				else:
					_text_mouse_selecting = false
					if not _file_data.is_empty():
						_scroll_to_cursor()
				# Do NOT consume — let TextEdit gain focus and handle selection
			MOUSE_BUTTON_WHEEL_UP:
				if me.pressed:
					_scroll_row    = maxi(0, _scroll_row - 3)
					_vscroll.value = _scroll_row
					_sync_text_panel()
					_canvas.queue_redraw()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if me.pressed:
					var total_rows : int = int(ceil(float(_file_data.size()) / float(_bytes_per_row)))
					_scroll_row    = mini(maxi(total_rows - 1, 0), _scroll_row + 3)
					_vscroll.value = _scroll_row
					_sync_text_panel()
					_canvas.queue_redraw()
					get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return
	var ke := event as InputEventKey
	if not ke.pressed:
		return

	# Redirect global shortcuts to hex editor
	if ke.ctrl_pressed:
		match ke.keycode:
			KEY_S: _save_file()
			KEY_Z: _do_undo(); _canvas.queue_redraw()
			KEY_Y: _do_redo(); _canvas.queue_redraw()
			KEY_F: _search_edit.grab_focus(); _search_edit.select_all()
			KEY_G: _show_goto_dialog()
			KEY_O: _show_open_dialog()
		get_viewport().set_input_as_handled()
		return

	match ke.keycode:
		KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
			return
		# Block keys that would modify TextEdit's buffer directly.
		# We handle text writes ourselves via _write_byte.
		KEY_BACKSPACE, KEY_DELETE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			get_viewport().set_input_as_handled()
			return
		# Arrow keys / Page Up/Down / Home / End: let TextEdit move the caret
		# natively; _on_text_panel_caret_changed will sync the hex view.

	# Printable character — overwrite the byte at the caret position
	var uch : int = ke.unicode
	if uch >= 0x20 and uch <= 0x7E and not _file_data.is_empty():
		var vis_start : int = _scroll_row * _bytes_per_row
		var col       : int = _text_panel.get_caret_column()
		var off       : int = vis_start + col
		if off < _file_data.size():
			_write_byte(off, uch)
			var vis_end : int = mini(vis_start + _rows_visible * _bytes_per_row, _file_data.size())
			var max_col : int = vis_end - vis_start - 1
			col = mini(col + 1, max_col)
			_text_updating = true
			_sync_text_panel()
			_text_panel.set_caret_line(0)
			_text_panel.set_caret_column(col)
			_text_updating = false
			_cursor = vis_start + col
			_canvas.queue_redraw()
		get_viewport().set_input_as_handled()


func _on_text_panel_caret_changed() -> void:
	if _text_updating or _file_data.is_empty():
		return

	# Column-to-byte mapping:
	# While drag-selecting we freeze the text content so column positions remain
	# anchored to _text_drag_vis_start (the vis_start when the drag started).
	# Using _scroll_row here would give wrong offsets if the hex has already
	# scrolled live to follow the drag.
	var base_start : int = _text_drag_vis_start if _text_mouse_selecting \
	                       else _scroll_row * _bytes_per_row
	var col        : int = _text_panel.get_caret_column()
	var off        : int = clamp(base_start + col, 0, _file_data.size() - 1)

	_cursor = off

	# Sync hex selection from text panel selection
	if _text_panel.has_selection():
		var sc : int = _text_panel.get_selection_from_column()
		var ec : int = _text_panel.get_selection_to_column()
		_sel_start = clamp(base_start + sc,     0, _file_data.size() - 1)
		_sel_end   = clamp(base_start + ec - 1, _sel_start, _file_data.size() - 1)
	else:
		_sel_start = -1
		_sel_end   = -1

	if _text_mouse_selecting:
		# Live-scroll the hex view to follow the caret without rebuilding the
		# text panel content (which would clear TextEdit's active selection).
		# Block scrollbar signals to avoid triggering _on_scroll → _sync_text_panel.
		var cursor_row : int = _cursor / _bytes_per_row
		var new_scroll : int = _scroll_row
		if cursor_row < _scroll_row:
			new_scroll = cursor_row
		elif cursor_row >= _scroll_row + _rows_visible:
			new_scroll = cursor_row - _rows_visible + 1
		if new_scroll != _scroll_row:
			_scroll_row = new_scroll
			_vscroll.set_block_signals(true)
			_text_vscroll.set_block_signals(true)
			_vscroll.value      = float(_scroll_row)
			_text_vscroll.value = float(_scroll_row)
			_vscroll.set_block_signals(false)
			_text_vscroll.set_block_signals(false)
		_canvas.queue_redraw()
		_update_status()
		return

	# Not selecting — if caret is outside hex-visible range, scroll and rebuild.
	var vis_end : int = (_scroll_row + _rows_visible) * _bytes_per_row
	if off >= vis_end or off < _scroll_row * _bytes_per_row:
		_text_updating = true
		_scroll_to_cursor()
		return

	_canvas.queue_redraw()
	_update_status()
