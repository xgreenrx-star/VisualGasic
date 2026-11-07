extends LineEdit

const COLUMNS := 38
const ROWS := 21
const CELL := Vector2(14, 22)
const ORIGIN := Vector2(30, 45)

var edit_row := -1
var prompt_text := ""
var blink_time := 0.0
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])

func _process(delta: float) -> void:
	if visible and editable and get_parent().is_visible_in_tree():
		blink_time += delta

func reset_screen_cursor() -> void:
	edit_row = -1
	prompt_text = ""
	text = ""
	caret_column = 0
	blink_time = 0.0

func terminal() -> Object:
	return get_parent().get("terminal")

func row_index() -> int:
	if edit_row >= 0:
		return edit_row
	return terminal().get("transcript").size()

func store_row() -> void:
	if edit_row >= 0:
		var lines: Array = terminal().get("transcript")
		if edit_row < lines.size():
			lines[edit_row] = text
	else:
		prompt_text = text

func move_vertical(direction: int) -> void:
	var lines: Array = terminal().get("transcript")
	var row := row_index()
	var column := caret_column
	if text.length() > COLUMNS:
		var destination := column + direction * COLUMNS
		if destination >= 0 and destination < maxi(COLUMNS, text.length()):
			caret_column = mini(destination, text.length())
			return
	store_row()
	if row == lines.size() and direction > 0 and lines.size() < ROWS - 1:
		lines.append(prompt_text)
		prompt_text = ""
	row = clampi(row + direction, 0, lines.size())
	edit_row = row if row < lines.size() else -1
	text = str(lines[row]) if edit_row >= 0 else prompt_text
	column %= COLUMNS
	if column > text.length():
		text += " ".repeat(column - text.length())
	caret_column = column

func _gui_input(event: InputEvent) -> void:
	if not editable or not event is InputEventKey or not event.pressed:
		return
	blink_time = 0.0
	if get_parent().get("emulator").get("active"):
		var emulator: Object = get_parent().get("emulator")
		var control_codes := {KEY_UP: 145, KEY_DOWN: 17, KEY_LEFT: 157, KEY_RIGHT: 29, KEY_BACKSPACE: 20, KEY_HOME: 19}
		if control_codes.has(event.keycode):
			if not emulator.call("queue_key", control_codes[event.keycode]):
				get_parent().set("loader_message", "C64 BUSY / BOOTING - PLEASE WAIT")
			if event.keycode == KEY_UP or event.keycode == KEY_DOWN or event.keycode == KEY_HOME:
				accept_event()
		elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
			if not emulator.call("queue_key", String.chr(event.unicode).to_upper().unicode_at(0)):
				get_parent().set("loader_message", "C64 BUSY / BOOTING - PLEASE WAIT")
		return
	if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
		move_vertical(-1 if event.keycode == KEY_UP else 1)
		accept_event()
	elif event.keycode == KEY_LEFT and caret_column == 0 and row_index() > 0:
		move_vertical(-1)
		if text.length() < COLUMNS:
			text += " ".repeat(COLUMNS - text.length())
		caret_column = COLUMNS - 1
		accept_event()
	elif event.keycode == KEY_RIGHT and caret_column == text.length() and text.length() < max_length:
		text += " "
		caret_column = text.length()
		accept_event()
	elif event.unicode >= 32 and not event.ctrl_pressed and not event.meta_pressed:
		# The C64 screen editor overwrites cells; Insert still makes room.
		var character := String.chr(event.unicode)
		var column := caret_column
		if column < text.length():
			text = text.substr(0, column) + character + text.substr(column + 1)
			caret_column = column + 1
			accept_event()

func draw_screen(canvas: CanvasItem, ink: Color, reduced: bool) -> void:
	var lines: Array = terminal().get("transcript")
	var current_row := row_index()
	var caret_row := current_row + caret_column / COLUMNS
	var last_row := maxi(lines.size(), current_row + maxi(0, text.length() - 1) / COLUMNS)
	var first_row := maxi(0, maxi(last_row, caret_row) - ROWS + 1)
	for index in range(lines.size()):
		if index == edit_row:
			continue
		var y := index - first_row
		if y >= 0 and y < ROWS:
			draw_cells(canvas, str(lines[index]), y, ink)
	for offset in range(0, maxi(1, text.length()), COLUMNS):
		var y := current_row + offset / COLUMNS - first_row
		if y >= 0 and y < ROWS:
			canvas.draw_rect(Rect2(ORIGIN + Vector2(0, y * CELL.y - 17), Vector2(COLUMNS * CELL.x, CELL.y)), terminal().get("palette")[terminal().get("background_index")])
			draw_cells(canvas, text.substr(offset, COLUMNS), y, ink)
	if editable and (reduced or fmod(blink_time, 1.0) < 0.5):
		var position := ORIGIN + Vector2((caret_column % COLUMNS) * CELL.x, (caret_row - first_row) * CELL.y - 17)
		canvas.draw_rect(Rect2(position, Vector2(CELL.x, 21)), ink)
		if caret_column < text.length():
			canvas.draw_string(font, position + Vector2(0, 17), text[caret_column], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, terminal().get("palette")[terminal().get("background_index")])

func draw_cells(canvas: CanvasItem, value: String, row: int, ink: Color) -> void:
	for column in range(mini(value.length(), COLUMNS)):
		canvas.draw_string(font, ORIGIN + Vector2(column * CELL.x, row * CELL.y), value[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
