"""Shared synthesis helpers for the Ash Meridian sound generators (48 kHz float, mono or stereo)."""
import os
import subprocess
import numpy as np
import scipy.io.wavfile as wavfile
from scipy import signal

SR = 48000


def t_axis(sec):
	return np.arange(int(sec * SR)) / SR


def _sos(kind, f, order):
	return signal.butter(order, f, btype=kind, fs=SR, output='sos')


def lp(x, hi, order=2):
	return signal.sosfilt(_sos('low', min(hi, SR * 0.45), order), x, axis=0)


def hp(x, lo, order=2):
	return signal.sosfilt(_sos('high', lo, order), x, axis=0)


def bp(x, lo, hi, order=2):
	return signal.sosfilt(_sos('band', [lo, min(hi, SR * 0.45)], order), x, axis=0)


def ramp(t, a, b):
	return np.clip((t - a) / max(b - a, 1e-6), 0.0, 1.0)


def env_ad(n, attack, decay):
	t = np.arange(n) / SR
	a = np.clip(t / max(attack, 1e-5), 0, 1)
	d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-5))
	return a * d


def env_adsr(n, a, d, s, r, gate):
	t = np.arange(n) / SR
	e = np.where(t < a, t / max(a, 1e-5), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-5)))
	return np.where(t < gate, e, e * np.exp(-np.maximum(t - gate, 0) / max(r, 1e-5)))


def sweep(f0, f1, n):
	"""Phase of an exponential glide from f0 to f1 over n samples."""
	f = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
	return 2 * np.pi * np.cumsum(f) / SR


def saw(phase):
	return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0


def square(phase, duty=0.5):
	return np.where((phase / (2 * np.pi)) % 1.0 < duty, 1.0, -1.0)


def fm_bell(freq, sec, ratio=3.5, index=2.2, decay=1.6, bright_decay=0.35):
	"""Celesta / music-box tone: sine carrier with an inharmonic modulator whose index dies fast."""
	t = t_axis(sec)
	idx = index * np.exp(-t / bright_decay)
	tone = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * ratio * t))
	tone += 0.25 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t / (bright_decay * 0.5))
	return tone * env_ad(len(t), 0.002, decay)


def sweep_lp(x, cutoff_hz, q=0.9):
	"""Resonant low-pass whose cutoff follows an envelope, updated every 128 samples."""
	cutoff_hz = np.broadcast_to(np.asarray(cutoff_hz, dtype=float), x.shape)
	out = np.empty_like(x)
	block = 128
	zi = np.zeros(2)
	for s in range(0, len(x), block):
		w = 2 * np.pi * float(np.clip(cutoff_hz[s], 30, SR * 0.45)) / SR
		alpha = np.sin(w) / (2 * q)
		c = np.cos(w)
		b = np.array([(1 - c) / 2, 1 - c, (1 - c) / 2]) / (1 + alpha)
		a = np.array([1.0, -2 * c / (1 + alpha), (1 - alpha) / (1 + alpha)])
		out[s:s + block], zi = signal.lfilter(b, a, x[s:s + block], zi=zi)
	return out


def place(buf, clip, at, gain=1.0, pan=0.0):
	i = int(at * SR)
	if i >= len(buf) or i < 0:
		return
	j = min(len(buf), i + len(clip))
	if clip.ndim == 1:
		l, r = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
		buf[i:j, 0] += clip[:j - i] * gain * l
		buf[i:j, 1] += clip[:j - i] * gain * r
	else:
		buf[i:j] += clip[:j - i] * gain


def normalize(x, peak=0.89):
	m = np.max(np.abs(x))
	return x if m < 1e-9 else x * (peak / m)


def fade_edges(x, fin=0.002, fout=0.01):
	n = len(x)
	a = min(int(fin * SR), n // 2)
	b = min(int(fout * SR), n // 2)
	e = np.ones(n)
	if a:
		e[:a] = np.linspace(0, 1, a)
	if b:
		e[-b:] = np.linspace(1, 0, b)
	return x * (e if x.ndim == 1 else e[:, None])


def write_ogg(path, x, quality=6, reverb=None, tail=0.8):
	"""Write float audio as Ogg Vorbis. reverb = sox reverb args, e.g. '40 50 70' (reverberance, damping, room)."""
	os.makedirs(os.path.dirname(path), exist_ok=True)
	tmp = path[:-4] + '.tmp.wav'
	wavfile.write(tmp, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
	src = tmp
	rv = path[:-4] + '.rv.wav'
	if reverb:
		subprocess.run(['sox', tmp, rv, 'gain', '-6', 'pad', '0', str(tail), 'reverb'] + reverb.split() + ['norm', '-1'], check=True)
		src = rv
	subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-c:a', 'libvorbis', '-q:a', str(quality), path], check=True)
	for f in (tmp, rv):
		if os.path.exists(f):
			os.remove(f)
