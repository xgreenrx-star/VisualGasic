Drop a .crt cartridge image here named "cartridge.crt" and it will
auto-load at boot (Native Machine mode only), the same way roms/ auto-loads
the KERNAL/BASIC/character ROMs.

You can also load a cartridge (.crt or a raw headerless 8K/16K $8000 ROM
dump) at any time, even after it has already booted, two ways:

  - RECOMMENDED: copy the file in your desktop file manager, click into the
    emulator window, and press Ctrl+V. A pasted file path is detected
    automatically (the same way a pasted BASIC listing is detected) and
    hot-swaps the cartridge in with a full soft-reset so it autostarts
    immediately.
  - Drag-and-drop the file straight onto the emulator window. This is wired
    up via Godot's OS file-drop signal, but has been observed to not fire at
    all on at least one Linux desktop/window manager -- if nothing happens
    when you drop a file, use the copy+paste method above instead.

Only "Normal cartridge" images (hardware type 0 -- plain 8K or 16K ROM at
$8000, no bank-switching) are supported right now, whether wrapped in a
.crt or a raw headerless dump. Bank-switched mappers (EasyFlash, Action
Replay, Simons' BASIC, etc.) and Ultimax-mode ($E000) cartridges are not
implemented yet and will be rejected with a message in the console/log.

See the "Cartridges" section in ../MANUAL.md for details.

