#!/usr/bin/env python3
"""More Ash Meridian music: four original pieces in the same 70s Italian horror-prog vein as 'Undercity Lullaby'.

  yard_dread    Backlight Yard and the surface. 4/4 at 76 bpm, D Phrygian. Muted synth-bass ostinato, organ,
                celesta tritones, heartbeat kick, tolling bells.                              32 bars, ~101 s
  stratum_deep  The maintenance floors. No meter to speak of: an E drone, scraped metal, choir swells,
                bells at irregular times, a broken music box very far away.                 26 bars, ~104 s
  chase         Escapes (awakening, trace cycle, yard turrets). 7/8, eighth = 0.13 s. Driving bass in 2+2+3,
                kit, organ stabs, gliding lead.                                             80 bars, ~73 s
  black_channel The flight. 120 bpm sixteenth-note sequencer in C minor over a pumping bass, choir pads
                and a lead that climbs and never resolves.                                  48 bars, 96 s

Every track is rendered with its reverb tail folded into the head, so it loops without a seam.

Usage: python3 music2.py [name ...]   (default: all four, into ../../assets/audio/music/)
"""
import os
import sys
import numpy as np
from dsp import SR, t_axis, lp, hp, bp, env_ad, sweep, saw, square, sweep_lp, place, normalize, fade_edges, write_ogg
import music_undercity as mu
from music_undercity import mtof, music_box, pluck, bass, kick, snare, hat, tom, organ_chord, bell_toll, whisper, choir, lead_line, reverb

rng = np.random.default_rng(1980)


# ---------------------------------------------------------------- extra instruments

def drone_at(root, sec, spread=(0, 7, 12, 13)):
	n = int(sec * SR)
	t = np.arange(n) / SR
	x = np.zeros(n)
	for k, iv in enumerate(spread):
		a = (1.0, 0.6, 0.4, 0.12)[k % 4]
		for det in (-0.12, 0.0, 0.11):
			x += a * saw(2 * np.pi * mtof(root + iv + det) * t + rng.uniform(0, 6.28))
	cutoff = 240 + 170 * np.sin(2 * np.pi * t / 19.0) + 110 * np.sin(2 * np.pi * t / 6.9)
	return sweep_lp(x, cutoff, 1.2) * 0.15


def scrape(sec):
	"""Bowed sheet metal: resonant noise gliding through a narrow band."""
	n = int(sec * SR)
	t = np.arange(n) / SR
	f0 = rng.uniform(300, 700)
	cut = f0 * (1 + 0.6 * np.sin(np.pi * t / sec)) * (1 + 0.05 * np.sin(2 * np.pi * 3.3 * t))
	x = sweep_lp(rng.standard_normal(n), cut, 9.0)
	x = hp(x, 150)
	return fade_edges(x / (np.max(np.abs(x)) + 1e-9) * np.sin(np.pi * t / sec) ** 2, 0.01, 0.2)


_arp = {}


def arp_note(m, sec):
	key = (m, round(sec, 3))
	if key not in _arp:
		n = int(sec * SR)
		k = np.arange(n) / SR
		ph = 2 * np.pi * mtof(m) * k
		x = saw(ph) + saw(ph * 1.006) * 0.7 + square(ph * 0.5, 0.4) * 0.25
		x = sweep_lp(x, 400 + 3200 * np.exp(-k / 0.05), 3.0)
		_arp[key] = fade_edges(np.tanh(x * 1.2) * env_ad(n, 0.002, sec * 0.6), 0.0, 0.01)
	return _arp[key]


def stab(notes, sec):
	return organ_chord(notes, sec) * env_ad(int(sec * SR), 0.003, sec * 0.5)


def heartbeat():
	return np.concatenate([kick() * 0.9, np.zeros(int(0.02 * SR))])


# ---------------------------------------------------------------- common mixdown

def mixdown(big, mid, loop_sec, gain_pts, big_rv='80 35 100 100 25', mid_rv='35 50 70 80 5', drive=1.2):
	big = reverb(big, big_rv)
	mid = reverb(mid, mid_rv)
	mix = big + mid
	loop_n = int(loop_sec * SR)
	out = mix[:loop_n].copy()
	tail = mix[loop_n:]
	out[:len(tail)] += tail[:loop_n]
	ts, vs = zip(*gain_pts)
	gain = np.interp(np.arange(loop_n) / SR, ts, vs)
	cs = np.cumsum(np.pad(gain, SR, mode='edge'))
	gain = (cs[2 * SR:] - cs[:-2 * SR])[:loop_n] / (2 * SR)
	out *= gain[:, None]
	out = np.tanh(out * drive) / drive
	return normalize(out, 0.9)


def buffers(total):
	n = int(total * SR)
	return np.zeros((n, 2)), np.zeros((n, 2)), n


# ---------------------------------------------------------------- yard_dread

def yard_dread():
	beat = 60 / 76
	bar = beat * 4
	bars = 32
	loop = bars * bar
	total = loop + 8.0
	big, mid, n = buffers(total)
	at = lambda b, q=0.0: b * bar + q * beat
	place(mid, drone_at(26, total, (0, 7, 12, 13)), 0, 0.3)
	roots = [38, 38, 39, 39, 34, 34, 33, 33]
	pads = [[50, 53, 57], [50, 53, 57], [51, 55, 58], [51, 55, 58], [46, 50, 53], [46, 50, 53], [45, 49, 52, 55], [45, 49, 52, 58]]
	ost = [0, 0, 12, 0, 1, 0, -2, 0]
	motif = [(0, 74), (1.5, 80), (2.0, 79), (3.0, 74), (4.5, 73), (5.0, 74), (6.5, 68), (7.0, 69)]
	for b in range(bars):
		sec = 'A' if b < 8 else 'B' if b < 16 else 'C' if b < 24 else 'D'
		r = roots[b % 8]
		if sec != 'A' or b >= 4:
			for e in range(8):
				place(mid, bass(r - 12 + ost[e], beat * 0.45), at(b, e * 0.5), 0.36 if e % 2 == 0 else 0.26)
		if b % 2 == 0:
			place(big, organ_chord(pads[b % 8], bar * 2), at(b), 0.09 if sec in ('A', 'D') else 0.13, -0.2)
		if sec in ('B', 'C', 'D') and b % 2 == 0:
			for q, m in motif:
				if sec == 'D' and rng.uniform() < 0.35:
					continue
				place(big, music_box(m, 1.0 if sec == 'D' else 0.0), at(b, q) + rng.uniform(-0.005, 0.005), 0.26, rng.uniform(-0.4, 0.4))
		for q in (0, 0.35):
			place(mid, heartbeat(), at(b, q), 0.28 if sec != 'C' else 0.36)
		if sec == 'C':
			place(mid, kick(), at(b, 2), 0.3)
			place(mid, snare(), at(b, 2), 0.3, 0.05)
			for e in range(8):
				place(mid, hat(e == 7), at(b, e * 0.5), 0.07, 0.35)
			if b % 4 == 3:
				for q, m in enumerate((45, 43, 40, 38)):
					place(mid, tom(m), at(b, 2 + q * 0.5), 0.3, 0.4 - q * 0.25)
		if b % 8 == 0:
			place(big, bell_toll(26 if b % 16 == 0 else 27), at(b), 0.3)
		if rng.uniform() < 0.3:
			place(big, whisper(rng.uniform(0.9, 1.8)), at(b, rng.uniform(0, 3)), 0.16, rng.uniform(-0.9, 0.9))
	phrase = [(0, 3, 62), (3, 1, 63), (4, 2, 62), (6, 2, 60), (8, 4, 58), (12, 3, 57), (15, 1, 58), (16, 6, 56), (22, 2, 57)]
	events = []
	for rep in range(2):
		b0 = 16 + rep * 4
		for q, d, m in phrase:
			events.append((at(b0, q * 0.5), d * beat * 0.5 * 0.95, m + 12))
	place(mid, lead_line(events, total), 0, 0.28, 0.15)
	g = {'A': 0.68, 'B': 0.75, 'C': 1.0, 'D': 0.6}
	pts = [(at(b), g['A' if b < 8 else 'B' if b < 16 else 'C' if b < 24 else 'D']) for b in range(bars)] + [(loop, g['A'])]
	return mixdown(big, mid, loop, pts), loop


# ---------------------------------------------------------------- stratum_deep

def stratum_deep():
	bar = 4.0
	bars = 26
	loop = bars * bar
	total = loop + 9.0
	big, mid, n = buffers(total)
	t = np.arange(n) / SR
	d = drone_at(28, total, (0, 6, 12, 19))
	place(mid, d * (0.75 + 0.25 * np.sin(2 * np.pi * t / loop))[:len(d)], 0, 0.42)
	sub = np.sin(2 * np.pi * 41.2 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0)) ** 3
	place(mid, sub, 0, 0.18)
	pos = 1.0
	while pos < loop - 4:
		place(big, scrape(rng.uniform(2.5, 5.5)), pos, 0.24, rng.uniform(-0.8, 0.8))
		pos += rng.uniform(5, 11)
	for at_s, m in ((2.0, 40), (19.0, 41), (38.0, 40), (53.0, 34), (71.0, 40), (88.0, 41)):
		place(big, bell_toll(m), at_s, 0.32, rng.uniform(-0.3, 0.3))
	for at_s, ch in ((12.0, [52, 55, 58]), (44.0, [53, 56, 59]), (76.0, [52, 55, 58, 63])):
		place(big, choir(ch, 14.0), at_s, 0.55)
	frag = [76, 75, 72, 71, 70, 67]
	for b0 in (6, 15, 22):
		for k, m in enumerate(frag[:int(rng.integers(3, 7))]):
			place(big, music_box(m, 1.0), b0 * bar + k * 0.42 + rng.uniform(0, 0.08), 0.13, 0.6 - k * 0.2)
	for b in range(bars):
		if b % 3 == 1:
			place(mid, tom(28 + int(rng.integers(0, 3))), b * bar + 2.0, 0.24, -0.3)
		if rng.uniform() < 0.45:
			place(big, whisper(rng.uniform(1.0, 2.0)), b * bar + rng.uniform(0, 3), 0.17, rng.uniform(-0.9, 0.9))
	pts = [(0, 0.7), (loop * 0.3, 0.9), (loop * 0.6, 1.0), (loop * 0.85, 0.8), (loop, 0.7)]
	return mixdown(big, mid, loop, pts, '90 30 100 100 40', '45 50 90 80 10', 1.1), loop


# ---------------------------------------------------------------- chase

def chase():
	e8 = 0.13
	bar = e8 * 7
	bars = 80
	loop = bars * bar
	total = loop + 6.0
	big, mid, n = buffers(total)
	at = lambda b, e=0.0: b * bar + e * e8
	ost = [0, 0, 3, 0, 6, 0, 5]
	roots = [40, 40, 40, 40, 41, 41, 38, 39]
	stabs = [[52, 55, 59], [52, 55, 59], [52, 55, 59], [52, 55, 59], [53, 56, 60], [53, 56, 60], [50, 53, 57, 58], [51, 54, 58, 59]]
	def sec_of(b):
		return 'A' if b < 8 else 'B' if b < 32 else 'C' if b < 56 else 'D' if b < 64 else 'E'
	for b in range(bars):
		s = sec_of(b)
		r = roots[(b // 2) % 8]
		for e in range(7):
			place(mid, bass(r - 12 + ost[e], e8 * 0.85), at(b, e), 0.44 if e in (0, 2, 4) else 0.3)
		if s != 'D':
			for e in range(7):
				place(mid, hat(e == 6 and b % 2), at(b, e), 0.09 if e in (0, 2, 4) else 0.05, 0.35)
		if s in ('B', 'C', 'E'):
			place(mid, kick(), at(b, 0), 0.5)
			place(mid, kick(), at(b, 4), 0.38)
			place(mid, snare(), at(b, 2), 0.42, 0.05)
			place(mid, snare(), at(b, 5.5), 0.22, 0.05)
			if b % 8 == 7:
				for q, m in enumerate((52, 50, 47, 45, 43)):
					place(mid, tom(m), at(b, 2 + q), 0.32, 0.4 - q * 0.2)
		if s in ('B', 'E'):
			place(mid, stab(stabs[(b // 2) % 8], e8 * 1.6), at(b, 0), 0.2, -0.25)
			place(mid, stab(stabs[(b // 2) % 8], e8 * 1.2), at(b, 4), 0.14, -0.25)
		if s == 'C':
			if b % 2 == 0:
				place(mid, organ_chord(stabs[(b // 2) % 8], bar * 2), at(b), 0.11, -0.2)
		if s == 'D':
			if b % 4 == 0:
				place(big, bell_toll(28), at(b), 0.32)
			place(mid, heartbeat(), at(b, 0), 0.32)
			if rng.uniform() < 0.5:
				place(big, whisper(rng.uniform(0.6, 1.2)), at(b, rng.uniform(0, 5)), 0.2, rng.uniform(-0.9, 0.9))
		if s in ('A', 'D') and b % 2 == 0:
			for k, m in enumerate((76, 75, 70)):
				place(big, music_box(m, 1.0 if s == 'D' else 0.0), at(b, k * 2), 0.18, (k - 1) * 0.4)
	phrase = [(0, 2, 64), (2, 2, 67), (4, 3, 70), (7, 2, 69), (9, 2, 67), (11, 3, 63), (14, 4, 64), (18, 3, 58), (21, 7, 59)]
	events = []
	for rep in range(6):
		b0 = 32 + rep * 4
		for e, d, m in phrase:
			events.append((at(b0, e), d * e8 * 0.95, m + 12 + (12 if rep >= 4 and e >= 14 else 0)))
	place(mid, lead_line(events, total), 0, 0.3, 0.15)
	g = {'A': 0.55, 'B': 0.85, 'C': 1.0, 'D': 0.5, 'E': 0.9}
	pts = [(at(b), g[sec_of(b)]) for b in range(bars)] + [(loop, g['A'])]
	return mixdown(big, mid, loop, pts, '60 40 80 100 15', '25 50 60 80 5', 1.3), loop


# ---------------------------------------------------------------- black_channel

def black_channel():
	s16 = 0.125
	bar = s16 * 16
	bars = 48
	loop = bars * bar
	total = loop + 7.0
	big, mid, n = buffers(total)
	at = lambda b, s=0.0: b * bar + s * s16
	prog = [36, 36, 32, 32, 34, 34, 31, 31]
	seq = [0, 12, 7, 12, 3, 12, 7, 15, 0, 12, 7, 12, 3, 12, 6, 14]
	pads = [[60, 63, 67], [60, 63, 67], [56, 60, 63], [56, 60, 63], [58, 62, 65], [58, 62, 65], [55, 59, 62, 63], [55, 59, 62, 66]]
	def sec_of(b):
		return 'A' if b < 8 else 'B' if b < 24 else 'C' if b < 32 else 'D'
	for b in range(bars):
		s = sec_of(b)
		r = prog[(b // 2) % 8]
		for k in range(16):
			if s == 'A' and k % 2:
				continue
			place(mid, arp_note(r + 24 + seq[k], s16 * 0.9), at(b, k), 0.13 * (1.2 if k % 4 == 0 else 0.85), 0.35 * np.sin(k * 0.8))
		if s != 'A':
			for k in (0, 3, 6, 8, 11, 14):
				place(mid, bass(r - 12 + (12 if k == 14 else 0), s16 * 1.6), at(b, k), 0.42)
		if s in ('B', 'D'):
			for k in (0, 8):
				place(mid, kick(), at(b, k), 0.5)
			place(mid, kick(), at(b, 10), 0.3)
			for k in (4, 12):
				place(mid, snare(), at(b, k), 0.38, 0.05)
			for k in range(0, 16, 2):
				place(mid, hat(k == 14), at(b, k), 0.07, 0.35)
		if s == 'C':
			place(mid, heartbeat(), at(b, 0), 0.32)
			if b % 4 == 0:
				place(big, bell_toll(24), at(b), 0.3)
			if rng.uniform() < 0.5:
				place(big, whisper(rng.uniform(0.8, 1.6)), at(b, rng.uniform(0, 10)), 0.18, rng.uniform(-0.9, 0.9))
		if b % 2 == 0:
			place(big, choir(pads[(b // 2) % 8], bar * 2), at(b), 0.42 if s != 'A' else 0.3)
	phrase = [(0, 6, 72), (6, 2, 74), (8, 6, 75), (14, 2, 74), (16, 8, 72), (24, 4, 71), (28, 4, 68), (32, 6, 67), (38, 2, 68), (40, 8, 71), (48, 8, 72), (56, 8, 78)]
	events = []
	for rep in range(2):
		b0 = 8 + rep * 4 if rep == 0 else 32 + 4
		for st, d, m in phrase:
			events.append((at(b0, st), d * s16 * 0.95, m + (12 if rep else 0)))
	place(mid, lead_line(events, total), 0, 0.26, -0.1)
	g = {'A': 1.0, 'B': 0.9, 'C': 0.7, 'D': 1.0}
	pts = [(at(b), g[sec_of(b)]) for b in range(bars)] + [(loop, g['A'])]
	return mixdown(big, mid, loop, pts, '70 40 90 100 20', '30 50 70 80 5', 1.25), loop


TRACKS = {'yard_dread': yard_dread, 'stratum_deep': stratum_deep, 'chase': chase, 'black_channel': black_channel}


def main():
	here = os.path.dirname(os.path.abspath(__file__))
	out = os.path.join(here, '..', '..', 'assets', 'audio', 'music')
	names = sys.argv[1:] or list(TRACKS)
	for name in names:
		x, loop = TRACKS[name]()
		write_ogg(os.path.join(out, name + '.ogg'), x, 6)
		print('wrote', name, '%.1f s' % loop)


if __name__ == '__main__':
	main()
