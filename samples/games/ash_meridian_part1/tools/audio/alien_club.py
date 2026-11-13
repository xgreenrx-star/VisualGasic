#!/usr/bin/env python3
"""Original alien chamber music; regenerate with python tools/audio/alien_club.py.

No conventional drum kit or common-time clock: unequal chambers contain different fractional
subdivisions. Continuous beds are periodic; every call, pulse and delay wraps
across the loop boundary rather than fading the whole composition to silence.
"""
import json
from pathlib import Path
import subprocess

import numpy as np

from dsp import SR, bp, fade_edges, normalize, place, t_axis, write_ogg


SEED = 910731
CHAMBERS = (7.3, 9.1, 6.7, 10.9, 8.3, 12.7, 7.9, 11.3, 9.7, 10.1, 11.1)
LOOP = round(sum(CHAMBERS), 6)
FRAMES = round(LOOP * SR)
OUTPUT = Path(__file__).resolve().parents[2] / "assets/audio/club/club_track.ogg"


def schedule():
	"""Return reproducible musical onsets, not a purported beat/BPM map."""
	rng = np.random.default_rng(SEED)
	events = []
	start = 0.0
	for chamber, duration in enumerate(CHAMBERS):
		divisor = (13, 11, 17, 13, 19)[chamber % 5]
		steps = ((0, 2, 5, 9), (1, 4, 8), (0, 3, 7, 12, 15))[chamber % 3]
		for index, step in enumerate(steps):
			# Some subdivisions deliberately cross into the next chamber.
			at = (start + duration * step / divisor + rng.uniform(-0.09, 0.09)) % LOOP
			events.append({
				"kind": "membrane", "time_seconds": round(at, 6),
				"duration_seconds": round(float(rng.uniform(1.0, 2.4)), 6),
				"frequency_hz": float((63.7, 89.3, 107.1, 142.6, 79.9)[(chamber + index) % 5]),
				"pan": float(rng.uniform(-0.8, 0.8)),
				"gain": float(rng.uniform(0.13, 0.22)),
				"chamber": chamber, "subdivision": f"{step}/{divisor}",
			})
		if chamber % 3 != 1:
			events.append({
				"kind": "call", "time_seconds": round((start + duration * 0.37) % LOOP, 6),
				"duration_seconds": round(float(rng.uniform(5.2, 8.4)), 6),
				"frequency_hz": float((181.3, 247.7, 213.1, 157.9)[chamber % 4]),
				"pan": float(rng.uniform(-0.65, 0.65)), "gain": 0.105,
				"chamber": chamber,
			})
		for offset in (0.193, 0.731):
			events.append({
				"kind": "glass", "time_seconds": round(start + duration * offset, 6),
				"duration_seconds": 4.7,
				"frequency_hz": float((417.1, 569.3, 733.7, 881.9, 643.1)[chamber % 5]),
				"pan": float(rng.uniform(-0.95, 0.95)), "gain": 0.052,
				"chamber": chamber,
			})
		start += duration
	kick_rng = np.random.default_rng(SEED + 808)
	start = 0.0
	for chamber, duration in enumerate(CHAMBERS):
		divisor = (13, 17, 11, 19)[chamber % 4]
		steps = ((0, 1, 5, 9), (0, 4, 5, 12, 15), (0, 2, 7))[chamber % 3]
		for index, step in enumerate(steps):
			events.append({
				"kind": "sub_kick",
				"time_seconds": round((start + 0.18 + duration * step / divisor
					+ kick_rng.uniform(-0.035, 0.035)) % LOOP, 6),
				"duration_seconds": round(float(kick_rng.uniform(0.85, 1.65)), 6),
				"frequency_hz": float((39.7, 46.3, 53.1, 43.9, 58.7)[(chamber + index) % 5]),
				"pan": 0.0, "gain": float(kick_rng.uniform(0.5, 0.66)),
				"chamber": chamber, "subdivision": f"{step}/{divisor}",
			})
		start += duration
	return sorted(events, key=lambda event: event["time_seconds"])


def wrap_place(buf, clip, at, gain=1.0, pan=0.0):
	"""Use the shared equal-power panner, including tails crossing the seam."""
	offset = round(at * SR) % len(buf)
	for first in range(0, len(clip), len(buf)):
		segment = clip[first:first + len(buf)]
		count = min(len(segment), len(buf) - offset)
		place(buf, segment[:count], offset / SR, gain, pan)
		if count < len(segment):
			place(buf, segment[count:], 0, gain, pan)
		offset = 0


def voice(event, rng):
	t = t_axis(event["duration_seconds"])
	f = event["frequency_hz"]
	if event["kind"] == "sub_kick":
		frequency = f + 145.0 * np.exp(-t / 0.024)
		frequency += f * 0.12 * np.sin(2 * np.pi * 3.71 * t) * np.exp(-t / 0.18)
		phase = 2 * np.pi * np.cumsum(frequency) / SR
		body = np.sin(phase) + 0.14 * np.sin(phase * 2.013) * np.exp(-t / 0.13)
		x = np.tanh(body * 1.6) / 1.6
		x *= (1 - np.exp(-t / 0.0015)) * np.exp(-t / 0.3)
		return fade_edges(x, 0.001, 0.12).astype(np.float32)
	elif event["kind"] == "membrane":
		phase = 2 * np.pi * f * (t + 0.055 * (1 - np.exp(-t / 0.14)))
		x = np.sin(phase + 1.4 * np.exp(-t / 0.16) * np.sin(phase * 1.413))
		x += 0.24 * np.sin(phase * 2.731) * np.exp(-t / 0.3)
		x *= (1 - np.exp(-t / 0.035)) * np.exp(-t / 0.43)
	elif event["kind"] == "call":
		u = t / event["duration_seconds"]
		frequency = f * (1 + 0.24 * np.sin(2 * np.pi * u - 0.8)
			+ 0.031 * np.sin(2 * np.pi * 6.7 * t) * np.sin(np.pi * u))
		phase = 2 * np.pi * np.cumsum(frequency) / SR
		x = np.sin(phase + (1.3 + 0.8 * np.sin(2 * np.pi * u)) * np.sin(phase * 1.731))
		x += 0.22 * np.sin(phase * 3.117) + 0.15 * np.sin(phase * 0.503)
		breath = bp(rng.standard_normal(len(t)), 640, 2100)
		x = bp(x, 130, 2600) * 0.7 + breath * 0.19
		x *= np.sin(np.pi * u) ** 2 * (0.7 + 0.3 * np.sin(2 * np.pi * 1.37 * t) ** 2)
	else:
		x = sum(g * np.sin(2 * np.pi * f * ratio * t)
			* np.exp(-t / decay) for ratio, g, decay in
			((1, 0.65, 1.8), (1.419, 0.35, 1.3), (2.713, 0.17, 0.75)))
		x *= 1 - np.exp(-t / 0.06)
	return fade_edges(x, 0.015, 0.45).astype(np.float32)


def render():
	rng = np.random.default_rng(SEED + 1)
	t = np.arange(FRAMES, dtype=np.float64) / SR
	angle = 2 * np.pi * t / LOOP
	audio = np.zeros((FRAMES, 2), dtype=np.float32)
	# Integer carrier bins and modulation cycles make the entire bed periodic,
	# while the close, non-tempered frequency ratios produce beating.
	for index, frequency in enumerate((47.3, 66.7, 91.619, 128.609, 149.003, 189.31)):
		bin_index = round(frequency * LOOP)
		phase = bin_index * angle + 1.1 * np.sin((index + 2) * angle + index)
		tone = np.sin(phase) + 0.16 * np.sin(2 * phase + 0.6)
		swell = 0.72 + 0.28 * np.sin((index + 1) * angle + index * 0.91)
		motion = 0.55 * np.sin((index + 2) * angle + index * 1.3)
		gain = (0.084, 0.046, 0.035, 0.025, 0.018, 0.012)[index]
		audio[:, 0] += (tone * swell * gain * np.sqrt((1 - motion) / 2)).astype(np.float32)
		audio[:, 1] += (tone * swell * gain * np.sqrt((1 + motion) / 2)).astype(np.float32)
	del phase, tone, swell, motion
	# Circularly filtered noise: no filter-start transient or pasted ambience.
	frequencies = np.fft.rfftfreq(FRAMES, 1 / SR)
	for channel in range(2):
		noise = np.fft.rfft(rng.standard_normal(FRAMES).astype(np.float32))
		curve = np.exp(-0.5 * ((frequencies - 830) / 490) ** 2)
		curve += 0.09 * np.exp(-0.5 * ((frequencies - 3300) / 850) ** 2)
		curve *= np.minimum(frequencies / 260, 1) ** 2
		texture = np.fft.irfft(noise * curve, n=FRAMES)
		texture /= np.sqrt(np.mean(texture ** 2))
		audio[:, channel] += (0.009 * texture * (0.68 + 0.32 *
			np.sin(3 * angle + channel * 1.7))).astype(np.float32)
	del noise, texture, curve, frequencies
	events = schedule()
	for event in events:
		clip = voice(event, rng)
		at, gain, pan = event["time_seconds"], event["gain"], event["pan"]
		# A slow density arc, without a conventional drop or chorus.
		gain *= 0.78 + 0.22 * np.sin(np.pi * at / LOOP) ** 2
		wrap_place(audio, clip, at, gain, pan)
		delays = () if event["kind"] == "sub_kick" else ((0.379, 0.24), (0.913, 0.14), (2.173, 0.075), (3.719, 0.035))
		for delay, level in delays:
			wrap_place(audio, clip, at + delay, gain * level, -pan)
	# Circular diffusion, so reverberation is never truncated at the file end.
	dry = audio.copy()
	for delay, gain in ((0.137, 0.09), (0.431, 0.065), (1.127, 0.04)):
		audio += np.roll(dry[:, ::-1], round(delay * SR), axis=0) * gain
	audio -= np.mean(audio, axis=0)
	audio = normalize(audio, peak=0.58).astype(np.float32)
	return audio, events


def measurements(audio):
	if audio.shape != (FRAMES, 2) or not np.all(np.isfinite(audio)):
		raise ValueError("Expected finite, stereo, full-length loop")
	seam = np.abs(audio[0] - audio[-1])
	window = SR // 10
	head_rms = float(np.sqrt(np.mean(audio[:window] ** 2)))
	tail_rms = float(np.sqrt(np.mean(audio[-window:] ** 2)))
	return {
		"duration_seconds": len(audio) / SR, "sample_rate_hz": SR, "channels": 2,
		"peak": float(np.max(np.abs(audio))),
		"rms": float(np.sqrt(np.mean(audio ** 2))),
		"dc_per_channel": np.mean(audio, axis=0).astype(float).tolist(),
		"seam_step_per_channel": seam.astype(float).tolist(),
		"seam_head_rms": head_rms, "seam_tail_rms": tail_rms,
		"stereo_difference_rms": float(np.sqrt(np.mean((audio[:, 0] - audio[:, 1]) ** 2))),
	}


def decode(path):
	raw = subprocess.run(
		["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-acodec",
		 "pcm_f32le", "-ar", str(SR), "-ac", "2", "-"],
		check=True, capture_output=True).stdout
	return np.frombuffer(raw, dtype="<f4").reshape(-1, 2)


def main():
	audio, events = render()
	source = measurements(audio)
	write_ogg(str(OUTPUT), audio, quality=7)
	encoded = measurements(decode(OUTPUT))
	if encoded["peak"] >= 0.7 or max(encoded["seam_step_per_channel"]) >= 0.025:
		raise ValueError(f"Encoded loop failed headroom/seam validation: {encoded}")
	metadata = {
		"title": "The Membrane Remembers", "generator": "tools/audio/alien_club.py",
		"seed": SEED, "original_procedural_audio": True, "external_audio_sources": [],
		"duration_seconds": LOOP, "loop": True, "loop_start_sample": 0,
		"loop_end_sample_exclusive": FRAMES, "sample_rate_hz": SR, "channels": 2,
		"rhythm": {
			"meter": "unmetered asymmetric chamber cycle; no common-time beat",
			"chamber_lengths_seconds": list(CHAMBERS),
			"subdivisions": [13, 11, 17, 19],
			"description": "Unequal chambers, fractional onsets with deterministic drift; "
				"some membrane events cross chamber boundaries. Events are musical "
				"onsets, not a regular beat map. Centered 808-style sub kicks form "
				"unequal clusters and gaps, with microtonal pitch drops. No global BPM.",
		},
		"tuning": "Non-equal-tempered frequency ratios; drones quantized only to loop-period FFT bins",
		"layers": ["irregular pitch-dropping 808-style sub kicks", "microtonal beating drones", "irregular resonant membrane pulses",
			"synthetic gliding organic calls", "inharmonic glass", "circular spectral atmosphere"],
		"seam_method": "periodic bed; wrapped voice tails, cross-delays and circular diffusion; no master fade",
		"events": events, "validation": {"source": source, "decoded_vorbis": encoded},
	}
	OUTPUT.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
	print(json.dumps({"output": str(OUTPUT), "events": len(events), "validation": metadata["validation"]}, indent=2))


if __name__ == "__main__":
	main()
