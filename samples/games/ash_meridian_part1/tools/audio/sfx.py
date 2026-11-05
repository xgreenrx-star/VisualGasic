#!/usr/bin/env python3
"""Ash Meridian sound effects. Every sound is synthesised here; rerun to regenerate.

  step_metal_1..4     deep-stratum grating: heel thud, toe clank, rattle
  step_concrete_1..4  yard / undercity streets: soft thud, grit scuff
  step_tile_1..4      buildings and lift car: hard click with a short body
  key_press           alien keypad blip
  key_accept          three-note rising bell (code accepted)
  key_reject          low double buzz (code refused)
  lift_doors          pneumatic hiss, door motor, end clunk
  lift_motor          car travel (4 s): cable hum spinning up and down, floor whooshes
  lift_chime          arrival bell
  lever_pull          ratchet, clunk, electrical arc
  grid_powerup        undercity power transfer (stereo, 7 s): swell, relay cascade, hum, neon strike

Usage: python3 sfx.py [out_dir]   (default ../../assets/audio/sfx)
"""
import os
import sys
import numpy as np
from dsp import (SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, fm_bell, place,
	normalize, fade_edges, write_ogg)


def modes(freqs, decays, sec, rng, amps=None, jitter=0.04):
	t = t_axis(sec)
	out = np.zeros(len(t))
	for k, (f, d) in enumerate(zip(freqs, decays)):
		f *= 1 + rng.uniform(-jitter, jitter)
		a = 1.0 if amps is None else amps[k]
		out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
	return fade_edges(out, 0.0, sec * 0.2)


def burst(sec, rng, lo, hi, decay, attack=0.001):
	n = int(sec * SR)
	return fade_edges(bp(rng.standard_normal(n), lo, hi) * env_ad(n, attack, decay), 0.0, sec * 0.2)


def thud(sec, f0, f1, decay):
	n = int(sec * SR)
	return fade_edges(np.sin(sweep(f0, f1, n)) * env_ad(n, 0.002, decay), 0.0, sec * 0.2)


def step_metal(rng):
	sec = 0.32
	x = np.zeros(int(sec * SR))
	heel = thud(0.12, 140, 70, 0.03) * 0.8 + burst(0.12, rng, 200, 900, 0.02) * 0.6
	toe = modes([480, 1260, 2150, 3380, 4720], [0.09, 0.07, 0.05, 0.035, 0.02], 0.25, rng, [1, 0.7, 0.5, 0.35, 0.2], 0.06)
	toe += burst(0.25, rng, 2500, 7000, 0.012) * 0.8
	rattle = np.zeros(int(0.2 * SR))
	for k in range(int(rng.integers(3, 6))):
		place_mono(rattle, burst(0.03, rng, 1800, 5200, 0.004), rng.uniform(0.01, 0.15), rng.uniform(0.15, 0.35))
	place_mono(x, heel, 0.0, 1.0)
	place_mono(x, toe, rng.uniform(0.03, 0.05), 0.45)
	place_mono(x, rattle, 0.05, 1.0)
	return finish(x, 0.55)


def step_concrete(rng):
	sec = 0.26
	x = np.zeros(int(sec * SR))
	body = burst(0.16, rng, 90, 700, 0.025) * 1.2 + thud(0.16, 110, 60, 0.02) * 0.6
	scuff = hp(rng.standard_normal(int(0.14 * SR)), 1800) * env_ad(int(0.14 * SR), 0.008, 0.018) * 0.1
	grit = np.zeros(int(0.12 * SR))
	for k in range(int(rng.integers(5, 10))):
		grit[int(rng.uniform(0, len(grit) - 1))] += rng.uniform(-0.6, 0.6)
	grit = hp(grit, 3000)
	place_mono(x, body, 0.0, 1.0)
	place_mono(x, scuff, rng.uniform(0.02, 0.04), 1.0)
	place_mono(x, grit, 0.01, 1.0)
	return finish(x, 0.5)


def step_tile(rng):
	sec = 0.22
	x = np.zeros(int(sec * SR))
	click = burst(0.06, rng, 1400, 5000, 0.006) * 1.0
	body = modes([210, 640, 1150], [0.03, 0.02, 0.015], 0.12, rng, [1, 0.5, 0.3]) * 0.5
	place_mono(x, body, 0.0, 1.0)
	place_mono(x, click, 0.0, 0.8)
	place_mono(x, burst(0.05, rng, 1800, 4500, 0.004) * 0.4, rng.uniform(0.035, 0.05), 1.0)
	return finish(x, 0.5)


def place_mono(buf, clip, at, gain):
	i = int(at * SR)
	j = min(len(buf), i + len(clip))
	buf[i:j] += clip[:j - i] * gain


def finish(x, peak):
	return fade_edges(normalize(x, peak), 0.0005, 0.02)


def finish_loop(x, peak):
	"""Loops are already cross-faded into themselves; an edge fade would dip to silence on every repeat."""
	return normalize(x, peak)


def key_press():
	n = int(0.11 * SR)
	tone = square(sweep(1500, 980, n), 0.3) * env_ad(n, 0.001, 0.03)
	tone = lp(tone, 4500) * 0.5 + np.sin(sweep(3000, 1960, n)) * env_ad(n, 0.0005, 0.015) * 0.4
	rng = np.random.default_rng(3)
	tone[:int(0.006 * SR)] += hp(rng.standard_normal(int(0.006 * SR)), 3000) * 0.4
	return finish(tone, 0.6)


def key_accept():
	sec = 0.9
	x = np.zeros(int(sec * SR))
	for k, f in enumerate([659.3, 987.8, 1318.5]):
		place_mono(x, fm_bell(f, 0.7, 2.0, 1.4, 0.45, 0.12), k * 0.075, 0.5 - k * 0.08)
	return finish(x, 0.7)


def key_reject():
	sec = 0.5
	x = np.zeros(int(sec * SR))
	for k in range(2):
		n = int(0.14 * SR)
		buzz = lp(square(sweep(150, 138, n)) + 0.5 * saw(sweep(151.5, 139, n)), 1400) * env_ad(n, 0.003, 0.2)
		buzz *= np.clip((0.14 - np.arange(n) / SR) * 60, 0, 1)
		place_mono(x, buzz, k * 0.19, 0.6)
	return finish(x, 0.65)


def lift_doors():
	rng = np.random.default_rng(11)
	sec = 1.1
	n = int(sec * SR)
	t = t_axis(sec)
	hiss = bp(rng.standard_normal(n), 1500, 7000) * np.clip(t / 0.05, 0, 1) * np.exp(-t / 0.35) * 0.5
	whine = (saw(sweep(180, 320, n)) * 0.3 + np.sin(sweep(360, 640, n)) * 0.3)
	whine = lp(whine, 1800) * np.clip(t / 0.08, 0, 1) * np.clip((0.75 - t) / 0.1, 0, 1) * 0.35
	x = hiss + whine
	clunk = thud(0.35, 120, 45, 0.08) * 0.9 + modes([340, 910, 1720], [0.12, 0.08, 0.05], 0.35, rng, [0.6, 0.4, 0.25])
	place_mono(x, clunk, 0.72, 1.0)
	return finish(x, 0.75)


def lift_motor():
	rng = np.random.default_rng(12)
	sec = 4.2
	n = int(sec * SR)
	t = t_axis(sec)
	speed = np.clip(t / 0.9, 0, 1) ** 1.5 * np.clip((sec - 0.15 - t) / 0.8, 0, 1)
	f = 46 + 26 * speed
	ph = 2 * np.pi * np.cumsum(f) / SR
	hum = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph + 0.4) + 0.15 * saw(4 * ph)
	hum = lp(hum, 900) * (0.25 + 0.75 * speed)
	cable = bp(rng.standard_normal(n), 300, 2400) * (0.06 + 0.25 * speed) * (1 + 0.5 * np.sin(2 * np.pi * 7.3 * t))
	x = hum * 0.6 + cable
	for k, at in enumerate([1.1, 1.75, 2.4, 3.0]):
		w = bp(rng.standard_normal(int(0.5 * SR)), 250, 1600) * np.hanning(int(0.5 * SR)) * 0.5
		place_mono(x, w, at, speed[int(at * SR)])
		place_mono(x, modes([780, 1900], [0.04, 0.03], 0.1, rng, [0.25, 0.15]), at + 0.25, speed[int(at * SR)])
	return fade_edges(normalize(x, 0.6), 0.05, 0.15)


def lift_chime():
	sec = 1.8
	x = np.zeros(int(sec * SR))
	place_mono(x, fm_bell(784.0, 1.6, 1.41, 1.6, 1.1, 0.25), 0.0, 0.55)
	place_mono(x, fm_bell(587.3, 1.4, 1.41, 1.6, 1.0, 0.25), 0.28, 0.5)
	return finish(x, 0.7)


def lever_pull():
	rng = np.random.default_rng(21)
	sec = 1.6
	x = np.zeros(int(sec * SR))
	at = 0.0
	for k in range(7):
		place_mono(x, modes([1450, 2900, 4100], [0.02, 0.012, 0.008], 0.06, rng, [0.5, 0.35, 0.2]) + burst(0.06, rng, 2000, 6000, 0.004) * 0.4, at, 0.5)
		at += 0.085 - k * 0.007
	clunk = thud(0.5, 95, 38, 0.11) * 1.1 + modes([220, 530, 1210, 2050], [0.25, 0.16, 0.09, 0.05], 0.5, rng, [0.7, 0.5, 0.35, 0.2])
	place_mono(x, clunk, at + 0.02, 1.0)
	arc_n = int(0.55 * SR)
	gate = (rng.uniform(0, 1, arc_n // 240 + 1) > 0.45).repeat(240)[:arc_n]
	arc = bp(rng.standard_normal(arc_n), 2500, 9000) * gate * np.exp(-np.arange(arc_n) / SR / 0.2)
	arc += np.sin(2 * np.pi * 120 * np.arange(arc_n) / SR) * gate * 0.3 * np.exp(-np.arange(arc_n) / SR / 0.15)
	place_mono(x, arc, at + 0.06, 0.45)
	return finish(x, 0.8)


def grid_powerup():
	rng = np.random.default_rng(31)
	sec = 7.5
	n = int(sec * SR)
	t = t_axis(sec)
	x = np.zeros((n, 2))
	swell = np.clip(t / 2.6, 0, 1) ** 2
	sub = np.sin(sweep(28, 55, n)) * swell * np.exp(-np.maximum(t - 3.0, 0) / 2.0)
	place(x, sub, 0, 0.7)
	for k in range(14):
		at = 0.4 + 2.1 * (k / 14) ** 0.8 + rng.uniform(-0.03, 0.03)
		relay = modes([900, 2300, 3700], [0.04, 0.025, 0.015], 0.12, rng, [0.6, 0.4, 0.25]) + burst(0.12, rng, 1500, 6000, 0.006) * 0.5
		place(x, relay, at, 0.28 * (0.6 + 0.4 * k / 14), rng.uniform(-0.9, 0.9))
	hum_env = ramp_np(t, 2.3, 3.4) * (0.75 + 0.25 * np.exp(-np.maximum(t - 3.0, 0) / 0.6)) * ramp_down(t, 6.0, 7.5)
	hf = 50 + 50 * ramp_np(t, 2.4, 3.6)
	hph = 2 * np.pi * np.cumsum(hf) / SR
	hum = lp(np.sin(hph) + 0.5 * np.sin(2 * hph) + 0.35 * saw(3 * hph) + 0.2 * square(6 * hph, 0.4), 2200) * hum_env
	place(x, hum, 0, 0.35)
	boom = thud(3.0, 70, 28, 0.9) + lp(rng.standard_normal(int(3.0 * SR)), 180) * env_ad(int(3.0 * SR), 0.01, 0.6) * 0.5
	place(x, boom, 2.85, 0.9)
	for k in range(6):
		at = 3.1 + k * 0.28 + rng.uniform(0, 0.15)
		m = int(0.45 * SR)
		flick = (rng.uniform(0, 1, m // 360 + 1) > 0.4).repeat(360)[:m] * np.minimum(1, np.arange(m) / SR * 5 + 0.2)
		buzz = hp(saw(2 * np.pi * 120 * np.arange(m) / SR) + 0.3 * rng.standard_normal(m), 600) * flick
		ping = np.sin(2 * np.pi * rng.uniform(2400, 4200) * np.arange(m) / SR) * np.exp(-np.arange(m) / SR / 0.08)
		place(x, fade_edges((buzz * 0.25 + ping * 0.25) * np.exp(-np.arange(m) / SR / 0.6), 0.002, 0.12), at, 0.5, rng.uniform(-0.85, 0.85))
	tail = bp(rng.standard_normal(n), 400, 3000) * ramp_np(t, 3.0, 3.6) * ramp_down(t, 4.5, 7.4) * 0.05
	place(x, tail, 0, 1.0, 0.3)
	return fade_edges(normalize(x, 0.85), 0.01, 0.3)


def ramp_np(t, a, b):
	return np.clip((t - a) / (b - a), 0, 1)


def ramp_down(t, a, b):
	return 1 - np.clip((t - a) / (b - a), 0, 1)


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'assets', 'audio', 'sfx')
	for k in range(4):
		write_ogg(os.path.join(out, 'step_metal_%d.ogg' % (k + 1)), step_metal(np.random.default_rng(100 + k)), 5)
		write_ogg(os.path.join(out, 'step_concrete_%d.ogg' % (k + 1)), step_concrete(np.random.default_rng(200 + k)), 5)
		write_ogg(os.path.join(out, 'step_tile_%d.ogg' % (k + 1)), step_tile(np.random.default_rng(300 + k)), 5)
	write_ogg(os.path.join(out, 'key_press.ogg'), key_press(), 5)
	write_ogg(os.path.join(out, 'key_accept.ogg'), key_accept(), 5, '25 50 40')
	write_ogg(os.path.join(out, 'key_reject.ogg'), key_reject(), 5)
	write_ogg(os.path.join(out, 'lift_doors.ogg'), lift_doors(), 5, '20 60 40')
	write_ogg(os.path.join(out, 'lift_motor.ogg'), lift_motor(), 5)
	write_ogg(os.path.join(out, 'lift_chime.ogg'), lift_chime(), 5, '35 40 60')
	write_ogg(os.path.join(out, 'lever_pull.ogg'), lever_pull(), 5, '30 50 70')
	write_ogg(os.path.join(out, 'grid_powerup.ogg'), grid_powerup(), 6, '60 40 100', 2.0)
	print('wrote', len(os.listdir(out)), 'files to', os.path.normpath(out))


if __name__ == '__main__':
	main()
