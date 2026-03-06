#!/usr/bin/env python3
"""
inject_vb6_theme.py — Patch existing .tscn forms to include VB6 Classic Theme.

Works without Godot running.  Reads a .tscn, checks for the 'vb6_theme' marker,
and if missing injects all StyleBoxFlat sub_resources + Theme sub_resource.

Usage:
    python3 inject_vb6_theme.py Form1.tscn Form2.tscn ...
    python3 inject_vb6_theme.py --all path/to/project/    # patches every .tscn

The script is idempotent: re-running it on an already-patched file is a no-op.
"""

import sys, os, re, glob

# ── VB6 System Colors (matches visual_gasic_form_designer.h) ──
SYS = {
    "button_face":      (0.8310, 0.8160, 0.7840, 1.0),
    "button_highlight": (1.0,    1.0,    1.0,    1.0),
    "button_shadow":    (0.5100, 0.5100, 0.5100, 1.0),
    "3d_dark_shadow":   (0.2500, 0.2500, 0.2500, 1.0),
    "3d_light":         (0.9300, 0.9300, 0.8900, 1.0),
    "window":           (1.0,    1.0,    1.0,    1.0),
    "window_text":      (0.0,    0.0,    0.0,    1.0),
    "title_text":       (1.0,    1.0,    1.0,    1.0),
    "scrollbar":        (0.8700, 0.8700, 0.8700, 1.0),
    "progress_fill":    (0.0,    0.5,    0.0,    1.0),
    "form_bg":          (0.7530, 0.7530, 0.7530, 1.0),
    "text":             (0.0,    0.0,    0.0,    1.0),
    "placeholder":      (0.6,    0.6,    0.6,    1.0),
    "transparent":      (0.0,    0.0,    0.0,    0.0),
}

PROTO_PREFIX = "res://addons/visual_gasic/prototypes/"

def fc(c):
    """Format a color tuple for .tscn."""
    return f"Color({c[0]:.4f}, {c[1]:.4f}, {c[2]:.4f}, {c[3]:.4f})"

def stylebox(sid, bg, bw_t, bw_r, bw_b, bw_l, border_color, corner=0, margin=-1):
    """Build a [sub_resource type=StyleBoxFlat] block."""
    s = f'[sub_resource type="StyleBoxFlat" id="{sid}"]\n'
    s += f"bg_color = {fc(bg)}\n"
    if bw_t > 0: s += f"border_width_top = {bw_t}\n"
    if bw_r > 0: s += f"border_width_right = {bw_r}\n"
    if bw_b > 0: s += f"border_width_bottom = {bw_b}\n"
    if bw_l > 0: s += f"border_width_left = {bw_l}\n"
    s += f"border_color = {fc(border_color)}\n"
    if corner > 0:
        for d in ("top_left","top_right","bottom_right","bottom_left"):
            s += f"corner_radius_{d} = {corner}\n"
    if margin >= 0:
        for d in ("left","top","right","bottom"):
            s += f"content_margin_{d} = {margin}.0\n"
    s += "\n"
    return s

def build_sub_resources(has_custom):
    """Build all VB6 StyleBoxFlat + Theme sub_resource blocks."""
    S = SYS
    t = S["transparent"]
    bf = S["button_face"]
    bh = S["button_highlight"]
    bs = S["button_shadow"]
    ds = S["3d_dark_shadow"]
    w  = S["window"]
    sc = S["scrollbar"]

    btn_hover = (min(bf[0]+0.04, 1.0), min(bf[1]+0.04, 1.0), min(bf[2]+0.04, 1.0), 1.0)
    btn_disabled = (0.85, 0.85, 0.85, 1.0)
    check_hover_bg = (bf[0], bf[1], bf[2], 0.3)
    ro_bg = (0.93, 0.93, 0.93, 1.0)

    out = ""
    # Button
    out += stylebox("vb6_btn_normal",   bf,  2,2,2,2, bs, margin=4)
    out += stylebox("vb6_btn_hover",    btn_hover, 2,2,2,2, bs, margin=4)
    out += stylebox("vb6_btn_pressed",  bf,  2,2,2,2, ds, margin=4)
    out += stylebox("vb6_btn_focus",    bf,  2,2,2,2, bs, margin=4)
    out += stylebox("vb6_btn_disabled", btn_disabled, 2,2,2,2, bs, margin=4)
    # LineEdit
    out += stylebox("vb6_edit_normal",   w, 2,2,2,2, bs, margin=3)
    out += stylebox("vb6_edit_focus",    w, 2,2,2,2, ds, margin=3)
    out += stylebox("vb6_edit_read_only", ro_bg, 2,2,2,2, bs, margin=3)
    # TextEdit
    out += stylebox("vb6_textedit_normal",    w, 2,2,2,2, bs, margin=3)
    out += stylebox("vb6_textedit_focus",     w, 2,2,2,2, ds, margin=3)
    out += stylebox("vb6_textedit_read_only", ro_bg, 2,2,2,2, bs, margin=3)
    # CheckBox
    out += stylebox("vb6_check_normal",  t, 0,0,0,0, t)
    out += stylebox("vb6_check_hover",   check_hover_bg, 0,0,0,0, t)
    out += stylebox("vb6_check_pressed", t, 0,0,0,0, t)
    # OptionButton (ComboBox)
    out += stylebox("vb6_combo_normal",  w, 2,2,2,2, bs, margin=3)
    out += stylebox("vb6_combo_hover",   w, 2,2,2,2, ds, margin=3)
    out += stylebox("vb6_combo_pressed", w, 2,2,2,2, ds, margin=3)
    # Panel
    out += stylebox("vb6_panel", S["form_bg"], 1,1,1,1, bs, margin=4)
    # ItemList
    out += stylebox("vb6_itemlist_normal", w, 2,2,2,2, bs, margin=2)
    out += stylebox("vb6_itemlist_focus",  w, 2,2,2,2, ds, margin=2)
    # ProgressBar
    out += stylebox("vb6_progress_bg",   w, 2,2,2,2, bs)
    out += stylebox("vb6_progress_fill", S["progress_fill"], 0,0,0,0, t)
    # TabContainer
    out += stylebox("vb6_tab_panel",      bf, 1,1,1,1, bs, margin=4)
    out += stylebox("vb6_tab_selected",   bf, 1,1,0,1, bh, margin=4)
    out += stylebox("vb6_tab_unselected", (0.72,0.72,0.72,1.0), 1,1,1,1, bs, margin=4)
    out += stylebox("vb6_tab_hovered",    (0.80,0.80,0.78,1.0), 1,1,0,1, bh, margin=4)
    # ScrollBar
    out += stylebox("vb6_scrollbar_scroll", sc, 0,0,0,0, t)
    out += stylebox("vb6_scrollbar_grabber", bf, 1,1,1,1, bh)
    out += stylebox("vb6_scrollbar_grabber_hl", btn_hover, 1,1,1,1, bh)
    out += stylebox("vb6_scrollbar_grabber_pressed", bf, 1,1,1,1, ds)
    # Label
    out += stylebox("vb6_label_normal", t, 0,0,0,0, t)
    # RadioButton
    out += stylebox("vb6_radio_normal",  t, 0,0,0,0, t)
    out += stylebox("vb6_radio_hover",   check_hover_bg, 0,0,0,0, t)
    out += stylebox("vb6_radio_pressed", t, 0,0,0,0, t)
    # Tree
    out += stylebox("vb6_tree_panel", w, 2,2,2,2, bs, margin=2)
    out += stylebox("vb6_tree_focus", w, 2,2,2,2, ds, margin=2)

    # ── Theme sub_resource ──
    txt = S["text"]
    wt  = S["window_text"]
    tt  = S["title_text"]
    pl  = S["placeholder"]
    sel = (0.0, 0.0, 0.5, 0.4)
    dis = (0.5, 0.5, 0.5, 1.0)
    guide = (0.9, 0.9, 0.9, 1.0)

    theme = '[sub_resource type="Theme" id="vb6_theme"]\n'
    # Button
    theme += f"Button/colors/font_color = {fc(txt)}\n"
    theme += f"Button/colors/font_hover_color = {fc(txt)}\n"
    theme += f"Button/colors/font_pressed_color = {fc(txt)}\n"
    theme += f"Button/colors/font_disabled_color = {fc(dis)}\n"
    theme += 'Button/styles/normal = SubResource("vb6_btn_normal")\n'
    theme += 'Button/styles/hover = SubResource("vb6_btn_hover")\n'
    theme += 'Button/styles/pressed = SubResource("vb6_btn_pressed")\n'
    theme += 'Button/styles/focus = SubResource("vb6_btn_focus")\n'
    theme += 'Button/styles/disabled = SubResource("vb6_btn_disabled")\n'
    # LineEdit
    theme += f"LineEdit/colors/font_color = {fc(wt)}\n"
    theme += f"LineEdit/colors/font_placeholder_color = {fc(pl)}\n"
    theme += f"LineEdit/colors/caret_color = {fc(wt)}\n"
    theme += f"LineEdit/colors/selection_color = {fc(sel)}\n"
    theme += 'LineEdit/styles/normal = SubResource("vb6_edit_normal")\n'
    theme += 'LineEdit/styles/focus = SubResource("vb6_edit_focus")\n'
    theme += 'LineEdit/styles/read_only = SubResource("vb6_edit_read_only")\n'
    # TextEdit
    theme += f"TextEdit/colors/font_color = {fc(wt)}\n"
    theme += f"TextEdit/colors/font_placeholder_color = {fc(pl)}\n"
    theme += f"TextEdit/colors/caret_color = {fc(wt)}\n"
    theme += 'TextEdit/styles/normal = SubResource("vb6_textedit_normal")\n'
    theme += 'TextEdit/styles/focus = SubResource("vb6_textedit_focus")\n'
    theme += 'TextEdit/styles/read_only = SubResource("vb6_textedit_read_only")\n'
    # CheckBox
    theme += f"CheckBox/colors/font_color = {fc(txt)}\n"
    theme += f"CheckBox/colors/font_hover_color = {fc(txt)}\n"
    theme += f"CheckBox/colors/font_pressed_color = {fc(txt)}\n"
    theme += 'CheckBox/styles/normal = SubResource("vb6_check_normal")\n'
    theme += 'CheckBox/styles/hover = SubResource("vb6_check_hover")\n'
    theme += 'CheckBox/styles/pressed = SubResource("vb6_check_pressed")\n'
    theme += 'CheckBox/styles/focus = SubResource("vb6_check_normal")\n'
    # RadioButton
    theme += f"RadioButton/colors/font_color = {fc(txt)}\n"
    theme += 'RadioButton/styles/normal = SubResource("vb6_radio_normal")\n'
    theme += 'RadioButton/styles/hover = SubResource("vb6_radio_hover")\n'
    theme += 'RadioButton/styles/pressed = SubResource("vb6_radio_pressed")\n'
    theme += 'RadioButton/styles/focus = SubResource("vb6_radio_normal")\n'
    # OptionButton
    theme += f"OptionButton/colors/font_color = {fc(wt)}\n"
    theme += 'OptionButton/styles/normal = SubResource("vb6_combo_normal")\n'
    theme += 'OptionButton/styles/hover = SubResource("vb6_combo_hover")\n'
    theme += 'OptionButton/styles/pressed = SubResource("vb6_combo_pressed")\n'
    theme += 'OptionButton/styles/focus = SubResource("vb6_combo_normal")\n'
    # Panel
    theme += 'Panel/styles/panel = SubResource("vb6_panel")\n'
    # Label
    theme += f"Label/colors/font_color = {fc(txt)}\n"
    theme += 'Label/styles/normal = SubResource("vb6_label_normal")\n'
    # ItemList
    theme += f"ItemList/colors/font_color = {fc(wt)}\n"
    theme += f"ItemList/colors/font_selected_color = {fc(tt)}\n"
    theme += f"ItemList/colors/guide_color = {fc(guide)}\n"
    theme += 'ItemList/styles/panel = SubResource("vb6_itemlist_normal")\n'
    theme += 'ItemList/styles/focus = SubResource("vb6_itemlist_focus")\n'
    # ProgressBar
    theme += f"ProgressBar/colors/font_color = {fc(txt)}\n"
    theme += 'ProgressBar/styles/background = SubResource("vb6_progress_bg")\n'
    theme += 'ProgressBar/styles/fill = SubResource("vb6_progress_fill")\n'
    # TabContainer
    theme += 'TabContainer/styles/panel = SubResource("vb6_tab_panel")\n'
    theme += 'TabContainer/styles/tab_selected = SubResource("vb6_tab_selected")\n'
    theme += 'TabContainer/styles/tab_unselected = SubResource("vb6_tab_unselected")\n'
    theme += 'TabContainer/styles/tab_hovered = SubResource("vb6_tab_hovered")\n'
    # ScrollBars
    for sb in ("HScrollBar", "VScrollBar"):
        theme += f'{sb}/styles/scroll = SubResource("vb6_scrollbar_scroll")\n'
        theme += f'{sb}/styles/grabber = SubResource("vb6_scrollbar_grabber")\n'
        theme += f'{sb}/styles/grabber_highlight = SubResource("vb6_scrollbar_grabber_hl")\n'
        theme += f'{sb}/styles/grabber_pressed = SubResource("vb6_scrollbar_grabber_pressed")\n'
    # Sliders
    for sl in ("HSlider", "VSlider"):
        theme += f'{sl}/styles/slider = SubResource("vb6_scrollbar_scroll")\n'
        theme += f'{sl}/styles/grabber_area = SubResource("vb6_scrollbar_scroll")\n'
    # Tree
    theme += f"Tree/colors/font_color = {fc(wt)}\n"
    theme += 'Tree/styles/panel = SubResource("vb6_tree_panel")\n'
    theme += 'Tree/styles/focus = SubResource("vb6_tree_focus")\n'
    # RichTextLabel
    theme += f"RichTextLabel/colors/default_color = {fc(wt)}\n"
    theme += 'RichTextLabel/styles/normal = SubResource("vb6_edit_normal")\n'
    theme += 'RichTextLabel/styles/focus = SubResource("vb6_edit_focus")\n'
    # MenuBar
    theme += 'MenuBar/styles/normal = SubResource("vb6_btn_normal")\n'
    theme += f"MenuBar/colors/font_color = {fc(txt)}\n"
    theme += "\n"

    out += theme

    # Empty theme for custom controls
    if has_custom:
        out += '[sub_resource type="Theme" id="vb6_empty_theme"]\n\n'

    return out

def count_sub_resources(text):
    """Count [sub_resource ...] blocks in text."""
    return len(re.findall(r'\[sub_resource ', text))

def patch_tscn(filepath):
    """Inject VB6 theme into a .tscn file. Returns True if patched."""
    with open(filepath, "r") as f:
        text = f.read()

    if "vb6_theme" in text:
        print(f"  SKIP (already themed): {filepath}")
        return False

    # Must be a VisualGasic form (has Window root + form_editor_helper)
    if 'type="Window"' not in text or "form_editor_helper" not in text:
        print(f"  SKIP (not a VG form): {filepath}")
        return False

    # Detect custom controls (scene paths NOT under prototypes/)
    has_custom = False
    for m in re.finditer(r'path="(res://[^"]+\.tscn)"', text):
        path = m.group(1)
        if not path.startswith(PROTO_PREFIX) and "form_editor_helper" not in path and "menu_bar_helper" not in path:
            has_custom = True
            break

    sub_res_text = build_sub_resources(has_custom)
    new_sub_count = count_sub_resources(sub_res_text)

    lines = text.split("\n")
    out_lines = []
    header_patched = False
    root_node_patched = False
    insert_point_found = False

    i = 0
    while i < len(lines):
        line = lines[i]

        # 1) Fix load_steps in header
        if not header_patched and line.startswith("[gd_scene "):
            m = re.search(r'load_steps=(\d+)', line)
            if m:
                old_steps = int(m.group(1))
                new_steps = old_steps + new_sub_count
                line = line.replace(f"load_steps={old_steps}", f"load_steps={new_steps}")
            header_patched = True
            out_lines.append(line)
            i += 1
            continue

        # 2) Insert sub_resources before the first [node ...] line
        if not insert_point_found and line.strip().startswith("[node "):
            # Insert all sub_resource blocks here
            out_lines.append(sub_res_text)
            insert_point_found = True
            # Fall through to process this [node line

        # 3) Add theme = SubResource("vb6_theme") to root Window node
        if not root_node_patched and line.strip().startswith("[node ") and 'type="Window"' in line:
            out_lines.append(line)
            i += 1
            # Read the rest of the node properties until next blank or [node
            while i < len(lines):
                prop_line = lines[i]
                if prop_line.strip().startswith("script = "):
                    # Insert theme BEFORE script
                    out_lines.append('theme = SubResource("vb6_theme")')
                    out_lines.append(prop_line)
                    root_node_patched = True
                    i += 1
                    break
                elif prop_line.strip() == "" or prop_line.strip().startswith("["):
                    # No script line found, insert theme before the blank/next section
                    out_lines.append('theme = SubResource("vb6_theme")')
                    out_lines.append(prop_line)
                    root_node_patched = True
                    i += 1
                    break
                else:
                    out_lines.append(prop_line)
                    i += 1
            continue

        # 4) For custom controls, add theme = SubResource("vb6_empty_theme")
        if has_custom and line.strip().startswith("[node ") and "instance=ExtResource" in line:
            # Check if this instance is a custom control
            ext_match = re.search(r'instance=ExtResource\("(\d+)"\)', line)
            if ext_match:
                ext_id = ext_match.group(1)
                # Look up the ext_resource path for this ID
                for er_line in lines:
                    if f'id="{ext_id}"' in er_line and "ext_resource" in er_line:
                        path_m = re.search(r'path="([^"]+)"', er_line)
                        if path_m:
                            epath = path_m.group(1)
                            if not epath.startswith(PROTO_PREFIX) and epath.endswith(".tscn"):
                                # This is a custom control — inject empty theme
                                out_lines.append(line)
                                i += 1
                                # Read properties until we hit a blank or next section
                                injected = False
                                while i < len(lines):
                                    prop_line = lines[i]
                                    if prop_line.strip() == "" or prop_line.strip().startswith("["):
                                        if not injected:
                                            out_lines.append('theme = SubResource("vb6_empty_theme")')
                                            injected = True
                                        out_lines.append(prop_line)
                                        i += 1
                                        break
                                    else:
                                        out_lines.append(prop_line)
                                        i += 1
                                continue
                        break

        out_lines.append(line)
        i += 1

    result = "\n".join(out_lines)
    with open(filepath, "w") as f:
        f.write(result)
    print(f"  PATCHED: {filepath} (+{new_sub_count} sub_resources, custom={has_custom})")
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: inject_vb6_theme.py [--all <project_dir>] [file.tscn ...]")
        sys.exit(1)

    files = []
    if sys.argv[1] == "--all":
        project_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        files = glob.glob(os.path.join(project_dir, "**", "*.tscn"), recursive=True)
    else:
        files = sys.argv[1:]

    patched = 0
    for f in files:
        if os.path.isfile(f):
            if patch_tscn(f):
                patched += 1

    print(f"\nDone: {patched}/{len(files)} files patched.")

if __name__ == "__main__":
    main()
