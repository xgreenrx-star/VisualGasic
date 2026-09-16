# VG Terminal — ANSI BBS Terminal Client

A full-featured terminal emulator and BBS (Bulletin Board System) client written entirely in VisualGasic.

## Features

- **ANSI Terminal Emulation** — 80×24 character grid with full 16-color ANSI support
- **ANSI Parser State Machine** — Handles ESC sequences, CSI commands, cursor movement, colors
- **TCP Networking** — Connect to BBS servers via WinSock TCP sockets
- **Bookmarks** — Save and recall favorite BBS addresses (via SaveSetting/GetSetting)
- **Session Logging** — Save terminal sessions to text files
- **Clipboard Support** — Copy selected text, paste into the terminal
- **Keyboard Input** — Send keystrokes to remote host in real time
- **Pre-loaded BBS Bookmarks** — telehack.com, bbs.fozztexx.com, and more

## OS Integration Demonstrated

| Feature | VG API |
|---------|--------|
| TCP Networking | WinSock (Connect, Send, Receive) |
| File I/O | FreeFile, Open, Print #, Close |
| Preferences | SaveSetting, GetSetting |
| Clipboard | Clipboard.GetText, Clipboard.SetText |
| System Info | VGSystem, Environ |
| Dialogs | MsgBox, InputBox |

## Files

- `VGTerminal.tscn` — Form layout with menus (File, Connect, Bookmarks, Settings)
- `VGTerminal.vg` — All terminal logic (~550 lines of VG code)
- `main.tscn` — Scene launcher

## How to Run

Open `main.tscn` in Godot and run, or open `VGTerminal.tscn` in the VG Form Editor.

## Platforms

Linux • Windows • Android • Apple • HTML5
