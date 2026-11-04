#!/usr/bin/env python3
"""B13 Undercity music: 'Undercity Lullaby'. An original piece in a 70s Italian horror prog style.

6/8, eighth = 0.21 s, bar = 1.26 s, 108 bars (~2:16), seamless loop (tail folded into the head).

  A   bars   0-15  music box over a descending chromatic line, drone, whispers
  B   bars  16-39  + plucked bass, tabla-like hand drums, bouzouki tremolo
  C   bars  40-55  breakdown: tolling bells, heartbeat, warped music box, whispers
  D   bars  56-79  prog burst: overdriven organ, gliding ladder-filter lead, drum kit
  E   bars  80-95  B again with the lead answering softly
  F   bars  96-107 music box alone, thinning back toward the top

Usage: python3 music_undercity.py [out.ogg]   (default ../../assets/audio/music/undercity_dark.ogg)
"""
import os
import subprocess
import sys
import tempfile
import numpy as np
import scipy.io.wavfile as wavfile
from scipy import signal
from dsp import SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, sweep_lp, place, normalize, fade_edges, write_ogg

E8 = 0.21
BAR = E8 * 6
BARS = 108
LOOP = BARS * BAR
rng = np.random.default_rng(1977)


def mtof(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def at(bar, eighth=0.0):
	return bar * BAR + eighth * E8


# ---------------------------------------------------------------- instruments

_cache = {}


def music_box(m, warp=0.0):
	key = ('mb', m, round(warp, 2))
	if key not in _cache:
		f = mtof(m)
		sec = 2.4
		t = t_axis(sec)
		drift = 1 + warp * 0.03 * np.sin(2 * np.pi * 0.7 * t)
		ph = 2 * np.pi * f * np.cumsum(drift) / SR
		tone = np.sin(ph + 1.1 * np.exp(-t / 0.08) * np.sin(3.0 * ph))
		tone += 0.35 * np.sin(5.4 * ph) * np.exp(-t / 0.12) + 0.18 * np.sin(8.9 * ph) * np.exp(-t / 0.05)
		tone += 0.5 * np.sin(ph * 1.0035)
		_cache[key] = fade_edges(tone * env_ad(len(t), 0.002, 0.9), 0.0, 0.3)
	return _cache[key]


def pluck(m, bright=0.5, decay=0.996, sec=1.6):
	key = ('ks', m, bright, decay, sec)
	if key not in _cache:
		f = mtof(m)
		n = int(sec * SR)
		N = int(SR / f)
		exc = np.zeros(n)
		burst = rng.uniform(-1, 1, N)
		exc[:N] = lp(burst, 800 + 7000 * bright)
		a = np.zeros(N + 2)
		a[0] = 1.0
		a[N] = -0.5 * decay
		a[N + 1] = -0.5 * decay
		y = signal.lfilter([1.0], a, exc)
		_cache[key] = fade_edges(y / (np.max(np.abs(y)) + 1e-9), 0.0, 0.2)
	return _cache[key]


def bass(m, sec):
	n = int(sec * SR)
	f = mtof(m)
	ph = 2 * np.pi * f * np.arange(n) / SR
	x = saw(ph) * 0.6 + square(ph * 0.5) * 0.3 + np.sin(ph) * 0.6
	x = sweep_lp(x, 180 + 1400 * np.exp(-np.arange(n) / SR / 0.09), 1.4)
	return fade_edges(np.tanh(x * 1.6) * env_ad(n, 0.004, sec * 0.7), 0.0, 0.03)


def tabla(kind):
	key = ('tb', kind)
	if key not in _cache:
		n = int(0.7 * SR)
		t = np.arange(n) / SR
		if kind == 'ge':
			f = 85 * (1 + 0.55 * (1 - np.exp(-t / 0.12)))
			x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.28)
			x += lp(rng.standard_normal(n), 400) * np.exp(-t / 0.01) * 0.3
		elif kind == 'na':
			f0 = 392
			x = sum(a * np.sin(2 * np.pi * f0 * k * t) * np.exp(-t / d) for k, a, d in ((1, 1, 0.35), (2, 0.6, 0.25), (3, 0.4, 0.15), (4, 0.25, 0.08)))
			x += bp(rng.standard_normal(n), 2000, 6000) * np.exp(-t / 0.004) * 0.6
		elif kind == 'tin':
			x = np.sin(2 * np.pi * 392 * t) * np.exp(-t / 0.06) + bp(rng.standard_normal(n), 1500, 5000) * np.exp(-t / 0.006) * 0.5
		else:
			x = bp(rng.standard_normal(n), 800, 4000) * np.exp(-t / 0.012) + np.sin(2 * np.pi * 300 * t) * np.exp(-t / 0.02) * 0.4
		_cache[key] = fade_edges(x / np.max(np.abs(x)), 0.0, 0.1)
	return _cache[key]


def kick():
	n = int(0.5 * SR)
	t = np.arange(n) / SR
	x = np.sin(sweep(130, 42, n)) * np.exp(-t / 0.22) + hp(rng.standard_normal(n), 2000) * np.exp(-t / 0.003) * 0.3
	return fade_edges(np.tanh(x * 1.8), 0.0, 0.05)


def snare():
	n = int(0.4 * SR)
	t = np.arange(n) / SR
	x = bp(rng.standard_normal(n), 900, 9000) * np.exp(-t / 0.09) * 0.9 + np.sin(sweep(230, 180, n)) * np.exp(-t / 0.06) * 0.7
	return fade_edges(np.tanh(x * 1.5), 0.0, 0.05)


def hat(open_=False):
	n = int((0.35 if open_ else 0.08) * SR)
	t = np.arange(n) / SR
	return fade_edges(hp(rng.standard_normal(n), 7000) * np.exp(-t / (0.12 if open_ else 0.02)), 0.0, 0.02)


def tom(m):
	n = int(0.6 * SR)
	t = np.arange(n) / SR
	f = mtof(m)
	return fade_edges(np.sin(sweep(f * 1.5, f, n)) * np.exp(-t / 0.25) + lp(rng.standard_normal(n), 800) * np.exp(-t / 0.02) * 0.3, 0.0, 0.05)


def organ_chord(notes, sec):
	n = int(sec * SR)
	t = np.arange(n) / SR
	x = np.zeros(n)
	for m in notes:
		f = mtof(m)
		for h, a in ((0.5, 0.6), (1, 1.0), (2, 0.7), (3, 0.45), (4, 0.35), (6, 0.2), (8, 0.15)):
			x += a * np.sin(2 * np.pi * f * h * t + rng.uniform(0, 6.28))
	x *= 1 + 0.25 * np.sin(2 * np.pi * 6.2 * t)
	x = np.tanh(x * 0.7) * 0.8
	x = lp(x, 4200)
	return fade_edges(x * np.clip(t / 0.01, 0, 1) * np.clip((sec - t) / 0.06, 0, 1), 0.0, 0.02)


def bell_toll(m):
	key = ('bell', m)
	if key not in _cache:
		f = mtof(m)
		sec = 6.0
		t = t_axis(sec)
		x = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d) for r, a, d in ((0.5, 0.7, 4.0), (1, 1, 3.0), (1.19, 0.6, 2.2), (1.5, 0.4, 1.8), (2.0, 0.5, 1.5), (2.74, 0.35, 0.9), (4.07, 0.2, 0.5)))
		_cache[key] = fade_edges(x / np.max(np.abs(x)), 0.0, 1.0)
	return _cache[key]


def whisper(sec):
	n = int(sec * SR)
	t = np.arange(n) / SR
	src = rng.standard_normal(n)
	syll = int(rng.integers(3, 6))
	envl = np.zeros(n)
	pos = 0.0
	for k in range(syll):
		d = sec / syll * rng.uniform(0.6, 1.1)
		s = int(pos * SR)
		m = min(n - s, int(d * SR))
		if m > 10:
			envl[s:s + m] += np.sin(np.linspace(0, np.pi, m)) ** 1.5 * rng.uniform(0.5, 1.0)
		pos += sec / syll
	formants = rng.choice([(300, 870, 2250), (530, 1840, 2480), (270, 2290, 3010), (570, 840, 2410), (440, 1020, 2240)], size=syll)
	out = np.zeros(n)
	for k in range(syll):
		s = int(k * n / syll)
		e = int((k + 1) * n / syll)
		seg = src[s:e]
		v = sum(bp(seg, f * 0.85, f * 1.15) * g for f, g in zip(formants[k], (1.0, 0.7, 0.4)))
		out[s:e] = v
	out += lp(hp(src, 4500), 9000) * 0.18
	return fade_edges(out * envl, 0.01, 0.1)


def drone(sec):
	n = int(sec * SR)
	t = np.arange(n) / SR
	x = np.zeros(n)
	for m, a in ((33, 1.0), (40, 0.6), (45, 0.4), (46, 0.12)):
		for det in (-0.12, 0.0, 0.11):
			x += a * saw(2 * np.pi * mtof(m + det) * t + rng.uniform(0, 6.28))
	cutoff = 260 + 180 * np.sin(2 * np.pi * t / 17.0) + 120 * np.sin(2 * np.pi * t / 7.3)
	return sweep_lp(x, cutoff, 1.2) * 0.15


def choir(notes, sec):
	n = int(sec * SR)
	t = np.arange(n) / SR
	x = np.zeros(n)
	for m in notes:
		for det in (-0.15, -0.05, 0.06, 0.14):
			x += saw(2 * np.pi * mtof(m + det) * t * (1 + 0.004 * np.sin(2 * np.pi * 5.1 * t + det * 40)))
	v = bp(x, 280, 340) * 1.0 + bp(x, 600, 900) * 0.6 + bp(x, 2300, 2700) * 0.25
	return v * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.25


def lead_line(events, total):
	"""events: (start_s, dur_s, midi). Continuous saw pair with glide, vibrato and per-note filter swell."""
	n = int(total * SR)
	freq = np.zeros(n)
	amp = np.zeros(n)
	cut = np.full(n, 300.0)
	last = None
	for s, d, m in events:
		i = int(s * SR)
		j = min(n, int((s + d) * SR))
		if j <= i:
			continue
		f = mtof(m)
		k = np.arange(j - i) / SR
		start = f if last is None else last
		g = f + (start - f) * np.exp(-k / 0.035)
		vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * k) * np.clip((k - 0.2) / 0.3, 0, 1)
		freq[i:j] = g * vib
		amp[i:j] = np.clip(k / 0.01, 0, 1) * np.clip((d - k) / 0.04, 0, 1)
		cut[i:j] = 500 + 3400 * np.exp(-k / 0.25) + 600 * np.clip(k / 1.0, 0, 1)
		last = f
	freq[freq == 0] = 220
	ph = 2 * np.pi * np.cumsum(freq) / SR
	x = saw(ph) + saw(ph * 1.004) * 0.8 + square(ph * 0.5, 0.45) * 0.3
	y = sweep_lp(x * amp, cut, 2.2)
	return np.tanh(y * 1.3) * 0.5


# ---------------------------------------------------------------- score

LINE = [57, 56, 55, 54, 53, 52, 53, 52]
ROOT = [45, 44, 43, 42, 41, 40, 41, 40]


def mb_bar(b):
	k = b % 8
	low = LINE[k] + 12
	sixth = 70 if k >= 6 else 71
	return [low, 76, 81, 84, sixth + 12, 81]


def sec_of(b):
	if b < 16:
		return 'A'
	if b < 40:
		return 'B'
	if b < 56:
		return 'C'
	if b < 80:
		return 'D'
	if b < 96:
		return 'E'
	return 'F'


def render():
	total = LOOP + 8.0
	n = int(total * SR)
	big = np.zeros((n, 2))
	mid = np.zeros((n, 2))
	dry = np.zeros((n, 2))

	dr = drone(total)
	denv = np.ones(n)
	tt = np.arange(n) / SR
	denv *= 0.4 + 0.6 * np.clip((tt - at(16)) / 4, 0, 1) * np.clip((at(96) + 6 - tt) / 6, 0, 1)
	place(mid, dr * denv, 0, 0.38)

	for b in range(BARS):
		s = sec_of(b)
		notes = mb_bar(b)
		mb_gain = {'A': 0.32, 'B': 0.26, 'C': 0.22, 'D': 0.1, 'E': 0.24, 'F': 0.3}[s]
		if s == 'F':
			mb_gain *= 1 - 0.5 * (b - 96) / 12
		warp = 1.0 if s == 'C' else 0.0
		for e, m in enumerate(notes):
			if s == 'C' and rng.uniform() < 0.25:
				continue
			place(big, music_box(m, warp), at(b, e) + rng.uniform(-0.004, 0.004), mb_gain * (1.0 if e == 0 else 0.8), (e - 2.5) * 0.12)

		if s in ('B', 'E', 'D'):
			r = ROOT[b % 8] - 12 if s != 'D' else [45, 45, 46, 46, 43, 43, 40, 40][b % 8] - 12
			for e, dm, dur in ((0, 0, 2.6), (3, 0, 1.2), (4, 7, 1.2), (5, 12, 0.9)):
				place(mid, bass(r + dm, dur * E8), at(b, e), 0.42 if s != 'D' else 0.5)

		if s in ('B', 'E'):
			for e, kind, g in ((0, 'ge', 1.0), (1.5, 'na', 0.5), (2, 'tin', 0.4), (3, 'ge', 0.7), (3.5, 'te', 0.3), (4, 'na', 0.6), (5, 'te', 0.3), (5.5, 'te', 0.25)):
				place(mid, tabla(kind), at(b, e) + rng.uniform(-0.006, 0.006), 0.28 * g * rng.uniform(0.85, 1.1), -0.25 if kind == 'ge' else 0.3)
			chord = [LINE[b % 8] + 12, 64, 69]
			for q in range(12):
				m = chord[(q // 2) % 3]
				place(mid, pluck(m, 0.6, 0.994, 0.6), at(b, q * 0.5), 0.06 * (1.2 if q % 2 == 0 else 0.8), 0.45)
				place(mid, pluck(m + 12, 0.7, 0.99, 0.4), at(b, q * 0.5) + 0.003, 0.03, 0.55)

		if s == 'C':
			if b % 4 == 0:
				place(big, bell_toll(33 if b % 8 == 0 else 34), at(b), 0.32, 0.0)
			for e in (0, 0.55, 3, 3.55):
				place(mid, kick(), at(b, e), 0.22 if e in (0, 3) else 0.14)
			if b % 2 == 1:
				place(big, choir([57, 60, 63] if b % 4 == 1 else [56, 59, 62], 2 * BAR), at(b), 0.5)

		if s == 'D':
			chords = [[57, 60, 64, 69], [57, 60, 64, 69], [58, 62, 65, 70], [58, 62, 65, 70], [55, 58, 62, 67], [55, 58, 62, 67], [56, 59, 62, 64, 65], [56, 59, 62, 64, 65]]
			ch = chords[b % 8]
			for e, dur in ((0, 2.5), (3, 1.4), (4.5, 1.4)):
				place(mid, organ_chord(ch, dur * E8), at(b, e), 0.16, -0.2)
			place(mid, kick(), at(b, 0), 0.5)
			place(mid, kick(), at(b, 2.5), 0.3)
			place(mid, snare(), at(b, 3), 0.42, 0.05)
			for e in range(6):
				place(mid, hat(e == 5 and b % 2 == 1), at(b, e), 0.13 if e % 3 == 0 else 0.08, 0.35)
			if b % 8 == 7:
				for q, m in enumerate((50, 47, 43, 40)):
					place(mid, tom(m), at(b, 3 + q * 0.75), 0.35, 0.4 - q * 0.25)

		if s in ('A', 'C', 'F') and rng.uniform() < 0.33:
			place(big, whisper(rng.uniform(0.9, 1.7)), at(b, rng.uniform(0, 4)), 0.18, rng.uniform(-0.9, 0.9))

	phrase = [(0, 3, 76), (3, 3, 77), (6, 2, 76), (8, 1, 74), (9, 3, 72), (12, 6, 71),
		(18, 2, 72), (20, 1, 74), (21, 3, 76), (24, 6, 81), (30, 3, 80), (33, 3, 77),
		(36, 4, 76), (40, 1, 74), (41, 1, 72), (42, 3, 71), (45, 3, 68)]
	events = []
	for rep in range(3):
		b0 = 56 + rep * 8
		for e, d, m in phrase:
			mm = m + (12 if rep == 2 and e >= 24 else 0)
			events.append((at(b0, e), d * E8 * 0.95, mm))
	for rep in range(2):
		b0 = 82 + rep * 8
		for e, d, m in phrase[:6]:
			events.append((at(b0, e + 24), d * E8 * 0.95, m - 12))
	ln = lead_line(events, total)
	lenv = np.where(tt < at(80), 1.0, 0.45)
	place(mid, ln * lenv, 0, 0.34, 0.15)

	big = reverb(big, '80 35 100 100 25')
	mid = reverb(mid, '35 50 70 80 5')
	mix = big + mid + dry
	head = int(8.0 * SR)
	loop_n = int(LOOP * SR)
	out = mix[:loop_n].copy()
	tail = mix[loop_n:loop_n + head]
	out[:len(tail)] += tail
	sg = {'A': 0.42, 'B': 0.62, 'C': 0.6, 'D': 1.0, 'E': 0.62, 'F': 0.42}
	pts = [at(b) for b in range(BARS)] + [at(BARS)]
	vals = [sg[sec_of(b)] for b in range(BARS)] + [sg['A']]
	gain = np.interp(np.arange(loop_n) / SR, pts, vals)
	cs = np.cumsum(np.pad(gain, SR, mode='edge'))
	gain = (cs[2 * SR:] - cs[:-2 * SR])[:loop_n] / (2 * SR)
	out *= gain[:, None]
	out = np.tanh(out * 1.2) / 1.2
	return normalize(out, 0.9)


def reverb(x, args):
	with tempfile.TemporaryDirectory() as d:
		a = os.path.join(d, 'a.wav')
		b = os.path.join(d, 'b.wav')
		peak = np.max(np.abs(x)) + 1e-9
		wavfile.write(a, SR, (x / peak * 0.5).astype(np.float32))
		subprocess.run(['sox', a, '-e', 'floating-point', b, 'reverb'] + args.split(), check=True)
		_, y = wavfile.read(b)
	return y[:len(x)].astype(np.float64) * peak / 0.5


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'assets', 'audio', 'music', 'undercity_dark.ogg')
	write_ogg(out, render(), 6)
	print('wrote', os.path.normpath(out), '%.1f s' % LOOP)


if __name__ == '__main__':
	main()
