#!/usr/bin/env python3
"""Stasis pod awakening audio for the Trace Vault.

pod_awaken.wav is timed to PosePod() in trace_cycle_test.vg (t = pod_t seconds):
  0.0-0.7  clamp arms retract (servo + clunks)
  0.5-1.4  seam arcing crackle
  1.0      pressure seal breaks (pop + burst)  -> fog hiss 1.0-9.0
  1.2-2.6  lids crack (strained servo, creak)
  2.6-6.0  lids swing open (hydraulic whine), latch thud at 6.0
orac_run.wav: Kokoro bm_george (sid 9) takes, fast delivery, "RUN!" pushed forward.

Usage: python3 pod_audio.py <out_dir> <orac_line.wav> <orac_run.wav>
"""
import sys
import numpy as np
import scipy.io.wavfile as wavfile
from scipy import signal

SR = 48000
rng = np.random.default_rng(7)


def t_axis(sec):
	return np.arange(int(sec * SR)) / SR


def env_ad(n, a, d):
	e = np.ones(n)
	na, nd = int(a * SR), int(d * SR)
	if na: e[:na] = np.linspace(0, 1, na)
	if nd: e[-nd:] *= np.linspace(1, 0, nd)
	return e


def bp(x, lo, hi, order=2):
	sos = signal.butter(order, [lo, hi], btype='band', fs=SR, output='sos')
	return signal.sosfilt(sos, x)


def lp(x, hi, order=2):
	return signal.sosfilt(signal.butter(order, hi, btype='low', fs=SR, output='sos'), x)


def hp(x, lo, order=2):
	return signal.sosfilt(signal.butter(order, lo, btype='high', fs=SR, output='sos'), x)


def place(buf, clip, at, gain=1.0, pan=0.0):
	i = int(at * SR)
	j = min(len(buf), i + len(clip))
	if j <= i: return
	l, r = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
	buf[i:j, 0] += clip[:j - i] * gain * l
	buf[i:j, 1] += clip[:j - i] * gain * r


def servo(sec, f0, f1, grit=0.3):
	t = t_axis(sec)
	f = np.linspace(f0, f1, len(t)) * (1 + 0.015 * np.sin(2 * np.pi * 9 * t))
	ph = 2 * np.pi * np.cumsum(f) / SR
	tone = np.sign(np.sin(ph)) * 0.35 + np.sin(ph * 2) * 0.4 + np.sin(ph * 3.01) * 0.2
	tone = lp(tone, 2600)
	g = bp(rng.standard_normal(len(t)), 300, 1800) * grit
	g *= 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t))
	return (tone * 0.5 + g) * env_ad(len(t), 0.04, 0.08)


def clunk(freq=90, sec=0.35, bright=0.5):
	t = t_axis(sec)
	body = np.sin(2 * np.pi * freq * t * (1 - 0.25 * t)) * np.exp(-t * 18)
	ring = np.sin(2 * np.pi * freq * 6.3 * t) * np.exp(-t * 40) * 0.3
	click = hp(rng.standard_normal(len(t)), 2000) * np.exp(-t * 300) * bright
	return body + ring + click


def crackle(sec, density=60):
	n = int(sec * SR)
	x = np.zeros(n)
	for _ in range(int(sec * density)):
		i = rng.integers(0, max(1, n - 2000))
		L = rng.integers(80, 1400)
		burst = rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4))
		x[i:i + L] += burst * rng.uniform(0.3, 1.0)
	buzz = np.sign(np.sin(2 * np.pi * 120 * t_axis(sec))) * 0.08
	x = hp(x, 1500) + buzz * (np.abs(x) > 0.05)
	return x * env_ad(n, 0.01, 0.1)


def hiss(sec, peak_at=0.15):
	t = t_axis(sec)
	n = len(t)
	white = rng.standard_normal(n)
	# Cold gas jet: bright initial burst, then breathy wide-band flow that thins out.
	jet = bp(white, 2500, 11000, 3)
	body = bp(white, 400, 3000, 2) * 0.6
	gust = 0.75 + 0.25 * lp(rng.standard_normal(n), 3) * 6
	gust = np.clip(gust, 0.3, 1.2)
	e = np.minimum(1, t / 0.03) * (0.35 + 0.65 * np.exp(-np.maximum(0, t - peak_at) * 0.9))
	e *= np.clip((sec - t) / 2.5, 0, 1)
	return (jet + body) * gust * e


def creak(sec):
	t = t_axis(sec)
	f = 70 + 25 * np.sin(2 * np.pi * 0.7 * t)
	ph = 2 * np.pi * np.cumsum(f) / SR
	pulses = (np.sin(ph) > 0.97).astype(float)
	x = signal.lfilter([1], [1, -0.97], pulses) * 0.05
	x = bp(x, 200, 2400)
	return x * env_ad(len(t), 0.2, 0.3)


def reverb(x, sec=1.6, wet=0.22):
	n = int(sec * SR)
	ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 4.2)
	ir = lp(ir, 5000)
	ir /= np.sqrt(np.sum(ir ** 2))
	out = np.stack([signal.fftconvolve(x[:, c], ir * (1 if c == 0 else -1) + 0, mode='full')[:len(x)] for c in range(2)], 1)
	return x * (1 - wet) + out * wet


def build_pod():
	buf = np.zeros((int(10.0 * SR), 2))
	# clamps
	place(buf, servo(0.6, 180, 320, 0.25), 0.02, 0.35, -0.5)
	place(buf, servo(0.6, 190, 330, 0.25), 0.05, 0.35, 0.5)
	place(buf, clunk(70, 0.5, 0.6), 0.66, 0.7, -0.4)
	place(buf, clunk(76, 0.5, 0.6), 0.71, 0.7, 0.4)
	# seam arcing
	place(buf, crackle(0.9), 0.5, 0.25, -0.15)
	place(buf, crackle(0.9), 0.52, 0.25, 0.15)
	# seal break: low thump + pressure burst
	place(buf, clunk(48, 0.9, 1.0), 1.0, 0.9)
	pop = hp(rng.standard_normal(int(0.25 * SR)), 900) * np.exp(-t_axis(0.25) * 22)
	place(buf, pop, 1.0, 0.6)
	# fog hiss, stereo-decorrelated
	place(buf, hiss(8.0), 1.0, 0.17, -0.6)
	place(buf, hiss(8.0), 1.01, 0.17, 0.6)
	# lids crack: strained slow servo + creak
	place(buf, servo(1.4, 90, 140, 0.45), 1.2, 0.3)
	place(buf, creak(1.4), 1.2, 0.5)
	# lids swing: hydraulic whine rising then easing
	sw = servo(3.4, 210, 360, 0.2)
	sw *= np.interp(np.arange(len(sw)), [0, len(sw) * 0.5, len(sw)], [0.6, 1.0, 0.5])
	place(buf, sw, 2.6, 0.3, -0.35)
	place(buf, servo(3.4, 205, 352, 0.2), 2.62, 0.3, 0.35)
	place(buf, clunk(60, 0.7, 0.4), 5.95, 0.8, -0.5)
	place(buf, clunk(64, 0.7, 0.4), 6.0, 0.8, 0.5)
	# low room rumble under everything
	rum = lp(rng.standard_normal(len(buf)), 70, 4) * 1.4
	rum *= np.interp(np.arange(len(buf)) / SR, [0, 1.0, 6.0, 10.0], [0.2, 0.7, 0.5, 0.0])
	buf[:, 0] += rum
	buf[:, 1] += rum
	buf = reverb(buf, 1.4, 0.25)
	fade = np.clip((10.0 - np.arange(len(buf)) / SR) / 0.8, 0, 1)
	buf *= fade[:, None]
	return buf


def load_voice(path):
	rate, d = wavfile.read(path)
	d = d.astype(np.float64)
	if d.ndim > 1: d = d.mean(1)
	d /= 32768.0 if np.abs(d).max() > 1.5 else 1.0
	if rate != SR:
		d = signal.resample_poly(d, SR, rate)
	nz = np.where(np.abs(d) > 0.01)[0]
	return d[max(0, nz[0] - 400):nz[-1] + 1200]


def build_orac(line_path, run_path):
	a = load_voice(line_path)
	r = load_voice(run_path)
	# Urgency: push "RUN!" forward with drive and presence, short breath gap.
	r = np.tanh(r / np.abs(r).max() * 2.2) * 0.95
	r = r + hp(r, 2500) * 0.35
	a = a / np.abs(a).max() * 0.8
	gap = np.zeros(int(0.12 * SR))
	v = np.concatenate([a, gap, r])
	# Comms-channel tint so Orac reads as a system voice, not a person in the room.
	v = bp(v, 160, 7500) + v * 0.35
	v /= np.abs(v).max()
	st = np.stack([v, v], 1)
	st = reverb(st, 0.6, 0.12)
	return st / np.abs(st).max() * 0.92


def write(path, x):
	x = x / max(1.0, np.abs(x).max()) * 0.95
	wavfile.write(path, SR, (x * 32767).astype(np.int16))


if __name__ == '__main__':
	out = sys.argv[1]
	write(f'{out}/pod_awaken.wav', build_pod())
	write(f'{out}/orac_run.wav', build_orac(sys.argv[2], sys.argv[3]))
	print('ok')
