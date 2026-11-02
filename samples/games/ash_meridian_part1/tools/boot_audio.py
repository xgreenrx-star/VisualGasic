#!/usr/bin/env python3
"""Boot terminal audio, timed to boot_terminal.vg (t = seconds since the tube lit).

  0.00        power-on thump and degauss swell; CRT hum and whine start
  LINE_TIMES  relay tick per log line, light data chatter between lines
  3.30        Orac overlay engages (rising chirp)
  3.45-4.15   Orac's sweep (filtered shimmer)
  4.85        carrier seized: static surge, hum warps
  CUT         hard thunk, hum dies; static tail decays under the face video

boot_terminal_push.wav     CUT = 5.30 (face pushes through the static)
boot_terminal_collapse.wav CUT = 5.72 (CRT collapses to a dot, face irises open)

Usage: python3 boot_audio.py <out_dir>
"""
import sys
import numpy as np
import scipy.io.wavfile as wavfile
from scipy import signal

SR = 48000

LINE_TIMES = [0.42, 0.56, 0.70, 0.78, 0.95, 1.02, 1.09, 1.34, 1.50, 1.61, 1.80,
	1.97, 2.14, 2.30, 2.49, 2.66, 2.84, 3.04]
T_ORAC = 3.3
T_SWEEP0 = 3.45
T_SWEEP1 = 4.15
T_ORAC_LINE = 4.28
T_CORRUPT = 4.85


def t_axis(sec):
	return np.arange(int(sec * SR)) / SR


def bp(x, lo, hi, order=2):
	return signal.sosfilt(signal.butter(order, [lo, hi], btype='band', fs=SR, output='sos'), x)


def lp(x, hi, order=2):
	return signal.sosfilt(signal.butter(order, hi, btype='low', fs=SR, output='sos'), x)


def hp(x, lo, order=2):
	return signal.sosfilt(signal.butter(order, lo, btype='high', fs=SR, output='sos'), x)


def place(buf, clip, at, gain=1.0, pan=0.0):
	i = int(at * SR)
	j = min(len(buf), i + len(clip))
	if j <= i:
		return
	l, r = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
	buf[i:j, 0] += clip[:j - i] * gain * l
	buf[i:j, 1] += clip[:j - i] * gain * r


def ramp(t, a, b):
	return np.clip((t - a) / max(b - a, 1e-6), 0.0, 1.0)


def tick(rng, freq):
	t = t_axis(0.05)
	click = hp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 420)
	body = np.sin(2 * np.pi * freq * t) * np.exp(-t * 160) * 0.5
	return click + body


def chatter(rng, sec):
	# Short square-ish data blips, like a teletype handshake under the hum.
	out = np.zeros(int(sec * SR))
	pos = 0
	while pos < len(out):
		n = int(rng.uniform(0.006, 0.02) * SR)
		f = rng.choice([1200, 1800, 2400, 3100])
		t = np.arange(n) / SR
		blip = np.sign(np.sin(2 * np.pi * f * t)) * np.hanning(n)
		out[pos:pos + n] += blip[:len(out) - pos]
		pos += n + int(rng.uniform(0.01, 0.06) * SR)
	return lp(out, 5000) * 0.25


def thunk(rng):
	t = t_axis(0.9)
	body = np.sin(2 * np.pi * 52 * t * (1 - 0.35 * t)) * np.exp(-t * 7)
	knock = np.sin(2 * np.pi * 130 * t) * np.exp(-t * 30) * 0.5
	snap = hp(rng.standard_normal(len(t)), 1500) * np.exp(-t * 180) * 0.9
	return body + knock + snap


def build(cut):
	rng = np.random.default_rng(14242)
	total = cut + 1.7
	t = t_axis(total)
	n = len(t)
	out = np.zeros((n, 2))
	alive = (t < cut).astype(float)

	# Power-on: low thump plus the degauss "bwoom" (60 Hz swelling and wobbling).
	place(out, thunk(rng) * 0.55, 0.0)
	dg = t_axis(1.1)
	degauss = np.sin(2 * np.pi * 60 * dg) * np.sin(np.pi * dg / 1.1) ** 2 * (1 + 0.5 * np.sin(2 * np.pi * 7 * dg))
	place(out, degauss * 0.35, 0.02)

	# Mains hum with harmonics, warped during the corruption.
	warp = ramp(t, T_CORRUPT, cut)
	f_hum = 60 * (1 + 0.08 * warp * np.sin(2 * np.pi * 9 * t))
	ph = 2 * np.pi * np.cumsum(f_hum) / SR
	hum = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.12 * np.sin(5 * ph)
	hum_env = ramp(t, 0.0, 0.35) * (0.10 + 0.08 * warp) * alive
	out += (hum * hum_env)[:, None]

	# Flyback whine: quiet, slightly detuned per channel so it shimmers.
	whine_env = ramp(t, 0.05, 0.6) * 0.012 * (1 + 2.0 * warp) * alive
	out[:, 0] += np.sin(2 * np.pi * 15734 * t) * whine_env
	out[:, 1] += np.sin(2 * np.pi * 15741 * t) * whine_env

	# Relay ticks per printed line, plus data chatter between them.
	for i, at in enumerate(LINE_TIMES):
		place(out, tick(rng, rng.uniform(900, 1600)), at, 0.32, pan=rng.uniform(-0.4, 0.4))
	place(out, chatter(rng, LINE_TIMES[-1] - LINE_TIMES[0] + 0.15), LINE_TIMES[0], 0.12)

	# Orac engages: a cyan chirp rising over the green hum.
	ct = t_axis(0.22)
	chirp = np.sin(2 * np.pi * (700 * ct + 0.5 * 5200 * ct * ct / 0.22)) * np.sin(np.pi * ct / 0.22)
	place(out, chirp * 0.16, T_ORAC, pan=0.2)
	place(out, chirp[::-1] * 0.08, T_ORAC + 0.12, pan=-0.2)

	# Sweep: bandpassed noise gliding upward as the scan line moves down.
	sw_len = T_SWEEP1 - T_SWEEP0 + 0.1
	st = t_axis(sw_len)
	noise = rng.standard_normal(len(st))
	shimmer = np.zeros(len(st))
	for k, f in enumerate([1500, 2400, 3600, 5200, 7000]):
		centre = sw_len * (k + 0.5) / 5
		shimmer += bp(noise, f * 0.85, f * 1.15) * np.exp(-((st - centre) / (sw_len / 6)) ** 2)
	shimmer *= np.sin(np.pi * st / sw_len) * (1 + 0.6 * np.sin(2 * np.pi * 24 * st))
	place(out, shimmer * 0.22, T_SWEEP0)

	# Orac's line lands: two soft blips.
	bt = t_axis(0.06)
	blip = np.sin(2 * np.pi * 1760 * bt) * np.hanning(len(bt))
	place(out, blip * 0.1, T_ORAC_LINE)
	place(out, blip * 0.08, T_ORAC_LINE + 0.08)

	# Static: a faint bed the whole time, surging when the carrier is seized.
	white = rng.standard_normal(n)
	pink = lp(white, 6000)
	crack = (rng.random(n) < 0.0009 + 0.006 * warp) * rng.standard_normal(n) * 3.0
	crack = hp(crack, 800)
	bed = 0.012 * ramp(t, 0.0, 0.3)
	surge = 0.22 * warp ** 1.6
	tail_k = ramp(t, cut, cut + 1.5)
	tail = 0.16 * (1 - tail_k) ** 2.2 * (t >= cut)
	static_env = (bed + surge) * alive + tail
	stat = pink * static_env + crack * (0.05 + 0.25 * warp) * alive + crack * tail * 0.6
	out[:, 0] += stat
	out[:, 1] += np.roll(stat, 37)

	# The cut: hard thunk, then only the decaying static tail is left.
	place(out, thunk(rng) * 0.9, cut)

	end = np.ones(n)
	end[-int(0.08 * SR):] = np.linspace(1, 0, int(0.08 * SR))
	out *= end[:, None]
	peak = np.max(np.abs(out))
	return out / peak * 0.89


def write(path, x):
	wavfile.write(path, SR, (x * 32767).astype(np.int16))


if __name__ == '__main__':
	out_dir = sys.argv[1]
	write(f'{out_dir}/boot_terminal_push.wav', build(5.30))
	write(f'{out_dir}/boot_terminal_collapse.wav', build(5.72))
