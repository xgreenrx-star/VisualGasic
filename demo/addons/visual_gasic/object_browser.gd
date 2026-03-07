# object_browser.gd
# VB6-style Object Browser — browse classes, methods, properties, and constants.
# Activated from: View → Object Browser  or  Tools → Object Browser (F2)
@tool
extends AcceptDialog

# VB6 theme palette (matches components_dialog.gd)
const VB6_PANEL_BG       = Color(0.941, 0.929, 0.910)   # #F0EDE8  cream
const VB6_PANEL_BORDER   = Color(0.72, 0.71, 0.68)
const VB6_HEADER_BG      = Color(0.58, 0.58, 0.62)      # panel-header blue-gray
const VB6_HEADER_BORDER  = Color(0.4, 0.4, 0.4)
const VB6_HEADER_TEXT    = Color(1.0, 1.0, 1.0)
const VB6_TEXT           = Color(0.0, 0.0, 0.0)
const VB6_LIST_BG        = Color(1.0, 1.0, 1.0)
const VB6_BTN_HOVER_BG   = Color(0.95, 0.94, 0.92)
const VB6_BTN_PRESSED_BG = Color(0.88, 0.87, 0.85)
const VB6_ACTIVE_TITLE   = Color(0.0, 0.0, 0.5)         # selection blue

var library_option: OptionButton
var search_edit: LineEdit
var class_list: ItemList
var member_list: ItemList
var desc_label: RichTextLabel

# Data: library_name → { class_name → [ {name, kind, signature, description}, … ] }
var _libraries: Dictionary = {}
# Flat list of class names in the currently displayed library
var _current_classes: PackedStringArray = []

# ─────────────────────────────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────────────────────────────
func _init():
	title = "Object Browser"
	size = Vector2(720, 520)
	unresizable = false
	dialog_hide_on_ok = true

func _ready():
	theme = _build_vb6_theme()
	get_label().visible = false                # hide AcceptDialog's default label
	get_ok_button().text = "Close"
	get_ok_button().custom_minimum_size.x = 80
	confirmed.connect(func(): queue_free())
	canceled.connect(func(): queue_free())

	_build_ui()
	_build_data()
	_populate_libraries()

# ─────────────────────────────────────────────────────────────────────
#  UI LAYOUT
# ─────────────────────────────────────────────────────────────────────
func _build_ui():
	var root = VBoxContainer.new()
	add_child(root)

	# ── Row 1: Library selector + Search ──
	var top_bar = HBoxContainer.new()
	root.add_child(top_bar)

	var lib_label = Label.new()
	lib_label.text = "Library:"
	top_bar.add_child(lib_label)

	library_option = OptionButton.new()
	library_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_option.item_selected.connect(_on_library_selected)
	top_bar.add_child(library_option)

	var search_label = Label.new()
	search_label.text = "  Search:"
	top_bar.add_child(search_label)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Type to filter…"
	search_edit.custom_minimum_size.x = 160
	search_edit.text_changed.connect(_on_search_changed)
	top_bar.add_child(search_edit)

	# ── Row 2: Classes | Members (side-by-side) ──
	var lists = HSplitContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lists)

	# Classes pane
	var cls_vbox = VBoxContainer.new()
	cls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(cls_vbox)

	var cls_header = Label.new()
	cls_header.text = "Classes"
	cls_vbox.add_child(cls_header)

	class_list = ItemList.new()
	class_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_list.auto_height = false
	class_list.item_selected.connect(_on_class_selected)
	cls_vbox.add_child(class_list)

	# Members pane
	var mem_vbox = VBoxContainer.new()
	mem_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(mem_vbox)

	var mem_header = Label.new()
	mem_header.text = "Members of"
	mem_header.name = "MembersHeader"
	mem_vbox.add_child(mem_header)

	member_list = ItemList.new()
	member_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	member_list.auto_height = false
	member_list.item_selected.connect(_on_member_selected)
	mem_vbox.add_child(member_list)

	# ── Row 3: Description ──
	var sep = HSeparator.new()
	root.add_child(sep)

	desc_label = RichTextLabel.new()
	desc_label.custom_minimum_size.y = 70
	desc_label.bbcode_enabled = false
	desc_label.fit_content = true
	desc_label.scroll_active = true
	root.add_child(desc_label)

# ─────────────────────────────────────────────────────────────────────
#  DATA  (hard-coded VB6 reference — matches visual_gasic_builtins.cpp)
# ─────────────────────────────────────────────────────────────────────
func _build_data():
	_libraries = {}

	# ── <All Libraries> ── (union of everything)
	# Built at the end after individual libs are defined.

	# ── VBA Library ──
	var vba := {}

	# -- Strings --
	vba["Strings"] = [
		_m("Len",       "Function", "Len(string) As Long",           "Returns the number of characters in a string."),
		_m("Left",      "Function", "Left(string, length) As String","Returns the leftmost characters of a string."),
		_m("Right",     "Function", "Right(string, length) As String","Returns the rightmost characters of a string."),
		_m("Mid",       "Function", "Mid(string, start[, length]) As String","Returns a substring from a string."),
		_m("InStr",     "Function", "InStr(string1, string2) As Long","Returns the position of a substring within a string (1-based)."),
		_m("InStrRev",  "Function", "InStrRev(string1, string2[, start]) As Long","Searches from the end of the string."),
		_m("Replace",   "Function", "Replace(expression, find, replace) As String","Replaces occurrences of a substring."),
		_m("Split",     "Function", "Split(expression, delimiter) As String()","Splits a string into an array."),
		_m("Join",      "Function", "Join(array, delimiter) As String","Joins an array into a single string."),
		_m("Trim",      "Function", "Trim(string) As String",        "Removes leading and trailing spaces."),
		_m("LTrim",     "Function", "LTrim(string) As String",       "Removes leading spaces."),
		_m("RTrim",     "Function", "RTrim(string) As String",       "Removes trailing spaces."),
		_m("UCase",     "Function", "UCase(string) As String",       "Converts to uppercase."),
		_m("LCase",     "Function", "LCase(string) As String",       "Converts to lowercase."),
		_m("StrComp",   "Function", "StrComp(string1, string2[, compare]) As Integer","Compares two strings."),
		_m("StrReverse","Function", "StrReverse(string) As String",  "Reverses a string."),
		_m("String",    "Function", "String(number, character) As String","Returns a string of repeated characters."),
		_m("Space",     "Function", "Space(number) As String",       "Returns a string of spaces."),
		_m("Chr",       "Function", "Chr(charcode) As String",       "Returns the character for an ASCII code."),
		_m("Asc",       "Function", "Asc(string) As Integer",        "Returns the ASCII code for the first character."),
		_m("Hex",       "Function", "Hex(number) As String",         "Returns the hexadecimal representation."),
		_m("Oct",       "Function", "Oct(number) As String",         "Returns the octal representation."),
		_m("Format",    "Function", "Format(expression[, format]) As String","Formats a value using a format string."),
	]

	# -- Conversion --
	vba["Conversion"] = [
		_m("Val",   "Function", "Val(string) As Double",    "Converts a string to a number."),
		_m("Str",   "Function", "Str(number) As String",    "Converts a number to a string."),
		_m("CStr",  "Function", "CStr(expression) As String","Converts to String."),
		_m("CInt",  "Function", "CInt(expression) As Integer","Converts to Integer (rounds)."),
		_m("CLng",  "Function", "CLng(expression) As Long",  "Converts to Long (rounds)."),
		_m("CSng",  "Function", "CSng(expression) As Single", "Converts to Single."),
		_m("CDbl",  "Function", "CDbl(expression) As Double", "Converts to Double."),
		_m("CBool", "Function", "CBool(expression) As Boolean","Converts to Boolean."),
		_m("CByte", "Function", "CByte(expression) As Byte",  "Converts to Byte (0-255)."),
		_m("CDate", "Function", "CDate(expression) As Date",  "Converts to Date."),
	]

	# -- Math --
	vba["Math"] = [
		_m("Abs",       "Function", "Abs(number) As Double",   "Returns the absolute value."),
		_m("Sgn",       "Function", "Sgn(number) As Integer",  "Returns the sign (−1, 0, or 1)."),
		_m("Int",       "Function", "Int(number) As Long",     "Returns the integer portion (rounds toward −∞)."),
		_m("Fix",       "Function", "Fix(number) As Long",     "Returns the integer portion (truncates toward zero)."),
		_m("Round",     "Function", "Round(number[, digits]) As Double","Rounds to a specified number of decimal places."),
		_m("Sqr",       "Function", "Sqr(number) As Double",   "Returns the square root."),
		_m("Exp",       "Function", "Exp(number) As Double",   "Returns e raised to a power."),
		_m("Log",       "Function", "Log(number) As Double",   "Returns the natural logarithm."),
		_m("Sin",       "Function", "Sin(number) As Double",   "Returns the sine."),
		_m("Cos",       "Function", "Cos(number) As Double",   "Returns the cosine."),
		_m("Tan",       "Function", "Tan(number) As Double",   "Returns the tangent."),
		_m("Atn",       "Function", "Atn(number) As Double",   "Returns the arctangent."),
		_m("Rnd",       "Function", "Rnd([number]) As Single", "Returns a random number between 0 and 1."),
		_m("Randomize", "Sub",      "Randomize [number]",      "Initialises the random-number generator."),
		_m("Min",       "Function", "Min(a, b) As Double",     "Returns the smaller of two values."),
		_m("Max",       "Function", "Max(a, b) As Double",     "Returns the larger of two values."),
		_m("Lerp",      "Function", "Lerp(a, b, t) As Double", "Linear interpolation between a and b."),
		_m("Clamp",     "Function", "Clamp(value, min, max) As Double","Clamps a value to a range."),
	]

	# -- Interaction --
	vba["Interaction"] = [
		_m("MsgBox",   "Function", "MsgBox(prompt[, buttons][, title]) As VbMsgBoxResult","Displays a message box and returns which button was clicked."),
		_m("InputBox", "Function", "InputBox(prompt[, title][, default]) As String","Displays an input dialog and returns the text entered."),
		_m("Shell",    "Function", "Shell(pathname[, windowstyle]) As Double","Runs an executable program."),
		_m("Beep",     "Sub",      "Beep",                    "Sounds a tone through the speaker."),
		_m("Timer",    "Function", "Timer As Single",          "Returns the number of seconds elapsed since midnight."),
		_m("IIf",      "Function", "IIf(expr, truepart, falsepart) As Variant","Returns one of two values depending on an expression."),
		_m("Choose",   "Function", "Choose(index, choice1[, choice2, …]) As Variant","Selects and returns a value from a list of arguments."),
		_m("Switch",   "Function", "Switch(expr1, val1[, expr2, val2, …]) As Variant","Evaluates expressions and returns the matching value."),
	]

	# -- Information --
	vba["Information"] = [
		_m("IsArray",   "Function", "IsArray(varname) As Boolean",  "Returns True if the variable is an array."),
		_m("IsNumeric", "Function", "IsNumeric(expression) As Boolean","Returns True if the expression is a valid number."),
		_m("IsDate",    "Function", "IsDate(expression) As Boolean", "Returns True if the expression is a valid date."),
		_m("IsEmpty",   "Function", "IsEmpty(expression) As Boolean","Returns True if the variable has not been initialized."),
		_m("IsNull",    "Function", "IsNull(expression) As Boolean", "Returns True if the expression is Null."),
		_m("TypeName",  "Function", "TypeName(varname) As String",  "Returns the type name of a variable."),
		_m("VarType",   "Function", "VarType(varname) As Integer",  "Returns the subtype of a variable."),
	]

	# -- DateTime --
	vba["DateTime"] = [
		_m("Now",      "Function", "Now As Date",             "Returns the current date and time."),
		_m("Date",     "Function", "Date As Date",            "Returns the current date."),
		_m("Time",     "Function", "Time As Date",            "Returns the current time."),
		_m("Year",     "Function", "Year(date) As Integer",   "Returns the year from a date."),
		_m("Month",    "Function", "Month(date) As Integer",  "Returns the month from a date."),
		_m("Day",      "Function", "Day(date) As Integer",    "Returns the day from a date."),
		_m("Hour",     "Function", "Hour(time) As Integer",   "Returns the hour from a time."),
		_m("Minute",   "Function", "Minute(time) As Integer", "Returns the minute from a time."),
		_m("Second",   "Function", "Second(time) As Integer", "Returns the second from a time."),
		_m("DateAdd",  "Function", "DateAdd(interval, number, date) As Date","Adds an interval to a date."),
		_m("DateDiff", "Function", "DateDiff(interval, date1, date2) As Long","Returns the number of intervals between two dates."),
		_m("DatePart", "Function", "DatePart(interval, date) As Integer","Returns the specified part of a date."),
	]

	# -- FileSystem --
	vba["FileSystem"] = [
		_m("Open",     "Statement","Open pathname For mode As #filenumber","Opens a file for reading or writing."),
		_m("Close",    "Statement","Close [#filenumber]",      "Closes an open file."),
		_m("FreeFile", "Function", "FreeFile([rangenumber]) As Integer","Returns the next available file number."),
		_m("EOF",      "Function", "EOF(filenumber) As Boolean","Returns True if the end of file has been reached."),
		_m("LOF",      "Function", "LOF(filenumber) As Long",  "Returns the size of an open file in bytes."),
		_m("Loc",      "Function", "Loc(filenumber) As Long",  "Returns the current read/write position."),
		_m("FileLen",  "Function", "FileLen(pathname) As Long", "Returns the length of a file in bytes."),
		_m("Dir",      "Function", "Dir([pathname][, attributes]) As String","Returns the name of a matching file or directory."),
		_m("MkDir",    "Sub",      "MkDir path",               "Creates a new directory."),
		_m("RmDir",    "Sub",      "RmDir path",               "Removes a directory."),
		_m("ChDir",    "Sub",      "ChDir path",               "Changes the current directory."),
		_m("CurDir",   "Function", "CurDir As String",          "Returns the current directory path."),
		_m("FileCopy", "Sub",      "FileCopy source, destination","Copies a file."),
		_m("Kill",     "Sub",      "Kill pathname",             "Deletes a file."),
	]

	# -- Arrays --
	vba["Arrays"] = [
		_m("Array",  "Function", "Array(arglist) As Variant","Creates an array from a list of values."),
		_m("UBound", "Function", "UBound(arrayname[, dimension]) As Long","Returns the largest subscript for an array."),
		_m("LBound", "Function", "LBound(arrayname[, dimension]) As Long","Returns the smallest subscript for an array."),
	]

	# -- Registry / Settings --
	vba["Settings"] = [
		_m("GetSetting",    "Function", "GetSetting(appname, section, key[, default]) As String","Reads a value from the settings store."),
		_m("SaveSetting",   "Sub",      "SaveSetting appname, section, key, setting","Writes a value to the settings store."),
		_m("DeleteSetting", "Sub",      "DeleteSetting appname[, section[, key]]","Deletes a setting."),
		_m("GetAllSettings","Function", "GetAllSettings(appname, section) As Variant","Returns all key/value pairs from a section."),
		_m("Environ",       "Function", "Environ(envstring | number) As String","Returns the value of an environment variable."),
	]

	# -- Constants --
	vba["Constants"] = [
		_m("vbCrLf",    "Constant", "vbCrLf As String",    "Carriage return + line feed (Chr(13) & Chr(10))."),
		_m("vbCr",      "Constant", "vbCr As String",      "Carriage return character."),
		_m("vbLf",      "Constant", "vbLf As String",      "Line feed character."),
		_m("vbTab",     "Constant", "vbTab As String",      "Tab character."),
		_m("vbNullChar","Constant", "vbNullChar As String", "Character with value 0."),
		_m("vbNullString","Constant","vbNullString As String","Zero-length string."),
		_m("True",      "Constant", "True As Boolean",      "Boolean True (−1)."),
		_m("False",     "Constant", "False As Boolean",      "Boolean False (0)."),
		_m("Nothing",   "Constant", "Nothing",              "Represents an uninitialized object reference."),
		_m("Null",      "Constant", "Null",                  "Represents a variable with no valid data."),
		_m("Empty",     "Constant", "Empty",                 "Represents an uninitialized Variant."),
		_m("vbOKOnly",      "Constant", "vbOKOnly = 0",         "MsgBox constant: OK button only."),
		_m("vbOKCancel",    "Constant", "vbOKCancel = 1",       "MsgBox constant: OK and Cancel buttons."),
		_m("vbYesNo",       "Constant", "vbYesNo = 4",          "MsgBox constant: Yes and No buttons."),
		_m("vbYesNoCancel", "Constant", "vbYesNoCancel = 3",    "MsgBox constant: Yes, No, and Cancel buttons."),
		_m("vbInformation", "Constant", "vbInformation = 64",   "MsgBox constant: Information icon."),
		_m("vbExclamation", "Constant", "vbExclamation = 48",   "MsgBox constant: Warning icon."),
		_m("vbCritical",    "Constant", "vbCritical = 16",      "MsgBox constant: Critical icon."),
		_m("vbQuestion",    "Constant", "vbQuestion = 32",      "MsgBox constant: Question icon."),
	]

	_libraries["VBA"] = vba

	# ── VB / Controls Library ──
	var vb := {}

	# -- Form --
	vb["Form"] = [
		_m("Caption",   "Property",  "Caption As String",           "Gets or sets the text displayed in the form's title bar."),
		_m("BackColor", "Property",  "BackColor As Long",           "Gets or sets the background colour of the form."),
		_m("Width",     "Property",  "Width As Single",             "Gets or sets the width of the form."),
		_m("Height",    "Property",  "Height As Single",            "Gets or sets the height of the form."),
		_m("Left",      "Property",  "Left As Single",              "Gets or sets the distance between the left edge and its container."),
		_m("Top",       "Property",  "Top As Single",               "Gets or sets the distance between the top edge and its container."),
		_m("Visible",   "Property",  "Visible As Boolean",          "Gets or sets whether the form is shown."),
		_m("Enabled",   "Property",  "Enabled As Boolean",          "Gets or sets whether the form responds to user events."),
		_m("Show",      "Method",    "Show [modal]",                "Displays the form."),
		_m("Hide",      "Method",    "Hide",                        "Hides the form."),
		_m("Unload",    "Method",    "Unload Me",                   "Unloads the form from memory."),
		_m("Form_Load",    "Event",  "Sub Form_Load()",             "Occurs when the form is loaded into memory."),
		_m("Form_Unload",  "Event",  "Sub Form_Unload(Cancel As Integer)","Occurs when the form is about to be unloaded."),
		_m("Form_Click",   "Event",  "Sub Form_Click()",            "Occurs when the user clicks on the form."),
		_m("Form_KeyPress","Event",  "Sub Form_KeyPress(KeyAscii As Integer)","Occurs when a key is pressed while the form has focus."),
		_m("Form_Resize",  "Event",  "Sub Form_Resize()",           "Occurs when the form is resized."),
	]

	# -- Button --
	vb["Button"] = [
		_m("Caption", "Property", "Caption As String",     "Gets or sets the button's label text."),
		_m("Enabled", "Property", "Enabled As Boolean",    "Gets or sets whether the button is clickable."),
		_m("Visible", "Property", "Visible As Boolean",    "Gets or sets whether the button is shown."),
		_m("Width",   "Property", "Width As Single",       "Gets or sets the width."),
		_m("Height",  "Property", "Height As Single",      "Gets or sets the height."),
		_m("Left",    "Property", "Left As Single",        "Gets or sets the X position."),
		_m("Top",     "Property", "Top As Single",         "Gets or sets the Y position."),
		_m("FontSize","Property", "FontSize As Single",    "Gets or sets the font size in points."),
		_m("Click",   "Event",    "Sub controlname_Click()","Occurs when the user clicks the button."),
	]

	# -- Label --
	vb["Label"] = [
		_m("Caption",   "Property", "Caption As String",    "Gets or sets the displayed text."),
		_m("Alignment", "Property", "Alignment As Integer", "0 = Left, 1 = Right, 2 = Center."),
		_m("Visible",   "Property", "Visible As Boolean",   "Gets or sets whether the label is shown."),
		_m("ForeColor", "Property", "ForeColor As Long",    "Gets or sets the text colour."),
		_m("FontSize",  "Property", "FontSize As Single",   "Gets or sets the font size in points."),
		_m("AutoSize",  "Property", "AutoSize As Boolean",  "If True, the label resizes to fit its caption."),
	]

	# -- LineEdit (TextBox) --
	vb["TextBox"] = [
		_m("Text",       "Property", "Text As String",       "Gets or sets the text content."),
		_m("MaxLength",  "Property", "MaxLength As Integer",  "Maximum number of characters allowed."),
		_m("Locked",     "Property", "Locked As Boolean",     "If True, the user cannot type in the box."),
		_m("Alignment",  "Property", "Alignment As Integer",  "0 = Left, 1 = Right, 2 = Center."),
		_m("Visible",    "Property", "Visible As Boolean",    "Gets or sets visibility."),
		_m("Enabled",    "Property", "Enabled As Boolean",    "Gets or sets whether input is accepted."),
		_m("FontSize",   "Property", "FontSize As Single",    "Gets or sets the font size."),
		_m("Change",     "Event",    "Sub controlname_Change()","Occurs when the text is modified."),
		_m("Click",      "Event",    "Sub controlname_Click()","Occurs when the user clicks the box."),
		_m("KeyPress",   "Event",    "Sub controlname_KeyPress(KeyAscii As Integer)","Occurs when a key is pressed."),
	]

	# -- CheckBox --
	vb["CheckBox"] = [
		_m("Caption", "Property", "Caption As String",      "Gets or sets the label text."),
		_m("Value",   "Property", "Value As Integer",        "0 = Unchecked, 1 = Checked, 2 = Grayed."),
		_m("Enabled", "Property", "Enabled As Boolean",      "Gets or sets whether the control is clickable."),
		_m("Visible", "Property", "Visible As Boolean",      "Gets or sets visibility."),
		_m("Click",   "Event",    "Sub controlname_Click()", "Occurs when the state changes."),
	]

	# -- OptionButton (ComboBox / DropDown) --
	vb["ComboBox"] = [
		_m("Text",      "Property", "Text As String",         "Gets or sets the current text."),
		_m("ListIndex", "Property", "ListIndex As Integer",   "Index of the currently selected item (−1 if none)."),
		_m("ListCount", "Property", "ListCount As Integer",   "Number of items in the list."),
		_m("AddItem",   "Method",   "AddItem item[, index]",  "Adds an item to the list."),
		_m("RemoveItem","Method",   "RemoveItem index",       "Removes an item from the list."),
		_m("Clear",     "Method",   "Clear",                   "Removes all items from the list."),
		_m("Click",     "Event",    "Sub controlname_Click()", "Occurs when an item is selected."),
		_m("Change",    "Event",    "Sub controlname_Change()","Occurs when the text portion changes."),
	]

	# -- Timer --
	vb["Timer"] = [
		_m("Interval", "Property", "Interval As Long",       "Milliseconds between Timer events (0 = disabled)."),
		_m("Enabled",  "Property", "Enabled As Boolean",     "Gets or sets whether the timer fires."),
		_m("Timer",    "Event",    "Sub controlname_Timer()", "Occurs each time the interval elapses."),
	]

	# -- PictureBox (TextureRect) --
	vb["PictureBox"] = [
		_m("Picture",   "Property", "Picture As StdPicture", "Gets or sets the displayed image."),
		_m("AutoSize",  "Property", "AutoSize As Boolean",   "Resizes the control to the image."),
		_m("Visible",   "Property", "Visible As Boolean",    "Gets or sets visibility."),
		_m("Width",     "Property", "Width As Single",       "Gets or sets the width."),
		_m("Height",    "Property", "Height As Single",      "Gets or sets the height."),
	]

	# -- HScrollBar / VScrollBar --
	vb["ScrollBar"] = [
		_m("Value",      "Property", "Value As Integer",      "Gets or sets the current position."),
		_m("Min",        "Property", "Min As Integer",        "Minimum value."),
		_m("Max",        "Property", "Max As Integer",        "Maximum value."),
		_m("SmallChange","Property", "SmallChange As Integer","Amount changed by arrow clicks."),
		_m("LargeChange","Property", "LargeChange As Integer","Amount changed by track clicks."),
		_m("Change",     "Event",    "Sub controlname_Change()","Occurs when the value changes."),
		_m("Scroll",     "Event",    "Sub controlname_Scroll()","Occurs while the thumb is dragged."),
	]

	# -- ListBox (ItemList) --
	vb["ListBox"] = [
		_m("ListIndex",  "Property", "ListIndex As Integer",  "Index of the currently selected item."),
		_m("ListCount",  "Property", "ListCount As Integer",  "Number of items."),
		_m("Text",       "Property", "Text As String",         "Text of the currently selected item."),
		_m("AddItem",    "Method",   "AddItem item[, index]",  "Adds an item."),
		_m("RemoveItem", "Method",   "RemoveItem index",       "Removes an item."),
		_m("Clear",      "Method",   "Clear",                   "Removes all items."),
		_m("Click",      "Event",    "Sub controlname_Click()", "Occurs when an item is selected."),
		_m("DblClick",   "Event",    "Sub controlname_DblClick()","Occurs when an item is double-clicked."),
	]

	# -- MenuBar --
	vb["MenuBar"] = [
		_m("Caption", "Property", "Caption As String",    "Gets or sets the menu item text."),
		_m("Enabled", "Property", "Enabled As Boolean",   "Gets or sets whether the menu item is clickable."),
		_m("Visible", "Property", "Visible As Boolean",   "Gets or sets whether the menu item is shown."),
		_m("Checked", "Property", "Checked As Boolean",   "Gets or sets the check mark."),
		_m("Click",   "Event",    "Sub menuname_Click()", "Occurs when the user clicks the menu item."),
	]

	# -- ProgressBar --
	vb["ProgressBar"] = [
		_m("Value",   "Property", "Value As Long",       "Gets or sets the current progress value."),
		_m("Min",     "Property", "Min As Long",         "Minimum value."),
		_m("Max",     "Property", "Max As Long",         "Maximum value."),
		_m("Visible", "Property", "Visible As Boolean",  "Gets or sets visibility."),
	]

	_libraries["VB"] = vb

	# ── VisualGasic Extensions Library ──
	var vge := {}

	vge["Godot"] = [
		_m("CreateNode",  "Function", "CreateNode(classname) As Object","Creates a new Godot node of the given class."),
		_m("Vector2",     "Function", "Vector2(x, y) As Vector2",    "Creates a 2D vector."),
		_m("Vector3",     "Function", "Vector3(x, y, z) As Vector3", "Creates a 3D vector."),
		_m("Color",       "Function", "Color(r, g, b[, a]) As Color","Creates a colour (0.0–1.0 per channel)."),
		_m("Color8",      "Function", "Color8(r, g, b[, a]) As Color","Creates a colour (0–255 per channel)."),
		_m("RGB",         "Function", "RGB(r, g, b) As Color",       "Creates a colour from 0–255 values."),
		_m("Rect2",       "Function", "Rect2(x, y, w, h) As Rect2", "Creates a 2D rectangle."),
		_m("CreateObject","Function", "CreateObject(classname) As Object","Creates a new Godot object by class name."),
	]

	vge["Input"] = [
		_m("IsKeyDown",       "Function", "IsKeyDown(keycode) As Boolean",   "Returns True if the specified key is held down."),
		_m("GetKey",          "Function", "GetKey(keyname) As Integer",      "Returns the key constant for a named key."),
		_m("IsMouseButtonDown","Function","IsMouseButtonDown(button) As Boolean","Returns True if the specified mouse button is held."),
	]

	vge["Data"] = [
		_m("DataCount",        "Function", "DataCount As Long",          "Returns the total number of DATA items."),
		_m("DataRemain",       "Function", "DataRemain As Long",         "Returns the number of unread DATA items."),
		_m("DataSectionCount", "Function", "DataSectionCount As Long",   "Returns the number of DATA sections."),
		_m("DataSectionRemain","Function", "DataSectionRemain As Long",  "Unread items in the current section."),
		_m("DataPointer",      "Function", "DataPointer As Long",        "Returns the current DATA read position."),
		_m("PeekData",         "Function", "PeekData([offset]) As Variant","Reads a DATA item without advancing the pointer."),
		_m("SetDataPointer",   "Sub",      "SetDataPointer position",     "Sets the DATA read position."),
		_m("DataLabels",       "Function", "DataLabels As String()",      "Returns the list of DATA section labels."),
		_m("DataSectionName",  "Function", "DataSectionName As String",   "Returns the name of the current DATA section."),
		_m("DataToArray",      "Function", "DataToArray([section]) As Variant()","Reads all DATA items into an array."),
	]

	_libraries["VisualGasic"] = vge

	# ── <All Libraries>  —  union ──
	var all_lib := {}
	for lib_name in _libraries:
		var lib: Dictionary = _libraries[lib_name]
		for cls_name in lib:
			if all_lib.has(cls_name):
				all_lib[cls_name] = all_lib[cls_name] + lib[cls_name]
			else:
				all_lib[cls_name] = lib[cls_name].duplicate()
	_libraries["<All Libraries>"] = all_lib

## Helper: create a member dictionary.
func _m(n: String, kind: String, sig: String, desc: String) -> Dictionary:
	return {"name": n, "kind": kind, "signature": sig, "description": desc}

# ─────────────────────────────────────────────────────────────────────
#  POPULATE
# ─────────────────────────────────────────────────────────────────────
func _populate_libraries():
	library_option.clear()
	var idx := 0
	# "<All Libraries>" first
	library_option.add_item("<All Libraries>")
	library_option.set_item_metadata(0, "<All Libraries>")
	idx += 1
	for lib_name in _libraries:
		if lib_name == "<All Libraries>":
			continue
		library_option.add_item(lib_name)
		library_option.set_item_metadata(idx, lib_name)
		idx += 1
	library_option.select(0)
	_show_library("<All Libraries>")

func _show_library(lib_name: String):
	class_list.clear()
	member_list.clear()
	desc_label.text = ""
	_current_classes = PackedStringArray()

	if not _libraries.has(lib_name):
		return

	var lib: Dictionary = _libraries[lib_name]
	var names: Array = lib.keys()
	names.sort()

	var filter := search_edit.text.strip_edges().to_lower() if search_edit else ""

	for cls_name in names:
		if filter != "" and cls_name.to_lower().find(filter) == -1:
			# Also check if any member matches
			var any_match := false
			for member in lib[cls_name]:
				if member["name"].to_lower().find(filter) != -1:
					any_match = true
					break
			if not any_match:
				continue
		class_list.add_item(cls_name)
		_current_classes.append(cls_name)

	if class_list.item_count > 0:
		class_list.select(0)
		_on_class_selected(0)
	# Update members header
	_update_members_header("")

func _show_members_for(cls_name: String):
	member_list.clear()
	desc_label.text = ""
	_update_members_header(cls_name)

	# Find the library currently selected
	var lib_name: String = _get_selected_library()
	if not _libraries.has(lib_name):
		return
	var lib: Dictionary = _libraries[lib_name]
	if not lib.has(cls_name):
		return

	var filter := search_edit.text.strip_edges().to_lower() if search_edit else ""

	for member in lib[cls_name]:
		if filter != "" and member["name"].to_lower().find(filter) == -1:
			continue
		var prefix := ""
		match member["kind"]:
			"Function": prefix = "⬡ "    # blue hex
			"Sub":      prefix = "⬡ "
			"Method":   prefix = "▸ "    # green arrow
			"Property": prefix = "■ "   # blue square
			"Event":    prefix = "⚡ "   # lightning
			"Constant": prefix = "● "   # purple dot
			"Statement":prefix = "▹ "
		member_list.add_item(prefix + member["name"])
		member_list.set_item_metadata(member_list.item_count - 1, member)

	if member_list.item_count > 0:
		member_list.select(0)
		_on_member_selected(0)

func _update_members_header(cls_name: String):
	var header_node = find_child("MembersHeader", true, false)
	if header_node:
		if cls_name != "":
			header_node.text = "Members of '" + cls_name + "'"
		else:
			header_node.text = "Members of"

func _get_selected_library() -> String:
	var idx = library_option.selected
	if idx < 0:
		return ""
	return library_option.get_item_metadata(idx)

# ─────────────────────────────────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────────────────────────────────
func _on_library_selected(idx: int):
	var lib_name = library_option.get_item_metadata(idx)
	_show_library(lib_name)

func _on_class_selected(idx: int):
	if idx < 0 or idx >= _current_classes.size():
		return
	var cls_name = _current_classes[idx]
	_show_members_for(cls_name)

func _on_member_selected(idx: int):
	if idx < 0 or idx >= member_list.item_count:
		return
	var meta: Dictionary = member_list.get_item_metadata(idx)
	if meta.is_empty():
		return
	desc_label.text = meta.get("signature", "") + "\n" + meta.get("description", "")

func _on_search_changed(_new_text: String):
	var lib_name = _get_selected_library()
	_show_library(lib_name)

# ─────────────────────────────────────────────────────────────────────
#  VB6 THEME
# ─────────────────────────────────────────────────────────────────────
func _build_vb6_theme() -> Theme:
	var t = Theme.new()

	# ── Window chrome ──
	var win_sb = StyleBoxFlat.new()
	win_sb.bg_color = VB6_HEADER_BG
	win_sb.border_color = VB6_HEADER_BORDER
	win_sb.set_border_width_all(2)
	win_sb.content_margin_left = 4; win_sb.content_margin_right = 4
	win_sb.content_margin_top = 4; win_sb.content_margin_bottom = 4
	t.set_stylebox("embedded_border", "Window", win_sb)
	var win_unfocus = win_sb.duplicate()
	win_unfocus.bg_color = Color(0.50, 0.50, 0.50)
	t.set_stylebox("embedded_unfocused_border", "Window", win_unfocus)
	t.set_color("title_color", "Window", VB6_HEADER_TEXT)
	t.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)

	# ── AcceptDialog panel ──
	var panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = VB6_PANEL_BG
	panel_sb.border_color = VB6_PANEL_BORDER
	panel_sb.set_border_width_all(1)
	panel_sb.set_content_margin_all(10)
	t.set_stylebox("panel", "AcceptDialog", panel_sb)

	# ── Label ──
	t.set_color("font_color", "Label", VB6_TEXT)

	# ── LineEdit (search box) ──
	var le_sb = StyleBoxFlat.new()
	le_sb.bg_color = VB6_LIST_BG
	le_sb.border_color = VB6_PANEL_BORDER
	le_sb.set_border_width_all(1)
	le_sb.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_stylebox("focus", "LineEdit", le_sb.duplicate())
	t.set_color("font_color", "LineEdit", VB6_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.5, 0.5))

	# ── ItemList (classes + members) ──
	var il_sb = StyleBoxFlat.new()
	il_sb.bg_color = VB6_LIST_BG
	il_sb.border_color = VB6_PANEL_BORDER
	il_sb.set_border_width_all(1)
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", VB6_TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	var il_sel = StyleBoxFlat.new()
	il_sel.bg_color = VB6_ACTIVE_TITLE
	t.set_stylebox("selected", "ItemList", il_sel)
	t.set_stylebox("selected_focus", "ItemList", il_sel)

	# ── RichTextLabel (description) ──
	var rt_sb = StyleBoxFlat.new()
	rt_sb.bg_color = VB6_LIST_BG
	rt_sb.border_color = VB6_PANEL_BORDER
	rt_sb.set_border_width_all(1)
	rt_sb.set_content_margin_all(6)
	t.set_stylebox("normal", "RichTextLabel", rt_sb)
	t.set_color("default_color", "RichTextLabel", VB6_TEXT)

	# ── OptionButton (library selector) ──
	var ob_sb = StyleBoxFlat.new()
	ob_sb.bg_color = VB6_PANEL_BG
	ob_sb.border_color = VB6_PANEL_BORDER
	ob_sb.set_border_width_all(1)
	ob_sb.content_margin_left = 6; ob_sb.content_margin_right = 6
	ob_sb.content_margin_top = 3; ob_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "OptionButton", ob_sb)
	var ob_hov = ob_sb.duplicate()
	ob_hov.bg_color = VB6_BTN_HOVER_BG
	t.set_stylebox("hover", "OptionButton", ob_hov)
	var ob_pre = ob_sb.duplicate()
	ob_pre.bg_color = VB6_BTN_PRESSED_BG
	t.set_stylebox("pressed", "OptionButton", ob_pre)
	t.set_color("font_color", "OptionButton", VB6_TEXT)
	t.set_color("font_hover_color", "OptionButton", VB6_TEXT)
	t.set_color("font_pressed_color", "OptionButton", VB6_TEXT)

	# ── Button ──
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = VB6_PANEL_BG
	btn_sb.border_color = VB6_PANEL_BORDER
	btn_sb.set_border_width_all(1)
	btn_sb.content_margin_left = 8; btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 3; btn_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn_sb)
	var btn_hov = btn_sb.duplicate()
	btn_hov.bg_color = VB6_BTN_HOVER_BG
	t.set_stylebox("hover", "Button", btn_hov)
	var btn_pre = btn_sb.duplicate()
	btn_pre.bg_color = VB6_BTN_PRESSED_BG
	t.set_stylebox("pressed", "Button", btn_pre)
	t.set_color("font_color", "Button", VB6_TEXT)
	t.set_color("font_hover_color", "Button", VB6_TEXT)
	t.set_color("font_pressed_color", "Button", VB6_TEXT)

	# ── HSeparator ──
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = VB6_PANEL_BORDER
	sep_sb.content_margin_top = 4; sep_sb.content_margin_bottom = 4
	t.set_stylebox("separator", "HSeparator", sep_sb)

	# ── ScrollBar ──
	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.92, 0.91, 0.89)
	scroll_bg.set_content_margin_all(2)
	var grabber_sb = StyleBoxFlat.new()
	grabber_sb.bg_color = Color(0.72, 0.71, 0.68)
	grabber_sb.set_content_margin_all(2)
	var grabber_hl = StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.60, 0.59, 0.56)
	grabber_hl.set_content_margin_all(2)
	var grabber_pr = StyleBoxFlat.new()
	grabber_pr.bg_color = Color(0.50, 0.49, 0.46)
	grabber_pr.set_content_margin_all(2)
	for sbar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbar, scroll_bg)
		t.set_stylebox("grabber", sbar, grabber_sb)
		t.set_stylebox("grabber_highlight", sbar, grabber_hl)
		t.set_stylebox("grabber_pressed", sbar, grabber_pr)

	# ── PopupMenu (OptionButton dropdown) ──
	var pm_sb = StyleBoxFlat.new()
	pm_sb.bg_color = VB6_LIST_BG
	pm_sb.border_color = VB6_PANEL_BORDER
	pm_sb.set_border_width_all(1)
	pm_sb.set_content_margin_all(4)
	t.set_stylebox("panel", "PopupMenu", pm_sb)
	t.set_color("font_color", "PopupMenu", VB6_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	var pm_hov = StyleBoxFlat.new()
	pm_hov.bg_color = VB6_ACTIVE_TITLE
	t.set_stylebox("hover", "PopupMenu", pm_hov)

	return t
