"# GBA Emulator in VisualGasic

A Game Boy Advance emulator written in pure VisualGasic — a Tier 2 (playable
subset) demonstration project built within the VisualGasic IDE.

## Architecture

```
gba_main.vg       ← Godot scene script (main loop, display, input)
gba_emulator.vg   ← Standalone emulator core (CPU + Memory + GPU + Audio)
gba_cpu.vg        ← ARM7TDMI CPU (ARM + THUMB instruction decode)
gba_memory.vg     ← GBA memory map (ROM, EWRAM, IWRAM, VRAM, OAM, IO)
gba_gpu.vg        ← PPU renderer (Mode 0 tilemaps, Mode 3/4 bitmaps)
gba_constants.vg  ← Hardware constants (addresses, bit flags, IO offsets)
```

## Status

- [ ] ARM7TDMI CPU: 32-bit ARM + 16-bit THUMB instruction decode
- [ ] Memory: Full GBA address space with ROM loading
- [ ] GPU: Mode 0 (tilemap BGs), Mode 3 (16-bit bitmap), Mode 4 (8-bit palette)
- [ ] Input: Joypad key interrupts
- [ ] Timer: Timer 0 with prescaler and IRQ
- [ ] DMA: VBlank-triggered DMA, 16/32-bit, fixed/increment
- [ ] Interrupts: VBlank, HBlank, Timer, DMA, Keypad
- [ ] Audio: SoundGen stream (silence, synthesis TBD)

## Usage

1. Open this project in Godot with VisualGasic addon installed
2. Run `gba_main.vg` as the main scene
3. Load a `.gba` ROM file
4. Controls: Arrow keys = D-pad, X = A, Z = B, Enter = Start, Shift = Select, A/S = L/R

## Development Roadmap

### Phase 1 — Core Boot (current)
- ARM + THUMB decode complete enough to run BIOS and boot simple ROMs
- Mode 0/3/4 rendering
- Basic input, VBlank interrupts

### Phase 2 — Playable Subset
- Full ARM/THUMB coverage (MUL/MLA, LDM/STM, SWI, BLX, SWP)
- Mode 1/2/5 rendering (affine BGs)
- Sprite/OBJ rendering
- GBA APU audio synthesis (Digital 1-4, Direct Sound FIFO)
- Save type detection (SRAM, Flash, EEPROM)

### Phase 3 — Compatibility & Polish
- Save states
- Configurable controls
- ROM compatibility database
- Performance profiling report

"