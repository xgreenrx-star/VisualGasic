#!/usr/bin/env python3
"""Ash Meridian sound effects, set two: vehicles, machines, weapons, the ship and interaction cues.

Loops (*_loop, holo_hum, alien_murmur) are cross-faded into themselves so they repeat without a seam;
the game sets stream.loop at runtime. Everything leans eerie: detuned, inharmonic, a little wrong.

Usage: python3 sfx2.py [out_dir]   (default ../../assets/audio/sfx)
"""
import os
import sys
import numpy as np
from dsp import SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, sweep_lp, fade_edges, write_ogg
from sfx import modes, burst, thud, finish, finish_loop, ramp_np

rng = np.random.default_rng(4242)


def make_loop(x, sec, xf=0.25):
	"""x must be at least sec + xf long. The tail past sec is faded over the head."""
	n = int(sec * SR)
	k = int(xf * SR)
	out = x[:n].copy()
	w = np.linspace(0, 1, k)
	if out.ndim == 2:
		w = w[:, None]
	out[:k] = out[:k] * w + x[n:n + k] * (1 - w)
	return out


def noise(sec):
	return rng.standard_normal(int(sec * SR))


def lfo(t, hz, depth, phase=0.0):
	return 1 + depth * np.sin(2 * np.pi * hz * t + phase)


# ---------------------------------------------------------------- vehicles

def buggy_motor():
	"""Electric drive at cruise: inverter whine with PWM sidebands, gear mesh, tyre hiss. Pitched by speed in game."""
	sec = 2.0
	t = t_axis(sec + 0.3)
	f = 180.0 * lfo(t, 1.5, 0.004)
	ph = 2 * np.pi * np.cumsum(f) / SR
	whine = np.sin(ph) + 0.5 * np.sin(2 * ph + 0.3) + 0.3 * np.sin(3.01 * ph) + 0.22 * np.sin(5.03 * ph)
	pwm = 0.18 * np.sin(ph * 7.5) * np.sin(2 * np.pi * 3.5 * t)
	gear = 0.35 * saw(ph * 0.25) * lfo(t, 6.0, 0.3)
	hiss = bp(noise(sec + 0.3), 1800, 6000) * 0.12 * lfo(t, 0.5, 0.2)
	rumble = lp(noise(sec + 0.3), 90) * 1.4
	x = 0.5 * whine + pwm + lp(gear, 900) + hiss + rumble
	return finish_loop(make_loop(x, sec), 0.7)


def vehicle_on():
	"""Power-on chirp: a capacitor bank charging up into the motor whine."""
	sec = 1.4
	t = t_axis(sec)
	ph = sweep(60, 360, len(t))
	x = (np.sin(ph) + 0.4 * np.sin(2.01 * ph) + 0.2 * square(ph * 0.5, 0.3)) * ramp_np(t, 0, 0.08) * np.exp(-np.maximum(t - 0.9, 0) / 0.18)
	x += 0.5 * modes([1120, 2410], [0.05, 0.03], sec, rng) * 0.6
	return finish(fade_edges(x, 0.002, 0.05), 0.8)


def train_loop():
	"""Train passing at speed: traction hum, a falling inverter scale, wheel-flange squeal and rail joints."""
	sec = 4.0
	n = int((sec + 0.4) * SR)
	t = np.arange(n) / SR
	hum = np.sin(2 * np.pi * 50 * t) + 0.6 * np.sin(2 * np.pi * 100 * t) + 0.3 * np.sin(2 * np.pi * 150.5 * t)
	inv = np.sin(2 * np.pi * 410 * t * (1 + 0.003 * np.sin(2 * np.pi * 0.25 * t))) * 0.25
	inv += np.sin(2 * np.pi * 547 * t) * 0.12
	squeal = bp(noise(sec + 0.4), 3100, 3400, 3) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.37 * t) ** 8) * 1.4
	roar = lp(noise(sec + 0.4), 400) * 1.8 + bp(noise(sec + 0.4), 600, 2500) * 0.25
	x = 0.35 * hum + inv + squeal + roar
	for c in (0.1, 0.32, 2.1, 2.32):
		for off in (0.0, sec):
			i = int((c + off) * SR)
			if i < n:
				clack = thud(0.25, 140, 60, 0.05) + modes([620, 1430, 2210], [0.04, 0.03, 0.02], 0.25, rng) * 0.4
				x[i:i + len(clack)] += clack[:n - i] * 1.6
	return finish_loop(make_loop(x, sec, 0.3), 0.75)


def train_horn():
	"""Dissonant two-tone horn: a minor second and a tritone that never resolve."""
	sec = 2.6
	t = t_axis(sec)
	x = np.zeros(len(t))
	for f, g in ((233.1, 1.0), (246.9, 0.8), (329.6, 0.6), (349.2, 0.45)):
		ph = 2 * np.pi * f * t * (1 - 0.012 * ramp_np(t, 1.8, 2.6))
		x += g * saw(ph)
	x = lp(x, 2200) * ramp_np(t, 0, 0.12) * (1 - ramp_np(t, 1.9, 2.6))
	return finish(fade_edges(x, 0.002, 0.05), 0.85)


def train_doors():
	sec = 1.8
	t = t_axis(sec)
	x = bp(noise(sec), 300, 4000) * env_ad(len(t), 0.02, 0.35) * 0.6
	x += lp(noise(sec), 300) * ramp_np(t, 0.05, 0.2) * (1 - ramp_np(t, 0.9, 1.1)) * 1.2
	i = int(1.05 * SR)
	clunk = thud(0.5, 110, 45, 0.09) + modes([380, 910], [0.08, 0.05], 0.5, rng) * 0.5
	x[i:i + len(clunk)] += clunk[:len(x) - i]
	ph = 2 * np.pi * np.cumsum(np.where(t < 0.5, 660.0, 523.0)) / SR
	x += 0.25 * np.sin(ph) * (t < 0.9) * (1 - ramp_np(t, 0.8, 0.9))
	return finish(fade_edges(x, 0.002, 0.08), 0.8)


# ---------------------------------------------------------------- holograms

def holo_hum():
	"""Projector hum: mains buzz, a shimmering detuned cluster and soft crackle."""
	sec = 3.0
	t = t_axis(sec + 0.3)
	buzz = sum(np.sin(2 * np.pi * 60 * k * t) / k for k in range(1, 9))
	buzz = lp(buzz, 600) * 0.6
	shimmer = np.zeros(len(t))
	for f in (1318.5, 1323.9, 1975.5, 2793.0):
		shimmer += np.sin(2 * np.pi * f * t) * lfo(t, 0.33 + f / 9000, 0.6)
	shimmer *= 0.05
	crack = (rng.uniform(size=len(t)) > 0.99975) * rng.uniform(-1, 1, len(t))
	crack = bp(crack, 1500, 7000) * 3
	x = buzz * lfo(t, 7.1, 0.12) + shimmer + crack
	return finish_loop(make_loop(x, sec), 0.6)


def _glottal(f0, n):
	ph = np.cumsum(f0) / SR
	frac = ph % 1.0
	pulse = np.where(frac < 0.4, np.sin(np.pi * frac / 0.4) ** 2, 0.0)
	return np.diff(pulse, prepend=0) * 40


def alien_murmur():
	"""Soft, low, breathy gibberish in a drifting pitch, formants that don't belong to a human mouth."""
	sec = 9.0
	n = int((sec + 0.4) * SR)
	t = np.arange(n) / SR
	f0 = 92 * (1 + 0.08 * np.sin(2 * np.pi * 0.21 * t) + 0.03 * np.sin(2 * np.pi * 1.7 * t))
	src = _glottal(f0, n) * 0.6 + bp(rng.standard_normal(n), 300, 5000) * 0.35
	vowels = [(310, 870, 2250, 3300), (650, 1080, 2650, 3500), (420, 1900, 2500, 3900), (500, 700, 2900, 4100), (280, 2300, 3000, 4200), (720, 1250, 2400, 3600)]
	out = np.zeros(n)
	pos = 0.0
	k = 0
	while pos < sec + 0.4:
		dur = rng.uniform(0.16, 0.42)
		gap = rng.uniform(0.02, 0.12) if rng.uniform() < 0.8 else rng.uniform(0.4, 0.9)
		a = int(pos * SR)
		b = min(n, int((pos + dur) * SR))
		if b > a:
			seg = src[a:b]
			v = vowels[rng.integers(len(vowels))]
			y = np.zeros(b - a)
			for j, fm in enumerate(v):
				y += bp(seg, fm * 0.92, fm * 1.08, 2) * (1.0, 0.7, 0.35, 0.2)[j]
			e = np.sin(np.pi * np.linspace(0, 1, b - a)) ** 0.7
			out[a:b] += y * e
		pos += dur + gap
		k += 1
	ring = np.sin(2 * np.pi * 31 * t)
	out = out * (0.85 + 0.15 * ring)
	out = hp(out, 120)
	return finish_loop(make_loop(out, sec, 0.4), 0.55)


# ---------------------------------------------------------------- weapons and damage

def turret_lock():
	"""Target lock: a rising charge whine with a stuttering tick."""
	sec = 1.1
	t = t_axis(sec)
	ph = sweep(300, 1900, len(t))
	x = (np.sin(ph) + 0.3 * np.sin(1.5 * ph)) * ramp_np(t, 0, 0.9) * (1 - ramp_np(t, 1.0, 1.1))
	x *= 0.7 + 0.3 * square(2 * np.pi * 14 * t)
	return finish(fade_edges(x, 0.002, 0.03), 0.7)


def turret_fire():
	"""Heavy turret beam: a falling FM zap over a sub thump and a hiss tail."""
	sec = 0.9
	t = t_axis(sec)
	ph = sweep(2400, 140, len(t))
	x = np.sin(ph + 3.0 * np.exp(-t / 0.1) * np.sin(ph * 2.7)) * env_ad(len(t), 0.001, 0.22)
	x += thud(sec, 90, 35, 0.12) * 1.2
	x += bp(noise(sec), 2000, 9000) * env_ad(len(t), 0.001, 0.08) * 0.5
	return finish(fade_edges(x, 0.0005, 0.05), 0.92)


def ship_laser():
	"""The ship's own guns: a brighter, quicker pew-pew with a metallic ring."""
	sec = 0.45
	t = t_axis(sec)
	ph = sweep(3300, 420, len(t))
	x = np.sin(ph + 1.6 * np.sin(ph * 1.41)) * env_ad(len(t), 0.0008, 0.09)
	x += modes([2960, 4410], [0.04, 0.02], sec, rng) * 0.25
	return finish(fade_edges(x, 0.0005, 0.03), 0.8)


def laser_hit():
	"""Beam striking metal near you: sizzle and a clang."""
	sec = 0.7
	t = t_axis(sec)
	x = bp(noise(sec), 1500, 8000) * env_ad(len(t), 0.001, 0.12) * 0.8
	x += modes([410, 1220, 1870, 3015], [0.2, 0.12, 0.08, 0.05], sec, rng) * 0.6
	x += thud(sec, 120, 45, 0.08)
	return finish(fade_edges(x, 0.0005, 0.04), 0.85)


def hull_hit():
	"""Your hull taking a shot: a deep metallic bang plus electrical static."""
	sec = 1.2
	t = t_axis(sec)
	x = modes([97, 233, 415, 702, 1150], [0.6, 0.4, 0.3, 0.2, 0.12], sec, rng) * 0.9
	x += thud(sec, 70, 30, 0.2) * 1.5
	st = bp(noise(sec), 2500, 9000) * (rng.uniform(size=len(t)) > 0.6) * env_ad(len(t), 0.001, 0.35) * 0.6
	return finish(fade_edges(x + st, 0.0005, 0.08), 0.92)


def hurt():
	"""Suit breach: a crunch and two dissonant warning blips."""
	sec = 0.9
	t = t_axis(sec)
	x = np.tanh(lp(noise(sec), 1200) * 4) * env_ad(len(t), 0.001, 0.07) * 0.8
	x += thud(sec, 80, 40, 0.1)
	for at, f in ((0.12, 880), (0.32, 831)):
		m = (t >= at) & (t < at + 0.14)
		x += m * 0.35 * square(2 * np.pi * f * t, 0.25) * np.exp(-np.maximum(t - at, 0) / 0.08)
	return finish(fade_edges(lp(x, 5000), 0.0005, 0.05), 0.85)


# ---------------------------------------------------------------- ship

def ship_ignite():
	"""Main engine light-off: igniter clicks, a turbine spool climbing through a tritone, then the roar."""
	sec = 6.0
	t = t_axis(sec)
	x = np.zeros(len(t))
	for at in (0.0, 0.18, 0.31, 0.62):
		i = int(at * SR)
		c = modes([2400, 5100], [0.01, 0.006], 0.1, rng) + burst(0.1, rng, 2000, 9000, 0.008)
		x[i:i + len(c)] += c * 0.6
	ph = sweep(70, 520, len(t))
	spool = (np.sin(ph) + 0.4 * np.sin(1.414 * ph) + 0.25 * np.sin(2.0 * ph)) * ramp_np(t, 0.6, 2.5)
	roar = sweep_lp(noise(sec), 300 + 1200 * ramp_np(t, 1.5, 4.5), 0.8) * ramp_np(t, 1.2, 3.5) * 3.0
	roar += hp(lp(noise(sec), 5000), 1500) * ramp_np(t, 2.5, 4.0) * 0.35
	x += spool * 0.45 + roar
	i = int(2.4 * SR)
	boom = thud(1.6, 60, 22, 0.5) * 2.0
	x[i:i + len(boom)] += boom[:len(x) - i]
	x *= 1 - ramp_np(t, 5.0, 6.0)
	return finish(fade_edges(x, 0.001, 0.1), 0.95)


def ship_engine_loop():
	"""Cruise drone for the flight: two detuned turbines beating against a sub roar."""
	sec = 4.0
	t = t_axis(sec + 0.3)
	x = np.zeros(len(t))
	for f, g in ((55, 0.7), (82.4, 0.4), (110.8, 0.35), (164.0, 0.15)):
		x += g * saw(2 * np.pi * f * t)
	x = lp(x, 500) * lfo(t, 0.5, 0.15)
	x += np.sin(2 * np.pi * 737 * t) * 0.06 + np.sin(2 * np.pi * 741 * t) * 0.06
	x += lp(noise(sec + 0.3), 250) * 2.2 + bp(noise(sec + 0.3), 900, 3000) * 0.12
	return finish_loop(make_loop(x, sec, 0.3), 0.75)


# ---------------------------------------------------------------- interaction

def pickup():
	"""Item recovered: a cold three-note bell figure (minor ninth) with a shimmer tail."""
	sec = 1.6
	t = t_axis(sec)
	x = np.zeros(len(t))
	for at, f in ((0.0, 659.3), (0.09, 987.8), (0.18, 698.5)):
		i = int(at * SR)
		b = modes([f, f * 2.76, f * 5.4], [0.6, 0.25, 0.1], sec - at, rng, [1.0, 0.4, 0.2], 0.0)
		x[i:i + len(b)] += b[:len(x) - i]
	return finish(fade_edges(x, 0.001, 0.1), 0.75)


def hack_tick():
	sec = 0.08
	t = t_axis(sec)
	x = np.sin(2 * np.pi * 1760 * t + 2 * np.sin(2 * np.pi * 2490 * t)) * env_ad(len(t), 0.0005, 0.015)
	return finish(fade_edges(x, 0.0005, 0.01), 0.5)


def hack_ok():
	"""Lock coupling accepted: a falling arpeggio that ends on an unresolved chord."""
	sec = 1.4
	t = t_axis(sec)
	x = np.zeros(len(t))
	for k, f in enumerate((1568, 1175, 932, 740, 622)):
		i = int(k * 0.06 * SR)
		b = modes([f, f * 3.01], [0.5, 0.15], sec - k * 0.06, rng, [1.0, 0.3], 0.0)
		x[i:i + len(b)] += b[:len(x) - i] * 0.7
	x += lp(noise(sec), 200) * env_ad(len(t), 0.01, 0.2) * 0.8
	return finish(fade_edges(x, 0.001, 0.1), 0.75)


def hack_fail():
	"""Lock bites back: an electrical snap and a falling buzz."""
	sec = 0.7
	t = t_axis(sec)
	ph = sweep(420, 90, len(t))
	x = square(ph, 0.3) * env_ad(len(t), 0.001, 0.25) * 0.5
	x += bp(noise(sec), 1000, 8000) * env_ad(len(t), 0.0005, 0.05) * 1.2
	return finish(fade_edges(lp(x, 4500), 0.0005, 0.04), 0.85)


def gate_open():
	"""Heavy Narcean door: seal pop, pneumatic hiss, a long grinding slide and a clunk."""
	sec = 2.6
	t = t_axis(sec)
	x = burst(sec, rng, 800, 9000, 0.25) * 0.7
	grind = bp(noise(sec), 120, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t)) * ramp_np(t, 0.2, 0.4) * (1 - ramp_np(t, 1.9, 2.1))
	ph = sweep(55, 48, len(t))
	x += grind * 1.0 + 0.4 * saw(ph) * ramp_np(t, 0.2, 0.4) * (1 - ramp_np(t, 1.9, 2.1))
	i = int(2.05 * SR)
	c = thud(0.55, 90, 35, 0.12) * 1.4 + modes([310, 760], [0.1, 0.06], 0.55, rng) * 0.4
	x[i:i + len(c)] += c[:len(x) - i]
	return finish(fade_edges(lp(x, 6000), 0.001, 0.05), 0.85)


def jetpack_loop():
	"""Thrust: a rough rocket hiss with a fluttering low burble."""
	sec = 1.5
	t = t_axis(sec + 0.25)
	x = bp(noise(sec + 0.25), 300, 5000) * 0.6 + lp(noise(sec + 0.25), 180) * 2.5
	x *= lfo(t, 18.0, 0.25) * lfo(t, 2.0, 0.1)
	return finish_loop(make_loop(x, sec, 0.25), 0.7)


def land():
	sec = 0.45
	x = thud(sec, 110, 40, 0.08) * 1.4 + burst(sec, rng, 200, 2500, 0.05) * 0.4
	return finish(fade_edges(x, 0.0005, 0.04), 0.8)


def term_key():
	"""Alien terminal key: a glassy two-partial blip in an odd ratio."""
	sec = 0.12
	t = t_axis(sec)
	f = rng.uniform(1300, 1500)
	x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.37 * t)) * env_ad(len(t), 0.0005, 0.03)
	return finish(fade_edges(x, 0.0005, 0.01), 0.45)


def term_reply():
	"""The terminal answering: a burst of random tones like data being spoken."""
	sec = 1.0
	t = t_axis(sec)
	x = np.zeros(len(t))
	for k in range(14):
		at = k * 0.065
		f = 400 * 2 ** (rng.integers(0, 22) / 12)
		m = (t >= at) & (t < at + 0.05)
		x += m * np.sin(2 * np.pi * f * t) * 0.5
	return finish(fade_edges(lp(x, 5000), 0.001, 0.05), 0.55)


def warp():
	"""Gravity flip / portal: a reversed swell into a sub drop."""
	sec = 1.5
	t = t_axis(sec)
	ph = sweep(80, 1800, len(t))
	x = np.sin(ph + 2 * np.sin(ph * 0.5)) * ramp_np(t, 0, 1.0) ** 2 * (1 - ramp_np(t, 1.0, 1.08))
	i = int(1.0 * SR)
	d = thud(0.5, 90, 25, 0.2) * 1.5
	x[i:i + len(d)] += d[:len(x) - i]
	return finish(fade_edges(x, 0.002, 0.05), 0.85)


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'assets', 'audio', 'sfx')
	jobs = [
		('buggy_motor', buggy_motor, None), ('vehicle_on', vehicle_on, None),
		('train_loop', train_loop, None), ('train_horn', train_horn, '40 50 90'), ('train_doors', train_doors, '25 50 50'),
		('holo_hum', holo_hum, None), ('alien_murmur', alien_murmur, None),
		('turret_lock', turret_lock, None), ('turret_fire', turret_fire, '30 50 80'), ('ship_laser', ship_laser, None),
		('laser_hit', laser_hit, '20 50 50'), ('hull_hit', hull_hit, None), ('hurt', hurt, None),
		('ship_ignite', ship_ignite, '30 50 100'), ('ship_engine_loop', ship_engine_loop, None),
		('pickup', pickup, '40 40 70'), ('hack_tick', hack_tick, None), ('hack_ok', hack_ok, '30 40 60'),
		('hack_fail', hack_fail, None), ('gate_open', gate_open, '30 50 70'), ('jetpack_loop', jetpack_loop, None),
		('land', land, None), ('term_key', term_key, None), ('term_reply', term_reply, '20 40 40'), ('warp', warp, '50 40 90'),
	]
	for name, fn, rv in jobs:
		write_ogg(os.path.join(out, name + '.ogg'), fn(), 5, rv, 1.2 if rv else 0.8)
		print('  ', name)
	print('wrote', len(jobs), 'files to', os.path.normpath(out))


if __name__ == '__main__':
	main()
