#!/usr/bin/env python3
"""Ash Meridian sound effects, set four: B13 Undercity street detail.

Dying neon, steam vents, ceiling drips, patrol drones, fly swarms, spark showers, the
power-up wave's relays and screens booting, and hologram faults.

Usage: python3 sfx4.py [out_dir]   (default ../../assets/audio/sfx)
"""
import os
import sys
import numpy as np
from dsp import SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, fade_edges, write_ogg
from sfx import modes, burst, finish
from sfx2 import make_loop, noise, lfo

rng = np.random.default_rng(88216)


def ticks(sec, rate, lo=2000, hi=9000, decay=0.004):
	"""Random electrical ticks: sparse impulses through a bright band-pass."""
	n = int(sec * SR)
	x = np.zeros(n)
	k = int(sec * rate)
	for i in rng.integers(0, n - 200, k):
		m = min(n - i, int(0.02 * SR))
		x[i:i + m] += rng.uniform(0.3, 1.0) * rng.choice([-1, 1]) * np.exp(-np.arange(m) / (decay * SR))
	return bp(x, lo, hi)


# ---------------------------------------------------------------- loops

def neon_buzz():
	"""A failing neon tube: mains buzz rich in odd harmonics, a ballast that sags, and stray ticks."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	x = 0.6 * square(2 * np.pi * 120 * t, 0.5) + 0.3 * saw(2 * np.pi * 240 * t)
	x = bp(x, 150, 3500) * lfo(t, 0.9, 0.35) * lfo(t, 7.3, 0.12)
	x += ticks(sec + 0.3, 9) * 0.5
	return finish(make_loop(x, sec), 0.4)


def steam_hiss():
	"""A street vent: pressurised hiss that surges and gurgles."""
	sec = 3.0
	t = t_axis(sec + 0.3)
	x = bp(noise(sec + 0.3), 900, 7000) * lfo(t, 0.333, 0.45) * lfo(t, 2.1, 0.12)
	x += lp(noise(sec + 0.3), 180) * 1.5 * lfo(t, 0.666, 0.6)
	return finish(make_loop(x, sec), 0.45)


def drone_hum():
	"""Patrol drone: four detuned rotor whines beating against each other, and a servo whir."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	x = np.zeros(len(t))
	for f, a in ((211, 0.4), (213.5, 0.35), (422, 0.2), (634.5, 0.12)):
		x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6))
	x += bp(noise(sec + 0.3), 300, 1200) * 0.25 * lfo(t, 2.5, 0.5)
	x += np.sin(2 * np.pi * 1300 * t) * 0.03 * lfo(t, 0.5, 0.9)
	return finish(make_loop(x, sec), 0.45)


def fly_buzz():
	"""A swarm: dozens of wingbeats drifting in pitch, each fading in and out."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	x = np.zeros(len(t))
	for _ in range(24):
		f = rng.uniform(170, 260) * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(0.5, 3) * t + rng.uniform(0, 6)))
		ph = 2 * np.pi * np.cumsum(f) / SR
		x += saw(ph) * np.clip(np.sin(2 * np.pi * rng.uniform(0.5, 1.5) * t + rng.uniform(0, 6)), 0, 1)
	x = bp(x, 150, 2500)
	return finish(make_loop(x, sec), 0.4)


# ---------------------------------------------------------------- one-shots

def neon_crackle():
	"""A tube shorting out: arcing bursts, a pop and the buzz cutting dead."""
	sec = 0.7
	t = t_axis(sec)
	x = ticks(sec, 120, 1500, 10000, 0.003) * env_ad(len(t), 0.001, 0.35)
	x += 0.5 * square(2 * np.pi * 120 * t, 0.5) * (t < 0.25) * (np.sin(2 * np.pi * 31 * t) > 0)
	x[:int(0.03 * SR)] += burst(0.03, rng, 200, 4000, 0.01)
	return finish(fade_edges(x, 0.001, 0.05), 0.8)


def spark_crackle():
	"""A shower of sparks: dense crackle thinning out."""
	sec = 1.0
	t = t_axis(sec)
	x = ticks(sec, 300, 2500, 12000, 0.002) * np.exp(-t * 4.0)
	x += bp(noise(sec), 3000, 9000) * 0.15 * np.exp(-t * 8.0)
	return finish(fade_edges(x, 0.001, 0.05), 0.75)


def drip():
	"""One drop from the cavern roof landing in a puddle: a rising plink."""
	sec = 0.5
	t = t_axis(sec)
	x = np.sin(sweep(900, 2100, len(t))) * env_ad(len(t), 0.001, 0.06)
	x += burst(sec, rng, 2000, 6000, 0.004) * 0.2
	return finish(fade_edges(x, 0.001, 0.1), 0.6)


def drone_chirp():
	"""The drone found you: two falling scan chirps and a soft lock tone."""
	sec = 0.9
	t = t_axis(sec)
	x = np.zeros(len(t))
	for start in (0.0, 0.2):
		i = int(start * SR)
		n = int(0.14 * SR)
		x[i:i + n] += np.sin(sweep(3200, 1400, n)) * env_ad(n, 0.002, 0.1)
	i = int(0.45 * SR)
	n = len(t) - i
	x[i:] += np.sin(2 * np.pi * 880 * t[:n]) * 0.4 * env_ad(n, 0.01, 0.35) * (np.sin(2 * np.pi * 12 * t[:n]) > 0)
	return finish(fade_edges(x, 0.001, 0.05), 0.65)


def screen_boot():
	"""A giant ad screen waking: CRT thunk, rising flyback whine and a three-note chime."""
	sec = 1.6
	t = t_axis(sec)
	x = burst(sec, rng, 60, 600, 0.06) * 0.8
	x += np.sin(sweep(3000, 15000, len(t))) * 0.08 * env_ad(len(t), 0.2, 1.0)
	for k, f in enumerate((523.0, 659.0, 466.0)):
		i = int((0.5 + k * 0.22) * SR)
		n = len(t) - i
		x[i:] += np.sin(2 * np.pi * f * t[:n]) * 0.3 * env_ad(n, 0.004, 0.4)
	return finish(fade_edges(x, 0.001, 0.1), 0.7)


def relay_clunk():
	"""A district relay closing as the power wave arrives: heavy clunk and a hum swell."""
	sec = 1.2
	t = t_axis(sec)
	x = burst(sec, rng, 40, 900, 0.05) * 1.2
	x += modes([180, 431, 997], [0.2, 0.1, 0.05], sec, rng, [1, 0.5, 0.3]) * 0.4
	x += np.sin(2 * np.pi * 60 * t) * 0.4 * env_ad(len(t), 0.15, 0.9)
	return finish(fade_edges(x, 0.001, 0.1), 0.8)


def holo_glitch():
	"""A hologram tearing: bit-crushed stutter and a pitch drop."""
	sec = 0.4
	t = t_axis(sec)
	x = np.sin(sweep(1800, 300, len(t))) * (np.sin(2 * np.pi * 40 * t) > 0)
	x = np.round(x * 4) / 4 + bp(noise(sec), 2000, 8000) * 0.2
	x *= env_ad(len(t), 0.002, 0.3)
	return finish(fade_edges(x, 0.001, 0.04), 0.55)


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'assets', 'audio', 'sfx')
	jobs = [
		('neon_buzz', neon_buzz, None), ('steam_hiss', steam_hiss, None),
		('drone_hum', drone_hum, None), ('fly_buzz', fly_buzz, None),
		('neon_crackle', neon_crackle, '30 50 60'), ('spark_crackle', spark_crackle, '30 50 60'),
		('drip', drip, '70 30 100'), ('drone_chirp', drone_chirp, '40 40 80'),
		('screen_boot', screen_boot, '50 40 100'), ('relay_clunk', relay_clunk, '60 40 100'),
		('holo_glitch', holo_glitch, '30 50 60'),
	]
	for name, fn, rv in jobs:
		write_ogg(os.path.join(out, name + '.ogg'), fn(), 5, rv, 1.2 if rv else 0.8)
		print('  ', name)
	print('wrote', len(jobs), 'files to', os.path.normpath(out))


if __name__ == '__main__':
	main()
