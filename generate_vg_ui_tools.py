#!/usr/bin/env python3
"""Generate the VG_UI_TOOLS demo project with all controls.

Every form below wires its controls to REAL, working VisualGasic code
(Button/CheckBox/OptionButton/HSlider/etc event handlers, a real Timer node,
TweenProperty-driven animation, a real FileDialog/ConfirmationDialog/PopupMenu,
etc.) so each form actually demonstrates what the control does instead of
just placing static labels describing it.

VG event auto-wiring convention used throughout (verified against
demo/test_suites/test_events.vg and addons/visual_gasic/vb6_importer.gd's
EVENT_MAP):
    Button/LinkButton     -> ControlName_Click()
    CheckBox              -> ControlName_Click(pressed)
    LineEdit               -> ControlName_Change(newText)
    TextEdit               -> ControlName_Change()
    OptionButton           -> ControlName_Click(index)
    ItemList               -> ControlName_Click(index) / ControlName_DblClick(index)
    Tree                   -> ControlName_Click()  (use .get_selected())
    HSlider/VSlider/H&VScrollBar/ProgressBar/SpinBox -> ControlName_Change(newValue)
    Timer                  -> ControlName_Timer()
    TabContainer           -> ControlName_Click()
"""
import os

OUT = "VG_UI_TOOLS"
THEME_PATH = "res://VG_UI_TOOLS/VB6Theme.tres"

# =========================================================================
# project.godot
# =========================================================================
PROJECT_CFG = """; Engine configuration file.
config_version=5

[application]
config/name="VG_UI_Tools"
config/description="VisualGasic UI Toolkit — interactive demo forms for every control in the VisualGasic IDE."
run/main_scene="res://VG_UI_TOOLS/BasicControls.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[rendering]
renderer/rendering_method="forward_plus"
"""

# =========================================================================
# Shared sub-resources used by all forms (VB6 theme styles + extras)
# =========================================================================
SHARED_STYLES = """
[sub_resource type="StyleBoxFlat" id="header_bg"]
bg_color = Color(0.0, 0.0, 0.5, 1.0)
content_margin_left = 8.0
content_margin_top = 6.0
content_margin_right = 8.0
content_margin_bottom = 6.0

[sub_resource type="StyleBoxFlat" id="section_bg"]
bg_color = Color(0.831, 0.816, 0.784, 1.0)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.51, 0.51, 0.51, 1.0)
content_margin_left = 8.0
content_margin_top = 4.0
content_margin_right = 8.0
content_margin_bottom = 4.0

[sub_resource type="StyleBoxFlat" id="feedback_bg"]
bg_color = Color(1.0, 1.0, 0.878, 1.0)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.4, 0.4, 0.0, 1.0)
content_margin_left = 8.0
content_margin_top = 6.0
content_margin_right = 8.0
content_margin_bottom = 6.0
"""

# =========================================================================
# TSCN generators for each form
# =========================================================================

def make_form_head(form_name, title, size=(640, 520), extra_ext_resources=None, extra_subresources=""):
    w, h = size
    lines = [
        '[gd_scene load_steps=14 format=3]',
        '',
        f'[ext_resource type="Theme" path="{THEME_PATH}" id="1"]',
        f'[ext_resource type="Script" path="res://VG_UI_TOOLS/{form_name}.vg" id="2"]',
        f'[ext_resource type="Script" path="res://addons/visual_gasic/form_editor_helper.gd" id="3"]',
    ]
    if extra_ext_resources:
        lines += extra_ext_resources
    lines.append(SHARED_STYLES)
    if extra_subresources:
        lines.append(extra_subresources)
    lines += [
        '',
        f'[node name="{form_name}" type="Window"]',
        f'title = "{title}"',
        'initial_position = 1',
        f'size = Vector2i({w}, {h})',
        'theme = ExtResource("1")',
        'script = ExtResource("2")',
        '',
        '[node name="_FormBackground" type="Panel" parent="."]',
        f'offset_right = {float(w)}',
        f'offset_bottom = {float(h)}',
        'mouse_filter = 2',
        'script = ExtResource("3")',
        '',
        '[node name="ScrollContainer" type="ScrollContainer" parent="."]',
        f'offset_right = {float(w)}',
        f'offset_bottom = {float(h)}',
        'follow_focus = true',
        '',
        '[node name="VBox" type="VBoxContainer" parent="ScrollContainer"]',
        f'offset_right = {float(w)}',
        '',
        '[node name="lblHeader" type="Label" parent="ScrollContainer/VBox"]',
        f'text = "{title}"',
        'theme_override_colors/font_color = Color(1.0, 1.0, 1.0, 1.0)',
        'theme_override_styles/normal = SubResource("header_bg")',
        'theme_override_font_sizes/font_size = 16',
    ]
    return lines


def section_label(name, text, parent="ScrollContainer/VBox"):
    return [
        f'[node name="{name}" type="Label" parent="{parent}"]',
        f'text = "{text}"',
        'theme_override_styles/normal = SubResource("section_bg")',
        'theme_override_font_sizes/font_size = 13',
    ]


def feedback_label(name="lblFeedback", text="Try the controls above.", parent="ScrollContainer/VBox"):
    return [
        f'[node name="{name}" type="Label" parent="{parent}"]',
        f'text = "{text}"',
        'autowrap_mode = 3',
        'theme_override_styles/normal = SubResource("feedback_bg")',
        'theme_override_font_sizes/font_size = 12',
    ]


def hbox_pair(label_name, label_text, control_node, parent="ScrollContainer/VBox", label_width=100):
    """HBoxContainer with a label on the left and a control on the right."""
    hbox_name = f"hbox_{label_name}"
    lines = [f'[node name="{hbox_name}" type="HBoxContainer" parent="{parent}"]']
    lines += [
        f'[node name="lbl_{label_name}" type="Label" parent="{parent}/{hbox_name}"]',
        f'text = "{label_text}"',
        f'custom_minimum_size = Vector2({label_width}, 0)',
        'vertical_alignment = 1',
    ]
    for ln in control_node:
        if ln.startswith('[node name=') and 'parent="ScrollContainer/VBox"' in ln:
            ln = ln.replace('parent="ScrollContainer/VBox"', f'parent="{parent}/{hbox_name}"')
        lines.append(ln)
    return lines


def button(name, text, parent="ScrollContainer/VBox", disabled=False, flat=False, tooltip=""):
    lines = [f'[node name="{name}" type="Button" parent="{parent}"]', f'text = "{text}"']
    if disabled:
        lines.append('disabled = true')
    if tooltip:
        lines.append(f'tooltip_text = "{tooltip}"')
    if flat:
        lines.append('flat = true')
    return lines


def label(name, text, parent="ScrollContainer/VBox", font_size=12, bold=False):
    lines = [f'[node name="{name}" type="Label" parent="{parent}"]', f'text = "{text}"']
    if font_size != 12:
        lines.append(f'theme_override_font_sizes/font_size = {font_size}')
    return lines


def line_edit(name, placeholder="", secret=False, text="", parent="ScrollContainer/VBox", expand=True):
    lines = [f'[node name="{name}" type="LineEdit" parent="{parent}"]']
    if placeholder:
        lines.append(f'placeholder_text = "{placeholder}"')
    if secret:
        lines.append('secret = true')
    if text:
        lines.append(f'text = "{text}"')
    if expand:
        lines.append('size_flags_horizontal = 3')
    return lines


def text_edit(name, placeholder="", text="", parent="ScrollContainer/VBox", height=80):
    lines = [
        f'[node name="{name}" type="TextEdit" parent="{parent}"]',
        f'custom_minimum_size = Vector2(0, {height})',
        'wrap_mode = 2',
    ]
    if placeholder:
        lines.append(f'placeholder_text = "{placeholder}"')
    if text:
        lines.append(f'text = "{text}"')
    return lines


def checkbox(name, text, checked=False, parent="ScrollContainer/VBox"):
    lines = [f'[node name="{name}" type="CheckBox" parent="{parent}"]', f'text = "{text}"']
    if checked:
        lines.append('button_pressed = true')
    return lines


def radio(name, text, group_id, parent="ScrollContainer/VBox"):
    """Godot has no built-in RadioButton class — a CheckBox with a shared
    ButtonGroup automatically renders/behaves as a radio button."""
    return [
        f'[node name="{name}" type="CheckBox" parent="{parent}"]',
        f'text = "{text}"',
        f'button_group = SubResource("{group_id}")',
    ]


def option_button(name, parent="ScrollContainer/VBox", expand=True):
    lines = [f'[node name="{name}" type="OptionButton" parent="{parent}"]']
    if expand:
        lines.append('size_flags_horizontal = 3')
    return lines


def progress_bar(name, value=50, parent="ScrollContainer/VBox", expand=True):
    lines = [f'[node name="{name}" type="ProgressBar" parent="{parent}"]', f'value = {float(value)}']
    if expand:
        lines.append('size_flags_horizontal = 3')
    return lines


def h_slider(name, value=50, parent="ScrollContainer/VBox", expand=True):
    lines = [f'[node name="{name}" type="HSlider" parent="{parent}"]', f'value = {float(value)}']
    if expand:
        lines.append('size_flags_horizontal = 3')
    return lines


def v_scrollbar(name, parent="ScrollContainer/VBox"):
    return [f'[node name="{name}" type="VScrollBar" parent="{parent}"]', 'custom_minimum_size = Vector2(16, 100)']


def h_scrollbar(name, parent="ScrollContainer/VBox"):
    return [f'[node name="{name}" type="HScrollBar" parent="{parent}"]', 'custom_minimum_size = Vector2(200, 16)']


def panel(name, size=(200, 80), parent="ScrollContainer/VBox"):
    return [f'[node name="{name}" type="Panel" parent="{parent}"]', f'custom_minimum_size = Vector2({size[0]}, {size[1]})']


def color_rect(name, color="1,0,0,1", size=(80, 40), parent="ScrollContainer/VBox"):
    return [
        f'[node name="{name}" type="ColorRect" parent="{parent}"]',
        f'color = Color({color})',
        f'custom_minimum_size = Vector2({size[0]}, {size[1]})',
    ]


def item_list(name, parent="ScrollContainer/VBox", height=100, select_mode_multi=False):
    lines = [f'[node name="{name}" type="ItemList" parent="{parent}"]', f'custom_minimum_size = Vector2(0, {height})']
    if select_mode_multi:
        lines.append('select_mode = 1')
    return lines


def tree(name, parent="ScrollContainer/VBox", height=120):
    return [f'[node name="{name}" type="Tree" parent="{parent}"]', f'custom_minimum_size = Vector2(0, {height})']


def tab_container(name, tabs, parent="ScrollContainer/VBox", height=140):
    """A TabContainer with real Label children on each tab (fixed: correct parent paths)."""
    lines = [f'[node name="{name}" type="TabContainer" parent="{parent}"]', f'custom_minimum_size = Vector2(0, {height})']
    tab_parent = f'{parent}/{name}'
    for i, tab_title in enumerate(tabs):
        tab_node_name = f'Tab{i}_{tab_title.replace(" ", "")}'
        lines += [
            f'[node name="{tab_node_name}" type="Label" parent="{tab_parent}"]',
            f'text = "This is the \'{tab_title}\' tab. Click the tabs above to switch pages."',
            'autowrap_mode = 3',
        ]
    return lines


def separator_h(parent="ScrollContainer/VBox"):
    return [f'[node name="HSep" type="HSeparator" parent="{parent}"]']


def separator_v(parent="ScrollContainer/VBox"):
    return [f'[node name="VSep" type="VSeparator" parent="{parent}"]']


def texture_rect(name, parent="ScrollContainer/VBox", size=(100, 60)):
    return [
        f'[node name="{name}" type="TextureRect" parent="{parent}"]',
        f'custom_minimum_size = Vector2({size[0]}, {size[1]})',
        'expand_mode = 1',
    ]


def texture_button(name, text, parent="ScrollContainer/VBox", size=(80, 40)):
    return [
        f'[node name="{name}" type="Button" parent="{parent}"]',
        f'text = "{text}"',
        f'custom_minimum_size = Vector2({size[0]}, {size[1]})',
    ]


def rich_text_label(name, text, parent="ScrollContainer/VBox", height=80):
    return [
        f'[node name="{name}" type="RichTextLabel" parent="{parent}"]',
        f'text = "{text}"',
        f'custom_minimum_size = Vector2(0, {height})',
        'bbcode_enabled = true',
        'fit_content = true',
    ]


def spin_box(name, value=0, min_v=0, max_v=100, parent="ScrollContainer/VBox"):
    return [
        f'[node name="{name}" type="SpinBox" parent="{parent}"]',
        f'value = {value}',
        f'min_value = {min_v}',
        f'max_value = {max_v}',
    ]


def link_button(name, text, uri="", parent="ScrollContainer/VBox"):
    lines = [f'[node name="{name}" type="LinkButton" parent="{parent}"]', f'text = "{text}"']
    if uri:
        lines.append(f'uri = "{uri}"')
    return lines


def timer_node(name, wait_time=1.0, one_shot=False, autostart=False, parent="ScrollContainer/VBox"):
    lines = [
        f'[node name="{name}" type="Timer" parent="{parent}"]',
        f'wait_time = {wait_time}',
    ]
    if one_shot:
        lines.append('one_shot = true')
    if autostart:
        lines.append('autostart = true')
    return lines


def menu_button(name, text, parent="ScrollContainer/VBox/hboxMenuBar"):
    return [f'[node name="{name}" type="MenuButton" parent="{parent}"]', f'text = "{text}"', 'flat = false']


def build_full_tscn(form_name, title, size, body_blocks, extra_ext_resources=None, extra_subresources=""):
    head = make_form_head(form_name, title, size, extra_ext_resources, extra_subresources)
    all_lines = head[:]
    all_lines.append('')
    for block in body_blocks:
        all_lines.extend(block)
        all_lines.append('')
    return '\n'.join(all_lines) + '\n'


# =========================================================================
# Form 1: BasicControls
# =========================================================================
GENDER_GROUP = '[sub_resource type="ButtonGroup" id="genderGroup"]'

BASIC_BODY = [
    section_label("secButtons", "── Buttons ──"),
    button("btnNormal", "Normal Button", tooltip="A standard push button."),
    button("btnDisabled", "Disabled Button", disabled=True, tooltip="This button is disabled."),
    button("btnFlat", "Flat Button", flat=True, tooltip="A flat/toolbar-style button."),
    section_label("secInputs", "── Text Inputs ──"),
    hbox_pair("txtName", "Name:", line_edit("txtName", "Enter your name...")),
    hbox_pair("txtPassword", "Password:", line_edit("txtPassword", "Enter password...", secret=True)),
    label("lblBio", "Bio (multiline — live word count):"),
    text_edit("txtBio", "Write a short bio...", height=70),
    section_label("secSelection", "── Selection Controls ──"),
    checkbox("chkFeature", "Enable Feature", checked=True),
    hbox_pair("optGender", "Gender:", [
        *radio("optMale", "Male", "genderGroup"),
        *radio("optFemale", "Female", "genderGroup"),
        *radio("optOther", "Other", "genderGroup"),
    ]),
    hbox_pair("cboCountry", "Country:", option_button("cboCountry")),
    section_label("secProgress", "── Progress & Sliders ──"),
    hbox_pair("barProgress", "Volume level:", progress_bar("barProgress", 75)),
    hbox_pair("sldVolume", "Volume:", h_slider("sldVolume", 75)),
    hbox_pair("sbVertical", "Scroll Y:", v_scrollbar("sbVertical")),
    feedback_label(),
]

BASIC_VG = '''\' BasicControls — VisualGasic UI Toolkit Demo
\' Controls demonstrated: Button, Label, LineEdit, TextEdit, CheckBox, RadioButton, OptionButton, ProgressBar, HSlider, VScrollBar
Option Explicit

Dim clickCount As Integer

Private Sub Form_Load()
    clickCount = 0
    cboCountry.add_item("United States")
    cboCountry.add_item("United Kingdom")
    cboCountry.add_item("Canada")
    cboCountry.add_item("Australia")
    lblFeedback.Text = "Try the controls above — this label reacts to every one of them."
End Sub

Private Sub btnNormal_Click()
    clickCount = clickCount + 1
    lblFeedback.Text = "Normal Button clicked " & clickCount & " time(s)."
End Sub

Private Sub btnFlat_Click()
    lblFeedback.Text = "Flat Button clicked — no border, like a VB6 flat-style button."
End Sub

Private Sub txtName_Change(newText)
    If Len(newText) > 0 Then
        lblFeedback.Text = "Hello, " & newText & "!"
    Else
        lblFeedback.Text = "Try the controls above — this label reacts to every one of them."
    End If
End Sub

Private Sub txtPassword_Change(newText)
    Dim strength As String
    If Len(newText) = 0 Then
        strength = "(empty)"
    ElseIf Len(newText) < 6 Then
        strength = "Weak"
    ElseIf Len(newText) < 10 Then
        strength = "Medium"
    Else
        strength = "Strong"
    End If
    lblFeedback.Text = "Password strength: " & strength & " (" & Len(newText) & " characters)"
End Sub

Private Sub txtBio_Change()
    Dim wordCount As Integer
    Dim bioText As String
    bioText = Trim(txtBio.text)
    If Len(bioText) = 0 Then
        wordCount = 0
    Else
        Dim parts As Variant
        parts = Split(bioText, " ")
        wordCount = UBound(parts) + 1
    End If
    lblFeedback.Text = "Bio word count: " & wordCount
End Sub

Private Sub chkFeature_Click(pressed)
    If pressed Then
        lblFeedback.Text = "Feature enabled."
    Else
        lblFeedback.Text = "Feature disabled."
    End If
End Sub

Private Sub optMale_Click()
    lblFeedback.Text = "Gender selected: Male"
End Sub

Private Sub optFemale_Click()
    lblFeedback.Text = "Gender selected: Female"
End Sub

Private Sub optOther_Click()
    lblFeedback.Text = "Gender selected: Other"
End Sub

Private Sub cboCountry_Click(index)
    lblFeedback.Text = "Country selected: " & cboCountry.get_item_text(index)
End Sub

Private Sub sldVolume_Change(newValue)
    barProgress.value = newValue
    lblFeedback.Text = "Volume: " & CInt(newValue) & "%"
End Sub

Private Sub sbVertical_Change(newValue)
    lblFeedback.Text = "Vertical scroll position: " & CInt(newValue)
End Sub
'''

# =========================================================================
# Form 2: ListControls
# =========================================================================
LIST_BODY = [
    section_label("secListBox", "── ItemList (ListBox) — add/remove items ──"),
    label("lblItemList", "Type a name and click Add, or select an item and click Remove:", font_size=11),
    hbox_pair("txtNewItem", "New item:", line_edit("txtNewItem", "e.g. Alice")),
    ['[node name="hboxListButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("btnAddItem", "Add", parent="ScrollContainer/VBox/hboxListButtons"),
    button("btnRemoveItem", "Remove Selected", parent="ScrollContainer/VBox/hboxListButtons"),
    item_list("lstItems", height=120, select_mode_multi=True),
    section_label("secTree", "── Tree View — click a node ──"),
    tree("treeMain", height=140),
    section_label("secCombo", "── ComboBox / Dropdowns ──"),
    hbox_pair("cboFruit", "Favorite fruit:", option_button("cboFruit")),
    section_label("secDriveList", "── DriveListBox ──"),
    label("lblDriveList", "DriveListBox — real drives/roots detected for this OS:", font_size=11),
    option_button("cboDrives"),
    feedback_label(),
]

LIST_VG = '''\' ListControls — VisualGasic UI Toolkit Demo
\' Controls demonstrated: ItemList (ListBox), Tree, ComboBox, DriveListBox
Option Explicit

Private Sub Form_Load()
    lstItems.add_item("Alice")
    lstItems.add_item("Bob")
    lstItems.add_item("Carlos")

    Dim root
    Set root = treeMain.create_item()
    root.set_text(0, "Documents")
    Dim child1
    Set child1 = treeMain.create_item(root)
    child1.set_text(0, "Report.docx")
    Dim child2
    Set child2 = treeMain.create_item(root)
    child2.set_text(0, "Budget.xlsx")
    Dim pics
    Set pics = treeMain.create_item(root)
    pics.set_text(0, "Pictures")
    Dim pic1
    Set pic1 = treeMain.create_item(pics)
    pic1.set_text(0, "Vacation.png")

    cboFruit.add_item("Apple")
    cboFruit.add_item("Banana")
    cboFruit.add_item("Cherry")
    cboFruit.add_item("Dragonfruit")

    If OS.get_name() = "Windows" Then
        cboDrives.add_item("C:\\")
        cboDrives.add_item("D:\\")
    Else
        cboDrives.add_item("/")
        cboDrives.add_item("/home")
        cboDrives.add_item("/tmp")
    End If

    lblFeedback.Text = "Add items, click the tree, or pick a fruit/drive."
End Sub

Private Sub btnAddItem_Click()
    If Len(Trim(txtNewItem.text)) > 0 Then
        lstItems.add_item(Trim(txtNewItem.text))
        lblFeedback.Text = "Added '" & Trim(txtNewItem.text) & "' to the list."
        txtNewItem.text = ""
    Else
        lblFeedback.Text = "Type a name first, then click Add."
    End If
End Sub

Private Sub btnRemoveItem_Click()
    Dim selected
    selected = lstItems.get_selected_items()
    Dim i As Integer
    Dim removedCount As Integer
    removedCount = 0
    For i = UBound(selected) To 0 Step -1
        lstItems.remove_item(selected(i))
        removedCount = removedCount + 1
    Next i
    If removedCount > 0 Then
        lblFeedback.Text = "Removed " & removedCount & " item(s)."
    Else
        lblFeedback.Text = "Select one or more items first, then click Remove."
    End If
End Sub

Private Sub lstItems_Click(index)
    lblFeedback.Text = "Selected: " & lstItems.get_item_text(index)
End Sub

Private Sub treeMain_Click()
    Dim item
    Set item = treeMain.get_selected()
    If Not item Is Nothing Then
        lblFeedback.Text = "Tree node selected: " & item.get_text(0)
    End If
End Sub

Private Sub cboFruit_Click(index)
    lblFeedback.Text = "Favorite fruit: " & cboFruit.get_item_text(index)
End Sub

Private Sub cboDrives_Click(index)
    lblFeedback.Text = "Drive selected: " & cboDrives.get_item_text(index)
End Sub
'''

# =========================================================================
# Form 3: ContainerControls
# =========================================================================
CONTAINER_BODY = [
    section_label("secTabContainer", "── TabContainer — click the tabs ──"),
    tab_container("tabMain", ["General", "Advanced", "About"], height=110),
    section_label("secPanel", "── Panel / GroupBox — clickable group ──"),
    label("lblPanel", "Click inside the panel below to toggle its color:", font_size=11),
    panel("pnlGroup", (250, 60)),
    section_label("secToolbar", "── Toolbar — buttons change the status label ──"),
    ['[node name="hboxToolbar" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("tbNew", "New", parent="ScrollContainer/VBox/hboxToolbar", flat=True),
    button("tbOpen", "Open", parent="ScrollContainer/VBox/hboxToolbar", flat=True),
    button("tbSave", "Save", parent="ScrollContainer/VBox/hboxToolbar", flat=True),
    feedback_label(),
]

CONTAINER_VG = '''\' ContainerControls — VisualGasic UI Toolkit Demo
\' Controls demonstrated: TabContainer, Panel/GroupBox, Toolbar
Option Explicit

Dim pnlToggled As Boolean

Private Sub Form_Load()
    pnlToggled = False
    lblFeedback.Text = "Switch tabs, click the panel, or use the toolbar."
End Sub

Private Sub tabMain_Click()
    lblFeedback.Text = "Tab changed to index " & tabMain.current_tab & " ('" & tabMain.get_tab_title(tabMain.current_tab) & "')."
End Sub

Private Sub pnlGroup_GuiInput(ev)
    If TypeOf ev Is InputEventMouseButton Then
        If ev.pressed And ev.button_index = MOUSE_BUTTON_LEFT Then
            pnlToggled = Not pnlToggled
            If pnlToggled Then
                TweenProperty pnlGroup, "modulate", Color(0.6, 0.8, 1.0, 1.0), 0.25
                lblFeedback.Text = "Panel clicked — highlighted blue."
            Else
                TweenProperty pnlGroup, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25
                lblFeedback.Text = "Panel clicked — back to normal."
            End If
        End If
    End If
End Sub

Private Sub tbNew_Click()
    lblFeedback.Text = "Toolbar: New clicked."
End Sub

Private Sub tbOpen_Click()
    lblFeedback.Text = "Toolbar: Open clicked."
End Sub

Private Sub tbSave_Click()
    lblFeedback.Text = "Toolbar: Save clicked."
End Sub
'''

# =========================================================================
# Form 4: DisplayControls
# =========================================================================
DISPLAY_BODY = [
    section_label("secColorRect", "── ColorRect — click a swatch to select it ──"),
    ['[node name="hboxColors" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    color_rect("crRed", "1,0,0,1", (80, 40), parent="ScrollContainer/VBox/hboxColors"),
    color_rect("crGreen", "0,1,0,1", (80, 40), parent="ScrollContainer/VBox/hboxColors"),
    color_rect("crBlue", "0,0,1,1", (80, 40), parent="ScrollContainer/VBox/hboxColors"),
    section_label("secTextureButton", "── Buttons that change the picture box below ──"),
    ['[node name="hboxPicButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    texture_button("tbtnRed", "Red", parent="ScrollContainer/VBox/hboxPicButtons"),
    texture_button("tbtnGreen", "Green", parent="ScrollContainer/VBox/hboxPicButtons"),
    texture_button("tbtnBlue", "Blue", parent="ScrollContainer/VBox/hboxPicButtons"),
    label("lblTextureRect", "PictureBox (TextureRect) — recolored by the buttons above:", font_size=11),
    color_rect("imgPlaceholder", "0.8,0.8,0.8,1", (200, 80)),
    section_label("secRichText", "── RichTextLabel — BBCode-formatted, updates live ──"),
    rich_text_label("rtfDemo", "[b]Bold[/b], [i]Italic[/i], [color=red]Red Text[/color]", height=50),
    hbox_pair("txtRichInput", "Type here:", line_edit("txtRichInput", "Type to update the RichTextLabel above...")),
    feedback_label(),
]

DISPLAY_VG = '''\' DisplayControls — VisualGasic UI Toolkit Demo
\' Controls demonstrated: ColorRect, PictureBox (TextureRect), RichTextLabel
Option Explicit

Private Sub Form_Load()
    lblFeedback.Text = "Click a swatch, a picture button, or type below."
End Sub

Private Sub crRed_GuiInput(ev)
    If TypeOf ev Is InputEventMouseButton And ev.pressed Then
        lblFeedback.Text = "Red swatch selected."
    End If
End Sub

Private Sub crGreen_GuiInput(ev)
    If TypeOf ev Is InputEventMouseButton And ev.pressed Then
        lblFeedback.Text = "Green swatch selected."
    End If
End Sub

Private Sub crBlue_GuiInput(ev)
    If TypeOf ev Is InputEventMouseButton And ev.pressed Then
        lblFeedback.Text = "Blue swatch selected."
    End If
End Sub

Private Sub tbtnRed_Click()
    imgPlaceholder.color = Color(1.0, 0.3, 0.3, 1.0)
    lblFeedback.Text = "Picture box recolored to red."
End Sub

Private Sub tbtnGreen_Click()
    imgPlaceholder.color = Color(0.3, 1.0, 0.3, 1.0)
    lblFeedback.Text = "Picture box recolored to green."
End Sub

Private Sub tbtnBlue_Click()
    imgPlaceholder.color = Color(0.3, 0.3, 1.0, 1.0)
    lblFeedback.Text = "Picture box recolored to blue."
End Sub

Private Sub txtRichInput_Change(newText)
    If Len(newText) > 0 Then
        rtfDemo.text = "[b]" & newText & "[/b] — typed live!"
    Else
        rtfDemo.text = "[b]Bold[/b], [i]Italic[/i], [color=red]Red Text[/color]"
    End If
End Sub
'''

# =========================================================================
# Form 5: AdvancedControls
# =========================================================================
ADVANCED_BODY = [
    section_label("secSpinBox", "── SpinBox / UpDown ──"),
    hbox_pair("spnAge", "Age:", spin_box("spnAge", 25, 0, 120)),
    hbox_pair("spnQuantity", "Qty:", spin_box("spnQuantity", 10, 1, 1000)),
    label("lblSpinTotal", "Total (Qty × $1.50): $15.00", font_size=11),
    section_label("secLinkButton", "── LinkButton — opens your browser ──"),
    link_button("lnkWebsite", "Visit VisualGasic on GitHub", uri="https://github.com/VisualGasic"),
    section_label("secCheckList", "── CheckBox List — enables Save when any are checked ──"),
    checkbox("chkOption1", "Option A — Email notifications", checked=True),
    checkbox("chkOption2", "Option B — SMS alerts"),
    checkbox("chkOption3", "Option C — Push notifications", checked=True),
    button("btnSavePrefs", "Save Preferences"),
    section_label("secFileDialog", "── FileDialog (real Godot file picker) ──"),
    button("btnOpenFile", "Open File...", tooltip="Opens the standard file open dialog."),
    button("btnSaveFile", "Save File...", tooltip="Opens the standard file save dialog."),
    feedback_label(),
]

ADVANCED_VG = '''\' AdvancedControls — VisualGasic UI Toolkit Demo
\' Controls demonstrated: SpinBox, LinkButton, CheckBox list, FileDialog
Option Explicit

Dim openDlg As Object
Dim saveDlg As Object

Private Sub Form_Load()
    UpdateTotal
    lblFeedback.Text = "Adjust the spinboxes, or try the file dialogs below."

    Set openDlg = New FileDialog
    openDlg.Title = "Open File"
    openDlg.FileMode = 0   \' FILE_MODE_OPEN_FILE
    openDlg.Access = 2     \' ACCESS_FILESYSTEM
    openDlg.Size = Vector2(600, 400)
    Me.AddChild(openDlg)
    Connect openDlg, "file_selected", "OnOpenFileSelected"

    Set saveDlg = New FileDialog
    saveDlg.Title = "Save File"
    saveDlg.FileMode = 2   \' FILE_MODE_SAVE_FILE
    saveDlg.Access = 2     \' ACCESS_FILESYSTEM
    saveDlg.Size = Vector2(600, 400)
    Me.AddChild(saveDlg)
    Connect saveDlg, "file_selected", "OnSaveFileSelected"
End Sub

Sub UpdateTotal()
    lblSpinTotal.text = "Total (Qty × $1.50): $" & Format(spnQuantity.value * 1.5, "0.00")
End Sub

Private Sub spnAge_Change(newValue)
    lblFeedback.Text = "Age set to " & CInt(newValue)
End Sub

Private Sub spnQuantity_Change(newValue)
    UpdateTotal
    lblFeedback.Text = "Quantity set to " & CInt(newValue)
End Sub

Private Sub chkOption1_Click(pressed)
    RefreshSaveButton
End Sub

Private Sub chkOption2_Click(pressed)
    RefreshSaveButton
End Sub

Private Sub chkOption3_Click(pressed)
    RefreshSaveButton
End Sub

Sub RefreshSaveButton()
    btnSavePrefs.disabled = Not (chkOption1.button_pressed Or chkOption2.button_pressed Or chkOption3.button_pressed)
End Sub

Private Sub btnSavePrefs_Click()
    lblFeedback.Text = "Preferences saved!"
End Sub

Private Sub btnOpenFile_Click()
    openDlg.PopupCentered(Vector2(600, 400))
End Sub

Private Sub btnSaveFile_Click()
    saveDlg.PopupCentered(Vector2(600, 400))
End Sub

Sub OnOpenFileSelected(path)
    lblFeedback.Text = "You chose to open: " & path
End Sub

Sub OnSaveFileSelected(path)
    lblFeedback.Text = "You chose to save as: " & path
End Sub
'''

# =========================================================================
# Form 6: TimerAndAnimation
# =========================================================================
TIMER_BODY = [
    section_label("secTimer", "── Timer — real Timer node, fires every second ──"),
    label("lblTimer", "Click Start to begin the clock (live Timer.Timer event):", font_size=11),
    label("lblClock", "00:00:00", font_size=20),
    ['[node name="hboxTimerButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("btnStartTimer", "Start Timer", parent="ScrollContainer/VBox/hboxTimerButtons"),
    button("btnStopTimer", "Stop Timer", parent="ScrollContainer/VBox/hboxTimerButtons"),
    timer_node("tmrClock", wait_time=1.0, one_shot=False, autostart=False),
    section_label("secAnimation", "── Animation — TweenProperty fades/moves the box ──"),
    label("lblAnimation", "Click a button to animate the box below:", font_size=11),
    ['[node name="hboxAnimButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("btnFadeAnim", "Fade", parent="ScrollContainer/VBox/hboxAnimButtons"),
    button("btnSlideAnim", "Slide", parent="ScrollContainer/VBox/hboxAnimButtons"),
    button("btnSpinAnim", "Spin", parent="ScrollContainer/VBox/hboxAnimButtons"),
    color_rect("animDemoRect", "0.2,0.4,0.9,1", (60, 60)),
    section_label("secDatePicker", "── DatePicker / Calendar — click a day ──"),
    label("lblDatePicker", "Days of the current month — click one to select it:", font_size=11),
    item_list("lstCalendarDays", height=110),
    label("lblSelectedDate", "Selected date: (none)", font_size=11),
    feedback_label(),
]

TIMER_VG = '''\' TimerAndAnimation — VisualGasic UI Toolkit Demo
\' Controls demonstrated: Timer, Animation (TweenProperty), Calendar/DatePicker
Option Explicit

Dim seconds As Integer
Dim currentMonth As Integer
Dim currentYear As Integer

Private Sub Form_Load()
    seconds = 0
    lblClock.text = "00:00:00"

    Dim dt
    Set dt = Time.get_datetime_dict_from_system()
    currentMonth = dt["month"]
    currentYear = dt["year"]

    Dim daysInMonth As Integer
    daysInMonth = 30
    Select Case currentMonth
        Case 1, 3, 5, 7, 8, 10, 12
            daysInMonth = 31
        Case 4, 6, 9, 11
            daysInMonth = 30
        Case 2
            daysInMonth = 28
            If (currentYear Mod 4 = 0 And currentYear Mod 100 <> 0) Or (currentYear Mod 400 = 0) Then
                daysInMonth = 29
            End If
    End Select

    Dim d As Integer
    For d = 1 To daysInMonth
        lstCalendarDays.add_item(CStr(d))
    Next d

    lblFeedback.Text = "Start the timer, try an animation, or pick a date."
End Sub

Private Sub btnStartTimer_Click()
    tmrClock.start()
    lblFeedback.Text = "Timer started."
End Sub

Private Sub btnStopTimer_Click()
    tmrClock.stop()
    lblFeedback.Text = "Timer stopped."
End Sub

Private Sub tmrClock_Timer()
    seconds = seconds + 1
    Dim h As Integer
    Dim m As Integer
    Dim s As Integer
    h = seconds \\ 3600
    m = (seconds Mod 3600) \\ 60
    s = seconds Mod 60
    lblClock.text = Format(h, "00") & ":" & Format(m, "00") & ":" & Format(s, "00")
End Sub

Private Sub btnFadeAnim_Click()
    animDemoRect.modulate = Color(1, 1, 1, 1)
    TweenProperty animDemoRect, "modulate:a", 0.15, 0.4
    lblFeedback.Text = "Fade animation triggered."
End Sub

Private Sub btnSlideAnim_Click()
    animDemoRect.position = Vector2(0, animDemoRect.position.y)
    TweenProperty animDemoRect, "position:x", 220.0, 0.5
    lblFeedback.Text = "Slide animation triggered."
End Sub

Private Sub btnSpinAnim_Click()
    animDemoRect.rotation = 0.0
    TweenProperty animDemoRect, "rotation", 6.2832, 0.6
    lblFeedback.Text = "Spin animation triggered."
End Sub

Private Sub lstCalendarDays_Click(index)
    lblSelectedDate.text = "Selected date: " & currentYear & "-" & Format(currentMonth, "00") & "-" & Format(index + 1, "00")
    lblFeedback.Text = "Date picked from calendar."
End Sub
'''

# =========================================================================
# Form 7: CustomWidgets
# =========================================================================
CUSTOM_BODY = [
    section_label("secToggleSwitch", "── ToggleSwitch — dark mode ──"),
    checkbox("tglDarkMode", "Dark Mode", checked=False),
    section_label("secBreadcrumbs", "── Breadcrumbs — click to navigate ──"),
    ['[node name="hboxCrumbs" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("crumbHome", "Home", parent="ScrollContainer/VBox/hboxCrumbs", flat=True),
    button("crumbProducts", "Products", parent="ScrollContainer/VBox/hboxCrumbs", flat=True),
    button("crumbDetail", "Detail", parent="ScrollContainer/VBox/hboxCrumbs", flat=True),
    label("lblBreadcrumbPath", "Current path: Home", font_size=11),
    section_label("secSpinner", "── Spinner — indeterminate progress (Start/Stop) ──"),
    ['[node name="hboxSpinnerButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("btnSpinnerStart", "Start Spinner", parent="ScrollContainer/VBox/hboxSpinnerButtons"),
    button("btnSpinnerStop", "Stop Spinner", parent="ScrollContainer/VBox/hboxSpinnerButtons"),
    progress_bar("spinner", 0),
    timer_node("tmrSpinner", wait_time=0.05, one_shot=False, autostart=False),
    section_label("secExpander", "── Expander — collapsible section ──"),
    button("btnExpand", "▶ Show Details"),
    label("lblExpandedContent", "Hidden content revealed when expanded — this is where extra options would go.", font_size=10),
    section_label("secMaskedEdit", "── MaskedEdit — live format validation ──"),
    hbox_pair("txtPhone", "Phone:", line_edit("txtPhone", "(###) ###-####")),
    feedback_label(),
]

CUSTOM_VG = '''\' CustomWidgets — VisualGasic UI Toolkit Demo
\' Controls demonstrated: ToggleSwitch, Breadcrumbs, Spinner, Expander, MaskedEdit
Option Explicit

Dim expanded As Boolean
Dim spinnerValue As Integer

Private Sub Form_Load()
    expanded = False
    lblExpandedContent.visible = False
    spinnerValue = 0
    lblFeedback.Text = "Toggle dark mode, click a breadcrumb, or start the spinner."
End Sub

Private Sub tglDarkMode_Click(pressed)
    If pressed Then
        Me._FormBackground.modulate = Color(0.25, 0.25, 0.3, 1.0)
        lblFeedback.Text = "Dark mode ON."
    Else
        Me._FormBackground.modulate = Color(1.0, 1.0, 1.0, 1.0)
        lblFeedback.Text = "Dark mode OFF."
    End If
End Sub

Private Sub crumbHome_Click()
    lblBreadcrumbPath.text = "Current path: Home"
    lblFeedback.Text = "Navigated to Home."
End Sub

Private Sub crumbProducts_Click()
    lblBreadcrumbPath.text = "Current path: Home > Products"
    lblFeedback.Text = "Navigated to Products."
End Sub

Private Sub crumbDetail_Click()
    lblBreadcrumbPath.text = "Current path: Home > Products > Detail"
    lblFeedback.Text = "Navigated to Detail."
End Sub

Private Sub btnSpinnerStart_Click()
    tmrSpinner.start()
    lblFeedback.Text = "Spinner started."
End Sub

Private Sub btnSpinnerStop_Click()
    tmrSpinner.stop()
    spinner.value = 0
    lblFeedback.Text = "Spinner stopped."
End Sub

Private Sub tmrSpinner_Timer()
    spinnerValue = (spinnerValue + 5) Mod 100
    spinner.value = spinnerValue
End Sub

Private Sub btnExpand_Click()
    expanded = Not expanded
    lblExpandedContent.visible = expanded
    If expanded Then
        btnExpand.text = "▼ Hide Details"
    Else
        btnExpand.text = "▶ Show Details"
    End If
End Sub

Private Sub txtPhone_Change(newText)
    Dim digitsOnly As String
    Dim i As Integer
    digitsOnly = ""
    For i = 1 To Len(newText)
        Dim ch As String
        ch = Mid(newText, i, 1)
        If ch >= "0" And ch <= "9" Then
            digitsOnly = digitsOnly & ch
        End If
    Next i
    If Len(digitsOnly) = 10 Then
        lblFeedback.Text = "Valid phone number: (" & Mid(digitsOnly, 1, 3) & ") " & Mid(digitsOnly, 4, 3) & "-" & Mid(digitsOnly, 7, 4)
    Else
        lblFeedback.Text = "Phone: " & Len(digitsOnly) & "/10 digits entered."
    End If
End Sub
'''

# =========================================================================
# Form 8: MenusAndStatus
# =========================================================================
MENUS_BODY = [
    section_label("secMenuBar", "── MenuBar — real MenuButton + PopupMenu ──"),
    ['[node name="hboxMenuBar" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    menu_button("mnuFile", "File"),
    menu_button("mnuEdit", "Edit"),
    menu_button("mnuHelp", "Help"),
    section_label("secContextMenu", "── Right-Click Context Menu ──"),
    label("lblContextMenu", "Right-click inside the box below:", font_size=11),
    panel("pnlContextArea", (300, 70)),
    section_label("secShortcuts", "── Keyboard Shortcuts (try them now) ──"),
    label("lblShortcuts", "Ctrl+O = Open   Ctrl+S = Save   F1 = Help   Ctrl+Q = Quit", font_size=10),
    section_label("secStatusBar", "── StatusBar ──"),
    feedback_label("lblStatus", "Ready"),
]

MENUS_VG = '''\' MenusAndStatus — VisualGasic UI Toolkit Demo
\' Controls demonstrated: MenuBar (MenuButton+PopupMenu), StatusBar, ContextMenu, Keyboard Shortcuts
Option Explicit

Dim ctxMenu As Object

Private Sub Form_Load()
    mnuFile.get_popup().add_item("New", 0)
    mnuFile.get_popup().add_item("Open", 1)
    mnuFile.get_popup().add_item("Save", 2)
    mnuFile.get_popup().add_item("Exit", 3)
    Connect mnuFile.get_popup(), "id_pressed", "OnFileMenuPressed"

    mnuEdit.get_popup().add_item("Cut", 0)
    mnuEdit.get_popup().add_item("Copy", 1)
    mnuEdit.get_popup().add_item("Paste", 2)
    Connect mnuEdit.get_popup(), "id_pressed", "OnEditMenuPressed"

    mnuHelp.get_popup().add_item("About", 0)
    Connect mnuHelp.get_popup(), "id_pressed", "OnHelpMenuPressed"

    Set ctxMenu = New PopupMenu
    ctxMenu.add_item("Cut", 0)
    ctxMenu.add_item("Copy", 1)
    ctxMenu.add_item("Paste", 2)
    ctxMenu.add_separator()
    ctxMenu.add_item("Delete", 3)
    Me.AddChild(ctxMenu)
    Connect ctxMenu, "id_pressed", "OnContextMenuPressed"

    lblStatus.Text = "Ready"
End Sub

Sub OnFileMenuPressed(id)
    Select Case id
        Case 0
            lblStatus.Text = "File > New"
        Case 1
            lblStatus.Text = "File > Open"
        Case 2
            lblStatus.Text = "File > Save"
        Case 3
            lblStatus.Text = "File > Exit (not really quitting in this demo)"
    End Select
End Sub

Sub OnEditMenuPressed(id)
    Select Case id
        Case 0
            lblStatus.Text = "Edit > Cut"
        Case 1
            lblStatus.Text = "Edit > Copy"
        Case 2
            lblStatus.Text = "Edit > Paste"
    End Select
End Sub

Sub OnHelpMenuPressed(id)
    lblStatus.Text = "Help > About — VisualGasic UI Toolkit Demo"
End Sub

Private Sub pnlContextArea_GuiInput(ev)
    If TypeOf ev Is InputEventMouseButton Then
        If ev.pressed And ev.button_index = MOUSE_BUTTON_RIGHT Then
            ctxMenu.position = Me.position + Vector2i(ev.global_position)
            ctxMenu.popup()
            lblStatus.Text = "Context menu opened."
        End If
    End If
End Sub

Sub OnContextMenuPressed(id)
    Select Case id
        Case 0
            lblStatus.Text = "Context menu: Cut"
        Case 1
            lblStatus.Text = "Context menu: Copy"
        Case 2
            lblStatus.Text = "Context menu: Paste"
        Case 3
            lblStatus.Text = "Context menu: Delete"
    End Select
End Sub

Sub _Input(ev)
    If TypeOf ev Is InputEventKey Then
        If ev.pressed And ev.ctrl_pressed Then
            If ev.keycode = 79 Then \' O
                lblStatus.Text = "Shortcut: Ctrl+O (Open)"
            ElseIf ev.keycode = 83 Then \' S
                lblStatus.Text = "Shortcut: Ctrl+S (Save)"
            ElseIf ev.keycode = 81 Then \' Q
                lblStatus.Text = "Shortcut: Ctrl+Q (Quit — not really quitting in this demo)"
            End If
        ElseIf ev.pressed And ev.keycode = 4194332 Then \' F1
            lblStatus.Text = "Shortcut: F1 (Help)"
        End If
    End If
End Sub
'''

# =========================================================================
# Form 9: GameUI_1 (HUD, Bars, Progress)
# =========================================================================
GAME1_BODY = [
    section_label("secHUD", "── HUDCounter / StatBars — click to change ──"),
    label("lblScore", "Score: 0", font_size=18),
    button("btnAddScore", "+100 Score"),
    hbox_pair("barHP", "HP:", progress_bar("barHP", 85)),
    hbox_pair("barMP", "MP:", progress_bar("barMP", 55)),
    hbox_pair("barStamina", "Stamina:", progress_bar("barStamina", 30)),
    ['[node name="hboxHudButtons" type="HBoxContainer" parent="ScrollContainer/VBox"]'],
    button("btnDamage", "Take Damage (-15 HP)", parent="ScrollContainer/VBox/hboxHudButtons"),
    button("btnHeal", "Heal (+15 HP)", parent="ScrollContainer/VBox/hboxHudButtons"),
    button("btnUseMana", "Cast Spell (-20 MP)", parent="ScrollContainer/VBox/hboxHudButtons"),
    section_label("secXPBar", "── XPBar — gain XP and level up ──"),
    label("lblLevel", "Level: 1", font_size=13),
    hbox_pair("barXP", "XP:", progress_bar("barXP", 0)),
    button("btnGainXP", "+25 XP"),
    section_label("secAmmoCounter", "── AmmoCounter ──"),
    label("lblAmmo", "Ammo: 30 / 120", font_size=18),
    button("btnFire", "Fire!"),
    section_label("secCooldownButton", "── CooldownButton — ability with real cooldown Timer ──"),
    button("btnAbility1", "Fireball (5s cooldown)"),
    timer_node("tmrCooldown", wait_time=5.0, one_shot=True, autostart=False),
    feedback_label(),
]

GAME1_VG = '''\' GameUI_1 — Game UI: HUD & Bars — VisualGasic UI Toolkit Demo
Option Explicit

Dim score As Integer
Dim hp As Integer
Dim mp As Integer
Dim level As Integer
Dim xp As Integer
Dim ammo As Integer
Const MAX_AMMO As Integer = 30

Private Sub Form_Load()
    score = 0
    hp = 85
    mp = 55
    level = 1
    xp = 0
    ammo = MAX_AMMO
    RefreshHud
    lblFeedback.Text = "Deal damage, heal, cast spells, or fire your weapon."
End Sub

Sub RefreshHud()
    lblScore.text = "Score: " & score
    barHP.value = hp
    barMP.value = mp
    lblLevel.text = "Level: " & level
    barXP.value = xp
    lblAmmo.text = "Ammo: " & ammo & " / " & (MAX_AMMO * 4)
End Sub

Private Sub btnAddScore_Click()
    score = score + 100
    RefreshHud
    lblFeedback.Text = "+100 score!"
End Sub

Private Sub btnDamage_Click()
    hp = hp - 15
    If hp < 0 Then hp = 0
    RefreshHud
    lblFeedback.Text = "Ouch! Took 15 damage."
End Sub

Private Sub btnHeal_Click()
    hp = hp + 15
    If hp > 100 Then hp = 100
    RefreshHud
    lblFeedback.Text = "Healed 15 HP."
End Sub

Private Sub btnUseMana_Click()
    If mp >= 20 Then
        mp = mp - 20
        RefreshHud
        lblFeedback.Text = "Spell cast! -20 MP."
    Else
        lblFeedback.Text = "Not enough MP!"
    End If
End Sub

Private Sub btnGainXP_Click()
    xp = xp + 25
    If xp >= 100 Then
        xp = xp - 100
        level = level + 1
        lblFeedback.Text = "Level up! Now level " & level & "."
    Else
        lblFeedback.Text = "+25 XP."
    End If
    RefreshHud
End Sub

Private Sub btnFire_Click()
    If ammo > 0 Then
        ammo = ammo - 1
        RefreshHud
        lblFeedback.Text = "Bang! " & ammo & " shots left in this clip."
    Else
        lblFeedback.Text = "Click! Out of ammo — reload needed."
        ammo = MAX_AMMO
        RefreshHud
    End If
End Sub

Private Sub btnAbility1_Click()
    If tmrCooldown.is_stopped() Then
        btnAbility1.disabled = True
        btnAbility1.text = "Fireball (cooling down...)"
        tmrCooldown.start()
        lblFeedback.Text = "Fireball cast! 5 second cooldown started."
    End If
End Sub

Private Sub tmrCooldown_Timer()
    btnAbility1.disabled = False
    btnAbility1.text = "Fireball (5s cooldown)"
    lblFeedback.Text = "Fireball ready again!"
End Sub
'''

# =========================================================================
# Form 10: GameUI_2 (Inventory, SkillTree, Quest, Map)
# =========================================================================
GAME2_BODY = [
    section_label("secInventoryGrid", "── InventoryGrid — click a slot ──"),
    item_list("invGrid", height=100),
    label("lblItemSlot", "Selected item: (none)", font_size=11),
    section_label("secSkillTree", "── SkillTree — click to unlock ──"),
    tree("skillTree", height=140),
    label("lblSkillPoints", "Skill points remaining: 3", font_size=11),
    section_label("secQuestTracker", "── QuestTracker — double-click to complete ──"),
    item_list("questList", height=100),
    section_label("secCompass", "── Compass — drag the slider to turn ──"),
    hbox_pair("sldCompass", "Heading:", h_slider("sldCompass", 0)),
    label("lblCompassDir", "N", font_size=16),
    feedback_label(),
]

GAME2_VG = '''\' GameUI_2 — Game UI: Inventory & Map — VisualGasic UI Toolkit Demo
Option Explicit

Dim skillPoints As Integer

Private Sub Form_Load()
    invGrid.add_item("Sword")
    invGrid.add_item("Shield")
    invGrid.add_item("Health Potion x3")
    invGrid.add_item("Iron Key")

    skillPoints = 3

    Dim root
    Set root = skillTree.create_item()
    root.set_text(0, "Skills (click a skill, then Quest below)")
    Dim s1
    Set s1 = skillTree.create_item(root)
    s1.set_text(0, "Fireball [locked]")
    Dim s2
    Set s2 = skillTree.create_item(root)
    s2.set_text(0, "Heal [locked]")
    Dim s3
    Set s3 = skillTree.create_item(root)
    s3.set_text(0, "Dash [locked]")

    questList.add_item("Defeat the goblin camp")
    questList.add_item("Collect 5 herbs")
    questList.add_item("Deliver the letter")

    lblFeedback.Text = "Click inventory slots, unlock skills, or complete quests."
End Sub

Private Sub invGrid_Click(index)
    lblItemSlot.text = "Selected item: " & invGrid.get_item_text(index)
    lblFeedback.Text = "Inventory slot " & index & " selected."
End Sub

Private Sub skillTree_Click()
    Dim item
    Set item = skillTree.get_selected()
    If item Is Nothing Then Exit Sub
    If item.get_text(0) = "Skills (click a skill, then Quest below)" Then Exit Sub
    Dim skillName As String
    skillName = item.get_text(0)
    If InStr(skillName, "[locked]") > 0 And skillPoints > 0 Then
        skillPoints = skillPoints - 1
        item.set_text(0, Replace(skillName, " [locked]", " [UNLOCKED]"))
        lblSkillPoints.text = "Skill points remaining: " & skillPoints
        lblFeedback.Text = "Unlocked a skill! " & skillPoints & " point(s) left."
    ElseIf InStr(skillName, "[locked]") > 0 Then
        lblFeedback.Text = "No skill points left!"
    Else
        lblFeedback.Text = skillName & " is already unlocked."
    End If
End Sub

Private Sub questList_DblClick(index)
    Dim questText As String
    questText = questList.get_item_text(index)
    If InStr(questText, "[DONE]") = 0 Then
        questList.set_item_text(index, questText & " [DONE]")
        lblFeedback.Text = "Quest completed: " & questText
    End If
End Sub

Private Sub sldCompass_Change(newValue)
    Dim dirs
    dirs = Array("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    Dim idx As Integer
    idx = Int(((newValue Mod 360) + 360) Mod 360 / 45)
    lblCompassDir.text = dirs(idx)
    lblFeedback.Text = "Heading: " & CInt(newValue) & "°"
End Sub
'''

# =========================================================================
# Form 11: GameUI_3 (Dialogs, Menus, Notifications, Chat)
# =========================================================================
GAME3_BODY = [
    section_label("secDialogPanel", "── DialogPanel — click to advance ──"),
    rich_text_label("dlgNpc", "[b]Guard:[/b] Halt! Who goes there?", height=50),
    button("btnNextLine", "Next Line ▶"),
    section_label("secConfirmDialog", "── ConfirmDialog — real Godot ConfirmationDialog ──"),
    button("btnConfirm", "Delete Save File..."),
    section_label("secSettingsPanel", "── SettingsPanel ──"),
    checkbox("chkMusic", "Music On", checked=True),
    checkbox("chkSfx", "Sound Effects On", checked=True),
    section_label("secNotificationToast", "── NotificationToast — auto-hides after 2s ──"),
    button("btnNotify", "Show Toast"),
    feedback_label("lblToast", ""),
    timer_node("tmrToast", wait_time=2.0, one_shot=True, autostart=False),
    section_label("secChatBox", "── ChatBox — type and send ──"),
    rich_text_label("chatBox", "[Player1]: hello!\n[Player2]: hey! ready for the raid?", height=70),
    hbox_pair("txtChatInput", "Say:", line_edit("txtChatInput", "Type a message...")),
    button("btnSendChat", "Send"),
    section_label("secDamageNumber", "── DamageNumber — floating damage text ──"),
    button("btnDealDamage", "Attack!"),
    label("lblDamage", "", font_size=24),
    feedback_label(),
]

GAME3_VG = '''\' GameUI_3 — Game UI: Dialogs & Chat — VisualGasic UI Toolkit Demo
Option Explicit

Dim dialogLines As Variant
Dim dialogIndex As Integer
Dim confirmDlg As Object

Private Sub Form_Load()
    dialogLines = Array( _
        "[b]Guard:[/b] Halt! Who goes there?", _
        "[b]You:[/b] Just a traveler passing through.", _
        "[b]Guard:[/b] Very well. Move along.")
    dialogIndex = 0

    Set confirmDlg = New ConfirmationDialog
    confirmDlg.dialog_text = "Are you sure you want to delete your save file? This cannot be undone."
    Me.AddChild(confirmDlg)
    Connect confirmDlg, "confirmed", "OnDeleteConfirmed"

    lblFeedback.Text = "Advance the dialog, try the confirm dialog, or send a chat message."
End Sub

Private Sub btnNextLine_Click()
    dialogIndex = (dialogIndex + 1) Mod (UBound(dialogLines) + 1)
    dlgNpc.text = dialogLines(dialogIndex)
End Sub

Private Sub btnConfirm_Click()
    confirmDlg.popup_centered()
End Sub

Sub OnDeleteConfirmed()
    lblFeedback.Text = "Save file deleted (simulated)."
End Sub

Private Sub chkMusic_Click(pressed)
    lblFeedback.Text = "Music: " & IIf(pressed, "On", "Off")
End Sub

Private Sub chkSfx_Click(pressed)
    lblFeedback.Text = "Sound Effects: " & IIf(pressed, "On", "Off")
End Sub

Private Sub btnNotify_Click()
    lblToast.text = "✔ Achievement Unlocked: Toolkit Explorer!"
    tmrToast.start()
End Sub

Private Sub tmrToast_Timer()
    lblToast.text = ""
End Sub

Private Sub btnSendChat_Click()
    If Len(Trim(txtChatInput.text)) > 0 Then
        chatBox.text = chatBox.text & Chr(10) & "[You]: " & Trim(txtChatInput.text)
        txtChatInput.text = ""
    End If
End Sub

Private Sub btnDealDamage_Click()
    Dim dmg As Integer
    dmg = Int(Rnd * 40) + 10
    lblDamage.text = "-" & dmg & " HP"
    lblDamage.modulate = Color(1, 1, 1, 1)
    TweenProperty lblDamage, "modulate:a", 0.0, 1.0
    lblFeedback.Text = "Attack hit for " & dmg & " damage!"
End Sub
'''

# =========================================================================
# Assemble all forms
# =========================================================================
FORMS = [
    ("BasicControls", "Basic Controls", (640, 560), BASIC_BODY, BASIC_VG, GENDER_GROUP),
    ("ListControls", "List Controls", (640, 620), LIST_BODY, LIST_VG, ""),
    ("ContainerControls", "Container Controls", (640, 480), CONTAINER_BODY, CONTAINER_VG, ""),
    ("DisplayControls", "Display Controls", (640, 560), DISPLAY_BODY, DISPLAY_VG, ""),
    ("AdvancedControls", "Advanced Controls", (640, 560), ADVANCED_BODY, ADVANCED_VG, ""),
    ("TimerAndAnimation", "Timer & Animation", (640, 640), TIMER_BODY, TIMER_VG, ""),
    ("CustomWidgets", "Custom Widgets", (640, 560), CUSTOM_BODY, CUSTOM_VG, ""),
    ("MenusAndStatus", "Menus & Status", (640, 440), MENUS_BODY, MENUS_VG, ""),
    ("GameUI_1", "Game UI — HUD & Bars", (640, 620), GAME1_BODY, GAME1_VG, ""),
    ("GameUI_2", "Game UI — Inventory & Map", (640, 560), GAME2_BODY, GAME2_VG, ""),
    ("GameUI_3", "Game UI — Dialogs & Chat", (640, 640), GAME3_BODY, GAME3_VG, ""),
]


def main():
    os.makedirs(OUT, exist_ok=True)

    with open(os.path.join(OUT, "project.godot"), "w") as f:
        f.write(PROJECT_CFG.strip() + "\n")

    for form_name, title, size, body, vg_code, extra_sub in FORMS:
        tscn_path = os.path.join(OUT, f"{form_name}.tscn")
        vg_path = os.path.join(OUT, f"{form_name}.vg")

        tscn_content = build_full_tscn(form_name, title, size, body, None, extra_sub)
        with open(tscn_path, "w") as f:
            f.write(tscn_content)

        with open(vg_path, "w") as f:
            f.write(vg_code)

        print(f"  \u2713 {form_name}.tscn + .vg  ({title})")

    readme = """# VisualGasic UI Toolkit Examples

A collection of **interactive** demo forms for every control in the VisualGasic IDE.
Every control is wired to real VisualGasic event-handler code — click buttons, drag
sliders, type in text boxes, and watch the rest of the form react.

## How to Use

1. Copy the `VG_UI_TOOLS/` folder into a Godot 4.3+ project that has the VisualGasic addon installed.
2. Open Godot → Import → select `project.godot` inside `VG_UI_TOOLS/`.
3. Open any `.tscn` file in the VisualGasic Form Designer.
4. Click **▶ Run** to test the form standalone.

## Forms

| File | What it demonstrates |
|------|-----------------------|
| `BasicControls.tscn` | Buttons, live text-input feedback, password strength, word count, radio-button group, ComboBox, sliders that drive a ProgressBar |
| `ListControls.tscn` | Add/remove ItemList items, a populated Tree, ComboBox selection, and a real OS-aware DriveListBox |
| `ContainerControls.tscn` | A real multi-page TabContainer, a clickable Panel, and toolbar buttons |
| `DisplayControls.tscn` | Clickable ColorRect swatches, buttons that recolor a PictureBox, and a RichTextLabel that updates as you type |
| `AdvancedControls.tscn` | SpinBoxes driving a live total, a CheckBox list that enables a Save button, and real native FileDialogs |
| `TimerAndAnimation.tscn` | A real `Timer` node running a live clock, `TweenProperty`-driven fade/slide/spin animations, and a clickable calendar day picker |
| `CustomWidgets.tscn` | Dark-mode toggle, clickable breadcrumbs, a Timer-driven spinner, an expandable section, and a live-validated phone number mask |
| `MenusAndStatus.tscn` | A real `MenuButton` + `PopupMenu` menu bar, a right-click context menu, and working keyboard shortcuts (Ctrl+O/S/Q, F1) |
| `GameUI_1.tscn` | HP/MP/Stamina bars you can damage/heal, an XP bar that levels you up, an ammo counter, and a real cooldown Timer on an ability button |
| `GameUI_2.tscn` | A clickable inventory list, a SkillTree you unlock with points, a double-click-to-complete quest tracker, and a slider-driven compass |
| `GameUI_3.tscn` | Advancing NPC dialogue, a real `ConfirmationDialog`, a toast notification, a working chat box, and floating damage numbers |

## Theme

All forms use `VB6Theme.tres` — the VisualGasic Classic VB6 theme with white backgrounds, raised 3D borders, and black text.

## Notes

- Every form has a yellow feedback label at the bottom that reports what you just did — this is the fastest way to see that a control is wired up correctly.
- Event handlers follow the standard VisualGasic auto-wire convention: `ControlName_Click`, `ControlName_Change`, `ControlName_Timer`, etc. (see `demo/test_suites/test_events.vg` for the full reference).
- This project is generated by `generate_vg_ui_tools.py` at the repo root — re-run it after editing that script to regenerate every form.
"""
    with open(os.path.join(OUT, "README.md"), "w") as f:
        f.write(readme)

    print(f"\n\u2705 Generated {len(FORMS)} forms in {OUT}/")


if __name__ == "__main__":
    main()
