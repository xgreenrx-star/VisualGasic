# Commodore 64 Emulator — User Manual

`demos/C64_Emulator/` is a Godot 4.6.1 GDExtension-based Commodore 64 emulator.
In its default configuration (**Native Machine mode**, `NATIVE_MACHINE = True` in
`c64_main.vg`), the entire machine — 6510 CPU, RAM/ROM banking, VIC-II raster
video, and the CIA1 system timer — runs natively in C++
(`src/cpu_cores/visual_gasic_c64_machine.cpp`) executing the real, unmodified
KERNAL, BASIC, and character ROMs shipped in `roms/`:

- `roms/kernal.901227-03.bin`
- `roms/basic.901226-01.bin`
- `roms/characters.901225-01.bin`

This means it boots to the authentic `**** COMMODORE 64 BASIC V2 ****` /
`READY.` screen with a blinking cursor, just like real hardware or VICE.

## Running it

Open `demos/C64_Emulator/main.tscn` in the Godot editor and run the scene
(F6), or run the project itself (F5) if `main.tscn` is set as the main scene.
Boot takes a few seconds of virtual time; wait for the `READY.` prompt before
typing or pasting anything.

## Typing directly

Once booted, the emulator behaves like a real C64: click into the window and
type. Standard BASIC V2 commands and line-numbered programs work exactly as
on real hardware (e.g. `10 PRINT "HELLO"` then `RUN`).

## Loading a program via clipboard paste (Ctrl+V)

Typing in a whole program character-by-character is slow, so the emulator
also supports pasting from the system clipboard with **Ctrl+V** (or Cmd+V on
macOS). What happens next depends on what you paste:

1. **A full line-numbered BASIC listing** (the first non-blank line starts
   with a digit, e.g. `10 PRINT "HI"`) is recognized as a program listing and
   loaded **directly into memory** — instantly and byte-perfectly. The
   listing is tokenized using the real BASIC V2 keyword table and written to
   RAM at `$0801` with correct line-link pointers, and `VARTAB`/`ARYTAB`/
   `STREND` are fixed up exactly as a real `LOAD"...",8` would leave them.
   This is effectively a "virtual disk/tape load."
2. **Anything else** (a single command, a short text fragment) is queued and
   typed into the real KERNAL keyboard type-ahead buffer (`$0277-$0280`,
   count byte at `$C6` — the classic `POKE 198,N` trick), one BASIC line (or
   up to 10 characters, whichever comes first) per burst, waiting for the
   previous burst to fully drain before sending the next. This mirrors how a
   real "type it in" utility or a human typing quickly would behave.

**Important:** pasting a listing only *loads* it into memory — just like a
real `LOAD`, it does **not** auto-run. After pasting, type `RUN` and press
Enter to execute it.

### Quick example

1. Copy this to your clipboard:
   ```
   10 PRINT "HELLO WORLD"
   20 PRINT "FROM VISUALGASIC"
   ```
2. Click into the emulator window once it shows `READY.`
3. Press Ctrl+V — the listing loads instantly (no visible typing).
4. Type `RUN` and press Enter.

## Loading a cartridge (.crt)

There are three ways to load a cartridge in **Native Machine mode**:

1. **Auto-load at boot** — drop a `.crt` file at `carts/cartridge.crt`
   (create the `carts/` folder if it isn't there yet) and it loads
   automatically, the same convention as the `roms/` folder.
2. **Copy the file, then paste (Ctrl+V) into the emulator window** — this
   is the recommended way to load a cartridge at runtime. Copy a `.crt` file
   (or a raw headerless ROM dump) in your desktop file manager, click into
   the emulator window once it shows `READY.`, and press Ctrl+V. A pasted
   clipboard value that's a single line, ends in `.crt`/`.bin`, and points
   at a file that actually exists is recognized as a cartridge path (the
   same kind of clipboard-content sniffing used to recognize a pasted BASIC
   listing, see above) and hot-swaps the cartridge in with a full
   soft-reset so it autostarts immediately, just like power-cycling a real
   C64 with the cartridge already plugged in.
3. **Drag-and-drop onto the window** — wired up via Godot's OS
   `files_dropped` signal, but **this has been observed to not fire at all
   on at least one Linux desktop environment/window manager** — if dragging
   a file onto the window silently does nothing, use option 2 instead
   (copy the file, then Ctrl+V into the window).

Only **"Normal cartridge"** images are supported right now — plain 8K or
16K ROM cartridges with no bank-switching (hardware type 0 in the `.crt`
spec). Bank-switched mappers (EasyFlash, Action Replay, Simons' BASIC, Ocean
type 1, etc.) are not implemented and will be rejected with a message in the
console/log naming the unsupported hardware type.

**Raw headerless ROM dumps** (no `.crt` wrapper — just the 8192 or 16384
raw cartridge bytes, a common format for hand-extracted images) are also
accepted directly, via all three loading methods above, as long as they're
a plain $8000-based Normal 8K/16K cartridge (checked by looking for the
real `CBM80` autostart signature at the expected offset). Ultimax-mode
cartridges (ROM mapped at $E000, replacing the KERNAL — a completely
different memory layout) are not supported and are rejected with a
different, specific error message.

When a cartridge is present, the emulator automatically falls back to the
**authentic boot sequence** (RAMTAS is not skipped, even if `SKIP_RAM_TEST`
is `True`) — the fast-boot stub jumps straight to BASIC and would never run
the real KERNAL code that detects the cartridge's `"CBM80"` signature and
autostarts it. This means booting with a cartridge takes a few seconds
longer than the normal fast boot.

## Known limitations

- Cartridge support only exists in **Native Machine mode**
  (`NATIVE_MACHINE = True`); the pure-VG and Turbo Mode CPU cores don't have
  it.
- Only "Normal cartridge" (8K/16K, no bank-switching, loaded at $8000) images
  are supported, whether wrapped in a `.crt` or a raw headerless dump.
  Bank-switched mappers and Ultimax-mode ($E000) cartridges are not
  implemented. Tape (`.tap`) and disk (`.d64`) images are not supported yet
  either — `LOAD "*",8,1` / `LOAD "...",1` have no virtual device behind
  them, so they'll report a real KERNAL `DEVICE NOT PRESENT` error, exactly
  like a real C64 with no drive/datasette attached.
- Paste bursts are capped at 10 characters (the real hardware keyboard
  buffer's capacity) — longer lines are automatically split across multiple
  bursts.
- Paste is ignored until the emulator has fully booted (`bLoaded = True`);
  pasting during the boot sequence is a no-op.

## Where the design notes live

The investigation history, root causes, and design decisions behind the
paste/loader feature are recorded in this repository's Copilot memory
(workspace-scoped notes, not plain files in this folder — see your
`/memories/repo/` files if you have tool access): `c64_paste_and_loader.md`,
`build_and_test.md`, and `c64_native_for_loop_bug.md`. This manual is the
user-facing summary of that work.
