#!/usr/bin/env python3
"""Ash Meridian sound effects, set three: the vehicle layer.

The buggy (and the hacked Narcean groundcars) are mixed from several loops and one-shots at runtime:
idle hum + load whine (buggy_motor, set two) or coast whine, a tyre bed per surface, a skid squeal,
and one-shots for braking, bumps, stutters, shut-down and turret interference.

Usage: python3 sfx3.py [out_dir]   (default ../../assets/audio/sfx)
"""
import os
import sys
import numpy as np
from dsp import SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, fade_edges, write_ogg
from sfx import modes, burst, thud, finish, finish_loop, ramp_np
from sfx2 import make_loop, noise, lfo

rng = np.random.default_rng(7331)


# ---------------------------------------------------------------- motor loops

def buggy_idle():
	"""Standstill: a thin capacitor-bank whine with a slow, uneasy beat and contactor buzz."""
	sec = 3.0
	t = t_axis(sec + 0.3)
	x = np.sin(2 * np.pi * 2310 * t) * 0.18 + np.sin(2 * np.pi * 2317.5 * t) * 0.14
	x += np.sin(2 * np.pi * 120 * t) * 0.35 + 0.15 * square(2 * np.pi * 60 * t, 0.2)
	x = lp(x, 3000)
	x += bp(noise(sec + 0.3), 4000, 7000) * 0.03 * lfo(t, 0.31, 0.6)
	x *= lfo(t, 0.66, 0.12)
	return finish_loop(make_loop(x, sec), 0.45)


def buggy_coast():
	"""Off-throttle: the same drive whine, softer and hollow, with a faint regen hiss and freewheel tick."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	f = 180.0 * lfo(t, 0.9, 0.006)
	ph = 2 * np.pi * np.cumsum(f) / SR
	whine = np.sin(ph) + 0.25 * np.sin(2 * ph + 0.7) + 0.18 * np.sin(3.98 * ph)
	tick = (np.sin(ph * 0.125) > 0.995).astype(float)
	tick = lp(tick, 2500) * 3.0
	hiss = bp(noise(sec + 0.3), 2500, 5500) * 0.05
	x = lp(0.5 * whine, 1400) + tick + hiss + lp(noise(sec + 0.3), 70) * 0.6
	return finish_loop(make_loop(x, sec), 0.5)


def car_motor():
	"""Narcean groundcar under load: a low ring-modulated throb with a glassy, wrong overtone."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	f = 92.0 * lfo(t, 1.0, 0.01)
	ph = 2 * np.pi * np.cumsum(f) / SR
	body = np.sin(ph) + 0.6 * np.sin(1.5 * ph + 0.2) + 0.35 * np.sin(2.76 * ph)
	ring = np.sin(ph * 6.13) * np.sin(2 * np.pi * 7.0 * t) * 0.3
	glass = np.sin(ph * 13.7) * 0.08 * lfo(t, 0.5, 0.5)
	x = lp(body * 0.5 + ring, 1800) + glass + lp(noise(sec + 0.3), 110) * 1.1
	return finish_loop(make_loop(x, sec), 0.7)


def car_idle():
	"""Groundcar idle: a breathing sub hum with a choir-like shimmer far above it."""
	sec = 3.0
	t = t_axis(sec + 0.3)
	x = np.sin(2 * np.pi * 46 * t) * 0.5 * lfo(t, 0.5, 0.3) + np.sin(2 * np.pi * 69.3 * t) * 0.2
	for f, a in ((1395, 0.05), (1402, 0.05), (2093, 0.03)):
		x += np.sin(2 * np.pi * f * t) * a * lfo(t, 0.17, 0.8, f)
	return finish_loop(make_loop(x, sec), 0.45)


# ---------------------------------------------------------------- tyres

def tyre_gravel():
	"""Rolling on yard grit: crunchy granular noise with random stone pings."""
	sec = 2.0
	n = int((sec + 0.3) * SR)
	x = bp(noise(sec + 0.3), 300, 3500) * 0.25
	grains = (rng.uniform(size=n) > 0.9985).astype(float) * rng.uniform(0.3, 1.0, n)
	x += bp(grains, 1500, 6000, 2) * 6.0
	x += lp(noise(sec + 0.3), 160) * 0.8
	x *= lfo(np.arange(n) / SR, 3.1, 0.2)
	return finish_loop(make_loop(x, sec), 0.6)


def tyre_smooth():
	"""Undercity street: a smooth tyre hiss with a soft tread hum."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	x = bp(noise(sec + 0.3), 600, 4500) * 0.35 + lp(noise(sec + 0.3), 220) * 0.6
	x += np.sin(2 * np.pi * 210 * t) * 0.05
	return finish_loop(make_loop(x, sec), 0.5)


def tyre_hollow():
	"""Slab over a tunnel: a boomy resonant rumble with expansion-joint knocks."""
	sec = 2.4
	n = int((sec + 0.3) * SR)
	t = np.arange(n) / SR
	x = lp(noise(sec + 0.3), 140) * 1.4 + bp(noise(sec + 0.3), 70, 110, 3) * 2.0
	x += bp(noise(sec + 0.3), 600, 3000) * 0.12
	for c in (0.35, 1.55):
		for off in (0.0, sec):
			i = int((c + off) * SR)
			if i < n:
				k = thud(0.35, 90, 45, 0.09) + modes([210, 480], [0.08, 0.05], 0.35, rng) * 0.3
				m = min(len(k), n - i)
				x[i:i + m] += k[:m] * 1.5
	return finish_loop(make_loop(x, sec), 0.7)


def tyre_skid():
	"""Hard cornering: a wavering tyre squeal over scrub noise."""
	sec = 1.6
	t = t_axis(sec + 0.3)
	f = 980.0 * lfo(t, 5.3, 0.03) * lfo(t, 0.7, 0.02)
	ph = 2 * np.pi * np.cumsum(f) / SR
	sq = np.sin(ph) + 0.5 * np.sin(2.01 * ph) + 0.25 * np.sin(3.03 * ph)
	sq *= 0.6 + 0.4 * lfo(t, 11.0, 0.5)
	scrub = bp(noise(sec + 0.3), 1200, 5000) * 0.5
	return finish_loop(make_loop(0.35 * sq + scrub, sec), 0.6)


# ---------------------------------------------------------------- one-shots

def regen_brake():
	"""Regenerative braking: the whine falls away while the cells crackle as they soak up charge."""
	sec = 1.3
	t = t_axis(sec)
	ph = sweep(420, 70, len(t))
	x = (np.sin(ph) + 0.4 * np.sin(2.02 * ph) + 0.2 * np.sin(3.1 * ph)) * env_ad(len(t), 0.01, 0.55)
	cr = bp(noise(sec), 2500, 8000) * (rng.uniform(size=len(t)) > 0.97) * env_ad(len(t), 0.05, 0.4) * 2.0
	return finish(fade_edges(x + cr, 0.003, 0.1), 0.6)


def buggy_thump():
	"""Suspension bottoming out / collision: a dull chassis thud with a sheet-metal rattle."""
	sec = 0.7
	x = thud(sec, 110, 38, 0.12) * 1.4 + burst(sec, rng, 120, 900, 0.05) * 0.5
	x += modes([187, 341, 622, 977], [0.18, 0.12, 0.08, 0.05], sec, rng, [1, 0.6, 0.4, 0.25]) * 0.45
	return finish(x, 0.9)


def buggy_knock():
	"""Small rock under a tyre: a short clunk for gravel at speed."""
	sec = 0.25
	x = thud(sec, 160, 70, 0.03) + burst(sec, rng, 400, 2500, 0.015) * 0.6
	return finish(x, 0.6)


def motor_pop():
	"""Failing motor: an electrical pop, a short arc and the drive dropping out."""
	sec = 0.6
	t = t_axis(sec)
	x = burst(sec, rng, 200, 9000, 0.012) * 1.5
	arc = bp(noise(sec), 3000, 9000) * (np.sin(2 * np.pi * 120 * t) > 0.6) * env_ad(len(t), 0.001, 0.12)
	sag = np.sin(sweep(180, 90, len(t))) * env_ad(len(t), 0.002, 0.2) * 0.6
	return finish(x + arc + sag, 0.75)


def vehicle_off():
	"""Shut-down: the whine spins down into silence, then a contactor relay clacks open."""
	sec = 1.6
	t = t_axis(sec)
	ph = sweep(360, 40, len(t))
	x = (np.sin(ph) + 0.4 * np.sin(2.01 * ph)) * (1 - ramp_np(t, 0.0, 1.1)) ** 1.5 * 0.8
	i = int(1.18 * SR)
	click = burst(0.2, rng, 1500, 7000, 0.006) + thud(0.2, 300, 150, 0.015) * 0.6
	x[i:i + len(click)] += click[:len(x) - i] * 1.2
	return finish(fade_edges(x, 0.002, 0.05), 0.7)


def car_start():
	"""Groundcar wakes: three falling glass chimes in an alien mode, over a rising sub swell."""
	sec = 2.2
	t = t_axis(sec)
	x = np.sin(sweep(30, 92, len(t))) * ramp_np(t, 0, 0.9) * (1 - ramp_np(t, 1.6, 2.2)) * 0.5
	for k, (at, f) in enumerate(((0.0, 1661), (0.22, 1244), (0.44, 1397))):
		i = int(at * SR)
		c = modes([f, f * 2.71, f * 4.13], [0.7, 0.35, 0.2], sec - at, rng, [1, 0.35, 0.15], 0.01)
		x[i:] += c * 0.5
	return finish(fade_edges(x, 0.002, 0.1), 0.7)


def car_off():
	"""Groundcar sleeps: the sub sinks away and a single detuned chime answers."""
	sec = 1.8
	t = t_axis(sec)
	x = np.sin(sweep(92, 25, len(t))) * (1 - ramp_np(t, 0, 1.2)) * 0.6
	i = int(0.5 * SR)
	x[i:] += modes([1108, 1114, 3020], [0.6, 0.6, 0.2], sec - 0.5, rng, [1, 0.8, 0.2], 0.0) * 0.4
	return finish(fade_edges(x, 0.002, 0.1), 0.6)


def motor_interference():
	"""Turret lock bleeding into the buggy's electronics: dropout static and a tuning-sweep squeal."""
	sec = 0.9
	t = t_axis(sec)
	gate = (rng.uniform(size=len(t)) > 0.5) * (np.sin(2 * np.pi * 23 * t) > -0.2)
	x = bp(noise(sec), 1500, 9000) * gate * 0.8
	x += np.sin(sweep(2600, 900, len(t))) * 0.25 * (np.sin(2 * np.pi * 9 * t) > 0)
	x *= env_ad(len(t), 0.005, 0.45)
	return finish(fade_edges(x, 0.001, 0.05), 0.7)


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'assets', 'audio', 'sfx')
	jobs = [
		('buggy_idle', buggy_idle, None), ('buggy_coast', buggy_coast, None),
		('car_motor', car_motor, None), ('car_idle', car_idle, None),
		('tyre_gravel', tyre_gravel, None), ('tyre_smooth', tyre_smooth, None),
		('tyre_hollow', tyre_hollow, None), ('tyre_skid', tyre_skid, None),
		('regen_brake', regen_brake, None), ('buggy_thump', buggy_thump, None), ('buggy_knock', buggy_knock, None),
		('motor_pop', motor_pop, None), ('vehicle_off', vehicle_off, None),
		('car_start', car_start, '40 40 80'), ('car_off', car_off, '40 40 80'),
		('motor_interference', motor_interference, None),
	]
	for name, fn, rv in jobs:
		write_ogg(os.path.join(out, name + '.ogg'), fn(), 5, rv, 1.2 if rv else 0.8)
		print('  ', name)
	print('wrote', len(jobs), 'files to', os.path.normpath(out))


if __name__ == '__main__':
	main()
