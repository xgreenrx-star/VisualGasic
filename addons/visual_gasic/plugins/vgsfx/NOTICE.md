# VGSFX — Third-party notices

VGSFX is a GDScript port of [bfxr2](https://github.com/increpare/bfxr2) by
Stephen Lavelle (increpare).

## Licenses

### bfxr2 — MIT License

> MIT License
>
> Copyright (c) 2021 Stephen Lavelle
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.

### Sfxr DSP — Apache License 2.0

The Bfxr DSP code in `vgsfx_dsp.gd` is derived from Thomas Vian's `SfxrSynth`
(part of as3sfxr), which was itself a port of DrPetter's Sfxr.

> Copyright 2010 Thomas Vian
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
>     http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OF ANY KIND, either express or implied.

### Adventure Kid Waveforms — CC0 1.0

The wavetables in `vgsfx_akwf.gd` (`hvoice_0012`, `fmsynth_0012`,
`granular_0044`) are from the Adventure Kid Waveforms (AKWF) library:

  https://www.adventurekid.se/akrt/waveforms/adventure-kid-waveforms/

Released under CC0 1.0 Universal (public domain). Conversion for the
Teensy Audio Library by Brad Roy (https://github.com/prosper00).

## Credits

* DrPetter — Sfxr (the original)
* Tom Vian — as3sfxr
* Stephen Lavelle (increpare) — Bfxr / Bfxr2
* Adventure Kid + Brad Roy — AKWF wavetables
* Obiwannabe — Footstep generator (Phase 3 only)
