#!/usr/bin/env python3
"""Original selectable club tracks with invented Narcean sung/chant syllables."""
import json

import numpy as np

from alien_club import CHAMBERS, FRAMES, LOOP, OUTPUT, SEED, decode, measurements, voice, wrap_place
from dsp import SR, bp, fade_edges, normalize, t_axis, write_ogg


TRACKS = (
	("lullaby", "Sleep Beneath the Glass", "ethereal hypnotic alien lullaby"),
	("fracture", "Teeth of the Relay", "fractured alien rap / sub-bass"),
	("undertow", "The Floor Answers", "alien dubstep / growling bass"),
)
WORDS = ("sha", "vei", "nu", "rah", "esh", "tho", "li", "ka")
FORMANTS = ((750, 1200), (450, 2200), (350, 850), (700, 1100),
	(500, 1900), (500, 900), (300, 2400), (800, 1300))


def schedule_track(kind):
	if kind not in {row[0] for row in TRACKS}:
		raise ValueError(f"Unknown club composition: {kind}")
	rng = np.random.default_rng(SEED + (1 if kind == "lullaby" else 2 if kind == "fracture" else 3))
	events = []
	start = 0.0
	for chamber, duration in enumerate(CHAMBERS):
		divisor = (13, 17, 11, 19)[chamber % 4]
		steps = (0, 3, 7) if kind == "lullaby" else (0, 1, 4, 7, 9, 12)
		for i, step in enumerate(steps):
			word = (chamber * 3 + i) % len(WORDS)
			events.append({
				"kind": "vocal", "time_seconds": round((start + duration * step / divisor + 0.25) % LOOP, 6),
				"duration_seconds": float(rng.uniform(1.7, 2.8) if kind == "lullaby" else rng.uniform(0.19, 0.38)),
				"frequency_hz": float((193.1, 229.7, 257.3, 211.9)[i % 4] if kind == "lullaby" else (98.3, 117.1, 87.9)[i % 3]),
				"word": WORDS[word], "formants": list(FORMANTS[word]),
				"gain": 0.24 if kind == "lullaby" else 0.3,
				"pan": float(rng.uniform(-0.3, 0.3)), "chamber": chamber,
				"subdivision": f"{step}/{divisor}", "soft": kind == "lullaby",
			})
		if kind != "lullaby":
			for i, step in enumerate((0, 2, 5, 6, 10, 14)):
				at = (start + duration * step / divisor + rng.uniform(-0.04, 0.04)) % LOOP
				events.append({"kind": "sub_kick", "time_seconds": round(at, 6),
					"duration_seconds": 1.2, "frequency_hz": (38.9, 43.7, 51.3)[(i + chamber) % 3],
					"gain": 0.7, "pan": 0.0, "chamber": chamber, "subdivision": f"{step}/{divisor}"})
			for i, offset in enumerate((0.23, 0.61, 0.83)):
				events.append({"kind": "growl", "time_seconds": round(start + duration * offset, 6),
					"duration_seconds": 1.35 if kind == "fracture" else 2.3,
					"frequency_hz": (41.3, 56.9, 47.1)[(i + chamber) % 3],
					"gain": 0.16 if kind == "fracture" else 0.3,
					"pan": float(rng.uniform(-0.2, 0.2)), "chamber": chamber})
		start += duration
	return sorted(events, key=lambda event: event["time_seconds"])


def sung_syllable(event, rng):
	t = t_axis(event["duration_seconds"])
	u = t / event["duration_seconds"]
	frequency = event["frequency_hz"] * (1 + 0.025 * np.sin(t * 2 * np.pi * 4.13))
	frequency *= 1 + 0.08 * np.exp(-t / 0.07)
	phase = 2 * np.pi * np.cumsum(frequency) / SR
	f = event["frequency_hz"]
	x = np.zeros(len(t))
	for harmonic in range(1, 44):
		hz = f * harmonic
		weight = 0.07 / harmonic
		for formant in event["formants"]:
			weight += np.exp(-0.5 * ((hz - formant) / 140) ** 2) / np.sqrt(harmonic)
		x += weight * np.sin(phase * harmonic)
	x /= max(float(np.max(np.abs(x))), 1e-6)
	breath = bp(rng.standard_normal(len(t)), 1500, 5500)
	x = x * 0.9 + breath * np.exp(-t / 0.035) * 0.12
	envelope = np.sin(np.pi * u) ** (0.8 if event["soft"] else 0.45)
	return fade_edges(x * envelope, 0.02, 0.04).astype(np.float32)


def render_track(kind):
	rng = np.random.default_rng(SEED + 99)
	t = np.arange(FRAMES) / SR
	angle = 2 * np.pi * t / LOOP
	audio = np.zeros((FRAMES, 2), dtype=np.float32)
	for i, f in enumerate((61.3, 97.1, 193.1, 229.7, 257.3)):
		phase = round(f * LOOP) * angle + 0.9 * np.sin((i + 2) * angle)
		tone = np.sin(phase) * (0.7 + 0.3 * np.sin((i + 1) * angle))
		gain = 0.03 if kind == "lullaby" else 0.012
		audio[:, 0] += (tone * gain).astype(np.float32)
		audio[:, 1] += (np.sin(phase + 0.25) * gain).astype(np.float32)
	events = schedule_track(kind)
	for event in events:
		if event["kind"] == "vocal":
			clip = sung_syllable(event, rng)
		elif event["kind"] == "growl":
			time = t_axis(event["duration_seconds"])
			phase = 2 * np.pi * event["frequency_hz"] * time
			modulation = 0.8 + 0.7 * np.sin(2 * np.pi * (2.31 * time + time ** 2 * 0.63))
			clip = np.tanh(np.sin(phase + modulation * np.sin(phase * 2.71)) * 2.2)
			clip = fade_edges(clip * np.exp(-time / 1.2), 0.015, 0.15)
		else:
			clip = voice(event, rng)
		wrap_place(audio, clip, event["time_seconds"], event["gain"], event["pan"])
		if event["kind"] == "vocal":
			for delay, level in ((0.417, 0.35), (1.193, 0.22), (2.713, 0.12)):
				wrap_place(audio, clip, event["time_seconds"] + delay, event["gain"] * level, -event["pan"])
	dry = audio.copy()
	for delay, gain in ((0.193, 0.08), (0.731, 0.06)):
		audio += np.roll(dry[:, ::-1], round(delay * SR), axis=0) * gain
	audio -= np.mean(audio, axis=0)
	return normalize(audio, peak=0.58).astype(np.float32), events


def main():
	for kind, title, style in TRACKS:
		audio, events = render_track(kind)
		path = OUTPUT.with_name(f"club_{kind}.ogg")
		write_ogg(str(path), audio, quality=7)
		facts = measurements(decode(path))
		if facts["peak"] >= 0.7 or max(facts["seam_step_per_channel"]) >= 0.025:
			raise ValueError(f"{title} failed encoded headroom/seam validation: {facts}")
		metadata = {"title": title, "style": style, "original_procedural_audio": True,
			"external_audio_sources": [], "generator": "tools/audio/alien_club_set.py",
			"duration_seconds": LOOP, "loop": True, "rhythm": "Unequal chambers and fractional subdivisions; no global BPM or common-time grid.",
			"lyrics": {"language": "invented Narcean syllables, no canonical translation",
				"vocabulary": list(WORDS), "method": "original formant-synthesized singing/chant, no sampled singer"},
			"events": events, "validation": facts}
		path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
		print(f"CLUB_COMPOSITION: {title} / {path} / peak {facts['peak']:.4f}")


if __name__ == "__main__":
	main()
