# Builtin Functions & Extension Points

This document describes the built-in functions and the public extension points introduced during the refactor that centralize expression evaluation and builtin handling.

## Overview
- Expression-level builtins are handled by `VisualGasicBuiltins::call_builtin_expr` and `call_builtin_expr_evaluated`.
- Statement-level builtins are handled by `VisualGasicBuiltins::call_builtin`.
- There are helper dispatch functions for base-specific behavior: `call_builtin_for_base_variable`, `call_builtin_for_base_object`, and `call_builtin_for_base_variant`.
- `VisualGasicInstance` exposes a small set of public wrappers used by the builtins module (see below).

## Notable Expression Builtins

String helpers:
- `Len(s)`, `Left(s,n)`, `Right(s,n)`, `Mid(s,start[,len])`
- `UCase(s)`, `LCase(s)`, `Asc(s)`, `Chr(n)`, `Space(n)`, `Str`, `Val`, `InStr`, `Replace`, `Trim`, `LTrim`, `RTrim`, `StrReverse`, `Hex`, `Oct`, `Split`, `Join`

Array helpers:
- `UBound(arr)`, `LBound(arr)`

Math helpers (some handled in `call_builtin_expr_evaluated` — they expect already-evaluated args):
- `Sin`, `Cos`, `Tan`, `Log`, `Exp`, `Atn`, `Sqr`, `Abs`, `Sgn`, `Int`, `Rnd` (fast inline LCG — ~5× faster than Godot wrapper), `Round`, `RandRange` (uses fast LCG), `Lerp`, `Clamp`, `CInt`, `CDbl`, `CBool`

File/dir helpers (delegate to `VisualGasicInstance` wrappers):
- `LOF(fileHandle)`, `Loc(fileHandle)`, `EOF(fileHandle)`, `FreeFile([range])`, `FileLen(path)`, `Dir(...)`, `Randomize()`
- `Timer()` — Seconds since midnight as Double

## Godot Namespace Wrappers (v4.x–v5.1)

VisualGasic ships a layered namespace API for the most common Godot subsystems.
These are dispatched directly inside `call_builtin_expr_evaluated` from
`src/visual_gasic_builtins.cpp` (see the `// ── Pass 1..6` comment markers).
They use VB6 dotted-call syntax (`Camera.Shake 0.5, 10`).

Namespaces (see [VisualGasic_Language_Reference.md §Godot Namespace Wrappers](VisualGasic_Language_Reference.md#v4xv51-godot-namespace-wrappers)
for full verb lists and signatures):

- **Pass 1** math helpers — `Quaternion`, `Basis`, `Transform2D/3D`, `Plane`, `AABB`,
  `NewRNG`, `NewNoise`, `NewCurve`, `Slerp`, `ColorFromHSV`, `ColorToHSV`, `Lighten`, `Darken`
- **Pass 2** audio/camera — `Camera.*`, `Sound.*`, `Speaker.*`, `SoundGen.*`
- **Pass 3** gameplay — `Animation.*`, `Physics.*`, `Ray.*`, `Cell.*`, `Nav.*`, plus globals `Push`, `Pull`, `Spin`
- **Pass 4** device — `Screen.*`, `Joypad.*`, `Sensor.*`, `Permission.*`, `Vibrate`
- **Pass 5** pro features — `Crypto.*`, `Theme.*`, `Shader.*`, `Material.*`, `Skeleton.*`, `Bone.*`, `Video.*`, `JS.*`
- **Android v4.4** — `GPS.*`, `Steps.*`
- **Pass 6** (v5.1 gap-fills) — `Camera.PanTo`/`Bounce`/`FlashColor`, `Crypto.Hex`/`FromHex`/`Base64`,
  `Physics.GravityV2`/`V3`/`Bounce`, `Ray.Cast2D`/`Cast3D`, `Joypad.IsConnected`/`Stick`,
  `Animation.Loop`, `Sensor.Magnetometer`, `Theme.Set`/`Get`, `Shader.Set`/`Get`, `Video.Play` 2-arg

Auto-wired event subs (no `AddHandler` required):
`Permission_Granted` · `Permission_Denied` · `GPS_Updated` · `Steps_Detected`
plus standard Godot lifecycle subs (`_Ready`, `_Process`, `_PhysicsProcess`, `_Input`, …).

Drawing commands (statement-level, available in `_Draw()`):
- `DrawPixel(x, y, color)`, `PSet(x, y, color)` — single pixel
- `DrawString(font, pos, text, color)` — text with font
- `DrawTexture(texture, x, y [, modulate])` — render texture
- `DrawTextureRect(texture, rect, tile [, modulate])` — stretch texture into rect
- `DrawArc(x, y, radius, startAngle, endAngle [, points, color, width])` — arc
- `DrawPolygon(points, color)` — filled polygon from Vector2 array
- `DrawPolyline(points, color [, width])` — multi-segment line
- `SetDrawTransform(x, y [, rotation, scaleX, scaleY])` — set 2D transform
- `ResetDrawTransform()` — reset to identity
- `QueueRedraw()` — request redraw
- `CLS()` — clear screen

Image & Texture builtins:
- `CreateImage(w, h [, fillColor])` — create RGBA8 Image (1–4096 px)
- `CreateTexture(image)` or `CreateTexture(w, h [, fillColor])` — create ImageTexture
- `ImageToTexture(image)` — convert Image → ImageTexture
- `SetImagePixel(image, x, y, color)` — write pixel to Image
- `GetImagePixel(image, x, y)` — read pixel from Image → Color
- `FillImage(image, color)` — fill entire Image
- `FillImageRect(image, rect, color)` — fill rectangular region
- `BlitImage(dest, src, srcRect, destPos)` — copy pixel region between Images
- `UpdateTexture(texture, image)` — push Image data to ImageTexture
- `ImageWidth(image)`, `ImageHeight(image)` — Image dimensions
- `TextureWidth(texture)`, `TextureHeight(texture)` — Texture dimensions
- `GetTextureImage(texture)` — extract Image from ImageTexture
- `SaveImage(image, path)` — save Image as PNG
- `LoadImage(path)` — load image file as Image object

Native Image drawing builtins:

These builtins perform pixel-level drawing entirely in **native C++**, making
them orders of magnitude faster than script-level loops. All operate on an
`Image` object — call `UpdateTexture` afterwards to display changes.

- **`DrawImageLine(image, x1, y1, x2, y2, color[, width])`** — Draws a line
  from `(x1,y1)` to `(x2,y2)` using the Bresenham algorithm. Omit `width`
  (or pass 1) for a 1px line; pass a larger value for a thick brush stroke.
  Out-of-bounds pixels are silently skipped.
  The VB6-style command **`Line`** is an alias for `DrawImageLine`.
  ```vb
  DrawImageLine img, 0, 0, 319, 239, Color(1, 0, 0, 1)       ' 1px red diagonal
  DrawImageLine img, 10, 120, 310, 120, Color8(0,0,255,255), 8 ' 8px blue line
  Line img, 0, 200, 319, 200, Color(0, 1, 0, 1), 4            ' VB6 alias
  ```

- **`DrawImageRect(image, x1, y1, x2, y2, color)`** — Draws a 1px **outline**
  rectangle between two corners. Corner order doesn't matter (auto-normalized).
  For a filled rectangle, use `FillImageRect` instead.
  ```vb
  DrawImageRect img, 20, 20, 200, 150, Color(0, 0, 1, 1)  ' Blue outline
  ```

- **`DrawImageEllipse(image, cx, cy, rx, ry, color)`** — Draws a 1px ellipse
  **outline** centered at `(cx,cy)` with radii `rx`, `ry` (midpoint algorithm).
  Use `rx = ry` for a perfect circle outline.
  ```vb
  DrawImageEllipse img, 160, 120, 80, 50, Color(0, 1, 0, 1)  ' Green ellipse
  ```

- **`DrawImageCircle(image, cx, cy, radius, color)`** — Draws a **filled**
  circle using scanline fill (one `fill_rect` per row). For an outline-only
  circle, use `DrawImageEllipse` with `rx = ry`.
  ```vb
  DrawImageCircle img, 200, 200, 30, Color(1, 1, 0, 1)    ' Yellow sun
  ```

- **`FloodFillImage(image, x, y, color)`** — 4-connected flood fill starting
  at seed `(x,y)`. Replaces all contiguous pixels matching the target color
  with the new color. Runs entirely in C++ with a safety bound of
  `width × height` iterations. Does nothing if target color equals fill color.
  ```vb
  ' Draw a closed shape, then fill its interior:
  DrawImageRect img, 50, 50, 200, 150, Color(0, 0, 0, 1)   ' Black outline
  FloodFillImage img, 100, 100, Color(0, 0, 1, 1)           ' Blue fill inside
  ```

### Bit Manipulation Builtins (native C++, no VG loop overhead)

Bitwise operations on 64-bit integers. All functions truncate floats to `Int64`
before operating. These are implemented directly in C++ via `call_builtin_expr_evaluated()`,
so they're orders of magnitude faster than VG-level loops.

| Function | Aliases | Args | Description |
|----------|---------|------|-------------|
| `BitAnd(a, b)` | — | 2 | Bitwise AND: `a And b` |
| `BitOr(a, b)` | — | 2 | Bitwise OR: `a Or b` |
| `BitXor(a, b)` | — | 2 | Bitwise XOR: `a Xor b` |
| `BitNot(a)` | — | 1 | Bitwise NOT: `Not a` |
| `BitClr(val, bit...)` | — | 2+ | Clear (zero) specified bits: `val And (Not (1 << bit))` |
| `BitSet(val, bit...)` | — | 2+ | Set specified bits: `val Or (1 << bit)` |
| `BitTst(val, bit)` | — | 2 | Test a single bit → Boolean |
| `BitGet(val, bit)` | — | 2 | Get a single bit → 0 or 1 |
| `LeftShift(val, n)` | `Shl` | 2 | Logical left shift by n bits (0..63) |
| `RightShift(val, n)` | `Shr` | 2 | Logical right shift by n bits (0..63) |
| `RotateLeft(val, n)` | `Rol` | 2 | Rotate left by n bits (64-bit) |
| `RotateRight(val, n)` | `Ror` | 2 | Rotate right by n bits (64-bit) |
| `Swap(val)` | — | 1 | Swap high/low 32-bit halves |
| `NumBits(val)` | — | 1 | Population count (number of set bits) |

**Examples:**
```vb
' Basic bitwise ops
Dim a As Long = &HFF00
Dim b As Long = &H0FF0
Print BitAnd(a, b)       ' → &H0F00
Print BitOr(a, b)        ' → &HFFF0
Print BitXor(a, b)       ' → &HF0F0
Print BitNot(a)          ' → &HFFFFFFFFFF00FF (64-bit)

' Bit-level manipulation
Dim flags As Long = 0
flags = BitSet(flags, 0, 2, 4)         ' set bits 0, 2, 4
Print BitTst(flags, 2)                  ' → True
Print BitGet(flags, 1)                  ' → 0
flags = BitClr(flags, 0)               ' clear bit 0

' Shifts and rotates
Print LeftShift(1, 8)                   ' → 256
Print Shl(1, 8)                         ' alias → 256
Print RightShift(&HFF00, 8)            ' → &HFF
Print RotateLeft(&H8000000000000001, 1) ' → &H0000000000000003

' Utility
Print Swap(&HAABBCCDD)                 ' → &HCCDDAABB (swap halves)
Print NumBits(&H0F)                    ' → 4 (binary: 1111)
```


### MemoryBuffer — Zero-Overhead Byte Access

The `MemoryBuffer` type provides direct byte-level read/write access to a raw byte buffer stored as a `PackedByteArray`. When you declare `Dim buf As New MemoryBuffer(size)`, the compiler emits specialized opcodes (`OP_BUF_ALLOC`, `OP_BUF_READ8`, `OP_BUF_WRITE8`, etc.) that bypass the Variant dispatch overhead of generic array access.

**Use cases:** Emulation, binary protocols, I/O buffers, image pixel manipulation, audio sample buffers.

#### Core API

| Syntax | Opcode | Description |
|--------|--------|-------------|
| `Dim buf As New MemoryBuffer(size)` | `OP_BUF_ALLOC` | Allocate a zero-filled byte buffer of `size` bytes |
| `buf(offset) = value` | `OP_BUF_WRITE8` | Write one byte (value AND &HFF) at offset |
| `x = buf(offset)` | `OP_BUF_READ8` | Read one byte as Integer (0–255) |

#### Multi-Byte Access (via VGMemoryBuffer object methods)

| Method | Description |
|--------|-------------|
| `buf.PeekInt16(offset)` | Read signed 16-bit LE word |
| `buf.PeekUInt16(offset)` | Read unsigned 16-bit LE word |
| `buf.PeekInt32(offset)` | Read signed 32-bit LE dword |
| `buf.PeekInt64(offset)` | Read signed 64-bit LE qword |
| `buf.PeekFloat(offset)` | Read 32-bit float |
| `buf.PeekDouble(offset)` | Read 64-bit double |
| `buf.PokeInt16(offset, value)` | Write 16-bit LE word |
| `buf.PokeInt32(offset, value)` | Write 32-bit LE dword |
| `buf.PokeInt64(offset, value)` | Write 64-bit LE qword |

#### Bytecode Fast Path

The compiler emits direct `OP_BUF_*` opcodes for local MemoryBuffer variables. These bypass the `OP_GET_ARRAY`/`OP_SET_ARRAY` path entirely — no Variant boxing, no type dispatch, no refcount overhead. The buffer is stored as a `PackedByteArray` in the local variable slot.

```vb
' Fast buffer read/write — compiles to OP_BUF_ALLOC + OP_BUF_WRITE8 + OP_BUF_READ8
Dim buf As New MemoryBuffer(256)
buf(0) = &H42
buf(1) = &HFF
Dim header As Integer = buf(0)   ' → 66 (0x42)
```


### Optimizer Hints — User-Extensible Performance Directives

Optimizer Hints are **comment-based directives** that tell the VG bytecode optimizer to recognize specific loop patterns, even when the code structure doesn't match the optimizer's built-in pattern detection. They are **NOPs at runtime** — the compiler emits `OP_HINT_*` marker opcodes that the optimizer consumes during the optimization pass, then removes before execution.

**When to use:** When you have a performance-critical loop that you've profiled and want to ensure the optimizer treats it as a known fast pattern.

#### Available Hints

| Hint | Opcode | Effect |
|------|--------|--------|
| `'@accumulator varname` | `OP_HINT_ACCUMULATOR` | Marks a variable as a loop accumulator (sum/product pattern). Tells the optimizer the variable is only modified by `+=` or `*=` operations inside the loop. Enables sum-reduction optimizations. |
| `'@loop_counter varname` | `OP_HINT_LOOP_COUNTER` | Marks a variable as a simple loop counter (0→N with Step 1). Enables counter elision and strength reduction. |
| `'@pure funcname` | `OP_HINT_PURE_CALL` | Marks a function call as pure (no side effects, deterministic). Enables the optimizer to hoist the call out of loops or fold constant arguments. |

#### Example

```vb
' Without hints, the optimizer might not recognize this as a reduction
Function SumArray(arr() As Long) As Long
    Dim total As Long = 0
    Dim i As Long
    '@accumulator total
    '@loop_counter i
    For i = 0 To UBound(arr)
        total = total + arr(i)
    Next i
    SumArray = total
End Function
```

#### Important Notes

- Hints are **advisory, not mandatory**. The optimizer may ignore them if the code doesn't match the expected pattern.
- Hints do **not change program semantics**. A `'@pure` hint on an impure function is a programmer error (results in undefined optimization behavior, not a crash).
- Hints are **forward-looking infrastructure**. As the optimizer grows smarter (v6.1+ Packed Arrays, v7.0 SIMD), hints will unlock more aggressive optimizations without requiring compiler pattern-matching changes.
- Currently, hints are recognized by the compiler and emitted as opcodes. The optimizer pass consumes them as markers. Future versions will use them to drive loop fusion, vectorization, and accumulator specialization.


### SoundGen.* — Real-time Audio Synthesis

The `SoundGen` namespace provides real-time PCM audio synthesis using Godot's
`AudioStreamGenerator`. SoundGen produces audio **entirely in C++** — the
`FillVoices` and `FillVoices4` builtins synthesize hundreds of thousands of
samples per second with zero VG script-loop overhead.

**Basic workflow:**
1. `SoundGen.Open(mix_rate, buffer_length)` → **handle** (Long, the `AudioStreamPlayer` ObjectID)
2. Each frame, call `SoundGen.Available(handle)` to get available stereo frames
3. Fill the buffer using `PushMono`, `PushStereo`, or the bulk `FillVoices` synthesizers
4. `SoundGen.Close(handle)` when done

#### Core API

| Function | Args | Returns | Description |
|----------|------|---------|-------------|
| `SoundGen.Open(mix_rate, buf_len)` | 2 | Long | Creates an AudioStreamGenerator + AudioStreamPlayer, starts playing. `mix_rate` = samples/sec (e.g. 44100), `buf_len` = ring buffer in seconds (e.g. 0.1). Returns handle. |
| `SoundGen.Close(handle)` | 1 | — | Stops and frees the stream player. |
| `SoundGen.Available(handle)` | 1 | Integer | Number of stereo frames (pairs of samples) that can be pushed without blocking. Call each `_Process()` and push this many. |
| `SoundGen.PushMono(handle, sample)` | 2 | — | Pushes one mono sample (Single) as left=right stereo frame. Call inside a loop: `For i = 0 To SoundGen.Available(h) - 1` |
| `SoundGen.PushStereo(handle, left, right)` | 3 | — | Pushes one stereo frame (two Singles). |
| `SoundGen.PushMonoBuffer(handle, samples)` | 2 | — | Push an entire `PackedFloat32Array` as mono frames. Pushes `min(samples.size, available)` frames — ~100× faster than calling PushMono N times. |
| `SoundGen.PushStereoBuffer(handle, samples)` | 2 | — | Push interleaved `PackedFloat32Array [L0,R0, L1,R1, ...]` as stereo frames. Pushes `min(samples.size/2, available)` frames. |

#### FillVoices — 3-Voice Synthesizer

`SoundGen.FillVoices(handle, sample_rate, arp_phase, arp_freq, kick_active, kick_t, kick_dur, noise_active, noise_t, noise_decay)` → `PackedFloat32Array [new_arp_phase, new_kick_t, new_noise_t]`

Synthesizes exactly `SoundGen.Available()` mono frames in a single C++ call.
Mixes three voices:
1. **Square arpeggio** (always on) — ±0.10, 50% duty
2. **Bass kick** (when `kick_active ≠ 0`) — exponential chirp 160→50Hz with click transient
3. **White noise burst** (when `noise_active ≠ 0`) — exponential decay

Returns updated phase/time values so VG can advance its globals.

```vb
' Square-wave arpeggio + optional kick + optional noise burst
Dim h = SoundGen.Open(22050, 0.1)
Dim arpPhase As Single = 0
Dim kickT As Single = 0
Dim noiseT As Single = 0

Sub _Process(delta As Double)
    Dim result As PackedFloat32Array
    result = SoundGen.FillVoices(h, 22050, _
        arpPhase, 440.0, _            ' arp freq = A4
        True, kickT, 0.15, _           ' kick active, 150ms duration
        False, noiseT, 20.0)           ' noise off
    arpPhase = result(0)
    kickT = result(1)
    noiseT = result(2)
End Sub
```

#### FillVoices4 — 4/5-Voice Synthesizer (chiptune engine)

`SoundGen.FillVoices4(handle, sample_rate, lead_f, lead_phase, bass_f, bass_phase, arp_f, arp_phase, hihat_active, hihat_t, hihat_inv_sr [, kick_active, kick_t, kick_dur [, note_age]])` → `PackedFloat32Array`

A full chiptune voice engine — synthesizes exactly `SoundGen.Available()` mono
frames in one C++ call. Four always-on voices + optional fifth kick drum:

| Voice | Type | Amplitude | Description |
|-------|------|-----------|-------------|
| 1 — Lead | 25% pulse | ±0.12 / −0.04 | NES-style lead, 4ms attack envelope |
| 2 — Bass | Sine | ×0.14 | Warm sine bass, 5ms attack |
| 3 — Arp | 50% square | ±0.05 | Percussive square arpeggio |
| 4 — Hi-hat | White noise | ×0.04 | Exponential decay (100 Hz cutoff) |
| 5 — Kick (opt) | 808-style | ×0.50 + ×0.15 (2nd harmonic) | Cosine sweep 200→55Hz, click transient |

**Arguments (11 required):**

| # | Name | Type | Description |
|---|------|------|-------------|
| 1 | handle | Long | SoundGen handle from `Open()` |
| 2 | sample_rate | Single | Mix rate (Hz) — matches `Open()` value |
| 3 | lead_f | Single | Lead oscillator frequency (Hz) — 0 = voice off |
| 4 | lead_phase | Single | Lead oscillator phase (0.0–1.0) — persist between calls |
| 5 | bass_f | Single | Bass oscillator frequency (Hz) — 0 = voice off |
| 6 | bass_phase | Single | Bass oscillator phase (0.0–1.0) — persist |
| 7 | arp_f | Single | Arpeggio frequency (Hz) — 0 = voice off |
| 8 | arp_phase | Single | Arpeggio phase (0.0–1.0) — persist |
| 9 | hihat_active | Boolean | Hi-hat on/off |
| 10 | hihat_t | Single | Hi-hat time accumulator — persist |
| 11 | hihat_inv_sr | Single | 1.0 / sample_rate (pre-computed for speed) |

**Optional arguments (14-arg variant adds kick):**

| # | Name | Type | Description |
|---|------|------|-------------|
| 12 | kick_active | Boolean | Kick on/off |
| 13 | kick_t | Single | Kick time accumulator — persist |
| 14 | kick_dur | Single | Kick duration in seconds (e.g. 0.3) |

**Optional arguments (15-arg variant adds note_age):**

| # | Name | Type | Description |
|---|------|------|-------------|
| 15 | note_age | Single | Seconds since current note started (0 = fresh attack). VG resets to 0 each beat for clean articulation. |

**Returns:** `PackedFloat32Array` with 4 elements (or 5 with kick):
`[new_lead_phase, new_bass_phase, new_arp_phase, new_hihat_t (, new_kick_t)]`

```vb
' Full chiptune engine — drum & bass arpeggio
Dim h = SoundGen.Open(44100, 0.1)
Dim leadPh As Single, bassPh As Single, arpPh As Single
Dim hihatT As Single, kickT As Single
Dim noteAge As Single
Dim beatLen As Single = 60.0 / 140.0 / 4.0   ' 140 BPM, 16th notes
Dim beatCounter As Integer = 0

Sub _Process(delta As Double)
    Dim result As PackedFloat32Array
    
    ' Change note every 16th beat
    noteAge = noteAge + delta
    If noteAge >= beatLen Then
        noteAge = noteAge - beatLen
        beatCounter = (beatCounter + 1) Mod 16
        
        ' Simple arpeggio pattern: C-E-G-C over 4 beats
        Dim notes(3) As Single = {261.63, 329.63, 392.00, 523.25}
        Dim arpFreq As Single = notes(beatCounter Mod 4)
        
        ' Trigger kick on beats 0 and 8
        If beatCounter = 0 Or beatCounter = 8 Then
            result = SoundGen.FillVoices4(h, 44100, _
                0.0, leadPh, _       ' lead off
                110.0, bassPh, _      ' bass A2
                arpFreq, arpPh, _    ' arpeggio
                True, hihatT, 1.0/44100.0, _  ' hi-hat on
                True, 0.0, 0.3, _    ' trigger kick
                noteAge)
            kickT = result(4)
        Else
            result = SoundGen.FillVoices4(h, 44100, _
                0.0, leadPh, _
                110.0, bassPh, _
                arpFreq, arpPh, _
                True, hihatT, 1.0/44100.0, _
                False, kickT, 0.3, _
                noteAge)
        End If
    Else
        ' Continue current notes
        result = SoundGen.FillVoices4(h, 44100, _
            0.0, leadPh, _
            110.0, bassPh, _
            arpFreq, arpPh, _
            True, hihatT, 1.0/44100.0, _
            False, kickT, 0.3, _
            noteAge)
    End If
    
    leadPh = result(0)
    bassPh = result(1)
    arpPh  = result(2)
    hihatT = result(3)
    If result.size() >= 5 Then kickT = result(4)
End Sub
```

**Bulk buffer methods** (fastest path for custom synthesis):

```vb
' Generate a sine wave in VG and push it all at once (no per-sample dispatch)
Dim h = SoundGen.Open(44100, 0.1)
Dim buf As PackedFloat32Array
Dim i As Integer
Dim phase As Single
Dim freq As Single = 440.0
Dim sr As Single = 44100.0

Sub _Process(delta As Double)
    Dim available = SoundGen.Available(h)
    buf.resize(available)
    For i = 0 To available - 1
        buf(i) = Sin(phase * 6.283185)
        phase = phase + freq / sr
        If phase >= 1.0 Then phase = phase - 1.0
    Next
    SoundGen.PushMonoBuffer(h, buf)
End Sub
```


Data introspection helpers:
- `DataCount()` — total number of items in the data tape
- `DataCount("label")` — number of items in a named data section (case-insensitive)
- `DataRemain()` — items remaining from current read pointer to end of tape
- `DataSectionCount()` — total items in the current labeled section
- `DataSectionRemain()` — items remaining in the current labeled section
- `DataPointer()` — current read position (0-based index)
- `PeekData(index)` — read a data value by absolute 0-based index without moving the pointer
- `PeekData("label", offset)` — read a value at *label* + *offset* without moving the pointer
- `SetDataPointer(n)` — set the read pointer to position *n* (clamped to valid range)
- `DataLabels()` — returns an Array of all label names in the data tape
- `DataSectionName()` — returns the label name of the section the pointer is currently in
- `DataToArray()` — read the entire data tape into an Array
- `DataToArray("label")` — read all items in a labeled section into an Array
- `DataToArray(n)` — read *n* items from the current pointer into an Array

Statement-level builtins (examples):
- `MsgBox(message[, buttons, title])` — shows a dialog with VB6-style button/icon constants
- `InputBox(prompt[, title, default])` — shows an input dialog and returns the result

### MsgBox Constants

VisualGasic supports all VB6 MsgBox constants:

**Button Constants (additive):**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbOKOnly` | 0 | OK button only (default) |
| `vbOKCancel` | 1 | OK and Cancel buttons |
| `vbAbortRetryIgnore` | 2 | Abort, Retry, Ignore buttons |
| `vbYesNoCancel` | 3 | Yes, No, Cancel buttons |
| `vbYesNo` | 4 | Yes and No buttons |
| `vbRetryCancel` | 5 | Retry and Cancel buttons |

**Icon Constants (additive):**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbCritical` | 16 | Critical/Error icon |
| `vbQuestion` | 32 | Question mark icon |
| `vbExclamation` | 48 | Warning/Exclamation icon |
| `vbInformation` | 64 | Information icon |

**Return Values:**
| Constant | Value | Description |
|----------|-------|-------------|
| `vbOK` | 1 | User clicked OK |
| `vbCancel` | 2 | User clicked Cancel |
| `vbAbort` | 3 | User clicked Abort |
| `vbRetry` | 4 | User clicked Retry |
| `vbIgnore` | 5 | User clicked Ignore |
| `vbYes` | 6 | User clicked Yes |
| `vbNo` | 7 | User clicked No |

**Example:**
```vb
' Simple message
MsgBox "Hello World!"

' With buttons and icon
Dim result As Integer
result = MsgBox("Save changes?", vbYesNoCancel + vbQuestion, "Confirm")

If result = vbYes Then
    ' Save...
ElseIf result = vbNo Then
    ' Don't save...
Else
    ' Cancel
End If
```

### VarType Constants

Used with `VarType()` to identify a value's type:

| Constant | Value | Description |
|----------|-------|-------------|
| `vbEmpty` | 0 | Uninitialized |
| `vbNull` | 1 | Contains no valid data |
| `vbInteger` | 2 | Integer |
| `vbLong` | 3 | Long integer |
| `vbSingle` | 4 | Single-precision float |
| `vbDouble` | 5 | Double-precision float |
| `vbCurrency` | 6 | Currency |
| `vbDate` | 7 | Date/Time |
| `vbString` | 8 | String |
| `vbObject` | 9 | Object |
| `vbError` | 10 | Error |
| `vbBoolean` | 11 | Boolean |
| `vbVariant` | 12 | Variant |
| `vbDataObject` | 13 | Data access object |
| `vbDecimal` | 14 | Decimal |
| `vbByte` | 17 | Byte |
| `vbArray` | 8192 | Array (OR'd with base type) |

### String Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `vbCrLf` | Chr(13)+Chr(10) | Carriage return + line feed |
| `vbCr` | Chr(13) | Carriage return |
| `vbLf` | Chr(10) | Line feed |
| `vbTab` | Chr(9) | Horizontal tab |
| `vbNewLine` | Chr(10) | Platform newline |
| `vbNullChar` | Chr(0) | Null character |
| `vbNullString` | "" | Empty string |
| `vbBack` | Chr(8) | Backspace |
| `vbFormFeed` | Chr(12) | Form feed |
| `vbVerticalTab` | Chr(11) | Vertical tab |
| `vbQuote` | Chr(34) | Double-quote character |
| `vbSpace` | Chr(32) | Space character (`Space(1)` is equivalent) |
| `vbComma` | Chr(44) | Comma character |
| `vbPipe` | Chr(124) | Pipe / vertical-bar character |

### Key Constants

Used with `Form_KeyDown(KeyCode As Integer)` and `Input.IsKeyPressed()`:

**Navigation:** `vbKeyBack`, `vbKeyTab`, `vbKeyReturn`, `vbKeyEnter`, `vbKeyEscape`, `vbKeySpace`, `vbKeyPageUp`, `vbKeyPageDown`, `vbKeyEnd`, `vbKeyHome`, `vbKeyLeft`, `vbKeyUp`, `vbKeyRight`, `vbKeyDown`, `vbKeyInsert`, `vbKeyDelete`

**Modifiers:** `vbKeyShift`, `vbKeyControl`, `vbKeyMenu`

**Function Keys:** `vbKeyF1`–`vbKeyF12`

**Letters / Digits:** `vbKeyA`–`vbKeyZ`, `vbKey0`–`vbKey9`

**Numpad:** `vbKeyNumpad0`–`vbKeyNumpad9`, `vbKeyMultiply`, `vbKeyAdd`, `vbKeySubtract`, `vbKeyDecimal`, `vbKeyDivide`

**Lock/Misc:** `vbKeyCapital`, `vbKeyNumlock`, `vbKeyScrollLock`, `vbKeyPause`, `vbKeySnapshot`

### Weekday Constants

Used with `Weekday()` and `DatePart()`:

`vbSunday` (1), `vbMonday` (2), `vbTuesday` (3), `vbWednesday` (4), `vbThursday` (5), `vbFriday` (6), `vbSaturday` (7)

First-week constants: `vbUseSystem` (0), `vbFirstJan1` (1), `vbFirstFourDays` (2), `vbFirstFullWeek` (3)

### File Attribute Constants

Used with `GetAttr()` and `SetAttr()`:

| Constant | Value | Description |
|----------|-------|-------------|
| `vbNormal` | 0 | Normal |
| `vbReadOnly` | 1 | Read-only |
| `vbHidden` | 2 | Hidden |
| `vbSystem` | 4 | System |
| `vbVolume` | 8 | Volume label |
| `vbDirectory` | 16 | Directory |
| `vbArchive` | 32 | Archive |
| `vbAlias` | 64 | Alias (symlink) |

### Shell Window Style Constants

Used with `Shell()`:

| Constant | Value | Description |
|----------|-------|-------------|
| `vbHide` | 0 | Hidden |
| `vbNormalFocus` | 1 | Normal with focus |
| `vbMinimizedFocus` | 2 | Minimized with focus |
| `vbMaximizedFocus` | 3 | Maximized with focus |
| `vbNormalNoFocus` | 4 | Normal without focus |
| `vbMinimizedNoFocus` | 6 | Minimized without focus |

### Color Constants

`vbBlack`, `vbRed`, `vbGreen`, `vbYellow`, `vbBlue`, `vbMagenta`, `vbCyan`, `vbWhite`

Base-specific handlers:
- `Clipboard.GetText()`, `Clipboard.SetText(text)`, `Clipboard.Clear()`
- `Tree.GetTextMatrix(row,col)`, `Tree.SetTextMatrix(row,col,text)`, `Tree.AddItem(text)`, `Tree.RemoveItem(index)`
- `Connect` helpers that simplify signal wiring
- `Err`-style dictionary helpers (`Clear`, `Raise`) which call back into the instance to raise runtime errors

### VB6 Global Objects

Three virtual objects are resolved automatically when referenced by name (no `Dim` required):

- **App** — `App.Path`, `App.EXEName`, `App.Title`, `App.Major`, `App.Minor`, `App.Revision`, `App.PrevInstance`, `App.ProductName`, `App.CompanyName`
- **Screen** — `Screen.Width`, `Screen.Height`, `Screen.TwipsPerPixelX`, `Screen.TwipsPerPixelY`, `Screen.MousePointer`
- **Err** — `Err.Number`, `Err.Description`, `Err.Source`, `Err.Clear`, `Err.Raise`

These are `Dictionary` instances initialized in the constructor and added to `non_local_names` in the compiler so they bypass local variable scoping.

### COM-Style Object Classes

Four C++ classes are registered with Godot ClassDB and instantiable via `New` or `CreateObject()`:

| Class | ProgIDs | Description |
|-------|---------|-------------|
| `VGCollection` | `VB6.Collection`, `VBA.Collection` | 1-based ordered collection with string keys |
| `VGRegEx` + `VGRegExMatch` | `VBScript.RegExp` | RegExp engine wrapping Godot PCRE2 |
| `VGHttpRequest` | `MSXML2.XMLHTTP` | HTTP client wrapping Godot HTTPClient |
| `VGTimer` | *(via New VBTimer)* | Poll-based timer with Interval/Enabled |

### File I/O Bytecode Opcodes

Four new bytecode opcodes for compiled file I/O:
- `OP_PRINT_FILE` — `Print #n, expr`
- `OP_WRITE_FILE` — `Write #n, expr`
- `OP_INPUT_FILE` — `Input #n, var`
- `OP_LINE_INPUT_FILE` — `Line Input #n, var`

### GoSub/Return

Intra-procedure branching compiled to bytecode:
- `OP_GOSUB` — Push return address and jump to label
- `OP_RETURN_GOSUB` — Pop and return to address
- Managed via a `gosub_stack` (Vector<int>) in the bytecode VM.

### Enhanced Data/Read System

Three new bytecode opcodes for the enhanced Data system:
- `OP_LOAD_DATA` — Pop path string from stack, open file, parse comma-separated values, append to data tape
- `OP_CLEAR_DATA` — Clear data tape, reset pointer, free runtime-loaded nodes
- `OP_DATA_FROM_STRING` — Pop string from stack, parse as comma-separated values, append to data tape
- `OP_COERCE_TYPE` — `[OP] [TYPE_IDX]` — Pop value, coerce to the type named by constant at TYPE_IDX, push result (used by typed `Read x As Integer`)

New statement keywords:
- `ClearData` — Clears the data tape (keyword registered in tokenizer)
- `DataFromString` — Parse a string expression as data values and append to tape (keyword registered in tokenizer)
- `Read x As Type` — Typed Read with compile-time coercion instruction
- `Data 1,,3` — Empty slots insert `Nothing` between commas

Public instance accessors used by builtins:
- `get_data_count()` — total tape size
- `get_data_pointer()` — current read position
- `get_data_section_end()` — end index for current section
- `get_data_section_start()` — start index for current section
- `get_label_to_data_index()` — label→index Dictionary (keys lowercase)

## VisualGasicInstance public wrappers
The builtins implementation uses a handful of instance helpers. These are documented here so extension authors know where to call into the runtime.

- `Variant evaluate_expression_for_builtins(ExpressionNode *expr)`
  - Evaluates an expression from the instance context; used by builtins that accept expressions as arguments.

- File/IO wrappers (renamed):
  - `Variant file_lof(int handle)`
  - `Variant file_loc(int handle)`
  - `Variant file_eof(int handle)`
  - `int file_free(int range)`
  - `Variant file_len(const String &path)`
  - `Variant file_dir(const Array &args)`
  - `void randomize_seed()`

- Error raising wrapper (renamed):
  - `void raise_runtime_error(const String &msg, int code)` — used by Err.Raise and similar flows.

These wrappers are intentionally small and stable to allow `visual_gasic_builtins.cpp` to be compiled in a separate translation unit while still using instance functionality.

## Extension points for third-party code

If you want to extend or override builtins:
- Implement a new dispatch in `visual_gasic_builtins.cpp` or add another translation unit that follows the same pattern.
- Use `call_builtin_expr` / `call_builtin_expr_evaluated` for expression-level functions. `call_builtin_expr` receives a `CallExpression*` and may evaluate arguments itself; `call_builtin_expr_evaluated` accepts already-evaluated `Array` of args.
- Use `call_builtin` for statement-level functions. Return `r_found = true` and set `r_ret` if returning a value.
- For base-object/variant-specific behavior, implement handling in `call_builtin_for_base_object` / `call_builtin_for_base_variant` / `call_builtin_for_base_variable` respectively.

## Examples

Simple BASIC usage:

```
Dim s
 s = Left("hello", 2)    ' returns "he"
 Print Len(s)             ' prints 2

Call MsgBox("Done")
```

Calling from C++ builtins (pseudo):

``cpp
bool r_handled = false;
Variant result = VisualGasicBuiltins::call_builtin_expr_evaluated(instance, "Len", {String("abc")}, r_handled);
if (r_handled) { /* use result */ }
```

## Tests

There is a small runtime test under `demo/test_builtins.bas` and a runner `tests/run_builtin_tests.py` that builds and executes the demo headless to validate core builtins.

## Notes and future work

- Add unit tests for `VisualGasicBuiltins` and `VisualGasicExpressionEvaluator` as C++/Godot tests to provide faster feedback than full headless runs.
- Consider moving more builtins behind a registration API to enable plugins to add builtins without editing core source files.
