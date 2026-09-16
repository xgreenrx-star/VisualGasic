# VG TwinPane

Dual-pane file manager built in Visual Gasic. Inspired by classic Amiga directory tools (Directory Opus 4 / Magellan II as **legal reference only**). This is an **original app and name** — not affiliated with GPSoftware's Windows Directory Opus product.

## Features (v1)

- Two independent directory listers (folders first, then files)
- Toolbar: Up, Refresh, Copy →, Move →, Delete, Trash
- Double-click folders to enter; click a pane to focus it
- VB6 Classic theme (`themes/VB6Theme.tres`) and standard VG event wiring (`btnUp_Click`, `lstLeft_DblClick`, …)
- Uses engine builtins: `ListFiles`, `ListFolders`, `CopyFolder`, `MoveFolder`, `DeleteFolder`, `SendToTrash`, `BuildPath`

## Form Designer workflow

This project is laid out like a programmer would build it in the VG IDE:

1. Open **`scenes/Main.tscn`** in Godot — root is a **`Window`** form with `_FormBackground` and VB6 prototype controls (`Button`, `Label`, `LineEdit`, `ItemList`).
2. Use **Form Designer** (Visual Gasic toolbox) to move, resize, or add controls. Event handlers in `scripts/Main.vg` wire by control name (`btnUp`, `lstLeft`, …).
3. Edit behavior in **`scripts/Main.vg`**; helper modules live in `scripts/Pane.vg` and `scripts/FileOps.vg`.

Copy and move between panes use the toolbar buttons. Drag-and-drop is not on the form itself (VG forms use `Window` + named controls, not `Extends Control` drag virtuals).

## Run

1. From repo root: `scripts/sync_addons.sh convert` (or symlink addon into this folder)
2. Open `samples/apps/vg_twinpane` in Godot 4.6 with Visual Gasic enabled (legacy: `projects/vg_twinpane`)
3. Press F5

Default starting directory: `$HOME` (or `/tmp` if unset).

## Legal

Amiga Directory Opus 4 (GPL) and Magellan II (AROS) may be used as reference implementations. Do **not** use the "Directory Opus" trademark in this project's branding.
