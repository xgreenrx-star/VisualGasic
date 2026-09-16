# Audio

Sound design, music integration, and audio programming.

## Overview

Audio synthesis, sample playback, music integration with procedural sound generation via GDSfx and BoscaFXR.

## Projects

| Project | Focus |
|---------|-------|
| Interactive Audio | Real-time synthesis, parameter control |
| Procedural SFX | Sound effect generation, sequencing |
| Music Player | Background music, cross-fading, playlists |

## Audio Tools

- **GDSfx** — Procedural audio synthesis in GDScript
- **BoscaFXR** — Chiptune and retro sound effect generator (integrated addon)
- **AudioStreamPlayer** — Godot's native audio node

## Quick Start

1. Open project in Godot editor
2. Place AudioStreamPlayer or GDSfx node in scene
3. Configure frequency/amplitude/effects parameters
4. Run and observe real-time audio generation

## Key Concepts

- PCM audio generation (sample rate, bit depth)
- Waveforms: sine, square, sawtooth, triangle
- Envelopes: ADSR (Attack, Decay, Sustain, Release)
- Filters: low-pass, high-pass, band-pass
- Effects: reverb, delay, distortion

## Notes

- Procedural audio is CPU-intensive; pre-generate for production
- Use AudioStreamOGGVorbis for streaming music to reduce memory
- GDSfx demos show synthesis patterns; not recommended for real-time game audio
